extends SceneTree
const O = preload("res://obstacles.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: "+message)
		failures += 1
		return
	checks += 1

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	check(scene.valid_course(scene.course),"supplied course is valid")
	check(scene.gates.size()==13,"13 stations constructed")
	var seen: Array[String] = []
	for g in scene.course.gates:
		if not g.type in seen: seen.append(g.type)
	check(seen.size()==9,"nine distinct obstacle types")
	for kind in O.TYPES:
		var data: Dictionary = scene.course.gates[0].duplicate(true)
		data.type = kind
		data.depth = 3.0
		if kind=="triple": data.width = 3.6; data.opening_height = 3.6
		var hole: Vector2 = O.holes(data)[0]
		var center: Vector3 = O.sections(data)[0].center
		check(O.fits(data,center+Vector3(hole.x,hole.y,0),0),kind+" centre is passable")
		check(not O.fits(data,Vector3(20,20,0),0),kind+" rejects outside opening")
		if kind in ["ring","hexagon"]:
			check(not O.fits(data,Vector3(data.width*0.46,data.opening_height*0.46,0),0),kind+" rejects rectangle corner")
	var gate = scene.gates[0]
	scene.check_gate(gate.to_global(Vector3(3,0,1)),gate.to_global(Vector3(3,0,-1)))
	check(scene.next_gate==0,"outside pass does not advance")
	scene.check_gate(gate.to_global(Vector3(0,0,-1)),gate.to_global(Vector3(0,0,1)))
	check(scene.next_gate==0,"reverse pass does not advance")
	for lap in range(3):
		for index in range(13):
			gate = scene.gates[index]
			var data: Dictionary = scene.course.gates[index]
			var sections := O.sections(data)
			for s in range(sections.size()):
				var center: Vector3 = sections[s].center
				var hole: Vector2 = O.holes(data)[0]
				center += Vector3(hole.x,hole.y,0)
				scene.check_gate(gate.to_global(center+Vector3(0,0,0.1)),gate.to_global(center-Vector3(0,0,0.1)))
				if s<sections.size()-1: check(scene.next_gate==index,"multi-section obstacle requires exit")
	check(scene.finished and scene.lap==3,"three complete laps finish")
	check(scene.read_results().size()==1,"one session saved")
	scene.finish_run("duplicate")
	check(scene.read_results().size()==1,"duplicate finish not recorded")
	scene.reset_run()
	check(not scene.finished and scene.next_gate==0 and scene.crashes==0,"reset restores attempt")
	var original: Dictionary = scene.course.duplicate(true)
	scene.selected = 0
	scene.show_module("Course Editor")
	scene.add_gate()
	check(scene.gates.size()==14,"editor adds obstacle")
	scene.remove_gate()
	check(scene.gates.size()==13,"editor removes obstacle")
	scene.selected = 0
	scene.duplicate_gate()
	check(scene.gates.size()==14,"editor duplicates obstacle")
	scene.move_gate(1)
	check(scene.selected==2,"editor reorders obstacle")
	scene.course = original
	scene.course.gates[0].width = 3.1
	scene.rebuild_course()
	scene.save_course()
	check(is_equal_approx(float(scene.load_course().gates[0].width),3.1),"course survives save/reload")
	scene.show_module("Course Editor")
	var edited_spin: SpinBox = scene.content.get_children().filter(func(child): return child is HBoxContainer and child.get_child_count()==2 and child.get_child(1) is SpinBox and child.get_child(0) is Label and child.get_child(0).text=="X — left/right")[0].get_child(1)
	edited_spin.value = -2.0
	check(is_equal_approx(float(scene.course.gates[scene.selected].x),-2.0),"editor numeric input updates course geometry")
	var invalid := original.duplicate(true)
	invalid.gates[0].width = -1
	check(not scene.valid_course(invalid),"invalid course rejected")
	scene.trainee = "Test pilot"
	scene.fov = 108
	scene.save_settings()
	scene.fov = 70
	scene.load_settings()
	check(scene.fov==108 and scene.trainee=="Test pilot","flight settings and pilot persist")
	scene.endpoints[0] = Vector2(-0.8,0.9)
	scene.centers[0] = 0.1
	scene.inversions[0] = false
	check(is_zero_approx(scene.normalize_axis(0,0.1)),"calibrated stick centre is zero")
	check(is_zero_approx(scene.normalize_axis(0,0.12)),"dead zone suppresses small stick input")
	check(is_equal_approx(scene.normalize_axis(0,0.9),1),"positive endpoint scales to full input")
	check(is_equal_approx(scene.normalize_axis(0,-0.8),-1),"negative endpoint scales to full input")
	scene.inversions[0] = true
	check(is_equal_approx(scene.normalize_axis(0,0.9),-1),"axis inversion reverses input")
	for name_ in ["Fly","Course Editor","Drone & Controls","Training Results"]:
		scene.show_module(name_)
		check(scene.content.get_child_count()>2,"module opens: "+name_)
	scene.course = original
	scene.rebuild_course()
	scene.start_flight(true)
	check(scene.active and scene.assessment and not scene.started,"timer waits for first gate")
	scene.contact_cooldown = 0
	scene.impact_speed = 1
	scene.on_contact(null)
	check(scene.crashes==0 and scene.contacts==1,"light contact is not crash")
	scene.contact_cooldown = 0
	scene.impact_speed = 5
	scene.on_contact(null)
	check(scene.crashes==1 and not scene.finished,"first crash allows continued assessment")
	scene.update_crash_state(1.2)
	scene.contact_cooldown = 0
	scene.on_contact(null)
	scene.update_crash_state(1.2)
	check(scene.finished and scene.crashes==2,"second crash disqualifies after impact")
	print(("PASS" if failures==0 else "FAIL")+": %d checks — shapes, directional gates, tunnel sections, laps, editing, persistence, modules and crash rules" % checks)
	scene.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
