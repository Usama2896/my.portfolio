extends Control
var host: Node
var editable := false
var dragging := false
var drag_pole := -1
var drag_bounds := Rect2(-26,-30,40,46)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if editable else Control.MOUSE_FILTER_IGNORE

func view_bounds() -> Rect2:
	if dragging: return drag_bounds
	var minimum := Vector2(-18,-22)
	var maximum := Vector2(6,8)
	for d in host.course.gates:
		var point := Vector2(d.x,d.z)
		minimum = minimum.min(point-Vector2(4,4))
		maximum = maximum.max(point+Vector2(4,4))
	if editable and host.selected<host.gates.size() and host.course.gates[host.selected].type=="zigzag":
		for section in host.O.sections(host.course.gates[host.selected]):
			var point3: Vector3 = host.gates[host.selected].to_global(section.pole)
			var point := Vector2(point3.x,point3.z)
			minimum = minimum.min(point-Vector2(3,3))
			maximum = maximum.max(point+Vector2(3,3))
	if not editable and is_instance_valid(host.drone):
		var position_ := Vector2(host.drone.position.x,host.drone.position.z)
		minimum = minimum.min(position_-Vector2(3,3))
		maximum = maximum.max(position_+Vector2(3,3))
	var extent := maximum-minimum
	var aspect := maxf(1,size.x-36)/maxf(1,size.y-36)
	if extent.x/extent.y<aspect: extent.x = extent.y*aspect
	else: extent.y = extent.x/aspect
	return Rect2((minimum+maximum-extent)/2,extent)

func project_point(x: float, z: float) -> Vector2:
	var bounds := view_bounds()
	return Vector2(18+(x-bounds.position.x)/bounds.size.x*(size.x-36),18+(z-bounds.position.y)/bounds.size.y*(size.y-36))

func unproject_point(point: Vector2) -> Vector2:
	var bounds := view_bounds()
	return bounds.position+Vector2((point.x-18)/maxf(1,size.x-36)*bounds.size.x,(point.y-18)/maxf(1,size.y-36)*bounds.size.y)

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
	if editable and host.selected<host.gates.size() and host.course.gates[host.selected].type=="zigzag":
		var sections: Array = host.O.sections(host.course.gates[host.selected])
		for i in range(sections.size()):
			var point: Vector3 = host.gates[host.selected].to_global(sections[i].pole)
			var pos := project_point(point.x,point.z)
			draw_circle(pos,8 if i==host.selected_pole else 5,Color("ffa35b"))
			draw_string(ThemeDB.fallback_font,pos+Vector2(9,-5),"P%d" % [i+1],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ffd4a3"))
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
		var bounds_before := view_bounds()
		dragging = event.pressed
		if dragging: drag_bounds = bounds_before
		if dragging:
			drag_pole = -1
			if host.course.gates[host.selected].type=="zigzag":
				var sections: Array = host.O.sections(host.course.gates[host.selected])
				var nearest_distance := 18.0
				for i in range(sections.size()):
					var point: Vector3 = host.gates[host.selected].to_global(sections[i].pole)
					var distance_: float = project_point(point.x,point.z).distance_to(event.position)
					if distance_<nearest_distance:
						drag_pole = i
						nearest_distance = distance_
				if drag_pole>=0:
					host.selected_pole = drag_pole
					host.highlight_pole()
					queue_redraw()
					return
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
		if drag_pole>=0:
			host.set_pole_world_position(drag_pole,unproject_point(event.position))
			queue_redraw()
			return
		var d: Dictionary = host.course.gates[host.selected]
		var position_ := unproject_point(event.position)
		d.x = snappedf(clampf(position_.x,-95,95),0.1)
		d.z = snappedf(clampf(position_.y,-95,95),0.1)
		host.rebuild_course()
		queue_redraw()
		# Numeric fields refresh when the drag ends.
	if event is InputEventMouseButton and not event.pressed:
		drag_pole = -1
		host.show_module("Course Editor")
