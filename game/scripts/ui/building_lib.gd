extends RefCounted
class_name BuildingLib
## BuildingLib —— 原版 3D 建筑模型库（.r6m，由 tools/pol2obj.py pack 生成）
##
## 目录约定：
##   res://assets/buildings/index.json     模型清单（id / 风格 / 类型 / 等级 / 尺寸 / 贴图）
##   res://assets/buildings/<id>.r6m       R6BM 二进制网格
##   res://assets/buildings/tex/<..>.png   原版图集（.tga 转 PNG）
##
## R6BM 布局（小端）：
##   char[4] "R6BM" | u32 ver | u32 n_vert | u32 n_tri
##   f32[3] 归一化包围盒尺寸（max(x,z) == 1.0）
##   f32[3] 归一化偏移（原始单位）
##   f32[3*n_vert] 位置      （Y 朝上，脚底 y=0，水平居中）
##   f32[2*n_vert] UV        （Godot 约定：v=0 在贴图顶部）
##   u32[3*n_tri]  三角索引
##
## R6HS v100 顶点从文件偏移 128 开始：UV2 + normal3 + position3。
## 旧版偏移 144 导致 UV 读到下一顶点；不是盒投影缺陷。参见 scene-recovery 报告。

const DIR := "res://assets/buildings/"

static var _index: Dictionary = {}      # id -> Dictionary
static var _meshes: Dictionary = {}     # id -> ArrayMesh
static var _mats: Dictionary = {}       # id -> StandardMaterial3D
static var _ready := false

# ---------------------------------------------------------------- 清单

static func _load_index() -> void:
	if _ready:
		return
	_ready = true
	var p := DIR + "index.json"
	if not FileAccess.file_exists(p):
		push_warning("BuildingLib: 找不到 %s" % p)
		return
	var txt := FileAccess.get_file_as_string(p)
	var arr: Variant = JSON.parse_string(txt)
	if arr is Array:
		for e in arr:
			if e is Dictionary:
				_index[str(e.get("id", ""))] = e


static func has(id: String) -> bool:
	_load_index()
	return _index.has(id)


static func entry(id: String) -> Dictionary:
	_load_index()
	return _index.get(id, {})


static func ids() -> Array:
	_load_index()
	var out := _index.keys()
	out.sort()
	return out


# ---------------------------------------------------------------- 网格

static func mesh_for(id: String) -> ArrayMesh:
	_load_index()
	if _meshes.has(id):
		return _meshes[id]
	var p := DIR + id + ".r6m"
	if not FileAccess.file_exists(p):
		return null
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return null
	var magic := f.get_buffer(4).get_string_from_ascii()
	if magic != "R6BM":
		push_warning("BuildingLib: %s 魔数错误 %s" % [p, magic])
		return null
	f.get_32()                                        # version
	var nv := f.get_32()
	var nt := f.get_32()
	f.get_float(); f.get_float(); f.get_float()       # size
	f.get_float(); f.get_float(); f.get_float()       # offset

	var pf := f.get_buffer(nv * 12).to_float32_array()
	var uf := f.get_buffer(nv * 8).to_float32_array()
	var ib := f.get_buffer(nt * 12).to_int32_array()

	var verts := PackedVector3Array()
	verts.resize(nv)
	for i in range(nv):
		verts[i] = Vector3(pf[i * 3], pf[i * 3 + 1], pf[i * 3 + 2])
	var uvs := PackedVector2Array()
	uvs.resize(nv)
	for i in range(nv):
		uvs[i] = Vector2(uf[i * 2], uf[i * 2 + 1])
	var idx := PackedInt32Array()
	idx.resize(nt * 3)
	for i in range(nt * 3):
		idx[i] = ib[i]

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[id] = m
	return m


static func size_of(id: String) -> Vector3:
	var e := entry(id)
	var s: Array = e.get("size", [1.0, 0.6, 1.0])
	if s.size() < 3:
		return Vector3(1, 0.6, 1)
	return Vector3(float(s[0]), float(s[1]), float(s[2]))


## 建筑占地边长（格）。1 = 一格（公寓/工厂），2 = 2x2（住宅/重工厂），3 = 3x3（住宅区/工业区）。
## 权威来源是 House.txt 的「宽 / 长」列（→ data/rules/houses.json 的 files 段）。
## R6BM 网格在打包时已归一化成「长边 = 1.0」，所以渲染时直接乘这个倍数即可。
static func footprint(id: String) -> int:
	return maxi(Rules.house_footprint(id), 1)


## 占地的宽 × 长（多数建筑是正方形，但原版表里是两列，保留原始信息）
static func footprint_size(id: String) -> Vector2i:
	return Rules.house_footprint_size(id)


## 人类可读的占地标签，如 "3x3"，用于 HUD / 自检
static func footprint_label(id: String) -> String:
	return Rules.house_footprint_label(id)


# ---------------------------------------------------------------- 材质

static func material_for(id: String) -> StandardMaterial3D:
	_load_index()
	if _mats.has(id):
		return _mats[id]
	var e := entry(id)
	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.roughness = 0.92
	mat.metallic = 0.0
	mat.metallic_specular = 0.08
	var tex_path := str(e.get("tex", ""))
	if tex_path != "":
		var full := DIR + tex_path
		if ResourceLoader.exists(full):
			var r: Resource = load(full)
			if r is Texture2D:
				mat.albedo_texture = r as Texture2D
	if mat.albedo_texture == null:
		mat.albedo_color = Color(0.78, 0.74, 0.68)
	_mats[id] = mat
	return mat


# ---------------------------------------------------------------- 选型

## 地图 → 建筑风格组（**仅作旧兜底**）。
## 注意：2026-09-26 修正 —— a/b/c 组才是通用住宅/商店/工业，
## d1xx/d2xx/d3xx 是 House.txt 里的 Special2/Special1/Special3（花园·连锁店·公园 /
## 俱乐部·银行·大酒店 / 垃圾场·发电厂·研究所），**不是埃及专用住宅**。
## 旧的 aiji→"d" 映射等于拿「花园」当住宅渲染，已废弃。
const STYLE_BY_MAP := {
	"aiji": "d",
	"china": "a",
	"japan": "b",
	"paris": "a",
	"island": "c",
	"space": "c",
	"train": "b",
}

## 由「主题 + 等级」取建筑模型 id —— **权威路径**。
## House.txt 的「文件」列就是模型目录名（a0101 / b0203 / d201 …），
## 经 tools/build_house_rules.py 落成 data/rules/houses.json。
## 等级 0 = 空地（无房屋），返回空串。
static func id_for(map_name: String, type_id: String, level: int) -> String:
	_load_index()
	if level <= 0:
		return ""
	var fid := Rules.house_file(type_id, level)
	if fid != "" and _index.has(fid):
		return fid
	# 模型缺失时才退回旧的名字猜法
	return pick_id(map_name, 0, level)

## 【旧】按风格 + 街区序号轮转猜模型名。新代码请用 id_for()。
## 命名两套：
##   a/b/c 组：<风格><主题2位><等级2位>，如 a0101 / b0203
##   d/e 组  ：<风格><主题1位><等级2位>，如 d101 / e1
static func pick_id(map_name: String, street_index: int, level: int) -> String:
	_load_index()
	var style := str(STYLE_BY_MAP.get(map_name, "a"))
	var btype := (maxi(street_index, 0) % 3) + 1
	var lv := clampi(level, 1, 5)
	var cands: Array = []
	for l in [lv, 5, 4, 3, 2, 1]:
		cands.append("%s%02d%02d" % [style, btype, l])
		cands.append("%s%d%02d" % [style, btype, l])
	cands.append("%s%d" % [style, btype])
	for s in ["a", "b", "c", "d", "e"]:
		for l in [lv, 1]:
			cands.append("%s%02d%02d" % [s, btype, l])
			cands.append("%s%d%02d" % [s, btype, l])
		cands.append("%s%d" % [s, btype])
	for t in cands:
		if _index.has(t):
			return t
	return ""
