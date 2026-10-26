extends RefCounted
const O = preload("res://obstacles.gd")

static func build(root: Node3D) -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var atmosphere := ProceduralSkyMaterial.new()
	atmosphere.sky_top_color = Color("4e779e")
	atmosphere.sky_horizon_color = Color("d8d6b7")
	atmosphere.ground_horizon_color = Color("d8d6b7")
	atmosphere.ground_bottom_color = Color("727f56")
	sky.sky_material = atmosphere
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment = env
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32,-38,0)
	sun.light_color = Color("fff0ca")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65
	root.add_child(sun)
	var ground := O.box(root,Vector3(-8,-0.3,-8),Vector3(400,0.5,400),Color("667951"))
	var grass := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
	varying vec3 world_pos;
	void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
	float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
	float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
	void fragment(){float n=noise(world_pos.xz*0.4)*0.65+noise(world_pos.xz*4.0)*0.35;ALBEDO=mix(vec3(0.13,0.19,0.075),vec3(0.24,0.29,0.13),n);ROUGHNESS=0.95;}
	"""
	grass.shader = shader
	ground.material_override = grass
	var rng := RandomNumberGenerator.new()
	rng.seed = 714
	# White perimeter, path and start grid.
	for x in [-38,22]: O.box(root,Vector3(x,-0.025,-8),Vector3(0.07,0.03,60),Color("c8c5a0"),false)
	for z in [-38,22]: O.box(root,Vector3(-8,-0.025,z),Vector3(60,0.03,0.07),Color("c8c5a0"),false)
	for i in range(8):
		for j in range(2):
			O.box(root,Vector3(-1.75+i*0.5,-0.015,2+j*0.5),Vector3(0.5,0.025,0.5),Color("ecedd7") if (i+j)%2==0 else Color("263d3a"),false)
	# Trees outside the flight area.
	for i in range(85):
		var angle := rng.randf_range(0,TAU)
		var distance_ := rng.randf_range(32,72)
		var pos := Vector3(-8+cos(angle)*distance_,0,-8+sin(angle)*distance_)
		var height := rng.randf_range(4,9)
		O.box(root,pos+Vector3(0,height*0.3,0),Vector3(0.28,height*0.6,0.28),Color("554c36"),false)
		var canopy := MeshInstance3D.new()
		var crown := SphereMesh.new()
		crown.radius = height*0.26
		crown.height = height*0.62
		crown.radial_segments = 12
		crown.rings = 6
		canopy.mesh = crown
		canopy.scale = Vector3(1.15,1,0.9)
		canopy.position = pos+Vector3(0,height*0.7,0)
		canopy.material_override = O.material(Color("526644")*rng.randf_range(0.8,1.2))
		root.add_child(canopy)
	# Training shelter and benches.
	O.box(root,Vector3(7,2.4,5),Vector3(6,0.2,5),Color("263e43"))
	for x in [4.5,9.5]:
		for z in [3.0,7.0]: O.box(root,Vector3(x,1.2,z),Vector3(0.1,2.4,0.1),Color("aab6a4"))
	for z in [4,6]:
		O.box(root,Vector3(7,0.55,z),Vector3(3,0.12,0.5),Color("bca477"))
	# Flat Punjab-inspired farmland beyond the training area, with field bunds,
	# irrigation channels, brick farm buildings and broadleaf shelter belts.
	for i in range(12):
		var x := -100.0+(i%6)*32
		var z := -80.0 if i<6 else 55.0
		O.box(root,Vector3(x,-0.025,z),Vector3(29,0.02,28),Color("a79852") if i%3==0 else Color("7d874b"),false)
		for j in range(10): O.box(root,Vector3(x-13+j*2.7,0,z),Vector3(0.12,0.05,27),Color("8b874e"),false)
		O.box(root,Vector3(x+15,0.01,z),Vector3(0.65,0.08,28),Color("9b9069"),false)
	O.box(root,Vector3(-8,-0.015,40),Vector3(180,0.025,2),Color("638f98"),false)
	for x in [-65.0,65.0]:
		O.box(root,Vector3(x,2,-42),Vector3(9,4,7),Color("9a7359"),false)
		O.box(root,Vector3(x,4.1,-42),Vector3(9.6,0.2,7.6),Color("c0ad8a"),false)
		O.box(root,Vector3(x,1.2,-38.45),Vector3(1.4,2.4,0.04),Color("4b5143"),false)
