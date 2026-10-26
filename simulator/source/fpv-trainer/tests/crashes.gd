extends SceneTree
const O = preload("res://obstacles.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func run() -> void:
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	app.use_radio = false
	app.assisted = false
	app.practice_god_mode = false
	app.launch_keyboard()
	# Complete two gates; the third obstacle must remain the recovery checkpoint.
	for index in range(2):
		var gate: Node3D = app.gates[index]
		app.check_gate(gate.to_global(Vector3(0,0,1)),gate.to_global(Vector3(0,0,-1)))
	check(app.next_gate==2,"two gates completed before collision")
	var target: Node3D = app.gates[2]
	app.drone.call("request_reset",Transform3D(target.basis,target.to_global(Vector3(0,0,3))),-target.basis.z*6)
	app.previous_position = app.drone.position
	app.throttle = 9.8/30
	app.contact_cooldown = 0
	var hit := false
	for i in range(90):
		await physics_frame
		if not app.crash_phase.is_empty(): hit = true; break
	check(hit,"real physics collision starts crash state")
	check(app.crashes==1,"real collision records one crash")
	check(app.throttle==0,"hard impact cuts motor command")
	check(app.drone.linear_velocity.dot(target.basis.z)>0,"body bounces back from obstacle")
	await frames(6)
	check(app.drone.angular_velocity.length()>0.1,"body tumbles instead of immediately self-correcting")
	check(app.impact_flash>0 and app.camera.position.length()>0,"impact has screen flash and camera shake")
	check(app.next_gate==2,"crash does not erase prior gates")
	app.assisted = true
	await frames(90)
	check(app.crash_phase.is_empty() and app.active,"crash recovers automatically")
	check(app.next_gate==2 and app.lap==1 and app.section_index==0,"recovery restarts current obstacle, not the entire course")
	check(app.drone.position.distance_to(target.to_global(Vector3(0.84,0,3.15)))<1,"recovery is near the current station entry")
	# Contact normals are already in world coordinates. Check a yawed drone too.
	app.leave_flight()
	app.course.gates[0].yaw_degrees = 90
	app.rebuild_course()
	app.assisted = false
	app.launch_keyboard()
	var rotated: Node3D = app.gates[0]
	app.drone.call("request_reset",Transform3D(rotated.basis,rotated.to_global(Vector3(1.2,0,3))),-rotated.basis.z*6)
	app.previous_position = app.drone.position
	app.throttle = 9.8/30
	app.contact_cooldown = 0
	var normals: Array[Vector3] = []
	app.drone.connect("impact",func(_s,n): normals.append(n))
	for i in range(90):
		await physics_frame
		if not normals.is_empty(): break
	check(not normals.is_empty() and normals[0].dot(rotated.basis.z)>0.95,"yawed collision has correct world-space bounce normal")
	app.leave_flight()
	app.course.gates[0].yaw_degrees = 0
	app.rebuild_course()
	# God Mode keeps physical collision, but does not enter crash or reset.
	app.leave_flight()
	app.practice_god_mode = true
	app.assisted = false
	app.launch_keyboard()
	app.drone.call("request_reset",Transform3D(Basis.IDENTITY,Vector3(1.2,2,3)),Vector3(0,0,-6))
	app.previous_position = app.drone.position
	app.throttle = 9.8/30
	app.contact_cooldown = 0
	await frames(60)
	check(app.contacts>0,"God Mode still has physical obstacle contact")
	check(app.crashes==0 and app.crash_phase.is_empty() and app.active,"God Mode never applies crash/reset")
	# Glancing/light bumps give feedback without a hard-crash penalty.
	app.practice_god_mode = false
	app.contact_cooldown = 0
	app.on_impact(1.5,Vector3.BACK)
	check(app.crashes==0 and app.crash_phase.is_empty(),"light touch is not classified as hard crash")
	check(app.shake_strength>0,"light touch still has feedback")
	# Assessment cannot use God Mode to bypass penalties.
	app.start_flight(true)
	app.contact_cooldown = 0
	app.practice_god_mode = true
	app.on_impact(6,Vector3.BACK)
	check(app.crashes==1 and not app.crash_phase.is_empty(),"assessment enforces crash even when God preference is saved")
	app.update_crash_state(1.2)
	app.contact_cooldown = 0
	app.on_impact(6,Vector3.BACK)
	check(not app.finished and app.crash_terminal.contains("second crash"),"second assessment crash shows impact before ending")
	app.update_crash_state(1.2)
	check(app.finished and app.crashes==2,"second assessment crash disqualifies after tumble")
	# Checkpoint respawn on a remote waits for low throttle again.
	app.leave_flight()
	app.controller = load("res://tests/fake_controller.gd").new()
	app.preferred_radio_guid = ""
	app.preferred_radio_name = ""
	app.poll_radio()
	app.launch_assessment = false
	app.practice_god_mode = false
	app.launch_remote()
	app.update_remote_arming(0.25)
	app.next_gate = 2
	app.contact_cooldown = 0
	app.on_impact(6,Vector3.BACK)
	app.update_crash_state(1.2)
	check(app.next_gate==2 and app.remote_waiting_low and app.drone.freeze,"remote checkpoint respawn remains disarmed")
	app.controller.reports[0][3] = -1
	app.started = true
	app.elapsed = 10
	app._physics_process(0.5)
	check(app.elapsed>10,"course clock continues during checkpoint re-arming")
	app.update_remote_arming(1)
	check(not app.active,"high throttle cannot cause immediate post-crash takeoff")
	app.controller.reports[0][3] = 1
	app.update_remote_arming(0.25)
	check(app.active,"low throttle re-arms after checkpoint recovery")
	app.practice_god_mode = true
	app.save_settings()
	app.practice_god_mode = false
	app.load_settings()
	check(app.practice_god_mode,"God Mode preference persists")
	print(("PASS" if failures==0 else "FAIL")+": %d physical impact, God Mode, checkpoint and assessment checks" % checks)
	app.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
