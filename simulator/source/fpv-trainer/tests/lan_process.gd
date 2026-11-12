extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var disconnect_case := OS.get_environment("FPV_TEST_MODE")=="disconnect"
	var obstacle := OS.get_environment("FPV_TEST_MODE")=="obstacle"
	var is_host := "--server" in args
	var expected_players := int(OS.get_environment("FPV_TEST_PLAYERS")) if not OS.get_environment("FPV_TEST_PLAYERS").is_empty() else 3
	var role := "host" if is_host else "client1" if "--client1" in args else "client2"
	var license_ = load("res://activation.gd").new()
	assert(license_.activate(load("res://owner_settings.gd").ACTIVATION_KEY))
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	app.set_physics_process(false)
	app.splash_remaining = 0
	app.trainee = role
	var lan = app.lan
	lan.port = int(OS.get_environment("FPV_TEST_PORT"))
	lan.options.controls = 0
	lan.options.legs = [30.0,30.0,30.0]
	lan.options.radius = 1.0
	lan.options.settle = 0.5
	if obstacle and is_host:
		var gate: Dictionary = app.course.gates[0].duplicate(true)
		gate.type = "ring"
		gate.x = 0.0
		gate.z = -4.0
		gate.height = 2.0
		gate.yaw_degrees = 0.0
		gate.width = 2.0
		gate.opening_height = 2.0
		app.course.gates = [gate]
		app.course.laps = 1
		lan.options.mode = 1
	var original: Dictionary = app.course.duplicate(true)
	if is_host: lan.host_room()
	else:
		lan.address = "127.0.0.1"
		lan.join_room()
	var begin := Time.get_ticks_msec()
	var airborne := 0.0
	var final_time := 0
	var started := false
	while Time.get_ticks_msec()-begin<25000:
		await physics_frame
		if lan.connected and lan.local_id in lan.rules.players and not lan.prepared and lan.rules.phase=="lobby": lan.prepare_local(false)
		if is_host and not started and lan.rules.order.size()==expected_players:
			var all_ready := true
			for id in lan.rules.order:
				if not lan.rules.players[id].ready: all_ready = false
			if all_ready: lan.request_start(); started = true
		if disconnect_case and role=="client1" and lan.rules.phase=="running":
			lan.disconnect_room()
			assert(app.course==original and not lan.connected)
			var file := FileAccess.open("/tmp/al-jehad-lan-"+role+".json",FileAccess.WRITE)
			file.store_string(JSON.stringify({"withdrawn":true}))
			print("PASS: client withdraws during active relay; solo state restored")
			quit()
			return
		if lan.prepared and lan.rules.can_fly(lan.local_id):
			airborne += 1.0/60
			var index: int = lan.rules.order.find(lan.local_id)
			var position_: Vector3 = lan.rules.stations()[index]+Vector3.UP*1.5 if airborne<0.3 else lan.rules.stations()[index+1]+Vector3.UP*(app.drone_span/2-0.04)
			if obstacle: position_ = Vector3(0,2,-3) if airborne<0.4 else Vector3(0,2,-5)
			app.drone.request_reset(Transform3D(Basis.IDENTITY,position_))
			app.drone.freeze = true
		if lan.rules.phase=="finished" and lan.result_saved:
			if disconnect_case: assert(lan.rules.outcome.contains("disconnected"),lan.rules.outcome)
			else: assert(lan.rules.leg==(0 if obstacle else 3),lan.rules.outcome)
			assert(lan.rules.rows().size()==expected_players)
			if not disconnect_case:
				for row in lan.rules.rows(): assert(row.result=="Finished" and row.score>0)
			if final_time==0:
				final_time = Time.get_ticks_msec()
				assert(lan.write_csv("user://network-results.csv"))
				var file := FileAccess.open("/tmp/al-jehad-lan-"+role+".json",FileAccess.WRITE)
				file.store_string(JSON.stringify({"phase":lan.rules.phase,"leg":lan.rules.leg,"mode":lan.options.mode,"players":lan.rules.rows(),"history":lan.history().size()}))
			if Time.get_ticks_msec()-final_time>1500:
				lan.disconnect_room()
				assert(app.course==original and not lan.connected)
				print("PASS: ",role," joined real ENet room, saw all pilots, host-validated race completion, shared results and CSV; solo course restored")
				quit()
				return
	push_error(role+" timed out: "+lan.rules.phase+" "+lan.rules.outcome+" "+lan.last_message)
	quit(1)
