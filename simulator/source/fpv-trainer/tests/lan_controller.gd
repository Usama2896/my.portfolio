extends SceneTree
var checks := 0
func check(value: bool, title: String) -> void:
	assert(value,title)
	checks += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var license_ = load("res://activation.gd").new()
	license_.activate(load("res://owner_settings.gd").ACTIVATION_KEY)
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	app.set_physics_process(false)
	app.splash_remaining = 0
	app.controller = load("res://tests/fake_controller.gd").new()
	app.poll_radio()
	var lan = app.lan
	lan.set_physics_process(false)
	lan.port = 26349
	lan.host_room()
	lan.prepare_local(true)
	check(lan.prepared and app.remote_waiting_low,"radio opens LAN view disarmed")
	app.update_remote_arming(0.25)
	lan._physics_process(0.01)
	check(lan.rules.players[1].ready,"stable low radio is ready")
	check(app.drone.freeze and not app.active,"ready radio is held until assigned turn")
	app.controller.connected.clear()
	app.poll_radio()
	lan._physics_process(0.01)
	check(not lan.rules.players[1].ready and lan.rules.phase=="lobby","unplug while in lobby clears readiness without false start")
	app.controller.connected.assign([0])
	app.poll_radio()
	check(app.remote_waiting_low,"reconnect requires low-throttle arming")
	app.update_remote_arming(0.25)
	lan._physics_process(0.01)
	for id in [2,3]: lan.rules.add_player(id,"Pilot",0.3); lan.rules.players[id].ready = true
	check(lan.rules.begin(),"all three radio participants can start")
	lan.rules.tick(5)
	lan.apply_local_state()
	check(app.remote_waiting_low,"turn start checks throttle again")
	app.update_remote_arming(0.25)
	lan.apply_local_state()
	check(app.active and not app.drone.freeze,"armed current pilot receives real local flight controls")
	app.controller.connected.clear()
	app.poll_radio()
	lan._physics_process(0.01)
	check(lan.rules.phase=="finished" and lan.rules.outcome.contains("USB radio disconnected"),"USB loss aborts team with correct reason")
	lan.disconnect_room()
	print("PASS: ",checks," LAN USB readiness, rearming, waiting-turn and disconnect checks (injected device reports)")
	quit()
