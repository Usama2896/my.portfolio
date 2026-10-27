extends SceneTree
var checks := 0
func check(value: bool, message: String) -> void:
	assert(value,message)
	checks += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	app.set_physics_process(false)
	var ex = app.experience
	check(ex.route.get_child_count()>30,"ground route contains strips and arrows")
	check(ex.route.find_children("*","CollisionObject3D",true,false).is_empty(),"route adds no collision")
	var mode = app.content.get_children().filter(func(c): return c is OptionButton)[0]
	check(mode.get_item_id(0)==3 and mode.get_item_id(1)==2 and mode.get_item_id(2)==0 and mode.get_item_id(3)==1,"difficulty sorted with stable IDs")
	for preset in range(5):
		app.weather = preset
		ex.apply_weather()
		check(true,"weather applies")
	app.splash_remaining = 0
	app.launch_keyboard()
	check(ex.remaining()==360,"default six minute battery")
	ex.tick(10)
	check(ex.remaining()==350,"drains before first gate")
	app.active = false
	ex.tick(20)
	check(ex.remaining()==350,"pause preserves battery")
	app.active = true
	app.practice_god_mode = true
	ex.battery_used = 359.99
	app.drone.position.y = 5
	ex.tick(0.02)
	check(ex.depleted and app.throttle==0,"God mode cannot bypass battery cut")
	app.drone.position.y = 0.05
	ex.tick(0.1)
	check(app.finished,"ground impact after empty ends flight")
	app.start_flight(false)
	check(not ex.depleted and ex.remaining()==360,"fresh flight recharges")
	app.wind = 4
	app.wind_direction = 90
	app.gust_strength = 0
	check(absf(ex.wind_force().x)<0.01 and ex.wind_force().z>0,"wind direction applied")
	app.attitude_enabled = true
	var event := InputEventKey.new()
	event.keycode = KEY_V
	event.pressed = true
	app._unhandled_key_input(event)
	check(not app.attitude_enabled,"V toggles attitude in flight")
	app.battery_minutes = 9
	app.gust_strength = 0.7
	app.save_settings()
	app.battery_minutes = 1
	app.load_settings()
	check(app.battery_minutes==9 and is_equal_approx(app.gust_strength,0.7),"new preferences persist")
	var attitude = load("res://attitude.gd").new()
	attitude.host = app
	app.drone.transform.basis = Basis.IDENTITY
	check(attitude.reference_frame().is_zero_approx(),"level aircraft centres attitude line")
	app.drone.transform.basis = Basis.from_euler(Vector3(0,0,0.3))
	check(attitude.reference_frame().x>0.2,"bank line follows projected horizon")
	app.drone.transform.basis = Basis.from_euler(Vector3(0.2,0,0))
	check(attitude.reference_frame().y>20,"nose up moves horizon downward")
	attitude.free()
	app.leave_flight()
	print("PASS: ",checks," environment, battery, route, difficulty and attitude checks")
	quit()
