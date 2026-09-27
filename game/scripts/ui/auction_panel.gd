extends Control
class_name AuctionPanel
## **拍卖**面板 —— 素材来自 `uitex/auction/`：
##
## | 素材 | 用途 |
## |---|---|
## | `back.tga`(256²) | 面板底（**已含拍卖师立绘 + 地皮预览框 + 三行信息栏**） |
## | `100/500/1000.tga`(64×32) | 加价档位按钮（**这就是加价的三个档**） |
## | `ok_up/dn.tga`(32×16) | 确认出价 |
## | `pass_up/dn.tga`(32×16) | 放弃（PASS） |
## | `bar.tga`(32²) | 行情条小图 |
##
## 依据 = `Info.txt` 364..367：
##   4001「`<ROAD>`一处土地公开拍卖。」/ 4002「SORRY 加价**不得少于100元**。」
##   4003「`<SOMEONE>`成功竞购`<ROAD>`土地。」
##
## ⚠️ 交互是**推断**出来的（原版没有界面说明）：
##   「先点 `+100/+500/+1000` 选加价额 → 再按 `OK` 提交；`PASS` 放弃」。
##   三行信息栏的位置是从底图上看出来的（左侧立绘、右上地皮、右下三条横栏）。

signal act(kind: String, amount: int)

const SIDE := 256.0

var _scale := 1.0
var _title: Label
var _sub: Label
var _third: Label
var _bar: ProgressBar
var _picked := 100
var _add_btns: Array = []


func setup(ui_scale: float) -> void:
	_scale = ui_scale
	visible = false
	z_index = 48
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	var vp := get_viewport().get_visible_rect()
	size = Vector2(SIDE * _scale, SIDE * _scale)
	position = Vector2((vp.size.x - size.x) * 0.5, (vp.size.y - size.y) * 0.42)


func _px(v: float) -> float:
	return v * _scale


func _tex(name: String) -> Texture2D:
	var p := "res://assets/ui/shop/auction_" + name
	if not ResourceLoader.exists(p):
		return null
	var r: Resource = VisualQuality.texture(p, true)
	return r if r is Texture2D else null


func _img(name: String, pos: Vector2, sz: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = _tex(name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.position = pos
	t.size = sz
	add_child(t)
	return t


func _label(pos: Vector2, sz: Vector2, fsz: float, col: Color) -> Label:
	var lb := Label.new()
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override("font_size", maxi(8, int(round(_px(fsz)))))
	lb.add_theme_color_override("font_color", col)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.position = pos
	lb.size = sz
	add_child(lb)
	return lb


func _build() -> void:
	_img("bg.png", Vector2.ZERO, Vector2(_px(SIDE), _px(SIDE)))
	# 底图右侧下方有三条白框信息栏 → 文字要**落在框里**（所以左右都留了边距、字号压小）
	_title = _label(Vector2(_px(16), _px(148)), Vector2(_px(178), _px(15)), 9.5,
		Color8(90, 40, 30))
	_sub = _label(Vector2(_px(16), _px(170)), Vector2(_px(178), _px(15)), 9.5,
		Color8(180, 40, 40))
	_third = _label(Vector2(_px(16), _px(192)), Vector2(_px(178), _px(15)), 9,
		Color8(70, 60, 90))

	# 倒计时条
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.position = Vector2(_px(20), _px(214))
	_bar.size = Vector2(_px(216), _px(7))
	_bar.min_value = 0.0
	_bar.max_value = 100.0
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color8(70, 30, 30, 180)
	_bar.add_theme_stylebox_override("background", sb)
	var sf := StyleBoxFlat.new()
	sf.bg_color = Color8(255, 170, 60)
	_bar.add_theme_stylebox_override("fill", sf)
	add_child(_bar)

	# 三个加价档（素材就是 100 / 500 / 1000）
	var add_row := HBoxContainer.new()
	add_row.position = Vector2(_px(18), _px(226))
	add_row.add_theme_constant_override("separation", maxi(1, int(round(_px(3)))))
	add_child(add_row)
	for amt in [100, 500, 1000]:
		var b := TextureButton.new()
		b.texture_normal = _tex("add%d.png" % amt)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(_px(58), _px(26))
		var a := int(amt)
		b.pressed.connect(func(): _pick_add(a))
		add_row.add_child(b)
		_add_btns.append({"btn": b, "amt": a})

	# OK / PASS
	var ok := TextureButton.new()
	ok.texture_normal = _tex("ok.png")
	ok.texture_pressed = _tex("ok_dn.png")
	ok.ignore_texture_size = true
	ok.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	ok.position = Vector2(_px(196), _px(226))
	ok.size = Vector2(_px(40), _px(26))
	ok.pressed.connect(func(): act.emit("bid", _picked))
	add_child(ok)

	var pass_btn := TextureButton.new()
	pass_btn.texture_normal = _tex("pass.png")
	pass_btn.texture_pressed = _tex("pass_dn.png")
	pass_btn.ignore_texture_size = true
	pass_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	pass_btn.position = Vector2(_px(196), _px(254))
	pass_btn.size = Vector2(_px(40), _px(20))
	pass_btn.pressed.connect(func(): act.emit("pass", 0))
	add_child(pass_btn)

	_pick_add(100)


func _pick_add(a: int) -> void:
	_picked = a
	for e in _add_btns:
		var b: TextureButton = e["btn"]
		b.modulate = Color(1, 1, 1, 1) if int(e["amt"]) == a else Color(0.72, 0.72, 0.78, 0.9)


## 开拍 / 刷新
func open(street: String, price: int, best_name: String, left_ratio: float) -> void:
	visible = true
	_title.text = "%s 一处土地公开拍卖" % street
	_sub.text = "当前价 %d 元" % price
	_third.text = ("最高出价：%s" % best_name) if best_name != "" else "还没有人出价"
	_bar.value = clampf(left_ratio, 0.0, 1.0) * 100.0


func close() -> void:
	visible = false
