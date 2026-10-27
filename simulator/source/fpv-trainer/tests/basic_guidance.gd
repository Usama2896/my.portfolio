extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
func turn(app, rate: float) -> float:
	app.leave_flight()
	app.practice_basic = false
	app.practice_stabilized = true
	app.yaw_rate = rate
	app.launch_keyboard()
	var previous: float = app.drone.rotation.y
	var total := 0.0
	key(KEY_Q,true)
	for i in range(90):
		await physics_frame
		var angle: float = app.drone.rotation.y
		total += wrapf(angle-previous,-PI,PI)
		previous = angle
	key(KEY_Q,false)
	return rad_to_deg(total)
func run() -> void:
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	check(not app.practice_basic,"Basic is opt-in")
	var mode: OptionButton = app.content.get_children().filter(func(c): return c is OptionButton)[0]
	check(mode.get_item_text(0).contains("Basic Guided") and mode.get_item_id(0)==3,"new mode is explicitly listed")
	var pitch_roll: float = app.rates
	var fast: float = await turn(app,240)
	var slower: float = await turn(app,90)
	print("Measured yaw: ",fast," degrees at 240 setting; ",slower," at 90 setting")
	check(fast>280 and fast>slower*2,"yaw setting changes actual stabilized turning speed")
	check(app.rates==pitch_roll,"yaw adjustment does not change pitch/roll rates")
	app.leave_flight()
	app.yaw_rate = 180
	app.wind = 8 # Basic must stay calm despite a previous practice wind setting.
	app.select_flight_mode(3)
	check(app.practice_basic and not app.practice_stabilized and app.practice_god_mode,"Basic selects easiest assists and God Mode")
	check(is_equal_approx(app.current_yaw_rate(),144),"Basic keeps responsive but moderated yaw")
	app.launch_keyboard()
	var start: Vector3 = app.drone.position
	key(KEY_W,true)
	await frames(120)
	key(KEY_W,false)
	check(app.drone.position.z<start.z-1.5,"Basic W moves forward without sustained manual banking")
	check(Vector2(app.drone.linear_velocity.x,app.drone.linear_velocity.z).length()<app.basic_speed+0.15,"Basic movement stays near configured walking speed")
	await frames(100)
	check(Vector2(app.drone.linear_velocity.x,app.drone.linear_velocity.z).length()<0.12,"releasing movement keys brings Basic flight to a stop")
	check(absf(app.drone.position.y-start.y)<0.2,"Basic keyboard flight holds altitude")
	check(absf(app.drone.rotation.x)<0.03 and absf(app.drone.rotation.z)<0.03,"Basic returns to level attitude")
	var x: float = app.drone.position.x
	key(KEY_D,true)
	await frames(100)
	key(KEY_D,false)
	check(app.drone.position.x>x+1,"Basic D moves sideways")
	app.leave_flight()
	app.controller = load("res://tests/fake_controller.gd").new()
	app.poll_radio()
	app.launch_remote()
	app.update_remote_arming(0.25)
	var radio_start: float = app.drone.position.y
	app.controller.reports[0][3] = -0.7
	await frames(90)
	check(app.drone.position.y>radio_start+0.8,"Basic remote throttle can climb")
	app.controller.reports[0][3] = 0
	await frames(90)
	var radio_z: float = app.drone.position.z
	app.controller.reports[0][1] = -0.75
	await frames(90)
	check(app.drone.position.z<radio_z-1 and absf(app.drone.rotation.x)<0.03,"Basic radio moves forward with a level horizon")
	app.controller.reports[0][1] = 0
	await frames(90)
	check(Vector2(app.drone.linear_velocity.x,app.drone.linear_velocity.z).length()<0.15,"centred radio sticks stop Basic translation")
	var previous_yaw: float = app.drone.rotation.y
	var total_yaw := 0.0
	app.controller.reports[0][2] = 1
	for i in range(60):
		await physics_frame
		var current: float = app.drone.rotation.y
		total_yaw += wrapf(current-previous_yaw,-PI,PI)
		previous_yaw = current
	check(rad_to_deg(total_yaw)< -90,"full right yaw stick turns Basic radio promptly clockwise")
	app.controller.reports[0][2] = 0
	app.set_physics_process(false)
	app.next_gate = 11
	app.section_index = 0
	app.guidance.update_guidance(0)
	check(app.guidance.visible and app.guidance.fits_opening,"guidance activates in Basic and checks body clearance")
	app.drone.call("request_reset",Transform3D(Basis.IDENTITY,app.guidance.target-app.guidance.normal))
	app.guidance.update_guidance(0)
	check(app.guidance.approach_first and (app.guidance.aim_point()-app.guidance.target).dot(app.guidance.normal)>0,"wrong-side approach points back toward valid entry")
	app.drone.call("request_reset",Transform3D(Basis.IDENTITY,app.guidance.target+app.guidance.normal*2))
	app.guidance.update_guidance(0)
	check(not app.guidance.approach_first,"front-side approach aims at opening centre")
	var path: Array = app.guidance.path
	check(path[-1].y>path[0].y+2,"moving guide route follows the upward tunnel")
	var last: Dictionary = app.guidance.sample_path(1000)
	check(last.direction.dot(Vector3.UP)>0.99,"ghost exits the tunnel upward")
	var lap_before: int = app.lap
	var gate_before: int = app.next_gate
	for i in range(120): app.guidance.update_guidance(1.0/30)
	check(app.lap==lap_before and app.next_gate==gate_before,"animated visual guide never completes pilot gates")
	check(app.guidance.find_children("*","CollisionObject3D",true,false).is_empty(),"guide meshes cannot collide with the pilot")
	var route: Array = app.O.sections(app.course.gates[11])
	var tunnel: Node3D = app.gates[11]
	for section in route:
		var axis: Vector3 = section.basis.z*0.1
		app.check_gate(tunnel.to_global(section.center+axis),tunnel.to_global(section.center-axis))
	check(app.next_gate==12 and app.guidance.passed_seconds>1,"actual gate completion triggers clear feedback")
	app.next_gate = 11
	app.section_index = 7
	app.guidance.update_guidance(0)
	var frame: Dictionary = app.guidance.opening(app.course.gates[11],6)
	check(app.guidance.path[0].is_equal_approx(app.gates[11].to_global(frame.center)),"inside-tunnel guide starts from previous valid section")
	app.assessment = true
	app.guidance.update_guidance(0.1)
	check(not app.guidance.visible and app.current_yaw_rate()==app.rates,"assessment hides guidance and retains its original yaw rate")
	app.assessment = false
	var data: Dictionary = app.course.gates[0].duplicate(true)
	app.O.apply_preset(data,"precision")
	data.width = 0.6
	data.opening_height = 0.6
	app.course.gates = [data]
	app.rebuild_course()
	app.next_gate = 0
	app.section_index = 0
	app.select_drone_size(5)
	app.guidance.update_guidance(0)
	check(not app.guidance.fits_opening and not app.guidance.ghost.visible,"impossible opening is flagged rather than falsely guided")
	app.yaw_rate = 225
	app.basic_speed = 1.4
	app.save_settings()
	app.yaw_rate = 90
	app.basic_speed = 3
	app.practice_basic = false
	app.load_settings()
	check(app.yaw_rate==225 and app.basic_speed==1.4 and app.practice_basic,"Basic and independent yaw preferences persist")
	print(("PASS" if failures==0 else "FAIL")+": %d yaw agility, Basic control and guidance checks" % checks)
	app.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
