extends Node3D
const RULES = preload("res://civilian_rules.gd")
const O = preload("res://obstacles.gd")
var host: Node
var running := false
var rules = RULES.new()
var scenery: Node3D
var backup: Dictionary = {}
var distance_ := 40.0
var pad_size := 4.0
var delivery := true
var view_mode := 0
var view_camera: Camera3D
var visual: Node3D
var unload_button: Button
var parcel: MeshInstance3D
var service_panel: HBoxContainer
var saved := false
func menu() -> void:
	host.content.add_child(host.label_("CIVILIAN CAMERA DRONE",25,"79e5c2"))
	host.paragraph("Ground-service missions in an offline woodland park. Gentle, level controls; no aerial parcel release. Take off, fly to the pad and land smoothly.")
	var event := OptionButton.new()
	event.add_item("Parcel Delivery — land, unload, return")
	event.add_item("Landing Practice — touchdown feedback")
	event.select(0 if delivery else 1)
	event.item_selected.connect(func(i): delivery = i==0)
	host.content.add_child(event)
	host.field("Route length m",distance_,20,200,10,func(v): distance_ = v)
	host.field("Square pad width m",pad_size,2,8,0.5,func(v): pad_size = v)
	host.paragraph("W/S forward/back · A/D sideways · Q/E turn · Up/Down climb/descend. Centre/release to stop. Hold Down or fully low throttle to settle on the pad for two seconds. USB radios use your existing saved mapping; fully low throttle still cuts motors.")
	host.button_("Start with Keyboard",func(): start(false),null,true)
	host.button_("Start with USB Radio",func(): start(true))
	host.paragraph("U unloads only after a grounded, stable landing on the destination pad. Use View to switch follow / forward / landing camera. Esc opens the menu. Camera-drone tasks are separate from FPV obstacle and relay events.")
func start(radio: bool) -> bool:
	if host.lan.connected: host.status = "Leave the LAN room before starting a civilian mission."; return false
	if running: stop()
	if not host.license_memory.is_active() or host.splash_remaining>0: host.status = "Activate this PC and wait for the title screen."; return false
	host.use_radio = radio
	host.poll_radio()
	if radio and not host.remote_configuration_issue().is_empty(): host.status = host.remote_configuration_issue(); return false
	backup.course = host.course.duplicate(true)
	for key in ["practice_basic","practice_stabilized","practice_god_mode","assisted","battery_enabled","wind"]: backup[key] = host.get(key)
	host.practice_basic = true
	host.practice_stabilized = false
	host.practice_god_mode = false
	host.assisted = true
	host.battery_enabled = false
	host.wind = 0
	if not host.start_flight(false): restore_preferences(); return false
	running = true
	host.started = true
	saved = false
	rules = RULES.new()
	rules.delivery = delivery
	rules.destination = Vector3(0,0,-distance_)
	rules.pad_size = pad_size
	build_park()
	host.drone.request_reset(Transform3D(Basis.IDENTITY,Vector3(0,host.drone_span/2+0.02,0)))
	host.previous_position = host.drone.position
	host.status = rules.message
	return true
func build_park() -> void:
	for item in host.solo_world_nodes:
		if item is Node3D: item.hide()
		if item is CollisionObject3D: item.collision_layer = 0
	host.gate_root.hide()
	for body in host.gate_root.find_children("*","CollisionObject3D",true,false): body.collision_layer = 0
	host.experience.route.hide()
	scenery = Node3D.new()
	add_child(scenery)
	var ground := O.box(scenery,Vector3(0,-0.3,-distance_/2),Vector3(180,0.5,distance_+180),Color("52633e"))
	for item in host.solo_world_nodes:
		if item is MeshInstance3D and item.material_override is ShaderMaterial:
			ground.material_override = item.material_override.duplicate()
			break
	for point in [rules.home,rules.destination]:
		O.box(scenery,point+Vector3(0,-0.018,0),Vector3(pad_size,0.025,pad_size),Color("abbfae"),false)
		for side in [-1,1]:
			O.box(scenery,point+Vector3(side*pad_size/2,0,0),Vector3(0.10,0.02,pad_size),Color("fff0a1"),false)
			O.box(scenery,point+Vector3(0,0,side*pad_size/2),Vector3(pad_size,0.02,0.10),Color("fff0a1"),false)
		var sign_ := Label3D.new()
		sign_.text = "HOME" if point==rules.home else "DELIVERY PAD" if delivery else "PRACTICE PAD"
		sign_.position = point+Vector3(0,2,-pad_size/2-1)
		sign_.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign_.font_size = 48
		scenery.add_child(sign_)
	O.box(scenery,Vector3(0,-0.025,-distance_/2),Vector3(2,0.02,distance_),Color("48504b"),false)
	for i in range(int(distance_/4)):
		O.box(scenery,Vector3(0,-0.008,-2-i*4),Vector3(0.1,0.02,1.2),Color("e5ddbd"),false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 507
	for i in range(80):
		var p := Vector3(rng.randf_range(9,48)*(1 if i%2==0 else -1),0,rng.randf_range(-distance_-20,20))
		var height := rng.randf_range(3,7)
		O.box(scenery,p+Vector3.UP*height/2,Vector3(0.23,height,0.23),Color("5f4a32"),false)
		var crown := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = height*0.3
		sphere.height = height*0.75
		crown.mesh = sphere
		crown.position = p+Vector3.UP*height
		crown.material_override = O.material(Color("36553a")*rng.randf_range(0.8,1.3))
		scenery.add_child(crown)
		var shrub := MeshInstance3D.new()
		var leaves := SphereMesh.new()
		leaves.radius = 0.7
		leaves.height = 0.9
		shrub.mesh = leaves
		shrub.position = p+Vector3(1,0.4,1)
		shrub.material_override = O.material(Color("4b693b"))
		scenery.add_child(shrub)
	visual = Node3D.new()
	scenery.add_child(visual)
	var span: float = host.drone_span
	O.box(visual,Vector3.ZERO,Vector3(span*0.7,0.07,span*0.15),Color("d5e4df"),false)
	O.box(visual,Vector3.ZERO,Vector3(span*0.15,0.07,span*0.7),Color("d5e4df"),false)
	O.box(visual,Vector3(0,-0.03,-span*0.25),Vector3(0.05,0.04,0.04),Color("273e47"),false)
	for x in [-0.32,0.32]:
		for z in [-0.32,0.32]:
			var prop := MeshInstance3D.new()
			var disc := CylinderMesh.new()
			disc.top_radius = span*0.18
			disc.bottom_radius = span*0.18
			disc.height = 0.01
			disc.radial_segments = 16
			prop.mesh = disc
			prop.position = Vector3(x*span,0.05,z*span)
			prop.material_override = O.material(Color("344e4b"))
			visual.add_child(prop)
	parcel = O.box(scenery,Vector3.ZERO,Vector3(0.24,0.16,0.20),Color("b78b58"),false)
	parcel.visible = delivery
	view_camera = Camera3D.new()
	view_camera.far = 1500
	scenery.add_child(view_camera)
	service_panel = HBoxContainer.new()
	service_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	service_panel.offset_left = -550
	service_panel.offset_top = 130
	service_panel.offset_right = -20
	host.overlay.add_child(service_panel)
	host.button_("View: follow / forward / landing",cycle_view,service_panel)
	if delivery: unload_button = host.button_("Unload [U]",unload,service_panel)
func cycle_view() -> void: view_mode = (view_mode+1)%3
func unload() -> bool:
	if not running or not host.active or host.pause_open(): return false
	# Recheck current physical contact and pose, rather than trusting an old hold.
	rules.sample(0,host.drone.position,host.drone.linear_velocity,host.drone.basis.y,host.drone_span,host.drone.get_contact_count()>0)
	if not rules.unload(): host.status = "Land fully on the pad and remain stable for two seconds before unloading."; return false
	parcel.position = rules.destination+Vector3(0,0.08,0)
	host.status = rules.message
	host.experience.tone(650)
	return true
func _physics_process(delta: float) -> void:
	if not running: return
	if host.active and not host.finished and not host.remote_waiting_low:
		rules.sample(delta,host.drone.position,host.drone.linear_velocity,host.drone.basis.y,host.drone_span,host.drone.get_contact_count()>0)
	visual.transform = host.drone.transform
	if is_instance_valid(unload_button): unload_button.disabled = not (rules.landed and rules.phase=="outbound" and host.active and not host.pause_open())
	if delivery and not rules.delivered: parcel.position = host.drone.position+Vector3(0,-0.02,0)
	host.minimap.hide()
	host.guide.hide()
	host.guidance.hide()
	host.target_label.text = ("PARCEL DELIVERY" if delivery else "LANDING PRACTICE")+" · "+rules.phase.to_upper()+" · %.1f m to pad" % host.drone.position.distance_to(rules.target())
	host.flight_status.text = "Centred landing hold %.1f / 2 s · offset %.2f m · speed %.2f m/s · Esc: menu" % [minf(2,rules.hold),rules.offset,host.drone.linear_velocity.length()]
	host.elapsed = rules.elapsed
	if not host.remote_waiting_low: host.status = rules.message
	if rules.phase in ["complete","failed"]:
		host.finished = true
		host.active = false
		host.drone.freeze = true
		host.centre_panel.show()
		host.centre_label.text = rules.message+"\nTime %.1f s · pad offset %.2f m · descent %.2f m/s\nEsc: menu" % [rules.elapsed,rules.offset,rules.descent_speed]
		if not saved: save_result(); saved = true
	update_camera()
func update_camera() -> void:
	if view_mode==1: host.camera.current = true; return
	var p: Vector3 = host.drone.position
	if view_mode==0:
		view_camera.position = p+Basis(Vector3.UP,host.drone.rotation.y)*Vector3(0,1.6,2.8)
		view_camera.look_at(p+Vector3.UP*0.25)
	else:
		view_camera.position = p+Vector3.UP*2
		view_camera.look_at(p,Vector3.FORWARD)
	view_camera.current = true
func fail(reason: String) -> void:
	if running: rules.fail(reason)
func save_result() -> void:
	var result := {"timestamp":Time.get_datetime_string_from_system(),"pilot":host.trainee,"mode":"Civilian Parcel Delivery" if delivery else "Civilian Landing Practice","result":rules.message,"seconds":rules.elapsed,"crashes":1 if rules.phase=="failed" else 0,"score":"Practice feedback","contacts":0,"course":"Woodland park","pad_offset_m":rules.offset,"descent_mps":rules.descent_speed}
	var file := FileAccess.open(host.RESULTS_PATH,FileAccess.READ_WRITE if FileAccess.file_exists(host.RESULTS_PATH) else FileAccess.WRITE)
	if file:
		file.seek_end()
		file.store_line(JSON.stringify(result))
func restore_preferences() -> void:
	for key in backup:
		if key!="course": host.set(key,backup[key])
	backup.clear()
func stop() -> void:
	if not running: return
	running = false
	host.leave_flight()
	if is_instance_valid(scenery): scenery.queue_free()
	if is_instance_valid(service_panel): service_panel.queue_free()
	for item in host.solo_world_nodes:
		if item is Node3D: item.show()
		if item is CollisionObject3D: item.collision_layer = 1
	host.gate_root.show()
	for body in host.gate_root.find_children("*","CollisionObject3D",true,false): body.collision_layer = 1
	host.experience.route.visible = host.ground_route
	restore_preferences()
