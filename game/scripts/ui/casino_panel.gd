extends Control
class_name CasinoPanel
## **拉霸（老虎机）** 面板 —— 素材全部来自原版 `uitex/casino/`：
##
## | 素材 | 用途 |
## |---|---|
## | `背景.tga` | 粉色拱形面板（顶窗 + 中间米色显示区 + 下方按钮条） |
## | `姑娘1..3.tga` | 兔子女郎（换姿势当「正在转」的反馈） |
## | `pull_1/pull_2.tga` | 拉杆（上/下） |
## | `add1..3.tga` | `+1000` / `+5000` / `+10000` 三档下注 |
## | `7/香蕉/财神.tga` | 三个滚轮的符号 |
## | `exit.tga` | 离开 |
##
## 依据 = 老板 2026-09-26 的原版截图（`docs/screenshots/orig/records/老虎机.png`：
## 左侧滑出的粉色面板 + 三个滚轮 + 「请投注」+ 三档下注 + EXIT）。
##
## ⚠️ 滚轮停格的**动画节奏**原版看不出来 → 这里取「三个滚轮依次停下」，属于表现层推断。

signal act(kind: String, amount: int)

const SIDE := 256.0              # 面板基准边长（native）
const SYM := {"sym7": "casino_sym7",
	"sym_banana": "casino_sym_banana", "sym_god": "casino_sym_god"}

var _scale := 1.0
var _bg: TextureRect
var _reels: Array = []           # 3 个 TextureRect
var _girl: TextureRect
var _bet_lbl: Label
var _pull: TextureButton
var _spin_t := 0.0
var _spin_left := 0.0
var _spin_idx := 0
var _reel_tex: Array = []
var _result := ""
var _resolved := false
var _won := false
var _close_left := -1.0
var _bet_buttons: Array[TextureButton] = []


func setup(ui_scale: float) -> void:
	_scale = ui_scale * 1.4
	visible = false
	z_index = 45
	mouse_filter = Control.MOUSE_FILTER_STOP
	for k in SYM.keys():
		var t: Texture2D = _tex(str(SYM[k]) + ".png")
		if t != null:
			_reel_tex.append(t)
	_build()
	# 摆位：**左侧滑出**（原版就是从左边滑出来的）
	var vp := get_viewport().get_visible_rect()
	var side := SIDE * _scale
	size = Vector2(_px(220), side)
	position = Vector2(10.0 * _scale, (vp.size.y - side) * 0.5)


func _px(v: float) -> float:
	return v * _scale


func _tex(name: String) -> Texture2D:
	var p := "res://assets/ui/shop/" + name
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


func _build() -> void:
	_bg = _img("casino_bg.png", Vector2.ZERO, Vector2(_px(SIDE), _px(SIDE)))
	# 三个滚轮（面板中间那三个米色格）
	var rw := _px(34)
	var gap := _px(9)
	var x0 := _px(41)
	var ry := _px(150)
	for i in range(3):
		var r := _img("casino_btn.png", Vector2(x0 + float(i) * (rw + gap), ry),
			Vector2(rw, _px(32)))
		r.texture = _reel_tex[0] if not _reel_tex.is_empty() else r.texture
		_reels.append(r)
	# 兔子女郎（面板顶上那个窗口）
	_girl = _img("casino_girl1.png", Vector2(_px(37), _px(15)),
		Vector2(_px(128), _px(128)))
	# 下注额
	_bet_lbl = Label.new()
	_bet_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bet_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bet_lbl.add_theme_font_size_override("font_size", maxi(10, int(round(_px(15.0)))))
	_bet_lbl.add_theme_color_override("font_color", Color8(70, 40, 60))
	_bet_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bet_lbl.position = Vector2(_px(17), _px(188))
	_bet_lbl.size = Vector2(_px(164), _px(20))
	add_child(_bet_lbl)
	# 三档下注 + 拉杆 + EXIT
	var bw := _px(54)
	var bh := _px(24)
	var by := _px(211)
	for i in range(3):
		var b := TextureButton.new()
		b.texture_normal = _tex("casino_add%d.png" % (i + 1))
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.position = Vector2(_px(17 + i * 55), by)
		b.size = Vector2(bw, bh)
		var amt: int = int([1000, 5000, 10000][i])
		b.pressed.connect(func():
			if not _resolved: act.emit("bet", amt))
		add_child(b)
		_bet_buttons.append(b)
	_pull = TextureButton.new()
	_pull.texture_normal = _tex("casino_pull1.png")
	_pull.texture_pressed = _tex("casino_pull2.png")
	_pull.ignore_texture_size = true
	_pull.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_pull.position = Vector2(_px(182), _px(110))
	_pull.size = Vector2(_px(31), _px(75))
	_pull.pressed.connect(func(): _on_pull())
	add_child(_pull)
	var ex := TextureButton.new()
	ex.texture_normal = _tex("casino_exit.png")
	ex.ignore_texture_size = true
	ex.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	ex.position = Vector2(_px(2), _px(143))
	ex.size = Vector2(_px(28), _px(42))
	ex.pressed.connect(func(): act.emit("exit", 0))
	add_child(ex)


func _on_pull() -> void:
	if _resolved or _spin_left > 0.0:
		return
	act.emit("pull", 0)
	# 三个滚轮依次停下（表现层推断）
	_spin_left = 2.0
	_spin_t = 0.0
	_spin_idx = 0


func open() -> void:
	visible = true
	_result = "请投注"
	_resolved = false
	_won = false
	_close_left = -1.0
	_spin_left = 0.0
	if _girl != null: _girl.texture = _tex("casino_girl1.png")


func close() -> void:
	visible = false


## 每帧：转轮动画 + 刷新下注额
func tick(delta: float, bet: int, reels: Array) -> void:
	if not visible:
		return
	if _bet_lbl != null:
		_bet_lbl.text = "注 %d" % bet if bet > 0 else _result
	for b in _bet_buttons:
		b.disabled = bet > 0 or _resolved
	_pull.disabled = bet <= 0 or _resolved
	if not reels.is_empty() and reels.size() == _reels.size():
		for i in range(_reels.size()):
			var key := str(reels[i])
			if _spin_left > 0.0 and i >= _spin_idx:
				# 还在转：快速轮播
				if not _reel_tex.is_empty():
					var k: int = int(_spin_t * 18.0 + float(i)) % _reel_tex.size()
					(_reels[i] as TextureRect).texture = _reel_tex[k]
			else:
				var t2 := _tex(str(SYM.get(key, "casino_sym7")) + ".png")
				if t2 != null:
					(_reels[i] as TextureRect).texture = t2
	if _spin_left > 0.0:
		_spin_t += delta
		_spin_left -= delta
		_spin_idx = clampi(3 - int(ceil(_spin_left / (2.0 / 3.0))), 0, 3)
		if _spin_left <= 0.0 and _resolved and _girl != null:
			_girl.texture = _tex("casino_girl2.png" if _won else "casino_girl3.png")
	if _resolved and _spin_left <= 0.0:
		_close_left -= delta
		if _close_left <= 0.0: close()


func set_result(txt: String, won: bool = false) -> void:
	_result = txt
	_resolved = true
	_won = won
	_close_left = 1.0 if won else 2.0 # Native 44d1c0 result dwell.
	if _spin_left <= 0.0 and _girl != null:
		_girl.texture = _tex("casino_girl2.png" if won else "casino_girl3.png")
