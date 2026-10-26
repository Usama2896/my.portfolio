extends RigidBody3D
signal impact(strength: float, normal: Vector3)
var previous_velocity := Vector3.ZERO
var pending_reset: Dictionary = {}

func request_reset(pose: Transform3D, velocity := Vector3.ZERO) -> void:
	pending_reset = {"pose":pose,"velocity":velocity}
	global_transform = pose
	linear_velocity = velocity
	angular_velocity = Vector3.ZERO
	previous_velocity = velocity
	reset_physics_interpolation()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not pending_reset.is_empty():
		state.transform = pending_reset.pose
		state.linear_velocity = pending_reset.velocity
		state.angular_velocity = Vector3.ZERO
		previous_velocity = pending_reset.velocity
		pending_reset.clear()
		return
	var strongest := 0.0
	var impact_normal := Vector3.UP
	for i in range(state.get_contact_count()):
		# Direct-state contact vectors are world-space; do not rotate them again.
		var normal := state.get_contact_local_normal(i).normalized()
		var collider_velocity := state.get_contact_collider_velocity_at_position(i)
		var closing := maxf(0,-(previous_velocity-collider_velocity).dot(normal))
		if closing>strongest:
			strongest = closing
			impact_normal = normal
	if strongest>0.45: impact.emit.call_deferred(strongest,impact_normal)
	previous_velocity = state.linear_velocity
