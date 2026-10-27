extends Control
var host: Node
func _ready() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void:
	visible = host.in_flight and host.attitude_enabled
	if visible: queue_redraw()
func _draw() -> void:
	if not is_instance_valid(host.drone): return
	var centre := size/2
	var reference := reference_frame()
	var angle: float = reference.x
	var pitch_offset: float = reference.y
	var origin := centre+Vector2(0,pitch_offset)
	for side in [-1,1]:
		for i in range(5):
			var a := origin+Vector2(side*(25+i*18),0).rotated(angle)
			var b := origin+Vector2(side*(35+i*18),0).rotated(angle)
			draw_line(a,b,Color.BLACK,5,true)
			draw_line(a,b,Color("f1fbdc"),2,true)
	draw_circle(centre,3,Color("ffd071"))

func reference_frame() -> Vector2:
	# The line follows the screen projection of the world horizon. The fixed
	# diamond remains camera-centred, so bank/pitch can be judged against it.
	var local_up: Vector3 = host.camera.global_basis.inverse()*Vector3.UP
	return Vector2(atan2(local_up.x,local_up.y),clampf(-local_up.z*180,-150,150))
