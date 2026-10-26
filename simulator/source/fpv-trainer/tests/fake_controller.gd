extends "res://controller_input.gd"
var connected: Array[int] = [0]
var reports := {0:[0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0],1:[0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0]}
func devices() -> Array[int]: return connected.duplicate()
func device_name(id: int) -> String: return "Test Radio TX16" if id==0 else "Test Radio Pocket"
func device_guid(id: int) -> String: return "injected-test-radio-"+str(id)
func axis(id: int, index: int) -> float: return reports[id][index] if reports.has(id) and index<reports[id].size() else 0.0
