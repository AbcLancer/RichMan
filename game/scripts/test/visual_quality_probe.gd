extends Node
## Same camera/pose before and after. Uses the production loaders and map scenes.
func _ready() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(path)

func run() -> void:
	get_tree().root.size = Vector2i(1600, 1000)
	var output := "D:/Projects/RichMan/docs/screenshots/visual-quality"
	DirAccess.make_dir_recursive_absolute(output)
	var world := Node3D.new()
	add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.16, 0.21)
	environment.environment = env
	world.add_child(environment)
	for enhanced in [false, true]:
		VisualQuality.enabled = enhanced
		var gallery := Node3D.new()
		world.add_child(gallery)
		for role in range(1, 13):
			var actor := OriginalMesh.new()
			gallery.add_child(actor)
			actor.setup(JSON.parse_string(FileAccess.get_file_as_string("res://assets/original/actors/role%d.json" % role)))
			actor.position = Vector3((role - 1) % 4 * 4.4 - 6.6, 0, int((role - 1) / 4) * 5.0)
			actor.set_process(false)
			if enhanced:
				assert(not actor._normals.is_empty())
				assert(actor._uv.size() > 3000)
				actor.play("run")
				actor._process(1.0 / 60.0)
				var resource := actor.mesh
				actor._process(1.0 / 60.0)
				assert(actor.mesh == resource)
			actor.play("stan")
			actor._clock = 0.0
			actor._process(0.0)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 16
		camera.position = Vector3(0, 14, 25)
		camera.look_at(Vector3(0, 1.5, 5))
		await capture(output + "/characters_%s.png" % ("enhanced" if enhanced else "original"))
		for other in gallery.get_children().slice(1):
			other.visible = false
		camera.size = 4.5
		camera.position = Vector3(-6.6, 2.3, 7)
		camera.look_at(Vector3(-6.6, 1.4, 0))
		await capture(output + "/role1_%s.png" % ("enhanced" if enhanced else "original"))
		gallery.queue_free()
		await get_tree().process_frame
	VisualQuality.enabled = true
	# UI sprites keep their original logical dimensions despite HD storage.
	for path in ["res://assets/ui/panel/dice_anim.png", "res://assets/uitex/subc/m_aiji.png", "res://assets/card/01.png"]:
		if not ResourceLoader.exists(path):
			continue
		var raw := load(path) as Texture2D
		var hd := VisualQuality.texture(path, true)
		assert(hd.get_size() == raw.get_size(), "HD UI must not change layout")
		if hd is ImageTexture:
			assert(hd.get_image().get_width() > raw.get_width(), "HD pixels must remain after logical resize")
	for name in ["aiji", "china", "island", "japan", "paris", "space", "train"]:
		var board := BoardView.new()
		world.add_child(board)
		board.build(MapData.load_from(name))
		for item in board.find_children("*", "OriginalMesh", true, false):
			item.set_process(false)
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.position = Vector3(80, 110, 110)
		camera.look_at(Vector3.ZERO)
		await capture(output + "/" + name + ".png")
		board.queue_free()
		await get_tree().process_frame
		print("VISUAL MAP PASS ", name)
	print("VISUAL QUALITY PASS: 12 characters; normal animation; stable GPU mesh; logical UI size; all 7 maps")
	get_tree().quit()
