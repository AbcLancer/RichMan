extends Control
## Original six-column inspection tables, driven by the same simulation as the HUD.
var app
var mode := "stocks"
var page := 0
var rows: Array = []
var scale_factor := 1.0
var elapsed := 0.0
const PAGE_ROWS := 8

func setup(root, kind: String) -> void:
	app = root
	mode = kind
	scale_factor = app._ui_scale
	name = "GameDataView"
	z_index = 76
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(650, 326) * scale_factor
	position = (get_viewport_rect().size - size) * .5
	var close := Button.new()
	close.name = "CloseDataView"
	close.text = "×"
	close.position = Vector2(618, 5) * scale_factor
	close.size = Vector2(27, 31) * scale_factor
	close.flat = true
	close.pressed.connect(hide)
	add_child(close)
	var next := Button.new()
	next.name = "NextStockPage"
	next.text = "▼"
	next.position = Vector2(582, 5) * scale_factor
	next.size = Vector2(30, 31) * scale_factor
	next.flat = true
	next.visible = mode == "stocks"
	next.pressed.connect(func() -> void:
		page = (page + 1) % maxi(1, ceili(float(Net.sim.stocks.size()) / PAGE_ROWS))
		refresh())
	add_child(next)
	refresh()

func _process(delta: float) -> void:
	if not visible: return
	elapsed += delta
	if elapsed >= .25:
		elapsed = 0.0
		refresh()

func refresh() -> void:
	if Net.sim == null: return
	var sim: Sim = Net.sim
	rows.clear()
	if mode == "stocks":
		var me: Dictionary = sim.players.get(multiplayer.get_unique_id(), {})
		var names := sim.stock_names()
		for company in names.slice(page * PAGE_ROWS, (page + 1) * PAGE_ROWS):
			var held := sim.holding_of(multiplayer.get_unique_id(), str(company))
			var available := int(sim.stocks[company].get("shares", 0))
			for player in sim.players.values(): available -= int(player.get("holdings", {}).get(company, 0))
			var basis: Dictionary = me.get("stock_cost_basis", {})
			var average := "0.0" if held == 0 else ("%.1f" % (float(basis[company]) / held) if basis.has(company) else "—")
			var change := sim.stock_change(str(company))
			rows.append({"values": [company, "%.1f" % sim.stock_price(str(company)),
				"%+d%%" % change if change != 0 else "0", str(maxi(0, available)), str(held), average],
				"color": Color8(255, 45, 43) if change > 0 else (Color8(63, 255, 30) if change < 0 else Color.WHITE)})
	else:
		for player in sim.players.values():
			var cash := int(player.money)
			var stock := sim.stock_portfolio_value(player)
			var estate := sim.estate_value(player)
			var alive := bool(player.alive)
			rows.append({"total": cash + stock + estate if alive else -1,
				"values": [Rules.role_name(int(player.role)), str(player.get("company", "")) if alive else "破产",
				str(cash + stock + estate) if alive else "", str(cash) if alive else "",
				str(stock) if alive else "", str(estate) if alive else ""],
				"color": Color.WHITE, "role": int(player.role), "owner_color": Color.html(str(player.color))})
		rows.sort_custom(func(a, b): return int(a.total) > int(b.total))
	queue_redraw()

func _draw() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color8(13, 23, 98, 215)
	panel.border_color = Color8(155, 255, 222)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(int(9 * scale_factor))
	draw_style_box(panel, Rect2(Vector2.ZERO, size))
	var font := get_theme_default_font()
	var title := "大富翁股市" if mode == "stocks" else "大富翁总排名"
	text_cell(title, Rect2(0, 0, size.x, 44 * scale_factor), Color.WHITE, 26, font)
	var headers := ["股票名称", "成交价", "涨跌", "交易量", "持有量", "成本价"] if mode == "stocks" \
		else ["玩家", "公司", "总资产", "资金", "股票", "房地产"]
	var widths := [128.0, 105.0, 102.0, 105.0, 105.0, 105.0]
	var x := 0.0
	for column in range(6):
		var width := float(widths[column]) * scale_factor
		var header := Rect2(x, 45 * scale_factor, width, 32 * scale_factor)
		draw_rect(header, Color8(0, 205, 236))
		text_cell(headers[column], header, Color8(2, 36, 69), 19, font)
		for row in range(PAGE_ROWS):
			var cell := Rect2(x, (77 + row * 30.0) * scale_factor, width, 30 * scale_factor)
			draw_rect(cell, Color8(58, 107, 172, 155), false, 1)
			if row >= rows.size(): continue
			var record: Dictionary = rows[row]
			if column == 0 and record.has("role"):
				var portrait: Texture2D = app._role_texture(int(record.role) - 1, "21")
				if portrait != null: draw_texture_rect(portrait, Rect2(cell.position + Vector2(3, 3) * scale_factor, Vector2(24, 24) * scale_factor), false)
				draw_rect(Rect2(cell.position + Vector2(27, 9) * scale_factor, Vector2(9, 12) * scale_factor), record.owner_color)
				cell.position.x += 36 * scale_factor
				cell.size.x -= 36 * scale_factor
			text_cell(str(record["values"][column]), cell, record.color, 17, font)
		x += width

func text_cell(value: String, rect: Rect2, color: Color, native_size: int, font: Font) -> void:
	var fs := int(native_size * scale_factor)
	while fs > 9 and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > rect.size.x - 6 * scale_factor:
		fs -= 1
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var point := rect.position + Vector2((rect.size.x - width) * .5, (rect.size.y - font.get_height(fs)) * .5 + font.get_ascent(fs))
	draw_string(font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
