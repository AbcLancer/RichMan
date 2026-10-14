extends Control
class_name Frontend
## All coordinates are original 800x600 pixels. Aspect ratio stays 4:3.
signal multiplayer_requested
signal system_requested
signal start_requested(settings: Dictionary)
signal load_requested
signal message_requested(message: String)
var page := "entry"
var selected_map := "aiji"
var selected_role := 5
var canvas: Control
var map_description: Callable
var _preview: TextureRect
var _description: Label
var _portrait: TextureRect
var _vehicle: TextureRect
var _role_name: Label
var _hexes: Dictionary = {}
var _roles: Dictionary = {}
var _options: Array[OptionButton] = []
var _pending_page := ""
# Keep this in the original hex order (top row, middle row, bottom row).
const MAPS := ["aiji", "island", "paris", "space", "train", "japan", "china"]

func _ready() -> void:
	name = "Frontend"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bars := ColorRect.new()
	bars.color = Color(0.015, 0.025, 0.07)
	bars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bars)
	canvas = Control.new()
	canvas.name = "Canvas800"
	canvas.size = Vector2(800, 600)
	add_child(canvas)
	resized.connect(_fit)
	show_page("entry")
	_fit()

func _fit() -> void:
	if canvas == null: return
	var factor := minf(size.x / 800.0, size.y / 600.0)
	canvas.scale = Vector2.ONE * factor
	canvas.position = (size - Vector2(800, 600) * factor) * 0.5

func texture(path: String) -> Texture2D:
	return load("res://assets/ui/frontend/" + path + ".png") as Texture2D

func image(id: String, path: String, rect: Rect2) -> TextureRect:
	var node := TextureRect.new()
	node.name = id
	node.texture = texture(path)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = rect.position
	node.size = rect.size
	canvas.add_child(node)
	return node

func button(id: String, path: String, rect: Rect2, action: Callable) -> TextureButton:
	var node := TextureButton.new()
	node.name = id
	node.texture_normal = texture(path + "_1")
	node.texture_hover = texture(path + "_2")
	node.texture_pressed = node.texture_hover
	node.ignore_texture_size = true
	node.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	node.position = rect.position
	node.size = rect.size
	node.pressed.connect(action)
	canvas.add_child(node)
	return node

func label(id: String, text: String, rect: Rect2, font_size := 16) -> Label:
	var node := Label.new()
	node.name = id
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", Color(0.015, 0.035, 0.13))
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.clip_text = true
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(node)
	return node

func show_page(next_page: String) -> void:
	# A button must stay alive until its pressed/input callback has returned.
	# Replacing it synchronously interrupts page construction midway through.
	_pending_page = next_page
	_replace_page.call_deferred()

func _replace_page() -> void:
	if _pending_page.is_empty(): return
	var next_page := _pending_page
	_pending_page = ""
	page = next_page
	for child in canvas.get_children(): child.free()
	_hexes.clear()
	_roles.clear()
	_options.clear()
	image("Background", page + "/back", Rect2(0, 0, 800, 600))
	if page == "entry":
		button("Single", "entry/single", Rect2(72, 363, 252, 60), func(): show_page("single"))
		button("Multi", "entry/multi", Rect2(496, 363, 252, 60), func(): multiplayer_requested.emit())
		button("System", "entry/option", Rect2(186, 440, 213, 54), func(): system_requested.emit())
		button("Quit", "entry/quit", Rect2(440, 440, 213, 54), func(): get_tree().quit())
	elif page == "single":
		button("NewGame", "single/newgame", Rect2(168, 207, 170, 213), func(): show_page("selmap"))
		button("LoadGame", "single/load", Rect2(456, 207, 170, 213), func(): load_requested.emit())
		back_button("entry")
	elif page == "selmap":
		build_maps()
		back_button("single")
	elif page == "start":
		build_options()
		back_button("selmap")

func back_button(target: String) -> void:
	button("Back", page + "/back", Rect2(690, 527, 109, 58), func(): show_page(target))

func build_maps() -> void:
	var slots := [Vector2(132, 106), Vector2(272, 106), Vector2(62, 226), Vector2(202, 226), Vector2(342, 226), Vector2(132, 346), Vector2(272, 346)]
	for i in range(MAPS.size()):
		var map_name: String = MAPS[i]
		var hex := TextureButton.new()
		hex.name = "Map_" + map_name
		hex.texture_normal = texture("selmap/" + map_name)
		hex.ignore_texture_size = true
		hex.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		hex.position = slots[i]
		hex.size = Vector2(132, 152)
		hex.pressed.connect(func(): pick_map(map_name))
		canvas.add_child(hex)
		_hexes[map_name] = hex
	# Trophy icons represent completion; no fabricated completion awards are shown.
	_preview = image("MapPreview", "gamemap/" + selected_map, Rect2(513, 130, 211, 157))
	_description = label("MapDescription", "", Rect2(510, 306, 218, 132), 14)
	_description.set_meta("ui_keep_font", true)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	button("Confirm", "selmap/ok", Rect2(625, 448, 116, 45), func(): show_page("start"))
	pick_map(selected_map)

func pick_map(map_name: String) -> void:
	selected_map = map_name
	for key in _hexes:
		var hex: TextureButton = _hexes[key]
		# Background already contains the original grey map icons.
		hex.self_modulate = Color.WHITE if key == selected_map else Color(1, 1, 1, 0)
	_preview.texture = texture("gamemap/" + selected_map)
	_description.text = str(map_description.call(selected_map))

func role_key(role: int) -> String:
	return str(role) if role < 10 else ["a", "b", "c"][role - 10]

func build_options() -> void:
	for i in range(12):
		var role := i + 1
		var pos := Vector2(26 + (i % 3) * 92, 92 + int(i / 3) * 106)
		var node := TextureButton.new()
		node.name = "Role_%d" % role
		node.texture_normal = texture("player/role%s_01" % role_key(role))
		node.ignore_texture_size = true
		node.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		node.position = pos
		node.size = Vector2(74, 92)
		node.pressed.connect(func(): pick_role(role))
		canvas.add_child(node)
		_roles[role] = node
		var caption := label("RoleLabel_%d" % role, Rules.role_name(role), Rect2(pos.x + 4, pos.y + 72, 66, 17), 12)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait = image("RolePortrait", "player/role5_02", Rect2(309, 90, 135, 158))
	_vehicle = image("RoleVehicle", "player/role5_10", Rect2(455, 203, 65, 79))
	_role_name = label("SelectedRole", "", Rect2(309, 252, 111, 30), 18)
	_role_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	image("SelectedMap", "gamemap/" + selected_map, Rect2(558, 123, 212, 156))
	var settings := [["4", "3", "2"], ["300000", "500000", "100000"], ["不限"], ["简单"], ["50", "100", "0"]]
	for i in range(5):
		var option := OptionButton.new()
		option.name = "Setting_%d" % i
		option.position = Vector2(651, 306 + i * 36)
		option.size = Vector2(122, 22)
		option.add_theme_font_size_override("font_size", 16)
		option.alignment = HORIZONTAL_ALIGNMENT_CENTER
		option.add_theme_icon_override("arrow", texture("other/scroll_dn_1"))
		option.add_theme_color_override("font_color", Color(0.01, 0.035, 0.17))
		var empty := StyleBoxEmpty.new()
		option.add_theme_stylebox_override("normal", empty)
		option.add_theme_stylebox_override("hover", empty)
		option.add_theme_stylebox_override("pressed", empty)
		for value in settings[i]: option.add_item(value)
		if i in [2, 3]: option.tooltip_text = "当前仅支持不限时、简单难度"
		canvas.add_child(option)
		_options.append(option)
	button("StartGame", "start/start", Rect2(152, 531, 115, 45), func():
		start_requested.emit({"map": selected_map, "role": selected_role, "players": int(_options[0].text), "money": int(_options[1].text), "credit": int(_options[4].text)}))
	button("CardSettings", "start/cardset", Rect2(321, 534, 178, 31), func(): message_requested.emit("卡片配置仍使用当前地图规则。"))
	pick_role(selected_role)

func pick_role(role: int) -> void:
	selected_role = role
	for key in _roles:
		(_roles[key] as TextureButton).self_modulate = Color.WHITE if key == role else Color(1, 1, 1, 0)
	_portrait.texture = texture("player/role%s_02" % role_key(role))
	_vehicle.texture = texture("player/role%s_20" % role_key(role))
	_role_name.text = Rules.role_name(role)

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event.is_action_pressed("ui_cancel") and page != "entry":
		show_page({"single": "entry", "selmap": "single", "start": "selmap"}[page])
		get_viewport().set_input_as_handled()
