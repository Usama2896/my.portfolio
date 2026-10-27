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
	app.select_flight_mode(3)
	await frames(4)
	await shot("basic-selection")
	app.launch_keyboard()
	await frames(35)
	await shot("basic-guide-flight")
	app.active = false
	app.drone.freeze = true
	app.next_gate = 11
	app.section_index = 3
	var gate: Node3D = app.gates[11]
	var pose: Dictionary = app.guidance.opening(app.course.gates[11],2)
	app.drone.call("request_reset",Transform3D(gate.basis,gate.to_global(pose.center+Vector3(0,0,0.2))))
	app.guidance.cache_key = ""
	await frames(20)
	await shot("basic-tunnel-guide")
	app.leave_flight()
	app.show_module("Drone & Controls")
	await frames(4)
	# Scroll to the independent turning and slow-translation settings.
	var scroll: ScrollContainer = app.menu.get_child(0)
	scroll.scroll_vertical = 330
	await frames(4)
	await shot("yaw-settings")
	print("Captured Basic selection, aim/ghost route, upward-tunnel guidance and yaw settings")
	quit()
