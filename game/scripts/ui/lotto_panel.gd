extends Control
class_name LottoPanel
## **乐透**面板 —— 素材全部来自原版 `uitex/casino2/`：
##
## | 素材 | 用途 |
## |---|---|
## | `背景.tga`(256²) | 粉色面板，**号码格 1..12 已经画在底图里**（3 行 × 4 列） |
## | `姑娘1..3.tga`(128×256) | 兔子女郎 |
## | `mark.tga`(32²) | 号码格上的**标记**（已开奖的号码） |
## | `cursor.tga`(32²) | 红色指针（当前指到的格子） |
## | `exit.tga`(64×32) | 离开 |
##
## 依据 = 老板的原版实机截图（`docs/screenshots/orig/records/乐透界面.png`：
## 粉色面板 + 左「今日乐透开奖，您的号码是」+ 中间 1..12 号格 + 右侧兔子女郎 + 右下 EXIT）。
##
## 格子的像素坐标是**从底图量出来的**（橙色格的行/列分段）：4 列 × 3 行，
## 见下面 `CELL_X / CELL_Y`。⚠️ 换底图要重新量。

signal act(kind: String, number: int)

const HEIGHT := 234.0 # Native 44d4c0; the exported texture includes 22 transparent top rows.
const SIDE := 256.0                       # 底图原尺寸 = 原版面板尺寸（1024×768 下的 native）
## 号码格（量自底图）：第 1 格左上角 + 格宽 + 间距
const CELL_X0 := 14.0
const CELL_Y0 := 94.0
const CELL_W := 39.0
const CELL_H := 39.0
const CELL_DX := 43.0
const CELL_DY := 43.0

var _scale := 1.0
var _bg: TextureRect
var _girl: TextureRect
var _marks: Array = []                    # 12 个标记（mark.png）
var _cursors: Array = []                  # 12 个指针（cursor.png）
var _cells: Array = []                    # 12 个透明按钮
var _title: Label
var _picked := -1                         # 本机已选的号码
var _open_numbers: Dictionary = {}        # 号码 -> 被谁选走（只用来把格子压暗）

class NumberRing:
	extends Control
	func _draw() -> void:
		draw_arc(size * .5, minf(size.x, size.y) * .37, 0, TAU, 48,
			Color8(227, 34, 45), maxf(2.0, size.x * .075), true)


func setup(ui_scale: float) -> void:
	_scale = ui_scale * 1.4
	visible = false
	z_index = 46
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	var vp := get_viewport().get_visible_rect()
	var side := SIDE * _scale
	size = Vector2(side, HEIGHT * _scale)
	position = Vector2((vp.size.x - side) * 0.5, (vp.size.y - HEIGHT * _scale) * 0.5)


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


## 号码格中心（1..12 → 3 行 4 列）
func _cell_rect(n: int) -> Rect2:
	var i := n - 1
	var col := i % 4
	var row := i / 4
	return Rect2(_px(CELL_X0 + float(col) * CELL_DX), _px(CELL_Y0 + float(row) * CELL_DY),
		_px(CELL_W), _px(CELL_H))


func _build() -> void:
	_bg = _img("lotto_bg.png", Vector2.ZERO, Vector2(_px(SIDE), _px(HEIGHT)))
	var atlas := AtlasTexture.new()
	atlas.atlas = _tex("lotto_bg.png")
	atlas.region = Rect2(0, 22, SIDE, HEIGHT)
	_bg.texture = atlas
	# 兔子女郎：底图右侧是空的，把人立在右上（同原版——女郎从面板右边探出来）
	_girl = _img("lotto_girl1.png", Vector2(_px(SIDE * 0.60), _px(-SIDE * 0.12)),
		Vector2(_px(SIDE * 0.42), _px(SIDE * 0.84)))

	# 顶部提示（原版那句「今日乐透开奖，您的号码是」）
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.add_theme_font_size_override("font_size", maxi(9, int(round(_px(12.0)))))
	_title.add_theme_color_override("font_color", Color8(120, 20, 40))
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.position = Vector2(_px(17), _px(28))
	_title.size = Vector2(_px(104), _px(51))
	add_child(_title)

	# 12 个号码格：标记 + 指针 + 透明按钮
	for n in range(1, 13):
		var r := _cell_rect(n)
		var mk := NumberRing.new()
		mk.position = r.position
		mk.size = r.size
		mk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(mk)
		mk.visible = false
		_marks.append(mk)
		var cu := _img("lotto_cursor.png", r.position,
			Vector2(r.size.x * 0.42, r.size.x * 0.42))
		cu.visible = false
		_cursors.append(cu)
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.position = r.position
		b.size = r.size
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", _hover_box())
		b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		var nn := n
		b.mouse_entered.connect(func(): _show_cursor(nn))
		b.mouse_exited.connect(func(): _hide_cursor(nn))
		b.pressed.connect(func(): act.emit("pick", nn))
		add_child(b)
		_cells.append(b)

	var ex := TextureButton.new()
	ex.texture_normal = _tex("lotto_exit.png")
	ex.ignore_texture_size = true
	ex.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	ex.position = Vector2(_px(188), _px(177))
	ex.size = Vector2(_px(55), _px(29))
	ex.pressed.connect(func(): act.emit("exit", 0))
	add_child(ex)


func _hover_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.96, 0.6, 0.35)
	sb.border_color = Color8(255, 120, 60)
	sb.set_border_width_all(maxi(1, int(round(_px(2.0)))))
	sb.set_corner_radius_all(int(round(_px(4.0))))
	return sb


func _show_cursor(n: int) -> void:
	if n - 1 < _cursors.size():
		var cursor := _cursors[n - 1] as TextureRect
		cursor.visible = true
		_place_cursor(cursor)

func _process(_delta: float) -> void:
	if not visible: return
	for cursor in _cursors:
		if cursor.visible: _place_cursor(cursor)

func _place_cursor(cursor: TextureRect) -> void:
	# The original pencil points near its lower-right edge. Keep that nib on
	# the actual mouse position instead of pinning the art above a cell.
	cursor.position = get_local_mouse_position() - cursor.size * Vector2(.78, .86)


func _hide_cursor(n: int) -> void:
	if n - 1 < _cursors.size():
		(_cursors[n - 1] as TextureRect).visible = false


## 打开面板（进乐透事件格时）
var _session := 0

func open(prize: int, taken: Dictionary, own_number: int = -1) -> void:
	_session += 1
	visible = true
	_girl.texture = _tex("lotto_girl1.png")
	_picked = own_number
	for mark in _marks: mark.visible = false
	for cursor in _cursors: cursor.visible = false
	_open_numbers = taken.duplicate()
	if own_number >= 1 and own_number <= _marks.size(): _marks[own_number - 1].visible = true
	_apply_state(prize, "您已购买号码：%d\n等待开奖" % own_number if own_number >= 1 else "")


## 选完号码 / 开奖后的状态刷新
func mark_picked(n: int) -> void:
	_picked = n
	_open_numbers[n] = -1
	for i in range(_marks.size()): _marks[i].visible = i == n - 1
	_apply_state(-1, "您的号码：%d" % n)
	var ticket := _session
	await get_tree().create_timer(2.0).timeout
	if ticket == _session: close()


## 开奖展示：把中奖号码的标记亮起来
func show_draw(win_n: int, winner_name: String, amount: int) -> void:
	_session += 1
	visible = true
	_picked = win_n # Result view cannot accept another purchase.
	for cursor in _cursors: cursor.visible = false
	for n in range(1, 13):
		(_marks[n - 1] as NumberRing).visible = (n == win_n)
	var txt := "开奖号码 %d" % win_n
	if winner_name != "":
		txt += "\n%s\n奖金 %d" % [winner_name, amount]
	else:
		txt += "\n本月无人中奖\n号码保留至下期"
	_apply_state(-1, txt)
	_girl.texture = _tex("lotto_girl2.png" if winner_name != "" else "lotto_girl3.png")
	var ticket := _session
	await get_tree().create_timer(3.0).timeout
	if ticket == _session: close()


func _apply_state(prize: int, extra: String) -> void:
	if prize >= 0:
		_title.text = "今日乐透开奖\n您的号码是\n奖池 %d" % prize
	if extra != "":
		_title.text = extra
	# 已被选走的格子压暗（原版：选过的号码不再可选）
	for n in range(1, 13):
		var b: Button = _cells[n - 1]
		var taken := n in _open_numbers and _picked != n
		b.disabled = taken or _picked >= 1
		(_cells[n - 1] as Button).modulate = Color(1, 1, 1, 1) if not taken \
			else Color(0.55, 0.55, 0.6, 0.85)


func close() -> void:
	_session += 1
	visible = false
