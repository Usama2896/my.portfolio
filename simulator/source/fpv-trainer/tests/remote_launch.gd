extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func run() -> void:
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	app.set_physics_process(false)
	var radio = load("res://tests/fake_controller.gd").new()
	app.controller = radio
	app.poll_radio()
	check(app.joystick==0,"radio detected through production adapter interface")
	check(app.remote_blocker().is_empty(),"calm sticks and low throttle are ready")
	app.use_radio = true
	check(app.launch_keyboard(),"keyboard button launches even with radio setting on")
	check(not app.use_radio and app.active and not app.drone.freeze,"keyboard source is chosen explicitly")
	app.leave_flight()
	app.show_module("Fly")
	var launch_buttons: Array = app.content.get_children().filter(func(c): return c is Button and c.text.begins_with("Fly with"))
	check(launch_buttons.size()==2,"exactly two clearly labelled flight input buttons")
	app.use_radio = true
	launch_buttons[0].pressed.emit()
	check(app.active and not app.use_radio,"real keyboard button signal overrides saved USB mode")
	app.leave_flight()
	app.use_radio = false
	launch_buttons[1].pressed.emit()
	check(app.active and app.use_radio,"real remote button signal selects radio and launches")
	app.leave_flight()
	app.use_radio = false
	check(app.launch_remote(),"remote button launches despite previous keyboard setting")
	check(app.use_radio and app.active and not app.drone.freeze,"remote launch unfreezes drone")
	app.leave_flight()
	radio.reports[0][3] = -1.0
	check(not app.launch_remote(),"high throttle blocks launch")
	check(is_instance_valid(app.launch_dialog) and app.launch_dialog.visible,"blocker opens visible setup dialog")
	check(app.remote_readout.text.contains("100%") and app.remote_readout.text.contains("Throttle"),"blocker shows live throttle and explanation")
	app.inversions[3] = false
	check(app.launch_remote(),"correcting inversion allows launch without restarting app")
	app.inversions[3] = true
	radio.reports[0][3] = 1.0
	app.leave_flight()
	app.begin_calibration(2)
	radio.reports[0][5] = 0.95
	app._physics_process(0)
	radio.reports[0][5] = -0.95
	app._physics_process(0)
	radio.reports[0][5] = 0.0
	check(not app.launch_remote() and app.remote_blocker().contains("unfinished"),"unfinished calibration explains blocked launch")
	app.finish_calibration()
	check(app.axes[2]==5 and app.calibrating==-1,"USB report calibration assigns yaw channel")
	check(app.endpoints[2].x< -0.9 and app.endpoints[2].y>0.9,"calibration records both endpoints")
	check(app.launch_remote(),"completed calibration allows flight")
	app.leave_flight()
	app.begin_calibration(0)
	radio.reports[0][4] = 0.95
	app._physics_process(0)
	check(app.axes[0]==4,"in-progress mapping is staged")
	app.cancel_calibration()
	check(app.axes[0]==0,"cancel restores previous mapping")
	radio.reports[0][4] = 0
	app.begin_calibration(3)
	radio.reports[0][6] = -0.95
	app._physics_process(0)
	radio.reports[0][6] = 0.95
	app._physics_process(0)
	radio.reports[0][6] = 0
	app.finish_calibration()
	check(app.calibrating==3,"throttle confirmation requires endpoint, not middle")
	radio.reports[0][6] = -0.95
	app.finish_calibration()
	check(app.axes[3]==6 and not app.inversions[3] and app.radio_axis(3)< -0.99,"throttle down endpoint detects polarity automatically")
	app.axes[1] = app.axes[0]
	check(not app.launch_remote() and app.remote_blocker().contains("both use axis"),"duplicate channel mapping is diagnosed")
	app.axes[1] = 1
	check(app.launch_remote(),"corrected channel mapping launches")
	radio.connected.clear()
	app._physics_process(0)
	check(not app.active and app.drone.freeze,"disconnect freezes remote flight")
	check(not app.launch_remote() and app.remote_blocker().contains("No selected USB"),"missing remote has explicit blocker")
	check(app.launch_keyboard(),"keyboard works with remote unplugged")
	app.leave_flight()
	radio.connected.assign([0,1])
	app.preferred_radio_guid = radio.device_guid(1)
	app.preferred_radio_name = radio.device_name(1)
	app.poll_radio()
	check(app.joystick==1,"explicit second radio selected instead of first device")
	check(app.launch_remote(),"second selected radio can fly")
	app.save_settings()
	app.preferred_radio_name = ""
	app.load_settings()
	check(app.preferred_radio_name==radio.device_name(1),"selected device persists")
	app.leave_flight()
	# Run the actual physics path with injected USB reports, not just its launch flag.
	radio.reports[1][3] = 1.0
	app.launch_remote()
	app.set_physics_process(true)
	var initial_y: float = app.drone.position.y
	radio.reports[1][3] = -0.2 # normalised throttle +0.2 => 60% power
	for i in range(90): await physics_frame
	check(app.drone.position.y>initial_y+1,"mapped USB throttle produces lift through real flight physics")
	app.leave_flight()
	app.show_module("Drone & Controls")
	check(app.content.get_children().filter(func(c): return c is CheckButton and c.text.contains("Use USB controller")).is_empty(),"obsolete USB-enable switch is removed")
	app.show_splash()
	check(is_instance_valid(app.splash_control) and app.splash_remaining==2.0,"two-second splash exists")
	check(not app.launch_keyboard(),"splash blocks launch until finished")
	app.set_process(false)
	app.update_splash(1.9)
	check(app.splash_remaining>0,"splash remains before two seconds")
	app.update_splash(0.2)
	check(app.splash_remaining==0,"splash finishes after two seconds")
	print(("PASS" if failures==0 else "FAIL")+": %d remote-launch, calibration, physics and splash checks (injected USB reports; physical radio not tested)" % checks)
	app.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
