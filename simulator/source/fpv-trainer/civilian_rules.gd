extends RefCounted
# Civilian ground-service tasks. Unloading has no airborne path or projectile.
var delivery := true
var home := Vector3.ZERO
var destination := Vector3(0,0,-40)
var pad_size := 4.0
var phase := "outbound"
var elapsed := 0.0
var hold := 0.0
var airborne := false
var landed := false
var delivered := false
var offset := 0.0
var descent_speed := 0.0
var last_air_velocity := Vector3.ZERO
var message := "Take off and fly to the marked pad."
func target() -> Vector3: return home if phase=="returning" else destination
func sample(delta: float, position_: Vector3, velocity: Vector3, up: Vector3, span: float, contact: bool) -> void:
	if phase in ["complete","failed"]: return
	elapsed += delta
	if position_.y>0.8: airborne = true
	if not contact: last_air_velocity = velocity
	var relative := position_-target()
	offset = Vector2(relative.x,relative.z).length()
	var within := absf(relative.x)+span/2<=pad_size/2 and absf(relative.z)+span/2<=pad_size/2
	var stable := contact and absf(position_.y-span/2)<0.15 and velocity.length()<0.3 and up.dot(Vector3.UP)>0.97
	if airborne and stable and within:
		if hold==0: descent_speed = absf(last_air_velocity.y)
		hold += delta
	else: hold = 0
	landed = hold>=2.0
	if not landed: return
	if phase=="returning" or not delivery:
		phase = "complete"
		message = "Home landing complete. Parcel delivered." if delivery else "Landing complete. Review your touchdown feedback."
	else: message = "Landed and stable. Press U or Unload to place the parcel on the ground."
func unload() -> bool:
	if not delivery or phase!="outbound" or not landed or not airborne: return false
	delivered = true
	phase = "returning"
	hold = 0
	landed = false
	airborne = false
	message = "Parcel placed on the ground. Take off and return to the home pad."
	return true
func fail(reason: String) -> void:
	phase = "failed"
	message = reason
