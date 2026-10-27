extends SceneTree
const O = preload("res://obstacles.gd")
const S = preload("res://drone_sizes.gd")
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
	var original: Dictionary = app.course.duplicate(true)
	check(app.APP_TITLE=="AL JEHAD FPV OBSTACLE COURSE","requested display name is exact")
	check(OS.get_user_data_dir().ends_with("DTC Flight Lab"),"existing calibration/course data directory is retained")
	app.selected = 2
	app.show_module("Course Editor")
	var data: Dictionary = app.course.gates[2]
	app.selected_pole = 1
	app.show_module("Course Editor")
	var pole_row: Node = app.content.get_children().filter(func(c): return c is HBoxContainer and c.get_child_count()==2 and c.get_child(0) is Label and c.get_child(0).text=="Pole X — left/right")[0]
	pole_row.get_child(1).value = 1.5
	check(is_equal_approx(float(data.pole_offsets[1].x),1.5),"pole numeric field edits just selected pole")
	check(is_equal_approx(float(data.pole_offsets[0].x),0),"other pole position is preserved")
	var mesh: MeshInstance3D = app.gates[2].get_node("SlalomPole01")
	check(is_equal_approx(mesh.position.x,1.5),"visible pole moves with edited offset")
	var section: Dictionary = O.sections(data)[1]
	check(is_equal_approx(section.center.x,1.5-float(data.width)*0.35),"passage target follows moved pole")
	check(O.fits(data,section.center,1),"moved pole remains passable on intended side")
	check(not O.fits(data,Vector3(1.5,0,section.center.z),1),"hitting moved pole does not count")
	data.pole_offsets[3].x = -1.5
	data.pole_offsets[3].z = 1.0
	app.rebuild_course()
	check(is_equal_approx(float(O.sections(data)[3].pole.z),-5),"individual pole also moves forward/back")
	app.save_course()
	var restored: Dictionary = app.load_course()
	check(is_equal_approx(float(restored.gates[2].pole_offsets[3].x),-1.5),"individual offsets survive save and load")
	# Top-down pointer input drives the same edit path as the actual editor.
	var map = app.editor_map
	map.size = Vector2(350,280)
	var point3: Vector3 = app.gates[2].to_global(O.sections(data)[1].pole)
	var point: Vector2 = map.project_point(point3.x,point3.z)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = point
	map._gui_input(press)
	check(map.drag_pole==1 and app.selected_pole==1,"map selects an individual pole")
	var move := InputEventMouseMotion.new()
	move.position = point+Vector2(20,0)
	map._gui_input(move)
	check(float(data.pole_offsets[1].x)>1.5,"dragging pole map point moves that pole right")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = move.position
	map._gui_input(release)
	data.yaw_degrees = 45
	data.pitch_degrees = 20
	data.roll_degrees = 15
	app.rebuild_course()
	var wanted: Vector3 = app.gates[2].to_global(Vector3(2,0,-1))
	check(app.set_pole_world_position(1,Vector2(wanted.x,wanted.z)),"pole dragging respects tilted/yawed station transform")
	var actual: Vector3 = app.gates[2].to_global(O.sections(data)[1].pole)
	check(Vector2(actual.x,actual.z).distance_to(Vector2(wanted.x,wanted.z))<0.01,"world map drag resolves correct local pole position")
	app.save_course()
	check(app.valid_course(app.load_course()),"rotations and offsets round trip through course schema")
	var invalid: Dictionary = app.course.duplicate(true)
	invalid.gates[2].pole_offsets[0].x = 9
	check(not app.valid_course(invalid),"out-of-bounds pole offset rejected")
	invalid = app.course.duplicate(true)
	invalid.gates[2].pole_offsets.pop_back()
	check(not app.valid_course(invalid),"wrong pole count rejected on import")
	invalid = app.course.duplicate(true)
	invalid.gates[2].pitch_degrees = 500
	check(not app.valid_course(invalid),"invalid tilt rejected")
	app.course = original.duplicate(true)
	app.rebuild_course()
	app.selected = 0
	app.module = "Fly"
	var gap: float = app.station_gap(1)
	var span: float = app.course.gates[1].width
	check(app.rotate_course(90),"whole course can turn 90 degrees")
	check(is_equal_approx(app.station_gap(1),gap),"course rotation preserves spacing")
	check(is_equal_approx(float(app.course.gates[1].width),span),"course rotation preserves shapes")
	check(is_equal_approx(float(app.course.gates[1].yaw_degrees),90),"gate headings rotate with their positions")
	check(app.rotate_course(360),"whole course accepts full 360-degree turn")
	check(Vector2(app.course.gates[1].x,app.course.gates[1].z).distance_to(Vector2(original.gates[1].x,original.gates[1].z))<0.01,"full turn restores station positions")
	app.rotate_course(0)
	app.course.gates[0].pitch_degrees = 30
	app.course.gates[0].roll_degrees = 45
	app.rebuild_course()
	check(absf(app.gates[0].basis.y.dot(Vector3.UP))<0.9,"individual pitch and roll change actual obstacle orientation")
	app.save_course()
	check(is_equal_approx(float(app.load_course().gates[0].roll_degrees),45),"obstacle orientation persists")
	check(S.LABELS.size()==6,"six requested size categories are available")
	for index in range(S.LABELS.size()):
		app.select_drone_size(index)
		check(is_equal_approx(app.drone_collision.shape.radius,S.SPANS[index]/2),"drone size changes physical collision envelope")
	app.drone_span = 0.72
	app.apply_drone_size()
	app.save_settings()
	app.drone_span = 0.20
	app.load_settings()
	app.apply_drone_size()
	check(is_equal_approx(app.drone_collision.shape.radius,0.36),"measured overall span saves and restores")
	# Check actual gate progression, not only the size dropdown or a geometry helper.
	var gate_data: Dictionary = original.gates[0].duplicate(true)
	O.apply_preset(gate_data,"precision")
	gate_data.width = 0.8
	gate_data.opening_height = 0.8
	app.course.gates = [gate_data]
	app.rebuild_course()
	for size in [0,5]:
		app.select_drone_size(size)
		app.reset_run()
		var gate: Node3D = app.gates[0]
		app.check_gate(gate.to_global(Vector3(0,0,1)),gate.to_global(Vector3(0,0,-1)))
		check(app.lap==2 if size==0 else app.lap==1,"small envelope passes narrow gate; large envelope is rejected")
		# Exercise physics collision on the same narrow opening.
		app.drone.gravity_scale = 0
		app.drone.linear_damp = 0
		app.drone.freeze = false
		app.drone.call("request_reset",Transform3D(Basis.IDENTITY,Vector3(0,2,1.2)),Vector3(0,0,-2))
		for i in range(90): await physics_frame
		check(app.drone.position.z< -0.5 if size==0 else app.drone.position.z>0,"physics agrees: small drone passes, large drone hits the frame")
	print(("PASS" if failures==0 else "FAIL")+": %d pole editing, rotation, persistence and drone-size checks" % checks)
	app.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
