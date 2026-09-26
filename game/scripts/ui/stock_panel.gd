extends Control
class_name StockPanel
## 右下角**常驻的股票行情面板** + 买卖对话框。
##
## 依据 = 老板 2026-09-26 给的**原版实机截图**（3 张）：
##   ① 右下角表格：表头「**名称 股价 持股 %**」，每行一家公司，涨跌是**整数百分数**
##      （`+7` / `+3` / `0` / `-1`）；玩家自己那家显示他的持股数（截图里 2000）
##   ② 点一下 → 弹出竖排 4 个按钮：**买进 / 卖出 / 股东 / 走势**
##   ③ 买进 → 弹对话框（底图 `uitex/buystock/buystock.tga`）：上排「买进 + 股数」、
##      中间大字显示金额、下面 `OK` / `PASS`
##
## 面板本身**没有底图素材** —— 原版截图里就是白底 + 蓝边的程序表格，这里照做。
##
## 数据全部来自权威 `Sim`（`stocks` / `holding_of`），本类只画不算。

const UI_SCALE_REF := 768.0

## 表头四列的宽度（native）
const COL_W: Array = [64.0, 46.0, 58.0, 34.0]
const HEAD_H := 20.0
const ROW_H := 19.0
const VISIBLE_ROWS := 5                 # 一屏 5 家（与截图一致）

var _scale := 1.0
var _bg: PanelContainer
var _head: Array = []                   # 4 个 Label
var _rows: Array = []                   # [{bg(Label), labels:[4]}]
var _hint: Label                        # 「▲▼」提示还能翻页
var _page := 0
var _menu: PanelContainer
var _menu_btns: Array = []
var _sel := ""                          # 当前选中的公司
var _dlg: PanelContainer                # 买进/卖出对话框
var _dlg_title: Label
var _dlg_input: LineEdit
var _dlg_amount: Label
var _dlg_ok: Button
var _dlg_pass: Button
var _dlg_buy := true
var _sig := ""

signal act_requested(kind: String, company: String, shares: int)


func setup(ui_scale: float) -> void:
	_scale = ui_scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_sync(0.0, "")


func _px(v: float) -> float:
	return v * _scale


func _build() -> void:
	# ---- 面板主体：白底 + 蓝边 + 圆角（原版截图就是这种表格）----
	_bg = PanelContainer.new()
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color8(248, 250, 255, 236)
	sb.border_color = Color8(32, 82, 168)
	sb.set_border_width_all(maxi(2, int(round(_px(2.0)))))
	sb.set_corner_radius_all(int(round(_px(5.0))))
	sb.content_margin_left = _px(5.0)
	sb.content_margin_right = _px(5.0)
	sb.content_margin_top = _px(3.0)
	sb.content_margin_bottom = _px(3.0)
	_bg.add_theme_stylebox_override("panel", sb)
	add_child(_bg)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	_bg.add_child(col)

	# ---- 表头 ----
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 0)
	col.add_child(hr)
	var heads := ["名称", "股价", "持股", "%"]
	for i in range(4):
		var lb := Label.new()
		lb.text = heads[i]
		lb.custom_minimum_size = Vector2(_px(COL_W[i]), _px(HEAD_H))
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if i > 0 \
			else HORIZONTAL_ALIGNMENT_LEFT
		lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lb.add_theme_font_size_override("font_size", maxi(9, int(round(_px(12.0)))))
		lb.add_theme_color_override("font_color", Color8(28, 62, 140))
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hr.add_child(lb)
		_head.append(lb)

	# ---- 数据行 ----
	for r in range(VISIBLE_ROWS):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		row.mouse_filter = Control.MOUSE_FILTER_STOP        # 整行可点（Label 都是 IGNORE）
		col.add_child(row)
		var ri := r
		row.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed \
					and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				_on_row_clicked(ri))
		var labels: Array = []
		for i in range(4):
			var lb := Label.new()
			lb.custom_minimum_size = Vector2(_px(COL_W[i]), _px(ROW_H))
			lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if i > 0 \
				else HORIZONTAL_ALIGNMENT_LEFT
			lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lb.add_theme_font_size_override("font_size", maxi(9, int(round(_px(12.0)))))
			lb.add_theme_color_override("font_color", Color8(24, 28, 44))
			lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(lb)
			labels.append(lb)
		# ⚠ 别在 HBoxContainer 里塞 Button 来当「整行热区」—— 容器会把它排成一列挤在右边
		_rows.append({"labels": labels, "name": ""})

	# ---- 底部提示（还能翻页 / 点行操作）----
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", maxi(8, int(round(_px(10.0)))))
	_hint.add_theme_color_override("font_color", Color8(90, 100, 130))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_hint)

	# ---- 操作菜单（买进 / 卖出 / 股东 / 走势）----
	_menu = PanelContainer.new()
	_menu.visible = false
	_menu.z_index = 40
	var msb := StyleBoxFlat.new()
	msb.bg_color = Color8(252, 252, 255, 245)
	msb.border_color = Color8(32, 82, 168)
	msb.set_border_width_all(maxi(2, int(round(_px(2.0)))))
	msb.set_corner_radius_all(int(round(_px(5.0))))
	msb.content_margin_left = _px(2.0)
	msb.content_margin_right = _px(2.0)
	msb.content_margin_top = _px(2.0)
	msb.content_margin_bottom = _px(2.0)
	_menu.add_theme_stylebox_override("panel", msb)
	add_child(_menu)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", maxi(1, int(round(_px(2.0)))))
	_menu.add_child(mv)
	# 原版截图里的顺序：买进 / 卖出 / 股东 / 走势
	for which in ["buy", "sell", "holder", "trend"]:
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.text = _menu_label(str(which))
		b.custom_minimum_size = Vector2(_px(56.0), _px(23.0))
		b.add_theme_font_size_override("font_size", maxi(9, int(round(_px(13.0)))))
		b.add_theme_color_override("font_color", Color8(28, 40, 80))
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", _hover_box())
		b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		var m := str(which)
		b.pressed.connect(func(): _on_menu(m))
		mv.add_child(b)
		_menu_btns.append(b)

	_build_dialog()


## 买进 / 卖出对话框（底图 = `uitex/buystock/buystock.tga`）
func _build_dialog() -> void:
	_dlg = PanelContainer.new()
	_dlg.visible = false
	_dlg.z_index = 60
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color8(255, 226, 214)
	sb.border_color = Color8(214, 128, 108)
	sb.set_border_width_all(maxi(2, int(round(_px(2.0)))))
	sb.set_corner_radius_all(int(round(_px(10.0))))
	sb.content_margin_left = _px(10.0)
	sb.content_margin_right = _px(10.0)
	sb.content_margin_top = _px(8.0)
	sb.content_margin_bottom = _px(8.0)
	_dlg.add_theme_stylebox_override("panel", sb)
	add_child(_dlg)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", maxi(3, int(round(_px(6.0)))))
	_dlg.add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", maxi(3, int(round(_px(6.0)))))
	col.add_child(top)
	_dlg_title = Label.new()
	_dlg_title.custom_minimum_size = Vector2(_px(50.0), _px(24.0))
	_dlg_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dlg_title.add_theme_font_size_override("font_size", maxi(10, int(round(_px(14.0)))))
	_dlg_title.add_theme_color_override("font_color", Color8(120, 40, 40))
	top.add_child(_dlg_title)
	_dlg_input = LineEdit.new()
	_dlg_input.custom_minimum_size = Vector2(_px(80.0), _px(24.0))
	_dlg_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dlg_input.add_theme_font_size_override("font_size", maxi(10, int(round(_px(14.0)))))
	_dlg_input.text_changed.connect(func(_t: String): _refresh_amount())
	top.add_child(_dlg_input)

	_dlg_amount = Label.new()
	_dlg_amount.custom_minimum_size = Vector2(_px(150.0), _px(34.0))
	_dlg_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dlg_amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dlg_amount.add_theme_font_size_override("font_size", maxi(12, int(round(_px(20.0)))))
	_dlg_amount.add_theme_color_override("font_color", Color8(30, 60, 120))
	var asb := StyleBoxFlat.new()
	asb.bg_color = Color8(206, 232, 245)
	asb.set_corner_radius_all(int(round(_px(4.0))))
	_dlg_amount.add_theme_stylebox_override("normal", asb)
	col.add_child(_dlg_amount)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", maxi(4, int(round(_px(10.0)))))
	col.add_child(btns)
	_dlg_ok = _dlg_button("OK")
	_dlg_ok.pressed.connect(func(): _confirm_dialog(true))
	btns.add_child(_dlg_ok)
	_dlg_pass = _dlg_button("PASS")
	_dlg_pass.pressed.connect(func(): _confirm_dialog(false))
	btns.add_child(_dlg_pass)


func _dlg_button(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(_px(52.0), _px(24.0))
	b.add_theme_font_size_override("font_size", maxi(9, int(round(_px(13.0)))))
	b.add_theme_color_override("font_color", Color8(60, 30, 90))
	b.add_theme_stylebox_override("normal", _btn_box(Color8(255, 246, 240)))
	b.add_theme_stylebox_override("hover", _btn_box(Color8(255, 232, 220)))
	b.add_theme_stylebox_override("pressed", _btn_box(Color8(240, 210, 200)))
	return b


func _btn_box(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.border_color = Color8(190, 120, 100)
	sb.set_border_width_all(maxi(1, int(round(_px(1.5)))))
	sb.set_corner_radius_all(int(round(_px(9.0))))
	return sb


func _hover_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color8(120, 180, 255, 90)
	sb.set_corner_radius_all(int(round(_px(4.0))))
	return sb


func _menu_label(which: String) -> String:
	match which:
		"buy":
			return "买进"
		"sell":
			return "卖出"
		"holder":
			return "股东"
		"trend":
			return "走势"
	return which


# ------------------------------------------------------------------ 同步

## 每帧/快照变化时刷新。`me` = 本地玩家字典（取持股用），`sim` = 权威模拟。
func _sync(_delta: float, me_id: String) -> void:
	if Net.sim == null:
		return
	var sim: Sim = Net.sim
	var names: Array = sim.stock_names()
	var page := _page
	var total := names.size()
	var max_page: int = maxi(0, int(ceil(float(total) / float(VISIBLE_ROWS))) - 1)
	_page = clampi(_page, 0, max_page)
	page = _page

	var me: Dictionary = sim.players.get(multiplayer.get_unique_id(), {})
	var sig := "%d|%d" % [page, me_id.hash()]
	for nm in names:
		sig += "%s%.2f%d;" % [str(nm), sim.stock_price(str(nm)),
			sim.holding_of(int(me.get("id", 0)), str(nm))]
	if sig == _sig:
		return
	_sig = sig

	for r in range(_rows.size()):
		var rec: Dictionary = _rows[r]
		var labels: Array = rec["labels"]
		var i := page * VISIBLE_ROWS + r
		if i >= names.size():
			rec["name"] = ""
			for lb in labels:
				(lb as Label).text = ""
			continue
		var comp := str(names[i])
		rec["name"] = comp
		var price := sim.stock_price(comp)
		var hold := sim.holding_of(int(me.get("id", 0)), comp)
		var chg := sim.stock_change(comp)
		(labels[0] as Label).text = comp
		(labels[1] as Label).text = "%.1f" % price
		(labels[2] as Label).text = str(hold) if hold > 0 else "0"
		var sign_txt := ("+%d" % chg) if chg > 0 else str(chg)
		(labels[3] as Label).text = sign_txt
		# 涨红跌绿（中国股市惯例）
		var col := Color8(24, 28, 44)
		if chg > 0:
			col = Color8(206, 44, 44)
		elif chg < 0:
			col = Color8(20, 140, 60)
		(labels[3] as Label).add_theme_color_override("font_color", col)
		if hold > 0:
			(labels[2] as Label).add_theme_color_override("font_color", Color8(30, 90, 190))

	_hint.text = "共 %d 家 ▲▼ 翻页 ｜ 点一行操作" % total
	_sync_layout()


func _sync_layout() -> void:
	var vp := get_viewport().get_visible_rect()
	var sz := _bg.get_combined_minimum_size()
	# 贴在**右下角**（原版就在这里）；上方留出 HUD 的工具栏与顶栏
	# ⚠ 底边必须让开右下角的**小地图 + 工具栏**（app.gd 的 `UI_BR_MAP_H` 156.7 +
	#   `UI_BR_BAR_H` 36.7 + 边距 ≈ 200 native），否则行情面板会压在小地图上。
	_bg.position = Vector2(vp.size.x - sz.x - _px(6.0), vp.size.y - sz.y - _px(200.0))
	_bg.size = sz
	if _menu.visible:
		var ms := _menu.get_combined_minimum_size()
		_menu.position = Vector2(_bg.position.x - ms.x - _px(2.0), _bg.position.y)
		_menu.size = ms
	if _dlg.visible:
		var ds := _dlg.get_combined_minimum_size()
		_dlg.size = ds
		_dlg.position = Vector2((vp.size.x - ds.x) * 0.5, (vp.size.y - ds.y) * 0.42)


func _process(_d: float) -> void:
	pass


func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and _bg.get_global_rect().has_point(
				mb.position):
			_page -= 1
			_sig = ""
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and _bg.get_global_rect().has_point(
				mb.position):
			_page += 1
			_sig = ""


# ------------------------------------------------------------------ 交互

func _on_row_clicked(r: int) -> void:
	var rec: Dictionary = _rows[r] if r < _rows.size() else {}
	var comp := str(rec.get("name", ""))
	if comp == "":
		return
	_sel = comp
	_menu.visible = true
	_sync_layout()


func _on_menu(which: String) -> void:
	_menu.visible = false
	if _sel == "" or Net.sim == null:
		return
	match which:
		"buy", "sell":
			_dlg_buy = which == "buy"
			_dlg_title.text = "买进" if _dlg_buy else "卖出"
			var hold := Net.sim.holding_of(multiplayer.get_unique_id(), _sel)
			_dlg_input.text = "100" if _dlg_buy else str(maxi(hold, 0))
			_dlg.visible = true
			_refresh_amount()
			_sync_layout()
		"holder":
			act_requested.emit("holder", _sel, 0)
		"trend":
			act_requested.emit("trend", _sel, 0)


func _refresh_amount() -> void:
	if Net.sim == null:
		return
	var n := int(_dlg_input.text) if _dlg_input.text.is_valid_int() else 0
	n = maxi(n, 0)
	var price := Net.sim.stock_price(_sel)
	var total := int(round(price * float(n)))
	_dlg_amount.text = "%d" % total


func _confirm_dialog(ok: bool) -> void:
	_dlg.visible = false
	if not ok or Net.sim == null:
		return
	var n := int(_dlg_input.text) if _dlg_input.text.is_valid_int() else 0
	if n <= 0:
		return
	act_requested.emit("buy" if _dlg_buy else "sell", _sel, n)
	_sig = ""


func close_all() -> void:
	_menu.visible = false
	_dlg.visible = false


func menu_open() -> bool:
	return _menu.visible or _dlg.visible
