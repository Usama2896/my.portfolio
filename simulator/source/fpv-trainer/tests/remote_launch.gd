extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func arm(app) -> void: app.update_remote_arming(0.25)
func run() -> void:
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	app.splash_remaining = 0
	if is_instance_valid(app.splash_control): app.splash_control.hide()
	app.set_physics_process(false)
	var radio = load("res://tests/fake_controller.gd").new()
	app.controller = radio
	app.poll_radio()
	check(app.joystick==0,"radio detected")
	app.use_radio = true
	check(app.launch_keyboard() and not app.use_radio and app.active,"keyboard overrides old USB setting")
	app.leave_flight()
	app.show_module("Fly")
	var buttons: Array = app.content.get_children().filter(func(c): return c is Button and c.text.begins_with("Fly with"))
	check(buttons.size()==2,"two explicit launch buttons")
	buttons[1].pressed.emit()
	check(app.in_flight and app.remote_waiting_low and app.drone.freeze,"remote button opens view with motors disarmed")
	app.update_remote_arming(0.1)
	check(not app.active,"requires stable low throttle, not one sample")
	app.update_remote_arming(0.11)
	check(app.active and not app.drone.freeze,"low throttle arms after stability interval")
	app.leave_flight()
	radio.reports[0][3] = -1
	check(app.launch_remote(),"high throttle still opens the flight view")
	app.update_remote_arming(1)
	app.update_flight_centre()
	check(app.remote_waiting_low and not app.active and app.drone.freeze,"high throttle never powers motors")
	check(app.centre_panel.visible and app.centre_label.text.contains("100%"),"live arming instruction is visible in flight")
	app.inversions[3] = false
	arm(app)
	check(app.active and not app.remote_waiting_low,"inversion correction arms without another menu round trip")
	app.leave_flight()
	app.inversions[3] = true
	radio.reports[0][3] = 1
	# Reproduce the exact popup Start button through GUI mouse input.
	app.axes[1] = 0
	check(not app.launch_remote() and app.launch_dialog.visible,"invalid mapping opens setup window")
	app.axes[1] = 1
	app.update_launch_readout()
	await process_frame
	await process_frame
	check(not app.launch_dialog.get_ok_button().disabled,"setup Start enabled after mapping is corrected")
	app.launch_dialog.get_ok_button().pressed.emit()
	await process_frame
	await process_frame
	check(app.in_flight and app.remote_waiting_low and not app.launch_dialog.visible,"popup Start button handler opens remote flight")
	arm(app)
	app.leave_flight()
	app.begin_calibration(2)
	radio.reports[0][5] = 0.95
	app._physics_process(0)
	radio.reports[0][5] = -0.95
	app._physics_process(0)
	radio.reports[0][5] = 0
	check(not app.launch_remote() and app.remote_configuration_issue().contains("unfinished"),"unfinished mapping is diagnosed")
	app.finish_calibration()
	check(app.axes[2]==5 and app.calibrating==-1,"calibration uses actual input reports")
	check(app.launch_remote(),"confirmed mapping opens remote flight")
	arm(app)
	app.leave_flight()
	app.begin_calibration(0)
	radio.reports[0][4] = 0.95
	app._physics_process(0)
	app.cancel_calibration()
	check(app.axes[0]==0,"cancel restores confirmed mapping")
	radio.reports[0][4] = 0
	app.begin_calibration(3)
	radio.reports[0][6] = -0.95
	app._physics_process(0)
	radio.reports[0][6] = 0.95
	app._physics_process(0)
	radio.reports[0][6] = 0
	app.finish_calibration()
	check(app.calibrating==3,"midpoint is not accepted as throttle down")
	radio.reports[0][6] = -0.95
	app.finish_calibration()
	check(app.axes[3]==6 and not app.inversions[3] and app.radio_axis(3)< -0.99,"throttle polarity follows confirmed low end")
	app.launch_remote()
	arm(app)
	radio.connected.clear()
	app._physics_process(0)
	check(not app.active and app.drone.freeze,"disconnect freezes remote flight")
	check(not app.launch_remote(),"disconnected remote is clearly blocked")
	check(app.launch_keyboard(),"keyboard works with radio unplugged")
	app.leave_flight()
	radio.connected.assign([0,1])
	app.preferred_radio_guid = radio.device_guid(1)
	app.preferred_radio_name = radio.device_name(1)
	app.poll_radio()
	check(app.joystick==1,"selected second device is used")
	app.launch_remote()
	arm(app)
	app.set_physics_process(true)
	var initial_y: float = app.drone.position.y
	radio.reports[1][3] = -0.2
	for i in range(90): await physics_frame
	check(app.drone.position.y>initial_y+1,"mapped remote throttle generates real physics lift")
	check(app.remote_report().contains("axis=") and app.remote_report().contains("v0.5"),"diagnostic report contains launch and axis data")
	app.leave_flight()
	app.show_module("Drone & Controls")
	check(app.content.get_children().filter(func(c): return c is CheckButton and c.text.contains("Use USB controller")).is_empty(),"no obsolete USB-enable switch")
	app.show_splash()
	check(app.splash_remaining==2 and not app.launch_keyboard(),"two-second splash blocks early launch")
	app.set_process(false)
	app.update_splash(1.9)
	check(app.splash_remaining>0,"splash remains before two seconds")
	app.update_splash(0.2)
	check(app.splash_remaining==0,"splash finishes on time")
	print(("PASS" if failures==0 else "FAIL")+": %d remote launch/popup/arming/calibration/physics checks (injected USB reports)" % checks)
	app.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
