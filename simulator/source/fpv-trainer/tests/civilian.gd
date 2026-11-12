extends SceneTree
var checks := 0
func check(value: bool, title: String) -> void:
	if not value: push_error(title); quit(1); return
	checks += 1
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var rule = load("res://civilian_rules.gd").new()
	check(not rule.unload(),"no unload before flight")
	rule.sample(3,Vector3(0,80,-40),Vector3.ZERO,Vector3.UP,0.3,false)
	check(not rule.unload() and not rule.delivered,"airborne unload blocked even over destination")
	rule.sample(3,Vector3(0,0.15,-40),Vector3.ZERO,Vector3.UP,0.3,false)
	check(not rule.unload(),"altitude alone cannot substitute for physical contact")
	rule.sample(3,Vector3(0,0.15,-40),Vector3(1,0,0),Vector3.UP,0.3,true)
	check(not rule.unload(),"moving parcel service blocked")
	rule.sample(3,Vector3(3,0.15,-40),Vector3.ZERO,Vector3.UP,0.3,true)
	check(not rule.unload(),"outside pad blocked")
	rule.sample(1,Vector3(0,0.15,-40),Vector3.ZERO,Vector3.UP,0.3,true)
	check(not rule.unload(),"full ground hold required")
	rule.sample(1.1,Vector3(0,0.15,-40),Vector3.ZERO,Vector3.UP,0.3,true)
	check(rule.unload() and rule.phase=="returning","grounded service changes to return leg")
	check(not rule.unload(),"parcel cannot be unloaded twice")
	rule.sample(3,Vector3(0,0.15,0),Vector3.ZERO,Vector3.UP,0.3,true)
	check(rule.phase=="returning","return requires a new takeoff")
	rule.sample(0.1,Vector3(0,2,0),Vector3.ZERO,Vector3.UP,0.3,false)
	rule.sample(2.1,Vector3(0,0.15,0),Vector3.ZERO,Vector3.UP,0.3,true)
	check(rule.phase=="complete","home landing completes delivery")
	var license_ = load("res://activation.gd").new()
	license_.activate(load("res://owner_settings.gd").ACTIVATION_KEY)
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	app.splash_remaining = 0
	var original: Dictionary = app.course.duplicate(true)
	var m = app.missions
	check(m.start(false),"civilian mission starts with keyboard")
	check(m.running and not app.gate_root.visible,"mission scene is separate from FPV course")
	app.drone.request_reset(Transform3D(Basis.IDENTITY,Vector3(0,3,-40)))
	await frames(3)
	check(not m.unload(),"live airborne unloading denied")
	var down := InputEventKey.new()
	down.physical_keycode = KEY_DOWN
	down.pressed = true
	Input.parse_input_event(down)
	app.drone.request_reset(Transform3D(Basis.IDENTITY,Vector3(0,0.10,-40)))
	await frames(150)
	check(app.drone.get_contact_count()>0,"test uses actual physical ground contacts")
	check(m.rules.landed,"real physics landing satisfies stable hold")
	app.open_escape_menu()
	var paused_time: float = m.rules.elapsed
	await frames(20)
	check(is_equal_approx(paused_time,m.rules.elapsed) and not m.unload(),"pause holds mission clock and blocks service action")
	app.resume_from_menu()
	await frames(3)
	check(m.unload() and m.rules.delivered,"actual stable landing permits ground placement")
	check(m.parcel.position.is_equal_approx(Vector3(0,0.08,-40)),"parcel placed statically on pad")
	app.drone.request_reset(Transform3D(Basis.IDENTITY,Vector3(0,2,0)))
	await frames(3)
	app.drone.request_reset(Transform3D(Basis.IDENTITY,Vector3(0,0.10,0)))
	await frames(150)
	check(m.rules.phase=="complete" and app.finished,"physical return landing completes flight")
	check(app.read_results().back().mode=="Civilian Parcel Delivery","feedback saved with ordinary training history")
	down.pressed = false
	Input.parse_input_event(down)
	m.stop()
	check(app.course==original and app.gate_root.visible,"solo course restored")
	m.delivery = false
	m.distance_ = 200
	check(m.start(false),"landing-only event starts")
	check(not m.unload(),"landing event has no parcel service")
	app.drone.request_reset(Transform3D(Basis.IDENTITY,Vector3(0,2,-190)))
	await frames(5)
	check(m.rules.phase=="outbound","longer civilian route remains inside its own scene bounds")
	m.stop()
	print("PASS: ",checks," civilian ground-service, physical landing, pause and restoration checks")
	quit()
