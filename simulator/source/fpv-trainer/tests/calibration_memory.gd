extends SceneTree
class Radio extends "res://tests/fake_controller.gd":
	var instance_guid := "port-A"
	func device_guid(_id: int) -> String: return instance_guid
	func device_name(_id: int) -> String: return "RadioMaster TX16 memory test"
var checks := 0
func check(value: bool, message: String) -> void:
	assert(value,message)
	checks += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	app.set_physics_process(false)
	var radio := Radio.new()
	app.controller = radio
	app.poll_radio()
	app.axes.assign([2,0,3,1])
	app.endpoints.assign([Vector2(-0.8,0.9),Vector2(-0.9,0.8),Vector2(-1,0.95),Vector2(-0.95,0.85)])
	app.centers.assign([0.03,-0.02,0.01,-0.05])
	app.inversions.assign([true,false,true,false])
	app.preferred_radio_guid = radio.instance_guid
	app.preferred_radio_name = radio.device_name(0)
	app.save_settings()
	app.queue_free()
	await process_frame
	var fresh = load("res://main.tscn").instantiate()
	root.add_child(fresh)
	fresh.set_physics_process(false)
	fresh.controller = Radio.new()
	fresh.poll_radio()
	check(fresh.axes==[2,0,3,1],"new app instance restores mapped axes")
	check(fresh.endpoints[0]==Vector2(-0.8,0.9),"travel limits restored")
	check(is_equal_approx(fresh.centers[0],0.03),"stick centre restored")
	check(fresh.inversions==[true,false,true,false],"inversions restored")
	check(fresh.calibrating==-1 and not fresh.restored_radio_profile.is_empty(),"ready without calibration wizard")
	fresh.controller.connected.clear()
	fresh.poll_radio()
	fresh.controller.instance_guid = "port-B"
	fresh.controller.connected.assign([1])
	fresh.poll_radio()
	check(fresh.joystick==1,"same named radio selected after USB instance changes")
	check(fresh.axes==[2,0,3,1],"calibration restored across USB GUID and index changes")
	fresh.begin_calibration(0)
	fresh.axes[0] = 7
	fresh.save_settings()
	fresh.cancel_calibration()
	fresh.load_radio()
	check(fresh.axes[0]==2,"unfinished recalibration cannot replace saved mapping")
	fresh.save_settings()
	fresh.controller.connected.clear()
	fresh.poll_radio()
	fresh.controller.instance_guid = "port-C"
	fresh.controller.connected.assign([0])
	fresh.poll_radio()
	check(fresh.axes==[2,0,3,1],"last profile survives further USB port changes")
	fresh.leave_flight()
	print("PASS: ",checks," calibration memory and reconnect checks")
	quit()
