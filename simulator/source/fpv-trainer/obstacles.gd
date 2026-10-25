extends RefCounted
# All geometry is generated locally; collision segments match each visible frame.
const TYPES = ["ring", "hexagon", "zigzag", "precision", "triple", "corridor", "tunnel", "u_tunnel", "kz", "triangle", "square", "diamond", "arch", "ladder", "dive", "hurdle", "flag"]
const NAMES = ["Circular Ring", "Hexagon", "Zig Zag", "Precision Gate", "Triple Ring", "Multi Frame Corridor", "Tunnel", "U-Tunnel", "KZ", "Triangle Gate", "Square Gate", "Diamond Gate", "Arch Gate", "Ladder Gate", "Dive Ring", "Hurdle", "Flag Turn"]

static func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.86
	return m

static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid := true) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.position = pos
	mesh.material_override = material(color)
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		body.position = pos
		var collision := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		collision.shape = bounds
		body.add_child(collision)
		parent.add_child(body)
	return mesh

static func beam(parent: Node3D, a: Vector3, b: Vector3, thickness: float, color: Color) -> void:
	var node := Node3D.new()
	node.position = (a+b)/2
	parent.add_child(node)
	if a.distance_to(b) < 0.01: return
	node.look_at_from_position(node.global_position, parent.to_global(b), Vector3.UP if absf((b-a).normalized().y)<0.95 else Vector3.RIGHT)
	box(node, Vector3.ZERO, Vector3(thickness,thickness,a.distance_to(b)+thickness*0.3),color)

static func sections(data: Dictionary) -> Array[Dictionary]:
	var kind: String = data.get("type","ring")
	var depth: float = data.get("depth",3.0)
	var out: Array[Dictionary] = []
	var count := 1
	if kind in ["tunnel","corridor","u_tunnel"]: count = 5
	if kind == "zigzag": count = 5
	for i in range(count):
		var x := 0.0
		var z := -depth*float(i)/maxi(1,count-1)
		if kind == "zigzag": x = float(data.width)*0.35*(1 if i%2==0 else -1)
		if kind == "flag": x = float(data.width)*0.35
		if kind == "u_tunnel": x = sin(float(i)*PI/4)*1.2
		out.append({"center":Vector3(x,0,z),"kind":kind})
	return out

static func polygon(kind: String, width: float, height: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := 32 if kind in ["ring","triple","tunnel","u_tunnel","dive"] else 6
	if kind == "triangle":
		return PackedVector2Array([Vector2(-width/2,-height/2),Vector2(width/2,-height/2),Vector2(0,height/2)])
	if kind == "diamond":
		return PackedVector2Array([Vector2(0,-height/2),Vector2(width/2,0),Vector2(0,height/2),Vector2(-width/2,0)])
	if kind == "arch":
		points.append(Vector2(-width/2,-height/2))
		points.append(Vector2(width/2,-height/2))
		points.append(Vector2(width/2,0))
		for i in range(1,17):
			var angle := PI*i/16.0
			points.append(Vector2(cos(angle)*width/2,sin(angle)*height/2))
		return points
	if kind in ["precision","zigzag","corridor","kz","square","ladder","hurdle","flag"]:
		return PackedVector2Array([Vector2(-width/2,-height/2),Vector2(width/2,-height/2),Vector2(width/2,height/2),Vector2(-width/2,height/2)])
	for i in range(count):
		var angle := TAU*i/count + (PI/6 if count==6 else 0.0)
		points.append(Vector2(cos(angle)*width/2,sin(angle)*height/2))
	return points

static func holes(data: Dictionary) -> Array[Vector2]:
	if data.get("type","") == "ladder":
		return [Vector2(0,-float(data.opening_height)/3),Vector2.ZERO,Vector2(0,float(data.opening_height)/3)]
	if data.get("type","") == "triple":
		var w: float = data.width
		var h: float = data.opening_height
		return [Vector2(-w*0.32,-h*0.20),Vector2(w*0.32,-h*0.20),Vector2(0,h*0.36)]
	return [Vector2.ZERO]

static func fits(data: Dictionary, point: Vector3, section: int, radius := 0.18) -> bool:
	var center: Vector3 = sections(data)[section].center
	var width: float = data.width
	var height: float = data.opening_height
	if data.get("type","") == "triple":
		width *= 0.60
		height *= 0.60
	if data.get("type","") in ["zigzag","flag"]: width *= 0.5
	if data.get("type","") == "ladder": height /= 3.0
	for offset in holes(data):
		var poly := polygon(data.get("type","ring"),width,height)
		var p := Vector2(point.x-center.x,point.y-center.y)-offset
		if not Geometry2D.is_point_in_polygon(p,poly): continue
		var safe := true
		for i in range(poly.size()):
			var near := Geometry2D.get_closest_point_to_segment(p,poly[i],poly[(i+1)%poly.size()])
			if near.distance_to(p) < radius: safe = false
		if safe: return true
	return false

static func build(parent: Node3D, data: Dictionary, index: int) -> Node3D:
	var gate := Node3D.new()
	parent.add_child(gate)
	gate.position = Vector3(data.x,data.height,data.z)
	gate.rotation_degrees.y = data.yaw_degrees
	var kind: String = data.get("type","ring")
	if kind == "dive": gate.rotation_degrees.x = -90
	var color := Color("268575")
	if kind in ["kz","tunnel"]: color = Color("bb6339")
	elif kind in ["precision","zigzag","triple"]: color = Color("bda13c")
	var width: float = data.width
	var height: float = data.opening_height
	var sec := sections(data)
	for s in range(sec.size()):
		var c: Vector3 = sec[s].center
		if kind in ["zigzag","flag"]:
			var pole_height := float(data.height)+height/2
			var pole := box(gate,Vector3(0,pole_height/2-float(data.height),c.z),Vector3(0.10,pole_height,0.10),color)
			pole.name = "SlalomPole%02d" % s
			box(gate,Vector3(0,-float(data.height)+0.04,c.z),Vector3(0.55,0.08,0.55),Color("344943"))
			if kind == "flag": box(gate,Vector3(0.28,height/2-0.3,c.z),Vector3(0.5,0.5,0.025),color,false)
			continue
		if kind == "hurdle":
			beam(gate,Vector3(-width/2,-height/2,0),Vector3(width/2,-height/2,0),0.10,color)
			for side in [-1,1]:
				beam(gate,Vector3(side*width/2,-float(data.height),0),Vector3(side*width/2,-height/2+0.2,0),0.10,color)
			continue
		for offset in holes(data):
			var scale_ := 0.60 if kind == "triple" else 1.0
			var poly := polygon(kind,width*scale_,height*scale_/3 if kind=="ladder" else height*scale_)
			for j in range(poly.size()):
				var a := Vector3(poly[j].x+offset.x,poly[j].y+offset.y,0)+c
				var n := poly[(j+1)%poly.size()]
				var b := Vector3(n.x+offset.x,n.y+offset.y,0)+c
				beam(gate,a,b,0.09,color)
				if s>0 and j%4==0 and kind in ["tunnel","u_tunnel","corridor"]:
					beam(gate,a,a-c+sec[s-1].center,0.045,Color("354c3e"))
				# Fabric panels cover the upper half of tunnel sections, leaving the bore open.
				if s>0 and kind in ["tunnel","u_tunnel"] and poly[j].y > -0.1:
					var p0: Vector3 = a-c+sec[s-1].center
					var p1: Vector3 = b-c+sec[s-1].center
					var st := SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					for v in [a,b,p0,b,p1,p0]: st.add_vertex(v)
					st.generate_normals()
					var cover := MeshInstance3D.new()
					cover.mesh = st.commit()
					var mat := material(Color("6e7752"))
					mat.cull_mode = BaseMaterial3D.CULL_DISABLED
					cover.material_override = mat
					gate.add_child(cover)
					cover.create_trimesh_collision()
					for child in cover.get_children():
						if child is StaticBody3D:
							for collision in child.get_children():
								if collision is CollisionShape3D and collision.shape is ConcavePolygonShape3D: collision.shape.backface_collision = true
		if kind == "dive":
			var stand := Node3D.new()
			gate.add_child(stand)
			stand.rotation_degrees.x = 90
			for side in [-1,1]:
				beam(stand,Vector3(side*width/2,0,0),Vector3(side*width/2,-float(data.height),0),0.06,Color("344943"))
			continue
		# Supports attach to the actual opening shape, not an invisible rectangle.
		var support_x := width*0.5
		var support_y := -height*0.5
		if kind in ["ring","tunnel","u_tunnel"]:
			support_x = width*0.35355
			support_y = -height*0.35355
		if kind == "diamond":
			support_y = 0
		if kind == "hexagon":
			support_x = width*0.433
			support_y = -height*0.25
		if kind == "triple":
			support_x = width*0.32
			support_y = -height*0.50
		for side in [-1,1]:
			beam(gate,c+Vector3(side*support_x,support_y,0),c+Vector3(side*support_x,-float(data.height),0),0.055,Color("344943"))
			box(gate,c+Vector3(side*support_x,-float(data.height)+0.04,0),Vector3(0.5,0.08,0.7),Color("344943"))
	if kind == "triple":
		var centers_ := holes(data)
		for pair in [[0,1],[0,2],[1,2]]:
			var a2: Vector2 = centers_[pair[0]]
			var b2: Vector2 = centers_[pair[1]]
			var direction := (b2-a2).normalized()
			var a3 := a2+direction*width*0.30
			var b3 := b2-direction*width*0.30
			beam(gate,Vector3(a3.x,a3.y,0),Vector3(b3.x,b3.y,0),0.10,color)
	if kind == "kz":
		for side in [-1,1]:
			beam(gate,Vector3(side*width/2,height/2,0),Vector3(side*width/2,height/2+1.0,0),0.10,color)
		beam(gate,Vector3(-width/2,height/2+1,0),Vector3(width/2,height/2+1,0),0.10,color)
	var sign_ := Label3D.new()
	sign_.text = "%02d  %s" % [index+1,data.name.to_upper()]
	sign_.position = Vector3(0,height/2+0.5+(1 if kind=="kz" else 0),0)
	sign_.font_size = 38
	sign_.pixel_size = 0.0055
	sign_.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_.modulate = Color("f5f1dc")
	gate.add_child(sign_)
	return gate

static func apply_preset(data: Dictionary, kind: String) -> void:
	data.type = kind
	data.name = NAMES[TYPES.find(kind)]
	data.width = 2.4
	data.opening_height = 2.4
	data.height = 2.0
	data.depth = 3.0
	match kind:
		"zigzag": data.depth = 8.0
		"precision": data.width = 1.5; data.opening_height = 2.2
		"triple": data.width = 3.6; data.opening_height = 3.6; data.height = 2.3
		"ladder": data.opening_height = 6.0; data.height = 3.2
		"tunnel", "u_tunnel": data.opening_height = 2.0; data.height = 1.5
		"dive": data.height = 4.0
		"hurdle": data.height = 1.8; data.opening_height = 2.4
