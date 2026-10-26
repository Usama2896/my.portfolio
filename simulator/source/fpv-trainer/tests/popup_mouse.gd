extends SceneTree
# Rendered X11 fixture. The accompanying Python runner clicks through the OS,
# since headless Viewports do not reproduce native popup mouse dispatch.
var app
var frames := 0
var ready := false
func _initialize() -> void: call_deferred("setup")
func setup() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	app.splash_remaining = 0
	if is_instance_valid(app.splash_control): app.splash_control.hide()
	app.set_physics_process(false)
	app.controller = load("res://tests/fake_controller.gd").new()
	app.poll_radio()
	app.axes[1] = 0
	app.launch_remote()
	app.axes[1] = 1
	app.update_launch_readout()
func _process(_delta: float) -> bool:
	if not is_instance_valid(app): return false
	frames += 1
	if frames==20:
		var button: Button = app.launch_dialog.get_ok_button()
		var point := Vector2(app.launch_dialog.position)+button.get_global_rect().get_center()
		point = Vector2(root.position)+root.get_final_transform()*point
		var file := FileAccess.open("/tmp/al-jehad-popup-mouse.json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"x":point.x,"y":point.y,"disabled":button.disabled}))
		ready = true
	if ready and app.in_flight:
		print("PASS: native mouse click on popup Start opens remote flight")
		quit()
	if frames>3600: push_error("No successful native Start click"); quit(1)
	return false
