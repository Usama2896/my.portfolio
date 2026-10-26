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
	await frames(5)
	await shot("pro-landscape")
	app.select_flight_mode(3)
	await frames(5)
	app.launch_keyboard()
	await frames(30)
	await shot("pro-ground-route")
	app.active = false
	app.drone.freeze = true
	var pose: Transform3D = app.drone.transform
	pose.basis = Basis.from_euler(Vector3(0.05,0,0.25))
	app.drone.request_reset(pose)
	app.practice_basic = false
	await frames(10)
	await shot("pro-attitude")
	app.weather = 4
	app.experience.apply_weather()
	await frames(10)
	await shot("pro-storm")
	app.leave_flight()
	quit()
