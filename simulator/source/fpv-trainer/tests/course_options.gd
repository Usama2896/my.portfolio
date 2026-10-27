extends SceneTree
const O = preload("res://obstacles.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	var original: Dictionary = scene.course.duplicate(true)
	check(O.TYPES.size()==17 and O.NAMES.size()==17,"17 named obstacle choices")
	for kind in O.TYPES:
		var data: Dictionary = original.gates[0].duplicate(true)
		O.apply_preset(data,kind)
		scene.course.gates = [data]
		scene.rebuild_course()
		check(scene.valid_course(scene.course),kind+" preset is valid")
		var sections := O.sections(data)
		for section in range(sections.size()):
			var center: Vector3 = sections[section].center
			for hole in O.holes(data):
				check(O.fits(data,center+Vector3(hole.x,hole.y,0),section),kind+" target opening is passable")
		if kind=="zigzag":
			var poles: Array = scene.gates[0].get_children().filter(func(c): return c is MeshInstance3D and c.name.begins_with("SlalomPole"))
			check(poles.size()==5,"zigzag contains five visible poles")
			for pole in poles:
				check(pole.mesh is BoxMesh and pole.mesh.size.x<0.15 and pole.mesh.size.z<0.15 and pole.mesh.size.y>2,"zigzag meshes are upright poles, not frames")
			check(scene.gates[0].get_children().filter(func(c): return c is Node3D and c.get_child_count()>0).size()==10,"zigzag has only pole/base collision bodies, no frame segments")
			check(not O.fits(data,Vector3(0,0,0),0),"flying straight at pole does not count")
			check(sections[0].center.x*sections[1].center.x<0,"slalom targets alternate sides")
		if kind=="dive":
			scene.reset_run()
			var gate: Node3D = scene.gates[0]
			check(gate.basis.z.dot(Vector3.UP)>0.99,"dive entry normal points up")
			scene.check_gate(gate.to_global(Vector3(0,0,1)),gate.to_global(Vector3(0,0,-1)))
			check(scene.lap==2,"descending through dive ring advances lap")
			check(absf(scene.drone.basis.y.dot(Vector3.UP)-1)<0.01,"spawn remains level when first station is a dive")
	scene.course = original.duplicate(true)
	scene.rebuild_course()
	scene.selected = 1
	scene.module = "Fly"
	var width: float = scene.course.gates[1].width
	var old_gap: float = scene.station_gap(1)
	var later_gap: float = scene.station_gap(2)
	check(scene.set_station_gap(old_gap*2),"increase station gap")
	check(is_equal_approx(scene.station_gap(1),old_gap*2),"requested gap is exact")
	check(is_equal_approx(scene.station_gap(2),later_gap),"following gap preserved when moving later route")
	check(is_equal_approx(float(scene.course.gates[1].width),width),"spacing does not resize obstacle")
	check(scene.set_station_gap(old_gap),"decrease station gap")
	check(is_equal_approx(scene.station_gap(1),old_gap),"reduced gap is exact")
	scene.move_following = false
	var following := Vector2(scene.course.gates[2].x,scene.course.gates[2].z)
	check(scene.set_station_gap(old_gap*1.5),"single-station spacing")
	check(Vector2(scene.course.gates[2].x,scene.course.gates[2].z).is_equal_approx(following),"single-station change leaves later station fixed")
	scene.course = original.duplicate(true)
	scene.rebuild_course()
	check(scene.scale_spacing(2),"scale entire layout up")
	for i in range(1,original.gates.size()):
		var a: Dictionary = original.gates[i-1]
		var b: Dictionary = original.gates[i]
		var gap := Vector2(b.x-a.x,b.z-a.z).length()
		check(is_equal_approx(scene.station_gap(i),gap*2),"every route gap doubles")
	check(scene.scale_spacing(1),"scale layout back down")
	check(is_equal_approx(scene.station_gap(1),old_gap),"spacing scale round trip restores gap")
	scene.selected = 1
	scene.move_following = true
	scene.set_station_gap(10)
	scene.save_course()
	check(scene.valid_course(scene.load_course()) and is_equal_approx(float(scene.load_course().gates[1].z),float(scene.course.gates[1].z)),"new gaps survive save and load")
	var before: Dictionary = scene.course.duplicate(true)
	check(not scene.scale_spacing(100),"invalid scale rejected")
	check(JSON.stringify(before)==JSON.stringify(scene.course),"invalid scale leaves course unchanged")
	var data: Dictionary = before.duplicate(true)
	data.spacing_scale = 0
	check(not scene.valid_course(data),"zero spacing scale rejected on import")
	var map = load("res://course_map.gd").new()
	map.host = scene
	map.editable = true
	map.size = Vector2(350,280)
	root.add_child(map)
	var point: Vector2 = map.project_point(-65,45)
	check(map.unproject_point(point).distance_to(Vector2(-65,45))<0.01,"adaptive map coordinates round trip")
	check(FileAccess.get_file_as_string("res://data/remote-guide.txt").contains("joy.cpl"),"offline beginner remote guide is included")
	print(("PASS" if failures==0 else "FAIL")+": %d course-option checks" % checks)
	map.queue_free()
	scene.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
