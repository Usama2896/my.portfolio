extends SceneTree
const O = preload("res://obstacles.gd")
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
	var data: Dictionary = app.course.gates[11].duplicate(true)
	check(data.type=="u_tunnel","existing U-tunnel identifier is retained")
	app.course.gates = [data]
	app.rebuild_course()
	var frames := O.sections(data)
	check(frames.size()==10,"horizontal inlet, elbow and upward neck have ordered checkpoints")
	check(frames[0].basis.is_equal_approx(Basis.IDENTITY),"entry is horizontal forward")
	check(frames[-1].center.y>float(data.opening_height),"exit rises above the inlet")
	check(frames[-1].basis.z.dot(Vector3.DOWN)>0.99,"exit crossing plane accepts upward flight")
	var gate: Node3D = app.gates[0]
	check(gate.has_node("UpwardNetShell"),"visible net shell is constructed")
	check(gate.get_node("UpwardNetShell").get_children().size()>0,"net walls have physical collision")
	for i in range(frames.size()):
		check(O.fits(data,frames[i].center,i),"centre of each oriented section is clear")
		check(not O.fits(data,frames[i].center+frames[i].basis.x*5,i),"outside of each section is rejected")
	app.reset_run()
	for i in range(frames.size()-1):
		var offset: Vector3 = frames[i].basis.z*0.1
		app.check_gate(gate.to_global(frames[i].center+offset),gate.to_global(frames[i].center-offset))
	check(app.lap==1 and app.section_index==frames.size()-1,"horizontal traversal alone does not complete the upward exit")
	var exit: Vector3 = frames[-1].center
	app.check_gate(gate.to_global(exit+Vector3(0,0,0.2)),gate.to_global(exit-Vector3(0,0,0.2)))
	check(app.lap==1,"continuing horizontally cannot complete top exit")
	app.check_gate(gate.to_global(exit+Vector3.UP*0.2),gate.to_global(exit-Vector3.UP*0.2))
	check(app.lap==1,"descending through exit is rejected")
	app.check_gate(gate.to_global(exit-Vector3.UP*0.2),gate.to_global(exit+Vector3.UP*0.2))
	check(app.lap==2,"ascending through top completes the obstacle")
	# Whole-station transforms must preserve the curved section frames.
	data.yaw_degrees = 60
	data.pitch_degrees = 10
	data.roll_degrees = 15
	app.rebuild_course()
	app.reset_run()
	gate = app.gates[0]
	for frame in frames:
		var offset: Vector3 = frame.basis.z*0.1
		app.check_gate(gate.to_global(frame.center+offset),gate.to_global(frame.center-offset))
	check(app.lap==2,"full traversal works after yaw/pitch/roll transforms")
	app.save_course()
	check(app.valid_course(app.load_course()),"existing course schema round-trips without migration")
	# Cast across the side wall and through the two open ends.
	var space: PhysicsDirectSpaceState3D = app.get_world_3d().direct_space_state
	var side_a: Vector3 = gate.to_global(Vector3(0,0,-float(data.depth)*0.5))
	var side_b: Vector3 = gate.to_global(Vector3(float(data.width),0,-float(data.depth)*0.5))
	await physics_frame
	var side: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(side_a,side_b))
	check(not side.is_empty(),"side net physically blocks an escape through the wall")
	for i in range(frames.size()-1):
		var path: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(gate.to_global(frames[i].center),gate.to_global(frames[i+1].center)))
		check(path.is_empty(),"centre path is not blocked between adjoining tunnel sections")
	var entrance: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(gate.to_global(Vector3(0,0,0.3)),gate.to_global(Vector3(0,0,-0.3))))
	check(entrance.is_empty(),"entry opening is not capped by fabric")
	var top: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(gate.to_global(exit-Vector3.UP*0.3),gate.to_global(exit+Vector3.UP*0.3)))
	check(top.is_empty(),"top exit is not capped by fabric")
	check(app.gate_labels[0].size()>=3,"procedural entry/exit labels are included in visibility controls")
	app.in_flight = true
	app.show_all_labels = false
	app.update_gate_labels()
	check(app.gate_labels[0][0].visible,"current target label remains visible")
	app.queue_free()
	await process_frame
	print(("PASS" if failures==0 else "FAIL")+": %d upward-tunnel geometry, direction, collision and compatibility checks" % checks)
	quit(0 if failures==0 else 1)
