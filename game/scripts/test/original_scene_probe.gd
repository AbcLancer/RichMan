extends Node
## Render actual assets with production BoardView; all seven maps and all actors.
func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var root := get_tree().root
	root.size = Vector2i(1440, 900)
	var world := Node3D.new()
	root.add_child(world)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	var output := "D:/Projects/RichMan/docs/screenshots/scene-recovery"
	DirAccess.make_dir_recursive_absolute(output)
	for map_name in ["aiji", "china", "island", "japan", "paris", "space", "train"]:
		var board := BoardView.new()
		world.add_child(board)
		var data := MapData.load_from(map_name)
		board.build(data)
		board.set_process(false)
		var sim := Sim.new()
		sim.setup(data, 42)
		var player := sim.add_player(1, "位置验证")
		board.sync(sim.to_dict())
		var before: Vector3 = board.player_pos(1)
		player["tile"] = 1
		player["progress"] = 0.5
		player["moving"] = 3
		board.sync(sim.to_dict())
		assert(board._player_target[1].distance_to(data.route_position_3d(1, 1, 0.5)) < 0.001)
		board._process(0.1)
		assert(before.distance_to(board.player_pos(1)) > 0.1, "Solo player must move")
		board._player_nodes[1].visible = false
		var maximum := 0.0
		for i in range(data.tile_count()):
			maximum = maxf(maximum, data.route_position(i, 1, 1).distance_to(data.pos_of(i + 1)))
		assert(maximum < 0.05, map_name + " route continuity")
		cam.position = Vector3(90, 135, 130)
		cam.look_at(Vector3.ZERO)
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output + "/" + map_name + ".png")
		if map_name == "aiji":
			var target := data.route_position_3d(0, 1, 0)
			cam.position = target + Vector3(5, 17, 27)
			cam.look_at(target + Vector3(0, 2, 0))
			for role in range(1, 13):
				var actor := OriginalMesh.new()
				board.add_child(actor)
				actor.setup(JSON.parse_string(FileAccess.get_file_as_string("res://assets/original/actors/role%d.json" % role)))
				actor.play("run")
				actor.position = target + Vector3((role - 1) % 4 * 4.0 - 6, 0, int((role - 1) / 4) * 5.0)
			await get_tree().create_timer(1.0).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output + "/actors.png")
			var source := board.get_node("OriginalScene")
			for child in source.get_children():
				if child is OriginalMesh and child.has_meta("source") and "munaiyi" in str(child.get_meta("source")):
					var center: Vector3 = child.mesh.get_aabb().get_center()
					cam.position = center + Vector3(7, 6, 10)
					cam.look_at(center)
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(output + "/mummy_0.png")
					await get_tree().create_timer(1.0).timeout
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(output + "/mummy_1.png")
		print("SCENE PASS ", map_name, " roads=", data.tile_count(), " join_error=", maximum)
		board.queue_free()
		await get_tree().process_frame
	var gallery := Node3D.new()
	world.add_child(gallery)
	var building_ids := BuildingLib.ids()
	for i in range(building_ids.size()):
		var model := MeshInstance3D.new()
		model.mesh = BuildingLib.mesh_for(building_ids[i])
		model.material_override = BuildingLib.material_for(building_ids[i])
		assert(model.mesh != null)
		model.scale = Vector3.ONE * 3.0
		model.position = Vector3(i % 8 * 5.0 - 17.5, 0, int(i / 8) * 6.0 - 15)
		gallery.add_child(model)
		var label := Label3D.new()
		label.text = building_ids[i]
		label.font_size = 32
		label.pixel_size = 0.015
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = model.position + Vector3(0, 0.1, 2.5)
		gallery.add_child(label)
	cam.position = Vector3(0, 43, 41)
	cam.look_at(Vector3.ZERO)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + "/buildings.png")
	print("BUILDINGS PASS ", building_ids.size())
	get_tree().quit()
