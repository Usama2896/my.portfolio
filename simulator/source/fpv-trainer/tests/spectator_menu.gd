extends SceneTree
var checks := 0
func check(value: bool, title: String) -> void:
	if not value: push_error(title); quit(1); return
	checks += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var license_ = load("res://activation.gd").new()
	license_.activate(load("res://owner_settings.gd").ACTIVATION_KEY)
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	app.set_physics_process(false)
	app.splash_remaining = 0
	var lan = app.lan
	lan.set_physics_process(false)
	lan.port = 26358
	lan.host_room()
	lan.prepare_local(false)
	for id in [2,3]: lan.rules.add_player(id,"Pilot "+str(id),0.3)
	lan.rules.players[2].position = Vector3(-10,2,-20)
	lan.rules.players[3].position = Vector3(-20,3,-30)
	lan.rules.players[1].result = "Finished"
	lan.rules.phase = "running"
	lan.rules.leg = 1
	lan.refresh_board()
	lan.apply_local_state()
	lan.update_spectator()
	check(lan.watched_peer==2 and root.get_camera_3d()==lan.spectator,"finished pilot automatically watches next pilot")
	check(lan.spectator.position.is_equal_approx(Vector3(-10,2.025,-20)),"read-only camera reconstructs remote pose")
	check(not app.centre_panel.visible,"finished-pilot message does not obstruct the spectator view")
	check(not lan.ghosts[2].visible,"watched drone does not block its own FPV view")
	lan.rules.leg = 2
	lan.update_spectator()
	check(lan.watched_peer==3,"automatic view follows final relay handoff")
	lan.spectated_slot = -2
	lan.update_spectator()
	check(root.get_camera_3d()==app.camera,"Mine returns to local camera")
	lan.spectated_slot = 1
	lan.update_spectator()
	check(lan.watched_peer==2,"manual P2 camera selection works")
	lan.rules.leg = 0
	lan.rules.players[1].result = "Flying"
	app.finished = false
	lan.apply_local_state()
	lan.update_spectator()
	check(root.get_camera_3d()==app.camera and app.active,"own turn always takes camera/control priority")
	var previous: Vector3 = lan.rules.players[2].position
	app.open_escape_menu()
	check(app.pause_open(),"Escape menu opens in LAN")
	check(not app.pause_dialog.find_children("*","Button",true,false).filter(func(b): return b.text=="Exit application ×").is_empty(),"visible exit button exists")
	var menu_key := InputEventKey.new()
	menu_key.physical_keycode = KEY_UP
	menu_key.pressed = true
	Input.parse_input_event(menu_key.duplicate())
	check(app.key_axis(KEY_UP,KEY_DOWN)==0,"menu navigation does not drive keyboard flight")
	lan.rules.leg = 1
	lan.rules.players[1].result = "Waiting"
	var before: float = lan.rules.elapsed
	lan._physics_process(0.25)
	check(lan.connected and lan.rules.elapsed>before,"Escape menu does not disconnect or pause shared clock")
	check(lan.rules.phase=="running","menu navigation cannot cause a keyboard false start")
	menu_key.pressed = false
	Input.parse_input_event(menu_key.duplicate())
	check(lan.rules.players[2].position==previous,"spectating does not alter another player's controls")
	app.resume_from_menu()
	check(lan.connected,"Resume preserves LAN room")
	check(ProjectSettings.get_setting("display/window/stretch/aspect")=="expand","layout expands on wide displays")
	lan.disconnect_room()
	print("PASS: ",checks," spectator, camera priority, Escape menu and widescreen checks")
	quit()
