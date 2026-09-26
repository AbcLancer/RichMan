class_name HudNumber
extends HBoxContainer
## 顶栏/面板数字控件 —— 用原版数字贴图逐字拼。
##
## 贴图来源：`game/assets/ui/hud/num_*.png`，由 `tools/make_hud_ui.py` 切自
## `game/assets/uitex/other/number1.tga`（原版顶栏那套**粗体白字 + 深蓝描边**）。
## → 所以这里 modulate 请保持白色，不要染色。
##
## 版式（`docs/ui-audit.md`，原版 1024×768 单位）：
##   数字高 17.1、字距 3.4；原版数字比 number1 的字形**横向宽约 1.38 倍**
##   （同高并排比对定案，见 `.workbuddy/tmp/ui/digit_cmp.png`）→ 故 x 方向额外拉伸。

const DIR := "res://assets/ui/hud/"
const SHEET_CAP := 41.0            ## number1.tga 里数字的墨迹高（px）
const DIGIT_H := 17.1              ## 目标字高（原版 1024×768 像素）
const STRETCH_X := 1.38            ## 横向补偿（实测）
const GAP_NATIVE := 3.4            ## 字距
const SLASH_H := 15.33             ## `/` 单独量（来自原版 x/y 面板截图）

static var _tex: Dictionary = {}   ## 贴图缓存（跨实例共享）

var ui_scale: float = 1.0:
	set(v):
		ui_scale = maxf(v, 0.01)
		_sync()

var _text: String = ""
var _pool: Array[TextureRect] = []


static func _tex_of(name: String) -> Texture2D:
	if not _tex.has(name):
		var p := DIR + name + ".png"
		_tex[name] = load(p) if ResourceLoader.exists(p) else null
	return _tex[name]


func _ready() -> void:
	add_theme_constant_override("separation", maxi(1, int(round(GAP_NATIVE * ui_scale))))
	_sync()


func set_text(v: Variant) -> void:
	var s := str(v)
	if s == _text:
		return
	_text = s
	_sync()


func _sync() -> void:
	if not is_inside_tree():
		return
	while _pool.size() < _text.length():
		var t := TextureRect.new()
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(t)
		_pool.append(t)
	for i in _pool.size():
		var t: TextureRect = _pool[i]
		if i >= _text.length():
			t.visible = false
			continue
		var ch := _text[i]
		var is_slash := ch == "/"
		var tex: Texture2D = _tex_of("num_slash" if is_slash else ("num_" + ch))
		if tex == null:
			t.visible = false
			continue
		var h := float(tex.get_height())
		if h <= 0.0:
			continue
		t.visible = true
		t.texture = tex
		# 斜杠已经是从原版截图直接裁的（已含原版拉伸），不再补横向
		var cap := SLASH_H if is_slash else DIGIT_H
		var sy := cap * ui_scale / h
		var sx := sy if is_slash else sy * STRETCH_X
		var sz: Vector2 = tex.get_size() * Vector2(sx, sy)
		t.custom_minimum_size = sz
		t.size = sz
