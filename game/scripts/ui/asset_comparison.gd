extends Control
## Three independent worlds with identical camera/pose, using production loaders.
var _worlds: Array[Node3D] = []
var _cameras: Array[Camera3D] = []
var _content: Array[Node3D] = []
var _mode: OptionButton
var _role: OptionButton
var _map: OptionButton
var _animate: CheckButton
var _angle: HSlider
var _zoom: HSlider
const PROFILES := ["original", "enhanced", "remade"]
const MAPS := ["aiji", "china", "island", "japan", "paris", "space", "train"]

func _ready() -> void:
	get_window().title = "RichMan6 · 三版本素材对照"
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	theme.default_font = font
	theme.default_font_size = 18
	self.theme = theme
	var background := ColorRect.new()
	background.color = Color(0.07, 0.09, 0.13)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)
	var toolbar := HBoxContainer.new()
	layout.add_child(toolbar)
	_mode = OptionButton.new()
	for label in ["角色", "占地标志物", "地图环境"]:
		_mode.add_item(label)
	toolbar.add_child(_mode)
	_role = OptionButton.new()
	for index in range(1, 13):
		_role.add_item(str(Rules.role_name(index)))
	toolbar.add_child(_role)
	_map = OptionButton.new()
	for label in ["埃及", "中国", "夏威夷", "日本", "巴黎", "太空", "火车"]:
		_map.add_item(label)
	toolbar.add_child(_map)
	_animate = CheckButton.new()
	_animate.text = "播放动作"
	toolbar.add_child(_animate)
	var rotate_label := Label.new()
	rotate_label.text = "转动"
	toolbar.add_child(rotate_label)
	_angle = HSlider.new()
	_angle.min_value = -180
	_angle.max_value = 180
	_angle.value = 0
	_angle.custom_minimum_size = Vector2(180, 30)
	toolbar.add_child(_angle)
	var zoom_label := Label.new()
	zoom_label.text = "缩放"
	toolbar.add_child(zoom_label)
	_zoom = HSlider.new()
	_zoom.step = 0.05
	_zoom.min_value = 0.5
	_zoom.max_value = 4.0
	_zoom.value = 1.0
	_zoom.custom_minimum_size = Vector2(140, 30)
	toolbar.add_child(_zoom)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(row)
	var labels := ["原素材", "上一轮高清修复", "新版重绘资产"]
	for i in range(3):
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(column)
		var label := Label.new()
		label.text = labels[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
		var container := SubViewportContainer.new()
		container.stretch = true
		container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(container)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(480, 760)
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.msaa_3d = Viewport.MSAA_4X
		container.add_child(viewport)
		var world := Node3D.new()
		viewport.add_child(world)
		_worlds.append(world)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-50, -30, 0)
		sun.light_energy = 1.0
		world.add_child(sun)
		var environment := WorldEnvironment.new()
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.13, 0.16, 0.21)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.7, 0.74, 0.82)
		env.ambient_light_energy = 0.65
		environment.environment = env
		world.add_child(environment)
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.current = true
		_cameras.append(camera)
	var note := Label.new()
	note.text = "相同模型姿态和相机 · 标志物背后的方格用于观察半透明 · ESC 退出"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(note)
	_mode.item_selected.connect(func(_index): rebuild())
	_role.item_selected.connect(func(_index): rebuild())
	_map.item_selected.connect(func(_index): rebuild())
	_animate.toggled.connect(func(_pressed): rebuild())
	_angle.value_changed.connect(func(value):
		for content in _content:
			if _mode.selected != 2:
				content.get_node("Asset").rotation_degrees.y = value
		update_zoom())
	_zoom.value_changed.connect(func(_value): update_zoom())
	rebuild()
	if OS.get_cmdline_user_args().has("--comparison-check"):
		call_deferred("check")

func rebuild() -> void:
	_role.visible = _mode.selected != 2
	_map.visible = _mode.selected == 2
	for child in _content:
		child.free()
	_content.clear()
	for i in range(3):
		VisualQuality.use_profile(PROFILES[i])
		var content := Node3D.new()
		_worlds[i].add_child(content)
		_content.append(content)
		var camera := _cameras[i]
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 4.5
		camera.position = Vector3(0, 2.3, 7)
		camera.look_at(Vector3(0, 1.45, 0))
		if _mode.selected == 2:
			var board := BoardView.new()
			content.add_child(board)
			board.build(MapData.load_from(MAPS[_map.selected]))
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.position = Vector3(85, 145, 125)
			camera.look_at(Vector3.ZERO)
			camera.set_meta("base_position", camera.position)
			camera.set_meta("target", Vector3.ZERO)
			for actor in board.find_children("*", "MeshInstance3D", true, false):
				if actor is OriginalMesh:
					actor.set_process(_animate.button_pressed)
			continue
		var role := _role.selected + 1
		var path := "res://assets/original/actors/role%d.json" % role
		if _mode.selected == 1:
			path = "res://assets/original/markers/%s.json" % str(Rules.role_record(role).get("marker", "diamond"))
		var actor := OriginalMesh.new()
		actor.name = "Asset"
		content.add_child(actor)
		actor.setup(JSON.parse_string(FileAccess.get_file_as_string(path)))
		actor.play("run" if _animate.button_pressed else "stan")
		actor.set_process(_animate.button_pressed)
		actor.rotation_degrees.y = _angle.value
		if _mode.selected == 1:
			actor.scale = Vector3.ONE * 5
			var backdrop := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(5, 5)
			backdrop.mesh = quad
			backdrop.position = Vector3(0, 1.5, -1.7)
			var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
			for x in range(64):
				for y in range(64):
					image.set_pixel(x, y, Color(0.16, 0.38, 0.60) if (int(x / 8) + int(y / 8)) % 2 == 0 else Color(0.85, 0.53, 0.29))
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_texture = ImageTexture.create_from_image(image)
			backdrop.material_override = material
			content.add_child(backdrop)
		var bounds := AABB(actor._frames[0][0] - actor._pivot, Vector3.ZERO)
		for point in actor._frames[0]:
			bounds = bounds.expand(point - actor._pivot)
		var target := (bounds.position + bounds.size * 0.5) * actor.scale
		camera.position = target + Vector3(0, 0.65, 7)
		camera.look_at(target)
		camera.size = maxf(bounds.size.y * actor.scale.y, bounds.size.x * actor.scale.x * 1.6) * 1.3
		camera.set_meta("base_size", camera.size)
	if _mode.selected != 2:
		for camera in _cameras:
			camera.position = _cameras[0].position
			camera.rotation = _cameras[0].rotation
			camera.set_meta("base_size", _cameras[0].get_meta("base_size"))
	update_zoom()

func update_zoom() -> void:
	for camera in _cameras:
		if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
			camera.size = float(camera.get_meta("base_size", 4.5)) / _zoom.value
		else:
			var target: Vector3 = camera.get_meta("target", Vector3.ZERO)
			var position_base: Vector3 = camera.get_meta("base_position", Vector3(85, 145, 125))
			camera.position = target + (position_base - target).rotated(Vector3.UP, deg_to_rad(_angle.value)) / _zoom.value
			camera.look_at(target)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

func screenshot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output := ProjectSettings.globalize_path("res://../docs/screenshots/remade-assets")
	DirAccess.make_dir_recursive_absolute(output)
	get_tree().root.get_texture().get_image().save_png(output + "/" + name + ".png")

func check() -> void:
	for role in range(12):
		_role.select(role)
		rebuild()
		for i in range(3):
			var actor := _content[i].get_node("Asset") as OriginalMesh
			assert(actor.mesh != null and actor._frames.size() > 10)
			if i == 2:
				assert(not actor._normals.is_empty())
		await screenshot("role%d" % (role + 1))
	_mode.select(1)
	_role.select(0)
	rebuild()
	for i in range(3):
		var actor := _content[i].get_node("Asset") as OriginalMesh
		var material := actor.mesh.surface_get_material(0) as StandardMaterial3D
		assert(material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS)
	await screenshot("diamond-transparency")
	_mode.select(2)
	for map_index in range(7):
		_map.select(map_index)
		rebuild()
		await screenshot(MAPS[map_index])
	print("COMPARISON PASS: 12 roles in 3 profiles; continuous diamond alpha; 7 maps")
	get_tree().quit()
