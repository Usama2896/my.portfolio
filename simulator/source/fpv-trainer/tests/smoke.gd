extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	assert(scene.gates.size() == 13)
	var gate = scene.gates[0]
	scene.check_gate(gate.to_global(Vector3(3,0,1)),gate.to_global(Vector3(3,0,-1)))
	assert(scene.next_gate == 0, "Outside gate must not count")
	scene.check_gate(gate.to_global(Vector3(0,0,-1)),gate.to_global(Vector3(0,0,1)))
	assert(scene.next_gate == 0, "Reverse entry must not count")
	for lap in range(3):
		for index in range(13):
			gate = scene.gates[index]
			scene.check_gate(gate.to_global(Vector3(0,0,1)),gate.to_global(Vector3(0,0,-1)))
	assert(scene.finished, "Three complete laps must finish")
	assert(scene.lap == 3)
	scene.reset_run()
	assert(not scene.finished and scene.next_gate == 0 and scene.crashes == 0)
	print("PASS: 13 gates, rejected outside/reverse passes, three laps, completion and reset")
	quit()
