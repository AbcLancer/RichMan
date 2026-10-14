extends Node3D
class_name BoardView
## BoardView —— 3D 棋盘表现层（P0.5：对齐原版实机）
##
## 只负责「把权威状态画出来」，不含任何玩法逻辑。
## 设计依据见 docs/original-visual-reference.md 与 docs/screenshots/orig/07_牌桌.png。
##
## 对齐原版的四条：
##   ① 地形与环境 = 原版 R6SM 网格、材质与 CVD 动画，统一应用地图坐标变换。
##   ② 地块 = 【地面贴花】（原版 ditan.tga 波斯地毯），沿路径切向摆放，四角带小红块
##   ③ 相机 = 【近距低机位斜视】跟随角色（实测约 3~4 格远 / 俯角 ~36°），不是俯视全盘
##   ④ 角色 = 原版 MD2 网格动画 + 彩色地面圆盘 + 脚下投影
##
## 没有逆向坐标的地图自动退回矩形外圈布局（_fallback_positions）。

# ------------------------------------------------------------------ 常量
const GROUND_Y := 0.0
const DECAL_LIFT := 0.05          # 地毯离地高度，避免与地形 z-fighting
const MARKER_R := 0.95
const CORNER_S := 0.26            # 地毯四角小红块

const C_UNSOLD := Color(0.48, 0.38, 0.22, 0.42)
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
var _plot_anchors: Dictionary = {}
var _plot_nodes: Dictionary = {}   # tile:int -> Node3D（原版彩色地产槽）
var _plot_border_tex: Texture2D = null
var estate_view := false
var _estate_coins: Node3D
var _estate_value_signature := ""

# 角色
var _player_nodes: Dictionary = {}   # id:int -> Node3D
var _player_mats: Dictionary = {}    # id:int -> StandardMaterial3D
var _player_target: Dictionary = {}  # id:int -> Vector3
var _blob_tex: Texture2D = null
var _effects: WorldEffects
var _actor_actions: Dictionary = {}
var _visual_time := 0.0
var _entry_parts: Array = []

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
			_tile_pos.append(Vector3(p2.x, float(m.original_layout.get("tiles", [])[i].get("y", 0.0)), p2.y))
		_ground_size = float(m.board_size)
	else:
		_tile_pos = _fallback_positions(m.tile_count())
		var b := _bounds()
		_ground_size = maxf(b.size.x, b.size.y) + _tile_spacing * 3.0

	_tile_spacing = _measure_spacing()
	_build_ground()
	_build_tiles()
	_build_event_icons()
	_place_camera()
	_effects = WorldEffects.new()
	add_child(_effects)
	_effects.setup(self)


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
	if OriginalMesh.load_scene(self, map.name):
		return

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
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var tex: Texture2D = null
	if map.ground_texture != "":
		var res: Resource = VisualQuality.texture(map.ground_texture)
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
	var fog: Array = map.original_layout.get("fog_color", [0.85, 0.84, 0.70])
	e.fog_enabled = map.name != "space"
	e.fog_light_color = Color(float(fog[0]), float(fog[1]), float(fog[2]))
	e.fog_density = 0.0015
	e.background_color = Color(0.015, 0.02, 0.045) if map.name == "space" else e.fog_light_color


# ------------------------------------------------------------------ 地块贴花

func _build_tiles() -> void:
	var rug := _rug_size()
	var tex: Texture2D = null
	if ResourceLoader.exists("res://assets/decals/rug.png"):
		var res: Resource = VisualQuality.texture("res://assets/decals/rug.png")
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
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		var kind: String = t.get("kind", "")
		var egypt_carpet := map.name == "aiji" and str(t.get("event", "")) == "platform"
		# 地毯是埃及传送点的标志，不是铺满所有路点的通用道路贴图。
		mat.albedo_texture = tex if egypt_carpet else null
		if kind == "start":
			mat.albedo_color = C_START
		elif kind == "event":
			mat.albedo_color = C_EVENT
		else:
			mat.albedo_color = C_UNSOLD

		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2.ONE if kind == "plot" and not map.original_layout.is_empty() else Vector2(rug, rug)
		mi.mesh = pm
		mi.material_override = mat
		if kind == "plot" and not map.original_layout.is_empty():
			mi.transform = map.plot_transform(i)
			mi.position.y += DECAL_LIFT + .01
		else:
			mi.position = pos + Vector3(0, DECAL_LIFT, 0)
			mi.rotation = Vector3(0, ang, 0)
		mi.name = "Plot%d" % i
		add_child(mi)
		mi.visible = kind == "plot" or egypt_carpet
		_tile_nodes.append(mi)
		_tile_mats.append(mat)

		# 四角小红块（原版地毯四角的标记）
		if egypt_carpet:
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

		# 起点：额外放一个彩色圆盘，便于远距离辨认。
		# ⚠ 事件格**不**放圆盘 —— 它有自己的原版图标（由 _build_event_icons 平贴在地毯上），
		#   原先那块黄圆盘（y 更高）会把图标整个盖住。
		if kind == "start":
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



# ------------------------------------- 事件格图标 / 路边物体（原版 roadobj）

## 原版事件格的棋盘图标（`samples/event/*.tga` 19 个 64×64）→ `assets/roadobj/event/`。
## 地图数据里的 key 是 `coupon<N>`，图标文件名按面额写成 `credit<N>`。
const EVENT_ICON_ALIAS := {
	"coupon1": "credit1", "coupon2": "credit2", "coupon3": "credit3",
	"coupon5": "credit5", "coupon10": "credit10", "coupon20": "credit20",
	"coupon30": "credit30", "coupon50": "credit50",
}
## 原版没给图标的事件格：传送平台（`samples/event/` 里没有 platform）
const EVENT_NO_ICON := ["platform"]

const ROAD_ASSET_DIR := "res://assets/roadobj/"
## 路面物体的模型缩放 = 地毯边长 × 这个值
const ROAD_OBJ_SCALE := 0.82

var _road_index: Dictionary = {}      # assets/roadobj/index.json
var _road_cvd_index: Dictionary = {}  # 原版 CVD 动画路面物体
var _event_nodes: Dictionary = {}     # tile:int -> MeshInstance3D
var _obstacle_nodes: Dictionary = {}
var _road_nodes: Dictionary = {}      # tile:int -> Node3D
var _tex_cache: Dictionary = {}       # res 路径 -> Texture2D
var _r6bm_cache: Dictionary = {}      # res 路径 -> ArrayMesh


func _load_road_index() -> Dictionary:
	if not _road_index.is_empty():
		return _road_index
	var p := ROAD_ASSET_DIR + "index.json"
	if FileAccess.file_exists(p):
		var f := FileAccess.open(p, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_road_index = parsed
	return _road_index


func _tex(path: String) -> Texture2D:
	if path == "":
		return null
	if _tex_cache.has(path):
		return _tex_cache[path]
	var res: Resource = VisualQuality.texture(path) if ResourceLoader.exists(path) else null
	var t: Texture2D = res if res is Texture2D else null
	_tex_cache[path] = t
	return t


## 事件格图标：平贴在地毯上、与地毯同朝向（原先事件格只有一块黄圆盘 + 文字）
func _build_event_icons() -> void:
	var idx := _load_road_index()
	var icons: Dictionary = idx.get("event_icons", {})
	if icons.is_empty() or map == null:
		return
	var rug := _rug_size()
	for i in range(mini(map.tile_count(), _tile_pos.size())):
		var t: Dictionary = map.tile(i)
		if str(t.get("kind", "")) != "event":
			continue
		var key: String = str(t.get("event", ""))
		var icon_name: String = str(EVENT_ICON_ALIAS.get(key, key))
		var tex: Texture2D = null
		if not EVENT_NO_ICON.has(key) and icons.has(icon_name):
			tex = _tex(ROAD_ASSET_DIR + str(icons[icon_name]))
		if tex == null:
			if key == "platform" and map.name == "aiji":
				continue              # 埃及传送地毯本身就是事件标志
			# 原版没给这个事件格画图标（例如传送平台）→ 退回原来的黄圆盘
			_event_disc(i)
			continue
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		mat.albedo_texture = tex
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(rug * 0.66, rug * 0.66)
		mi.mesh = pm
		mi.material_override = mat
		var dir := _dir_at(i)
		mi.position = _tile_pos[i] + Vector3(0, DECAL_LIFT + 0.03, 0)
		mi.rotation = Vector3(0, atan2(dir.x, dir.y), 0)
		mi.name = "EvIcon%d" % i
		add_child(mi)
		_event_nodes[i] = mi


## 没有原版图标的事件格 → 退回一块黄圆盘（原来的做法）
func _event_disc(i: int) -> void:
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = MARKER_R
	cyl.bottom_radius = MARKER_R
	cyl.height = 0.12
	disc.mesh = cyl
	var dm := StandardMaterial3D.new()
	dm.albedo_color = C_EVENT
	dm.emission_enabled = true
	dm.emission = dm.albedo_color * 0.4
	disc.material_override = dm
	disc.position = _tile_pos[i] + Vector3(0, DECAL_LIFT + 0.06, 0)
	disc.name = "EvDisc%d" % i
	add_child(disc)
	_event_nodes[i] = disc


## 读 R6BM（建筑与路面物体共用同一格式，见 tools/pol2obj.py / build_road_assets.py）
func _r6bm(path: String) -> ArrayMesh:
	if _r6bm_cache.has(path):
		return _r6bm_cache[path]
	var out: ArrayMesh = null
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f.get_buffer(4) == "R6BM".to_ascii_buffer():
			f.get_32()                                   # 版本
			var nv: int = f.get_32()
			var nt: int = f.get_32()
			for _i in 6:                                 # size(3) + offset(3)
				f.get_float()
			var pos := PackedVector3Array()
			pos.resize(nv)
			for i in nv:
				pos[i] = Vector3(f.get_float(), f.get_float(), f.get_float())
			var uvs := PackedVector2Array()
			uvs.resize(nv)
			for i in nv:
				uvs[i] = Vector2(f.get_float(), f.get_float())
			var tri := PackedInt32Array()
			tri.resize(nt * 3)
			for i in nt * 3:
				tri[i] = f.get_32()
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = pos
			arrays[Mesh.ARRAY_TEX_UV] = uvs
			arrays[Mesh.ARRAY_INDEX] = tri
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out = am
	_r6bm_cache[path] = out
	return out


## 把权威状态里的路边物体画出来。
## 有 `.pol` 静态网格的用真模型；其余（原版只有 `.cvd` 动画、格式未逆）用替代表现：
## 四神直接用宠物大图（准确），别的用发光球 + 名字（清楚、不误导）。
func _sync_road(objs: Dictionary) -> void:
	var known := {}
	for k in objs.keys():
		var ti := int(k)
		if ti < 0 or ti >= _tile_pos.size():
			continue
		var kind := str((objs[k] as Dictionary).get("kind", ""))
		known[ti] = true
		if _road_nodes.has(ti) and str((_road_nodes[ti] as Node3D).get_meta("kind", "")) == kind:
			(_road_nodes[ti] as Node3D).visible = true
			continue
		if _road_nodes.has(ti):
			(_road_nodes[ti] as Node3D).queue_free()
		_road_nodes[ti] = _make_road_node(ti, kind)
	for ti in _road_nodes.keys():
		if not known.has(ti):
			(_road_nodes[ti] as Node3D).visible = false


func _sync_obstacles(obstacles: Array) -> void:
	var known := {}
	for entry in obstacles:
		if not entry is Dictionary: continue
		var tile := int(entry.get("idx", -1))
		if tile < 0 or tile >= _tile_pos.size(): continue
		var kind := str(entry.get("kind", ""))
		known[tile] = true
		if _obstacle_nodes.has(tile) and str((_obstacle_nodes[tile] as Node3D).get_meta("kind", "")) == kind:
			(_obstacle_nodes[tile] as Node3D).visible = true
			continue
		if _obstacle_nodes.has(tile): (_obstacle_nodes[tile] as Node3D).queue_free()
		_obstacle_nodes[tile] = _make_road_node(tile, "block" if kind == "roadblock" else kind)
		(_obstacle_nodes[tile] as Node3D).set_meta("kind", kind)
	for tile in _obstacle_nodes:
		if not known.has(tile): (_obstacle_nodes[tile] as Node3D).visible = false


func _make_road_node(tile: int, kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Road%d" % tile
	root.set_meta("kind", kind)
	root.position = _tile_pos[tile]
	add_child(root)
	var rug := _rug_size()
	if kind == "block" or kind == "mine":
		var road_dir := _dir_at(tile)
		root.rotation.y = atan2(road_dir.x, road_dir.y) + (PI * 0.5 if kind == "block" else 0.0)
	var idx := _load_road_index()
	var items: Dictionary = idx.get("items", {})
	var rec: Dictionary = items.get(kind, {})
	# 解包的原版 CVD 优先：财神、衰神、小偷等都有几何与逐帧动画。
	if _road_cvd_index.is_empty():
		var cvd_index_path := "res://assets/original/road_items/index.json"
		if FileAccess.file_exists(cvd_index_path):
			_road_cvd_index = JSON.parse_string(FileAccess.get_file_as_string(cvd_index_path))
	var parts: Array = _road_cvd_index.get(kind, [])
	if not parts.is_empty():
		for part in parts:
			var actor := OriginalMesh.new()
			actor.name = "OriginalRoadItem" if root.get_child_count() == 0 else "OriginalRoadPart%d" % root.get_child_count()
			root.add_child(actor)
			actor.setup(part)
			actor.position.y = DECAL_LIFT + rug * .24
			actor.scale = Vector3.ONE * minf(rug * .27, .75)
		return root

	# ⚠ index.json 里没有模型的项是 JSON `null`，`str(null)` 会得到 "<null>" → 显式判类型
	var mv: Variant = rec.get("model", null)
	var model: String = mv if mv is String else ""
	if model != "":
		var mesh := _r6bm(ROAD_ASSET_DIR + model)
		if mesh != null:
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			var mat := StandardMaterial3D.new()
			var tex := _tex(ROAD_ASSET_DIR + str(rec.get("model_tex", "")))
			if tex != null:
				mat.albedo_texture = tex
			mat.roughness = 0.9
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mi.material_override = mat
			var s := rug * (1.05 if kind == "mine" else ROAD_OBJ_SCALE)
			mi.scale = Vector3(s, s, s)
			mi.position = Vector3(0, DECAL_LIFT + (0.17 if kind == "mine" else 0.04), 0)
			root.add_child(mi)
			if kind == "mine" and tex != null:
				# 原版地雷很扁；保留模型，再加贴地的原版六角纹样防止被路面遮住。
				var mine_top := MeshInstance3D.new()
				var plane := PlaneMesh.new()
				plane.size = Vector2.ONE * rug * 0.62
				mine_top.mesh = plane
				var top_mat := StandardMaterial3D.new()
				top_mat.albedo_texture = tex
				top_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				top_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				top_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				mine_top.material_override = top_mat
				mine_top.position.y = DECAL_LIFT + 0.20
				root.add_child(mine_top)
			if kind == "block" and tex != null:
				# POL 的侧面会露出贴图集中的青色区域；立一块裁出的 STOP 正面。
				var sign_image := tex.get_image().get_region(Rect2i(0, 0, 128, 96))
				var sign_tex := ImageTexture.create_from_image(sign_image)
				for side in 2:
					var sign := MeshInstance3D.new()
					var face := QuadMesh.new()
					face.size = Vector2(rug * 0.78, rug * 0.58)
					sign.mesh = face
					var sign_mat := StandardMaterial3D.new()
					sign_mat.albedo_texture = sign_tex
					sign_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					sign_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					sign_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
					sign.material_override = sign_mat
					sign.position = Vector3(0, DECAL_LIFT + rug * 0.51, (0.08 if side == 0 else -0.08) * rug)
					sign.rotation.y = PI * side
					root.add_child(sign)
			return root

	# ---- 替代表现 ----
	var cn := str(rec.get("cn", kind))
	if kind in ["caishen", "fushen", "qiongshen", "shuaishen"]:
		var ptex := _tex("res://assets/pets/%s/70.png" % kind)
		if ptex != null:
			var sp := Sprite3D.new()
			sp.texture = ptex
			sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sp.pixel_size = rug * 0.55 / 128.0
			sp.position = Vector3(0, rug * 0.30, 0)
			root.add_child(sp)
			return root

	var col := _road_color(kind)
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = rug * 0.20
	sm.height = rug * 0.40
	ball.mesh = sm
	var dm := StandardMaterial3D.new()
	dm.albedo_color = col
	dm.emission_enabled = true
	dm.emission = col * 0.45
	ball.material_override = dm
	ball.position = Vector3(0, DECAL_LIFT + rug * 0.20, 0)
	root.add_child(ball)

	return root


func _road_color(kind: String) -> Color:
	match kind:
		"card":
			return Color(0.95, 0.42, 0.78)
		"crystal":
			return Color(0.62, 0.86, 1.00)
		"hanbao":
			return Color(0.95, 0.70, 0.30)
		"petegg":
			return Color(1.00, 0.88, 0.52)
		"robber":
			return Color(0.80, 0.60, 0.25)
		"bomb":
			return Color(0.35, 0.35, 0.40)
		"thief":
			return Color(0.28, 0.30, 0.42)
		"dianjuan":
			return Color(0.55, 0.90, 0.55)
		"san":
			return Color(0.90, 0.90, 0.95)
	return Color(0.85, 0.85, 0.85)


func _rug_size() -> float:
	if not map.original_layout.is_empty():
		return float(map.original_layout.get("world_scale", 0.036)) * 90.0
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


## 找屏幕上离 `screen` 最近的一格 —— 给「请选择一格」的卡用（地雷卡 / 路障卡 / 拆迁卡 …）。
##
## 做法：**把每一格投影到屏幕再比距离**。94 格 × 每帧一次完全够快，
## 比「从相机打射线求交」简单得多，也不用管网格缩放。
## `max_dist` = 命中半径（像素），超出就返回 -1（表示点空了）。
func nearest_card_tile_to_screen(screen: Vector2, candidates: Array, include_plots: bool) -> int:
	var cam := _cam()
	if cam == null: return -1
	var best := -1
	var best_d := 70.0
	for index in candidates:
		var points := [_pos_of(int(index))]
		if include_plots and str(map.tile(int(index)).get("kind", "")) == "plot":
			points.append(_building_spot(int(index)))
			if _plot_nodes.has(int(index)): points.append((_plot_nodes[int(index)] as Node3D).position)
		for point in points:
			if cam.is_position_behind(point): continue
			var distance := cam.unproject_position(point).distance_to(screen)
			if distance < best_d:
				best_d = distance
				best = int(index)
	return best

func nearest_tile_to_screen(screen: Vector2, max_dist: float = 70.0) -> int:
	var cam := _cam()
	if cam == null or map == null:
		return -1
	var best := -1
	var best_d := max_dist
	for i in range(map.tile_count()):
		var wp := _pos_of(i)
		if cam.is_position_behind(wp):       # 在相机背后 → 跳过（否则会得到镜像坐标）
			continue
		var d := cam.unproject_position(wp).distance_to(screen)
		if d < best_d:
			best_d = d
			best = i
	return best


## 「请选择对手」的目标高亮 —— **原版做法**（老板 2026-09-27 的实机截图）：
##   · **候选**角色脚下的彩色圆盘 → 亮**绿色**
##   · 鼠标**悬停**到的那一个 → **红色**
##   · 太远（超出 `Sim.CARD_TARGET_MAX_TILES` 格）的不亮 → **目标选择是有距离限制的**
##
## 传空数组 = 退出选目标模式，圆盘恢复本人颜色。
var _target_cands: Array = []
var _target_hover := -1


func set_card_targets(cands: Array, hover: int) -> void:
	_target_cands = cands
	_target_hover = hover
	for pid in _player_nodes:
		_paint_disc(_player_nodes[pid], _player_mats[pid].albedo_color if cands.has(pid) else Color.html(str(_player_nodes[pid].get_meta("owner_color", "ffffff"))), int(pid))


## 给某个玩家的脚下圆盘染色（绿 = 可选 / 红 = 当前指到 / 暗 = 不可选）
func _paint_disc(node: Node3D, col: Color, pid: int) -> void:
	var dn := node.get_node_or_null("PColorDisc") as MeshInstance3D
	if dn == null:
		return
	var m: StandardMaterial3D = dn.material_override as StandardMaterial3D
	if m == null:
		return
	dn.visible = _target_cands.has(pid) and float(node.get_meta("entry_until", 0.0)) <= _visual_time
	var want := col
	if not _target_cands.is_empty():
		if _target_hover == pid and _target_cands.has(pid):
			want = Color8(255, 74, 74)
		elif _target_cands.has(pid):
			want = Color8(96, 240, 120)
		else:
			want = col.darkened(0.62)
	m.albedo_color = want
	m.emission = want * 0.45


## 每个玩家在**屏幕**上的位置（「鼠标指到了谁」用这个判，跟棋盘选格子同一套思路）
func player_screen_positions() -> Dictionary:
	var out: Dictionary = {}
	var cam := _cam()
	if cam == null:
		return out
	for id in _player_nodes.keys():
		var node: Node3D = _player_nodes[id]
		if not node.visible:
			continue
		var wp: Vector3 = node.position + Vector3(0, 1.1, 0)   # 抬到身体中部，好点
		if cam.is_position_behind(wp):
			continue
		out[int(id)] = cam.unproject_position(wp)
	return out


func _pos_of(i: int) -> Vector3:
	var n := _tile_pos.size()
	if n == 0:
		return Vector3.ZERO
	var v: Vector3 = _tile_pos[((i % n) + n) % n]
	return v


func _route_pos(tile: int, direction: int, progress: float) -> Vector3:
	if map != null and not map.original_layout.is_empty():
		return map.route_position_3d(tile, direction, progress)
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
		_follow = true
		if _player_target.has(_my_id):
			_cam_target = _player_target[_my_id] + Vector3(0, CAM_TARGET_LIFT, 0)
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


func drag_rotate(relative: Vector2) -> void:
	_cam_yaw = fposmod(_cam_yaw - relative.x * 0.32, 360.0)
	_cam_pitch = clampf(_cam_pitch + relative.y * 0.20, CAM_PITCH_MIN, CAM_PITCH_MAX)
	var cam := _cam()
	if cam != null: _apply_camera(cam)


func reset_follow_camera() -> void:
	_cam_yaw = CAM_YAW_DEF
	set_overview(false)


func resume_follow() -> void:
	# Movement resumes tracking only. The user's orbit, tilt and zoom stay intact.
	_follow = true
	if _player_target.has(_my_id):
		_cam_target = _player_target[_my_id] + Vector3(0, CAM_TARGET_LIFT, 0)


func drag_pan(relative: Vector2) -> void:
	var cam := _cam()
	if cam == null: return
	_follow = false
	var center := get_viewport().get_visible_rect().size * 0.5
	var plane := Plane(Vector3.UP, _cam_target.y)
	var before: Variant = plane.intersects_ray(cam.project_ray_origin(center), cam.project_ray_normal(center))
	var after: Variant = plane.intersects_ray(cam.project_ray_origin(center + relative), cam.project_ray_normal(center + relative))
	if before != null and after != null: _cam_target += before - after
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
	if not Net.game_paused: _visual_time += delta
	# 快照 10Hz，位置用插值平滑，避免一跳一跳
	var k := clampf(delta * 10.0, 0.0, 1.0)
	for id in _player_nodes.keys():
		var node: Node3D = _player_nodes[id]
		if _player_target.has(id):
			var target: Vector3 = _player_target[id]
			var remaining := float(node.get_meta("entry_until", 0.0)) - _visual_time
			if remaining > 0.0:
				var phase := clampf(remaining / Sim.ENTRY_SECONDS, 0.0, 1.0)
				node.position = target + Vector3(sin(_visual_time * 3.0 + int(id)) * .25 * phase, 13.0 * phase, 0)
			else: node.position = node.position.lerp(target, k)
			var parachute := node.get_node_or_null("Parachute") as Node3D
			if parachute != null:
				parachute.visible = remaining > 0.0
				parachute.rotation.z = sin(_visual_time * 2.5 + int(id)) * .07
			var disc := node.get_node_or_null("PColorDisc") as Node3D
			if disc != null: disc.visible = remaining <= 0.0 and _target_cands.has(id)
		var actor := node.get_node_or_null("OriginalActor") as OriginalMesh
		if actor != null:
			actor.rotation.y = lerp_angle(actor.rotation.y, float(node.get_meta("heading", actor.rotation.y)), 1 - exp(-delta * 12))
			if _actor_actions.has(id):
				_actor_actions[id].remaining -= delta
				if float(_actor_actions[id].remaining) <= 0:
					_actor_actions.erase(id)
					actor.play(str(node.get_meta("base_clip", "stan")))

	if _follow and _player_target.has(_my_id):
		var want: Vector3 = _player_target[_my_id] + Vector3(0, CAM_TARGET_LIFT, 0)
		var followed: Node3D = _player_nodes[_my_id]
		var phase := clampf((float(followed.get_meta("entry_until", 0.0)) - _visual_time) / Sim.ENTRY_SECONDS, 0.0, 1.0)
		want.y += 13.0 * phase + (2.0 if phase > 0.0 else 0.0)
		_cam_target = _cam_target.lerp(want, clampf(delta * 6.0, 0.0, 1.0))
	var cam := _cam()
	if cam != null:
		_apply_camera(cam)


# ==================================================================== 同步

func sync(snap: Dictionary) -> void:
	if map == null:
		return
	_visual_time = float(snap.get("t", 0.0))
	var players: Dictionary = snap.get("players", {})
	var plots: Dictionary = snap.get("plots", {})
	for id in _player_nodes.keys():
		if not players.has(id):
			(_player_nodes[id] as Node3D).queue_free()
			_player_nodes.erase(id)
			_player_target.erase(id)
			_player_mats.erase(id)
			_actor_actions.erase(id)

	# 地毯着色（归属 + 等级）
	for i in range(_tile_mats.size()):
		if i >= map.tile_count():
			break
		var t: Dictionary = map.tile(i)
		var kind: String = t.get("kind", "")
		(_tile_nodes[i] as MeshInstance3D).visible = (kind == "plot" and not plots.has(i)) \
			or (map.name == "aiji" and str(t.get("event", "")) == "platform")
		var mat: StandardMaterial3D = _tile_mats[i]
		if kind == "start":
			mat.albedo_color = C_START
		elif kind == "event":
			mat.albedo_color = C_EVENT
		elif plots.has(i) and players.has(int(plots[i]["owner"])):
			var owner_info: Dictionary = players[int(plots[i]["owner"])]
			var col := Color(0.025, 0.025, 0.03) if Sim.owner_abnormal(owner_info, _visual_time) \
				else Color.html(str(owner_info["color"]))
			var lv := int(plots[i]["level"])
			mat.albedo_color = col.lerp(Color.WHITE, 0.16 * lv)
		else:
			mat.albedo_color = C_UNSOLD

	_sync_plot_platforms(plots, players, snap.get("street_seal", {}) as Dictionary)
	_sync_buildings(plots)
	if estate_view: _sync_estate_coins()
	_sync_road(snap.get("road_objs", {}))
	_sync_obstacles(snap.get("obstacles", []))

	# 角色
	for id in players.keys():
		var p: Dictionary = players[int(id)]
		if not _player_nodes.has(int(id)):
			_create_player(int(id), p)
		var node: Node3D = _player_nodes[int(id)]
		node.set_meta("entry_until", float(p.get("entry_until", 0.0)))
		node.visible = bool(p["alive"]) and maxf(float(p["effects"].get("hospital_until", 0.0)),
			float(p["effects"].get("hotel_until", 0.0))) <= float(snap.get("t", 0.0))
		if not bool(p["alive"]):
			continue
		# 「请选择对手」时把脚下圆盘染色（绿 = 可选 / 红 = 指到 / 暗 = 太远或自己）
		node.set_meta("owner_color", p["color"])
		_paint_disc(node, Color.html(str(p["color"])), int(id))
		var f: float = clampf(float(p["progress"]), 0.0, 1.0)
		var pos := _route_pos(int(p["tile"]), int(p["dir"]), f)
		# 多人同格时错开，避免完全重叠
		var idx := _stack_index(players, int(p["tile"]), int(id))
		if idx > 0:
			var ang := TAU * float(idx - 1) / 4.0
			pos += Vector3(cos(ang) * 0.34, 0.0, sin(ang) * 0.34)
		_player_target[int(id)] = pos
		if int(id) == _my_id and int(p.get("moving", 0)) > 0 and float(snap.get("t", 0.0)) >= float(p.get("move_after", 0.0)):
			resume_follow()
		# 原版平时不挂姓名/现金；只有神仙附身才显示头像与绿色剩余步数。
		var tag := node.get_node_or_null("Tag") as Label3D
		if tag != null: tag.visible = false
		var god_icon := node.get_node_or_null("GodIcon") as Sprite3D
		var god_steps := node.get_node_or_null("GodSteps") as Label3D
		if god_icon != null and god_steps != null:
			var status: Dictionary = p["effects"]
			var god := ""
			var steps := 0
			for pair in [["sleepwalk_steps", "梦游"], ["free_upgrade_steps", "福神"], ["no_upgrade_steps", "衰神"],
				["rent_double_steps", "穷神"], ["no_rent_steps", "财神"]]:
				if int(status.get(pair[0], 0)) > 0:
					god = str(pair[1])
					steps = int(status[pair[0]])
					break
			god_icon.visible = steps > 0
			god_steps.visible = steps > 0
			if steps > 0:
				if str(god_icon.get_meta("god", "")) != god:
					god_icon.texture = _tex(Rules.pet_art("hutu", "mini", 1) if god == "梦游"
						else "res://assets/uitex/effect/%s.png" % god)
					god_icon.set_meta("god", god)
				god_steps.text = str(steps)
			var invisible_left := float(status.get("invisible_until", 0.0)) - float(snap.get("t", 0.0))
			if invisible_left > 0:
				god_icon.visible = false
				god_steps.visible = true
				god_steps.text = str(ceili(invisible_left))
		if node.position.distance_to(_player_target[int(id)]) > 12.0:
			node.position = _player_target[int(id)]      # 复位（换图/首次出现）

		var base_col := Color.html(str(p["color"]))
		var sleep_until := maxf(float(p["effects"].get("rest_until", 0.0)),
			maxf(float(p["effects"].get("sleep_until", 0.0)), float(p["effects"].get("hospital_until", 0.0))))
		if sleep_until > float(snap.get("t", 0.0)):
			base_col = base_col.lerp(Color(0.40, 0.40, 0.46), 0.5)
		var mat: StandardMaterial3D = _player_mats[int(id)]
		mat.albedo_color = base_col
		mat.emission = base_col * 0.22
		_paint_disc(node, base_col, int(id))

		var actor := node.get_node_or_null("OriginalActor") as OriginalMesh
		if actor != null:
			actor.set_opacity(0.45 if float(p["effects"].get("invisible_until", 0.0)) > float(snap.get("t", 0.0)) else 1.0)
			var clip := "slee" if sleep_until > float(snap.get("t", 0.0)) else ("run" if int(p["moving"]) > 0 and float(snap.get("t", 0.0)) >= float(p.get("move_after", 0.0)) else "stan")
			node.set_meta("base_clip", clip)
			if not _actor_actions.has(int(id)) or clip == "slee":
				if clip == "slee": _actor_actions.erase(int(id))
				actor.play(clip)
			actor.motion_speed = clampf(float(p.get("speed", 2.0)) / 2.0, .65, 2.5) if clip == "run" and not _actor_actions.has(int(id)) else 1.0
			var ahead := _route_pos(int(p["tile"]), int(p["dir"]), minf(f + 0.01, 1.0)) - _route_pos(int(p["tile"]), int(p["dir"]), f)
			if ahead.length_squared() > 0.00001:
				node.set_meta("heading", atan2(ahead.x, ahead.z))


	if _effects != null: _effects.sync(snap)
	if _follow and _player_target.has(_my_id):
		var followed: Node3D = _player_nodes[_my_id]
		if float(followed.get_meta("entry_until", 0.0)) > _visual_time:
			_cam_target = _player_target[_my_id] + Vector3(0, CAM_TARGET_LIFT + 13.0 * clampf((float(followed.get_meta("entry_until")) - _visual_time) / Sim.ENTRY_SECONDS, 0, 1) + 2.0, 0)

func on_game_event(kind: String, data: Dictionary) -> void:
	if is_instance_valid(_effects): _effects.on_event(kind, data)
	var pid := int(data.get("pid", -1))
	match kind:
		"roll":
			_actor_actions.erase(pid)
			var player := _player_nodes.get(pid) as Node3D
			if player != null:
				var actor := player.get_node_or_null("OriginalActor") as OriginalMesh
				if actor != null: actor.play("stan")
		"pay_rent":
			react(pid, "sad")
			react(int(data.get("to", -1)), "glad")
		"buy", "upgrade", "rebuild", "win_money", "get_pet", "pet_levelup", "credit", "news", "road_chest": react(pid, "glad")
		"lotto_draw":
			if pid == int(data.get("winner", -1)): react(pid, "glad")
		"casino_result": react(pid, "glad" if int(data.get("win", 0)) > 0 else "sad")
		"road_god": react(pid, "sad" if str(data.get("god", "")) == "qiongshen" else "glad")
		"mine", "road_bomb", "pet_attacked", "lose_money", "road_thief", "card_damage": react(pid, "sad")
		"pet_skill": react(pid, "stpa", .8)

func react(pid: int, clip: String, duration := 1.0) -> void:
	var player := _player_nodes.get(pid) as Node3D
	if player == null or not player.visible or str(player.get_meta("base_clip", "")) == "slee": return
	var actor := player.get_node_or_null("OriginalActor") as OriginalMesh
	if actor == null or not actor._clips.has(clip): return
	_actor_actions[pid] = {"remaining": minf(duration, actor.animation_duration(clip))}
	actor.motion_speed = 1.0
	actor.play(clip, false, .12)


## 原版买地后出现彩色框住的平坦地产槽，边缘用 platform/mtlplat2.tga。
## 它在地毯旁边；等级 0 只有地产槽，下次抵达建设后才叠建筑。
func _sync_plot_platforms(plots: Dictionary, players: Dictionary, seals: Dictionary) -> void:
	var known := {}
	for tile_key in plots.keys():
		var tile := int(tile_key)
		if tile < 0 or tile >= _tile_pos.size():
			continue
		var plot: Dictionary = plots[tile]
		if int(plot.get("anchor", tile)) != tile:
			continue
		var owner := int(plot.get("owner", -1))
		if not players.has(owner):
			continue
		known[tile] = true
		if not _plot_nodes.has(tile):
			_plot_nodes[tile] = _make_plot_platform(tile)
		var node: Node3D = _plot_nodes[tile]
		var sid := BuildingLib.id_for(str(map.name), str(plot.get("type", "")), int(plot["level"]))
		var fp := int(plot.get("footprint", BuildingLib.footprint(sid) if sid != "" else 1))
		if int(node.get_meta("footprint", 0)) != fp:
			_size_plot_platform(node, fp)
		node.position = _building_spot(tile, fp)
		var d := _dir_at(tile)
		node.rotation.y = atan2(d.x, d.y)
		if not map.original_layout.is_empty():
			node.transform = map.plot_transform(tile, fp, int(plot.get("build_cell", -1)))
		var sealed := float(seals.get(map.street_of(tile), 0.0)) > _visual_time
		var color := Color(0.025, 0.025, 0.03) if sealed or Sim.owner_abnormal(players[owner], _visual_time) \
			else Color.html(str(players[owner]["color"]))
		var border := (node.get_node("Edge0") as MeshInstance3D).material_override as StandardMaterial3D
		border.albedo_color = color
		border.emission = color * 0.6
		_sync_owner_marker(node, players[owner], int(plot["level"]) == 0)
		node.visible = true
	for tile in _plot_nodes.keys():
		if not known.has(tile):
			(_plot_nodes[tile] as Node3D).visible = false


func _make_plot_platform(tile: int) -> Node3D:
	var root := Node3D.new()
	root.name = "OwnedPlot%d" % tile
	root.set_meta("footprint", 0)
	var border := StandardMaterial3D.new()
	border.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	border.roughness = 0.9
	border.emission_enabled = true
	if _plot_border_tex == null:
		var path := "res://assets/terrain/aiji_plot_border.png"
		if ResourceLoader.exists(path):
			_plot_border_tex = VisualQuality.texture(path) as Texture2D
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
	_plot_anchors.clear()
	for key in plots: _plot_anchors[int(key)] = int(plots[key].get("anchor", int(key)))
	var map_name := str(map.name) if map != null else "aiji"
	var known := {}
	for tile_key in plots.keys():
		var tile := int(tile_key)
		var plot: Dictionary = plots[tile]
		if int(plot.get("anchor", tile)) != tile:
			continue
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
		if not map.original_layout.is_empty():
			node.transform = map.plot_transform(tile, int(plot.get("footprint", BuildingLib.footprint(sid))), int(plot.get("build_cell", -1)))
		node.visible = not estate_view

	for tile in _level_nodes.keys():
		if not known.has(tile):
			(_level_nodes[tile] as Node3D).visible = false

func set_estate_view(enabled: bool) -> void:
	estate_view = enabled
	_estate_value_signature = ""
	if is_instance_valid(_estate_coins):
		_estate_coins.hide()
		_estate_coins.queue_free()
		_estate_coins = null
	if Net.sim == null: return
	_sync_buildings(Net.sim.plots)
	# Keep ownership platforms visible; only the buildings and owner flags change.
	for key in _plot_nodes:
		var platform: Node3D = _plot_nodes[key]
		var marker := (platform as Node3D).get_node_or_null("OwnerMarker") as Node3D
		if marker != null: marker.visible = not enabled and Net.sim.plots.has(key) and int(Net.sim.plots[key].level) == 0
	if enabled: _sync_estate_coins()

func _sync_estate_coins() -> void:
	if Net.sim == null: return
	var values := {}
	for key in Net.sim.unique_plot_keys():
		var value := Net.sim.estate_asset_value(int(key))
		values[int(key)] = value
	var signature := str(values)
	if signature == _estate_value_signature: return
	_estate_value_signature = signature
	if is_instance_valid(_estate_coins):
		_estate_coins.hide()
		_estate_coins.queue_free()
	_estate_coins = Node3D.new()
	_estate_coins.name = "EstateValueCoins"
	add_child(_estate_coins)
	var coin := CylinderMesh.new()
	coin.top_radius = .34
	coin.bottom_radius = .34
	coin.height = .065
	coin.radial_segments = 24
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color8(255, 207, 25)
	gold.metallic = .35
	gold.roughness = .42
	var face := StandardMaterial3D.new()
	face.albedo_texture = _tex("res://assets/roadobj/tex/gold/金币.png")
	face.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	face.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for key in values:
		var plot: Dictionary = Net.sim.plots[key]
		var root := Node3D.new()
		root.name = "EstateCoins%d" % int(key)
		_estate_coins.add_child(root)
		root.transform = map.plot_transform(int(key), int(plot.get("footprint", 1)), int(plot.get("build_cell", -1)))
		# An inexpensive lone estate must not become the tallest stack merely
		# because it is the only owned lot. Use the same monetary scale everywhere.
		var count := maxi(1, int(ceil(sqrt(float(values[key]) / maxf(1.0, Net.sim.empty_plot_price())))))
		root.set_meta("value", values[key])
		root.set_meta("coin_count", count)
		for level in range(count):
			var mesh := MeshInstance3D.new()
			mesh.mesh = coin
			mesh.material_override = gold
			mesh.position.y = .13 + level * .085
			root.add_child(mesh)
		var top := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(.68, .68)
		top.mesh = plane
		top.material_override = face
		top.position.y = .166 + (count - 1) * .085
		root.add_child(top)
		var label := Label3D.new()
		label.text = str(values[key])
		label.font_size = 32
		label.pixel_size = .003
		label.modulate = Color.BLACK
		label.outline_modulate = Color8(255, 233, 130)
		label.outline_size = 2
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position.y = top.position.y + .25
		root.add_child(label)


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
	mi.set_meta("rent_flash_generation", int(mi.get_meta("rent_flash_generation", 0)) + 1)
	mi.set_meta("rent_flash_base", mi.material_override)
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

	# 世界名牌（名字 + 现金）—— 原版每个玩家头顶都有，用本人颜色描边
	var tag := Label3D.new()
	tag.name = "Tag"
	tag.font_size = 44
	tag.pixel_size = 0.0055
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.outline_size = 10
	tag.modulate = Color(1.0, 0.99, 0.94)
	tag.outline_modulate = col.darkened(0.45)
	tag.position = Vector3(0, 4.3, 0)
	root.add_child(tag)
	var god_icon := Sprite3D.new()
	god_icon.name = "GodIcon"
	god_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	god_icon.pixel_size = 0.0048
	god_icon.no_depth_test = true
	god_icon.position = Vector3(0, 4.65, 0)
	god_icon.visible = false
	root.add_child(god_icon)
	var god_steps := Label3D.new()
	god_steps.name = "GodSteps"
	god_steps.font_size = 65
	god_steps.pixel_size = 0.007
	god_steps.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	god_steps.no_depth_test = true
	god_steps.outline_size = 8
	god_steps.modulate = Color(0.29, 1.0, 0.15)
	god_steps.outline_modulate = Color(0.08, 0.31, 0.02)
	god_steps.position = Vector3(0, 5.15, 0)
	god_steps.visible = false
	root.add_child(god_steps)

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
	disc.name = "PColorDisc"
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = col
	dmat.emission_enabled = true
	dmat.emission = col * 0.35
	disc.material_override = dmat
	disc.position = Vector3(0, 0.06, 0)
	root.add_child(disc)
	disc.visible = false

	var actor := OriginalMesh.new()
	actor.name = "OriginalActor"
	actor.scale = Vector3.ONE * float(map.original_layout.get("world_scale", 0.036)) / 0.036
	root.add_child(actor)
	var actor_path := "res://assets/original/actors/role%d.json" % int(p.get("role", 1))
	if FileAccess.file_exists(actor_path):
		actor.setup(JSON.parse_string(FileAccess.get_file_as_string(actor_path)))
		actor.play("stan")

	# Original san.cvd canopy and suspension ropes, only during entry.
	if _entry_parts.is_empty():
		var entry_path := "res://assets/original/entry/index.json"
		if FileAccess.file_exists(entry_path): _entry_parts = JSON.parse_string(FileAccess.get_file_as_string(entry_path)).get("parts", [])
	var parachute := Node3D.new()
	parachute.name = "Parachute"
	parachute.position.y = 4.0
	parachute.scale = actor.scale
	parachute.visible = false
	root.add_child(parachute)
	for part in _entry_parts:
		var mesh := OriginalMesh.new()
		parachute.add_child(mesh)
		mesh.setup(part)
		var pivot: Array = part.get("pivot", [0, 0, 0])
		mesh.position = Vector3(pivot[0], pivot[1], pivot[2])

	_player_nodes[id] = root
	_player_mats[id] = dmat
	_player_target[id] = root.position


# -------------------------------------------------------------------- 查询

func player_pos(id: int) -> Variant:
	## 取某玩家在棋盘上的世界坐标（给 3D 音效定位用）；没有则返回 null
	var n: Variant = _player_nodes.get(id, null)
	if n is Node3D and (n as Node3D).is_inside_tree():
		return (n as Node3D).global_position
	return null


func plot_pos_of(idx: int) -> Variant:
	# Rent belongs to the estate anchor, including merged three-cell buildings.
	var anchor := int(_plot_anchors.get(idx, idx))
	var node: Variant = _level_nodes.get(anchor, _plot_nodes.get(anchor))
	if node is Node3D and node.is_inside_tree() and node.visible: return node.global_position
	if anchor >= 0 and anchor < _tile_pos.size(): return _building_spot(anchor)
	return null


func flash_joint_rent(members: Array) -> void:
	# 425ab3 case0x3f4 -> 443310(...,4). 442c7f alternates the red
	# emissive material at int(t*3)&1; 442d00 clears the flag after 2s.
	var seen := {}
	for member in members:
		var anchor := int(_plot_anchors.get(int(member), int(member)))
		if seen.has(anchor): continue
		seen[anchor] = true
		var building: Node3D = _level_nodes.get(anchor)
		if not is_instance_valid(building) or not building.visible: continue
		var model := building.get_node_or_null("Model") as MeshInstance3D
		if model == null or not model.material_override is StandardMaterial3D: continue
		var base: Material = model.get_meta("rent_flash_base", model.material_override)
		var red := base.duplicate() as StandardMaterial3D
		red.albedo_color = Color(1, 0, 0)
		red.emission_enabled = true
		red.emission = Color(1, 0, 0)
		var generation := int(model.get_meta("rent_flash_generation", 0)) + 1
		model.set_meta("rent_flash_generation", generation)
		model.set_meta("rent_flash_base", base)
		model.material_override = base
		var tween := create_tween()
		for phase in range(1, 7):
			tween.tween_interval(1.0 / 3.0)
			var material: Material = red if phase % 2 == 1 and phase < 6 else base
			tween.tween_callback(func():
				if is_instance_valid(model) and int(model.get_meta("rent_flash_generation", 0)) == generation:
					model.material_override = material)


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
	estate_view = false
	_estate_coins = null
	_estate_value_signature = ""
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_ground = null
	_tile_nodes.clear()
	_tile_mats.clear()
	_tile_pos.clear()
	_level_nodes.clear()
	_plot_anchors.clear()
	_plot_nodes.clear()
	_player_nodes.clear()
	_player_mats.clear()
	_player_target.clear()
	_event_nodes.clear()
	_road_nodes.clear()
	_obstacle_nodes.clear()
	_road_target_nodes.clear()
	_target_cands.clear()
	_target_hover = -1
	_actor_actions.clear()
	_effects = null
	_follow = true
	_cam_pitch = CAM_PITCH_DEF
	_cam_yaw = CAM_YAW_DEF
	map = null

func _sync_owner_marker(platform: Node3D, player: Dictionary, empty: bool) -> void:
	var role := int(player.get("role", 1))
	var key := str(Rules.role_record(role).get("marker", "diamond"))
	var marker := platform.get_node_or_null("OwnerMarker") as OriginalMesh
	if marker != null and str(marker.get_meta("marker_id", "")) != key:
		platform.remove_child(marker)
		marker.queue_free()
		marker = null
	if marker == null and empty:
		var path := "res://assets/original/markers/%s.json" % key
		if FileAccess.file_exists(path):
			marker = OriginalMesh.new()
			marker.name = "OwnerMarker"
			marker.set_meta("marker_id", key)
			platform.add_child(marker)
			marker.setup(JSON.parse_string(FileAccess.get_file_as_string(path)))
			marker.position.y = 0.09
	if marker != null:
		marker.visible = empty and not estate_view

var _road_target_nodes: Dictionary = {}
var _road_target_hover := -1
func set_road_targets(tiles: Array) -> void:
	for tile in _road_target_nodes:
		(_road_target_nodes[tile] as Node3D).visible = tiles.has(tile)
	if not tiles.has(_road_target_hover): _road_target_hover = -1
	for tile in tiles:
		if _road_target_nodes.has(tile): continue
		var marker := MeshInstance3D.new()
		marker.name = "RoadTarget%d" % tile
		var ring := TorusMesh.new()
		ring.inner_radius = _tile_spacing * .23
		ring.outer_radius = _tile_spacing * .31
		marker.mesh = ring
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color8(96, 240, 120)
		material.no_depth_test = true
		marker.material_override = material
		marker.position = _pos_of(int(tile)) + Vector3.UP * (DECAL_LIFT + .18)
		add_child(marker)
		_road_target_nodes[tile] = marker
	set_road_target_hover(_road_target_hover)

func set_road_target_hover(tile: int) -> void:
	_road_target_hover = tile
	for key in _road_target_nodes:
		var marker := _road_target_nodes[key] as MeshInstance3D
		var material := marker.material_override as StandardMaterial3D
		material.albedo_color = Color8(255, 72, 68) if marker.visible and int(key) == tile else Color8(96, 240, 120)
