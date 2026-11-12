extends SceneTree
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func shot(title: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/workspace/fpv-review-"+title+".png")
func run() -> void:
	var license_ = load("res://activation.gd").new()
	license_.activate(load("res://owner_settings.gd").ACTIVATION_KEY)
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(1440,900)
	app.splash_remaining = 0
	if is_instance_valid(app.splash_control): app.splash_control.hide()
	app.show_module("LAN Competition")
	await frames(5)
	await shot("lan-lobby")
	app.lan.port = 25433
	app.lan.host_room()
	await frames(5)
	await shot("lan-mountain")
	app.lan.prepare_local(false)
	app.lan.rules.add_player(2,"Pilot 2",0.3)
	app.lan.rules.add_player(3,"Pilot 3",0.3)
	for id in [1,2,3]: app.lan.rules.players[id].ready = true
	app.lan.request_start()
	await frames(15)
	await shot("lan-relay-flight")
	app.lan.disconnect_room()
	app.lan.options.terrain = 1
	app.lan.host_room()
	await frames(5)
	await shot("lan-desert")
	app.lan.disconnect_room()
	app.lan.options.terrain = 2
	app.lan.host_room()
	await frames(5)
	await shot("lan-city")
	app.lan.disconnect_room()
	quit()
