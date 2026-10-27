extends Node3D
const O = preload("res://obstacles.gd")
var host: Node
var route: Node3D
var battery_used := 0.0
var depleted := false
var falling := 0.0
var warning_bucket := -1
var audio: AudioStreamPlayer
var clock := 0.0
var rain: CPUParticles3D
func _ready() -> void:
	audio = AudioStreamPlayer.new()
	add_child(audio)
	rain = CPUParticles3D.new()
	rain.amount = 160
	rain.lifetime = 1.2
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(12,5,12)
	rain.direction = Vector3(0,-1,0)
	rain.spread = 5
	rain.initial_velocity_min = 9
	rain.initial_velocity_max = 13
	rain.gravity = Vector3(1,-4,0)
	var drop := CylinderMesh.new()
	drop.top_radius = 0.006
	drop.bottom_radius = 0.006
	drop.height = 0.30
	drop.radial_segments = 4
	drop.material = O.material(Color("91adb8"))
	rain.mesh = drop
	add_child(rain)
	apply_weather()
	rebuild_route()
func reset_battery() -> void:
	battery_used = 0
	depleted = false
	falling = 0
	warning_bucket = -1
func remaining() -> float: return maxf(0,host.battery_minutes*60-battery_used)
func tick(delta: float) -> void:
	clock += delta
	if is_instance_valid(host.camera): rain.global_position = host.camera.global_position+Vector3.UP*4
	if not host.in_flight or host.finished or not host.active: return
	if host.battery_enabled:
		if not host.remote_waiting_low and host.crash_phase.is_empty(): battery_used += delta
		var bucket := int(ceil(remaining()/10))
		if remaining()<=30 and bucket!=warning_bucket:
			warning_bucket = bucket
			tone(420,0.18)
		if remaining()<=0 and not depleted:
			depleted = true
			host.throttle = 0
			host.drone.angular_velocity = Vector3(0.5,0,0.6)
			host.status = "BATTERY EMPTY — motors off. Falling; press R for a fresh battery."
			tone(180,0.5)
	if depleted:
		falling += delta
		if host.drone.position.y<=host.drone_span/2+0.1 or falling>8: host.finish_run("Battery depleted — flight ended")
func wind_force() -> Vector3:
	var direction := deg_to_rad(host.wind_direction)
	var gust: float = 1.0+sin(clock*1.8)*host.gust_strength*0.45+sin(clock*4.3)*host.gust_strength*0.2
	return Vector3(cos(direction),0,sin(direction))*host.wind*gust*host.mass*0.3
func tone(frequency: float, duration := 0.14) -> void:
	if not host.motor_sound or DisplayServer.get_name()=="headless": return
	var bytes := PackedByteArray()
	var count := int(22050*duration)
	bytes.resize(count*2)
	for i in range(count):
		var t := float(i)/22050
		bytes.encode_s16(i*2,int(sin(TAU*frequency*t)*sin(PI*i/count)*6500))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.data = bytes
	audio.stream = wav
	audio.volume_db = -14
	audio.play()
func vibrate(strength: float) -> void:
	if host.vibration_enabled and host.joystick in Input.get_connected_joypads():
		Input.start_joy_vibration(host.joystick,clampf(strength/10,0.15,1),0.6,0.22)
func apply_weather() -> void:
	if is_instance_valid(rain): rain.emitting = host.weather==4
	var palettes := [Color("84b4d8"),Color("b7b9a2"),Color("9caebf"),Color("8bacae"),Color("535e71")]
	for child in host.get_children():
		if child is WorldEnvironment:
			var sky: ProceduralSkyMaterial = child.environment.sky.sky_material
			sky.sky_top_color = palettes[host.weather]
			sky.sky_horizon_color = palettes[host.weather].lightened(0.18)
			child.environment.ambient_light_energy = 0.42 if host.weather!=4 else 0.26
		if child is DirectionalLight3D:
			child.light_energy = [1.0,1.15,0.65,0.75,0.30][host.weather]*host.scene_brightness
			child.light_color = Color("ffe1a3") if host.weather==1 else Color("dceaff") if host.weather==2 else Color("fff0d5")
func rebuild_route() -> void:
	if is_instance_valid(route):
		remove_child(route)
		route.queue_free()
	route = Node3D.new()
	route.name = "GroundRoute"
	add_child(route)
	route.visible = host.ground_route
	var points: Array[Vector3] = []
	for i in range(host.gates.size()):
		var gate: Node3D = host.gates[i]
		for section in O.sections(host.course.gates[i]):
			var p: Vector3 = gate.to_global(section.center)
			p.y = -0.025
			if points.is_empty() or points[-1].distance_to(p)>0.1: points.append(p)
	if points.size()<2: return
	# A continuous collision-free track; only visual. Arrows show course order.
	for i in range(points.size()-1):
		var a := points[i]
		var b := points[i+1]
		var length_ := a.distance_to(b)
		var direction := (b-a).normalized()
		var side := direction.cross(Vector3.UP)
		var strip := O.box(route,(a+b)/2,Vector3(1.25,0.012,length_),Color("77664b"),false)
		strip.rotation.y = atan2(direction.x,direction.z)
		for sign_ in [-1,1]:
			var edge := O.box(route,(a+b)/2+side*sign_*0.64+Vector3.UP*0.008,Vector3(0.045,0.012,length_),Color("eee5b7"),false)
			edge.rotation.y = strip.rotation.y
		for j in range(int(length_/2.5)):
			var p: Vector3 = a+direction*(j*2.5+1.0)+Vector3.UP*0.025
			for sign_ in [-1,1]:
				var end: Vector3 = p-direction*0.35+side*sign_*0.25
				var mark := O.box(route,(p+end)/2,Vector3(0.06,0.012,p.distance_to(end)),Color("fff5d1"),false)
				mark.rotation.y = atan2((p-end).x,(p-end).z)
