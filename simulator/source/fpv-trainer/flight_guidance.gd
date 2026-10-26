extends Control
var host: Node
var instruction: Label
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	instruction = Label.new()
	instruction.position = Vector2(24,128)
	instruction.add_theme_font_size_override("font_size",17)
	instruction.add_theme_color_override("font_color",Color("b2ffe4"))
	instruction.add_theme_color_override("font_shadow_color",Color.BLACK)
	instruction.add_theme_constant_override("shadow_offset_x",2)
	instruction.add_theme_constant_override("shadow_offset_y",2)
	add_child(instruction)
func _process(_delta: float) -> void:
	visible = is_instance_valid(host) and is_instance_valid(host.guidance) and host.guidance.visible
	if visible: queue_redraw()
func _draw() -> void:
	if not is_instance_valid(host) or not is_instance_valid(host.guidance) or not host.guidance.visible: return
	var middle := size/2
	var color := Color("a5ffe1")
	for axis in [Vector2.RIGHT,Vector2.DOWN]:
		for side in [-1,1]:
			var a: Vector2 = middle+axis*side*5
			var b: Vector2 = middle+axis*side*17
			draw_line(a,b,Color(0,0,0,0.9),4,true)
			draw_line(a,b,color,2,true)
	var point: Vector3 = host.guidance.aim_point()
	var behind: bool = host.camera.is_position_behind(point)
	var projected: Vector2 = host.camera.unproject_position(point) if not behind else Vector2(-1000,-1000)
	var inside := not behind and Rect2(Vector2(45,180),size-Vector2(90,370)).has_point(projected)
	var direction := ""
	if inside:
		var aligned := projected.distance_to(middle)<24
		color = Color("7bffd0") if aligned else Color("ffd389")
		draw_arc(projected,18,0,TAU,32,Color(0,0,0,0.9),5,true)
		draw_arc(projected,18,0,TAU,32,color,2,true)
		draw_line(projected-Vector2(9,0),projected+Vector2(9,0),color,2,true)
		draw_line(projected-Vector2(0,9),projected+Vector2(0,9),color,2,true)
		direction = "CENTRED — steer gently through the marker" if aligned else "Line up the centre + with the marked opening"
	else:
		var local: Vector3 = host.camera.to_local(point)
		var delta_ := Vector2(local.x,-local.y)
		if delta_.length()<0.01: delta_ = Vector2.RIGHT
		delta_ = delta_.normalized()
		var edge := middle+delta_*minf(size.x,size.y)*0.32
		var side := Vector2(-delta_.y,delta_.x)
		draw_colored_polygon(PackedVector2Array([edge+delta_*15,edge-delta_*9+side*10,edge-delta_*9-side*10]),Color("ffd389"))
		direction = "Turn "+("RIGHT" if local.x>=0 else "LEFT")+" toward the next target" if behind or absf(local.x)>absf(local.y) else ("CLIMB" if local.y>0 else "DESCEND")+" toward the next target"
	var feedback := "GATE CLEAR ✓\n" if host.guidance.passed_seconds>0 else ""
	if not host.guidance.fits_opening: direction = "Opening too small for this drone — choose a smaller span or wider gate"
	elif host.guidance.approach_first: direction = "Approach from the marked entry side"
	var controls := "Move stick: forward/sideways · yaw stick: turn · centre to stop\nThrottle: above middle climbs · middle holds · fully low switches motors off" if host.use_radio else "W/S forward/back · A/D sideways · Q/E or ←/→ turn · release to stop"
	instruction.text = feedback+"BASIC GUIDED PRACTICE\n"+direction+"\nCyan drone and dotted line = visual route only. You fly the real drone.\nW/S forward/back · A/D sideways · Q/E or ←/→ turn · release to stop"
