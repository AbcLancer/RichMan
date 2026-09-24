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
	return m

static func available_maps() -> Array:
	## 扫描 data/maps 目录
	var out: Array = []
	var dir := DirAccess.open("res://data/maps")
	if dir == null:
		return out
	for fn in dir.get_files():
		if fn.ends_with(".json"):
			out.append(fn.get_basename())
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
