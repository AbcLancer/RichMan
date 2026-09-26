extends RefCounted
class_name MapData
## MapData —— 地图数据加载
##
## 数据来源：res://data/maps/<name>.json
## 由 tools/build_map.py 从原版 gamedata.pck 的 scene/<name>/ 生成，
## 街道名、虚拟公司、标志点坐标均为原版真实数据。

var name: String = ""
var display_name: String = ""
var camera: Dictionary = {}
var streets: Array = []
var tiles: Array = []
var build_flags: Dictionary = {}
var virtual_companies: Array = []
var landmarks: Dictionary = {}
## 体力四参数（原版 config/scene/<map>/<map>.txt 的「和体力相关参数」一行）：
## step_cost / regen_per_sec / min_to_start / max
var stamina: Dictionary = {}
## 棋盘路面物体生成数量（同一份场景配置）：card / ring / hamburger / pethouse …
var road_items: Dictionary = {}

## 埃及坐标来自原版 R6MP 道路记录与 Bezier 曲线，见 r6_map_verified.py。
var tile_pos: Array = []          # [Vector2(x, z)]，与 tiles 等长
var board_size: float = 200.0
var ground_texture: String = ""   # res://assets/terrain/<map>_ground.png（若有）
var has_real_layout: bool = false
var original_layout: Dictionary = {}

static func load_from(map_name: String) -> MapData:
	var path := "res://data/maps/%s.json" % map_name
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("MapData: 找不到 %s" % path)
		return null
	var txt := f.get_as_text()
	f.close()
	var d = JSON.parse_string(txt)
	if typeof(d) != TYPE_DICTIONARY:
		push_error("MapData: %s 解析失败" % path)
		return null
	var m := MapData.new()
	m.name = d.get("name", map_name)
	m.display_name = d.get("display_name", map_name)
	m.camera = d.get("camera", {})
	m.streets = d.get("streets", [])
	m.tiles = d.get("tiles", [])
	m.build_flags = d.get("build_flags", {})
	m.virtual_companies = d.get("virtual_companies", [])
	m.landmarks = d.get("landmarks", {})
	m.stamina = d.get("stamina", {})
	m.road_items = d.get("road_items", {})
	m._load_layout(map_name)
	return m


## 载入逆向重建的棋盘坐标（缺失时退回 false，由表现层用矩形布局兜底）
func _load_layout(map_name: String) -> void:
	var path := "res://data/maps/%s_tilepos.json" % map_name
	tile_pos.clear()
	has_real_layout = false
	ground_texture = ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY:
		return
	board_size = float(d.get("_board_size", 200.0))
	if d.has("knots") and d.has("roads"):
		original_layout = d
	var arr: Array = d.get("tiles", [])
	if arr.size() != tiles.size():
		push_warning("MapData: %s 格数不匹配（tilepos %d vs tiles %d），改用矩形布局"
			% [map_name, arr.size(), tiles.size()])
		return
	for e in arr:
		tile_pos.append(Vector2(float(e["x"]), float(e["z"])))
	has_real_layout = not tile_pos.is_empty()
	# 对应地形贴图（只有部分地图有原版 ditu* 资源）
	var tex := "res://assets/terrain/%s_ground.png" % map_name
	if ResourceLoader.exists(tex):
		ground_texture = tex

static func available_maps() -> Array:
	## 扫描 data/maps 目录
	var out: Array = []
	var dir := DirAccess.open("res://data/maps")
	if dir == null:
		return out
	for fn in dir.get_files():
		if fn.ends_with(".json"):
			var map_name := fn.get_basename()
			# 同目录还存放格点、街区和 UV 标定文件；它们不是可选地图。
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/" + fn))
			if data is Dictionary and data.has("tiles") and data.has("name"):
				out.append(map_name)
	out.sort()
	return out

func tile_count() -> int:
	return tiles.size()

func tile(i: int) -> Dictionary:
	if tiles.is_empty():
		return {}
	return tiles[((i % tiles.size()) + tiles.size()) % tiles.size()]

func is_plot(i: int) -> bool:
	return tile(i).get("kind", "") == "plot"

func street_of(i: int) -> String:
	return tile(i).get("street", "")


## 第 i 格的世界坐标（XZ 平面）。无真实布局时返回 ZERO，由表现层兜底。
func pos_of(i: int) -> Vector2:
	if tile_pos.is_empty():
		return Vector2.ZERO
	var n := tile_pos.size()
	return tile_pos[((i % n) + n) % n]


## 第 i 格处路径的单位切向（用于让地块贴花与道路对齐）。
func dir_of(i: int) -> Vector2:
	if not original_layout.is_empty():
		return (route_position(i, 1, 0.01) - route_position(i, -1, 0.01)).normalized()
	if tile_pos.size() < 2:
		return Vector2.RIGHT
	var a := pos_of(i - 1)
	var b := pos_of(i + 1)
	var v := b - a
	if v.length() < 0.0001:
		return Vector2.RIGHT
	return v.normalized()


func _pair(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))


## rich6.exe 0x42bc40: advance by stored segment lengths, then evaluate Bezier.
func route_position(i: int, direction: int, progress: float) -> Vector2:
	var p := route_position_3d(i, direction, progress)
	return Vector2(p.x, p.z)

func _knot_point(knot: Dictionary, key: String, height_index: int) -> Vector3:
	var p := _pair(knot[key])
	return Vector3(p.x, float(knot.get("height", [0, 0, 0])[height_index]), p.y)

func route_position_3d(i: int, direction: int, progress: float) -> Vector3:
	if original_layout.is_empty():
		var p := pos_of(i).lerp(pos_of(i + direction), progress)
		return Vector3(p.x, 0, p.y)
	var roads: Array = original_layout["roads"]
	var knots: Array = original_layout["knots"]
	var idx := posmod(i if direction > 0 else i - 1, roads.size())
	var road: Dictionary = roads[idx]
	var amount := progress if direction > 0 else 1.0 - progress
	var distance := float(road["distance"]) * clampf(amount, 0.0, 1.0)
	var parameter := float(road["parameter"])
	var k := int(parameter) % knots.size()
	var remaining := float(road["remaining"])
	if distance < remaining:
		parameter = float(k) + 1.0 - (remaining - distance) / float(knots[k]["length"])
	else:
		distance -= remaining
		k = (k + 1) % knots.size()
		while distance >= float(knots[k]["length"]):
			distance -= float(knots[k]["length"])
			k = (k + 1) % knots.size()
		parameter = float(k) + distance / float(knots[k]["length"])
	var f := parameter - floorf(parameter)
	var a: Dictionary = knots[k]
	var b: Dictionary = knots[(k + 1) % knots.size()]
	return _knot_point(a, "point", 2).bezier_interpolate(_knot_point(a, "outgoing", 1), _knot_point(b, "incoming", 0), _knot_point(b, "point", 2), f)


## Original block matrix maps grid CORNERS; the center adds half a cell.
func plot_transform(i: int, footprint: int = 1) -> Transform3D:
	var road: Dictionary = original_layout["roads"][posmod(i, tile_count())]
	var block: Dictionary = original_layout["blocks"][int(road["block"])]
	var w := int(block["width"])
	var d := int(block["depth"])
	var col := clampi(int(road["cell"]) % w, 0, maxi(0, w - footprint))
	var row := clampi(int(road["cell"]) / w, 0, maxi(0, d - footprint))
	var ax := _pair(block["axes"][0])
	var az := _pair(block["axes"][1])
	var center := _pair(block["origin"]) + ax * (col + footprint * 0.5) + az * (row + footprint * 0.5)
	return Transform3D(Basis(Vector3(ax.x, 0, ax.y), Vector3.UP * sqrt(ax.length() * az.length()),
		Vector3(az.x, 0, az.y)), Vector3(center.x, float(block.get("height", 0.0)), center.y))


func minimap_uv(i: int, direction: int = 1, progress: float = 0.0) -> Vector2:
	if original_layout.is_empty():
		return route_position(i, direction, progress) / board_size + Vector2(0.5, 0.5)
	# Reverse the affine used for the ground. Original minimap has its own mapping.
	var world := route_position(i, direction, progress) / board_size + Vector2(0.5, 0.5)
	var affine: Array = original_layout["ground_affine"]
	var transform := Transform2D(_pair(affine[0]), _pair(affine[1]), _pair(affine[2]))
	var original := transform.affine_inverse() * Vector2(world.x, 1.0 - world.y)
	var mini: Dictionary = original_layout["minimap"]
	var point := (original - _pair(mini["origin"])) * float(mini["scale"]) + _pair(mini["offset"])
	if int(mini["swap"]) != 0:
		point = Vector2(point.y, point.x)
	# 0x4464fe/0x446bc5: marker margins 20,16; source widget 229x155.
	return (point + Vector2(20, 16)) / Vector2(229, 155) * Vector2(1, 128.0 / 98.0)
