extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	for i in range(330): await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/workspace/fpv-review-activation.png")
	var dialog: AcceptDialog
	for child in app.get_children():
		if child is AcceptDialog and child.title.contains("Activate"): dialog = child
	assert(is_instance_valid(dialog))
	var key: LineEdit = dialog.find_children("*","LineEdit",true,false)[0]
	key.text = "wrong"
	dialog.confirmed.emit()
	assert(not app.license_memory.is_active() and dialog.visible)
	key.text = "TWP29"
	dialog.confirmed.emit()
	await process_frame
	assert(app.license_memory.is_active())
	assert(app.launch_keyboard())
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/workspace/fpv-review-owner-fullscreen.png")
	print("PASS: rendered activation dialog rejects wrong key and accepts owner key; fullscreen flight launches")
	quit()
