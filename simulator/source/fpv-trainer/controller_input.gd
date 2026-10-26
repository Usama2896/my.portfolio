extends RefCounted
# The real platform adapter. Tests substitute deterministic devices/axes here,
# exercising the same launch, calibration and flight code without pretending
# that a physical USB radio has been tested.
func devices() -> Array[int]:
	var result: Array[int] = []
	for id in Input.get_connected_joypads(): result.append(id)
	return result
func device_name(id: int) -> String: return Input.get_joy_name(id)
func device_guid(id: int) -> String: return Input.get_joy_guid(id)
func axis(id: int, index: int) -> float: return Input.get_joy_axis(id,index)
