extends Control
class_name Minimap
## Minimap —— 原版右下角小地图
##
## 底图用原版 `uitex/subc/m_<map>.tga`（已转 png）。
## 埃及标记使用从原程序恢复的小地图变换，与地面 UV 分开。

const C_PATH := Color(0.30, 0.18, 0.06, 0.85)
const C_PLOT_FREE := Color(0.85, 0.80, 0.70, 0.85)
const C_EVENT := Color(1.0, 0.82, 0.25, 0.95)
const C_START := Color(0.35, 0.92, 0.5, 0.95)

var map: MapData = null
var snap: Dictionary = {}
var my_id: int = 0

var _tex: Texture2D = null
## 原版底图 `m_<map>.png` 是 256×128，但**第 99 行往下是一条装饰蓝条，不是地形**。
## 原版小地图的做法是：**裁掉蓝条、把地形区铺满整个框**（不是等比居中）。
## 依据：`tools/_tmp_mini_cmp.py` 出的四联对比图 —— 「只取地形 99 行铺满」与原版实机
## 的路径走向、河流、红方块、蓝方块、红十字图标位置逐项吻合；整图铺满则底部露出蓝条。
## 逐图实测起始行：aiji/china/japan/paris/space/train = 99，island = 98（取 98 更保险）。
const TERRAIN_ROWS := 98

## UV has already accounted for the source texture crop.
var _map_h_ratio := 1.0


func setup(m: MapData) -> void:
	map = m
	_tex = null
	_map_h_ratio = 1.0
	if m != null:
		var p := "res://assets/uitex/subc/m_%s.png" % m.name
		if ResourceLoader.exists(p):
			var r: Resource = load(p)
			if r is Texture2D:
				_tex = r
	queue_redraw()


## 底图在控件内的绘制矩形：**铺满**（原版就是铺满，不做等比居中）
func _content_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size)


## 贴图上真正是「地形」的那块区域（去掉底部装饰蓝条）
func _terrain_region() -> Rect2:
	if _tex == null:
		return Rect2()
	var ts := _tex.get_size()
	if ts.y <= float(TERRAIN_ROWS):
		return Rect2(Vector2.ZERO, ts)
	return Rect2(0.0, 0.0, ts.x, float(TERRAIN_ROWS))


func update_state(s: Dictionary, me_id: int) -> void:
	snap = s
	my_id = me_id
	queue_redraw()


## The original minimap transform is independent from the ground texture UV.
func _uv(i: int) -> Vector2:
	if map == null:
		return Vector2.ZERO
	return map.minimap_uv(i)


## UV → 控件像素（只落在地图区内，不含底部装饰条）
func _px_from_uv(uv: Vector2) -> Vector2:
	var r := _content_rect()
	return Vector2(r.position.x + uv.x * r.size.x,
		r.position.y + uv.y * r.size.y * _map_h_ratio)


func _px(i: int) -> Vector2:
	return _px_from_uv(_uv(i))


func _draw() -> void:
	var full := Rect2(Vector2.ZERO, size)
	if _tex != null:
		draw_texture_rect_region(_tex, _content_rect(), _terrain_region())
	else:
		draw_rect(full, Color(0.10, 0.14, 0.20, 0.9), true)

	if map == null or map.tile_count() == 0:
		return
	# 没有逆向坐标的地图（只有埃及有），叠加层会与底图对不上 → 只显示底图
	if not map.has_real_layout:
		return
	var n := map.tile_count()

	# 路径折线（闭合）
	var pts := PackedVector2Array()
	for i in range(n):
		pts.append(_px(i))
	pts.append(_px(0))
	draw_polyline(pts, C_PATH, 1.6, true)

	# 地块点
	for i in range(n):
		var p := _px(i)
		var t: Dictionary = map.tile(i)
		var kind: String = t.get("kind", "")
		if kind == "start":
			draw_circle(p, 3.0, C_START)
		elif kind == "event":
			draw_circle(p, 2.2, C_EVENT)
		else:
			var col := C_PLOT_FREE
			var plots: Dictionary = snap.get("plots", {})
			var players: Dictionary = snap.get("players", {})
			if plots.has(i) and players.has(int(plots[i]["owner"])):
				col = Color.html(str(players[int(plots[i]["owner"])]["color"]))
			draw_circle(p, 2.0, col)

	# 玩家
	var players: Dictionary = snap.get("players", {})
	for id in players.keys():
		var pl: Dictionary = players[int(id)]
		if not bool(pl["alive"]):
			continue
		var p := _px_from_uv(map.minimap_uv(int(pl["tile"]), int(pl["dir"]),
			clampf(float(pl["progress"]), 0.0, 1.0)))
		var col := Color.html(str(pl["color"]))
		if int(id) == my_id:
			draw_circle(p, 5.2, Color(1, 1, 1, 0.95))
			draw_circle(p, 3.6, col)
		else:
			draw_circle(p, 4.0, Color(0, 0, 0, 0.55))
			draw_circle(p, 2.8, col)
