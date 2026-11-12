extends RefCounted
const O = preload("res://obstacles.gd")
static func label(parent: Node3D, text: String, position_: Vector3, size_ := 70) -> void:
	var sign_ := Label3D.new()
	sign_.text = text
	sign_.font_size = size_
	sign_.pixel_size = 0.012
	sign_.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_.position = position_
	parent.add_child(sign_)
static func build(parent: Node3D, options: Dictionary, stations: Array[Vector3]) -> void:
	var terrain: int = options.terrain
	var reach := maxf(maxf(options.legs[0],options.legs[1]),options.legs[2])
	O.box(parent,Vector3(-reach/2,-0.3,-reach/2),Vector3(reach*4+300,0.5,reach*4+300),[Color("666e50"),Color("b49b68"),Color("6b716d")][terrain])
	for i in range(4 if options.mode==0 else 0):
		var p := stations[i]
		var pad := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = options.radius
		cylinder.bottom_radius = options.radius
		cylinder.height = 0.015
		pad.mesh = cylinder
		pad.position = p+Vector3(0,-0.012,0)
		pad.material_override = O.material(Color("f4d675"))
		parent.add_child(pad)
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = options.radius-0.015
		torus.outer_radius = options.radius+0.015
		ring.mesh = torus
		ring.material_override = O.material(Color("ea7138"))
		ring.position = p
		parent.add_child(ring)
		label(parent,"START / PILOT 1" if i==0 else "LZ %d / %s" % [i,"FINISH" if i==3 else "HANDOFF"],p+Vector3.UP*3)
		for side in [-1,1]: O.box(parent,p+Vector3(side*(options.radius+1),1.3,side*(options.radius+1)),Vector3(0.06,2.6,0.06),Color("f3d477"),false)
	for i in range(3 if options.mode==0 else 0):
		var a := stations[i]
		var b := stations[i+1]
		var length_ := a.distance_to(b)
		var stripe := O.box(parent,(a+b)/2+Vector3(0,-0.018,0),Vector3(2,0.02,length_),Color("8d8060") if terrain!=2 else Color("3c4141"),false)
		stripe.rotation.y = atan2((b-a).x,(b-a).z)
		var steps := mini(100,maxi(2,int(length_/6)))
		for j in range(steps):
			var p := a.lerp(b,(j+0.5)/steps)
			var dash := O.box(parent,p+Vector3.UP*0.005,Vector3(0.12,0.02,minf(1.5,length_/steps*0.3)),Color("f2d790"),false)
			dash.rotation.y = stripe.rotation.y
		label(parent,"LEG %d — %.0f m" % [i+1,length_],(a+b)/2+Vector3.UP*4,90)
	var rng := RandomNumberGenerator.new()
	rng.seed = 912+terrain
	# Geometry count stays bounded even for kilometre-long routes.
	for i in range(54):
		var route_leg := i%3
		var a := stations[route_leg]
		var b := stations[route_leg+1]
		var direction := (b-a).normalized()
		var side := direction.cross(Vector3.UP)
		var p := a.lerp(b,rng.randf_range(0.03,0.97))+side*(1 if i%2==0 else -1)*rng.randf_range(18,65)
		var clear := true
		if options.mode==0:
			for leg in range(3):
				var closest := Geometry3D.get_closest_point_to_segment(p,stations[leg],stations[leg+1])
				if p.distance_to(closest)<(25 if terrain!=2 else 15): clear = false
		if not clear: continue
		if options.mode==1 and maxf(absf(p.x),absf(p.z))<125:
			p = Vector3(p.x,0,p.z).normalized()*rng.randf_range(150,200)
		if terrain==2:
			var h := rng.randf_range(5,24)
			O.box(parent,p+Vector3.UP*h/2,Vector3(8,h,8),Color("a0a293")*rng.randf_range(0.65,1.1))
			for floor_ in range(int(h/3)):
				O.box(parent,p+Vector3(0,2+floor_*3,4.02),Vector3(5,0.9,0.03),Color("4f6975"),false)
		else:
			var mound := MeshInstance3D.new()
			var mesh_: PrimitiveMesh
			if terrain==0:
				var cone := CylinderMesh.new()
				cone.top_radius = 1
				cone.bottom_radius = rng.randf_range(9,16)
				cone.height = rng.randf_range(18,48)
				cone.radial_segments = 9
				mesh_ = cone
				p.y = cone.height/2-1
			else:
				var sphere := SphereMesh.new()
				sphere.radius = 10
				sphere.height = 20
				mesh_ = sphere
				mound.scale = Vector3(1.5,0.35,1)
				p.y = -0.8
			mound.mesh = mesh_
			mound.position = p
			mound.material_override = O.material(Color("777d70") if terrain==0 else Color("c4a66c"))
			parent.add_child(mound)
			mound.create_trimesh_collision()
