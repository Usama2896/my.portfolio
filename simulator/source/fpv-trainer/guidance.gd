extends Node3D
const O = preload("res://obstacles.gd")
const SIZES = preload("res://drone_sizes.gd")
var host: Node
var path: Array[Vector3] = []
var target := Vector3.ZERO
var normal := Vector3.BACK
var approach_target := Vector3.ZERO
var fits_opening := true
var approach_first := false
var ghost: Node3D
var plus: Node3D
var dots: Node3D
var cache_key := ""
var distance_along := 0.0
var passed_seconds := 0.0

func _ready() -> void:
	ghost = Node3D.new()
	ghost.name = "VisualGuideDrone"
	add_child(ghost)
	var cyan := guide_material(Color(0.35,1,0.86,0.85))
	visual_box(ghost,Vector3.ZERO,Vector3(0.16,0.055,0.20),cyan)
	visual_box(ghost,Vector3.ZERO,Vector3(0.34,0.025,0.035),cyan)
	visual_box(ghost,Vector3.ZERO,Vector3(0.035,0.025,0.34),cyan)
	for x in [-0.14,0.14]:
		for z in [-0.14,0.14]:
			var prop := MeshInstance3D.new()
			var ring := TorusMesh.new()
			ring.inner_radius = 0.045
			ring.outer_radius = 0.060
			ring.rings = 12
			ring.ring_segments = 6
			prop.mesh = ring
			prop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			prop.position = Vector3(x,0,z)
			prop.material_override = cyan
			ghost.add_child(prop)
	plus = Node3D.new()
	plus.name = "OpeningCentrePlus"
	add_child(plus)
	visual_box(plus,Vector3.ZERO,Vector3(0.34,0.035,0.025),cyan)
	visual_box(plus,Vector3.ZERO,Vector3(0.035,0.34,0.025),cyan)
	dots = Node3D.new()
	dots.name = "RouteBreadcrumbs"
	add_child(dots)
	visible = false

func guide_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func visual_box(parent: Node3D, position_: Vector3, size_: Vector3, material: Material) -> void:
	var visual := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size_
	visual.mesh = shape
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.position = position_
	visual.material_override = material
	parent.add_child(visual) # Deliberately no collision/trigger or flight input.

func opening(data: Dictionary, section: int) -> Dictionary:
	var frame: Dictionary = O.sections(data)[section]
	var basis_: Basis = frame.get("basis",Basis.IDENTITY)
	var chosen: Vector2 = O.holes(data)[0]
	var fits := false
	for hole in O.holes(data):
		if O.fits(data,frame.center+basis_*Vector3(hole.x,hole.y,0),section,SIZES.radius(host.drone_span)):
			chosen = hole
			fits = true
			break
	return {"center":frame.center+basis_*Vector3(chosen.x,chosen.y,0),"basis":basis_,"fits":fits}

func rebuild_path() -> void:
	path.clear()
	var data: Dictionary = host.course.gates[host.next_gate]
	var gate: Node3D = host.gates[host.next_gate]
	var sections := O.sections(data)
	var current := opening(data,host.section_index)
	target = gate.to_global(current.center)
	normal = (gate.basis*current.basis.z).normalized()
	fits_opening = current.fits
	approach_target = target+normal*1.1 if host.section_index==0 else gate.to_global(opening(data,host.section_index-1).center)
	path.append(approach_target)
	for i in range(host.section_index,sections.size()):
		var frame := opening(data,i)
		path.append(gate.to_global(frame.center))
	var last := opening(data,sections.size()-1)
	path.append(gate.to_global(last.center-last.basis.z*1.0))
	distance_along = 0
	for child in dots.get_children():
		dots.remove_child(child)
		child.queue_free()
	var material := guide_material(Color(0.3,0.95,0.78,0.45))
	for i in range(path.size()-1):
		var steps := maxi(1,ceili(path[i].distance_to(path[i+1])/0.45))
		for j in range(steps):
			visual_box(dots,path[i].lerp(path[i+1],float(j)/steps),Vector3.ONE*0.035,material)
	plus.global_transform = Transform3D(gate.basis*current.basis,target)
	plus.visible = fits_opening

func sample_path(distance_: float) -> Dictionary:
	for i in range(path.size()-1):
		var length_ := path[i].distance_to(path[i+1])
		if distance_<=length_:
			return {"position":path[i].lerp(path[i+1],distance_/maxf(length_,0.001)),"direction":(path[i+1]-path[i]).normalized()}
		distance_ -= length_
	return {"position":path[-1],"direction":(path[-1]-path[-2]).normalized()}

func update_guidance(delta: float) -> void:
	visible = host.in_flight and host.practice_basic and not host.assessment and not host.finished and host.crash_phase.is_empty() and not host.remote_waiting_low
	passed_seconds = maxf(0,passed_seconds-delta)
	if not visible: return
	var key := "%d:%d:%d:%.3f" % [host.next_gate,host.section_index,host.course_revision,host.drone_span]
	if key!=cache_key:
		cache_key = key
		rebuild_path()
	approach_first = (host.drone.position-target).dot(normal)<-0.10
	var length_ := 0.0
	for i in range(path.size()-1): length_ += path[i].distance_to(path[i+1])
	distance_along = fmod(distance_along+delta*1.25,maxf(0.1,length_+0.7))
	dots.visible = fits_opening
	plus.visible = fits_opening and plus.global_position.distance_to(host.camera.global_position)>1.5
	for dot in dots.get_children(): dot.visible = dot.global_position.distance_to(host.camera.global_position)>0.6
	ghost.visible = fits_opening and distance_along<length_
	if ghost.visible:
		var point := sample_path(distance_along)
		ghost.global_position = point.position
		ghost.visible = ghost.global_position.distance_to(host.camera.global_position)>1.4 and not host.camera.is_position_behind(ghost.global_position)
		var direction: Vector3 = point.direction
		if direction.length()>0.001:
			ghost.look_at(ghost.global_position+direction,Vector3.UP if absf(direction.dot(Vector3.UP))<0.95 else Vector3.FORWARD)

func aim_point() -> Vector3:
	return approach_target if approach_first else target

func gate_passed() -> void:
	passed_seconds = 1.2
	cache_key = ""
