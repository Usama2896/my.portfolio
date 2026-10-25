extends Node3D

var course: Dictionary
var drone: RigidBody3D
var camera: Camera3D
var hud: Label
var gates: Array[Node3D] = []
var next_gate := 0
var lap := 1
var elapsed := 0.0
var crashes := 0
var active := false
var finished := false
var previous_position := Vector3.ZERO
var contact_cooldown := 0.0
var throttle := 0.0
var joystick := -1
var axes := [0, 1, 2, 3] # roll, pitch, yaw, throttle
var calibration_action := -1
var axis_baseline: Array[float] = []
var status := "Press Enter to start. F1–F4 calibrate roll/pitch/yaw/throttle."

func _ready() -> void:
	var path := OS.get_executable_path().get_base_dir().path_join("course.json")
	if not FileAccess.file_exists(path):
		path = "res://data/course.json"
	course = JSON.parse_string(FileAccess.get_file_as_string(path))
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("8ebbd1")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.7
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	add_child(sun)
	box(self, Vector3(0,-0.2,0), Vector3(100,0.4,100), Color("647951"), true)
	for i in range(course.gates.size()):
		create_gate(course.gates[i], i)
	drone = RigidBody3D.new()
	drone.mass = 0.65
	drone.linear_damp = 0.15
	drone.angular_damp = 4.0
	drone.contact_monitor = true
	drone.max_contacts_reported = 8
	drone.continuous_cd = true
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.18
	shape.shape = sphere
	drone.add_child(shape)
	add_child(drone)
	drone.body_entered.connect(on_contact)
	camera = Camera3D.new()
	camera.fov = 100
	camera.rotation_degrees.x = 15
	drone.add_child(camera)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = Label.new()
	hud.position = Vector2(18,18)
	hud.add_theme_font_size_override("font_size",20)
	hud.add_theme_color_override("font_shadow_color", Color.BLACK)
	hud.add_theme_constant_override("shadow_offset_x",2)
	hud.add_theme_constant_override("shadow_offset_y",2)
	canvas.add_child(hud)
	var profile := ConfigFile.new()
	if profile.load("user://controller.cfg") == OK:
		for i in range(4): axes[i] = int(profile.get_value("axes", str(i), axes[i]))
	reset_run()

func box(parent: Node3D, position_: Vector3, size: Vector3, color: Color, solid: bool) -> void:
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	mesh.position = position_
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		collision.shape = bounds
		body.position = position_
		body.add_child(collision)
		parent.add_child(body)

func create_gate(data: Dictionary, index: int) -> void:
	var gate := Node3D.new()
	gate.position = Vector3(data.x, data.height, data.z)
	gate.rotation_degrees.y = data.yaw_degrees
	add_child(gate)
	gates.append(gate)
	# Rectangular collision frames are placeholders for the custom obstacle meshes.
	var width: float = data.width
	var height: float = data.opening_height
	var color := Color("edbd55")
	for side in [-1,1]:
		box(gate, Vector3(side*width/2,0,0), Vector3(0.12,height+0.24,0.15),color,true)
		box(gate, Vector3(0,side*height/2,0), Vector3(width,0.12,0.15),color,true)
	var label := Label3D.new()
	label.text = "%d · %s" % [index+1,data.name]
	label.position.y = height/2+0.5
	label.font_size = 40
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	gate.add_child(label)

func reset_run() -> void:
	drone.freeze = true
	drone.transform = Transform3D(Basis.IDENTITY, Vector3(0,1.5,4))
	drone.linear_velocity = Vector3.ZERO
	drone.angular_velocity = Vector3.ZERO
	previous_position = drone.position
	next_gate = 0
	lap = 1
	elapsed = 0
	crashes = 0
	throttle = 0
	active = false
	finished = false
	contact_cooldown = 2

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER and not finished:
			active = not active
			drone.freeze = not active
		if event.keycode == KEY_R: reset_run()
		if event.keycode >= KEY_F1 and event.keycode <= KEY_F4:
			var devices := Input.get_connected_joypads()
			if devices.is_empty():
				status = "No USB game controller detected. Keyboard remains available."
			else:
				joystick = devices[0]
				calibration_action = event.keycode-KEY_F1
				axis_baseline.clear()
				for i in range(10): axis_baseline.append(Input.get_joy_axis(joystick,i))
				status = "Move only the selected stick axis through its travel."

func key_axis(positive: Key, negative: Key) -> float:
	return float(Input.is_physical_key_pressed(positive))-float(Input.is_physical_key_pressed(negative))

func _physics_process(delta: float) -> void:
	var devices := Input.get_connected_joypads()
	joystick = devices[0] if not devices.is_empty() else -1
	if calibration_action >= 0 and joystick >= 0:
		for i in range(10):
			if absf(Input.get_joy_axis(joystick,i)-axis_baseline[i]) > 0.65:
				axes[calibration_action] = i
				calibration_action = -1
				var profile := ConfigFile.new()
				for j in range(4): profile.set_value("axes",str(j),axes[j])
				profile.save("user://controller.cfg")
				status = "Axis saved. Check direction before flying."
				break
	if active:
		elapsed += delta
		contact_cooldown = maxf(0,contact_cooldown-delta)
		var roll := key_axis(KEY_D,KEY_A)
		var pitch := key_axis(KEY_S,KEY_W)
		var yaw := key_axis(KEY_Q,KEY_E)
		throttle = clampf(throttle+key_axis(KEY_UP,KEY_DOWN)*delta*0.5,0,1)
		if joystick >= 0:
			roll = Input.get_joy_axis(joystick,axes[0])
			pitch = Input.get_joy_axis(joystick,axes[1])
			yaw = Input.get_joy_axis(joystick,axes[2])
			throttle = clampf((1.0-Input.get_joy_axis(joystick,axes[3]))/2.0,0,1)
		# Rate control: releasing the stick stops rotation; it does not self-level.
		drone.angular_velocity = drone.basis * Vector3(pitch,yaw,-roll)*3.0
		drone.apply_central_force(drone.basis.y*throttle*19.5)
		check_gate(previous_position,drone.position)
		previous_position = drone.position
		if elapsed > float(course.cutoff_seconds): finish_run("Disqualified: time limit")
	var target: Dictionary = course.gates[next_gate]
	hud.text = "FPV TRAINER · PROTOTYPE / APPROXIMATE COURSE\nLap %d / %d   Gate %d: %s\nTime %.1fs   Crashes %d   Throttle %d%%\n%s\nEnter: start/pause   R: restart\nW/S pitch · A/D roll · Q/E yaw · Up/Down throttle\nController: %s\n%s" % [lap,course.laps,next_gate+1,target.name,elapsed,crashes,int(throttle*100),"ASSESSMENT" if active else "PAUSED / FINISHED",Input.get_joy_name(joystick) if joystick >= 0 else "keyboard",status]

func check_gate(from: Vector3, to: Vector3) -> void:
	var gate := gates[next_gate]
	var a := gate.to_local(from)
	var b := gate.to_local(to)
	if a.z > 0 and b.z <= 0:
		var point := a.lerp(b,a.z/(a.z-b.z))
		var data: Dictionary = course.gates[next_gate]
		if absf(point.x) < float(data.width)/2-0.18 and absf(point.y) < float(data.opening_height)/2-0.18:
			next_gate += 1
			if next_gate == gates.size():
				next_gate = 0
				if lap == int(course.laps): finish_run("Course completed")
				else: lap += 1

func on_contact(_body: Node) -> void:
	if not active or contact_cooldown > 0: return
	if drone.linear_velocity.length() < 2.0: return
	crashes += 1
	contact_cooldown = 1.5
	if crashes >= 2: finish_run("Disqualified: second crash")
	else: status = "First crash: 20 point deduction. R restarts the entire attempt."

func finish_run(reason: String) -> void:
	active = false
	finished = true
	drone.freeze = true
	var score := 100-20*crashes-int(maxf(0,elapsed-float(course.qualifying_seconds))/5)
	var result := {"timestamp":Time.get_datetime_string_from_system(),"result":reason,"seconds":elapsed,"crashes":crashes,"score":score if reason == "Course completed" else 0,"course":course.name}
	var log_path := "user://sessions.jsonl"
	var file := FileAccess.open(log_path,FileAccess.READ_WRITE if FileAccess.file_exists(log_path) else FileAccess.WRITE)
	if file:
		file.seek_end()
		file.store_line(JSON.stringify(result))
	status = "%s · Score %d · Saved locally. Bonus disabled pending rule clarification." % [reason,result.score]
