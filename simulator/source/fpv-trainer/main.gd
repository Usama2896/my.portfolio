extends Node3D
const BODY = preload("res://drone_body.gd")
const APP_TITLE = "AL JEHAD FPV OBSTACLE COURSE"
const INPUT_ADAPTER = preload("res://controller_input.gd")
const SIZES = preload("res://drone_sizes.gd")
const O = preload("res://obstacles.gd")
const WORLD = preload("res://world.gd")
const MAP = preload("res://course_map.gd")
const SAVE_PATH = "user://course.json"
const PROFILE_PATH = "user://settings.cfg"
const RESULTS_PATH = "user://sessions.jsonl"
var controller = INPUT_ADAPTER.new()
var preferred_radio_guid := ""
var preferred_radio_name := ""
var drone_category := 1
var drone_span := 0.30
var drone_collision: CollisionShape3D
var launch_assessment := false
var launch_dialog: AcceptDialog
var remote_readout: Label
var launch_message: Label
var selected_pole := 0
var splash_control: Control
var splash_progress: ProgressBar
var splash_remaining := 0.0
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
var practice_god_mode := false
var remote_waiting_low := false
var low_throttle_time := 0.0
var crash_phase := ""
var crash_timer := 0.0
var crash_terminal := ""
var impact_flash := 0.0
var shake_strength := 0.0
var feedback_clock := 0.0
var impact_overlay: ColorRect
var centre_panel: PanelContainer
var centre_label: Label
var impact_audio: AudioStreamPlayer
var last_launch_action := "Idle"
var previous_position := Vector3.ZERO
var impact_speed := 0.0
var contact_cooldown := 0.0
var status := "Welcome. Choose a practice flight or configure your course."
var selected := 0
var move_following := true
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
var calibration_snapshot: Dictionary = {}
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
	DisplayServer.window_set_title(APP_TITLE)
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
	build_impact_interface()
	reset_run()
	show_module("Fly")
	if DisplayServer.get_name()!="headless": show_splash()
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
		for angle in ["pitch_degrees","roll_degrees"]:
			var v = d.get(angle,0)
			if not (v is int or v is float) or not is_finite(float(v)) or absf(float(v))>360: return false
		if d.has("pole_offsets"):
			if not d.pole_offsets is Array or d.pole_offsets.size()!=5: return false
			for offset in d.pole_offsets:
				if not offset is Dictionary: return false
				for axis in ["x","z"]:
					var v = offset.get(axis)
					if not (v is int or v is float) or not is_finite(float(v)) or absf(float(v))>8: return false
		if absf(d.x)>100 or absf(d.z)>100 or d.height<0.5 or d.height>12: return false
	var rotation_ = value.get("layout_rotation",0)
	if not (rotation_ is int or rotation_ is float) or not is_finite(float(rotation_)) or absf(float(rotation_))>360: return false
	var scale_ = value.get("spacing_scale",1)
	if not (scale_ is float or scale_ is int) or not is_finite(float(scale_)) or float(scale_)<0.25 or float(scale_)>4: return false
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
	if module=="Course Editor": highlight_pole()
	if is_instance_valid(editor_map): editor_map.queue_redraw()
	if is_instance_valid(minimap): minimap.queue_redraw()

func create_drone() -> void:
	drone = BODY.new()
	drone.mass = mass
	drone.linear_damp = 0.35
	drone.angular_damp = 3
	drone.contact_monitor = true
	drone.max_contacts_reported = 12
	drone.continuous_cd = true
	var surface := PhysicsMaterial.new()
	surface.bounce = 0.28
	surface.friction = 0.65
	drone.physics_material_override = surface
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = SIZES.radius(drone_span)
	shape.shape = sphere
	drone_collision = shape
	drone.add_child(shape)
	add_child(drone)
	drone.connect("impact",on_impact)
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
	top_row.add_child(label_("AL JEHAD  /  FPV COURSE",21,"79e5c2"))
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
	version_label = label_("OFFLINE  /  V0.5   •   APPROXIMATE COURSE",12,"e0ead7")
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
	content.add_child(label_("Choose how\nyou fly.",36,"f3f1dd"))
	paragraph("AL JEHAD FPV OBSTACLE COURSE")
	content.add_child(label_("%02d STATIONS     %d LAPS" % [course.gates.size(),course.laps],13,"79e5c2"))
	content.add_child(label_("Pilot name (optional)",13,"a9beb6"))
	var pilot := LineEdit.new()
	pilot.placeholder_text = "Pilot name (optional)"
	pilot.text = trainee
	pilot.text_changed.connect(func(v): trainee = v.strip_edges().left(60); save_settings())
	content.add_child(pilot)
	content.add_child(label_("Flight mode",13,"a9beb6"))
	var mode := OptionButton.new()
	mode.add_item("Practice — learn and retry")
	mode.add_item("Acro Assessment — timed and scored")
	mode.select(1 if launch_assessment else 0)
	mode.item_selected.connect(func(i): launch_assessment = i==1; show_module.call_deferred("Fly"))
	content.add_child(mode)
	var collisions := OptionButton.new()
	collisions.add_item("Crash Mode — impacts and checkpoint restart")
	collisions.add_item("God Mode — bumps, no crashes or restart")
	collisions.select(1 if practice_god_mode else 0)
	collisions.disabled = launch_assessment
	collisions.item_selected.connect(func(i): practice_god_mode = i==1; save_settings())
	content.add_child(collisions)
	paragraph("Assessment always uses crash rules. Practice lets you choose Crash Mode or God Mode.")
	button_("Fly with Keyboard",launch_keyboard,null,true)
	button_("Fly with Remote",launch_remote)
	launch_message = label_("",14,"ffc98e")
	launch_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(launch_message)
	paragraph("The two buttons select the input automatically. No hidden USB switch is needed.")
	paragraph("KEYBOARD PRACTICE\nAuto-level and height assistance. W/S tilt; A/D bank; Q/E or ←/→ turn. ↑/↓ climb and descend.")
	paragraph("REMOTE PRACTICE\nYour mapped USB radio, in Acro mode. The flight view opens first; motors wait until throttle is low. Setup issues are explained on screen.")
	paragraph("Assessment uses Acro for both input types. Practice has no competition score. Enter pauses; R restarts; Esc opens this menu.")
	paragraph("Selected drone: %s · approximate overall span %.2f m. Change it in Drone & Controls." % [SIZES.LABELS[drone_category],drone_span],"79e5c2")
	paragraph("Course geometry and flight dynamics remain approximate.","c0b38f")

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
	type_input.item_selected.connect(func(i): O.apply_preset(data,O.TYPES[i]); rebuild_course(); show_module(module))
	content.add_child(type_input)
	if data.type=="zigzag":
		pole_editor(data)
		add_editor_map()
	paragraph("STATION POSITION / ROTATION", "79e5c2")
	for spec in [["X — left/right", "x",-95,95,0.1],["Z — front/back", "z",-95,95,0.1],["Y — height", "height",0.5,12,0.1],["Opening width", "width",0.6,8,0.1],["Opening height", "opening_height",0.6,8,0.1],["Depth", "depth",0.5,8,0.1],["Yaw / turn °", "yaw_degrees",-360,360,5]]:
		var key: String = spec[1]
		field(spec[0],data[key],spec[2],spec[3],spec[4],func(v): data[key] = v; rebuild_course())
	for spec in [["Pitch / tilt °","pitch_degrees"],["Roll / bank °","roll_degrees"]]:
		var key: String = spec[1]
		field(spec[0],float(data.get(key,0)),-360,360,5,func(v): data[key] = v; rebuild_course())
	paragraph("SPACING BETWEEN STATIONS", "79e5c2")
	if selected>0:
		field("Gap from previous (m)",station_gap(selected),0.5,80,0.1,func(v):
			if not set_station_gap(v): show_module.call_deferred(module))
		var following := CheckButton.new()
		following.text = "Move later stations together"
		following.button_pressed = move_following
		following.toggled.connect(func(v): move_following = v)
		content.add_child(following)
	else: paragraph("Select station 02 or later to change its gap from the previous station.")
	field("Whole-course spacing ×",float(course.get("spacing_scale",1)),0.25,4,0.05,func(v):
		if not scale_spacing(v): show_module.call_deferred(module))
	field("Rotate whole course °",float(course.get("layout_rotation",0)),-360,360,5,func(v):
		if not rotate_course(v): show_module.call_deferred(module))
	paragraph("Gaps are horizontal distances between station entry centres, not clearances between their edges. Scaling keeps obstacle sizes unchanged.")
	button_("Save course locally",save_course,null,true)
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
	if data.type!="zigzag": add_editor_map()
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
	d.x = clampf(float(d.x)+3,-95,95)
	d.name = "New Ring"
	d.type = "ring"
	course.gates.append(d)
	selected = course.gates.size()-1
	rebuild_course()
	show_module(module)

func duplicate_gate() -> void:
	if course.gates.size()>=80: return
	var d: Dictionary = course.gates[selected].duplicate(true)
	d.x = clampf(float(d.x)+2,-95,95)
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
	paragraph("Choose drone size, flight settings and your USB radio.")
	var category := OptionButton.new()
	for name_ in SIZES.LABELS: category.add_item(name_)
	category.select(drone_category)
	category.item_selected.connect(func(i): select_drone_size(i); show_module(module))
	content.add_child(category)
	field("Overall span (m)",drone_span,0.10,1.40,0.01,func(v): drone_span = v; apply_drone_size(); save_settings())
	paragraph("Size labels refer to propellers. These overall-span presets are estimates; enter your measured full width for clearance. Size changes collision clearance, not the aircraft's flight tuning.")
	var assisted_toggle := CheckButton.new()
	assisted_toggle.text = "Auto-level in keyboard practice"
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
	device_picker()
	paragraph("Choose keyboard or remote using the two buttons on the Fly screen. There is no separate USB-enable switch. Keyboard auto-level only affects keyboard practice.")
	paragraph("Connect the radio in USB Joystick mode. Right stick: roll/pitch. Left stick: yaw/throttle (Mode 2). Calibrate one axis at a time: move fully both ways, return roll/pitch/yaw to centre, then confirm. For throttle, finish fully DOWN before Confirm; its direction is detected automatically.")
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
		readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(readout)
		axis_labels.append(readout)
	button_("Confirm axis travel & centre",finish_calibration)
	button_("Cancel unfinished calibration",cancel_calibration)
	paragraph("Correct live values: roll RIGHT +1; pitch FORWARD −1; yaw RIGHT +1; throttle LOW −1 and HIGH +1. Toggle Invert if a channel is reversed.")
	button_("Open beginner USB remote guide",show_remote_help)
	button_("Copy remote diagnostic report",copy_remote_report)
	button_("Open offline browser Radio Test",open_browser_radio_test)
	paragraph("Mappings are saved for the currently connected device. Physical RadioMaster testing is still pending. Assessment always uses Acro and calm conditions.","c0b38f")

func begin_calibration(index: int) -> void:
	if joystick<0: status = "No controller detected. Connect a USB joystick first."; return
	if calibrating>=0: cancel_calibration()
	calibration_snapshot = {"axes":axes.duplicate(),"endpoints":endpoints.duplicate(),"centers":centers.duplicate()}
	calibrating = index
	calibration_step = 0
	baseline.clear()
	for i in range(10): baseline.append(controller.axis(joystick,i))
	status = "Move only %s fully in both directions." % ["ROLL","PITCH","YAW","THROTTLE"][index]

func finish_calibration() -> void:
	if calibrating<0 or joystick<0 or calibration_step==0: status = "Select Map, then move that stick fully first."; return
	if calibration_max-calibration_min<0.8: status = "Axis travel too small. Move fully to both ends."; return
	endpoints[calibrating] = Vector2(calibration_min,calibration_max)
	centers[calibrating] = controller.axis(joystick,axes[calibrating]) if calibrating<3 else (calibration_min+calibration_max)/2
	if calibrating<3 and (centers[calibrating]<calibration_min+0.1 or centers[calibrating]>calibration_max-0.1):
		status = "Return that stick to centre before confirming."
		return
	if calibrating==3:
		var low_reading := controller.axis(joystick,axes[3])
		var margin := (calibration_max-calibration_min)*0.15
		if low_reading>calibration_min+margin and low_reading<calibration_max-margin:
			status = "Put the throttle fully DOWN, then Confirm. It must be at an endpoint."
			return
		inversions[3] = low_reading>(calibration_min+calibration_max)/2
	calibrating = -1
	calibration_snapshot.clear()
	save_settings()
	status = "Axis calibration saved. Check live values and inversion before flight."

func device_section() -> String:
	return "radio_"+controller.device_guid(joystick)+"_"+controller.device_name(joystick) if joystick>=0 else "default_radio"

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
	practice_god_mode = bool(cfg.get_value("flight","practice_god_mode",false))
	drone_category = clampi(int(cfg.get_value("flight","drone_category",1)),0,SIZES.LABELS.size()-1)
	drone_span = clampf(float(cfg.get_value("flight","drone_span",SIZES.SPANS[drone_category])),0.10,1.40)
	preferred_radio_guid = str(cfg.get_value("flight","preferred_radio_guid",""))
	preferred_radio_name = str(cfg.get_value("flight","preferred_radio_name",""))

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
	for key in ["fov","rates","mass","wind","assisted","use_radio","deadzone","trainee","motor_sound","shadows","drone_category","drone_span","preferred_radio_guid","preferred_radio_name","practice_god_mode"]: cfg.set_value("flight",key,get(key))
	if joystick>=0:
		var stored_axes: Array = calibration_snapshot.axes if calibrating>=0 and not calibration_snapshot.is_empty() else axes
		var stored_ranges: Array = calibration_snapshot.endpoints if calibrating>=0 and not calibration_snapshot.is_empty() else endpoints
		var stored_centers: Array = calibration_snapshot.centers if calibrating>=0 and not calibration_snapshot.is_empty() else centers
		for i in range(4):
			cfg.set_value(device_section(),"axis"+str(i),stored_axes[i])
			cfg.set_value(device_section(),"invert"+str(i),inversions[i])
			cfg.set_value(device_section(),"range"+str(i),stored_ranges[i])
			cfg.set_value(device_section(),"center"+str(i),stored_centers[i])
	if cfg.save(PROFILE_PATH)!=OK: status = "Settings could not be saved."

func radio_axis(index: int) -> float:
	if joystick<0: return 0.0
	return normalize_axis(index,controller.axis(joystick,axes[index]))

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
			var keys := PackedStringArray(["timestamp","pilot","mode","result","seconds","crashes","contacts","score","course","input","drone_size","span_metres","collision_mode"])
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
	drone.call("request_reset",Transform3D(Basis(Vector3.UP,deg_to_rad(float(course.gates[0].yaw_degrees))),first.to_global(Vector3(0,0,4))))
	drone.linear_velocity = Vector3.ZERO
	drone.angular_velocity = Vector3.ZERO
	drone.set("previous_velocity",Vector3.ZERO)
	previous_position = drone.position
	next_gate = 0
	section_index = 0
	lap = 1
	elapsed = 0
	crashes = 0
	contacts = 0
	throttle = 0
	remote_waiting_low = false
	low_throttle_time = 0
	crash_phase = ""
	crash_timer = 0
	crash_terminal = ""
	impact_flash = 0
	shake_strength = 0
	drone.linear_damp = 0.35
	drone.angular_damp = 3
	active = false
	finished = false
	started = false
	contact_cooldown = 0.5

func start_flight(scored: bool) -> bool:
	if splash_remaining>0: return false
	if use_radio:
		var reason := remote_configuration_issue()
		if not reason.is_empty():
			active = false
			drone.freeze = true
			status = reason
			last_launch_action = "Setup blocked: "+reason
			show_launch_problem()
			return false
	assessment = scored
	reset_run()
	in_flight = true
	active = not use_radio
	remote_waiting_low = use_radio
	drone.freeze = use_radio
	if use_radio:
		var grounded := drone.transform
		grounded.origin.y = SIZES.radius(drone_span)+0.06
		drone.call("request_reset",grounded)
	previous_position = drone.position
	camera.current = true
	menu.visible = false
	hud.visible = true
	minimap.visible = true
	if is_instance_valid(launch_dialog): launch_dialog.hide()
	status = "Lower throttle fully to arm. The remote flight view is open." if use_radio else "Cross the first gate to start timing. KEYBOARD PRACTICE" if not scored else "ACRO ASSESSMENT"
	last_launch_action = "Flight view opened — waiting for low throttle" if use_radio else "Keyboard flight started"
	return true

func leave_flight() -> void:
	remote_waiting_low = false
	crash_phase = ""
	active = false
	drone.freeze = true
	in_flight = false
	overview.current = true
	overview.position = Vector3(15,16,20)
	overview.look_at(Vector3(-7,0,-8))
	guide.visible = false

func _unhandled_key_input(event: InputEvent) -> void:
	if splash_remaining>0 or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_F11:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if event.keycode == KEY_ESCAPE:
		leave_flight()
		show_module("Fly")
	if not in_flight: return
	if event.keycode == KEY_R: start_flight(assessment)
	if event.keycode == KEY_ENTER and not finished:
		if remote_waiting_low:
			status = "Lower throttle to arm; arming happens automatically after a stable low reading."
			return
		if not active and use_radio and (joystick<0 or (radio_axis(3)+1)/2>0.1):
			status = "Reconnect controller and lower throttle before resuming."
			return
		active = not active
		drone.freeze = not active
		previous_position = drone.position

func key_axis(positive: Key, negative: Key) -> float:
	return float(Input.is_physical_key_pressed(positive))-float(Input.is_physical_key_pressed(negative))

func _physics_process(delta: float) -> void:
	poll_radio()
	update_feedback(delta)
	update_remote_arming(delta)
	if started and in_flight and not finished and (active or remote_waiting_low): elapsed += delta
	update_crash_state(delta)
	if calibrating>=0 and joystick>=0:
		if calibration_step==0:
			for i in range(10):
				if absf(controller.axis(joystick,i)-baseline[i])>0.45:
					axes[calibrating] = i
					calibration_min = minf(baseline[i],controller.axis(joystick,i))
					calibration_max = maxf(baseline[i],controller.axis(joystick,i))
					calibration_step = 1
					break
		else:
			var raw := controller.axis(joystick,axes[calibrating])
			calibration_min = minf(calibration_min,raw)
			calibration_max = maxf(calibration_max,raw)
			status = "Travel %.2f to %.2f. Move both ways, centre stick, then Confirm." % [calibration_min,calibration_max]
	for i in range(axis_labels.size()):
		axis_labels[i].text = "Axis %d   %+.2f    %s" % [axes[i],radio_axis(i),controller.device_name(joystick) if joystick>=0 else "No USB controller"]
	if is_instance_valid(motor):
		motor.volume_db = lerpf(motor.volume_db,-23.0+throttle*8 if active and crash_phase.is_empty() and motor_sound else -80.0,0.12)
		motor.pitch_scale = 0.7+throttle*1.8+drone.linear_velocity.length()*0.008
	if active and crash_phase.is_empty():
		contact_cooldown = maxf(0,contact_cooldown-delta)
		var roll := key_axis(KEY_D,KEY_A)
		var pitch := key_axis(KEY_S,KEY_W)
		var yaw := clampf(key_axis(KEY_Q,KEY_E)+key_axis(KEY_LEFT,KEY_RIGHT),-1,1)
		var lift := key_axis(KEY_UP,KEY_DOWN)
		if use_radio:
			roll = radio_axis(0)
			pitch = radio_axis(1)
			yaw = -radio_axis(2) # Positive live yaw input means turn RIGHT, clockwise.
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

		if drone.position.y < -3 or drone.position.y>80 or absf(drone.position.x)>100 or absf(drone.position.z)>100:
			finish_run("Outside training area")
	if in_flight and not finished and assessment and elapsed>float(course.cutoff_seconds): finish_run("Disqualified: time limit")
	update_flight_centre()
	if is_instance_valid(notice): notice.text = status
	if is_instance_valid(launch_message) and not in_flight: launch_message.text = status
	if is_instance_valid(remote_readout) and is_instance_valid(launch_dialog) and launch_dialog.visible: update_launch_readout()
	if in_flight:
		var data: Dictionary = course.gates[next_gate]
		target_label.text = "%02d / %02d   %s    ·    LAP %d / %d" % [next_gate+1,course.gates.size(),data.name.to_upper(),lap,course.laps]
		telemetry.text = "%s  %05.1fs     |     %02d km/h     |     ALT %.1fm     |     HDG %03d°     |     POWER %d%%     |     CRASH %d" % ["TIME" if started else "READY",elapsed,int(drone.linear_velocity.length()*3.6),drone.position.y,int(fposmod(-rad_to_deg(drone.rotation.y),360)),int(throttle*100),crashes]
		flight_status.text = ("GOD MODE · " if not assessment and practice_god_mode else "CRASH MODE · ")+("ACRO ASSESSMENT" if assessment else "ASSISTED PRACTICE" if assisted and not use_radio else "ACRO PRACTICE")+"    ·    Q/E or ←/→: turn    /    A/D: bank    /    Enter: pause    /    Esc: menu"+("    PAUSED" if not active else "")
		minimap.queue_redraw()
		guide.visible = not finished
		var center: Vector3 = O.sections(data)[section_index].center
		var hole: Vector2 = O.holes(data)[0]
		center += Vector3(hole.x,hole.y,0)
		guide.position = gates[next_gate].to_global(center)
	else: guide.visible = false

func check_gate(from: Vector3, to: Vector3) -> void:
	if finished or not crash_phase.is_empty() or remote_waiting_low: return
	var gate := gates[next_gate]
	var data: Dictionary = course.gates[next_gate]
	var sections := O.sections(data)
	# Process every crossed section in order, even in a fast frame.
	for unused in range(sections.size()):
		var a: Vector3 = gate.to_local(from)-sections[section_index].center
		var b: Vector3 = gate.to_local(to)-sections[section_index].center
		if not (a.z>0 and b.z<=0): break
		var point := gate.to_local(from).lerp(gate.to_local(to),a.z/(a.z-b.z))
		if not O.fits(data,point,section_index,SIZES.radius(drone_span)): break
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
	# Compatibility hook for assessment rule tests; real physics uses body impact normals.
	on_impact(impact_speed,Vector3.BACK)

func on_impact(strength: float, normal: Vector3) -> void:
	if not active or finished or not crash_phase.is_empty() or contact_cooldown>0: return
	contact_cooldown = 0.35
	contacts += 1
	impact_flash = 0.16
	shake_strength = clampf(strength*0.012,0.02,0.10)
	play_impact_sound(strength)
	if not assessment and practice_god_mode:
		status = "GOD MODE — contact, no crash or reset."
		return
	if strength<3.5:
		status = "Light contact — physical bounce, no crash penalty."
		return
	crashes += 1
	crash_phase = "tumble"
	crash_timer = 1.1
	crash_terminal = "Disqualified: second crash" if assessment and crashes>=2 else ""
	impact_flash = 0.42
	shake_strength = 0.08
	throttle = 0
	drone.linear_damp = 0.08
	drone.angular_damp = 0.25
	drone.apply_central_impulse(normal.normalized()*mass*clampf(strength*0.35,1,4))
	var inertia := 0.4*mass*pow(SIZES.radius(drone_span),2)
	drone.apply_torque_impulse(Vector3(2.5,0.8,-3.5)*inertia*clampf(strength/5,0.5,1.5))
	status = "CRASH — motors cut. Restarting at station %02d after impact." % [next_gate+1]
	if assessment and crashes==1: status += " First-crash penalty: −20."

func finish_run(reason: String) -> void:
	if finished: return
	active = false
	remote_waiting_low = false
	crash_phase = ""
	finished = true
	drone.freeze = true
	var score := 100-20*crashes-int(maxf(0,elapsed-float(course.qualifying_seconds))/5)
	var bonus: float = course.get("bonus_seconds_per_point",0) if course.get("bonus_seconds_per_point") != null else 0
	if bonus>0: score += int(maxf(0,float(course.qualifying_seconds)-elapsed)/bonus)
	var result := {"timestamp":Time.get_datetime_string_from_system(),"pilot":trainee if not trainee.is_empty() else "Guest","mode":"Assessment" if assessment else "Practice","result":reason,"seconds":snappedf(elapsed,0.01),"crashes":crashes,"contacts":contacts,"score":maxi(0,score) if assessment and reason=="Course completed" else 0 if assessment else "Practice","course":course.name,"drone_size":SIZES.LABELS[drone_category],"span_metres":drone_span,"input":"Remote" if use_radio else "Keyboard","collision_mode":"Assessment" if assessment else "God Mode" if practice_god_mode else "Crash Mode"}
	var f := FileAccess.open(RESULTS_PATH,FileAccess.READ_WRITE if FileAccess.file_exists(RESULTS_PATH) else FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line(JSON.stringify(result))
		status = "%s · %s · Result saved. See Training Results." % [reason,str(result.score)]
	else: status = reason+" · Result could not be saved."
	if assessment and bonus<=0: status += " Time bonus is disabled in course rules."

func _process(_delta: float) -> void:
	update_splash(_delta)
	if not "--capture" in OS.get_cmdline_user_args(): return
	if splash_remaining>0:
		if splash_remaining<1.5 and capture_stage==0:
			get_viewport().get_texture().get_image().save_png("/workspace/fpv-review-splash.png")
			capture_stage = -1
		return
	if capture_stage<0: capture_stage = 0
	capture_ticks += 1
	if capture_ticks%15!=0: return
	var names := ["home","editor","controls","results","flight","hexagon","zigzag","triple","corridor","tunnel","u-tunnel","kz","triangle","square","diamond","arch","ladder","dive","hurdle","flag","poles","remote-check"]
	if capture_stage>0: get_viewport().get_texture().get_image().save_png("/workspace/fpv-review-"+names[capture_stage-1]+".png")
	if capture_stage>=names.size():
		set_process(false)
		get_tree().quit.call_deferred()
		return
	match capture_stage:
		0: show_module("Fly")
		1: selected = 0; show_module("Course Editor")
		2: show_module("Drone & Controls")
		3: show_module("Training Results")
		4: launch_keyboard(); active = false; drone.freeze = true
		20:
			leave_flight()
			selected = 2
			O.ensure_poles(course.gates[2])
			course.gates[2].pole_offsets[1].x = 1.5
			course.gates[2].pole_offsets[3].x = -1.5
			selected_pole = 1
			rebuild_course()
			show_module("Course Editor")
		21: leave_flight(); show_module("Fly"); launch_remote()
		_:
			leave_flight()
			if capture_stage<12: selected = [1,2,7,9,10,11,12][capture_stage-5]
			else:
				selected = 0
				O.apply_preset(course.gates[0],O.TYPES[capture_stage-3])
				rebuild_course()
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
	if is_instance_valid(impact_audio):
		impact_audio.stop()
		impact_audio.stream = null
	if is_instance_valid(motor):
		motor.stop()
		motor.stream = null

func station_gap(index: int) -> float:
	if index<1 or index>=course.gates.size(): return 0
	var a: Dictionary = course.gates[index-1]
	var b: Dictionary = course.gates[index]
	return Vector2(float(b.x)-float(a.x),float(b.z)-float(a.z)).length()

func set_station_gap(distance_: float) -> bool:
	if selected<1 or distance_<0.5 or distance_>80: return false
	var previous: Dictionary = course.gates[selected-1]
	var data: Dictionary = course.gates[selected]
	var offset := Vector2(float(data.x)-float(previous.x),float(data.z)-float(previous.z))
	var direction := offset.normalized()
	if offset.length()<0.01:
		var heading := deg_to_rad(float(previous.yaw_degrees))
		direction = Vector2(-sin(heading),-cos(heading))
	var shift := direction*distance_-offset
	var stop: int = course.gates.size() if move_following else selected+1
	for i in range(selected,stop):
		var point := Vector2(course.gates[i].x,course.gates[i].z)+shift
		if absf(point.x)>95 or absf(point.y)>95:
			status = "Gap exceeds the 190 m editable area. Reduce spacing or move the layout."
			return false
	for i in range(selected,stop):
		course.gates[i].x = float(course.gates[i].x)+shift.x
		course.gates[i].z = float(course.gates[i].z)+shift.y
	rebuild_course()
	focus_gate()
	status = "Gap set to %.1f m (%.1f ft). Save course to keep it." % [distance_,distance_*3.28084]
	if module=="Course Editor": show_module.call_deferred(module)
	return true

func scale_spacing(value: float) -> bool:
	if value<0.25 or value>4: return false
	var factor := value/float(course.get("spacing_scale",1))
	var anchor := Vector2(course.gates[0].x,course.gates[0].z)
	var positions: Array[Vector2] = []
	for d in course.gates:
		var point := anchor+(Vector2(d.x,d.z)-anchor)*factor
		if absf(point.x)>95 or absf(point.y)>95:
			status = "Layout would exceed editable bounds. Choose a smaller spacing multiplier."
			return false
		positions.append(point)
	for i in range(positions.size()):
		course.gates[i].x = positions[i].x
		course.gates[i].z = positions[i].y
	course.spacing_scale = value
	rebuild_course()
	focus_gate()
	status = "Whole-course spacing ×%.2f. Obstacle dimensions unchanged. Save to keep it." % value
	if module=="Course Editor": show_module.call_deferred(module)
	return true

func show_remote_help() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "USB RadioMaster setup — beginner guide"
	dialog.min_size = Vector2i(680,520)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640,480)
	dialog.add_child(scroll)
	var text := Label.new()
	text.custom_minimum_size.x = 610
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.text = FileAccess.get_file_as_string("res://data/remote-guide.txt")
	scroll.add_child(text)
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func launch_keyboard() -> bool:
	use_radio = false
	if calibrating>=0: cancel_calibration()
	save_settings()
	return start_flight(launch_assessment)

func launch_remote() -> bool:
	use_radio = true
	poll_radio()
	save_settings()
	return start_flight(launch_assessment)

func remote_configuration_issue() -> String:
	if joystick<0: return "No selected USB remote is connected. Connect it in USB Joystick/HID mode, then choose the device in Drone & Controls."
	if calibrating>=0: return "Axis calibration is unfinished. Confirm its travel and centre, or Cancel unfinished calibration in Drone & Controls."
	for i in range(4):
		for j in range(i):
			if axes[i]==axes[j]: return "%s and %s both use axis %d. Map each movement to a different radio axis." % [["Roll","Pitch","Yaw","Throttle"][j],["Roll","Pitch","Yaw","Throttle"][i],axes[i]]
	return ""

func remote_blocker() -> String:
	var setup := remote_configuration_issue()
	if not setup.is_empty(): return setup
	var power := (radio_axis(3)+1)/2
	if power>0.10: return "Throttle is at %d%%. Move the throttle stick fully DOWN. Low should read −1.00. If DOWN reads +1.00, invert throttle; if it does not change, remap throttle." % roundi(power*100)
	return ""

func show_launch_problem() -> void:
	if not is_instance_valid(launch_dialog):
		launch_dialog = AcceptDialog.new()
		launch_dialog.title = "Remote flight — setup check"
		launch_dialog.dialog_hide_on_ok = false
		launch_dialog.get_ok_button().text = "Start Remote Flight"
		launch_dialog.min_size = Vector2i(660,390)
		remote_readout = Label.new()
		remote_readout.custom_minimum_size = Vector2(610,310)
		remote_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		launch_dialog.add_child(remote_readout)
		launch_dialog.add_button("Open Controls",false,"controls")
		launch_dialog.add_button("Invert Throttle",false,"invert")
		launch_dialog.add_button("Copy Report",false,"report")
		launch_dialog.get_ok_button().pressed.connect(func(): launch_from_popup.call_deferred())
		launch_dialog.custom_action.connect(func(action):
			if action=="report": copy_remote_report()
			if action=="controls":
				launch_dialog.hide()
				leave_flight()
				show_module("Drone & Controls")
			if action=="invert" and joystick>=0:
				inversions[3] = not inversions[3]
				save_settings()
				update_launch_readout())
		add_child(launch_dialog)
	update_launch_readout()
	launch_dialog.popup_centered()

func update_launch_readout() -> void:
	var device := controller.device_name(joystick) if joystick>=0 else "NOT CONNECTED"
	var reason := remote_configuration_issue()
	launch_dialog.get_ok_button().disabled = not reason.is_empty()
	if joystick<0:
		remote_readout.text = "SELECTED REMOTE: NOT CONNECTED\n\n"+reason+"\n\nUse a data cable and USB Joystick/HID mode. Open Controls to select the device.\n\nKeyboard flight is available separately on the Fly screen."
		return
	remote_readout.text = "SELECTED REMOTE: %s\n\n%s\n\nThrottle: %+.2f  /  %d%% motor command\nRoll: %+.2f   Pitch: %+.2f   Yaw: %+.2f\n\nClick Start Remote Flight to open the flight view. Motors stay off until throttle is near −1.00.\n\nKeyboard flight is separate: close this window and use Fly with Keyboard." % [device,reason if not reason.is_empty() else "READY — open the flight view; motors wait for low throttle.",radio_axis(3),roundi((radio_axis(3)+1)*50),radio_axis(0),radio_axis(1),radio_axis(2)]

func poll_radio() -> void:
	var devices: Array[int] = controller.devices()
	var chosen := -1
	for id in devices:
		if (not preferred_radio_guid.is_empty() or not preferred_radio_name.is_empty()) and controller.device_guid(id)==preferred_radio_guid and controller.device_name(id)==preferred_radio_name:
			chosen = id
			break
	if chosen<0 and preferred_radio_guid.is_empty() and preferred_radio_name.is_empty() and not devices.is_empty(): chosen = devices[0]
	joystick = chosen
	if joystick==previous_joystick: return
	if in_flight and use_radio:
		active = false
		remote_waiting_low = false
		drone.freeze = true
		status = "Remote connection changed. Check the selected device and throttle before restarting."
	calibrating = -1
	previous_joystick = joystick
	calibration_snapshot.clear()
	load_radio()
	if module=="Drone & Controls" and is_instance_valid(content): show_module.call_deferred(module)

func device_picker() -> void:
	var devices: Array[int] = controller.devices()
	var picker := OptionButton.new()
	if devices.is_empty():
		picker.add_item("No USB radio detected")
		picker.disabled = true
	else:
		for i in range(devices.size()):
			var id: int = devices[i]
			picker.add_item(controller.device_name(id),id)
			if id==joystick: picker.select(i)
		picker.item_selected.connect(func(index):
			var id := picker.get_item_id(index)
			preferred_radio_guid = controller.device_guid(id)
			preferred_radio_name = controller.device_name(id)
			poll_radio()
			save_settings())
	content.add_child(picker)
	paragraph("If more than one controller is connected, select the radio you calibrated. Fly with Remote selects USB input automatically.")

func select_drone_size(index: int) -> void:
	drone_category = clampi(index,0,SIZES.LABELS.size()-1)
	drone_span = SIZES.SPANS[drone_category]
	apply_drone_size()
	save_settings()

func apply_drone_size() -> void:
	if is_instance_valid(drone_collision):
		var shape := SphereShape3D.new()
		shape.radius = SIZES.radius(drone_span)
		drone_collision.shape = shape

func pole_editor(data: Dictionary) -> void:
	O.ensure_poles(data)
	paragraph("INDIVIDUAL ZIG ZAG POLES", "79e5c2")
	paragraph("Choose a pole to move it left/right or forward/back. Orange marks the selected pole. You can also drag its numbered orange point on the map below.")
	var select := OptionButton.new()
	for i in range(5): select.add_item("Pole %d" % [i+1])
	selected_pole = clampi(selected_pole,0,4)
	select.select(selected_pole)
	select.item_selected.connect(func(i): selected_pole = i; show_module(module))
	content.add_child(select)
	var offset: Dictionary = data.pole_offsets[selected_pole]
	field("Pole X — left/right",offset.x,-8,8,0.1,func(v): offset.x = v; rebuild_course())
	field("Pole Z — front/back",offset.z,-8,8,0.1,func(v): offset.z = v; rebuild_course())
	button_("Reset five poles to a straight line",func():
		data.erase("pole_offsets")
		O.ensure_poles(data)
		rebuild_course()
		show_module(module))
	highlight_pole()

func highlight_pole() -> void:
	if selected<0 or selected>=gates.size() or course.gates[selected].type!="zigzag": return
	for i in range(5):
		var mesh := gates[selected].get_node_or_null("SlalomPole%02d" % i)
		if mesh is MeshInstance3D: mesh.material_override = O.material(Color("df793e") if i==selected_pole else Color("bda13c"))

func set_pole_world_position(index: int, world_xz: Vector2) -> bool:
	var data: Dictionary = course.gates[selected]
	var gate := gates[selected]
	var delta := world_xz-Vector2(gate.position.x,gate.position.z)
	var determinant := gate.basis.x.x*gate.basis.z.z-gate.basis.z.x*gate.basis.x.z
	if absf(determinant)<0.05:
		status = "This station is nearly vertical. Use the Pole X/Z fields instead of top-down dragging."
		return false
	O.ensure_poles(data)
	var x := (delta.x*gate.basis.z.z-delta.y*gate.basis.z.x)/determinant
	var z := (gate.basis.x.x*delta.y-gate.basis.x.z*delta.x)/determinant+float(data.depth)*index/4
	data.pole_offsets[index].x = snappedf(clampf(x,-8,8),0.1)
	data.pole_offsets[index].z = snappedf(clampf(z,-8,8),0.1)
	rebuild_course()
	return true

func rotate_course(value: float) -> bool:
	if value< -360 or value>360: return false
	var angle := deg_to_rad(value-float(course.get("layout_rotation",0)))
	var rotation_ := Basis(Vector3.UP,angle)
	var anchor := Vector3(course.gates[0].x,0,course.gates[0].z)
	var positions: Array[Vector3] = []
	for data in course.gates:
		var point: Vector3 = anchor+rotation_*(Vector3(data.x,0,data.z)-anchor)
		if absf(point.x)>95 or absf(point.z)>95:
			status = "Rotation would exceed the editable area. Move the course or choose a smaller turn."
			return false
		positions.append(point)
	for i in range(positions.size()):
		course.gates[i].x = positions[i].x
		course.gates[i].z = positions[i].z
		course.gates[i].yaw_degrees = wrapf(float(course.gates[i].yaw_degrees)+rad_to_deg(angle),-180,180)
	course.layout_rotation = value
	rebuild_course()
	focus_gate()
	status = "Course rotated %.0f°. Shapes and gaps unchanged. Save course to keep it." % value
	if module=="Course Editor": show_module.call_deferred(module)
	return true

func show_splash() -> void:
	splash_remaining = 2.0
	if is_instance_valid(splash_control): splash_control.get_parent().queue_free()
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	splash_control = Control.new()
	splash_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(splash_control)
	var background := ColorRect.new()
	background.color = Color("091d19")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	splash_control.add_child(background)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	splash_control.add_child(centre)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",18)
	centre.add_child(column)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/icon.svg")
	icon.custom_minimum_size = Vector2(108,108)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(icon)
	var title := label_("AL JEHAD",64,"f3f1dd")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle := label_("FPV  OBSTACLE  COURSE",24,"79e5c2")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	splash_progress = ProgressBar.new()
	splash_progress.custom_minimum_size = Vector2(560,4)
	splash_progress.show_percentage = false
	splash_progress.add_theme_stylebox_override("background",style("1c3e33",2,0))
	splash_progress.add_theme_stylebox_override("fill",style("79e5c2",2,0))
	column.add_child(splash_progress)
	var footer := label_("OFFLINE FLIGHT SIMULATOR   /   VERSION 0.5",12,"79988c")
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(footer)

func update_splash(delta: float) -> void:
	if splash_remaining<=0: return
	splash_remaining = maxf(0,splash_remaining-delta)
	if is_instance_valid(splash_progress): splash_progress.value = (1-splash_remaining/2)*100
	if splash_remaining<=0 and is_instance_valid(splash_control):
		var layer := splash_control.get_parent()
		layer.queue_free()

func cancel_calibration() -> void:
	if not calibration_snapshot.is_empty():
		axes.assign(calibration_snapshot.axes)
		endpoints.assign(calibration_snapshot.endpoints)
		centers.assign(calibration_snapshot.centers)
	calibration_snapshot.clear()
	calibrating = -1
	status = "Calibration cancelled. Previous axis mappings kept."

func add_editor_map() -> void:
	editor_map = MAP.new()
	editor_map.host = self
	editor_map.editable = true
	editor_map.custom_minimum_size = Vector2(350,280)
	content.add_child(editor_map)

func build_impact_interface() -> void:
	impact_overlay = ColorRect.new()
	impact_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	impact_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	impact_overlay.color = Color(0.9,0.18,0.08,0)
	overlay.add_child(impact_overlay)
	centre_panel = PanelContainer.new()
	centre_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	centre_panel.offset_left = -310
	centre_panel.offset_right = 310
	centre_panel.offset_top = -115
	centre_panel.offset_bottom = 115
	centre_panel.add_theme_stylebox_override("panel",style("102722ed",12,20))
	overlay.add_child(centre_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	centre_panel.add_child(column)
	centre_label = label_("",18,"f5e7ce")
	centre_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	centre_label.custom_minimum_size.x = 560
	column.add_child(centre_label)
	var row := HBoxContainer.new()
	row.name = "RemoteActions"
	row.add_theme_constant_override("separation",10)
	column.add_child(row)
	button_("Invert Throttle",func(): inversions[3] = not inversions[3]; low_throttle_time = 0; save_settings(),row)
	button_("Open Controls",func(): leave_flight(); show_module("Drone & Controls"),row)
	button_("Copy Remote Report",copy_remote_report,row)
	centre_panel.visible = false

func update_flight_centre() -> void:
	if not is_instance_valid(centre_panel): return
	centre_panel.visible = in_flight and (remote_waiting_low or not crash_phase.is_empty() or finished)
	if not centre_panel.visible: return
	centre_panel.get_child(0).get_node("RemoteActions").visible = remote_waiting_low
	if remote_waiting_low:
		centre_label.text = "REMOTE FLIGHT IS OPEN\nLower throttle fully to arm the motors.\n\nThrottle %+.2f  /  %d%%     Low should be −1.00 / 0%%.\nIf fully down reads +1.00, use Invert Throttle.\nIf this number does not move, use Open Controls to map throttle." % [radio_axis(3),roundi((radio_axis(3)+1)*50)]
	elif finished: centre_label.text = status+"\n\nR: new attempt   •   Esc: menu"
	else: centre_label.text = "CRASH — MOTORS CUT\nImpact and recovery… %.1fs\n\n%s" % [maxf(0,crash_timer),"Assessment ends after this impact." if not crash_terminal.is_empty() else "Restarting at station %02d: %s. Earlier gates stay complete." % [next_gate+1,course.gates[next_gate].name]]

func update_remote_arming(delta: float) -> void:
	if not in_flight or finished or not remote_waiting_low or not crash_phase.is_empty(): return
	if joystick<0 or not remote_configuration_issue().is_empty():
		low_throttle_time = 0
		return
	if (radio_axis(3)+1)/2>0.10:
		low_throttle_time = 0
		throttle = 0
		return
	low_throttle_time += delta
	if low_throttle_time<0.20: return
	remote_waiting_low = false
	active = true
	drone.freeze = false
	throttle = 0
	previous_position = drone.position
	last_launch_action = "Remote motors armed after stable low throttle"
	status = "REMOTE ARMED — raise throttle gently. "+("GOD MODE" if not assessment and practice_god_mode else "CRASH MODE")

func update_crash_state(delta: float) -> void:
	if crash_phase.is_empty() or not active: return
	crash_timer -= delta
	if crash_timer>0: return
	if not crash_terminal.is_empty(): finish_run(crash_terminal)
	else: respawn_checkpoint()

func respawn_checkpoint() -> void:
	var data: Dictionary = course.gates[next_gate]
	var gate := gates[next_gate]
	var entry: Vector3 = O.sections(data)[0].center
	var position_: Vector3 = gate.to_global(entry+Vector3(0,0,3+SIZES.radius(drone_span)))
	if use_radio or assessment or not assisted: position_.y = SIZES.radius(drone_span)+0.06
	else: position_.y = maxf(position_.y,SIZES.radius(drone_span)+0.3)
	drone.freeze = true
	drone.call("request_reset",Transform3D(Basis(Vector3.UP,deg_to_rad(float(data.yaw_degrees))),position_))
	drone.linear_velocity = Vector3.ZERO
	drone.angular_velocity = Vector3.ZERO
	drone.set("previous_velocity",Vector3.ZERO)
	drone.linear_damp = 0.35
	drone.angular_damp = 3
	previous_position = position_
	section_index = 0
	throttle = 0
	crash_phase = ""
	crash_terminal = ""
	contact_cooldown = 1
	remote_waiting_low = use_radio
	low_throttle_time = 0
	active = not use_radio
	drone.freeze = use_radio
	status = "Checkpoint: station %02d. " % [next_gate+1]+("Lower throttle to re-arm, then raise it to fly." if use_radio else "Continue from this obstacle. Earlier gates are preserved.")

func update_feedback(delta: float) -> void:
	feedback_clock += delta
	impact_flash = maxf(0,impact_flash-delta*0.65)
	shake_strength = maxf(0,shake_strength-delta*0.30)
	if is_instance_valid(impact_overlay): impact_overlay.color = Color(0.95,0.22,0.10,impact_flash)
	if is_instance_valid(camera):
		camera.position = Vector3(sin(feedback_clock*71),sin(feedback_clock*83),0)*shake_strength
		camera.rotation_degrees.z = sin(feedback_clock*59)*shake_strength*15

func play_impact_sound(strength: float) -> void:
	if not motor_sound or DisplayServer.get_name()=="headless": return
	if not is_instance_valid(impact_audio):
		impact_audio = AudioStreamPlayer.new()
		add_child(impact_audio)
	var bytes := PackedByteArray()
	bytes.resize(6615*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 601
	for i in range(6615):
		var t := float(i)/22050
		var value := (sin(TAU*85*t)*0.4+rng.randf_range(-0.35,0.35))*exp(-t*18)
		bytes.encode_s16(i*2,int(value*32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.data = bytes
	impact_audio.stream = wav
	impact_audio.volume_db = -18+minf(strength,8)
	impact_audio.play()

func launch_from_popup() -> void:
	last_launch_action = "Start Remote Flight popup button pressed"
	if is_instance_valid(launch_dialog): launch_dialog.hide()
	launch_remote()

func remote_report() -> String:
	var rows := PackedStringArray([APP_TITLE+" v0.5 REMOTE REPORT","Device: "+(controller.device_name(joystick) if joystick>=0 else "NOT CONNECTED"),"Setup issue: "+remote_configuration_issue(),"State: in_flight=%s active=%s waiting_low=%s" % [in_flight,active,remote_waiting_low],"Last action: "+last_launch_action])
	for i in range(4):
		rows.append("%s axis=%d raw=%+.3f scaled=%+.3f inverted=%s endpoints=%s centre=%.3f" % [["Roll","Pitch","Yaw","Throttle"][i],axes[i],controller.axis(joystick,axes[i]) if joystick>=0 else 0,radio_axis(i),inversions[i],str(endpoints[i]),centers[i]])
	return "\n".join(rows)

func copy_remote_report() -> void:
	DisplayServer.clipboard_set(remote_report())
	status = "Remote report copied. Paste it into chat if launch still fails."

func open_browser_radio_test() -> void:
	var file := FileAccess.open("user://RadioTest-v0.5.html",FileAccess.WRITE)
	if not file:
		status = "Cannot create browser test page. Open RADIO-TEST.html beside the executable."
		return
	file.store_string(FileAccess.get_file_as_string("res://data/radio-test.html"))
	file.close()
	OS.shell_open(ProjectSettings.globalize_path("user://RadioTest-v0.5.html"))
