extends Node3D
class_name BoardView
## BoardView —— 3D 棋盘表现层（P0.5：对齐原版实机）
##
## 只负责「把权威状态画出来」，不含任何玩法逻辑。
## 设计依据见 docs/original-visual-reference.md 与 docs/screenshots/orig/07_牌桌.png。
##
## 对齐原版的四条：
##   ① 地形 = 一整块【连续平面】，贴原版 ditu.tga 俯视棋盘美术（不切分、不用盒子）
##   ② 地块 = 【地面贴花】（原版 ditan.tga 波斯地毯），沿路径切向摆放，四角带小红块
##   ③ 相机 = 【近距低机位斜视】跟随角色（实测约 3~4 格远 / 俯角 ~36°），不是俯视全盘
##   ④ 角色 = chibi 小人 + 彩色地面圆盘 + 脚下投影
##
## 没有逆向坐标的地图自动退回矩形外圈布局（_fallback_positions）。

# ------------------------------------------------------------------ 常量
const GROUND_Y := 0.0
const DECAL_LIFT := 0.05          # 地毯离地高度，避免与地形 z-fighting
const MARKER_R := 0.95
const CORNER_S := 0.26            # 地毯四角小红块

const C_UNSOLD := Color(0.80, 0.78, 0.79)
const C_START := Color(0.34, 0.88, 0.50)
const C_EVENT := Color(1.00, 0.84, 0.28)

# 建筑（原版 3D 模型，见 building_lib.gd）
const BUILDING_SCALE := 1.08       # 1x1 建筑的模型长边 / 一格地毯
const BUILDING_GAP := 0.18         # 建筑靠棋盘一侧的边缘与地毯边线之间的空隙（单位 = 地毯边长）
const RUG_HALF := 0.5              # 地毯半边 = 0.47 地毯 ≈ 0.5 格距；落点用它做「近边锚点」

# 相机（数值取自原版 aiji.r6m 头部，见 docs/original-visual-reference.md）
#   .r6m: offset 56..67 = 光照方向 (0.353553, 0.866025, 0.353553)
#         offset 72 = 45.0（水平角）  offset 76 = 30.0（俯角）
const CAM_FOV := 60.0
const CAM_PITCH_DEF := 32.0
const CAM_PITCH_MIN := 14.0
const CAM_PITCH_MAX := 68.0
const CAM_YAW_DEF := 45.0
const CAM_DIST_TILES := 3.9       # 距角色的格数（原版 .r6m distance=12 ≈ 3 格）
const CAM_TARGET_LIFT := 0.85

# 原版太阳方向（aiji.r6m @56，已归一化：仰角 60°、方位角 45°）
const SUN_DIR := Vector3(0.353553, 0.866025, 0.353553)

# 地形外围裙边：取 aiji_ground.png 四边平均色，避免看到虚空
const SKIRT_COLOR := Color(0.963, 0.785, 0.536)

var map: MapData = null

# 地形与地块
var _ground: MeshInstance3D = null
var _ground_size := 200.0
var _tile_nodes: Array = []        # MeshInstance3D（地毯贴花），与 tiles 同序
var _tile_mats: Array = []         # StandardMaterial3D
var _tile_pos: Array = []          # Vector3，与 tiles 同序
var _tile_spacing := 4.4
var _level_nodes: Dictionary = {}  # tile:int -> Node3D（房屋）
var _plot_nodes: Dictionary = {}   # tile:int -> Node3D（原版彩色地产槽）
var _plot_border_tex: Texture2D = null

# 角色
var _player_nodes: Dictionary = {}   # id:int -> Node3D
var _player_mats: Dictionary = {}    # id:int -> StandardMaterial3D
var _player_target: Dictionary = {}  # id:int -> Vector3
var _blob_tex: Texture2D = null

# 相机
var _cam_pitch := CAM_PITCH_DEF
var _cam_yaw := CAM_YAW_DEF
var _cam_dist := 17.0
var _cam_target := Vector3.ZERO
var _cam_pos := Vector3.ZERO
var _follow := true
var _my_id := 0

# ==================================================================== 构建

func build(m: MapData) -> void:
	clear()
	if m == null:
		return
	map = m
	_my_id = multiplayer.get_unique_id()

	if m.has_real_layout:
		for i in range(m.tile_count()):
			var p2 := m.pos_of(i)
			_tile_pos.append(Vector3(p2.x, GROUND_Y, p2.y))
		_ground_size = float(m.board_size)
	else:
		_tile_pos = _fallback_positions(m.tile_count())
		var b := _bounds()
		_ground_size = maxf(b.size.x, b.size.y) + _tile_spacing * 3.0

	_tile_spacing = _measure_spacing()
	_build_ground()
	_build_tiles()
	_place_camera()


## 相机初始取景：默认跟人（近距斜视）；无角色时先框住全盘
func _place_camera() -> void:
	var cam := _cam()
	if cam == null:
		return
	var b := _bounds()
	_cam_target = Vector3(b.position.x + b.size.x * 0.5, CAM_TARGET_LIFT,
		b.position.y + b.size.y * 0.5)
	_cam_dist = maxf(_tile_spacing * CAM_DIST_TILES, 6.0)
	_apply_camera(cam)
	cam.fov = CAM_FOV


func _apply_camera(cam: Camera3D) -> void:
	var yaw := deg_to_rad(_cam_yaw)
	var pitch := deg_to_rad(_cam_pitch)
	# yaw=0 → 相机在 +Z 侧，朝 -Z 看（地形贴图的上方）
	var dir := Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw))
	_cam_pos = _cam_target + dir * _cam_dist
	cam.position = _cam_pos
	cam.look_at(_cam_target, Vector3.UP)


# -------------------------------------------------------------- 地形（一整块）

func _build_ground() -> void:
	_ensure_environment()

	var mesh := ArrayMesh.new()
	var h := _ground_size * 0.5
	# Layout positions are transformed from original world coordinates through terrain UV.
	# Export flips the original texture V once; this plane uses top-origin image UV.
	var verts := PackedVector3Array([
		Vector3(-h, GROUND_Y, -h), Vector3(h, GROUND_Y, -h),
		Vector3(h, GROUND_Y, h), Vector3(-h, GROUND_Y, h)])
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)])
	var nrms := PackedVector3Array([
		Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	var idx := PackedInt32Array([0, 3, 2, 0, 2, 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_NORMAL] = nrms
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # 原版地形自带烘焙光影
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var tex: Texture2D = null
	if map.ground_texture != "":
		var res: Resource = load(map.ground_texture)
		if res is Texture2D:
			tex = res
	if tex != null:
		mat.albedo_texture = tex
	else:
		mat.albedo_color = Color(0.78, 0.68, 0.48)            # 沙色兜底

	_ground = MeshInstance3D.new()
	_ground.name = "Ground"
	_ground.mesh = mesh
	_ground.material_override = mat
	add_child(_ground)

	_build_skirt()


## 外围裙边：一块更大的沙色平面垫在地形下方，避免相机贴近边缘时看到虚空
func _build_skirt() -> void:
	var sm := ArrayMesh.new()
	var h := _ground_size * 2.5
	var verts := PackedVector3Array([
		Vector3(-h, GROUND_Y - 0.05, -h), Vector3(h, GROUND_Y - 0.05, -h),
		Vector3(h, GROUND_Y - 0.05, h), Vector3(-h, GROUND_Y - 0.05, h)])
	var uvs := PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var nrms := PackedVector3Array([
		Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	var idx := PackedInt32Array([0, 3, 2, 0, 2, 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_NORMAL] = nrms
	arr[Mesh.ARRAY_INDEX] = idx
	sm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.cull_mode = BaseMaterial3D.CULL_DISABLED
	smat.albedo_color = SKIRT_COLOR

	var node := MeshInstance3D.new()
	node.name = "Skirt"
	node.mesh = sm
	node.material_override = smat
	add_child(node)


## 光源与环境：只用原版 aiji.r6m 里的数值，已有就改写、没有就新建
## （避免像早先那样重复叠光把画面打爆）
func _ensure_environment() -> void:
	var p := get_parent()
	if p == null:
		return
	var light: DirectionalLight3D = null
	var we: WorldEnvironment = null
	for c in p.get_children():
		if c is DirectionalLight3D and light == null:
			light = c
		elif c is WorldEnvironment and we == null:
			we = c
	if light == null:
		light = DirectionalLight3D.new()
		light.name = "BoardSun"
		p.add_child(light)
	light.shadow_enabled = false
	light.light_energy = 1.05
	# 方向取自原版 aiji.r6m @56..67（仰角 60° / 方位角 45°）
	light.look_at_from_position(SUN_DIR * 40.0, Vector3.ZERO, Vector3.UP)

	if we == null:
		we = WorldEnvironment.new()
		we.name = "BoardEnv"
		p.add_child(we)
	var e: Environment = we.environment
	if e == null:
		e = Environment.new()
		we.environment = e
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.10, 0.16, 0.24)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.60, 0.62, 0.66)
	e.ambient_light_energy = 1.0
	# 原版雾色（aiji.r6m @8 = 0.85/0.84/0.70），远处地形自然泛白
	e.fog_enabled = true
	e.fog_light_color = Color(0.85, 0.84, 0.70)
	e.fog_density = 0.0045


# ------------------------------------------------------------------ 地块贴花

func _build_tiles() -> void:
	var rug := _rug_size()
	var tex: Texture2D = null
	if ResourceLoader.exists("res://assets/decals/rug.png"):
		var res: Resource = load("res://assets/decals/rug.png")
		if res is Texture2D:
			tex = res

	var corner_ps := [
		Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]

	for i in range(map.tile_count()):
		var t: Dictionary = map.tile(i)
		var pos: Vector3 = _tile_pos[i]
		var dir := _dir_at(i)
		var ang := atan2(dir.x, dir.y)

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mat.albedo_texture = tex
		var kind: String = t.get("kind", "")
		if kind == "start":
			mat.albedo_color = C_START
		elif kind == "event":
			mat.albedo_color = C_EVENT
		else:
			mat.albedo_color = C_UNSOLD

		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(rug, rug)
		mi.mesh = pm
		mi.material_override = mat
		mi.position = pos + Vector3(0, DECAL_LIFT, 0)
		mi.rotation = Vector3(0, ang, 0)
		mi.name = "Plot%d" % i
		add_child(mi)
		_tile_nodes.append(mi)
		_tile_mats.append(mat)

		# 四角小红块（原版地毯四角的标记）
		if kind != "start":
			var cmat := StandardMaterial3D.new()
			cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			cmat.albedo_color = Color(0.42, 0.10, 0.12)
			for cp in corner_ps:
				var c := MeshInstance3D.new()
				var cb := BoxMesh.new()
				cb.size = Vector3(CORNER_S, CORNER_S * 0.5, CORNER_S)
				c.mesh = cb
				c.material_override = cmat
				var off := Vector2(cp.x, cp.y) * (rug * 0.5 - CORNER_S)
				var w := Vector3(off.x, 0, off.y).rotated(Vector3.UP, ang)
				c.position = pos + w + Vector3(0, DECAL_LIFT + 0.02, 0)
				add_child(c)

		# 起点 / 事件点：额外放一个彩色圆盘，便于远距离辨认
		if kind == "start" or kind == "event":
			var disc := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = MARKER_R
			cyl.bottom_radius = MARKER_R
			cyl.height = 0.12
			disc.mesh = cyl
			var dm := StandardMaterial3D.new()
			dm.albedo_color = C_START if kind == "start" else C_EVENT
			dm.emission_enabled = true
			dm.emission = dm.albedo_color * 0.4
			disc.material_override = dm
			disc.position = pos + Vector3(0, DECAL_LIFT + 0.06, 0)
			add_child(disc)

		# 文字：街道名 / 事件名 / 起点（只标关键格，避免糊成一团）
		var txt := ""
		if kind == "plot" and int(t.get("plot_in_street", -1)) == 0:
			txt = str(t.get("street", ""))
		elif kind == "event":
			txt = str(t.get("name", ""))
		elif kind == "start":
			txt = "起点"
		if txt != "":
			var lab := Label3D.new()
			lab.text = txt
			lab.font_size = 64
			lab.pixel_size = 0.0072
			lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lab.no_depth_test = true
			lab.outline_size = 12
			lab.modulate = Color(1.0, 0.98, 0.9)
			lab.outline_modulate = Color(0.06, 0.06, 0.10, 0.85)
			lab.position = pos + Vector3(0, 1.35, 0)
			add_child(lab)


func _rug_size() -> float:
	if not map.original_layout.is_empty():
		return 3.2 # Original 100-unit cells are about 3.6 board units.
	return clampf(_tile_spacing * 0.94, 0.8, 24.0)


func _measure_spacing() -> float:
	var n := _tile_pos.size()
	if n < 2:
		return 4.4
	var sum := 0.0
	for i in range(n):
		var a: Vector3 = _tile_pos[i]
		var b: Vector3 = _tile_pos[(i + 1) % n]
		sum += a.distance_to(b)
	return maxf(sum / float(n), 0.5)


func _dir_at(i: int) -> Vector2:
	var n := _tile_pos.size()
	if n < 2:
		return Vector2(0, 1)
	var a: Vector3 = _tile_pos[((i - 1) % n + n) % n]
	var b: Vector3 = _tile_pos[((i + 1) % n + n) % n]
	var v := Vector2(b.x - a.x, b.z - a.z)
	if v.length() < 0.0001:
		return Vector2(0, 1)
	return v.normalized()


func _bounds() -> Rect2:
	if _tile_pos.is_empty():
		return Rect2(-20, -20, 40, 40)
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p in _tile_pos:
		mn.x = minf(mn.x, p.x)
		mn.y = minf(mn.y, p.z)
		mx.x = maxf(mx.x, p.x)
		mx.y = maxf(mx.y, p.z)
	return Rect2(mn, mx - mn)


## 没有逆向坐标时退回矩形外圈（保证任何地图都能显示）
func _fallback_positions(n: int) -> Array:
	var out: Array = []
	if n < 4:
		return out
	var total := int((n + 4) / 2.0)
	var cols := clampi(int(round(total * 0.62)), 3, total - 2)
	var rows := total - cols
	var step := 1.0
	for i in range(n):
		var g := Vector2i(0, 0)
		var k := i
		if k < cols:
			g = Vector2i(k, 0)
		else:
			k -= cols
			if k < rows - 1:
				g = Vector2i(cols - 1, 1 + k)
			else:
				k -= rows - 1
				if k < cols - 1:
					g = Vector2i(cols - 2 - k, rows - 1)
				else:
					k -= cols - 1
					g = Vector2i(0, rows - 2 - min(k, rows - 2))
		out.append(Vector3(
			(float(g.x) - float(cols) * 0.5) * 4.0 * step, GROUND_Y,
			(float(g.y) - float(rows) * 0.5) * 4.0 * step))
	return out


func _pos_of(i: int) -> Vector3:
	var n := _tile_pos.size()
	if n == 0:
		return Vector3.ZERO
	var v: Vector3 = _tile_pos[((i % n) + n) % n]
	return v


func _route_pos(tile: int, direction: int, progress: float) -> Vector3:
	if map != null and not map.original_layout.is_empty():
		var point := map.route_position(tile, direction, progress)
		return Vector3(point.x, GROUND_Y, point.y)
	var a := _pos_of(tile)
	var b := _pos_of(tile + direction)
	if map == null or not map.has_real_layout or _tile_pos.size() < 4:
		return a.lerp(b, progress)
	# 原版道路是连续曲线；直线连格点会在弯道内侧抄近路。
	return a.cubic_interpolate(b, _pos_of(tile - direction),
		_pos_of(tile + direction * 2), progress)


# -------------------------------------------------------------------- 相机

func _cam() -> Camera3D:
	if not is_inside_tree():
		return null
	return get_viewport().get_camera_3d()


## 让相机对准某个世界坐标（跟随本地玩家）
func focus_on(p: Vector3) -> void:
	_follow = true
	_cam_target = p + Vector3(0, CAM_TARGET_LIFT, 0)


## 拉远看全盘 / 拉近跟人（Tab 或 HUD 按钮）
func set_overview(on: bool) -> void:
	var cam := _cam()
	if cam == null:
		return
	if on:
		_follow = false
		var b := _bounds()
		_cam_target = Vector3(b.position.x + b.size.x * 0.5, 2.0,
			b.position.y + b.size.y * 0.5)
		var need := maxf(b.size.x, b.size.y) * 0.5
		_cam_pitch = 46.0
		_cam_dist = need / tan(deg_to_rad(CAM_FOV * 0.5)) * 1.05
	else:
		_cam_pitch = CAM_PITCH_DEF
		_cam_dist = maxf(_tile_spacing * CAM_DIST_TILES, 6.0)
	_apply_camera(cam)


func is_overview() -> bool:
	return not _follow


func rotate_camera(deg: float) -> void:
	_cam_yaw = fposmod(_cam_yaw + deg, 360.0)
	var cam := _cam()
	if cam != null:
		_apply_camera(cam)


func tilt_camera(deg: float) -> void:
	_cam_pitch = clampf(_cam_pitch + deg, CAM_PITCH_MIN, CAM_PITCH_MAX)
	var cam := _cam()
	if cam != null:
		_apply_camera(cam)


func zoom_camera(factor: float) -> void:
	_cam_dist = clampf(_cam_dist * factor, 5.0, 900.0)
	var cam := _cam()
	if cam != null:
		_apply_camera(cam)


func _unhandled_input(e: InputEvent) -> void:
	if not visible or map == null:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_Q: rotate_camera(-8.0)
			KEY_E: rotate_camera(8.0)
			KEY_R: tilt_camera(-4.0)
			KEY_F: tilt_camera(4.0)
			KEY_TAB: set_overview(not is_overview())
			KEY_EQUAL: zoom_camera(0.85)
			KEY_MINUS: zoom_camera(1.18)
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_camera(0.88)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_camera(1.14)


func _process(delta: float) -> void:
	if not visible or _player_nodes.is_empty():
		return
	# 快照 10Hz，位置用插值平滑，避免一跳一跳
	var k := clampf(delta * 10.0, 0.0, 1.0)
	for id in _player_nodes.keys():
		var node: Node3D = _player_nodes[id]
		if _player_target.has(id):
			node.position = node.position.lerp(_player_target[id], k)

	if _follow and _player_target.has(_my_id):
		var want: Vector3 = _player_target[_my_id] + Vector3(0, CAM_TARGET_LIFT, 0)
		_cam_target = _cam_target.lerp(want, clampf(delta * 6.0, 0.0, 1.0))
	var cam := _cam()
	if cam != null:
		_apply_camera(cam)


# ==================================================================== 同步

func sync(snap: Dictionary) -> void:
	if map == null:
		return
	var players: Dictionary = snap.get("players", {})
	var plots: Dictionary = snap.get("plots", {})

	# 地毯着色（归属 + 等级）
	for i in range(_tile_mats.size()):
		if i >= map.tile_count():
			break
		var t: Dictionary = map.tile(i)
		var kind: String = t.get("kind", "")
		var mat: StandardMaterial3D = _tile_mats[i]
		if kind == "start":
			mat.albedo_color = C_START
		elif kind == "event":
			mat.albedo_color = C_EVENT
		elif plots.has(i) and players.has(int(plots[i]["owner"])):
			var col := Color.html(str(players[int(plots[i]["owner"])]["color"]))
			var lv := int(plots[i]["level"])
			mat.albedo_color = col.lerp(Color.WHITE, 0.16 * lv)
		else:
			mat.albedo_color = C_UNSOLD

	_sync_plot_platforms(plots, players)
	_sync_buildings(plots)

	# 角色
	for id in players.keys():
		var p: Dictionary = players[int(id)]
		if not _player_nodes.has(int(id)):
			_create_player(int(id), p)
		var node: Node3D = _player_nodes[int(id)]
		node.visible = bool(p["alive"])
		if not bool(p["alive"]):
			continue
		var f: float = clampf(float(p["progress"]), 0.0, 1.0)
		var pos := _route_pos(int(p["tile"]), int(p["dir"]), f)
		# 多人同格时错开，避免完全重叠
		var idx := _stack_index(players, int(p["tile"]), int(id))
		if idx > 0:
			var ang := TAU * float(idx - 1) / 4.0
			pos += Vector3(cos(ang) * 0.34, 0.0, sin(ang) * 0.34)
		_player_target[int(id)] = pos
		if node.position.distance_to(_player_target[int(id)]) > 12.0:
			node.position = _player_target[int(id)]      # 复位（换图/首次出现）

		var base_col := Color.html(str(p["color"]))
		var sleep_until := float(p["effects"].get("sleep_until", 0.0))
		if sleep_until > float(snap.get("t", 0.0)):
			base_col = base_col.lerp(Color(0.40, 0.40, 0.46), 0.5)
		var mat: StandardMaterial3D = _player_mats[int(id)]
		mat.albedo_color = base_col
		mat.emission = base_col * 0.22

		# 骰子精灵：只在移动中显示，展示最近一次掷出的点数
		var dz := node.get_node("Dice") as Sprite3D
		var lr := int(p.get("last_roll", 0))
		if int(p["moving"]) > 0 and lr >= 1 and lr <= 6:
			var dp := "res://assets/dice/%d.png" % lr
			if ResourceLoader.exists(dp):
				var rr: Resource = load(dp)
				if rr is Texture2D:
					dz.texture = rr
					dz.visible = true
		else:
			dz.visible = false

	if _follow and _player_target.has(_my_id):
		pass  # 目标点已在 _process 里插值跟随


## 原版买地后出现彩色框住的平坦地产槽，边缘用 platform/mtlplat2.tga。
## 它在地毯旁边；等级 0 只有地产槽，下次抵达建设后才叠建筑。
func _sync_plot_platforms(plots: Dictionary, players: Dictionary) -> void:
	var known := {}
	for tile_key in plots.keys():
		var tile := int(tile_key)
		if tile < 0 or tile >= _tile_pos.size():
			continue
		var plot: Dictionary = plots[tile]
		var owner := int(plot.get("owner", -1))
		if not players.has(owner):
			continue
		known[tile] = true
		if not _plot_nodes.has(tile):
			_plot_nodes[tile] = _make_plot_platform(tile)
		var node: Node3D = _plot_nodes[tile]
		var sid := BuildingLib.id_for(str(map.name), str(plot.get("type", "")), int(plot["level"]))
		var fp := BuildingLib.footprint(sid) if sid != "" else 1
		if int(node.get_meta("footprint", 0)) != fp:
			_size_plot_platform(node, fp)
		node.position = _building_spot(tile, fp)
		var d := _dir_at(tile)
		node.rotation.y = atan2(d.x, d.y)
		if not map.original_layout.is_empty():
			node.transform = map.plot_transform(tile, fp)
		var color := Color.html(str(players[owner]["color"]))
		var border := (node.get_node("Edge0") as MeshInstance3D).material_override as StandardMaterial3D
		border.albedo_color = color
		border.emission = color * 0.6
		node.visible = true
	for tile in _plot_nodes.keys():
		if not known.has(tile):
			(_plot_nodes[tile] as Node3D).visible = false


func _make_plot_platform(tile: int) -> Node3D:
	var root := Node3D.new()
	root.name = "OwnedPlot%d" % tile
	root.set_meta("footprint", 0)
	var border := StandardMaterial3D.new()
	border.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	border.roughness = 0.9
	border.emission_enabled = true
	if _plot_border_tex == null:
		var path := "res://assets/terrain/aiji_plot_border.png"
		if ResourceLoader.exists(path):
			_plot_border_tex = load(path) as Texture2D
	border.albedo_texture = _plot_border_tex
	for i in range(4):
		var edge := MeshInstance3D.new()
		edge.name = "Edge%d" % i
		edge.material_override = border
		root.add_child(edge)
	var center := MeshInstance3D.new()
	center.name = "Center"
	var center_mat := StandardMaterial3D.new()
	center_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	center_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	center_mat.albedo_color = Color(0.41, 0.29, 0.18, 0.88)
	center.material_override = center_mat
	root.add_child(center)
	add_child(root)
	return root


func _size_plot_platform(node: Node3D, fp: int) -> void:
	node.set_meta("footprint", fp)
	var size := _rug_size() * BUILDING_SCALE * float(fp)
	if not map.original_layout.is_empty():
		size = float(fp)
	var rim := size * 0.07
	for i in range(4):
		var edge := node.get_node("Edge%d" % i) as MeshInstance3D
		var box := BoxMesh.new()
		box.size = Vector3(size, 0.11, rim) if i < 2 else Vector3(rim, 0.11, size - 2.0 * rim)
		edge.mesh = box
		var off := size * 0.5 - rim * 0.5
		edge.position = Vector3(0, 0.07, -off if i == 0 else off) if i < 2 \
			else Vector3(-off if i == 2 else off, 0.07, 0)
	var center := node.get_node("Center") as MeshInstance3D
	var plane := PlaneMesh.new()
	plane.size = Vector2(size - 2.0 * rim, size - 2.0 * rim)
	center.mesh = plane
	center.position.y = 0.055


## 地产上的建筑：直接用原版 3D 模型（building/<id>/model.pol → assets/buildings/<id>.r6m）。
##
## 两条原版规矩（2026-09-26 按老板决策修正）：
##   ① 建筑是**三维模型**，不是贴图精灵；
##   ② 建筑盖在**地块旁边的空地上**，不压在地毯上（原版截图里地毯只是路边的落点标记）。
##
## 选型：直接取 House.txt 的「文件」列（主题 + 等级 → a0101 / b0203 / d201 …），
## 等级 0 = 空地（原版买地后先是一块空地，下一次抵达才开始建设，见 Info.txt id 88/92/93）。
func _sync_buildings(plots: Dictionary) -> void:
	var map_name := str(map.name) if map != null else "aiji"
	var known := {}
	for tile_key in plots.keys():
		var tile := int(tile_key)
		var plot: Dictionary = plots[tile]
		var lv := int(plot["level"])
		if tile >= _tile_pos.size():
			continue
		if lv <= 0:
			continue                       # 只买地未盖房：仅地毯变色，不放房子
		var ptype := str(plot.get("type", ""))
		var sid := BuildingLib.id_for(map_name, ptype, lv)
		if sid == "":
			continue
		known[tile] = true
		if not _level_nodes.has(tile):
			_level_nodes[tile] = _make_building(tile)
		var node: Node3D = _level_nodes[tile]

		if str(node.get_meta("bld_id", "")) != sid:
			_apply_building_model(node, sid)
		node.visible = true

	for tile in _level_nodes.keys():
		if not known.has(tile):
			(_level_nodes[tile] as Node3D).visible = false


## 把某个建筑 id 的网格 + 材质装到节点上，并按**占地**缩放与定位
##
## 关键：R6BM 网格打包时已归一化成「水平长边 = 1.0」，所以缩放倍数
##       直接 = 地毯边长 × BUILDING_SCALE × 占地格数。
##       1x1 公寓 ≈ 一格地毯；2x2 住宅 ≈ 两格；3x3 住宅区 ≈ 三格（对齐原版实机截图）。
func _apply_building_model(node: Node3D, sid: String) -> void:
	node.set_meta("bld_id", sid)
	var fp := BuildingLib.footprint(sid)
	node.set_meta("bld_fp", fp)
	var tile := int(node.get_meta("tile", -1))
	if tile >= 0 and tile < _tile_pos.size():
		node.position = _building_spot(tile, fp)

	var mi := node.get_node_or_null("Model") as MeshInstance3D
	if mi == null:
		return
	mi.mesh = BuildingLib.mesh_for(sid)
	mi.material_override = BuildingLib.material_for(sid)
	var rug := _rug_size()
	var s := rug * BUILDING_SCALE * float(fp)
	if not map.original_layout.is_empty():
		node.transform = map.plot_transform(tile, fp)
		s = float(fp)
	mi.scale = Vector3(s, s, s)


func _make_building(tile: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Bld%d" % tile
	root.set_meta("tile", tile)
	root.position = _building_spot(tile, 1)

	var mi := MeshInstance3D.new()
	mi.name = "Model"
	mi.position.y = 0.12
	root.add_child(mi)

	add_child(root)
	return root


## Original blocks supply plot positions; other maps retain the fallback layout.
func _building_spot(tile: int, fp: int = 1) -> Vector3:
	if not map.original_layout.is_empty():
		return map.plot_transform(tile, fp).origin
	var base: Vector3 = _tile_pos[tile]
	var d := _dir_at(tile)
	var side := Vector2(-d.y, d.x)
	var half := float(maxi(fp, 1)) * BUILDING_SCALE * 0.5
	var dist := (RUG_HALF + BUILDING_GAP + half) * _rug_size()
	var off := side * dist
	# 朝棋盘重心的一侧为「内侧」
	var c := _centroid_xz()
	var to_c := Vector2(c.x - base.x, c.y - base.z)
	if side.dot(to_c) < 0.0:
		off = -off
	return base + Vector3(off.x, GROUND_Y, off.y)


## 棋盘重心（XZ 平面，返回 Vector2(x, z)）
func _centroid_xz() -> Vector2:
	var n := _tile_pos.size()
	if n == 0:
		return Vector2.ZERO
	var s := Vector2.ZERO
	for p in _tile_pos:
		var v: Vector3 = p
		s += Vector2(v.x, v.z)
	return s / float(n)


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


# -------------------------------------------------------------------- 角色

func _create_player(id: int, p: Dictionary) -> void:
	var col := Color.html(str(p["color"]))
	var root := Node3D.new()
	root.name = "P%d" % id
	root.position = _pos_of(int(p["tile"]))
	add_child(root)

	# 脚下投影
	var blob := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(1.7, 1.7)
	blob.mesh = q
	var bmat := StandardMaterial3D.new()
	bmat.albedo_texture = _blob_texture()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bmat.albedo_color = Color(0, 0, 0, 0.55)
	blob.material_override = bmat
	blob.position = Vector3(0, 0.02, 0)
	root.add_child(blob)

	# 地面圆盘（原版角色脚下的彩色圆盘）
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.86
	cyl.bottom_radius = 0.86
	cyl.height = 0.10
	disc.mesh = cyl
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = col
	dmat.emission_enabled = true
	dmat.emission = col * 0.35
	disc.material_override = dmat
	disc.position = Vector3(0, 0.06, 0)
	root.add_child(disc)

	# 身体（chibi：胶囊躯干 + 球头 + 两只手）
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.55
	mat.emission_enabled = true
	mat.emission = col * 0.22

	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.30
	cap.height = 0.86
	body.mesh = cap
	body.material_override = mat
	body.position = Vector3(0, 0.52, 0)
	root.add_child(body)

	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = col.lightened(0.22)
	head_mat.roughness = 0.5
	head_mat.emission_enabled = true
	head_mat.emission = col * 0.30

	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.33
	sph.height = 0.66
	head.mesh = sph
	head.material_override = head_mat
	head.position = Vector3(0, 1.06, 0)
	root.add_child(head)

	for s in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var ac := CapsuleMesh.new()
		ac.radius = 0.11
		ac.height = 0.46
		arm.mesh = ac
		arm.material_override = mat
		arm.position = Vector3(0.35 * s, 0.62, 0.0)
		arm.rotation_degrees = Vector3(0, 0, 30.0 * s)
		root.add_child(arm)

	# 最近一次点数：原版棋盘上那个实体骰子
	var dice := Sprite3D.new()
	dice.name = "Dice"
	dice.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dice.shaded = false
	dice.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	dice.pixel_size = 0.018
	dice.position = Vector3(0, 1.85, 0)
	dice.visible = false
	root.add_child(dice)

	var lab := Label3D.new()
	lab.text = str(p["name"])
	lab.font_size = 56
	lab.pixel_size = 0.0052
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.no_depth_test = true
	lab.outline_size = 12
	lab.modulate = Color(1, 1, 1)
	lab.outline_modulate = Color(0.05, 0.05, 0.08, 0.9)
	lab.position = Vector3(0, 1.50, 0)
	root.add_child(lab)

	_player_nodes[id] = root
	_player_mats[id] = mat
	_player_target[id] = root.position


# -------------------------------------------------------------------- 查询

func player_pos(id: int) -> Variant:
	## 取某玩家在棋盘上的世界坐标（给 3D 音效定位用）；没有则返回 null
	var n: Variant = _player_nodes.get(id, null)
	if n is Node3D and (n as Node3D).is_inside_tree():
		return (n as Node3D).global_position
	return null


func tile_pos_of(idx: int) -> Variant:
	## 取某格的中心世界坐标；没有则返回 null
	if idx >= 0 and idx < _tile_pos.size():
		return _tile_pos[idx]
	return null


func _blob_texture() -> Texture2D:
	if _blob_tex != null:
		return _blob_tex
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.75))
	g.set_color(1, Color(0, 0, 0, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 64
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	_blob_tex = t
	return _blob_tex


# -------------------------------------------------------------------- 清理

func clear() -> void:
	for c in get_children():
		c.queue_free()
	_ground = null
	_tile_nodes.clear()
	_tile_mats.clear()
	_tile_pos.clear()
	_level_nodes.clear()
	_plot_nodes.clear()
	_player_nodes.clear()
	_player_mats.clear()
	_player_target.clear()
	_follow = true
	_cam_pitch = CAM_PITCH_DEF
	_cam_yaw = CAM_YAW_DEF
	map = null
