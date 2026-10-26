extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(name_: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/workspace/fpv-review-"+name_+".png")
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func run() -> void:
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	root.size = Vector2i(1440,900)
	app.splash_remaining = 0
	if is_instance_valid(app.splash_control): app.splash_control.hide()
	app.controller = load("res://tests/fake_controller.gd").new()
	app.poll_radio()
	app.controller.reports[0][3] = -1
	app.launch_remote()
	await frames(20)
	await capture("remote-arming")
	app.controller.reports[0][3] = 1
	await frames(25)
	await capture("remote-armed")
	app.leave_flight()
	app.assisted = false
	app.practice_god_mode = false
	app.launch_keyboard()
	for i in range(2):
		var gate: Node3D = app.gates[i]
		app.check_gate(gate.to_global(Vector3(0,0,1)),gate.to_global(Vector3(0,0,-1)))
	var target: Node3D = app.gates[2]
	app.drone.call("request_reset",Transform3D(target.basis,target.to_global(Vector3(0,0,3))),-target.basis.z*6)
	app.previous_position = app.drone.position
	app.throttle = 9.8/30
	app.contact_cooldown = 0
	for i in range(90):
		await physics_frame
		if not app.crash_phase.is_empty(): break
	assert(not app.crash_phase.is_empty(),"Rendered collision must produce a crash before capture")
	await frames(8)
	await capture("crash-impact")
	app.assisted = true
	await frames(90)
	await capture("checkpoint")
	app.leave_flight()
	app.practice_god_mode = true
	app.show_module("Fly")
	await frames(3)
	await capture("god-mode")
	app.launch_keyboard()
	app.drone.call("request_reset",Transform3D(Basis.IDENTITY,Vector3(1.2,2,3)),Vector3(0,0,-6))
	app.previous_position = app.drone.position
	app.assisted = false
	app.throttle = 9.8/30
	app.contact_cooldown = 0
	for i in range(90):
		await physics_frame
		if app.contacts>0: break
	await capture("god-contact")
	print("Captured actual arming, crash, checkpoint and God Mode views")
	quit()
