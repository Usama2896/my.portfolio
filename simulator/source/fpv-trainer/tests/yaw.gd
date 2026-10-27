extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.use_radio = false
	scene.assisted = true
	scene.wind = 0
	for scored in [false,true]:
		for code in [KEY_Q,KEY_E,KEY_LEFT,KEY_RIGHT]:
			scene.start_flight(scored)
			scene.throttle = 9.8/30
			await physics_frame
			var position: Vector3 = scene.drone.position
			var previous: float = scene.drone.rotation.y
			var total := 0.0
			key(code,true)
			for i in range(360):
				await physics_frame
				var angle: float = scene.drone.rotation.y
				total += wrapf(angle-previous,-PI,PI)
				previous = angle
			key(code,false)
			print("Yaw test: assessment=",scored," key=",OS.get_keycode_string(code)," turn=",rad_to_deg(total)," deg, displacement=",scene.drone.position.distance_to(position),"m")
			check(total>TAU if code in [KEY_Q,KEY_LEFT] else total< -TAU,"must complete a full turn in correct direction")
			check(scene.drone.position.distance_to(position)<0.35,"yaw must not move the level drone sideways or vertically")
			check(absf(scene.drone.rotation.x)<0.02 and absf(scene.drone.rotation.z)<0.02,"yaw must not bank or pitch")
	print(("PASS" if failures==0 else "FAIL")+": %d yaw checks" % checks)
	scene.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
