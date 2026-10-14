extends Node
## Rules —— 玩法数值单例（autoload）
##
## 数据来源：
##   F:\游戏\Rich6\config\Initvar_r.txt（原版即时制参数）
##     → tools/ 提取为 res://data/rules/realtime.json
##   F:\游戏\Rich6\config\House.txt（原版房屋等级表：升级费 / 基本租金 / 占地）
##     → tools/build_house_rules.py 生成 res://data/rules/houses.json
##
## 原则：所有硬编码数值都必须能追溯到原版配置，不得凭感觉写。

const RULES_PATH := "res://data/rules/realtime.json"
const HOUSES_PATH := "res://data/rules/houses.json"
const UI_STRINGS_PATH := "res://data/rules/ui_strings.json"
const CARD_INDEX_PATH := "res://assets/card/index.json"

## 房屋表读不到时的兜底（对齐 House.txt「一级公寓」：升级费 1000 / 基本租金 1500）
const FALLBACK_UPGRADE_COST := 1000
const FALLBACK_RENT_PER_LEVEL := 1500
const FALLBACK_MAX_LEVEL := 12
const FALLBACK_FOOTPRINT := 1        # House.txt 查不到时的占地（格）

var data: Dictionary = {}
var houses: Dictionary = {}
var house_types: Array = []          # 有序 type id 列表
var file_to_type: Dictionary = {}    # 建筑 id（a0101…）→ 主题 id
var ui_strings: Dictionary = {}      # 原版 config/String.txt（tools/build_ui_strings.py）
var card_index: Dictionary = {}      # 卡面索引（tools/build_card_assets.py）
var _card_meta: Dictionary = {}      # 卡 id → 卡面索引条目
var _card_by_n: Array = []           # 1..42 → 卡 id

func _ready() -> void:
	_load()
	_load_houses()
	_load_ui_strings()
	_load_info_strings()
	_load_card_index()
	_load_roles()
	_load_pet_assets()

func _load() -> void:
	var f := FileAccess.open(RULES_PATH, FileAccess.READ)
	if f == null:
		push_error("Rules: 无法读取 %s" % RULES_PATH)
		return
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Rules: JSON 解析失败")
		return
	data = parsed
	print("[Rules] 已载入 %d 张卡牌定义" % (data.get("cards", []) as Array).size())

func _load_houses() -> void:
	var f := FileAccess.open(HOUSES_PATH, FileAccess.READ)
	if f == null:
		push_error("Rules: 无法读取 %s（先跑 tools/build_house_rules.py）" % HOUSES_PATH)
		return
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Rules: houses.json 解析失败")
		return
	houses = parsed
	house_types = houses.get("type_order", [])
	file_to_type = houses.get("file_to_type", {})
	var n := 0
	for t in house_types:
		n += house_grades(str(t)).size()
	print("[Rules] 已载入 %d 个房屋主题 / %d 个等级（House.txt）" % [house_types.size(), n])

func get_val(path: String, default_value = null):
	## 按 "economy.auction.wait_seconds" 形式的路径取值
	var cur = data
	for part in path.split("."):
		if typeof(cur) != TYPE_DICTIONARY or not cur.has(part):
			return default_value
		cur = cur[part]
	return cur

func seconds_per_day() -> float:
	return float(get_val("time.seconds_per_day", 24.0))

func cards() -> Array:
	return data.get("cards", [])

func card_by_id(id: String) -> Dictionary:
	if id.begins_with("boost:"):
		var base := base_card_id(id)
		if not GEM_SAME.has(base): return {}
		var upgraded := card_by_id(base).duplicate(true)
		upgraded["id"] = id
		upgraded["enhanced"] = true
		for field in GEM_FIELDS.get(base, []): upgraded[field] = float(upgraded.get(field, 0)) * 2.0
		return upgraded
	for c in cards():
		if c.get("id", "") == id:
			return c
	return {}

## Native callbacks 41f1a0/41f270/41f310/41f480 use an explicit 1x/2x branch.
# card.crd tail values, decoded by native 41e460/41f080 (all eight maps).
const GEM_TRANSFORMS := {"upgrade": "tianshi", "monster": "emo", "buyland": "tudigong",
    "free": "caishen", "invincible": "invisible", "missile": "nuke",
    "tax": "qiongshen", "rob": "shuaishen"}
const GEM_SAME := ["caishen", "fushen", "qiongshen", "shuaishen", "tianshi", "emo",
    "qingshen", "run", "priceup", "pricedown", "hibernate", "redcard", "blackcard", "seize", "invisible"]
# Only fields with confirmed callback multipliers belong here. Other enhanced
# cards carry the native flag; unresolved effect fields are not blindly doubled.
const GEM_FIELDS := {"caishen": ["min", "max", "no_rent_steps"], "fushen": ["steps"],
	"qiongshen": ["steps", "target_lose_min", "target_lose_max"], "shuaishen": ["steps"], "seize": ["days"]}

func base_card_id(id: String) -> String:
	return id.trim_prefix("boost:")

func can_gem_combine(id: String) -> bool:
	return not id.begins_with("boost:") and (GEM_SAME.has(id) or GEM_TRANSFORMS.has(id))


func gem_result(id: String) -> String:
	if not can_gem_combine(id): return ""
	return str(GEM_TRANSFORMS.get(id, "boost:" + id))


# ------------------------------------------------- 原版界面字串（String.txt）

const INFO_STRINGS_PATH := "res://data/rules/info_strings.json"
var info_strings: Dictionary = {}


func _load_ui_strings() -> void:
	var f := FileAccess.open(UI_STRINGS_PATH, FileAccess.READ)
	if f == null:
		push_warning("Rules: 无 %s（先跑 tools/build_ui_strings.py）" % UI_STRINGS_PATH)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is not Dictionary:
		push_warning("Rules: ui_strings.json 解析失败")
		return
	ui_strings = parsed
	print("[Rules] 已载入原版界面字串 %d 条（String.txt）" % int(ui_strings.get("_count", 0)))

## 取原版界面字串（id 见 config/String.txt，如 9001 = 财神卡说明、1101 = 请选择对手）
func ui_string(id: int, fallback: String = "") -> String:
	var e: Variant = (ui_strings.get("entries", {}) as Dictionary).get(str(id), null)
	if e is Dictionary:
		return str((e as Dictionary).get("text", fallback))
	return fallback


# ------------------------------------------------- 原版游戏消息（Info.txt）

## ⚠ `Info.txt` 的 id 空间与 `String.txt` **完全独立**：
##    String.txt 的 63 = 「只能用于对手的地产」；Info.txt 的 63 = 「今日乐透开奖」。
## 两份表的用途也不同：String.txt 是**界面标签**，Info.txt 是**过程中弹出的消息**。
func _load_info_strings() -> void:
	var f := FileAccess.open(INFO_STRINGS_PATH, FileAccess.READ)
	if f == null:
		push_warning("Rules: 无 %s（先跑 tools/build_info_strings.py）" % INFO_STRINGS_PATH)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is not Dictionary:
		push_warning("Rules: info_strings.json 解析失败")
		return
	info_strings = parsed
	print("[Rules] 已载入原版游戏消息 %d 条（Info.txt）"
		% int((info_strings.get("entries", {}) as Dictionary).size()))


## 取原版游戏消息（id 见 config/Info.txt，如 203 = 购买小神仙确认、8001 = 俱乐部）
func info_string(id: int, fallback: String = "") -> String:
	var e: Variant = (info_strings.get("entries", {}) as Dictionary).get(str(id), null)
	if e is Dictionary:
		return str((e as Dictionary).get("text", fallback))
	return fallback


## 原版消息里带 `<NUMBER>` / `<SOMEONE>` 这类占位符 → 按表替换。
## keys 用**不带尖括号**的小写键，例如 {"number": "25", "someone": "钱夫人"}。
func info_fill(id: int, keys: Dictionary, fallback: String = "") -> String:
	var s := info_string(id, fallback)
	for k in keys.keys():
		s = s.replace("<%s>" % str(k).to_upper(), str(keys[k]))
	return s

## 卡片目标选择提示（String.txt 1101..1106）
func card_target_prompt(kind: String) -> String:
	const ID := {"player": 1101, "plot": 1102, "stock": 1103,
		"road": 1104, "card": 1105, "building": 1106}
	var id := int(ID.get(kind, 0))
	if id == 0:
		return ""
	return ui_string(id, "请选择目标")

## 卡片右键菜单文字（String.txt 1..6：使用/锁定/丢弃/喂食/解除/组合）
func card_menu_label(which: String) -> String:
	const ID := {"use": 1, "lock": 2, "discard": 3, "feed": 4, "unlock": 5, "combine": 6}
	return ui_string(int(ID.get(which, 0)), which)


# ------------------------------------------------------- 卡面索引（card/index.json）

# ------------------------------------------------------- 角色表（Role.txt）

## `config/Role.txt` 的 12 个角色 → `roles.json`。
## ⭐ 第 6 列「**缺省公司**」就是股票系统里那家公司的名字
##   （老板 2026-09-26 的原版股票截图：中华美食 = 孙小美、新土地 = 阿土伯 …，逐字对上）。
##   另外第 3~5 列是 AI 的**三项性格权重**（害人 / 买卖股票 / 买地）。
const ROLES_PATH := "res://data/rules/roles.json"
var roles_data: Dictionary = {}

func _load_roles() -> void:
	var f := FileAccess.open(ROLES_PATH, FileAccess.READ)
	if f == null:
		push_warning("Rules: 无 %s（先跑 tools/build_role_data.py）" % ROLES_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		roles_data = parsed
		print("[Rules] 已载入 %d 个角色（Role.txt）" % int(roles_data.get("count", 0)))

## 全部角色（按 Role.txt 行序）
func roles() -> Array:
	return roles_data.get("roles", [])

## 第 n 个角色（1..12，= Role.txt 行序 = `Sim.p["role"]`）
func role_record(n: int) -> Dictionary:
	for r in roles():
		if int((r as Dictionary).get("n", 0)) == n:
			return r
	return {}

## 该角色上市的公司名（Role.txt 第 6 列「缺省公司」）
func role_company(n: int) -> String:
	return str(role_record(n).get("company", ""))

func role_name(n: int) -> String:
	return str(role_record(n).get("name", ""))

## AI 三项性格权重 {screw, stock, land}
func role_aggr(n: int) -> Dictionary:
	return role_record(n).get("aggr", {})


func _load_card_index() -> void:
	var f := FileAccess.open(CARD_INDEX_PATH, FileAccess.READ)
	if f == null:
		push_warning("Rules: 无 %s（先跑 tools/build_card_assets.py）" % CARD_INDEX_PATH)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is not Dictionary:
		push_warning("Rules: card/index.json 解析失败")
		return
	card_index = parsed
	_card_meta.clear()
	_card_by_n.clear()
	var arr: Array = card_index.get("cards", [])
	for i in range(arr.size()):
		var e: Variant = arr[i]
		if e is not Dictionary:
			continue
		_card_meta[str((e as Dictionary)["id"])] = e
		_card_by_n.append(str((e as Dictionary)["id"]))
	print("[Rules] 已载入 %d 张卡面（card/index.json）" % _card_meta.size())

## 卡面索引条目（含 ui_name / desc / badge / effect）
func card_meta(id: String) -> Dictionary:
	var e: Variant = _card_meta.get(base_card_id(id), {})
	return e if e is Dictionary else {}

## 卡面中文名（优先用原版 String.txt 的标签，与卡面 art 一致）
func card_name(id: String) -> String:
	if id.begins_with("boost:"): return "强化" + card_name(base_card_id(id))
	var m := card_meta(id)
	if not m.is_empty():
		return str(m.get("ui_name", m.get("name_tga", id)))
	return str(card_by_id(id).get("name", id))

## 卡面说明（原版 String.txt 9001..9042）
func card_desc(id: String) -> String:
	var m := card_meta(id)
	if not m.is_empty():
		return str(m.get("desc", ""))
	return ""

## 卡面左上角徽章数字（1..5）；44e3e0/44e4c0 原版商店按等级×10点券定价。
func card_badge(id: String) -> int:
	return int(card_meta(id).get("badge", 0))

## 卡面贴图路径（res://assets/card/<id>.png）
func card_face_path(id: String) -> String:
	var m := card_meta(id)
	var fn := str(m.get("file", id + ".png"))
	return "res://assets/card/%s" % fn

# ------------------------------------------------- 小神仙素材索引（assets/pets）

## `tools/build_pet_assets.py` 的产物：每只小神仙的图片清单 + 底图槽位坐标 + 商店底图路径。
## 槽位坐标放在 json 里而不是硬编码进 gdscript，方便对着原版底图复量。
const PET_INDEX_PATH := "res://assets/pets/index.json"
var pet_assets: Dictionary = {}


func _load_pet_assets() -> void:
	var f := FileAccess.open(PET_INDEX_PATH, FileAccess.READ)
	if f == null:
		push_warning("Rules: 无 %s（先跑 tools/build_pet_assets.py）" % PET_INDEX_PATH)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		pet_assets = parsed
		print("[Rules] 已载入小神仙素材 %d 只（assets/pets）"
			% int((pet_assets.get("pets", []) as Array).size()))


## 某只小神仙某类图（face / big / cast / icon / mini / faceb）某一级（1..4）的路径。
## 取不到就回退到该类第 1 张，再取不到返回空串。
func pet_art(pet_id: String, kind: String, level: int = 1) -> String:
	for r in pet_assets.get("pets", []):
		if str((r as Dictionary).get("id", "")) != pet_id:
			continue
		var files: Array = (r as Dictionary).get("files", {}).get(kind, [])
		if files.is_empty():
			return ""
		var i := clampi(level - 1, 0, files.size() - 1)
		return "res://assets/pets/%s/%s" % [pet_id, str(files[i])]
	return ""


## Native 4321b0 -> 432910 -> 432830: 01/02/03 are HUD expressions,
## independent of level. Stars represent level separately (447740).
func pet_hud_art(pet_id: String, anxious: bool, ready: bool) -> String:
	return pet_art(pet_id, "face", 2 if anxious else 3 if ready else 1)


func pet_star(level: int) -> String:
	var s: Array = pet_assets.get("stars", [])
	var i := clampi(level - 1, 0, maxi(s.size() - 1, 0))
	return "res://assets/pets/%s" % str(s[i]) if not s.is_empty() else ""


## 商店底图的槽位表（native 256×256 坐标），键见 tools/build_pet_assets.py 的 SLOT
func pet_slots(name: String) -> Variant:
	return (pet_assets.get("slot", {}) as Dictionary).get(name, null)


func shop_ui_path(name: String) -> String:
	return str((pet_assets.get("ui", {}) as Dictionary).get(name, ""))


## 第 n 张（1..42）的卡 id
func card_id_at(n: int) -> String:
	var i := n - 1
	if i < 0 or i >= _card_by_n.size():
		return ""
	return str(_card_by_n[i])


# ------------------------------------------------------------- 房屋等级表

## 可建设的主题（原版 House.txt 里 Uptown / Shop / Industry）
func primary_types() -> Array:
	return houses.get("primary_types", ["uptown", "shop", "industry"])

func has_house_type(type_id: String) -> bool:
	return ((houses.get("types", {}) as Dictionary).has(type_id))

func house_type_cn(type_id: String) -> String:
	return str(_house_type(type_id).get("cn", type_id))

func house_grades(type_id: String) -> Array:
	return _house_type(type_id).get("grades", [])

## 等级上限（= House.txt 的 nGrade）。等级 0 = 空地，1..n_grade = 各房屋等级。
func house_max_level(type_id: String) -> int:
	var n := int(_house_type(type_id).get("n_grade", 0))
	return n if n > 0 else FALLBACK_MAX_LEVEL

## 取某等级的房屋定义（1-based；越界时 clamp 到合法范围）
func house_grade(type_id: String, level: int) -> Dictionary:
	var gs := house_grades(type_id)
	if gs.is_empty():
		return {}
	var i := clampi(level, 1, gs.size()) - 1
	var g: Variant = gs[i]
	return g if g is Dictionary else {}

# The old list index remains the asset key for save compatibility. Native size
# and local grade are distinct; an upgrade never crosses a size group.
func house_local_grade(type_id: String, level: int) -> int:
	if level <= 0: return 0
	var side := house_footprint(house_file(type_id, level))
	var local := 0
	for g in house_grades(type_id):
		if house_footprint(str(g.file)) == side: local += 1
		if int(g.level) == level: return local
	return 0

func house_asset_level(type_id: String, side: int, local: int) -> int:
	if local <= 0: return 0
	var count := 0
	for g in house_grades(type_id):
		if house_footprint(str(g.file)) != side: continue
		count += 1
		if count == local: return int(g.level)
	return 0

func house_next_level(type_id: String, level: int) -> int:
	if level <= 0: return house_asset_level(type_id, 1, 1)
	return house_asset_level(type_id, house_footprint(house_file(type_id, level)),
		house_local_grade(type_id, level) + 1)

## 该等级被踩到时付的过路费基数（元）
func house_rent(type_id: String, level: int) -> int:
	var v := int(house_grade(type_id, level).get("base_rent", 0))
	if v > 0:
		return v
	return FALLBACK_RENT_PER_LEVEL * maxi(level, 1)

## 由**当前等级**升到下一等级要付的钱（元）
func house_upgrade_cost(type_id: String, level: int) -> int:
	var g := house_grade(type_id, level)
	if g.is_empty():
		return FALLBACK_UPGRADE_COST
	return int(g.get("upgrade_cost", FALLBACK_UPGRADE_COST))

## 该等级的房屋模型 id（a0101 / b0203 / d201 …），直接取自 House.txt 的「文件」列
func house_file(type_id: String, level: int) -> String:
	return str(house_grade(type_id, level).get("file", ""))

## 建筑 id 反查主题（a0101 → uptown）
func type_of_house_file(file_id: String) -> String:
	return str(file_to_type.get(file_id, ""))

## 建筑 id → 该等级的全量信息（type / level / name / w / h / size）。
## 数据源是 houses.json 的 files 段（由 tools/build_house_rules.py 生成）。
func house_file_info(file_id: String) -> Dictionary:
	var files: Dictionary = houses.get("files", {})
	var e: Variant = files.get(file_id, {})
	return e if e is Dictionary else {}

## 建筑占地（宽, 长），单位 = 格。原版 House.txt 第 3/4 列。
## 1x1 = 公寓/工厂，2x2 = 住宅/重工厂+商场，3x3 = 住宅区/工业区/商业区。
func house_footprint_size(file_id: String) -> Vector2i:
	var e := house_file_info(file_id)
	if e.is_empty():
		return Vector2i(FALLBACK_FOOTPRINT, FALLBACK_FOOTPRINT)
	return Vector2i(maxi(int(e.get("w", FALLBACK_FOOTPRINT)), 1),
					maxi(int(e.get("h", FALLBACK_FOOTPRINT)), 1))

## 建筑占地边长（取宽/长的较大者）。渲染时用来决定缩放倍数。
func house_footprint(file_id: String) -> int:
	var s := house_footprint_size(file_id)
	return maxi(s.x, s.y)

## 该建筑 / 该主题 + 等级对应的尺寸档字符串（"1x1" / "2x2" / "3x3"）
func house_footprint_label(file_id: String) -> String:
	return str(house_file_info(file_id).get("size", "%dx%d" % [FALLBACK_FOOTPRINT, FALLBACK_FOOTPRINT]))

func _house_type(type_id: String) -> Dictionary:
	var types: Dictionary = houses.get("types", {})
	var t: Variant = types.get(type_id, {})
	return t if t is Dictionary else {}
