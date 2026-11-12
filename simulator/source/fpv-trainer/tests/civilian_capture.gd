extends SceneTree
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func shot(title: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/workspace/fpv-review-"+title+".png")
func run() -> void:
	load("res://activation.gd").new().activate(load("res://owner_settings.gd").ACTIVATION_KEY)
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(1600,900)
	app.splash_remaining = 0
	if is_instance_valid(app.splash_control): app.splash_control.hide()
	app.show_module("Civilian Missions")
	await frames(4)
	assert(root.get_visible_rect().size.x/root.get_visible_rect().size.y>1.7)
	await shot("civilian-menu")
	app.missions.start(false)
	app.drone.request_reset(Transform3D(Basis.IDENTITY,Vector3(0,2,-15)))
	await frames(5)
	await shot("civilian-flight")
	app.open_escape_menu()
	await frames(4)
	await shot("escape-menu")
	app.resume_from_menu()
	app.missions.stop()
	app.show_module("LAN Competition")
	app.lan.port = 26359
	app.lan.host_room()
	app.lan.prepare_local(false)
	for id in [2,3]:
		app.lan.rules.add_player(id,"Pilot "+str(id),0.3)
		app.lan.rules.players[id].ready = true
	app.lan.rules.phase = "running"
	app.lan.rules.leg = 1
	app.lan.rules.players[1].result = "Finished"
	app.lan.rules.players[2].result = "Flying"
	app.lan.rules.players[2].position = Vector3(-50,2,-5)
	await frames(5)
	await shot("spectator-p2")
	app.lan.disconnect_room()
	print("Captured civilian menu/flight, Escape exit menu and read-only P2 view at 16:9")
	quit()
