extends Node3D
const O = preload("res://obstacles.gd")
const WORLD = preload("res://world.gd")
const MAP = preload("res://course_map.gd")
const SAVE_PATH = "user://course.json"
const PROFILE_PATH = "user://settings.cfg"
const RESULTS_PATH = "user://sessions.jsonl"
var course: Dictionary
var gates: Array[Node3D] = []
var gate_root: Node3D
var drone: RigidBody3D
var camera: Camera3D
var overview: Camera3D
var next_gate := 0
var section_index := 0
var lap := 1
var elapsed := 0.0
var crashes := 0
var contacts := 0
var active := false
var finished := false
var started := false
var throttle := 0.0
var previous_position := Vector3.ZERO
var impact_speed := 0.0
var contact_cooldown := 0.0
var status := "Welcome. Choose a practice flight or configure your course."
var selected := 0
var module := "Fly"
var in_flight := false
var assessment := false
var assisted := true
var fov := 95.0
var rates := 150.0
var mass := 0.65
var wind := 0.0
var motor_sound := true
var shadows := true
var motor: AudioStreamPlayer
var deadzone := 0.06
var trainee := "Guest"
var joystick := -1
var previous_joystick := -1
var use_radio := false
var axes: Array[int] = [0,1,2,3]
var inversions: Array[bool] = [false,false,false,true]
var endpoints: Array[Vector2] = [Vector2(-1,1),Vector2(-1,1),Vector2(-1,1),Vector2(-1,1)]
var centers: Array[float] = [0.0,0.0,0.0,0.0]
var calibrating := -1
var calibration_step := 0
var baseline: Array[float] = []
var calibration_min := 1.0
var calibration_max := -1.0
var overlay: Control
var menu: PanelContainer
var content: VBoxContainer
var notice: Label
var hud: PanelContainer
var telemetry: Label
var target_label: Label
var flight_status: Label
var minimap: Control
var editor_map: Control
var axis_labels: Array[Label] = []
var guide: MeshInstance3D
var version_label: Label
var capture_stage := 0
var capture_ticks := 0

func _ready() -> void:
	load_settings()
	Engine.max_fps = 60
	course = load_course()
	WORLD.build(self)
	apply_graphics()
	create_motor_audio()
	gate_root = Node3D.new()
	add_child(gate_root)
	rebuild_course()
	create_drone()
	overview = Camera3D.new()
	add_child(overview)
	overview.position = Vector3(15,16,20)
	overview.look_at(Vector3(-7,0,-8))
	overview.fov = 58
	overview.current = true
	build_interface()
	reset_run()
	show_module("Fly")
	if "--capture" in OS.get_cmdline_user_args():
		DisplayServer.window_set_size(Vector2i(1440,900))
		get_window().size = Vector2i(1440,900)

func load_course() -> Dictionary:
	var candidates := [SAVE_PATH,OS.get_executable_path().get_base_dir().path_join("course.json"),"res://data/course.json"]
	for path in candidates:
		if not FileAccess.file_exists(path): continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if valid_course(parsed): return parsed
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/course.json"))

func valid_course(value: Variant) -> bool:
	if not value is Dictionary or not value.get("gates") is Array: return false
	if not value.get("name") is String: return false
	for key in ["laps","qualifying_seconds","cutoff_seconds"]:
		if not (value.get(key) is int or value.get(key) is float) or not is_finite(float(value[key])): return false
	if value.gates.is_empty() or value.gates.size()>80: return false
	for d in value.gates:
		if not d is Dictionary: return false
		for key in ["x","z","height","width","opening_height","yaw_degrees","depth"]:
			if not (d.get(key) is float or d.get(key) is int): return false
			if not is_finite(float(d[key])): return false
		if not d.get("type","") in O.TYPES or not d.get("name") is String: return false
		if d.width<0.6 or d.width>8 or d.opening_height<0.6 or d.opening_height>8 or d.depth<0.5 or d.depth>8: return false
		if absf(d.x)>100 or absf(d.z)>100 or d.height<0.5 or d.height>12: return false
	var bonus = value.get("bonus_seconds_per_point")
	if bonus != null and (not (bonus is float or bonus is int) or not is_finite(float(bonus)) or float(bonus)<0 or float(bonus)>60): return false
	if int(value.get("laps",0))<1 or int(value.get("laps",0))>10: return false
	if float(value.get("qualifying_seconds",0))<=0 or float(value.get("cutoff_seconds",0))<float(value.qualifying_seconds): return false
	return true

func rebuild_course() -> void:
	for child in gate_root.get_children():
		gate_root.remove_child(child)
		child.queue_free()
	gates.clear()
	for i in range(course.gates.size()): gates.append(O.build(gate_root,course.gates[i],i))
	if is_instance_valid(editor_map): editor_map.queue_redraw()
	if is_instance_valid(minimap): minimap.queue_redraw()

func create_drone() -> void:
	drone = RigidBody3D.new()
	drone.mass = mass
	drone.linear_damp = 0.35
	drone.angular_damp = 3
	drone.contact_monitor = true
	drone.max_contacts_reported = 12
	drone.continuous_cd = true
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.18
	shape.shape = sphere
	drone.add_child(shape)
	add_child(drone)
	drone.body_entered.connect(on_contact)
	camera = Camera3D.new()
	camera.fov = fov
	drone.add_child(camera)
	guide = MeshInstance3D.new()
	var marker := SphereMesh.new()
	marker.radius = 0.10
	marker.height = 0.20
	guide.mesh = marker
	var mat := O.material(Color("e6ff9e"))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	guide.material_override = mat
	add_child(guide)

func style(color: String, radius := 12, padding := 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(color)
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.content_margin_left = padding
	s.content_margin_right = padding
	s.content_margin_top = padding
	s.content_margin_bottom = padding
	return s

func label_(text: String, size_ := 16, color := "d7e5e0") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size",size_)
	if size_>=20: l.add_theme_font_override("font",load("res://assets/InterfaceBold.ttf"))
	l.add_theme_color_override("font_color",Color(color))
	return l

func paragraph(text: String, color := "a9beb6") -> void:
	var l := label_(text,14,color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(l)

func button_(text: String, action: Callable, parent: Node = null, accent := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 38
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal",style("58d9b4" if accent else "203c37",7,10))
	b.add_theme_stylebox_override("hover",style("82edcd" if accent else "34564c",7,10))
	b.add_theme_stylebox_override("pressed",style("40b996",7,10))
	b.add_theme_color_override("font_color",Color("0a241e") if accent else Color("e0eae6"))
	b.add_theme_color_override("font_hover_color",Color("0a241e") if accent else Color.WHITE)
	b.pressed.connect(action)
	(parent if parent else content).add_child(b)
	return b

func build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)
	var theme_ := Theme.new()
	theme_.default_font = load("res://assets/Interface.ttf")
	theme_.default_font_size = 14
	for control_type in ["LineEdit","OptionButton"]:
		theme_.set_stylebox("normal",control_type,style("203c37",6,8))
		theme_.set_stylebox("focus",control_type,style("2f5148",6,8))
		theme_.set_color("font_color",control_type,Color("e3ece6"))
	overlay.theme = theme_
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 20
	top.offset_right = -20
	top.offset_top = 18
	top.offset_bottom = 78
	top.add_theme_stylebox_override("panel",style("102722",12,14))
	overlay.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation",20)
	top.add_child(top_row)
	top_row.add_child(label_("DTC  /  FLIGHT LAB",21,"79e5c2"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)
	for name_ in ["Fly","Course Editor","Drone & Controls","Training Results"]:
		button_(name_,func(): leave_flight(); show_module(name_),top_row)
	menu = PanelContainer.new()
	menu.position = Vector2(20,94)
	menu.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	menu.offset_top = 94
	menu.offset_bottom = -46
	menu.offset_left = 20
	menu.offset_right = 430
	menu.add_theme_stylebox_override("panel",style("102722",12,20))
	overlay.add_child(menu)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12)
	scroll.add_child(content)
	notice = label_("",13,"ffc98e")
	notice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	notice.offset_left = 24
	notice.offset_right = -20
	notice.offset_top = -35
	overlay.add_child(notice)
	version_label = label_("OFFLINE  /  V0.2   •   APPROXIMATE COURSE",12,"e0ead7")
	version_label.position = Vector2(450,96)
	overlay.add_child(version_label)
	hud = PanelContainer.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hud.offset_left = 20
	hud.offset_right = -270
	hud.offset_top = -145
	hud.offset_bottom = -46
	hud.add_theme_stylebox_override("panel",style("102722e8",12,16))
	overlay.add_child(hud)
	var hudbox := VBoxContainer.new()
	hud.add_child(hudbox)
	target_label = label_("",20,"7be3be")
	hudbox.add_child(target_label)
	telemetry = label_("",16)
	hudbox.add_child(telemetry)
	flight_status = label_("Enter: pause  •  Esc: menu  •  R: restart",13,"bdcec3")
	hudbox.add_child(flight_status)
	minimap = MAP.new()
	minimap.host = self
	minimap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	minimap.offset_left = -250
	minimap.offset_right = -20
	minimap.offset_top = -295
	minimap.offset_bottom = -46
	overlay.add_child(minimap)

func show_module(name_: String) -> void:
	module = name_
	if name_ != "Course Editor" and is_instance_valid(overview):
		overview.position = Vector3(15,16,20)
		overview.look_at(Vector3(-7,0,-8))
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	axis_labels.clear()
	menu.visible = true
	hud.visible = false
	minimap.visible = false
	content.add_child(label_(name_.to_upper(),12,"78d9bc"))
	match name_:
		"Fly": fly_menu()
		"Course Editor": editor_menu()
		"Drone & Controls": controls_menu()
		"Training Results": results_menu()

func fly_menu() -> void:
	content.add_child(label_("Your next\nclean lap.",38,"f3f1dd"))
	paragraph("A dedicated FPV training field. Learn the course, find your line, then challenge the clock.")
	content.add_child(label_("%02d STATIONS     %d LAPS     100 POINTS" % [course.gates.size(),course.laps],13,"79e5c2"))
	paragraph("Rings · Hexagons · Zigzag · Precision\nTriple ring · Corridor · Tunnels · KZ")
	var pilot := LineEdit.new()
	pilot.placeholder_text = "Pilot name"
	pilot.text = trainee
	pilot.text_changed.connect(func(v): trainee = v.strip_edges().left(60); save_settings())
	content.add_child(pilot)
	button_("Start keyboard-friendly practice  →",func(): start_flight(false),null,true)
	button_("Start Acro assessment",func(): start_flight(true))
	paragraph("PRACTICE\nAuto-level and altitude assistance for keyboard users. Unlimited retries; no competition score.")
	paragraph("ASSESSMENT\nAcro only. 3 laps, 2:40 qualifying time, 3:20 cutoff. First crash: −20; second crash: disqualification.")
	paragraph("W/S pitch  •  A/D roll  •  Q/E turn\n↑ / ↓ climb & descend in assisted practice\nEnter pause  •  R restart  •  Esc menu")
	paragraph("Course dimensions are approximate. Flight dynamics are a tunable simulation, not yet calibrated to your drone.","c0b38f")

func field(text: String, value: float, low: float, high: float, step: float, changed: Callable) -> SpinBox:
	var row := HBoxContainer.new()
	var l := label_(text,13)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	spin.value = value
	spin.custom_minimum_size.x = 125
	spin.value_changed.connect(changed)
	row.add_child(spin)
	content.add_child(row)
	return spin

func editor_menu() -> void:
	content.add_child(label_("Build your line.",28,"f3f1dd"))
	paragraph("Select a station, edit its shape and dimensions, or drag a point on the map. Measurements are in metres.")
	var select := OptionButton.new()
	for i in range(course.gates.size()): select.add_item("%02d  %s" % [i+1,course.gates[i].name])
	selected = clampi(selected,0,course.gates.size()-1)
	select.select(selected)
	select.item_selected.connect(func(i): selected = i; show_module(module); focus_gate())
	content.add_child(select)
	var data: Dictionary = course.gates[selected]
	var name_input := LineEdit.new()
	name_input.text = data.name
	name_input.text_changed.connect(func(v): data.name = v.left(60); rebuild_course())
	content.add_child(name_input)
	var type_input := OptionButton.new()
	for n in O.NAMES: type_input.add_item(n)
	type_input.select(O.TYPES.find(data.type))
	type_input.item_selected.connect(func(i): data.type = O.TYPES[i]; data.name = O.NAMES[i]; rebuild_course(); show_module(module))
	content.add_child(type_input)
	for spec in [["X", "x",-25,12,0.1],["Z", "z",-29,14,0.1],["Centre height", "height",0.5,12,0.1],["Opening width", "width",0.6,8,0.1],["Opening height", "opening_height",0.6,8,0.1],["Depth", "depth",0.5,8,0.1],["Heading °", "yaw_degrees",-180,180,5]]:
		var key: String = spec[1]
		field(spec[0],data[key],spec[2],spec[3],spec[4],func(v): data[key] = v; rebuild_course())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	content.add_child(row)
	button_("+ Add",add_gate,row)
	button_("Duplicate",duplicate_gate,row)
	button_("Remove",remove_gate,row).disabled = course.gates.size()<=1
	var order := HBoxContainer.new()
	content.add_child(order)
	button_("Earlier in route",func(): move_gate(-1),order).disabled = selected==0
	button_("Later in route",func(): move_gate(1),order).disabled = selected==course.gates.size()-1
	editor_map = MAP.new()
	editor_map.host = self
	editor_map.editable = true
	editor_map.custom_minimum_size = Vector2(350,280)
	content.add_child(editor_map)
	paragraph("ASSESSMENT RULES", "79e5c2")
	field("Laps",course.laps,1,10,1,func(v): course.laps = int(v))
	field("Qualifying seconds",course.qualifying_seconds,30,1800,5,func(v):
		course.qualifying_seconds = v
		course.cutoff_seconds = maxf(v,course.cutoff_seconds))
	field("Cutoff seconds",course.cutoff_seconds,30,2400,5,func(v): course.cutoff_seconds = maxf(v,course.qualifying_seconds))
	field("Bonus seconds/point",course.get("bonus_seconds_per_point",0) if course.get("bonus_seconds_per_point") != null else 0,0,60,1,func(v): course.bonus_seconds_per_point = v)
	paragraph("Bonus 0 means disabled. Slow-time deduction: one point per completed five seconds beyond qualifying time.")
	button_("Save course locally",save_course,null,true)
	button_("Export course.json…",func(): file_dialog(false))
	button_("Import course.json…",func(): file_dialog(true))
	button_("Restore supplied course",func(): confirm_restore())
	focus_gate()

func focus_gate() -> void:
	if not is_instance_valid(overview): return
	var pos: Vector3 = gates[selected].position
	overview.position = pos+gates[selected].basis*Vector3(6,4,9)
	overview.look_at(pos)

func add_gate() -> void:
	if course.gates.size()>=80: status = "Course limit: 80 stations."; return
	var d: Dictionary = course.gates[selected].duplicate(true)
	d.x = clampf(float(d.x)+3,-25,12)
	d.name = "New Ring"
	d.type = "ring"
	course.gates.append(d)
	selected = course.gates.size()-1
	rebuild_course()
	show_module(module)

func duplicate_gate() -> void:
	if course.gates.size()>=80: return
	var d: Dictionary = course.gates[selected].duplicate(true)
	d.x = clampf(float(d.x)+2,-25,12)
	course.gates.insert(selected+1,d)
	selected += 1
	rebuild_course()
	show_module(module)

func remove_gate() -> void:
	if course.gates.size()<=1: return
	course.gates.remove_at(selected)
	selected = mini(selected,course.gates.size()-1)
	rebuild_course()
	show_module(module)

func move_gate(direction: int) -> void:
	var destination := selected+direction
	if destination<0 or destination>=course.gates.size(): return
	var d: Dictionary = course.gates[selected]
	course.gates.remove_at(selected)
	course.gates.insert(destination,d)
	selected = destination
	rebuild_course()
	show_module(module)

func save_course() -> void:
	if write_json(SAVE_PATH,course): status = "Course saved. It will load automatically next time."

func write_json(path: String, data: Dictionary) -> bool:
	var f := FileAccess.open(path,FileAccess.WRITE)
	if not f: status = "Could not save file. Choose a writable folder."; return false
	f.store_string(JSON.stringify(data,"  "))
	return true

func file_dialog(importing: bool) -> void:
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE if importing else FileDialog.FILE_MODE_SAVE_FILE
	dialog.filters = PackedStringArray(["*.json ; Course JSON"])
	dialog.current_file = "course.json"
	dialog.title = "Import course" if importing else "Export course"
	add_child(dialog)
	dialog.file_selected.connect(func(path):
		if importing:
			var data = JSON.parse_string(FileAccess.get_file_as_string(path))
			if valid_course(data):
				course = data
				selected = 0
				rebuild_course()
				save_course()
				show_module(module)
			else: status = "Invalid course file. Your current course was preserved."
		else:
			if write_json(path,course): status = "Course exported: "+path
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(0.7)

func confirm_restore() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Replace your current course with the supplied layout? Export first to keep a copy."
	add_child(dialog)
	dialog.confirmed.connect(func():
		course = JSON.parse_string(FileAccess.get_file_as_string("res://data/course.json"))
		selected = 0
		rebuild_course()
		save_course()
		show_module(module)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func controls_menu() -> void:
	content.add_child(label_("Make it yours.",28,"f3f1dd"))
	paragraph("Flight tuning and USB radio setup. Keyboard practice works without any controller.")
	var assisted_toggle := CheckButton.new()
	assisted_toggle.text = "Keyboard assistance in practice"
	assisted_toggle.button_pressed = assisted
	assisted_toggle.toggled.connect(func(v): assisted = v; save_settings())
	content.add_child(assisted_toggle)
	field("Camera FOV",fov,60,120,1,func(v): fov = v; camera.fov = v; save_settings())
	field("Acro rates °/s",rates,60,500,10,func(v): rates = v; save_settings())
	field("Drone mass kg",mass,0.25,2,0.05,func(v): mass = v; drone.mass = v; save_settings())
	field("Practice wind m/s",wind,0,8,0.5,func(v): wind = v; save_settings())
	field("Stick dead zone",deadzone,0,0.25,0.01,func(v): deadzone = v; save_settings())
	var audio_toggle := CheckButton.new()
	audio_toggle.text = "Motor sound"
	audio_toggle.button_pressed = motor_sound
	audio_toggle.toggled.connect(func(v): motor_sound = v; save_settings())
	content.add_child(audio_toggle)
	var shadows_toggle := CheckButton.new()
	shadows_toggle.text = "Shadows (off for slower laptops)"
	shadows_toggle.button_pressed = shadows
	shadows_toggle.toggled.connect(func(v): shadows = v; apply_graphics(); save_settings())
	content.add_child(shadows_toggle)
	paragraph("USB CONTROLLER", "79e5c2")
	var radio := CheckButton.new()
	radio.text = "Use USB controller instead of keyboard"
	radio.button_pressed = use_radio
	radio.toggled.connect(func(v): use_radio = v; save_settings())
	content.add_child(radio)
	paragraph("Connect the radio in USB Joystick mode. Calibrate one axis at a time: move fully both ways, return roll/pitch/yaw to centre, then confirm. Throttle should be at its lowest-power end before flight.")
	for i in range(4):
		var row := HBoxContainer.new()
		content.add_child(row)
		button_(["Map roll","Map pitch","Map yaw","Map throttle"][i],func(): begin_calibration(i),row)
		var invert := CheckButton.new()
		invert.text = "Invert"
		invert.button_pressed = inversions[i]
		invert.toggled.connect(func(v): inversions[i] = v; save_settings())
		row.add_child(invert)
		var readout := label_("",12,"79e5c2")
		content.add_child(readout)
		axis_labels.append(readout)
	button_("Confirm axis travel & centre",finish_calibration)
	paragraph("Mappings are saved for the currently connected device. Physical RadioMaster testing is still pending. Assessment always uses Acro and calm conditions.","c0b38f")

func begin_calibration(index: int) -> void:
	if joystick<0: status = "No controller detected. Connect a USB joystick first."; return
	calibrating = index
	calibration_step = 0
	baseline.clear()
	for i in range(10): baseline.append(Input.get_joy_axis(joystick,i))
	status = "Move only %s fully in both directions." % ["ROLL","PITCH","YAW","THROTTLE"][index]

func finish_calibration() -> void:
	if calibrating<0 or joystick<0 or calibration_step==0: status = "Select Map, then move that stick fully first."; return
	if calibration_max-calibration_min<0.8: status = "Axis travel too small. Move fully to both ends."; return
	endpoints[calibrating] = Vector2(calibration_min,calibration_max)
	centers[calibrating] = Input.get_joy_axis(joystick,axes[calibrating]) if calibrating<3 else (calibration_min+calibration_max)/2
	if calibrating<3 and (centers[calibrating]<calibration_min+0.1 or centers[calibrating]>calibration_max-0.1):
		status = "Return that stick to centre before confirming."
		return
	calibrating = -1
	save_settings()
	status = "Axis calibration saved. Check live values and inversion before flight."

func device_section() -> String:
	return "radio_"+Input.get_joy_guid(joystick)+"_"+Input.get_joy_name(joystick) if joystick>=0 else "default_radio"

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH)!=OK: return
	fov = clampf(float(cfg.get_value("flight","fov",95)),60,120)
	rates = clampf(float(cfg.get_value("flight","rates",150)),60,500)
	mass = clampf(float(cfg.get_value("flight","mass",0.65)),0.25,2)
	wind = clampf(float(cfg.get_value("flight","wind",0)),0,8)
	assisted = bool(cfg.get_value("flight","assisted",true))
	use_radio = bool(cfg.get_value("flight","use_radio",false))
	deadzone = clampf(float(cfg.get_value("flight","deadzone",0.06)),0,0.25)
	trainee = str(cfg.get_value("flight","trainee","Guest")).left(60)
	motor_sound = bool(cfg.get_value("flight","motor_sound",true))
	shadows = bool(cfg.get_value("flight","shadows",true))

func load_radio() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PROFILE_PATH)
	for i in range(4):
		axes[i] = clampi(int(cfg.get_value(device_section(),"axis"+str(i),i)),0,9)
		inversions[i] = bool(cfg.get_value(device_section(),"invert"+str(i),i==3))
		endpoints[i] = cfg.get_value(device_section(),"range"+str(i),Vector2(-1,1))
		centers[i] = float(cfg.get_value(device_section(),"center"+str(i),0.0))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PROFILE_PATH)
	for key in ["fov","rates","mass","wind","assisted","use_radio","deadzone","trainee","motor_sound","shadows"]: cfg.set_value("flight",key,get(key))
	if joystick>=0:
		for i in range(4):
			cfg.set_value(device_section(),"axis"+str(i),axes[i])
			cfg.set_value(device_section(),"invert"+str(i),inversions[i])
			cfg.set_value(device_section(),"range"+str(i),endpoints[i])
			cfg.set_value(device_section(),"center"+str(i),centers[i])
	if cfg.save(PROFILE_PATH)!=OK: status = "Settings could not be saved."

func radio_axis(index: int) -> float:
	if joystick<0: return 0.0
	return normalize_axis(index,Input.get_joy_axis(joystick,axes[index]))

func normalize_axis(index: int, raw: float) -> float:
	var range_: Vector2 = endpoints[index]
	var center: float = centers[index]
	var value: float = clampf((raw-center)/maxf(0.01,range_.y-center) if raw>=center else (raw-center)/maxf(0.01,center-range_.x),-1,1)
	if inversions[index]: value = -value
	return signf(value)*maxf(0,(absf(value)-deadzone)/(1-deadzone)) if index<3 else value

func read_results() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not FileAccess.file_exists(RESULTS_PATH): return rows
	var f := FileAccess.open(RESULTS_PATH,FileAccess.READ)
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty(): continue
		var parser := JSON.new()
		if parser.parse(line)!=OK: continue
		var parsed = parser.data
		if parsed is Dictionary: rows.append(parsed)
	return rows

func results_menu() -> void:
	content.add_child(label_("Every lap counts.",28,"f3f1dd"))
	var rows := read_results()
	paragraph("Local training history. Profiles and results stay on this PC. Export a CSV to copy them to USB.")
	content.add_child(label_("%d RECORDED SESSIONS" % rows.size(),14,"79e5c2"))
	button_("Export results to CSV…",export_results,null,true)
	if rows.is_empty(): paragraph("No sessions yet. Finish a practice run or assessment to record your first result.")
	for i in range(rows.size()-1,maxi(-1,rows.size()-31),-1):
		var d: Dictionary = rows[i]
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel",style("203b34",8,12))
		content.add_child(panel)
		var column := VBoxContainer.new()
		panel.add_child(column)
		column.add_child(label_("%s  /  %s" % [d.get("pilot","Guest"),d.get("mode","Assessment")],15,"8ee5c8"))
		var info := label_("%s\n%.1fs  ·  %d crashes  ·  %s\n%s" % [d.result,d.seconds,d.crashes,str(d.get("score","Practice")),d.timestamp],12)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(info)

func export_results() -> void:
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.filters = PackedStringArray(["*.csv ; Training results"])
	dialog.current_file = "training-results.csv"
	add_child(dialog)
	dialog.file_selected.connect(func(path):
		var file := FileAccess.open(path,FileAccess.WRITE)
		if file:
			var keys := PackedStringArray(["timestamp","pilot","mode","result","seconds","crashes","contacts","score","course"])
			file.store_csv_line(keys)
			for d in read_results():
				var values := PackedStringArray()
				for key in keys:
					var value := str(d.get(key,""))
					if value.begins_with("=") or value.begins_with("+") or value.begins_with("-") or value.begins_with("@"): value = "'"+value
					values.append(value)
				file.store_csv_line(values)
			status = "Results exported to "+path
		else: status = "Could not write CSV. Choose a writable folder."
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(0.7)

func reset_run() -> void:
	drone.freeze = true
	var first := gates[0]
	drone.transform = Transform3D(first.basis,first.to_global(Vector3(0,0,4)))
	drone.linear_velocity = Vector3.ZERO
	drone.angular_velocity = Vector3.ZERO
	previous_position = drone.position
	next_gate = 0
	section_index = 0
	lap = 1
	elapsed = 0
	crashes = 0
	contacts = 0
	throttle = 0
	active = false
	finished = false
	started = false
	contact_cooldown = 0.5

func start_flight(scored: bool) -> void:
	if use_radio and joystick<0: status = "USB control selected, but no radio is connected. Switch to keyboard in Drone & Controls."; return
	if use_radio and (radio_axis(3)+1)/2 > 0.1: status = "Lower radio throttle before starting. Check inversion if needed."; return
	assessment = scored
	reset_run()
	in_flight = true
	active = true
	drone.freeze = false
	camera.current = true
	menu.visible = false
	hud.visible = true
	minimap.visible = true
	status = "Cross the first gate to start timing. "+("ACRO ASSESSMENT" if scored else "PRACTICE — no competition score")

func leave_flight() -> void:
	active = false
	drone.freeze = true
	in_flight = false
	overview.current = true
	overview.position = Vector3(15,16,20)
	overview.look_at(Vector3(-7,0,-8))
	guide.visible = false

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_F11:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if event.keycode == KEY_ESCAPE:
		leave_flight()
		show_module("Fly")
	if not in_flight: return
	if event.keycode == KEY_R: start_flight(assessment)
	if event.keycode == KEY_ENTER and not finished:
		if not active and use_radio and (joystick<0 or (radio_axis(3)+1)/2>0.1):
			status = "Reconnect controller and lower throttle before resuming."
			return
		active = not active
		drone.freeze = not active
		previous_position = drone.position

func key_axis(positive: Key, negative: Key) -> float:
	return float(Input.is_physical_key_pressed(positive))-float(Input.is_physical_key_pressed(negative))

func _physics_process(delta: float) -> void:
	var devices := Input.get_connected_joypads()
	joystick = devices[0] if not devices.is_empty() else -1
	if joystick!=previous_joystick:
		if in_flight and use_radio:
			active = false
			drone.freeze = true
			status = "Controller connection changed. Restart the flight after checking throttle."
		calibrating = -1
		previous_joystick = joystick
		load_radio()
		if module=="Drone & Controls" and is_instance_valid(content): show_module(module)
	if calibrating>=0 and joystick>=0:
		if calibration_step==0:
			for i in range(10):
				if absf(Input.get_joy_axis(joystick,i)-baseline[i])>0.45:
					axes[calibrating] = i
					calibration_min = minf(baseline[i],Input.get_joy_axis(joystick,i))
					calibration_max = maxf(baseline[i],Input.get_joy_axis(joystick,i))
					calibration_step = 1
					break
		else:
			var raw := Input.get_joy_axis(joystick,axes[calibrating])
			calibration_min = minf(calibration_min,raw)
			calibration_max = maxf(calibration_max,raw)
			status = "Travel %.2f to %.2f. Move both ways, centre stick, then Confirm." % [calibration_min,calibration_max]
	for i in range(axis_labels.size()):
		axis_labels[i].text = "Axis %d   %+.2f    %s" % [axes[i],radio_axis(i),Input.get_joy_name(joystick) if joystick>=0 else "No USB controller"]
	if is_instance_valid(motor):
		motor.volume_db = lerpf(motor.volume_db,-23.0+throttle*8 if active and motor_sound else -80.0,0.12)
		motor.pitch_scale = 0.7+throttle*1.8+drone.linear_velocity.length()*0.008
	if active:
		if started: elapsed += delta
		contact_cooldown = maxf(0,contact_cooldown-delta)
		var roll := key_axis(KEY_D,KEY_A)
		var pitch := key_axis(KEY_S,KEY_W)
		var yaw := key_axis(KEY_Q,KEY_E)
		var lift := key_axis(KEY_UP,KEY_DOWN)
		if use_radio:
			roll = radio_axis(0)
			pitch = radio_axis(1)
			yaw = radio_axis(2)
			throttle = clampf((radio_axis(3)+1)/2,0,1)
		if assisted and not assessment and not use_radio:
			# Keyboard learning mode: velocity-based lift and proportional attitude hold.
			var local_up: float = maxf(0.35,drone.basis.y.dot(Vector3.UP))
			throttle = clampf((mass*9.8+mass*(lift*3-drone.linear_velocity.y)*3)/(mass*30*local_up),0,1)
			var target_basis := Basis(Vector3.UP,drone.rotation.y)*Basis.from_euler(Vector3(pitch*0.32,0,-roll*0.32))
			var error_ := (target_basis*drone.basis.inverse()).get_rotation_quaternion()
			drone.angular_velocity = error_.get_axis()*error_.get_angle()*4+Vector3.UP*yaw*1.5
		else:
			if not use_radio: throttle = clampf(throttle+lift*delta*0.4,0,1)
			drone.angular_velocity = drone.basis*Vector3(pitch,yaw,-roll)*deg_to_rad(rates)
		drone.apply_central_force(drone.basis.y*throttle*mass*30)
		if not assessment: drone.apply_central_force(Vector3(wind,0,wind*0.25)*mass*0.3)
		impact_speed = drone.linear_velocity.length()
		check_gate(previous_position,drone.position)
		previous_position = drone.position
		if assessment and elapsed>float(course.cutoff_seconds): finish_run("Disqualified: time limit")
		if drone.position.y < -3 or drone.position.y>80 or absf(drone.position.x)>100 or absf(drone.position.z)>100:
			finish_run("Outside training area")
	if is_instance_valid(notice): notice.text = status
	if in_flight:
		var data: Dictionary = course.gates[next_gate]
		target_label.text = "%02d / %02d   %s    ·    LAP %d / %d" % [next_gate+1,course.gates.size(),data.name.to_upper(),lap,course.laps]
		telemetry.text = "%s  %05.1fs     |     %02d km/h     |     ALT %.1fm     |     POWER %d%%     |     CRASH %d" % ["TIME" if started else "READY",elapsed,int(drone.linear_velocity.length()*3.6),drone.position.y,int(throttle*100),crashes]
		flight_status.text = ("ACRO ASSESSMENT" if assessment else "ASSISTED PRACTICE" if assisted and not use_radio else "ACRO PRACTICE")+"    ·    Enter pause  /  R restart  /  Esc menu"+("    PAUSED" if not active else "")
		minimap.queue_redraw()
		guide.visible = not finished
		var center: Vector3 = O.sections(data)[section_index].center
		var hole: Vector2 = O.holes(data)[0]
		center += Vector3(hole.x,hole.y,0)
		guide.position = gates[next_gate].to_global(center)
	else: guide.visible = false

func check_gate(from: Vector3, to: Vector3) -> void:
	if finished: return
	var gate := gates[next_gate]
	var data: Dictionary = course.gates[next_gate]
	var sections := O.sections(data)
	# Process every crossed section in order, even in a fast frame.
	for unused in range(sections.size()):
		var a: Vector3 = gate.to_local(from)-sections[section_index].center
		var b: Vector3 = gate.to_local(to)-sections[section_index].center
		if not (a.z>0 and b.z<=0): break
		var point := gate.to_local(from).lerp(gate.to_local(to),a.z/(a.z-b.z))
		if not O.fits(data,point,section_index): break
		if not started: started = true; elapsed = 0
		section_index += 1
		if section_index == sections.size():
			section_index = 0
			next_gate += 1
			if next_gate == gates.size():
				next_gate = 0
				if lap == int(course.laps): finish_run("Course completed")
				else: lap += 1
			break

func on_contact(_body: Node) -> void:
	if not active or contact_cooldown>0: return
	contact_cooldown = 0.7
	contacts += 1
	if impact_speed < 3.5:
		status = "Contact recorded — no crash penalty."
		return
	crashes += 1
	if assessment and crashes>=2: finish_run("Disqualified: second crash")
	elif assessment: status = "First crash: −20 points. Second crash ends the assessment."
	else: status = "Practice collision. R restarts; no assessment penalty."

func finish_run(reason: String) -> void:
	if finished: return
	active = false
	finished = true
	drone.freeze = true
	var score := 100-20*crashes-int(maxf(0,elapsed-float(course.qualifying_seconds))/5)
	var bonus: float = course.get("bonus_seconds_per_point",0) if course.get("bonus_seconds_per_point") != null else 0
	if bonus>0: score += int(maxf(0,float(course.qualifying_seconds)-elapsed)/bonus)
	var result := {"timestamp":Time.get_datetime_string_from_system(),"pilot":trainee if not trainee.is_empty() else "Guest","mode":"Assessment" if assessment else "Practice","result":reason,"seconds":snappedf(elapsed,0.01),"crashes":crashes,"contacts":contacts,"score":maxi(0,score) if assessment and reason=="Course completed" else 0 if assessment else "Practice","course":course.name}
	var f := FileAccess.open(RESULTS_PATH,FileAccess.READ_WRITE if FileAccess.file_exists(RESULTS_PATH) else FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line(JSON.stringify(result))
		status = "%s · %s · Result saved. See Training Results." % [reason,str(result.score)]
	else: status = reason+" · Result could not be saved."
	if assessment and bonus<=0: status += " Time bonus is disabled in course rules."

func _process(_delta: float) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	capture_ticks += 1
	if capture_ticks%15!=0: return
	var names := ["home","editor","controls","results","flight","hexagon","zigzag","triple","corridor","tunnel","u-tunnel","kz"]
	if capture_stage>0:
		var img := get_viewport().get_texture().get_image()
		img.save_png("/workspace/fpv-review-"+names[capture_stage-1]+".png")
	if capture_stage>=names.size():
		set_process(false)
		get_tree().quit.call_deferred()
		return
	match capture_stage:
		0: show_module("Fly")
		1: selected = 0; show_module("Course Editor")
		2: show_module("Drone & Controls")
		3: show_module("Training Results")
		4: start_flight(false); active = false; drone.freeze = true
		_:
			leave_flight()
			selected = [1,2,7,9,10,11,12][capture_stage-5]
			show_module("Course Editor")
	capture_stage += 1

func apply_graphics() -> void:
	for child in get_children():
		if child is DirectionalLight3D: child.shadow_enabled = shadows

func create_motor_audio() -> void:
	if DisplayServer.get_name()=="headless": return
	var samples := PackedByteArray()
	samples.resize(22050*2)
	for i in range(22050):
		var t := float(i)/22050
		var value := (sin(TAU*110*t)*0.50+sin(TAU*220*t)*0.25+sin(TAU*440*t)*0.12)*0.6
		samples.encode_s16(i*2,int(value*32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.data = samples
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = 22050
	motor = AudioStreamPlayer.new()
	motor.stream = wav
	motor.volume_db = -80
	add_child(motor)
	motor.play()

func _exit_tree() -> void:
	if is_instance_valid(motor):
		motor.stop()
		motor.stream = null
