extends Node3D
class_name BoardView
## BoardView —— 3D 棋盘表现层
##
## 只负责「把权威状态画出来」，不含任何玩法逻辑。
## 棋盘沿矩形外圈铺设（与原版大富翁的环形路径一致）。
## 相机默认参数取自原版 .r6m 头部（距离 12 格 / 俯角 30~45°）。

const TILE_SIZE := 1.0
const TILE_GAP := 0.12
const TILE_HEIGHT := 0.30

var map: MapData = null

var _tile_nodes: Array = []      # MeshInstance3D
var _tile_mats: Array = []       # StandardMaterial3D
var _tile_pos: Array = []        # Vector3
var _player_nodes: Dictionary = {}  # id -> Node3D
var _player_mats: Dictionary = {}
var _cells := Vector2i(0, 0)

const C_START := Color(0.16, 0.55, 0.30)
const C_PLOT := Color(0.30, 0.32, 0.38)
const C_EVENT := Color(0.78, 0.62, 0.18)


func build(m: MapData) -> void:
	clear()
	if m == null:
		return
	map = m
	_cells = _perimeter_cells(m.tile_count())

	var step := TILE_SIZE + TILE_GAP
	var origin := Vector2((_cells.x - 1) * step * 0.5, (_cells.y - 1) * step * 0.5)

	for i in range(m.tile_count()):
		var g := _perimeter_pos(i)
		var pos := Vector3(g.x * step - origin.x, 0, g.y * step - origin.y)
		_tile_pos.append(pos)

		var t: Dictionary = m.tile(i)
		var col := C_PLOT
		match t.get("kind", ""):
			"start": col = C_START
			"event": col = C_EVENT

		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		mat.roughness = 0.85

		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(TILE_SIZE, TILE_HEIGHT, TILE_SIZE)
		mi.mesh = bm
		mi.material_override = mat
		mi.position = pos + Vector3(0, TILE_HEIGHT * 0.5, 0)
		add_child(mi)
		_tile_nodes.append(mi)
		_tile_mats.append(mat)

		# 格名标签（地产格显示街道名）
		var txt: String = ""
		if t.get("kind", "") == "plot" and int(t.get("plot_in_street", 0)) == 0:
			txt = str(t.get("street", ""))
		elif t.get("kind", "") == "event":
			txt = str(t.get("name", ""))
		elif t.get("kind", "") == "start":
			txt = "起点"
		if txt != "":
			var lab := Label3D.new()
			lab.text = txt
			lab.font_size = 64
			lab.pixel_size = 0.0042
			lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lab.no_depth_test = true
			lab.modulate = Color(0.88, 0.90, 0.95)
			lab.position = pos + Vector3(0, 0.95, 0)
			add_child(lab)

	# 相机按原版参数摆放（距离 12 格 / 俯角取自 .r6m），并按棋盘尺寸取景
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var span := maxf(_cells.x, _cells.y) * step
		var yaw: float = float(map.camera.get("yaw", 30.0))
		var d := span * 0.46
		cam.position = Vector3(0, d * sin(deg_to_rad(yaw)) * 1.30 + 4.0,
			d * cos(deg_to_rad(yaw)) * 1.30)
		cam.look_at(Vector3(0, 0, 0))
		cam.v_offset = -1.6          # 上移，避开左下日志面板与右下按钮


func clear() -> void:
	for c in get_children():
		c.queue_free()
	_tile_nodes.clear()
	_tile_mats.clear()
	_tile_pos.clear()
	_player_nodes.clear()
	_player_mats.clear()
	map = null


## 矩形外圈周长排布：给定 tiles 数，反推矩形行列
func _perimeter_cells(n: int) -> Vector2i:
	var total := int((n + 4) / 2.0)
	var cols := int(round(total * 0.62))
	cols = clampi(cols, 3, total - 2)
	return Vector2i(cols, total - cols)


func _perimeter_pos(i: int) -> Vector2i:
	## 顺时针：底边 → 右边 → 顶边 → 左边
	var cols := _cells.x
	var rows := _cells.y
	var bottom := cols
	var right := rows - 1
	var top := cols - 1
	var left := rows - 2

	if i < bottom:
		return Vector2i(i, 0)
	i -= bottom
	if i < right:
		return Vector2i(cols - 1, 1 + i)
	i -= right
	if i < top:
		return Vector2i(cols - 2 - i, rows - 1)
	i -= top
	if i < left:
		return Vector2i(0, rows - 2 - i)
	return Vector2i(0, 0)


func _pos_at(tile_index: int) -> Vector3:
	if _tile_pos.is_empty():
		return Vector3.ZERO
	var n := _tile_pos.size()
	return _tile_pos[((tile_index % n) + n) % n]


func sync(snap: Dictionary) -> void:
	if map == null:
		return
	var players: Dictionary = snap.get("players", {})
	var plots: Dictionary = snap.get("plots", {})

	# 地产归属着色
	for i in range(_tile_mats.size()):
		var t: Dictionary = map.tile(i)
		if t.get("kind", "") != "plot":
			continue
		var col := C_PLOT
		if plots.has(i):
			var oid := int(plots[i]["owner"])
			if players.has(oid):
				col = Color.html(str(players[oid]["color"]))
				var lv := int(plots[i]["level"])
				col = col.lerp(Color.WHITE, 0.13 * lv)
		_tile_mats[i].albedo_color = col

	# 玩家位置（格间插值，体现「连续移动」而非跳格）
	for id in players.keys():
		var p: Dictionary = players[int(id)]
		if not _player_nodes.has(int(id)):
			_create_player(int(id), p)
		var node: Node3D = _player_nodes[int(id)]
		node.visible = bool(p["alive"])
		if not p["alive"]:
			continue
		var a := _pos_at(int(p["tile"]))
		var b := _pos_at(int(p["tile"]) + int(p["dir"]))
		var f: float = clampf(float(p["progress"]), 0.0, 1.0)
		var pos := a.lerp(b, f)
		# 多人同格时错开，避免重叠
		var idx := _stack_index(players, int(p["tile"]), int(id))
		var ang := TAU * float(idx) / 4.0
		node.position = pos + Vector3(cos(ang) * 0.26, 0.80, sin(ang) * 0.26)
		var base_col := Color.html(str(p["color"]))
		var sleep_until := float(p["effects"].get("sleep_until", 0.0))
		if sleep_until > float(snap.get("t", 0.0)):
			base_col = base_col.lerp(Color(0.35, 0.35, 0.4), 0.55)
		var mat: StandardMaterial3D = _player_mats[int(id)]
		mat.albedo_color = base_col


func _stack_index(players: Dictionary, tile: int, self_id: int) -> int:
	var ids := players.keys()
	ids.sort()
	var k := 0
	for id in ids:
		if int(id) == self_id:
			return k
		if int(players[int(id)]["tile"]) == tile:
			k += 1
	return 0


func _create_player(id: int, p: Dictionary) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.html(str(p["color"]))
	mat.emission_enabled = true
	mat.emission = Color.html(str(p["color"])) * 0.35

	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.30
	cap.height = 0.95
	mi.mesh = cap
	mi.material_override = mat
	add_child(mi)

	# 头顶标记：小圆锥，便于远距离辨认朝向与归属
	var marker := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.20
	cone.height = 0.36
	marker.mesh = cone
	marker.material_override = mat
	marker.position = Vector3(0, 0.70, 0)
	mi.add_child(marker)

	var lab := Label3D.new()
	lab.text = str(p["name"])
	lab.font_size = 44
	lab.pixel_size = 0.0060
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.no_depth_test = true
	lab.position = Vector3(0, 0.76, 0)
	mi.add_child(lab)

	_player_nodes[id] = mi
	_player_mats[id] = mat
