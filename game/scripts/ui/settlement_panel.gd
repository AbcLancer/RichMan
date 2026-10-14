extends Control
## End-of-match assets and final authoritative assets. No invented native score.
signal return_requested
var winner_id := -1
var result_title := ""
var ranking

func setup(app, snapshot: Dictionary) -> void:
	name = "SettlementPanel"
	z_index = 120
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	winner_id = int(snapshot.get("win", -1))
	var players: Dictionary = snapshot.get("players", {})
	var winner: Dictionary = players.get(winner_id, {})
	result_title = "对局结束" if winner.is_empty() else ("胜利" if winner_id == multiplayer.get_unique_id() else "败北")
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, .8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var scale_factor: float = minf(get_viewport_rect().size.x / 820, get_viewport_rect().size.y / 620)
	var canvas := Control.new()
	canvas.size = Vector2(800, 600)
	canvas.scale = Vector2.ONE * scale_factor
	canvas.position = (get_viewport_rect().size - canvas.size * scale_factor) * .5
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	if not winner.is_empty():
		var role := int(winner.get("role", 1))
		var suffix: String = str(role) if role < 10 else ["a", "b", "c"][clampi(role - 10, 0, 2)]
		var art := TextureRect.new()
		art.texture = load("res://assets/ui/frontend/win_end/role%s.png" % suffix)
		art.size = Vector2(800, 450)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(art)
	var title := Label.new()
	title.name = "ResultTitle"
	title.text = result_title + (" · " + Rules.role_name(int(winner.role)) if not winner.is_empty() else "")
	title.position = Vector2(0, 12)
	title.size = Vector2(800, 65)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color8(255, 237, 120))
	title.add_theme_color_override("font_shadow_color", Color.BLACK)
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(title)
	ranking = load("res://scripts/ui/game_data_view.gd").new()
	canvas.add_child(ranking)
	ranking.setup(app, "ranking")
	ranking.scale = Vector2.ONE / app._ui_scale
	ranking.position = Vector2(75, 170)
	ranking.set_process(false)
	ranking.get_node("CloseDataView").hide()
	var back := Button.new()
	back.name = "ReturnToMenu"
	back.text = "返回主菜单"
	back.position = Vector2(290, 535)
	back.size = Vector2(220, 48)
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(func(): return_requested.emit())
	canvas.add_child(back)
