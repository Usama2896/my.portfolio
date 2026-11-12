extends Control
var lan: Node
func _ready() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void:
	visible = lan.connected and lan.prepared and lan.options.mode==0 and lan.host.in_flight
	if visible: queue_redraw()
func _draw() -> void:
	var stations: Array[Vector3] = lan.rules.stations()
	var target: Vector3 = stations[mini(lan.rules.leg+1,3)]+Vector3.UP*0.25
	var camera: Camera3D = get_viewport().get_camera_3d()
	var projected := camera.unproject_position(target) if not camera.is_position_behind(target) else Vector2(-1000,-1000)
	var color := Color("ffdf79")
	if Rect2(Vector2(30,250),size-Vector2(60,420)).has_point(projected):
		draw_arc(projected,22,0,TAU,32,Color.BLACK,5,true)
		draw_arc(projected,22,0,TAU,32,color,2,true)
		draw_line(projected-Vector2(12,0),projected+Vector2(12,0),color,2,true)
	else:
		var local := camera.to_local(target)
		var direction := Vector2(local.x,-local.y).normalized()
		if direction.length()<0.01: direction = Vector2.RIGHT
		var point := size/2+direction*minf(size.x,size.y)*0.30
		var side := Vector2(-direction.y,direction.x)
		draw_colored_polygon(PackedVector2Array([point+direction*18,point-direction*12+side*12,point-direction*12-side*12]),color)
	var panel := Rect2(Vector2(size.x-255,size.y-245),Vector2(235,185))
	draw_style_box(lan.host.style("102722e8",10,8),panel)
	var minimum := Vector2.ZERO
	var maximum := Vector2.ZERO
	for p in stations:
		minimum = minimum.min(Vector2(p.x,p.z))
		maximum = maximum.max(Vector2(p.x,p.z))
	var extent := (maximum-minimum).max(Vector2(30,30))
	var points: Array[Vector2] = []
	for i in range(4):
		var unit := (Vector2(stations[i].x,stations[i].z)-minimum)/extent
		var p := panel.position+Vector2(22,25)+unit*Vector2(190,135)
		points.append(p)
		if i>0: draw_line(points[i-1],p,Color("7fbc9d"),2,true)
		draw_circle(p,5,color if i==mini(lan.rules.leg+1,3) else Color("7fbc9d"))
		draw_string(ThemeDB.fallback_font,p+Vector2(6,-5),"SP" if i==0 else "LZ"+str(i),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
	for id in lan.rules.order:
		var p3: Vector3 = lan.rules.players[id].position
		var unit := (Vector2(p3.x,p3.z)-minimum)/extent
		var p := panel.position+Vector2(22,25)+unit*Vector2(190,135)
		draw_circle(p,4,Color("62fff0") if id==lan.local_id else Color("f29a83"))
