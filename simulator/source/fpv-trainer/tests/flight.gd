extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	if not ok: failures += 1; push_error(text)
func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.use_radio = false
	scene.assisted = true
	scene.wind = 0
	scene.start_flight(false)
	var initial: float = scene.drone.position.y
	await frames(120)
	check(absf(scene.drone.position.y-initial)<0.25,"assisted hover should hold altitude")
	key(KEY_UP,true)
	await frames(90)
	key(KEY_UP,false)
	check(scene.drone.position.y>initial+2,"up arrow should climb")
	await frames(90)
	var stopped: float = scene.drone.position.y
	await frames(60)
	check(absf(scene.drone.position.y-stopped)<0.3,"releasing climb should settle")
	var z: float = scene.drone.position.z
	key(KEY_W,true)
	await frames(60)
	key(KEY_W,false)
	print("Forward displacement: ",scene.drone.position.z-z," m; pitch: ",scene.drone.rotation.x)
	check(scene.drone.position.z<z-0.5,"W should move forward at least half a metre in one second")
	await frames(90)
	check(absf(scene.drone.rotation.x)<0.08,"practice should auto-level after releasing W")
	scene.active = false
	scene.drone.freeze = true
	await frames(2)
	var position: Vector3 = scene.drone.position
	await frames(30)
	check(scene.drone.position.distance_to(position)<0.01,"pause should freeze flight")
	print(("PASS" if failures==0 else "FAIL")+": 6 physical keyboard-flight checks — hover, climb, settle, forward flight, auto-level and pause")
	scene.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
