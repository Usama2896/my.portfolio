extends SceneTree
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func shot(name_: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/workspace/fpv-review-"+name_+".png")
func run() -> void:
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	root.size = Vector2i(1440,900)
	app.splash_remaining = 0
	if is_instance_valid(app.splash_control): app.splash_control.hide()
	app.selected = 11
	app.show_module("Course Editor")
	var gate: Node3D = app.gates[11]
	app.overview.position = gate.to_global(Vector3(6.5,4.5,4.5))
	app.overview.look_at(gate.to_global(Vector3(0,1,-float(app.course.gates[11].depth)*0.7)))
	await frames(15)
	await shot("u-tunnel-upward")
	app.launch_keyboard()
	app.active = false
	app.drone.freeze = true
	app.next_gate = 11
	app.drone.call("request_reset",Transform3D(gate.basis,gate.to_global(Vector3(0,0,1.3))))
	app.update_gate_labels()
	await frames(8)
	await shot("u-tunnel-entry")
	app.leave_flight()
	app.show_module("Fly")
	app.practice_stabilized = true
	app.show_module("Fly")
	await frames(4)
	await shot("beginner-mode")
	app.show_module("Drone & Controls")
	await frames(4)
	await shot("visibility-settings")
	print("Captured upward U-tunnel, entry and beginner/visibility controls")
	quit()
