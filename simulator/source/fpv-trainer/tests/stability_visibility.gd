extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func run() -> void:
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	check(not app.practice_stabilized,"ordinary practice remains the default")
	var modes: OptionButton = app.content.get_children().filter(func(c): return c is OptionButton)[0]
	check(modes.get_item_text(2).contains("Beginner Stabilized"),"beginner mode is an explicit optional choice")
	app.controller = load("res://tests/fake_controller.gd").new()
	app.poll_radio()
	app.practice_stabilized = true
	app.assisted = false
	app.wind = 0
	app.launch_remote()
	app.update_remote_arming(0.25)
	var start_y: float = app.drone.position.y
	app.controller.reports[0][3] = -0.7 # input power 85%, assisted climb
	await frames(90)
	check(app.drone.position.y>start_y+0.8,"beginner remote throttle climbs")
	app.controller.reports[0][3] = 0 # midpoint is height hold, not raw 50% thrust
	await frames(90)
	var held: float = app.drone.position.y
	await frames(60)
	check(absf(app.drone.position.y-held)<0.25,"mid-throttle holds altitude after settling")
	app.controller.reports[0][1] = -0.6
	app.controller.reports[0][0] = 0.25
	await frames(60)
	check(absf(app.drone.rotation.x)<0.27 and absf(app.drone.rotation.z)<0.27,"beginner attitude is gently limited")
	var moving: float = Vector2(app.drone.linear_velocity.x,app.drone.linear_velocity.z).length()
	app.controller.reports[0][1] = 0
	app.controller.reports[0][0] = 0
	await frames(90)
	check(absf(app.drone.rotation.x)<0.04 and absf(app.drone.rotation.z)<0.04,"releasing sticks auto-levels remote practice")
	check(Vector2(app.drone.linear_velocity.x,app.drone.linear_velocity.z).length()<moving*0.5,"centred sticks gently brake horizontal drift")
	app.controller.reports[0][3] = 1
	app._physics_process(1.0/60)
	check(app.throttle==0,"fully low throttle still cuts motors in beginner mode")
	app.leave_flight()
	app.use_radio = false
	app.start_flight(true)
	app.throttle = 9.8/30
	key(KEY_W,true)
	await frames(10)
	key(KEY_W,false)
	await frames(45)
	check(app.assessment and absf(app.drone.rotation.x)>0.15,"assessment remains Acro despite saved beginner preference")
	app.leave_flight()
	check(app.gate_labels[0].size()>0 and app.gate_labels[11].size()>=3,"all procedural labels are tracked")
	app.in_flight = true
	app.next_gate = 0
	app.show_all_labels = false
	app.update_gate_labels()
	check(app.gate_labels[0][0].visible and not app.gate_labels[1][0].visible,"only active obstacle labels show in flight")
	var old_camera: Vector3 = app.camera.position
	app.camera.global_position = app.gate_labels[0][0].global_position+Vector3(0,0,1)
	app.update_gate_labels()
	check(not app.gate_labels[0][0].visible,"nearby large labels hide instead of covering the FPV view")
	app.camera.position = old_camera
	app.show_all_labels = true
	app.update_gate_labels()
	check(app.gate_labels[1][0].visible,"all-labels setting restores other labels")
	app.leave_flight()
	app.update_gate_labels()
	check(app.gate_labels[1][0].visible,"editor overview retains its labels")
	app.high_visibility = false
	app.apply_visibility()
	var mesh: MeshInstance3D = app.gates[0].find_children("*","MeshInstance3D",true,false)[0]
	var base: Color = mesh.material_override.albedo_color
	app.high_visibility = true
	app.apply_visibility()
	check(mesh.material_override.albedo_color.r>base.r and mesh.material_override.emission_enabled,"visibility option increases frame contrast")
	app.high_visibility = false
	app.apply_visibility()
	check(mesh.material_override.albedo_color.is_equal_approx(base),"visibility setting reverses without accumulating brightness")
	app.high_visibility = true
	app.show_all_labels = false
	app.fov = 80
	app.save_settings()
	app.practice_stabilized = false
	app.high_visibility = false
	app.load_settings()
	check(app.practice_stabilized and app.high_visibility and app.fov==80,"practice and visibility preferences persist")
	print(("PASS" if failures==0 else "FAIL")+": %d beginner stability, Acro isolation and visibility checks" % checks)
	app.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
