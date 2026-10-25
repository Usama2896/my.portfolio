extends Control
var host: Node
var editable := false
var dragging := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if editable else Control.MOUSE_FILTER_IGNORE

func project_point(x: float, z: float) -> Vector2:
	return Vector2(18+(x+26)/40*(size.x-36),18+(z+30)/46*(size.y-36))

func _draw() -> void:
	if not is_instance_valid(host): return
	draw_style_box(panel_style(),Rect2(Vector2.ZERO,size))
	for i in range(9):
		var x := size.x*i/8
		draw_line(Vector2(x,0),Vector2(x,size.y),Color(0.4,0.7,0.65,0.08))
	for i in range(9):
		var y := size.y*i/8
		draw_line(Vector2(0,y),Vector2(size.x,y),Color(0.4,0.7,0.65,0.08))
	var data: Array = host.course.gates
	for i in range(data.size()):
		var a := project_point(data[i].x,data[i].z)
		var next: Dictionary = data[(i+1)%data.size()]
		draw_line(a,project_point(next.x,next.z),Color("3e635e"),1.5,true)
	for i in range(data.size()):
		var pos := project_point(data[i].x,data[i].z)
		var chosen: bool = i == (host.selected if editable else host.next_gate)
		var color := Color("60e3c2") if chosen else Color("71928b")
		draw_circle(pos,7 if chosen else 4,color)
		draw_string(ThemeDB.fallback_font,pos+Vector2(9,4),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("d7e4df"))
	if is_instance_valid(host.drone):
		var pos := project_point(host.drone.position.x,host.drone.position.z)
		draw_circle(pos,4,Color("ffc47a"))

func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("102622")
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style

func _gui_input(event: InputEvent) -> void:
	if not editable: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if dragging:
			var nearest := -1
			var distance_ := 22.0
			for i in range(host.course.gates.size()):
				var d := project_point(host.course.gates[i].x,host.course.gates[i].z).distance_to(event.position)
				if d < distance_:
					nearest = i
					distance_ = d
			if nearest >= 0:
				host.selected = nearest
				host.focus_gate()
			else: dragging = false
	if event is InputEventMouseMotion and dragging:
		var d: Dictionary = host.course.gates[host.selected]
		d.x = snappedf(clampf((event.position.x-18)/(size.x-36)*40-26,-25,12),0.1)
		d.z = snappedf(clampf((event.position.y-18)/(size.y-36)*46-30,-29,14),0.1)
		host.rebuild_course()
		queue_redraw()
		# Numeric fields refresh when the drag ends.
	if event is InputEventMouseButton and not event.pressed:
		host.show_module("Course Editor")
