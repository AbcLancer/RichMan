extends RefCounted
class_name Sim
## Sim —— 权威游戏模拟（即时制）
##
## 设计要点（对齐原版大富翁6 即时制）：
##   1. 时间是连续的：1 天 = 24 秒（Rules.seconds_per_day）
##   2. 角色沿格子【连续】移动，不是回合制踏步；速度单位 = 格/秒
##   3. 到达格子时结算（买地/过路费/事件点）
##   4. 状态效果以【秒】计时（无敌 72s、冬眠 10s …）
##   5. 玩家静止 25 秒进入睡眠（原版 Player_Sleep_StandTime）
##
## 本类只做逻辑，不做任何渲染与网络 IO —— 服务端与客户端（预测）共用。

signal log_message(text: String)
## 语义事件 —— 供表现层配音效/语音/新闻播报。
## 本类不发任何渲染指令，只描述"发生了什么"，这样服务端与客户端可共用。
## kind 取值见 docs/sfx-map.md；data 至少含 {pid, role, tile}
signal game_event(kind: String, data: Dictionary)

# ---- 经济常量（对齐原版 House.txt / Initvar_r.txt）----
## ⭐ **地价指数**（动态，不是常量了）
##
## 依据 `Initvar_r.txt`：
##   `Empty_Grid_PriceFactor = 200`   //空地产格价格 (200) 将要乘**地价因子** (10)
##   `EstateGrid_PriceFactor_Min = 5` //**地价指数最小值**
## → **空地产格价 = 200 × 地价指数**，指数**默认 10**（就是那行注释尾上的 (10)）。
##
## 老板 2026-09-27：「游戏里是 30 天为一个月，**每个月物价指数都会有上涨**」。
## ⚠️ **涨幅在配置里没有明文**（只有最小值 5，没有最大值也没有涨速）→ 取**每月 +1**（推断），
##   并且始终不低于 `EstateGrid_PriceFactor_Min`。房租、地价都按这个指数放大。
var estate_index: float = 10.0
## 上一次涨指数时的「第几个月」，避免一个月内重复涨
var estate_month := 0


## 空地产格价格 = `Empty_Grid_PriceFactor`(200) × 地价指数
func empty_plot_price(idx: int = -1) -> int:
	return int(round(float(Rules.get_val("economy.empty_grid_price_factor", 200))
		* estate_index * _land_factor(idx) / 10.0))

## Native cells own these factors independently of ownership (42e870/42e9e0).
## Keep physical corner frontages on one key, including before anyone buys land.
var land_factors: Dictionary = {}
var economy_factors: Dictionary = {"industry": 1.0, "shop": 1.0, "uptown": 1.0}
var _environment_signature: Array = []

func _refresh_land_environment() -> void:
	if map == null or map.original_layout.is_empty(): return
	var buildings: Array = []
	var signature: Array = []
	for key in unique_plot_keys():
		var estate: Dictionary = plots[key]
		if int(estate.get("level", 0)) <= 0: continue
		var road: Dictionary = map.original_layout.roads[int(key)]
		var cell := int(estate.get("build_cell", -1))
		if cell < 0: cell = int(road.cell)
		var grade := Rules.house_grade(str(estate.get("type", "")), int(estate.level))
		buildings.append({"block": int(road.block), "cell": cell, "grade": grade})
		signature.append([int(road.block), cell, str(grade.get("file", ""))])
	if signature == _environment_signature: return
	_environment_signature = signature
	var seen := {}
	for idx in range(map.tile_count()):
		if not map.is_plot(idx): continue
		var key := _land_key(idx)
		if seen.has(key): continue
		seen[key] = true
		var road: Dictionary = map.original_layout.roads[idx]
		var bid := int(road.block)
		if bid < 0: continue
		var width := int(map.original_layout.blocks[bid].width)
		var cell := int(road.cell)
		var target := Vector2(cell % width + .5, cell / width + .5)
		var initial := clampf(10.0 + float(street_index.get(map.street_of(idx), 0)), 5.0, 100.0)
		var state: Dictionary = land_factors.get(key, {"price": initial, "rent": initial}).duplicate()
		state.price = float(state.get("rent", initial))
		state.environment = {"industry": 0.0, "shop": 0.0, "uptown": 0.0}
		# 41d9e0 resets derived price from the baseline, then 41d800 contributes
		# each building in its own block with radial linear falloff.
		for building in buildings:
			if int(building.block) != bid: continue
			var grade: Dictionary = building.grade
			var side := float(grade.get("w", 1))
			var center := Vector2(int(building.cell) % width + side * .5,
				int(int(building.cell) / width) + side * .5)
			var radius := (side + 1.0) * 1.5
			var weight := maxf(0.0, 1.0 - center.distance_to(target) / radius)
			state.price = clampf(float(state.price) + float(grade.get("price_effect", 0)) * weight, 5.0, 100.0)
			for type_id in ["industry", "shop", "uptown"]:
				state.environment[type_id] += float(grade.get("add_" + type_id, 0)) * weight
		land_factors[key] = state

func _land_key(idx: int) -> int:
	return int(map.plot_frontages(idx)[0]) if map != null and map.is_plot(idx) else idx

func _land_factor(idx: int) -> float:
	if idx < 0 or map == null: return 10.0
	_refresh_land_environment()
	var initial := clampf(10.0 + float(street_index.get(map.street_of(idx), 0)), 5.0, 100.0)
	return float(land_factors.get(_land_key(idx), {"price": initial}).get("price", initial))

func _change_land_factors(delta: float, percentage: bool, street: String = "") -> int:
	var seen := {}
	var changed := 0
	for idx in range(map.tile_count()):
		if not map.is_plot(idx) or (street != "" and map.street_of(idx) != street): continue
		var key := _land_key(idx)
		if seen.has(key): continue
		seen[key] = true
		var old := _land_factor(idx)
		var state: Dictionary = land_factors.get(key, {"price": old, "rent": old}).duplicate()
		var price := old + (absf(old) * delta if percentage else delta)
		# Native updates price first, then uses that new price for rent's increment.
		var rent := float(state.get("rent", old)) + (absf(price) * delta if percentage else delta)
		state.price = clampf(price, 5.0, 100.0)
		state.rent = clampf(rent, 5.0, 100.0)
		land_factors[key] = state
		if not is_equal_approx(old, float(state.price)): changed += 1
	return changed


## 相对的物价倍数（房租等按它放大；指数 10 = 1.0 倍）
func price_scale() -> float:
	return estate_index / 10.0


## Native 43f270 / 4418b0 averages active company assets, not stock quotes.
## 441170 raises the integer world index to floor(current / initial), capped at9.
## Keep tenths internally for existing snapshots; native whole-index values are10..90.
var initial_company_assets := 0

func _company_asset_average() -> int:
	# 440cd0 stores player-company count at +0c; 4418b0 excludes virtual firms.
	var total := 0
	var count := 0
	for p in players.values():
		if not bool(p.alive): continue
		total += int(p.money) + stock_portfolio_value(p) + estate_value(p)
		count += 1
	return maxi(1, int(total / maxi(1, count)))

func _tick_estate_index() -> void:
	var current := _company_asset_average()
	if initial_company_assets <= 0:
		initial_company_assets = current
		return
	var index := mini(9, int(current / initial_company_assets))
	if float(index) <= price_scale(): return
	var previous := price_scale()
	estate_index = float(index * 10)
	var date := calendar_at_day(road_day)
	log_message.emit("[物价] 公司平均资产增长，物价指数涨到%d" % index)
	_ev("estate_index_up", null, {"month": date.month, "year": date.year,
		"index": index, "price": empty_plot_price(), "delta": index - previous})
const EMPTY_PLOT_RENT := 250        # Empty_Grid_RentFactor(25) × 地价因子(10)
const START_MONEY := 500000         # 对齐 Player_Com_Capital 量级
const START_HP := 3000
const MOVE_SPEED := 2.0             # 格/秒（对齐 BullDozer_Speed / Ambulance_Speed）
const IDLE_SLEEP_SECONDS := 25.0

## ---- 体力（即时制行走能量）----
## 唯一权威：config/scene/<map>/<map>.txt 那一行「和体力相关参数」，
## 依次是「每走一步消耗体力 / 每秒恢复体力 / 自己走所需要最小体力值 / 玩家最大体力值」。
## 实测各地图：aiji / china / japan / paris / island = `20 7 240 600`；
##             space（太空关）= `0 0 10 5000`（不走体力，上限 5000）。
## 下表只是**读不到地图配置时的兜底**，正常走 map.stamina。
const STAMINA_STEP_COST := 20.0     # 每前进 1 格消耗
const STAMINA_REGEN := 7.0          # 每秒恢复
const STAMINA_MIN_START := 240.0    # 低于它不能开始行走（原版「自己走所需要最小体力值」）
const STAMINA_MAX := 600.0          # 上限
## 一次最多几颗骰子（GO 钮左侧选择器）。
## 原版实机 5 张截图（07_牌桌 / 08_牌桌_2 / 09_牌桌_3 / new_session_board /
## new_session_later）一致：GO 钮左侧**固定 2 颗**，上白（选中）下灰（未选中），
## 从未出现第 3 颗 → 上限 = 2，默认掷 1 颗。
const DICE_PER_ROLL_MAX := 2

## 掷骰动画时长：点数定下后，**先播「骰子抛出 → 抛物线落下 → 定格点数」**，
## 这段时间角色**站着不动**，动画完了才起步 —— 这就是原版的节奏。
## ⚠️ 我们原来是把 `moving` 一设就走、骰子只是「同时」显示数字，节奏是错的
##    （老板 2026-09-26 反馈）。这个值要和表现层的 `DIE_FLY_TIME` 对齐。
const ROLL_ANIM_SECONDS := 1.15
const ENTRY_SECONDS := 2.8

## The authority chooses distinct random starting road nodes once, before play.
func begin_entry() -> void:
	initial_company_assets = _company_asset_average()
	var available: Array = range(map.tile_count())
	var chosen: Array = []
	var spacing := maxi(2, map.tile_count() / maxi(player_ids().size() * 5, 1))
	for id in player_ids():
		if available.is_empty(): break
		var candidates: Array = []
		for road in available:
			var spaced := true
			for prior in chosen:
				if _tile_distance(int(road), int(prior)) < spacing: spaced = false; break
			if spaced: candidates.append(road)
		if candidates.is_empty(): candidates = available
		var tile := int(candidates[rng.randi_range(0, candidates.size() - 1)])
		available.erase(tile)
		chosen.append(tile)
		var p: Dictionary = players[id]
		p.tile = tile
		p.moving = 0
		p.progress = 0.0
		p.entry_started = time
		p.entry_until = time + ENTRY_SECONDS
		p.move_after = p.entry_until
		_clear_chance(p)

## ---- 卡片目标类型 ----
## 提示文案来自原版 `config/String.txt` 1101..1106（Rules.card_target_prompt）。
## ⚠ 这张「哪张卡点谁」的映射是**推导**出来的（依据每张卡的说明文字 + 作用对象），
##   原版配置里没有这张表 → 代码改动必须同步这里。
##   player = 点选对手；road = 显式选路点（飞弹还支持点击相邻地产平台）；
##   street/plot = 当前仍有取当前格或自动挑地的实现，待逐张对齐；stock/card = 专用选择流程。
const CARD_TARGET := {
	"qiongshen": "player", "shuaishen": "player", "abduct": "player",
	"tax": "player", "rob": "player", "sharewealth": "player",
	"tudigong": "plot", "rebuild": "plot", "upgrade": "building", "monster": "building",
	"buyland": "plot", "missile": "road", "nuke": "road",
	"tianshi": "street", "emo": "street", "priceup": "street",
	"pricedown": "street", "seize": "street",
	"roadblock": "road",
	"redcard": "stock", "blackcard": "stock",
	"copy": "card", "gem": "card",
}

## 需要玩家真的点一个对手才能用的卡（只有这一类的使用是两步：选卡 → 选人）
func card_target(card_id: String) -> String:
	return str(CARD_TARGET.get(Rules.base_card_id(card_id), ""))

func card_needs_player(card_id: String) -> bool:
	return card_target(card_id) == "player"

func card_map_candidates(pid: int, card_id: String) -> Array:
	if card_target(card_id) != "building": return card_road_candidates(pid, card_id)
	var p: Dictionary = players.get(pid, {})
	var out: Array = []
	if p.is_empty(): return out
	for index in unique_plot_keys():
		var plot: Dictionary = plots[index]
		if _tile_distance(int(p.tile), int(index)) > CARD_TARGET_MAX_TILES: continue
		if card_id == "upgrade":
			if int(plot.owner) != pid or construction_plan(pid, int(index)).is_empty(): continue
		elif int(plot.level) <= 0: continue
		out.append(int(index))
	return out

func rebuild_plan(pid: int, index: int, house_type: String) -> Dictionary:
	if not plots.has(index) or int(plots[index].get("level", 0)) <= 0: return {}
	if int(plots[index].get("owner", -1)) < 0: return {}
	# 原版 0x41fa20 把普通建筑类别 0..2 改成特殊类别 3..5，保留
	# 地块尺寸，特殊建筑内部等级固定为 1。House.txt 的 d1/d2/d3
	# 用 1/2/3 表示占地尺寸，故这里的 level 必须等于 footprint。
	if not Rules.primary_types().has(str(plots[index].get("type", ""))): return {}
	if not ["special1", "special2", "special3"].has(house_type): return {}
	var old_type := str(plots[index].get("type", ""))
	var old_level := int(plots[index].get("level", 1))
	var old_space := Rules.house_footprint(Rules.house_file(old_type, old_level))
	var space := clampi(int(plots[index].get("footprint", old_space)), 1, 3)
	var grade := Rules.house_grade(house_type, space)
	if grade.is_empty() or Rules.house_footprint(str(grade.get("file", ""))) != space: return {}
	return {"type": house_type, "level": space, "name": str(grade.get("name", "")),
		"cost": 0, "building_grade": 1, "footprint": space, "members": plots[index].get("members", [index])}

## 还没做的子系统对应的卡 → **不消耗**（宁可留着，也别让玩家白扔一张卡）。
## ✅ 2026-09-26：**红卡 / 黑卡**（股票系统上线）与**复制卡**（本轮）都已解开 → 现在**没有了**，
##   42 张卡全部可用。留这个常量是为了以后加新子系统时继续用同一套门禁。
const CARD_UNSUPPORTED: Array = []

## 「按步数」计的效果（原版 Initvar_r.txt 里写「多少步」的项）。
## 每前进 1 格消耗 1 —— 与「按绝对时刻」的 invincible_until / sleep_until 严格区分。
const STEP_EFFECTS := ["no_rent_steps", "rent_double_steps",
	"free_upgrade_steps", "no_upgrade_steps"]

# ---------------------------------------------------------------- 12 个互斥状态
#
# 原版 `FUN_00435f80(this, state, duration)`：**先把 12 个状态标志全部清零，再置位一个**
#   （`this+0x118` 是 12 个 int 的标志数组，`this+0x148` 是同下标的持续量数组）。
#   → 所以原版的这 12 个状态是**天然互斥**的：中一个必然清掉其余 11 个。
#
# **状态编号**（反编译 + 交叉验证，见 `docs/rea-2026-10-16/C05-状态互斥.md`）：
#   1 = 无敌（花仙子写状态 1）· 3 = 糊涂鬼（梦游）· 6 = 小穷神 · 9 = 小财神（免费）
#   11 = 隐形
#   ⚠️ 0 / 2 / 7 / 8 **含义未知**；4 / 5 / 10 没有被 `435f80` 写过。
#
# ⚠️ **不要**把医院 / 酒店 / 休息 / 暴走 / 外星人绑架塞进来 ——
#   10-11 报告明确提醒「医院、宠物等其他系统**不一定**属于这 12 项」，
#   硬塞会引入新错误。
const STATUS_SLOTS := 12

## 我们的字段 → 原版状态号（**只映射已证实的**，其余保持独立）
const STATUS_FIELD := {
	1: "invincible_until",        # 无敌
	3: "sleepwalk_steps",         # 糊涂鬼（梦游）
	6: "rent_pay_double_until",   # 小穷神：收双倍
	9: "no_rent_until",           # 小财神：免费
	11: "invisible_until",        # 隐形
}


## 统一的**状态写入入口** —— 对应原版 `FUN_00435f80`。
## **先把属于这 12 个槽的字段全部清空，再写目标那一个**（这就是原版的「互斥」）。
## `value` 类型按字段而定（绝对时刻用 float，剩余步数用 int）。
func set_status(p: Dictionary, state: int, value) -> void:
	if not STATUS_FIELD.has(state):
		return
	var e: Dictionary = p["effects"]
	for s in STATUS_FIELD:
		e[str(STATUS_FIELD[s])] = 0
	e[str(STATUS_FIELD[state])] = value


## 该玩家当前处于 12 个状态里的哪一个（0 = 没有；返回值是原版状态号）。
## ⚠️ 只认「还生效」的：绝对时刻比 `time`，步数比 0。
func current_status(p: Dictionary) -> int:
	var e: Dictionary = p["effects"]
	for s in STATUS_FIELD:
		var k := str(STATUS_FIELD[s])
		var v: float = float(e.get(k, 0.0))
		if k.ends_with("_until"):
			if v > time:
				return int(s)
		elif v > 0.0:
			return int(s)
	return 0

const PLAYER_COLORS := [
	Color(0.91, 0.16, 0.77),   # 钱夫人 紫
	Color(0.65, 0.47, 0.0),    # 阿土伯 土黄
	Color(0.0, 0.20, 0.69),    # 宫本宝藏 蓝
	Color(1.0, 0.53, 0.0),     # 乌咪 橙
]

var map: MapData = null
var players: Dictionary = {}     # peer_id:int -> Dictionary
var plots: Dictionary = {}       # tile_index:int -> Dictionary {owner, level, type}
var time: float = 0.0
var pending_card_impacts: Array = []
var pending_road_clears: Array = []
var tick_count: int = 0
var running: bool = false
var winner: int = -1

## 街道级地价系数（涨价卡 / 降价卡：Card_ZhangJia_Price / Card_JiangJia_Price = 5 点）。
## key = 街道名，value = 百分点。租金按 (1 + v/100) 计。
var street_index: Dictionary = {}
## 街道查封（查封卡：Card_ChaFeng_Days = 5 天）→ key = 街道名，value = 解封的绝对时刻
var street_seal: Dictionary = {}
## 路面道具（地雷卡 / 路障卡）→ [{idx, kind, owner}]
var obstacles: Array = []

## ---- 路边物体（原版 roadobj）----
## 与上面的 `obstacles` 分开：`obstacles` 是**玩家用卡放的陷阱**（有 owner、会挡路），
## 这里是**系统按天数随机撒的道具**（踩到即触发）。
##
## 权威依据两条：
##   ① `config/scene/<map>/<map>.txt` 的「路面物体出现几率」段（13 种，逐图权重不同，
##      -1 = 本图不随机生成）—— 各图**注释顺序完全一致**，已进 `game/data/maps/*.json`；
##   ② `config/Initvar_r.txt` 的 Crystal_Born_Days / Box_Born_Days / PetEgg_Born_Days。
##
## 效果数值来自**定点逆向** `tools/r6_re.py`（2026-09-26）：
##   路面物体的注册表就在 `0x431690` 这个函数里 —— 13 个名字的压栈顺序与 Aiji.txt 的
##   注释顺序**逐项一致**，紧跟其后是 13 个效果回调的函数指针（0x431120 起）。
##   已还原的公式（见 `game/data/rules/realtime.json` 的 `road` 段）：
##     · 小偷 = rand(1..10)% 现金           （0x4313d0）
##     · 宝箱 = rand(10..20)% × 全体平均现金，下限 1000（0x431220）
##     · 戒指 = 有小神仙且等级 < 4 → 升一级；否则「什么也没发生」（0x431170）
var road_objs: Dictionary = {}           # tile_index -> {"kind": String, "born": int}
var road_day: int = 0                    # 已经过的整天数
var _road_last_day: Dictionary = {}      # kind -> 上次生成它的天数（用于周期节流）

## 棋盘上同时存在的路边物体上限。原版没有这一项 —— 我们加的，免得撒满整盘。
const ROAD_MAX_ON_BOARD := 12

var rng := RandomNumberGenerator.new()

func setup(m: MapData, seed_val: int = 0) -> void:
	map = m
	initial_company_assets = 0
	land_factors.clear()
	_environment_signature.clear()
	economy_factors = {"industry": 1.0, "shop": 1.0, "uptown": 1.0}
	pending_card_impacts.clear()
	pending_road_clears.clear()
	if seed_val == 0:
		rng.randomize()
	else:
		rng.seed = seed_val
	_load_pets()
	_init_virtual_companies()       # 地图的 6 家虚拟公司上市（玩家公司由 add_player 建）


# ------------------------------------------------------------ 小神仙（精灵）数据

## 权威来源：`config/Pet.txt`（9 只 × 4 级的即时制秒数 / 回合制次数 / 消耗点数）
## + `config/String.txt` 2201..2209（技能名）+ `config/Info.txt` 202（持有上限 5 位）。
## 由 `tools/build_pet_data.py` 编译成 `res://data/rules/pets.json`。
const PET_DATA_PATH := "res://data/rules/pets.json"
const PET_SHOP_PRICE_PATH := "res://data/rules/pet_shop_prices.json"

var pets_data: Dictionary = {}
var _pet_index: Dictionary = {}          # id -> 该只的 record


func _load_pets() -> void:
	if not FileAccess.file_exists(PET_DATA_PATH):
		push_warning("[Sim] 缺少 %s —— 先跑 tools/build_pet_data.py" % PET_DATA_PATH)
		return
	var f := FileAccess.open(PET_DATA_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		pets_data = parsed
		_pet_index.clear()
		for r in pets_data.get("pets", []):
			_pet_index[str((r as Dictionary).get("id", ""))] = r
		if FileAccess.file_exists(PET_SHOP_PRICE_PATH):
			var prices: Variant = JSON.parse_string(FileAccess.get_file_as_string(PET_SHOP_PRICE_PATH))
			if prices is Dictionary:
				for pet_id in prices:
					if _pet_index.has(str(pet_id)) and (prices[pet_id] is float or prices[pet_id] is int):
						(_pet_index[str(pet_id)] as Dictionary)["buy_price"] = maxi(0, int(prices[pet_id]))


## 全部 9 只（精灵屋货架 / 持有面板都读它）
func pet_catalog() -> Array:
	return pets_data.get("pets", [])


func pet_record(pet_id: String) -> Dictionary:
	var r: Variant = _pet_index.get(pet_id, {})
	return r if r is Dictionary else {}


func pet_name(pet_id: String) -> String:
	return str(pet_record(pet_id).get("name", pet_id))


## 技能名（String.txt 2201..2209 的原文，例如「穷神技  罚金加倍」）
func pet_skill(pet_id: String) -> String:
	return str(pet_record(pet_id).get("skill_raw", ""))


## 持有上限。`Info.txt` 202 原文：「您已拥有5位小神仙，此时不能请神！」
func max_pets() -> int:
	return int(pets_data.get("max_owned", 5))


## 第 level 级的某个字段（level 从 1 开始；越界自动 clamp）→ 1 级 = 下标 0
func _pet_val(pet_id: String, key: String, level: int) -> float:
	var arr: Array = pet_record(pet_id).get(key, [])
	if arr.is_empty():
		return 0.0
	var i := clampi(level - 1, 0, arr.size() - 1)
	return float(arr[i])


## 请神购买价（点券），与技能消耗分开；优先读可编辑的 pet_shop_prices.json。
## 七只已有原版截图或玩家实测，两只仍待核对。
func pet_price(pet_id: String) -> int:
	return int(pet_record(pet_id).get("buy_price", 0))


## 特技持续时间（秒，即时制第 ① 行）
func pet_seconds(pet_id: String, level: int) -> float:
	return _pet_val(pet_id, "seconds", level)


## 发动一次消耗的宠物内部能量（435910 / 432bf0），不是玩家点券。
func pet_cost(pet_id: String, level: int) -> int:
	return int(_pet_val(pet_id, "points", level))


# ------------------------------------------------------- 持有 / 增减（都是字典表）

## p["pets"] 里每项 = {"id": 小神仙 id, "level": 1..4, "cool": 下次可发动的绝对时刻}
func pet_index_of(p: Dictionary, pet_id: String) -> int:
	var arr: Array = p.get("pets", [])
	for i in range(arr.size()):
		if pet_token(arr[i]) == pet_id or str((arr[i] as Dictionary).get("id", "")) == pet_id:
			return i
	return -1


func has_pet(p: Dictionary, pet_id: String) -> bool:
	return pet_index_of(p, pet_id) >= 0


func pet_count(p: Dictionary) -> int:
	return (p.get("pets", []) as Array).size()


## 加一只（已持有则升级一级）。返回 0 = 成功，否则返回失败原因码：
##   1 = 已达上限（Info.txt 202）、2 = 未知 id
func add_pet(p: Dictionary, pet_id: String) -> int:
	if pet_record(pet_id).is_empty():
		return 2
	var i := pet_index_of(p, pet_id)
	if i >= 0:
		var e: Dictionary = (p["pets"] as Array)[i]
		var mx := maxi((pet_record(pet_id).get("seconds", []) as Array).size(), 1)
		e["level"] = mini(int(e.get("level", 1)) + 1, mx)
		log_message.emit("%s 的 %s 升到 %d 级" % [
			p["name"], pet_name(pet_id), int(e["level"])])
		_ev("pet_levelup", p, {"pet": pet_id, "level": int(e["level"])})
		return 0
	if pet_count(p) >= max_pets():
		_ev("pet_full", p, {"pet": pet_id, "max": max_pets()})
		log_message.emit("%s 已经拥有 %d 位小神仙，不能再请了" % [p["name"], max_pets()])
		return 1
	# Newly acquired pets have enough energy to stay, but still need feeding
	# before their first skill. Hunger eventually makes them leave.
	var added := {"id": pet_id, "level": 1, "growth": 0,
		"uid": "%s:%s:%s:%s" % [p.id, pet_id, tick_count, p.get("pet_serial", 0)]}
	p["pet_serial"] = int(p.get("pet_serial", 0)) + 1
	_set_pet_energy(added, float(int(pet_max_energy(added)) * 5 / 10))
	(p["pets"] as Array).append(added)
	if str(p.get("pet_active", "")) in ["", "none"]:
		p["pet_active"] = pet_token(added)        # 第一只自动「出战」（面板与世界跟随强调显示）
	log_message.emit("%s 得到小神仙「%s」" % [p["name"], pet_name(pet_id)])
	_ev("get_pet", p, {"pet": pet_id, "name": pet_name(pet_id)})
	return 0


## 设「出战」的小神仙（原版：点角色面板的精灵栏位打开**仓库**，在里面选一只使用）。
##
## 用户确认：同时只有选中的一只精灵跟随并发动技能；其他精灵保留在背包。
func act_set_active_pet(id: int, pet_id: String) -> bool:
	var p: Dictionary = players.get(id, {})
	if p.is_empty():
		return false
	if pet_index_of(p, pet_id) < 0:
		return false
	var selected: Dictionary = p.pets[pet_index_of(p, pet_id)]
	p["pet_active"] = pet_token(selected)
	pet_id = str(selected.id)
	log_message.emit("%s 把「%s」设为出战" % [p["name"], pet_name(pet_id)])
	_ev("pet_active", p, {"pet": pet_id, "name": pet_name(pet_id)})
	return true

func act_release_pet(id: int, pet_id: String) -> bool:
	var p: Dictionary = players.get(id, {})
	if p.is_empty(): return false
	var index := pet_index_of(p, pet_id)
	if index < 0: return false
	var released: Dictionary = p.pets[index]
	var was_active := pet_token(active_pet(p)) == pet_token(released)
	(p.pets as Array).remove_at(index)
	if was_active: p["pet_active"] = "none"
	pet_id = str(released.id)
	log_message.emit("%s 放生了「%s」" % [p.name, pet_name(pet_id)])
	_ev("pet_released", p, {"pet": pet_id, "pet_name": pet_name(pet_id)})
	return true


## 当前出战的小神仙（没设过就取第一只；一只都没有返回空字典）
func pet_token(pet: Dictionary) -> String:
	return str(pet.get("uid", pet.get("id", "")))

func active_pet(p: Dictionary) -> Dictionary:
	var pets: Array = p.get("pets", [])
	var want := str(p.get("pet_active", ""))
	if want == "none": return {}
	for e in pets:
		if pet_token(e) == want or str(e.get("id", "")) == want: return e
	return pets[0] if not pets.is_empty() else {}


func act_buy_pet(id: int, pet_id: String) -> bool:
	var p: Dictionary = players.get(id, {})
	if p.is_empty() or not bool(p["alive"]):
		return false
	if pet_record(pet_id).is_empty():
		return false
	var shelf: Array = p.get("pet_shop_stock", [])
	if bool(p.get("pet_shop_open", false)) and not shelf.has(pet_id):
		_ev("pet_shop_refused", p, {"pet": pet_id, "reason": "这只小神仙已售出"})
		return false
	var price := pet_price(pet_id)
	if int(p["credit"]) < price:
		log_message.emit("%s 的点券不够（%d/%d），买不了%s" % [
			p["name"], int(p["credit"]), price, pet_name(pet_id)])
		_ev("pet_shop_refused", p, {"pet": pet_id, "need": price, "have": int(p["credit"])})
		return false
	if pet_count(p) >= max_pets() and not has_pet(p, pet_id):
		_ev("pet_full", p, {"pet": pet_id, "max": max_pets()})
		return false
	p["credit"] = int(p["credit"]) - price
	add_pet(p, pet_id)
	if bool(p.get("pet_shop_open", false)):
		shelf[shelf.find(pet_id)] = ""       # 保留空货位，其他头像不挪位
	log_message.emit("%s 花 %d 点券请到「%s」" % [p["name"], price, pet_name(pet_id)])
	_ev("buy_pet", p, {"pet": pet_id, "price": price, "stock": shelf.duplicate()})
	return true

func _new_pet_shop_stock() -> Array:
	var ids: Array = []
	for record in pet_catalog():
		ids.append(str((record as Dictionary).get("id", "")))
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = ids[i]
		ids[i] = ids[j]
		ids[j] = swap
	return ids.slice(0, 4)


# ------------------------------------------------------- 卡片商店（用点券买卡）

## 卡片商店售价（点券）。
## ⚠ **推断**：原版配置里**没有卡片价格表** —— 卡面左上角的徽章数字（`Rules.card_badge`，
## 1..5）是卡面上唯一的数字，取「徽章 × 10」＝ 10..50 点券，与点券收入的量级
## （点券格 5/10/20/30/50、游戏点 1~50、市政府表扬 100）吻合。
## 依据与不确定项见 `docs/alignment-gap.md` / `docs/decision-log.md §16`。
const CARD_PRICE_PER_BADGE := 10

func card_price(card_id: String) -> int:
	return maxi(Rules.card_badge(card_id), 1) * CARD_PRICE_PER_BADGE


## 货架上摆哪 8 张（原版 `uitex/other/cardshop.tga` 是 2 列 × 4 行 = 8 格）
const CARD_SHOP_SLOTS := 8
## 兼容旧存档的货架；正常到访货架保存在各玩家 card_shop_stock 中。
var card_shop_stock: Array = []
var card_shop_initialized := false


func _shop_stock(pid: int = 1) -> Array:
	var p: Dictionary = players.get(pid, {})
	if p.has("card_shop_stock"): return (p.card_shop_stock as Array).duplicate()
	# 同次到访反复查询不刷新；原版每次抵达时才抽取新货架。
	if not card_shop_initialized and card_shop_stock.is_empty():
		refill_card_shop()
	card_shop_initialized = true
	return card_shop_stock.duplicate()


## 原版 439530 -> 41ee60：每次抵达取八张普通卡，同次售完不补。
func refill_card_shop() -> void:
	card_shop_initialized = true
	var all: Array = Rules.cards()
	var ids: Array = []
	for c in all.slice(0, 40): # 41ee60 -> 41ed50(-1): original indices0..39.
		ids.append(str(c.get("id", "")))
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = ids[i]
		ids[i] = ids[j]
		ids[j] = swap
	card_shop_stock = ids.slice(0, mini(CARD_SHOP_SLOTS, ids.size()))


func act_buy_card(id: int, card_id: String) -> bool:
	## 卡片商店购买（Info.txt 41「卡片商店 您有<NUMBER>点券」/ 42 点券不够不能进）
	var p: Dictionary = players.get(id, {})
	if p.is_empty() or not bool(p["alive"]):
		return false
	if Rules.card_by_id(card_id).is_empty():
		return false
	if not _shop_stock(id).has(card_id):
		return false
	var price := card_price(card_id)
	if int(p["credit"]) < price:
		_ev("cardshop_refused", p, {"card": card_id, "need": price, "have": int(p["credit"])})
		log_message.emit("%s 点券不够（%d/%d），买不了「%s」" % [
			p["name"], int(p["credit"]), price, Rules.card_name(card_id)])
		return false
	p["credit"] = int(p["credit"]) - price
	var res := _push_card(p, card_id)
	if not bool(res["added"]):
		# 全锁着 → 买不进来，钱退回去
		p["credit"] = int(p["credit"]) + price
		_ev("hand_full", p, {"card": card_id})
		log_message.emit("%s 的卡片栏满了（全锁着），买不下「%s」" % [
			p["name"], Rules.card_name(card_id)])
		return false
	_report_card_push(p, res, Rules.card_name(card_id))
	# ⭐ 买走 → **从货架上移除**（老板 2026-09-27；不然可以对着同一格反复买）
	if p.has("card_shop_stock"):
		p.card_shop_stock[(p.card_shop_stock as Array).find(card_id)] = ""
	else:
		card_shop_stock.erase(card_id)
	log_message.emit("%s 花 %d 点券买下「%s」（货架剩 %d 张）" % [p["name"], price,
		Rules.card_name(card_id), _shop_stock(id).size()])
	_ev("buy_card", p, {"card": card_id, "name": Rules.card_name(card_id), "price": price})
	return true


# ------------------------------------------------------------ 小神仙特技结算

func _random_other(p: Dictionary) -> Dictionary:
	## 随机挑一个「还活着、不是自己」的对手（特技的施加对象）
	var cand: Array = []
	for oid in player_ids():
		var q: Dictionary = players[oid]
		if int(oid) != int(p["id"]) and bool(q["alive"]):
			cand.append(q)
	if cand.is_empty():
		return {}
	return cand[rng.randi_range(0, cand.size() - 1)]


## Skills are manually triggered at full energy. Pet.txt seconds describe the
## effect duration; there is no cooldown between skills once fed again.
func _tick_pets(_p: Dictionary) -> void:
	# Skills are released by the player; merely arriving must not consume a
	# full energy bar before the visible skill button can be pressed.
	pass

func pet_skill_candidates(id: int) -> Array:
	var p: Dictionary = players.get(id, {})
	var result: Array = []
	if p.is_empty(): return result
	for oid in player_ids():
		if int(oid) == id: continue
		var q: Dictionary = players[oid]
		if bool(q.get("alive", false)) and _tile_distance(int(p.tile), int(q.tile)) <= 2:
			result.append(int(oid))
	return result

func pet_skill_block_reason(id: int) -> String:
	var p: Dictionary = players.get(id, {})
	if time < float(p.get("entry_until", 0.0)): return "角色正在乘降落伞入场"
	if p.is_empty() or not bool(p.get("alive", false)): return "角色当前无法行动"
	if time < float(p.effects.get("hospital_until", 0.0)): return "住院期间不能发动技能"
	if time < float(p.effects.get("hotel_until", 0.0)): return "酒店住宿期间不能发动技能"
	if time < float(p.effects.get("sleep_until", 0.0)): return "睡眠期间不能发动技能"
	var pet := active_pet(p)
	if pet.is_empty(): return "没有出战的小神仙"
	if not pet_skill_ready(pet): return "饱食度不足：%d/100，请从手牌菜单喂食" % int(pet.get("fullness", 0.0))

	return ""

func act_pet_skill(id: int, feedback := true, target: int = -1) -> bool:
	var p: Dictionary = players.get(id, {})
	var reason := pet_skill_block_reason(id)
	if reason == "":
		var pet := active_pet(p)
		var pet_id := str(pet.id)
		var level := int(pet.level)
		if pet_id in ["hutu", "qiongshen"] and target < 0:
			if feedback: _ev("need_pet_target", p, {"pet": pet_id, "candidates": pet_skill_candidates(id)})
			return false
		if _pet_apply(p, pet_id, level, target):
			var cost := pet_cost(pet_id, level)
			_set_pet_energy(pet, pet_energy(pet) - float(cost))
			pet.skill_at = time
			log_message.emit("%s 发动%s，消耗%d能量" % [pet_name(pet_id), pet_skill(pet_id), cost])
			_ev("pet_skill", p, {"pet": pet_id, "name": pet_name(pet_id), "level": level,
				"skill": pet_skill(pet_id), "effect": str(pet_record(pet_id).get("effect", "")),
				"cost": cost, "seconds": pet_seconds(pet_id, level), "credit": int(p.credit)})
			return true
		else: reason = "当前没有符合条件的技能目标，能量已保留"
	if feedback: _ev("pet_skill_refused", p if not p.is_empty() else null, {"reason": reason})
	return false


## 真正施加特技。返回 false = 条件不满足（不消耗）。
func _pet_apply(p: Dictionary, pet_id: String, lv: int, target: int = -1) -> bool:
	var secs := pet_seconds(pet_id, lv)
	var eff := str(pet_record(pet_id).get("effect", ""))
	var here := int(p["tile"])
	var me := int(p["id"])
	match eff:
		# 小财神「免费技 免付房租」（String.txt 2204 / Info.txt 194）
		"free_rent":
			_clear_attached_gods(p)
			# 原版状态 9（见 set_status 注释）—— 走统一入口：写它就清掉其余 11 个状态
			set_status(p, 9, time + secs)
			log_message.emit("%s 的小财神显灵：%.0f 秒内免付租金" % [p["name"], secs])
		# 小穷神「穷神技 罚金加倍」（2201 / Info.txt 191）
		"curse_rent_double":
			var t: Dictionary = players.get(target, {})
			if not pet_skill_candidates(me).has(target) or _protected(t):
				return false
			_clear_attached_gods(t)
			set_status(t, 6, time + secs)   # 原版状态 6（小穷神）
			log_message.emit("%s 的小穷神附上 %s：%.0f 秒内罚金加倍" % [p["name"], t["name"], secs])
			_ev("pet_curse", t, {"pet": pet_id, "from": me, "seconds": secs})
		# 糊涂鬼：选择一位附近对手，让电脑接管指定步数。
		"sleep_nearby":
			if not pet_skill_candidates(me).has(target): return false
			var q: Dictionary = players[target]
			if _protected(q): return false
			_clear_attached_gods(q)
			q["moving"] = 0
			q["progress"] = 0.0
			var steps := int((pet_record(pet_id).get("turn_times", []) as Array)[clampi(lv - 1, 0, 3)])
			# 原版状态 3（糊涂鬼）。⚠️ 原版是 **覆盖**（先清空 12 个再写入），
			# 而这里原来是 `maxi(已有, steps)` 取较大值 —— 改成覆盖，与 435f80 一致。
			set_status(q, 3, steps)
			_clear_chance(q)
			log_message.emit("%s 的糊涂鬼让 %s 梦游 %d 步" % [p.name, q.name, steps])
			_ev("sleepwalk", q, {"pet": pet_id, "by": me, "steps": steps})
		# 小恶魔「拆除技 拆除房屋」（2203 / Info.txt 193）
		"demolish_enemy":
			var ei := here
			if not plots.has(ei) or int(plots[ei]["level"]) <= 0:
				return false
			for _i in range(int(secs)):
				if int(plots[ei].level) > 0: _downgrade_estate(ei)
			log_message.emit("%s 的小恶魔把 %s 拆除 %d 级" % [p["name"], map.street_of(ei), int(secs)])
			_ev("downgrade", p, {"idx": ei, "level": int(plots[ei]["level"]),
				"street": map.street_of(ei), "pet": pet_id})
		# 小土神「土神技 强制占地」（2205 / Info.txt 196）
		"seize_enemy_plot":
			var si := here
			if not plots.has(si) or int(plots[si].owner) == me or (int(plots[si].level) > 0 and Rules.house_footprint(Rules.house_file(str(plots[si].type), int(plots[si].level))) > int(secs)):
				return false
			var old := int(plots[si]["owner"])
			plots[si]["owner"] = me
			log_message.emit("%s 的小土神强占了 %s（原属 %s）" % [
				p["name"], map.street_of(si), _owner_name(old)])
			_ev("own_plot", p, {"idx": si, "street": map.street_of(si),
				"from": old, "pet": pet_id})
		# 雪精灵「加盖技 升级房屋」（2206）
		"free_upgrade":
			var ui := here
			if not plots.has(ui) or int(plots[ui].level) <= 0: return false
			var owner := int(plots[ui].owner)
			if not force_upgrade(owner, ui, true): return false
			for _i in range(1, int(secs)): force_upgrade(owner, ui, true)
			log_message.emit("%s 的雪精灵为 %s 加盖最多 %d 级" % [p["name"], map.street_of(ui), int(secs)])
		# 花仙子「无敌技 无敌状态」（2207）
		"invincible":
			_clear_attached_gods(p)
			set_status(p, 1, time + secs)   # 原版状态 1（无敌）
			log_message.emit("%s 的花仙子让主人无敌 %.0f 秒" % [p["name"], secs])
		# 小赌神「骰子技 遥控骰子」（2208）—— 只备一次，掷骰时消费
		"max_dice":
			if bool(p.get("pending_steps", false)) or int(p.get("moving", 0)) > 0: return false
			p["pending_steps"] = true
			p["pending_steps_source"] = "dushen"
			_clear_chance(p)
			_ev("card_choose_steps", p, {"pet": pet_id})
		# 小怪兽「PK技 攻击小神仙」（2209 / Info.txt 195）
		"attack_pet":
			for other_id in player_ids():
				var other: Dictionary = players[other_id]
				# Native query parameter is 6. Its road-distance conversion
				# remains provisional until the selector unit is established.
				if int(other_id) == me or not bool(other.alive) or _protected(other): continue
				if _tile_distance(here, int(other.tile)) > 6: continue
				var victim := active_pet(other)
				if victim.is_empty() or str(victim.id) == "guaishou": continue
				var damage := int(pet_max_energy(victim) * float(secs) / 100.0)
				if int(victim.level) == 4: damage = int(damage * 80 / 100)
				_set_pet_energy(victim, pet_energy(victim) - float(damage))
				_ev("pet_attacked", other, {"pet": str(victim.id), "from": me, "damage": damage,
					"voice_line": 8 if pet_energy(victim) <= 0.0 else 6})
				if pet_energy(victim) <= 0.0: _pet_leave(other, victim, "attack")

		_:
			return false
	return true

# ------------------------------------------------------------ 股票 / 公司

## 「公司」怎么来（依据逐条可查）：
##   · **玩家公司** —— 每个玩家以自己的「缺省公司」上市，公司名 = `config/Role.txt`
##     第 6 列（钱夫人=钻石集团、阿土伯=新土地、宫本宝藏=第一宝藏、乌咪=玛雅、
##     孙小美=中华美食 …）。老板 2026-09-26 的原版股票截图（`docs/screenshots/orig/records/`）
##     上那前四家**逐字对上**，而且那一局玩家是孙小美、持股 **2000** ——
##     正好 = `Initvar_r.txt` 的 `Player_Com_SelfShares = 2000`。
##   · **虚拟公司** —— 每图另有 6 家（`config/scene/<map>/<map>.txt`）→ `maps/*.json`。
##
## 一条行情：`{name, owner(>=0 玩家 / -1 虚拟), price, prev, shares, chairman}`
var stocks: Dictionary = {}
## 甲6「股市暂停交易 N 天」—— 到这个 `road_day` 之前不刷新股价
var stock_closed_until_day := 0


func _stock_cfg(key: String, dflt):
	return Rules.get_val("economy.stock." + key, dflt)


func stock_price(comp: String) -> float:
	return float((stocks.get(comp, {}) as Dictionary).get("price", 0.0))


## 涨跌（%，取整）—— 原版截图里就是 `+7` / `+3` / `0` / `-1` 这种整数
func stock_change(comp: String) -> int:
	var s: Dictionary = stocks.get(comp, {})
	if s.is_empty():
		return 0
	var prev := float(s.get("prev", 0.0))
	if prev <= 0.0:
		return 0
	return int(round((float(s["price"]) - prev) / prev * 100.0))


func holding_of(pid: int, comp: String) -> int:
	var p: Dictionary = players.get(pid, {})
	return int((p.get("holdings", {}) as Dictionary).get(comp, 0))


## 持股比例 0..1
func holding_ratio(pid: int, comp: String) -> float:
	var s: Dictionary = stocks.get(comp, {})
	if s.is_empty():
		return 0.0
	return float(holding_of(pid, comp)) / maxf(float(s.get("shares", 1)), 1.0)


## 建「玩家公司」（`add_player` 时调）
func _init_player_company(p: Dictionary) -> void:
	var cname := Rules.role_company(int(p.get("role", 1)))
	if cname == "":
		return
	var capital := float(Rules.get_val("economy.player_company.init_capital", 500000))
	var total := int(Rules.get_val("economy.player_company.init_total_shares", 10000))
	var self_sh := int(Rules.get_val("economy.player_company.init_self_shares", 2000))
	var unit := capital / maxf(float(total), 1.0)
	stocks[cname] = {
		"name": cname, "owner": int(p["id"]),
		"price": unit, "prev": unit, "shares": total,
		"chairman": -1,
		# 趋势 / 历史价 / 月初价（分红与走势折线用）
		"activity": 20, "trend": 0, "trend_days": 0,
		"history": [unit], "month_start_price": unit,
	}
	var h: Dictionary = p.get("holdings", {})
	h[cname] = int(h.get(cname, 0)) + self_sh
	p["holdings"] = h
	p["company"] = cname
	p["stock_cost_basis"] = {cname: unit * self_sh}


## 建「虚拟公司」（地图配置里的那 6 家）
func _init_virtual_companies() -> void:
	for c in (map.virtual_companies as Array):
		var rec: Dictionary = c
		var nm := str(rec.get("name", ""))
		if nm == "" or stocks.has(nm):
			continue
		var cap := float(rec.get("capital", 300000))
		var tot := int(rec.get("shares", 10000))
		var unit := cap / maxf(float(tot), 1.0)
		stocks[nm] = {
			"name": nm, "owner": -1, "price": unit, "prev": unit,
			"shares": tot, "chairman": -1,
			"activity": 20, "trend": 0, "trend_days": 0,
			"history": [unit], "month_start_price": unit,
		}


## 每天开盘：
##   · **趋势**每 `Stock_Trend_MinTime..MaxTime`（2~9）天重掷一次；取值按**活泼程度**
##     （`Stock_VCom_Bottom/Middle/TopAct_Min/Max`：低 10 天 -50..120 / 中 20 天 -60..180 /
##      高 30 天 -70..300）。玩家公司取「中」。
##   · 股价 = 昨收 × (1 + 随机 ±`Stock_OpenPrice`% + 趋势漂移)
##   · 顺手记一天历史价（走势折线用，最多 60 天）
func _tick_stocks() -> void:
	if stocks.is_empty():
		return
	# 甲6「股市暂停交易 N 天」：停牌期内不刷价（只推一条平盘历史）
	if road_day < stock_closed_until_day:
		for nm in stocks.keys():
			var s0: Dictionary = stocks[nm]
			var hist0: Array = s0.get("hist", [])
			hist0.append(float(s0["price"]))
			if hist0.size() > 60:
				hist0.pop_front()
			s0["hist"] = hist0
		return
	var lo := float(_stock_cfg("open_price_min_pct", -10)) / 100.0
	var hi := float(_stock_cfg("open_price_max_pct", 10)) / 100.0
	var tmin := int(_stock_cfg("trend_change_days_min", 2))
	var tmax := int(_stock_cfg("trend_change_days_max", 9))
	for nm in stocks.keys():
		var s: Dictionary = stocks[nm]
		# ---- 趋势 ----
		s["trend_days"] = int(s.get("trend_days", 0)) - 1
		if int(s["trend_days"]) <= 0:
			var act := int(s.get("activity", 20))
			var tlo := -60
			var thi := 180
			if act <= 10:
				tlo = -50
				thi = 120
			elif act >= 30:
				tlo = -70
				thi = 300
			s["trend"] = rng.randi_range(tlo, thi)
			s["trend_days"] = rng.randi_range(tmin, tmax)
		# ---- 价格 ----
		s["prev"] = float(s["price"])
		var bias := clampf(float(s.get("trend", 0)) / 300.0, -1.0, 1.0) * 0.5
		var k := rng.randf_range(lo, hi) + (hi - lo) * bias * 0.5
		s["price"] = maxf(0.1, float(s["price"]) * (1.0 + k))
		var hist: Array = s.get("history", [])
		hist.append(float(s["price"]))
		while hist.size() > 60:
			hist.pop_front()
		s["history"] = hist
		_ev("stock_tick", null, {"company": str(nm), "price": float(s["price"]),
			"prev": float(s["prev"]), "change": stock_change(str(nm)),
			"trend": int(s.get("trend", 0))})


## 分红（原版 `Initvar_r.txt`）：
##   · **虚拟公司** = 总资产 × rand(`Stock_VCom_Bonus_Min`..`Max`)（0 ~ 0.5）
##   · **玩家公司** = **上月利润** × `Stock_PCom_Bonus`（0.3）
##
## ⚠️ 「玩家公司的利润」原版没写怎么算 → 取「这一个月里股价涨幅 × 总股数」，登记为推断。
const MONTH_DAYS := 30

static func calendar_at_day(elapsed_days: int) -> Dictionary:
	var days := maxi(0, elapsed_days)
	return {"day": days % MONTH_DAYS + 1, "month": (days / MONTH_DAYS) % 12 + 1,
		"year": days / (MONTH_DAYS * 12) + 1}


func _pay_dividends() -> void:
	for nm in stocks.keys():
		var s: Dictionary = stocks[nm]
		var tot := maxf(float(s.get("shares", 1)), 1.0)
		var pool := 0.0
		if int(s.get("owner", -1)) >= 0:
			var start := float(s.get("month_start_price", s.get("price", 0.0)))
			var profit := (float(s["price"]) - start) * tot
			pool = maxf(profit, 0.0) * float(_stock_cfg("player_company_bonus_rate", 0.3))
			s["month_start_price"] = float(s["price"])
		else:
			pool = float(s["price"]) * tot * rng.randf_range(
				float(_stock_cfg("virtual_company_bonus_min", 0.0)),
				float(_stock_cfg("virtual_company_bonus_max", 0.5)))
		if pool <= 0.5:
			continue
		var per := pool / tot
		for pid in player_ids():
			var sh := holding_of(int(pid), str(nm))
			if sh <= 0:
				continue
			var got := int(round(per * float(sh)))
			if got > 0:
				players[pid]["money"] = int(players[pid]["money"]) + got
				_ev("dividend", players[pid], {"company": str(nm), "amount": got,
					"shares": sh, "player": int(pid)})
		log_message.emit("%s 分红：每股 %.2f 元" % [str(nm), per])


## 走势的历史价（折线图用）
func stock_history(comp: String) -> Array:
	return (stocks.get(comp, {}) as Dictionary).get("history", [])


## 股东名单（持股从多到少）→ [{pid, name, shares, ratio, chairman}]
func stockholders(comp: String) -> Array:
	var out: Array = []
	var tot := maxf(float((stocks.get(comp, {}) as Dictionary).get("shares", 1)), 1.0)
	for pid in player_ids():
		var sh := holding_of(int(pid), comp)
		if sh <= 0:
			continue
		out.append({"pid": int(pid), "name": str(players[pid]["name"]), "shares": sh,
			"ratio": float(sh) / tot, "chairman": is_chairman(int(pid), comp)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["shares"]) > int(b["shares"]))
	return out


## 手续费率（`Stock_Handle_Charge = 0.01`：买卖一笔按交易额的 1%）
func stock_charge_rate() -> float:
	return float(_stock_cfg("handle_charge_rate", 0.01))


## 买进 N 股：股款 = 当前价 × 股数，另外收手续费
func act_buy_stock(id: int, comp: String, shares: int) -> bool:
	var p: Dictionary = players.get(id, {})
	if p.is_empty() or not bool(p["alive"]) or shares <= 0 or not stocks.has(comp):
		return false
	if road_day < stock_closed_until_day:
		_ev("stock_closed", p, {"days": stock_closed_until_day - road_day})
		return false
	var price := stock_price(comp)
	var cost := int(ceil(price * float(shares)))
	var fee := int(ceil(float(cost) * stock_charge_rate()))
	var need := cost + fee
	if int(p["money"]) < need:
		_ev("insufficient_money", p, {"need": need, "have": int(p["money"])})
		return false
	p["money"] = int(p["money"]) - need
	var h: Dictionary = p.get("holdings", {})
	var basis: Dictionary = p.get("stock_cost_basis", {})
	# An old save without historical costs must not report an invented average.
	if basis.has(comp) or int(h.get(comp, 0)) == 0:
		basis[comp] = float(basis.get(comp, 0.0)) + cost
	p["stock_cost_basis"] = basis
	h[comp] = int(h.get(comp, 0)) + shares
	p["holdings"] = h
	log_message.emit("%s 买进 %s %d 股（%.1f 元 × %d = %d 元，手续费 %d）" % [
		p["name"], comp, shares, price, shares, cost, fee])
	_ev("stock_buy", p, {"company": comp, "shares": shares, "price": price,
		"cost": cost, "fee": fee})
	_check_chairman(p, comp)
	return true


## 卖出 N 股（按当前价，扣手续费）
func act_sell_stock(id: int, comp: String, shares: int) -> bool:
	var p: Dictionary = players.get(id, {})
	if p.is_empty() or shares <= 0 or not stocks.has(comp):
		return false
	if road_day < stock_closed_until_day:
		_ev("stock_closed", p, {"days": stock_closed_until_day - road_day})
		return false
	shares = mini(shares, holding_of(id, comp))
	if shares <= 0:
		_ev("stock_no_holding", p, {"company": comp})
		return false
	var price := stock_price(comp)
	var gross := int(price * float(shares))
	var fee := int(ceil(float(gross) * stock_charge_rate()))
	p["money"] = int(p["money"]) + gross - fee
	var h: Dictionary = p.get("holdings", {})
	var basis: Dictionary = p.get("stock_cost_basis", {})
	if basis.has(comp): basis[comp] = float(basis[comp]) * float(int(h.get(comp, 0)) - shares) / maxi(1, int(h.get(comp, 0)))
	p["stock_cost_basis"] = basis
	h[comp] = int(h.get(comp, 0)) - shares
	p["holdings"] = h
	log_message.emit("%s 卖出 %s %d 股（得 %d 元，手续费 %d）" % [
		p["name"], comp, shares, gross - fee, fee])
	_ev("stock_sell", p, {"company": comp, "shares": shares, "price": price,
		"gain": gross - fee, "fee": fee})
	_check_chairman(p, comp)
	return true


## 持股 ≥60% = 该公司**董事长**（`Info.txt` 131..135；进自家公司土地免租）
func _check_chairman(p: Dictionary, comp: String) -> void:
	var s: Dictionary = stocks.get(comp, {})
	if s.is_empty():
		return
	var ratio := holding_ratio(int(p["id"]), comp)
	var is_ch := ratio >= 0.6
	var cur := int(s.get("chairman", -1))
	if is_ch and cur != int(p["id"]):
		s["chairman"] = int(p["id"])
		_ev("chairman", p, {"company": comp, "on": true, "ratio": ratio})
		log_message.emit("%s 成为 %s 公司董事长（持股 %.0f%%）" % [
			p["name"], comp, ratio * 100.0])
	elif not is_ch and cur == int(p["id"]):
		s["chairman"] = -1
		_ev("chairman", p, {"company": comp, "on": false, "ratio": ratio})
		log_message.emit("%s 持股低于 60%%，不再是 %s 公司董事长" % [p["name"], comp])


func is_chairman(pid: int, comp: String) -> bool:
	return int((stocks.get(comp, {}) as Dictionary).get("chairman", -1)) == pid


## 面板显示顺序：玩家公司在前、虚拟公司在后（各自按名字排序）
func stock_names() -> Array:
	var own: Array = []
	var virt: Array = []
	for nm in stocks.keys():
		if int((stocks[nm] as Dictionary).get("owner", -1)) >= 0:
			own.append(str(nm))
		else:
			virt.append(str(nm))
	own.sort()
	virt.sort()
	return own + virt


## 红卡 / 黑卡：把**某一种股票**的价格抬 / 压 `ratio`（原版 = ±20%）。
## 返回 false = 没生效（公司名不认识）→ 卡片保留、不消耗。
func _shift_stock(comp: String, ratio: float, p: Dictionary, card_id: String) -> bool:
	if comp == "" or not stocks.has(comp):
		return false
	var s: Dictionary = stocks[comp]
	var old := float(s["price"])
	var now := maxf(0.1, old * (1.0 + ratio))
	s["price"] = now
	s["prev"] = old                  # 让面板上的「%」立刻反映这次操作
	log_message.emit("%s 用「%s」把 %s 的股价 %.1f → %.1f（%+.0f%%）" % [
		p["name"], Rules.card_name(card_id), comp, old, now, ratio * 100.0])
	_ev("stock_shift", p, {"company": comp, "from": old, "to": now,
		"ratio": ratio, "card": card_id})
	return true


## 聊天（原版右下角「聊天」按钮弹出的那个栏：含**公共**频道与**私聊**）
func act_chat(id: int, text: String, to: int, channel: String) -> bool:
	var p: Dictionary = players.get(id, {})
	if p.is_empty():
		return false
	var txt := text.strip_edges()
	if txt == "":
		return false
	txt = txt.substr(0, 60)                      # 限长，防刷屏
	var payload := {"from": int(id), "name": str(p["name"]), "text": txt,
		"channel": channel, "to": to}
	if to >= 0 and players.has(to) and to != id:
		# 私聊：只发给双方
		_ev("chat", players[to], payload)
		_ev("chat", p, payload)
	else:
		payload["channel"] = "公共"
		payload["to"] = -1
		# ⚠️ 公共频道**只发一次事件**。
		#   原来写成「对每个玩家各 `_ev` 一次」→ UI 收到 N 次就**把同一句刷 N 遍**
		#   （老板 2026-09-27：「我发一句，公屏上会一下次出现三句同样的话」——4 人局就是 4 遍）。
		_ev("chat", null, payload)
	log_message.emit("[聊天] %s: %s" % [p["name"], txt])
	return true


## 全局新闻（`Info.txt` 甲1..甲14 = id 3001..3014，标签 `"NEWS"`；
## 效果参数 = `realtime.json` 的 `news` 段 14 项，出自 `Initvar_r.txt` 的 `XinWen1..14`）。
##
## ⚠️ **触发频率原版没写**（`tvnews` 事件格是「踩到才播」）；这里取「每 12~20 天一次」，登记为推断。
##
## ⚠️ 插画（`samples/news/01..38.tga`）与事件的**对应关系也没有依据** → 按序号取图。
var news_day := 0


func _maybe_global_news() -> void:
	var period := rng.randi_range(12, 20)
	if road_day < news_day + period:
		return
	news_day = road_day
	_fire_global_news(rng.randi_range(1, 14))


func _news_cfg(key: String, dflt):
	return Rules.get_val("news." + key, dflt)


func _fire_global_news(idx: int) -> void:
	var art := idx                       # 插画序号（无力据，按事件序号取）
	var number := 0
	var road_name := ""
	var changed_land := -1
	match idx:
		1:   # 股市低迷不振，重挫崩盘
			_news_all_stocks(-float(_news_cfg("stock_down", 1.0)))
		2:   # 股市气势如虹，全面上涨
			_news_all_stocks(float(_news_cfg("stock_up", 0.5)))
		8:   # 外来投资增加，地价上涨 N%
			var rise := _random_news_factor("all_price_up", [0.1, 0.3])
			number = int(round(rise * 100.0))
			changed_land = _news_all_plots(1.0 + rise)
		9:   # 外来投资减少，所有地价下跌 N%
			var fall := _random_news_factor("all_price_down", [0.1, 0.2])
			number = int(round(fall * 100.0))
			changed_land = _news_all_plots(1.0 - fall)
		10:  # 政府向每位市民发放一张卡片
			for pid in player_ids():
				_give_random_card(players[pid], "政府")
		3:   # 甲3 专家预测**商业**景气繁荣 → 商业区房租抬高
			var shop_rise := _random_news_factor("shop_rent_up", [0.1, 0.3])
			number = int(round(shop_rise * 100.0))
			_news_type_rent("shop", 1.0 + shop_rise)
		4:   # 甲4 专家预测**工业**景气回升
			var industry_rise := _random_news_factor("industry_price_up", [0.1, 0.3])
			number = int(round(industry_rise * 100.0))
			_news_type_rent("industry", 1.0 + industry_rise)
		5:   # 甲5 专家预测**房地产**买气回升
			var house_rise := _random_news_factor("uptown_price_up", [0.1, 0.3])
			number = int(round(house_rise * 100.0))
			_news_type_rent("uptown", 1.0 + house_rise)
		6:   # 甲6 股市暂停交易 N 天
			var mc: Array = _news_cfg("market_close_days", [1, 5]) as Array
			number = rng.randi_range(int(mc[0]), int(mc[1]))
			stock_closed_until_day = road_day + number
		7:   # 甲7 银行加发存款利息 N％ → 现金按利率生息
			var ir: Array = _news_cfg("interest_rate_pct", [5, 15]) as Array
			var pct := rng.randi_range(int(ir[0]), int(ir[1]))
			number = pct
			for pid2 in player_ids():
				var pp: Dictionary = players[pid2]
				pp["money"] = int(pp["money"]) + int(round(float(pp["money"]) * pct / 100.0))
		11:  # 甲11 发生地震，部分建筑倒塌 → 随机几处房屋降 1 级
			var quake := 0
			var keys: Array = unique_plot_keys()
			keys.shuffle()
			for k in keys:
				if quake >= 3:
					break
				var qp: Dictionary = plots[k]
				if int(qp.get("level", 0)) > 1:
					_downgrade_estate(int(k))
					quake += 1
		12:  # 甲12 近日大雨，<ROAD>地价下跌！
			var streets: Array = []
			for i2 in range(map.tile_count()):
				var st2 := str(map.street_of(i2))
				if st2 != "" and not streets.has(st2):
					streets.append(st2)
			if not streets.is_empty():
				var hit := str(streets[rng.randi_range(0, streets.size() - 1)])
				road_name = hit
				_change_land_factors(-0.1, true, hit)
				log_message.emit("[新闻] 近日大雨，%s 地价下跌！" % hit)
		13:  # ⭐ 甲13 公开拍卖<ROAD>一处公有土地（Info.txt 4001/4002/4003）
			if start_auction(): road_name = map.street_of(int(auction.get("tile", -1)))
		14:  # 甲14 经济萧条，所有租金下降 N％
			var rent_fall := float((_news_cfg("all_price_down", [0.1, 0.2]) as Array)[1])
			number = int(round(rent_fall * 100.0))
			_news_all_rents(1.0 - rent_fall)
		_:
			pass                          # 剩下的只播新闻、不改状态
	var msg := Rules.info_fill(3000 + idx, {"number": str(number), "road": road_name})
	if changed_land == 0:
		msg = "地价已达%s，本次没有变化。" % ("上限" if idx == 8 else "下限")
	log_message.emit("[新闻] %s" % msg.replace("\n", ""))
	_ev("global_news", null, {"idx": idx, "text": msg, "art": art,
		"info_id": 3000 + idx, "changed_land": changed_land, "number": number})


## 新闻「某一类房屋的租金一起涨 / 跌」（甲3/甲4/甲5）
func _random_news_factor(key: String, fallback: Array) -> float:
	var limits: Array = _news_cfg(key, fallback)
	return rng.randf_range(float(limits[0]), float(limits[1]))

func _news_type_rent(type_id: String, ratio: float) -> void:
	# 42fd00/42fd70/42fde0 add to a world factor, including future buildings.
	economy_factors[type_id] = float(economy_factors.get(type_id, 1.0)) + ratio - 1.0


func _news_all_rents(ratio: float) -> void:
	for type_id in economy_factors:
		economy_factors[type_id] = float(economy_factors[type_id]) * ratio


## 新闻「所有股票一起涨 / 跌」
func _news_all_stocks(ratio: float) -> void:
	for nm in stocks.keys():
		var s: Dictionary = stocks[nm]
		var old := float(s["price"])
		s["price"] = maxf(0.1, old * (1.0 + ratio))
		s["prev"] = old


## 新闻「所有地价 / 房租一起变」—— 直接按倍率调地块的地价系数
func _news_all_plots(mul: float) -> int:
	return _change_land_factors(mul - 1.0, true)


# ------------------------------------------------------------ 拉霸（老虎机）

## REA 44c8e0 / 44d230 / 429c60: 三种符号，按财神/香蕉/7数量派彩。
## 三财神17倍、三7五倍、三香蕉3倍、两财神2倍，其余0。
## Casino_Fee/TopRate/MiddleRate 配置不是这条原版执行路径的赔率。
const CASINO_SYMBOLS := ["sym_god", "sym_banana", "sym7"] # 44c8e0 image order.

func casino_multiplier(reels: Array) -> int:
	# 44d230 counts the stopped symbols; 429c60 evaluates those counts.
	var gods := reels.count("sym_god")
	if gods == 3: return 17
	if reels.count("sym7") == 3: return 5
	if reels.count("sym_banana") == 3: return 3
	if gods == 2: return 2
	return 0

var casino: Dictionary = {}          # {pid: {bet, reels, last, open, played}}


func _casino_of(pid: int) -> Dictionary:
	if not casino.has(pid):
		casino[pid] = {"bet": 0, "reels": [], "last": "", "open": false, "played": false}
	return casino[pid]


## 加注（原版那三个 `+1000` / `+5000` / `+10000` 按钮）
func act_casino_bet(id: int, amount: int) -> bool:
	var p: Dictionary = players.get(id, {})
	if p.is_empty() or amount not in [1000, 5000, 10000] or not bool(p["alive"]):
		return false
	var st := _casino_of(id)
	if not bool(st.get("open", false)) or bool(st.get("played", false)) or int(st.get("bet", 0)) > 0:
		return false
	if int(p["money"]) < amount:
		_ev("insufficient_money", p, {"need": amount, "have": int(p["money"])})
		return false
	p["money"] = int(p["money"]) - amount
	st["bet"] = int(st["bet"]) + amount
	_ev("casino_bet", p, {"amount": amount, "bet": int(st["bet"])})
	return true


## 拉杆：转三个滚轮并结算
func act_casino_pull(id: int) -> bool:
	var p: Dictionary = players.get(id, {})
	if p.is_empty():
		return false
	var st := _casino_of(id)
	if not bool(st.get("open", false)) or bool(st.get("played", false)):
		return false
	if int(st["bet"]) <= 0:
		_ev("casino_need_bet", p, {})
		return false
	var reels: Array = []
	for _i in range(3):
		reels.append(CASINO_SYMBOLS[rng.randi_range(0, CASINO_SYMBOLS.size() - 1)])
	st["reels"] = reels
	var bet := int(st["bet"])
	st["bet"] = 0
	st["played"] = true
	st["open"] = false
	var same := 0
	if reels[0] == reels[1] and reels[1] == reels[2]:
		same = 3
	elif reels[0] == reels[1] or reels[1] == reels[2] or reels[0] == reels[2]:
		same = 2
	var multiplier := casino_multiplier(reels)
	var win := bet * multiplier
	if win > 0:
		p["money"] = int(p["money"]) + win
	st["last"] = "赢 %d" % win if win > 0 else "没中"
	_ev("casino_result", p, {"reels": reels, "bet": bet, "win": win, "same": same, "multiplier": multiplier})
	log_message.emit("%s 拉霸：%s → %s" % [p["name"], str(reels),
		("赢 %d 元" % win) if win > 0 else "没中"])
	return true

func act_casino_exit(id: int) -> bool:
	var p: Dictionary = players.get(id, {})
	if p.is_empty(): return false
	var st := _casino_of(id)
	if not bool(st.get("open", false)): return false
	var refund := int(st.get("bet", 0))
	if refund > 0: p["money"] = int(p["money"]) + refund
	st["bet"] = 0
	st["open"] = false
	_ev("casino_exit", p, {"refund": refund})
	return true


## Native energy: 431ea0 initial half, 431f50 active-only decay/full freeze,
## 435910 skill cost. fullness remains a percentage mirror for old saves/UI.
const PET_FULLNESS_MAX := 100.0
const PET_START_FULLNESS := 50.0
const PET_HUNGER_PER_DAY := 1.0 # legacy percentage constant; native decay uses energy below.
const PET_ENERGY_MAX := {"qiongshen": 15.0, "hutu": 15.0, "emo": 20.0,
	"caishen": 20.0, "tushen": 30.0, "jingling": 20.0, "huaxian": 15.0,
	"dushen": 20.0, "guaishou": 15.0}

func pet_max_energy(e: Dictionary) -> float:
	var id := str(e.get("id", ""))
	return float(pet_record(id).get("max_energy", PET_ENERGY_MAX.get(id, 20.0)))

func pet_energy(e: Dictionary) -> float:
	var mx := pet_max_energy(e)
	# Old snapshots only have a percentage. Legacy writes to that mirror are
	# also accepted by diagnostic fixtures and converted once on access.
	if not e.has("energy") or not is_equal_approx(float(e.get("fullness", 0.0)), float(e.get("energy_percent", -1.0))):
		var percent := float(e.get("fullness", PET_START_FULLNESS))
		# Old ready was latched while the bar decayed; recover its actual full
		# state once, then rely exclusively on the new energy value.
		if not e.has("energy") and bool(e.get("ready", false)): percent = 100.0
		_set_pet_energy(e, percent * mx / 100.0)
	return float(e.energy)

func _set_pet_energy(e: Dictionary, value: float) -> void:
	e["max_energy"] = pet_max_energy(e)
	e["energy"] = clampf(value, 0.0, float(e.max_energy))
	e["fullness"] = 100.0 * float(e.energy) / float(e.max_energy)
	e["energy_percent"] = e.fullness
	e["ready"] = is_equal_approx(float(e.energy), float(e.max_energy))

func pet_anxious(e: Dictionary) -> bool:
	return not e.is_empty() and pet_energy(e) <= 3.0
const PET_LEVEL_CAP := 4               # Pet.txt 每只 4 级
const CARD_TARGET_MAX_TILES := 5 # Existing selection boundary; native units unresolved.
const MISSILE_AIM_MAX_TILES := 20


## 饱食度进度 0..1（UI 画条用）
func pet_fullness_ratio(e: Dictionary) -> float:
	return pet_energy(e) / pet_max_energy(e)


func pet_skill_ready(e: Dictionary) -> bool:
	return not e.is_empty() and is_equal_approx(pet_energy(e), pet_max_energy(e))


func pet_feed_value(card_id: String) -> float:
	# Native 41c530 / 43b672: card +0x11c goes directly to 432410.
	# card.crd +0x224 matches the printed badge: 1..5 internal energy points.
	return float(clampi(Rules.card_badge(card_id), 1, 5))

func _tick_pet_hunger(dt: float) -> void:
	# Native 431f50: update game hours / (consume_days * 24).
	var hours := dt * 24.0 / maxf(Rules.seconds_per_day(), 0.001)
	var loss := hours / (maxf(float(Rules.get_val("pet.consume_interval_days", 3)), 0.001) * 24.0)
	for pid in player_ids():
		var p: Dictionary = players[pid]
		var pet := active_pet(p)
		if pet.is_empty() or pet_skill_ready(pet): continue
		_set_pet_energy(pet, pet_energy(pet) - loss)
		if pet_energy(pet) <= 0.0: _pet_leave(p, pet)

func _pet_leave(p: Dictionary, pet: Dictionary, cause: String = "hunger") -> void:
	var token := pet_token(pet)
	(p.pets as Array).erase(pet)
	if str(p.get("pet_active", "")) == token or str(p.get("pet_active", "")) == str(pet.id):
		p["pet_active"] = "none"
	log_message.emit("%s 的 %s 能量耗尽离开了" % [p.name, pet_name(str(pet.id))])
	_ev("pet_flew_away", p, {"pet": str(pet.id), "pet_name": pet_name(str(pet.id)),
		"cause": cause, "voice_line": 9 if cause == "hunger" else 0})


func _tick_pet_aging() -> void:
	# Native growth belongs to the active instance, not the calendar month.
	# _advance records native road-crossing flags; this consumes the progress.
	for pid in player_ids():
		_try_pet_levelup(players[pid])


func card_road_candidates(pid: int, card_id: String) -> Array:
	var p: Dictionary = players.get(pid, {})
	var out: Array = []
	if p.is_empty() or map == null: return out
	for tile in range(map.tiles.size()):
		if card_id in ["missile", "nuke"]:
			# Follow road points for aiming; `range` still controls blast radius.
			if _tile_distance(int(p["tile"]), tile) > MISSILE_AIM_MAX_TILES: continue
			out.append(tile)
			continue
		if _tile_distance(int(p["tile"]), tile) > CARD_TARGET_MAX_TILES: continue
		if card_id == "clear":
			if _obstacle_at(tile).is_empty() and not road_objs.has(tile): continue
		elif not _obstacle_at(tile).is_empty(): continue
		out.append(tile)
	return out


func card_target_candidates(pid: int, card_id: String = "") -> Array:
	var p: Dictionary = players.get(pid, {})
	if p.is_empty():
		return []
	var out: Array = []
	for oid in player_ids():
		if int(oid) == pid:
			continue
		var o: Dictionary = players[oid]
		if not bool(o["alive"]):
			continue
		if _tile_distance(int(p["tile"]), int(o["tile"])) > CARD_TARGET_MAX_TILES:
			continue
		if card_id == "rob" and (o.get("cards", []) as Array).is_empty(): continue
		if card_id == "abduct" and ((o.get("pets", []) as Array).is_empty() or pet_count(p) >= max_pets()): continue
		if card_id == "tax" and int(o.get("money", 0)) <= 0: continue
		out.append(int(oid))
	return out


# ------------------------------------------------------------ 乐透

## REA 429df0: 买号码时付1000，进入不收费；44e120: 最多持有6个号码。
## 429a70 / 41c2f0: 每月15日开奖；429d20: 中奖者获整个城市基金。
## 无人中奖时号码和基金保留，中奖后429cd0才清空号码。
const LOTTO_NUMBERS := 12
const LOTTO_DRAW_DAYS := 30
const LOTTO_DRAW_DAY := 15 # 429a70 -> 41c2f0 (day-of-month), compared with 0x0f.
const LOTTO_PLAYER_LIMIT := 6 # 44e120 checks 429ca0's owned-number count < 6.

var lotto_prize := 10000 # Native 41a8e0 city fund; lotto pays this shared fund.
var lotto_numbers: Dictionary = {}        # 号码(int 1..12) -> 选了它的玩家 id
var lotto_last_draw_day := 0


func lotto_free_numbers() -> Array:
	var out: Array = []
	for i in range(1, LOTTO_NUMBERS + 1):
		if not lotto_numbers.has(i):
			out.append(i)
	return out

func lotto_pick_of(id: int) -> int:
	for number in lotto_numbers:
		if int(lotto_numbers[number]) == id: return int(number)
	return -1

func lotto_owned_count(id: int) -> int:
	return lotto_numbers.values().count(id)


## 玩家挑一个号码（面板上点号格）
func act_lotto_pick(id: int, n: int) -> bool:
	var p: Dictionary = players.get(id, {})
	if p.is_empty() or not bool(p["alive"]):
		return false
	if not bool(p.get("lotto_can_pick", false)):
		return false
	if n < 1 or n > LOTTO_NUMBERS or lotto_numbers.has(n) or lotto_owned_count(id) >= LOTTO_PLAYER_LIMIT:
		return false
	# 429df0 charges 1000 only when a free number is actually registered.
	if int(p.money) < 1000:
		_ev("insufficient_money", p, {"need": 1000, "have": int(p.money)})
		return false
	_transfer(p, null, 1000, "乐透号码")
	lotto_numbers[n] = id
	p["lotto_can_pick"] = false
	log_message.emit("%s 选了乐透号码 %d（当前奖金 %d 元）" % [p["name"], n, int(lotto_prize)])
	_ev("lotto_pick", p, {"number": n, "prize": int(lotto_prize)})
	return true


## 开奖（每 `LOTTO_DRAW_DAYS` 天）
func _lotto_draw() -> void:
	var win_n := rng.randi_range(1, LOTTO_NUMBERS)
	var winner := int(lotto_numbers.get(win_n, -1))
	if not players.has(winner): winner = -1
	var top := int(lotto_prize)
	var amount := 0
	var winner_name := ""
	if winner >= 0 and players.has(winner):
		amount = top
		players[winner]["money"] = int(players[winner]["money"]) + amount
		winner_name = str(players[winner]["name"])
	for pid in player_ids():
		players[pid]["lotto_can_pick"] = false
		_ev("lotto_draw", players[pid], {"number": win_n, "prize": int(lotto_prize),
			"winner": winner, "winner_name": winner_name, "amount": amount})
	if winner >= 0:
		log_message.emit("[乐透] 开奖号码 %d，%s 中了 %d 元" % [win_n, winner_name, amount])
		lotto_prize = 0
	else:
		# 429d20 returns zero when the drawn number has no owner; no reset follows.
		log_message.emit("[乐透] 开奖号码 %d，没有人中奖（奖金累积到下一期）" % win_n)
	if winner >= 0: lotto_numbers.clear()


## 小神仙台词（原版 `Info.txt` 的 `PETSAY` 段）。
##
## ⭐ **编号规律**（2026-09-27 解出，这就是之前一直缺的那张映射表）：
##     `id = 6000 + 数组下标(0..8) × 100 + 台词号(1..9)`
##   小穷神 6001..6009 / 糊涂鬼 6101..6109 / 小恶魔 6201..6209 / **小财神 6301..6309** /
##   小土神 6401..6409 / 雪精灵 6501..6509 / 花仙子 6601..6609 / 小赌神 6701..6709 /
##   小怪兽 6801..6809 —— 序号就是 `Pet.txt` 里的顺序。
##
##   台词号 1..9 = **发特技 / 平时×3 / 悲伤 / 被PK / 濒临逃离 / PK逃离 / HP逃离**，
##   与 `voice_map.json` 里 `pets[].lines` 的场景名**逐条对得上**。
##   例：老板截图那句「我是人见人爱的小财神」= **6302**（小财神 · 台词号 2「平时」）✅
func pet_line(pet_id: String, line_key: int) -> String:
	if line_key < 1:
		return ""
	var arr: Array = pets_data.get("pets", [])
	for i in range(arr.size()):
		if str((arr[i] as Dictionary).get("id", "")) != pet_id:
			continue
		return Rules.info_string(6000 + i * 100 + line_key)
	return ""


# ------------------------------------------------------------ 拍卖

## 拍卖（原版 `Info.txt` 364..367）：
##   4001「`<ROAD>`一处土地公开拍卖。」（对所有人）
##   4002「SORRY 加价**不得少于100元**。」（加价比现价低 100 元时）
##   4003「`<SOMEONE>`成功竞购`<ROAD>`土地。」（对所有人）
##
## **触发** = 全局新闻的一种（`Info.txt` 3013/3213 甲13「公开拍卖`<ROAD>`一处公有土地」）。
##
## ⚠️ **推断项**（配置里只给了这两条，别的没有）：
##   · `EstateSell_WaitTicks = 15` → **拍卖等待 15 秒**（有人加价就重新计时）
##   · `EstateSell_InitPriceRate = 0.8` → **起拍价 = 地产值 × 0.8**
##   · 加价档 **+100 / +500 / +1000** ← 这三张就是 `uitex/auction/100|500|1000.tga`
const AUCTION_SECONDS := 15.0           # EstateSell_WaitTicks
const AUCTION_INIT_RATE := 0.8          # EstateSell_InitPriceRate
const AUCTION_MIN_INC := 100            # Info.txt 4002「加价不得少于100元」
const AUCTION_INCS := [100, 500, 1000]  # 素材就是这三张

var auction: Dictionary = {}            # {} = 当前没在拍卖


func auction_active() -> bool:
	return not auction.is_empty()


## 从**无主的地产**里挑一块开拍。返回 false = 没有可拍的地。
func start_auction() -> bool:
	if map == null or auction_active():
		return false
	var cands: Array = []
	for i in range(map.tile_count()):
		if str(map.tile(i).get("kind", "")) == "plot" and not plots.has(i):
			cands.append(i)
	if cands.is_empty():
		return false
	var idx := int(cands[rng.randi_range(0, cands.size() - 1)])
	# `EstateSell_InitPriceRate = 0.8`「拍卖开始价格占房产价格的比例」
	var base := int(round(float(plot_value(idx)) * AUCTION_INIT_RATE))
	auction = {"tile": idx, "price": base, "best": -1, "name": "",
		"until": time + AUCTION_SECONDS}
	for pid in player_ids():
		_ev("auction_start", players[pid], {"tile": idx, "price": base,
			"street": map.street_of(idx),
			"info": Rules.info_fill(4001, {"ROAD": map.street_of(idx)})})
	log_message.emit("[拍卖] %s 一处土地公开拍卖，起拍 %d 元"
		% [map.street_of(idx), base])
	return true


## 加价（`delta` 取 `AUCTION_INCS` 之一）
func act_auction_bid(id: int, delta: int) -> bool:
	if not auction_active():
		return false
	var p: Dictionary = players.get(id, {})
	if p.is_empty() or not bool(p["alive"]) or (auction.get("passed", []) as Array).has(id):
		return false
	if delta < AUCTION_MIN_INC:
		# Info.txt 4002「SORRY 加价不得少于100元。」
		_ev("auction_bad_bid", p, {"info": Rules.info_fill(4002, {})})
		return false
	var want := int(auction["price"]) + delta
	if int(p["money"]) < want:
		_ev("insufficient_money", p, {"need": want, "have": int(p["money"])})
		return false
	auction["price"] = want
	auction["best"] = id
	auction["name"] = str(p["name"])
	if not players.has(-1):
		auction["until"] = time + AUCTION_SECONDS      # 有人出价 → 重新计时
	log_message.emit("%s 出价 %d 元" % [p["name"], want])
	_ev("auction_bid", p, {"tile": int(auction["tile"]), "price": want,
		"name": str(p["name"])})
	return true


## 放弃（PASS）：本场不再参与
func act_auction_pass(id: int) -> bool:
	if not auction_active():
		return false
	var p: Dictionary = players.get(id, {})
	if p.is_empty():
		return false
	if not (auction.get("passed", []) as Array).has(id):
		auction["passed"] = (auction.get("passed", []) as Array) + [id]
	_ev("auction_pass", p, {"tile": int(auction["tile"])})
	return true


## 结算：出价最高的拿走地皮，钱付给银行
func _auction_settle() -> void:
	var a := auction.duplicate()
	auction = {}
	var idx := int(a.get("tile", -1))
	var best := int(a.get("best", -1))
	var price := int(a.get("price", 0))
	if best < 0 or not players.has(best):
		log_message.emit("[拍卖] 没有人出价，流拍")
		for pid in player_ids():
			_ev("auction_end", players[pid], {"tile": idx, "price": 0, "winner": -1,
				"info": ""})
		return
	var pl: Dictionary = players[best]
	pl["money"] = int(pl["money"]) - price
	var t: Dictionary = map.tile(idx)
	_bind_plot(idx, {"owner": best, "level": 0, "type": "",
		"paid_base": float(price) / maxf(price_scale(), .001)})
	# 拿到地就要选房型（复用建筑卡片那套）
	if not players.has(-1):
		pl["last_plot"] = idx
		pl["last_plot_kind"] = "upgrade"
	for pid in player_ids():
		_ev("auction_end", players[pid], {"tile": idx, "price": price, "winner": best,
			"name": str(pl["name"]),
			"info": Rules.info_fill(4003, {"SOMEONE": str(pl["name"]),
				"ROAD": map.street_of(idx)})})
	log_message.emit("[拍卖] %s 以 %d 元竞购 %s 成功" % [pl["name"], price, map.street_of(idx)])


## 每帧检查拍卖是否到点
func _tick_auction() -> void:
	if auction_active() and time >= float(auction.get("until", 0.0)):
		_auction_settle()


## 某公司属于哪个玩家（虚拟公司返回 -1）
func company_owner(comp: String) -> int:
	return int((stocks.get(comp, {}) as Dictionary).get("owner", -1))


# ------------------------------------------------------------------ 玩家管理

## 体力参数（地图级优先，读不到回落到常量）
func stamina_max() -> float:
	return float(map.stamina.get("max", STAMINA_MAX)) if map != null else STAMINA_MAX

func stamina_step_cost() -> float:
	return float(map.stamina.get("step_cost", STAMINA_STEP_COST)) if map != null else STAMINA_STEP_COST

func stamina_regen() -> float:
	return float(map.stamina.get("regen_per_sec", STAMINA_REGEN)) if map != null else STAMINA_REGEN

func stamina_min_start() -> float:
	return float(map.stamina.get("min_to_start", STAMINA_MIN_START)) if map != null else STAMINA_MIN_START

## 掷骰的统一门槛；UI 使用快照时刻，服务端使用当前时刻。
func _roll_block_code(p: Dictionary, at_time: float = -1.0) -> String:
	if p.is_empty() or not bool(p.get("alive", false)):
		return "unavailable"
	var now := time if at_time < 0.0 else at_time
	if now < float(p.get("entry_until", 0.0)):
		return "entry"
	if int(p.get("moving", 0)) > 0:
		return "moving"
	var effects: Dictionary = p.get("effects", {})
	if now < float(effects.get("sleep_until", 0.0)):
		return "sleep"
	if now < float(effects.get("hospital_until", 0.0)):
		return "hospital"
	if now < float(effects.get("hotel_until", 0.0)): return "hotel"
	if now < float(effects.get("alien_until", 0.0)):
		return "alien"
	if int(effects.get("sleepwalk_steps", 0)) > 0:
		return "sleepwalk"
	if bool(p.get("pending_steps", false)): return "choose_steps"
	if float(p.get("stamina", 0.0)) < stamina_min_start():
		return "stamina"
	return ""

## 返回空串表示可以掷骰，其余值可直接作为 GO 钮的等待提示。
func roll_block_reason(p: Dictionary, at_time: float = -1.0) -> String:
	var now := time if at_time < 0.0 else at_time
	match _roll_block_code(p, now):
		"": return ""
		"entry": return "等待角色降落（还需 %.1f 秒）" % (float(p.get("entry_until", 0.0)) - now)
		"moving": return "角色正在移动"
		"choose_steps": return "请选择前进步数"
		"sleep": return "%s：冬眠中（还需 %.1f 秒）" % [
			str(p["effects"].get("sleep_source", "冬眠效果")),
			float(p["effects"].get("sleep_until", 0.0)) - now]
		"hospital": return "住院中（还需 %.1f 秒）" % (float(p["effects"].get("hospital_until", 0.0)) - now)
		"hotel": return "酒店住宿中（还需 %.1f 秒）" % (float(p["effects"].get("hotel_until", 0.0)) - now)
		"alien": return "被外星人带走（还需 %.1f 秒）" % (float(p["effects"].get("alien_until", 0.0)) - now)
		"sleepwalk": return "梦游中：电脑接管剩余 %d 步" % int(p["effects"].get("sleepwalk_steps", 0))
		"stamina": return "体力不足（%.0f/%.0f），歇一会儿" % [float(p.get("stamina", 0.0)), stamina_min_start()]
	return "当前无法掷骰"

func can_start_walk(p: Dictionary) -> bool:
	return _roll_block_code(p) == ""

## 业主处于异常状态时地产边框变黑，并且暂时不收租。
static func owner_abnormal(p: Dictionary, now: float) -> bool:
	var effects: Dictionary = p.get("effects", {})
	for key in ["rest_until", "sleep_until", "hospital_until", "alien_until", "hotel_until"]:
		if float(effects.get(key, 0.0)) > now:
			return true
	if int(effects.get("sleepwalk_steps", 0)) > 0 or bool(p.get("_dream_arrival", false)): return true
	return false

## `want_role`：玩家在**角色选择界面**挑的角色序号（1..12）。
## 0 或不合法 → 按加入顺序自动分配（原行为）。角色序号对应 `Role.txt` 行序与 `sound/player/roleN`。
func add_player(id: int, pname: String, want_role: int = 0) -> Dictionary:
	var idx := players.size()
	var role := want_role if want_role >= 1 and want_role <= 12 else idx % 12 + 1
	var used: Array = []
	for existing in players.values(): used.append(int(existing.get("role", 0)))
	for offset in range(12):
		var candidate := (role - 1 + offset) % 12 + 1
		if not used.has(candidate):
			role = candidate
			break
	var p := {
		"id": id,
		"name": pname,
		"money": START_MONEY,
		"credit": 0,                  # 点券（原版顶栏第 4 项；事件格「点券 5/10/20/30/50」加）
		"gems": 0,                    # 宝石（宝石卡：与卡片组合提升效果）
		"hp": START_HP,
		"stamina": stamina_max(),
		# 小神仙（精灵屋请来的）。每项 = {"id","level","cool"}，见 Pet.txt / pets.json
		"pets": [],
		"pet_shop_stock": [],
		"pet_shop_open": false,
		"lotto_can_pick": false,
		# 走满多少步给小神仙升级：原版 Initvar_r.txt「Pet_Upgrade_Steps = 300
		# 宠物每走多少步（此值 × 级数）升级」
		"pet_steps": 0,
		# 是否在「本段行走」里已经被传送过（防传送门 A→B→A 原地打转）
		"_teleported": false,
		# 掷骰动画播完之前不许起步（原版节奏：抛骰子 → 定格 → 才走）
		"move_after": 0.0,
		# 「出战」的小神仙（角色面板的精灵栏位显示它；原版可点开仓库切换）
		"pet_active": "",
		"tile": 0,
		"progress": 0.0,
		"dir": 1,
		"moving": 0,
		"speed": MOVE_SPEED,
		"alive": true,
		"idle": 0.0,
		"color": PLAYER_COLORS[idx % PLAYER_COLORS.size()].to_html(false),
		"cards": [],
		# 锁定的卡（key = 卡 id）。锁着的卡不会被新卡顶掉（原版菜单 id 2「锁定」）
		"card_locks": {},
		# 持股：{公司名: 股数}。上市的公司 = 本角色的「缺省公司」（config/Role.txt 第 6 列）
		"holdings": {},
		"company": "",
		"effects": {
			"invincible_until": 0.0,      # 绝对时刻（秒）
			"rest_until": 0.0,            # 挂机休息；点击 GO 可以立即唤醒
			"sleep_until": 0.0,           # 绝对时刻（秒）
			"sleepwalk_steps": 0,        # 糊涂鬼：电脑接管剩余行走步数
			"alien_until": 0.0,           # 新闻事件外星人绑架（异常状态）
			"invisible_until": 0.0,       # 绝对时刻（秒，隐形卡 Card_YinXing_Ticks = 72）
			"rush_until": 0.0,            # 绝对时刻（秒，暴走卡：加速且不走体力）
			"no_rent_steps": 0,           # 剩余步数（免费卡 / Card_MianFei_Steps）
			"no_rent_until": 0.0,         # 绝对时刻（小财神「免费技」按**秒**算，与上面的步数版区分）
			"rent_pay_double_until": 0.0, # 绝对时刻（小穷神「穷神技」：被附身者付双倍罚金）
			"pet_max_dice": 0,            # 小赌神「骰子技 遥控骰子」：下次掷骰取最大点数的次数
			"rent_double_steps": 0,       # 剩余步数（穷神卡 / Card_QiongShen_Steps）
			"free_upgrade_steps": 0,      # 福神剩余步数：抵达自有建筑自动升级，不免手动造价
			"no_upgrade_steps": 0,        # 剩余步数（衰神卡 / Card_ShuaiShen_Steps = 30）
		},
		"pending_steps": false,   # 骰子卡：等玩家点「走几步」（String.txt 9016「自由选择前进的步数」）
		"last_plot": -1,
		"last_plot_kind": "",     # "buy" / "upgrade" —— 本次抵达留下的**一次性**机会
		"last_roll": 0,
		"role": role,
	}
	players[id] = p
	# 以自己的「缺省公司」上市（Role.txt 第 6 列）+ 初始持有本公司 2000 股
	_init_player_company(p)
	log_message.emit("%s 加入游戏" % pname)
	return p


func _ev(kind: String, p, extra: Dictionary = {}) -> void:
	## 发一条带权威时间的语义事件（表现层播放特效、音效、语音与动作）。
	var d: Dictionary = extra.duplicate()
	d["t"] = time
	if p != null and p is Dictionary:
		d["pid"] = int(p["id"])
		d["role"] = int(p.get("role", 1))
		d["tile"] = int(p["tile"])
	game_event.emit(kind, d)

func remove_player(id: int) -> void:
	if players.has(id):
		_release_plots(id)
		players.erase(id)

func player_ids() -> Array:
	var ids := players.keys()
	ids.sort()
	return ids

# ---------------------------------------------------------------- 主循环 tick

func step(dt: float) -> void:
	if not running or map == null:
		return
	var t_before := time
	time += dt
	tick_count += 1
	for clear in pending_road_clears.duplicate():
		if time < float(clear.at): continue
		_remove_obstacle(int(clear.idx))
		road_objs.erase(int(clear.idx))
		pending_road_clears.erase(clear)
	for impact in pending_card_impacts.duplicate():
		if time >= float(impact["at"]):
			pending_card_impacts.erase(impact)
			_damage_area(int(impact["idx"]), int(impact["range"]), int(impact["damage"]),
				int(impact["owner"]), str(impact["card"]))

	# 天数推进 → 路边物体生成。
	# 节奏是**推断**：原版权重表只写了各类型的相对几率，没写判定频率；这里取「每天 roll 一次」，
	# 并对三种有 `*_Born_Days` 的（水晶 3 天 / 宝箱 5 天 / 神仙蛋 1 天）按周期节流。
	var now_day := int(time / Rules.seconds_per_day())
	while road_day < now_day:
		road_day += 1
		_spawn_road_obj()
		_tick_stocks()              # 每天开盘：股价按 Stock_OpenPrice_Min/Max 波动
		_maybe_global_news()        # 全局新闻（甲1..甲14）
		# 429a70 maintains a minimum city fund before checking the 15th-day draw.
		lotto_prize = maxi(lotto_prize, int(10000.0 * price_scale()))
		# 每月15日开奖。
		if road_day > lotto_last_draw_day and road_day % LOTTO_DRAW_DAYS == LOTTO_DRAW_DAY - 1:
			lotto_last_draw_day = road_day
			_lotto_draw()
		# 拍卖：到点结算
		_tick_auction()
		# Active pet growth accumulator; calendar alone does not level pets.
		_tick_pet_aging()
		# World index follows company assets, independently of calendar.
		if road_day % MONTH_DAYS == 0:
			_pay_dividends()        # 每 30 天（一个月）分红一次
	_tick_estate_index()
	lotto_prize = maxi(lotto_prize, int(10000.0 * price_scale()))
	_tick_pet_hunger(dt)

	for id in player_ids():
		var p: Dictionary = players[id]
		if not p["alive"]:
			continue
		if time < float(p.get("entry_until", 0.0)): continue
		if float(p["effects"].get("hospital_until", 0.0)) > 0.0:
			p["stamina"] = minf(stamina_max(), float(p.get("stamina", 0.0))
				+ maxf(stamina_regen(), 7.0) * dt)
			if float(p["stamina"]) + 0.001 < stamina_max(): continue
			p["effects"]["hospital_until"] = 0.0
			p["stamina"] = stamina_max()
			_ev("hospital_release", p)
		if time < float(p["effects"].get("hotel_until", 0.0)): continue
		if time < float(p["effects"].get("alien_until", 0.0)): continue

		# 体力随时间恢复（原版「每秒恢复体力」）—— 睡着了也恢复
		p["stamina"] = minf(stamina_max(),
			float(p.get("stamina", 0.0)) + stamina_regen() * dt)

		# 暴走卡到点 → 速度恢复正常
		if float(p["effects"]["rush_until"]) > 0.0 \
				and time >= float(p["effects"]["rush_until"]):
			p["effects"]["rush_until"] = 0.0
			p["speed"] = MOVE_SPEED

		# 睡眠 / 冬眠状态
		if time < maxf(float(p["effects"].get("rest_until", 0.0)),
				float(p["effects"]["sleep_until"])):
			continue

		if p["moving"] > 0:
			# 掷骰动画还没播完就先站着（原版：抛骰子 → 定格点数 → 才起步）。
			# ⚠️ 只走「本帧里动画终点之后」的那一段 —— 否则等待的时间会被算进移动距离
			var seg: float = time - maxf(t_before, float(p.get("move_after", 0.0)))
			if seg > 0.0:
				_advance(p, seg)
		else:
			if float(p["stamina"]) + 0.001 < stamina_max():
				p["idle"] = 0.0
			else:
				p["idle"] = float(p["idle"]) + dt
			if float(p["idle"]) >= IDLE_SLEEP_SECONDS:
				p["idle"] = 0.0
				var delay := rng.randf_range(6.0, 12.0)
				p["effects"]["rest_until"] = time + delay
				log_message.emit("%s 打了个盹，%.0f 秒后继续" % [p["name"], delay])
				_ev("sleep", p)

func _advance(p: Dictionary, dt: float) -> void:
	var step_dist: float = float(p["speed"]) * dt
	p["progress"] = float(p["progress"]) + step_dist
	var crossed_road := false
	while float(p["progress"]) >= 1.0 and int(p["moving"]) > 0:
		crossed_road = true
		p["progress"] = float(p["progress"]) - 1.0
		var previous_tile := int(p["tile"])
		p["tile"] = _wrap(int(p["tile"]) + int(p["dir"]))
		p["lotto_can_pick"] = false
		p["moving"] = int(p["moving"]) - 1
		p["walked_this_move"] = int(p.get("walked_this_move", 0)) + 1
		_tick_step_effects(p)
		# 每前进 1 格扣体力（原版「每走一步消耗体力」）。
		# ⚠️ 出发门槛（min_to_start）只在 act_roll 判定；已经上路的不因为半路见底而原地卡住
		#   —— 原版注释里那一项写的是「自己走**所需要**最小体力值」，是出发条件。
		# 暴走卡（9015「不消耗体力疯狂前进」）期间不扣。
		if float(p["effects"]["rush_until"]) <= time:
			p["stamina"] = maxf(0.0, float(p.get("stamina", 0.0)) - stamina_step_cost())
		# 踩到**玩家放的陷阱**（地雷卡 / 路障卡）
		var ob := _obstacle_at(int(p["tile"]))
		if not ob.is_empty():
			_remove_obstacle(int(ob["idx"]))
			if str(ob["kind"]) == "mine":
				if not _protected(p):
					_ev("mine", p, {"idx": int(p["tile"]), "owner": int(ob["owner"])})
					_send_to_hospital(p, float(Rules.get_val("hp.mine_damage", 1000)), "mine")
				p["moving"] = 0
				p["progress"] = 0.0
			else:
				p["moving"] = 0
				p["progress"] = 0.0
				log_message.emit("%s 被路障挡住" % p["name"])
				_ev("roadblock", p, {"idx": int(p["tile"]), "owner": int(ob["owner"])})
		# ⚠️ 路边物体（roadobj）**故意不在这里判** —— 老板 2026-09-27：
		#   「路线上的事件点必须要**踩到**才会生效，现在**路过**就生效了」
		#   → 已挪到 `_arrive()`（停下来那一刻才触发）。
		# 卡片点（`cardpt`）：**路过就给 1 张**（老板 2026-09-27「路过就会发一张卡」），
		#   停在这一格时由 `_resolve_event` **再补 1 张**（合计 2 张）。
		elif _event_key(int(p["tile"])) == "cardpt":
			_give_random_card(p, "卡片点")
			p["_cardpt_given"] = int(p["tile"])
		# 踩到**传送平台**（原版 Roadevent 事件 1）：经过就传送，并结束本次移动。
		# ⚠ 必须放在**逐格循环里**判 —— 原来只在 _arrive（停下那一刻）判，
		#   于是「路过」不传送，玩家可以站在传送平台上；此时再掷 1 点走 1 格到
		#   「另一处平台」，又被原样传回来 ⇒ 看起来「留在原地」（老板 2026-09-26 反馈）。
		#   埃及的 2 格传送平台在路径上相邻、世界里却隔 13.9 单位（≈3 格），正是传送门的两端。
		elif _event_key(int(p["tile"])) == "platform" \
				and not bool(p.get("_teleported", false)):
			if _teleport_platform(p, int(p["tile"])) < 0 and map.name == "aiji" \
					and _event_key(previous_tile) == "platform":
				# 埃及的 24/25 是一张地毯的两端；路径索引相邻但世界坐标相隔很远。
				# 让视觉动画把人从上一格载过来，走线结算仍按原路径索引。
				p["progress"] = 0.0
				p["move_after"] = time + 1.0
				_ev("platform", p, {"idx": previous_tile, "to": int(p["tile"]), "visual_only": true})
				break
	# Native 423b90 returns bit 2 if this update crosses a road boundary;
	# 433d40 -> 4361b0 adds one to the equipped pet's own growth field.
	# Multiple boundaries in one unusually large update still return one flag.
	if crossed_road:
		var pet := active_pet(p)
		if not pet.is_empty(): pet["growth"] = int(pet.get("growth", 0)) + 1
	if int(p["moving"]) <= 0:
		p["moving"] = 0
		p["progress"] = 0.0
		p["idle"] = 0.0
		# 骰子在这一刻停住（音效 005「骰子滚动结束」的时机，老板试听确认）
		_ev("roll_end", p)
		_arrive(p)
		p["_teleported"] = false       # 本次抵达结束 → 解除「本段行走已传送」保护

func _tick_step_effects(p: Dictionary) -> void:
	## 每走 1 格，把所有「多少步」类的状态各减 1
	## （原版 Initvar_r.txt：Card_MianFei_Steps / Card_FuShen_Steps / Card_ShuaiShen_Steps …）
	var e: Dictionary = p["effects"]
	for k in STEP_EFFECTS:
		if int(e[k]) > 0:
			e[k] = int(e[k]) - 1
	if int(e.get("sleepwalk_steps", 0)) > 0:
		p["_dream_arrival"] = true
		e["sleepwalk_steps"] = int(e["sleepwalk_steps"]) - 1
		if int(e["sleepwalk_steps"]) == 0:
			_ev("sleepwalk_end", p)
	# Pet growth is recorded by _advance; elapsed time does not add growth.


## 走够步数就把一只小神仙升一级。门槛 = Pet_Upgrade_Steps × 当前等级。
func _try_pet_levelup(p: Dictionary) -> void:
	var pet := active_pet(p)
	if pet.is_empty(): return
	var level := int(pet.get("level", 1))
	var threshold := int(Rules.get_val("pet.upgrade_steps_per_level", 300)) * level
	if level >= PET_LEVEL_CAP or int(pet.get("growth", 0)) < threshold: return
	pet["level"] = level + 1
	pet["growth"] = 0
	_ev("pet_levelup", p, {"pet": str(pet.id), "level": level + 1, "by": "growth"})


func _wrap(i: int) -> int:
	var n := map.tile_count()
	return ((i % n) + n) % n

# --------------------------------------------------------------- 到达格结算

## 同一格上已经有人 → 把 TA **往前挤一格**（老板 2026-09-26 的原版观察：
## 原版**不允许多人站在同一个位置**）。
##
## 「挤」= 一种搞怪：
##   · 被挤的人**要付房租**（落点若踩在别人的地产上）—— 走一遍 `_resolve_plot`
##   · 但**不触发**地面事件 / 买地 / 升级 —— 结算完立刻 `_clear_chance()` 把机会作废
##
## ⚠️ 只挤「**站着不动**」的人（`moving == 0`）；正在走的人不挤（他马上会离开这格）。
## 找到站在 `tile` 上、且**不是** `except_id` 的**一个**玩家（没有则返回 {}）。
## 只算**站着不动**的 —— 正在走的人还没落位，不算占着这格。
func _occupant_at(tile: int, except_id: int) -> Dictionary:
	for oid in player_ids():
		if int(oid) == except_id:
			continue
		var o: Dictionary = players[oid]
		if not bool(o["alive"]) or int(o["moving"]) > 0:
			continue
		if int(o["tile"]) == tile:
			return o
	return {}


## 把同格的人往前挤一格。**原版铁律：任何时刻都不允许两人同格。**
##
## 老板 2026-09-27 补充的三条，缺一不可：
##   ① 被挤的人**朝向变得和挤他的人一致**（`dir` 跟着走，不是原地转身）
##   ② 这一下移动会**打断他跟位置绑定的操作** —— 买地/升级的气泡、卡片菜单、
##      卡片商店 / 精灵屋、拍卖 / 乐透 / 拉霸这些「站在这一格才点得开」的界面全部作废；
##      而**买入股票**这种**跟位置无关**的不受影响（所以事件的 `bound` 标记区分两类）
##   ③ 被挤的人**也会去挤他前面的人**（**连锁反应**），一直往前推，直到前面没人
func _push_away_occupants(p: Dictionary) -> void:
	if map == null:
		return
	var cur: Dictionary = p
	var guard := 0
	var displaced: Array[Dictionary] = []
	while guard < players.size() + 2:
		guard += 1
		var victim := _occupant_at(int(cur["tile"]), int(cur["id"]))
		if victim.is_empty():
			break                     # 前面没人了 → 连锁结束
		var from := int(victim["tile"])
		var dest := _wrap(from + int(cur.get("dir", 1)))
		victim["tile"] = dest
		victim["lotto_can_pick"] = false
		victim["progress"] = 0.0
		victim["idle"] = 0.0
		# ① 朝向跟挤他的人一致
		victim["dir"] = int(cur.get("dir", 1))
		# ② 位置绑定的操作当场作废（UI 收到 `pushed_away` 会把对应界面关掉）
		_clear_chance(victim)
		log_message.emit("%s 被 %s 挤到 %d 格" % [victim["name"], cur["name"], dest])
		_ev("pushed_away", victim, {"by": int(cur["id"]), "by_name": str(cur["name"]),
			"from": from, "tile": dest})
		displaced.append({"player": victim, "tile": dest})
		cur = victim                    # ③ 接着往前连锁
	# 等连锁挤人完成后，从队尾向前结算，避免同格临时状态影响事件。
	for i in range(displaced.size() - 1, -1, -1):
		var landing: Dictionary = displaced[i]
		_resolve_pushed_landing(landing["player"], int(landing["tile"]))

func _resolve_pushed_landing(p: Dictionary, idx: int) -> void:
	if int(p["tile"]) != idx:
		return
	if road_objs.has(idx):
		var obj: Dictionary = road_objs[idx]
		road_objs.erase(idx)
		_pick_road_obj(p, str(obj["kind"]), idx)
	if int(p["tile"]) != idx:
		return
	var t: Dictionary = map.tile(idx)
	match str(t.get("kind", "")):
		"event":
			# 商店、乐透和拉霸需要主动选择；财神、点券、问号等自动事件照常触发。
			if str(t.get("event", "")) not in ["cardshop", "pethouse", "casino", "labar"]:
				_resolve_event(p, idx, t)
		"plot":
			# 被挤到别人的地产仍须交租；空地和自家地产不给购买、升级机会。
			var owner := int(plots.get(idx, {}).get("owner", -1))
			if owner >= 0 and owner != int(p["id"]):
				_resolve_plot(p, idx, t)
	_clear_chance(p)

func _arrive(p: Dictionary) -> void:
	if float(p["effects"].get("hospital_until", 0.0)) > time: return
	var idx: int = int(p["tile"])
	var t: Dictionary = map.tile(idx)
	# 原版**不允许多人站在同一格** —— 后到的人把先到的人往前挤一格。
	# 必须在「本次抵达结算」之前做，否则被挤的人会先吃到本格的结算。
	_push_away_occupants(p)
	# 上一次抵达留下的「一次性机会」作废 —— 想再动这块地，必须再走回来
	# （原版 Info.txt id 93：升级是抵达时的一次询问，不是随时可点）
	_clear_chance(p)

	# 路边物体（宝箱 / 水晶 / 神仙蛋 / 小偷 …）：**停在这一格**才触发，随即消失。
	# ⚠️ 老板 2026-09-27：原来写在逐格循环里 → **路过就捡**，不符合原版。
	if road_objs.has(idx):
		var rob: Dictionary = road_objs[idx]
		road_objs.erase(idx)
		_pick_road_obj(p, str(rob["kind"]), idx)

	match t.get("kind", ""):
		"plot":
			_resolve_plot(p, idx, t)
		"event":
			_resolve_event(p, idx, t)
		"start":
			pass
	# 格子结算完之后再给小神仙一次发动机会（它们的效果不再回头触发本函数）
	_tick_pets(p)
	p["_dream_arrival"] = false

func _clear_chance(p: Dictionary) -> void:
	p["last_plot"] = -1
	p["last_plot_kind"] = ""

## Native 438ab0: state 7 auto-upgrades eligible OWN buildings before the normal
## construction choice. It neither spends money nor consumes that manual choice.
func _apply_fushen_arrival(p: Dictionary, idx: int, plot: Dictionary) -> bool:
	if int(p.effects.get("free_upgrade_steps", 0)) <= 0 or int(plot.owner) != int(p.id): return false
	var kind := str(plot.get("type", ""))
	var level := int(plot.get("level", 0))
	if level <= 0 or kind.begins_with("special") or Rules.house_next_level(kind, level) == 0: return false
	var plan := construction_plan(int(p.id), idx, kind)
	if plan.is_empty(): return false
	_commit_construction(idx, plan, 0)
	_ev("upgrade", p, {"idx": idx, "level": int(plan.level), "cost": 0,
		"street": map.street_of(idx), "type": kind, "forced": true, "by_god": "fushen"})
	return true

## Native 439160 -> 438d70. Special buildings are services, not fallback rent.
## 423250 resets move+8c; 423b90 increments it for each actual crossed road.
func _resolve_special_building(p: Dictionary, idx: int, plot: Dictionary) -> bool:
	var kind := str(plot.get("type", ""))
	if not kind.begins_with("special"): return false
	var file := Rules.house_file(kind, int(plot.get("level", 0)))
	var owner := int(plot.get("owner", -1))
	var own := owner == int(p.id)
	var beneficiary: Variant = players.get(owner, null)
	var walked := maxi(0, int(p.get("walked_this_move", 0)))
	var number := 0
	var card := ""
	match file:
		"d201": # Club transfers coupons from visitor to owner; it never gives a card.
			if not own:
				number = mini(int(p.credit), walked)
				p.credit = int(p.credit) - number
				if beneficiary != null: beneficiary.credit = int(beneficiary.credit) + number
		"d202": # Bank fee: visitor cash * actual steps * 2%, truncation.
			if not own:
				number = int(float(p.money) * float(walked) * 0.02)
				_transfer(p, beneficiary, number, "银行手续费")
		"d203": # Hotel charges steps * 10000 and puts the visitor away for 48 hours.
			if not own:
				number = walked * 10000
				if number > 0:
					_transfer(p, beneficiary, number, "酒店住宿")
					p.effects["hotel_until"] = time + 2.0 * Rules.seconds_per_day()
		"d101": # Fountain restores the character's HP/stamina completely.
			number = int(stamina_max() - float(p.stamina))
			p.stamina = stamina_max()
		"d102": # Chain stores charge exponentially by owner's stores across the map.
			if not own:
				var count := 0
				for key in unique_plot_keys():
					var other: Dictionary = plots[key]
					if int(other.owner) == owner and Rules.house_file(str(other.get("type", "")), int(other.level)) == "d102": count += 1
				number = mini(160000, 10000 * int(pow(2.0, maxi(0, count - 1))))
				_transfer(p, beneficiary, number, "连锁店消费")
		"d103":
			p.stamina = stamina_max()
			var pet := active_pet(p)
			if not pet.is_empty(): _set_pet_energy(pet, pet_max_energy(pet))
		"d301": # Its environmental price change is applied by the estate model.
			pass
		"d302": # MP is the equipped little god's energy, not character stamina.
			var pet := active_pet(p)
			if not pet.is_empty(): _set_pet_energy(pet, pet_max_energy(pet))
		"d303":
			var research := rng.randi_range(1, 3) if own else 1
			# 41ed50 category 2 selects original indices 0..7; visitor -1 selects 0..39.
			card = "gem" if research == 2 else ("nuke" if research == 3 else Rules.card_id_at(rng.randi_range(1, 8 if own else 40)))
			if Rules.card_by_id(card).is_empty(): card = _random_card()
			var gained := _push_card(p, card)
			if bool(gained.get("added", false)): _report_card_push(p, gained, Rules.card_name(card))
			else: card = ""
	_ev("special_building", p, {"idx": idx, "file": file, "owner": owner,
		"number": number, "card": card, "pet_present": not active_pet(p).is_empty(),
		"name": str(Rules.house_grade(kind, int(plot.level)).get("name", ""))})
	return true

func _resolve_plot(p: Dictionary, idx: int, t: Dictionary) -> void:
	var street: String = t.get("street", "")
	var dreamwalking := bool(p.get("_dream_arrival", false)) or int(p["effects"].get("sleepwalk_steps", 0)) > 0
	if not plots.has(idx):
		if dreamwalking:
			_ev("sleepwalk_pass_plot", p, {"idx": idx, "street": street})
			return
		if int(p["effects"].get("no_upgrade_steps", 0)) > 0:
			_ev("buy_blocked", p, {"idx": idx, "street": street})
			return
		# 空地：原版 Info.txt id 91「<ROAD>\n购买价格<NUMBER>元\n是否购买」
		p["last_plot"] = idx
		p["last_plot_kind"] = "buy"
		log_message.emit("%s 抵达 %s（空地，可购买）" % [p["name"], street])
		_ev("arrive_empty", p, {"idx": idx, "street": street, "price": empty_plot_price(idx)})
		return

	var plot: Dictionary = plots[idx]
	var owner: int = int(plot["owner"])
	var level: int = int(plot["level"])
	var ptype: String = str(plot.get("type", ""))

	# Native 439160 routes all special buildings through 438d70 and returns before rent.
	if _resolve_special_building(p, idx, plot): return
	_apply_fushen_arrival(p, idx, plot)
	level = int(plot["level"])

	if owner == int(p["id"]):
		if dreamwalking:
			_ev("sleepwalk_pass_plot", p, {"idx": idx, "street": street})
			return
		# ---- 回到自己地产：原版 id 93「<ROAD>\n升级费用<NUMBER>元\n是否升级」 ----
		# 触发点权威依据：
		#   id 1050（福神）批注「附身者**进入自己土地时**显示」
		#   id 1053（衰神）批注「附身者**进自己土地建设或升级后**显示」
		# 也就是说：能升级的时机 = **刚刚走到自己这块地**，一次一格一次机会。
		log_message.emit("%s 回到自己的 %s（%d 级）" % [p["name"], street, level])
		if int(p["effects"]["no_upgrade_steps"]) > 0:
			_ev("arrive_own", p, {"idx": idx, "street": street, "level": level,
				"type": ptype, "blocked": true})
			log_message.emit("  衰神附身中，无法升级")
			return
		var target := Rules.house_next_level(ptype, level)
		if level > 0 and target == 0:
			_ev("arrive_own", p, {"idx": idx, "street": street, "level": level,
				"type": ptype, "maxed": true})
			log_message.emit("  已是最高等级（%s）" % str(Rules.house_grade(ptype, level).get("name", "")))
			return
		p["last_plot"] = idx
		p["last_plot_kind"] = "upgrade"
		var cost := upgrade_cost(p, idx, "")
		var opts: Array = buildable_types() if ptype == "" else []
		_ev("arrive_own", p, {"idx": idx, "street": street, "level": level, "type": ptype,
			"target": target, "cost": cost, "options": opts,
			"free": false})
		log_message.emit("  可升级到 %d 级%s，费用 %d 元" % [
			target, "（需选择房型）" if ptype == "" else "", cost])
		return

	# ---- 踩到别人的地：交租（原版 id 94）----
	if owner_abnormal(players.get(owner, {}), time):
		log_message.emit("%s 的业主处于异常状态，%s 暂不收租" % [p["name"], street])
		_ev("free_rent", p, {"idx": idx, "street": street, "owner_abnormal": owner})
		return
	# 免费卡按**步数**、小财神「免费技」按**秒**（Pet.txt 即时制那一行）—— 语义不同，
	# Info.txt 1051 也把「免费状态」单独列了一条，所以两个字段并存。
	if int(p["effects"]["no_rent_steps"]) > 0:
		log_message.emit("%s 使用免费卡，免付过路费" % p["name"])
		_ev("free_rent", p, {"idx": idx, "street": street})
		return
	if float(p["effects"].get("no_rent_until", 0.0)) > time or float(p["effects"].get("invisible_until", 0.0)) > time:
		log_message.emit("%s 的小财神显灵，免付租金" % p["name"])
		_ev("free_rent", p, {"idx": idx, "street": street, "by_pet": "caishen"})
		return

	# 查封卡（9031）：查封期内这条街不收租
	var sealed_until := float(street_seal.get(street, 0.0))
	if sealed_until > time:
		log_message.emit("%s 踩到查封中的 %s，免收过路费" % [p["name"], street])
		_ev("sealed_rent", p, {"idx": idx, "street": street, "until": sealed_until})
		return

	var rent := plot_rent(idx)
	var joint := joint_rent_members(idx)
	if int(p["effects"]["rent_double_steps"]) > 0:
		rent *= 2
		log_message.emit("%s 处于穷神状态，租金加倍" % p["name"])
	# 小穷神「穷神技 罚金加倍」（String.txt 2201 / Info.txt 191）：被附身者付双倍**罚金**。
	# 与穷神卡（按步数）分开记：这是**按秒**的。
	if float(p["effects"].get("rent_pay_double_until", 0.0)) > time:
		rent *= 2
		log_message.emit("%s 被小穷神附身，罚金加倍" % p["name"])
		_ev("pet_curse_rent", p, {"idx": idx, "street": street, "rent": rent})

	_transfer(p, players.get(owner), rent, "%s 的 %s" % [players[owner]["name"], street])
	log_message.emit("%s 向 %s 支付过路费 %d 元" % [p["name"], players[owner]["name"], rent])
	_ev("pay_rent", p, {"idx": idx, "street": street, "amount": rent, "to": owner,
		"level": level, "type": ptype, "joint_members": joint})

## 该等级被踩到时的过路费（元）。等级 0 = 尚未建设的空地。
func _rent_of(level: int, type_id: String = "") -> int:
	if level <= 0:
		return int(round(EMPTY_PLOT_RENT * price_scale()))
	# 原版房租乘整数世界物价指数；它由公司资产增长驱动。
	# `price_scale()` = 指数 / 10 —— 指数 10 时就是 House.txt 原价。
	return int(round(float(Rules.house_rent(type_id, level)) * price_scale()
		* float(economy_factors.get(type_id, 1.0))))

func _single_plot_rent(idx: int) -> int:
	var estate: Dictionary = plots.get(idx, {})
	if estate.is_empty(): return 0
	var owner: Dictionary = players.get(int(estate.get("owner", -1)), {})
	if owner.is_empty() or owner_abnormal(owner, time): return 0
	if float(street_seal.get(map.street_of(idx), 0.0)) > time: return 0
	var level := int(estate.get("level", 0))
	var type_id := str(estate.get("type", ""))
	var coefficient := 0.0
	var cells := {}
	for member in estate.get("members", [idx]): cells[_land_key(int(member))] = true
	for cell in cells: coefficient += _land_factor(int(cell))
	coefficient /= maxi(1, cells.size())
	if level > 0:
		var environment := 0.0
		for cell in cells:
			environment += float(land_factors.get(int(cell), {}).get("environment", {}).get(type_id, 0.0))
		environment /= maxi(1, cells.size())
		coefficient = maxf(1.0, environment + (10.0 if type_id == "industry" else coefficient))
	var amount := float(_rent_of(level, type_id)) * coefficient / 10.0 * float(estate.get("rent_mul", 1.0))
	return int(snappedf(amount, 0.000001)) # Stable truncation across JSON float roundtrips.

func joint_rent_members(idx: int) -> Array:
	var estate: Dictionary = plots.get(idx, {})
	if estate.is_empty(): return []
	if int(estate.get("level", 0)) <= 0: return [idx]
	var result: Array = []
	for key in unique_plot_keys():
		var other: Dictionary = plots[key]
		if map.street_of(int(key)) == map.street_of(idx) \
				and int(other.get("owner", -1)) == int(estate.get("owner", -1)) \
				and str(other.get("type", "")) == str(estate.get("type", "")) \
				and int(other.get("level", 0)) > 0:
			result.append(int(key))
	return result

func plot_rent(idx: int) -> int:
	var rent := 0
	for member in joint_rent_members(idx): rent += _single_plot_rent(int(member))
	return rent

## 路面事件（权威表 = 原版 config/Roadevent.txt 的 1..16，地图 JSON 的 event 字段即这张表的 key）
func _resolve_event(p: Dictionary, idx: int, t: Dictionary) -> void:
	var eid: String = t.get("event", "")
	var ename: String = t.get("name", eid)
	# Dreamwalking still triggers automatic road events. It cannot open a shop
	# or a minigame that requires decisions from the absent player.
	if (bool(p.get("_dream_arrival", false)) or int(p.effects.get("sleepwalk_steps", 0)) > 0) \
			and eid in ["cardshop", "pethouse", "casino", "labar"]:
		_ev("sleepwalk_pass_event", p, {"eid": eid, "ename": ename})
		return
	match eid:
		"hospital":
			# 普通路点没有伤害，不应把医院路点误写成冬眠状态。
			# 爆炸等受伤仍由 _send_to_hospital 按体力恢复处理。
			log_message.emit("%s 经过%s" % [p["name"], ename])
			_ev("hospital", p, {"eid": eid})
		"platform":
			# 传送平台（原版 Roadevent.txt 事件 1）。
			# ⚠ 主体逻辑在 `_advance` 的逐格循环里（**经过就传送**），这里只是「刚好停在上面」的
			#   兜底；本段行走已经传过就不再传（否则 A→B 再 B→A 会原地打转）。
			if map.name != "aiji" and not bool(p.get("_teleported", false)) and _teleport_platform(p, idx) < 0:
				log_message.emit("%s 站在传送平台上，但本图没有第二处平台" % p["name"])
		"cardshop":
			# 卡片商店：**用点券买卡**（Info.txt 41「卡片商店 您有<NUMBER>点券」/
			# 42「您没有点券 不能进入卡片商店」）。这里是「开架」——
			# 真正的购买走 act_buy_card()，由 UI 的商店面板发指令（uitex/other/cardshop.tga）。
			# 439530 requests eight fresh instances via 41ee60 on every arrival.
			refill_card_shop()
			p.card_shop_stock = card_shop_stock.duplicate()
			_ev("cardshop_open", p, {"eid": eid, "credit": int(p["credit"]),
				"stock": _shop_stock(int(p.id)), "have": int(p["credit"])})
			log_message.emit("%s 走进%s（点券 %d）" % [p["name"], ename, int(p["credit"])])
		"cardpt":
			# 卡片点：**站上去再补 1 张**（逐格循环里路过时已经给过 1 张了）
			# 老板 2026-09-27：「路过就会发一张卡，站上去会发两张」
			if int(p.get("_cardpt_given", -1)) == int(p["tile"]):
				_give_random_card(p, ename)       # 补第 2 张（路过已得 1 张）
			else:
				# 没在逐格里给过（比如被传送/被挤上来）→ 直接给 2 张
				_give_random_card(p, ename)
				_give_random_card(p, ename)
			p["_cardpt_given"] = -1
		"coupon5", "coupon10", "coupon20", "coupon30", "coupon50":
			# 点券格：事件名就是面额（Roadevent.txt 事件 11..15）
			var amount := int(eid.substr(6))
			p["credit"] = int(p["credit"]) + amount
			log_message.emit("%s 在%s获得 %d 点券" % [p["name"], ename, amount])
			_ev("credit", p, {"eid": eid, "ename": ename, "amount": amount})
		"tvnews":
			# 问号／电视台事件使用原版 Info.txt「命运1..19」结果表。
			_resolve_fate(p)
		"labar":
			# **拉霸（老虎机）** —— `labar` 就是「拉霸」的拼音（台语对老虎机的叫法）。
			# 打开面板让玩家自己下注（原版截图 records/老虎机.png：
			# 从左侧滑出 + 三档下注 `+1000/+5000/+10000` + 拉杆）。
			#
			# ⚠️ 2026-09-27 **纠正**：上一轮我把这一支写在了 `casino` 格上 —— 错了。
			#   `casino` 格是**乐透**（`Event_Casino_*` 三项参数的注释都写着「进入**乐透**事件点…」），
			#   `labar` 格才是拉霸。两台的素材也不同：拉霸 = `uitex/casino/`，乐透 = `uitex/casino2/`。
			var slot := _casino_of(int(p["id"]))
			# 位置被挤走等异常离开后，下一次进入先退还未拉杆的旧注。
			if int(slot.get("bet", 0)) > 0:
				p["money"] = int(p["money"]) + int(slot["bet"])
			slot["open"] = true
			slot["played"] = false
			slot["bet"] = 0
			slot["reels"] = []
			slot["last"] = ""
			_ev("casino_open", p, {"eid": eid})
		"capital":
			# 市政府：按市政基金征收 / 发放（Event_CityFund_MinValue）
			var fund := int(Rules.get_val("economy.city_fund_min", 1000))
			if rng.randi_range(0, 1) == 0:
				_transfer(p, null, fund, ename)
				log_message.emit("%s 在%s缴纳市政基金 %d 元" % [p["name"], ename, fund])
				_ev("capital_result", p, {"amount": -fund})
			else:
				p["money"] = int(p["money"]) + fund
				log_message.emit("%s 在%s领到市政补助 %d 元" % [p["name"], ename, fund])
				_ev("win_money", p, {"eid": eid, "amount": fund})
				_ev("capital_result", p, {"amount": fund})
		"pethouse":
			# 精灵屋：**用点券买**（Info.txt 201「精灵屋 请选购小神仙」/ 202 上限 5 位 /
			# 203「<BABYNAME>价格<NUMBER>点券 确认要购买吗？」）。
			# 这里是「开店」——真正的购买走 act_buy_pet()，由 UI 的商店面板发指令。
			p["pet_shop_stock"] = _new_pet_shop_stock()
			p["pet_shop_open"] = true
			log_message.emit("%s 走进%s，点券 %d" % [p["name"], ename, int(p["credit"])])
			_ev("pethouse_open", p, {"eid": eid, "credit": int(p["credit"]),
				"owned": pet_count(p), "max": max_pets(), "stock": p["pet_shop_stock"].duplicate()})
		"game_a", "game_b":
			# 游戏点：记忆游戏，按成绩给点券（Event_MemoryGame_CreditMin/Max）
			var lo2 := int(Rules.get_val("events.memory_game_credit_min", 1))
			var hi2 := int(Rules.get_val("events.memory_game_credit_max", 50))
			var g := rng.randi_range(lo2, hi2)
			p["credit"] = int(p["credit"]) + g
			log_message.emit("%s 在%s玩了一把，赢得 %d 点券" % [p["name"], ename, g])
			_ev("credit", p, {"eid": eid, "ename": ename, "amount": g})
		"casino":
			# 429df0 only charges after a valid number purchase.
			var fee := 1000
			if int(p["money"]) < fee:
				_ev("insufficient_money", p, {"need": fee, "have": int(p["money"])})
			elif lotto_free_numbers().is_empty() or lotto_owned_count(int(p.id)) >= LOTTO_PLAYER_LIMIT:
				_ev("lotto_sold_out", p, {})            # Info.txt 68「乐透号码已售完」
			else:
				p["lotto_can_pick"] = true
				log_message.emit("%s 进了乐透，奖金累积到 %d 元" % [p["name"], int(lotto_prize)])
				_ev("lotto_open", p, {"prize": int(lotto_prize), "fee": fee,
					"numbers": lotto_numbers.duplicate(), "picked": -1})
		_:
			log_message.emit("%s 抵达 %s" % [p["name"], ename])
			_ev("event", p, {"eid": eid, "ename": ename})

## 问号路点：原版 Info.txt 3220..3238「命运1..19」。每条文案必须对应
## 已经写入权威状态的结果；无可作用目标时明确说明本次未产生变化。
func _resolve_fate(p: Dictionary) -> void:
	var fate := rng.randi_range(1, 19)
	var number := 0
	var road_name := ""
	var message := ""
	if fate <= 9:
		var lo := int(Rules.get_val("events.news_bonus_min", 1000))
		var hi := int(Rules.get_val("events.news_bonus_max", 10000))
		number = _round100(rng.randi_range(lo, hi))
		if fate <= 4:
			p["money"] = int(p["money"]) + number
			_ev("win_money", p, {"amount": number, "eid": "tvnews"})
		else:
			number = mini(number, int(p["money"]))
			p["money"] = int(p["money"]) - number
			_ev("lose_money", p, {"amount": number, "eid": "tvnews"})
	match fate:
		10:
			var proceeds := 0
			for company in (p.get("holdings", {}) as Dictionary).keys():
				var shares := int(p["holdings"][company])
				proceeds += int(float(shares) * stock_price(str(company)))
				p["holdings"][company] = 0
				_check_chairman(p, str(company))
			p["money"] = int(p["money"]) + proceeds
			message = "变卖所有股票，获得%d元。" % proceeds
		11:
			_send_to_hospital(p, stamina_max(), "fate")
		12:
			p["effects"]["alien_until"] = time + 3.0 * Rules.seconds_per_day()
			p["moving"] = 0
			p["progress"] = 0.0
			_clear_chance(p)
		13:
			var count := (p["cards"] as Array).size()
			p["cards"] = []
			p["card_locks"] = {}
			message = "变卖所有卡片，共失去%d张。" % count
		14, 15, 19:
			var owned: Array = []
			for key in unique_plot_keys():
				if int(plots[key].get("owner", -1)) == int(p["id"]): owned.append(key)
			if owned.is_empty():
				message = "命运事件：没有可受影响的地产，本次没有变化。"
			elif fate == 14:
				var taken := int(owned[rng.randi_range(0, owned.size() - 1)])
				road_name = map.street_of(taken)
				for key in plots.keys():
					if int(plots[key].get("anchor", key)) == taken: plots.erase(key)
			elif fate == 15:
				var damaged := int(owned[rng.randi_range(0, owned.size() - 1)])
				road_name = map.street_of(damaged)
				_downgrade_estate(damaged)
			else:
				owned.shuffle()
				var raised := 0
				for key in owned.slice(0, 3):
					var level := int(plots[key].get("level", 0))
					var next := Rules.house_next_level(str(plots[key].get("type", "")), level)
					if next > 0:
						plots[key]["level"] = next
						plots[key]["building_grade"] = Rules.house_local_grade(str(plots[key].type), next)
						raised += 1
				message = "福神显灵，%d栋房屋等级上升。" % raised
		16:
			var before := (p["cards"] as Array).size()
			for i in range(3): _give_random_card(p, "命运事件")
			message = "意外得到%d张卡片。" % maxi(0, (p["cards"] as Array).size() - before)
		17, 18:
			var pets: Array = p["pets"]
			if pets.is_empty():
				message = "命运事件：没有携带小神仙，本次没有变化。"
			else:
				var index := rng.randi_range(0, pets.size() - 1)
				var pet_id := str(pets[index].get("id", ""))
				if fate == 17:
					var old := int(pets[index].get("level", 1))
					pets[index]["level"] = mini(PET_LEVEL_CAP, old + 1)
					message = "%s受到精灵祝福，升到%d级。" % [pet_name(pet_id), int(pets[index]["level"])]
				else:
					pets.remove_at(index)
					if str(p.get("pet_active", "")) == pet_id:
						p["pet_active"] = str(active_pet(p).get("id", ""))
					message = "幽灵出现，%s受惊飞走。" % pet_name(pet_id)
	if message == "":
		message = Rules.info_fill(3219 + fate, {"number": str(number), "road": road_name})
	log_message.emit("%s 遇到命运事件：%s" % [p["name"], message.replace("\n", "")])
	_ev("fate", p, {"eid": "tvnews", "fate": fate, "text": message,
		"amount": number})

## 给玩家一张随机卡（卡片商店 / 卡片点共用）
# ------------------------------------------------------------ 手牌（卡片栏）

## 卡片栏**最多 5 张**；**同种卡叠加、只占一个栏位**；满栏时新卡把
## **最前方（最早获得、且未锁定）** 的那张顶掉；锁定的卡不会被顶。
##
## ⚠ 依据 = **老板 2026-09-26 的原版实机观察**。
##   `Initvar_r.txt` 里**没有**手牌上限这一项（整表只有 25 个 Card_* 效果参数），
##   只有 `Card_FuShen_NumCard = 5`「福神卡得到 5 张卡片」→ 至少能一次拿 5 张，与上限 5 自洽。
const HAND_MAX := 5


## 手牌里占几个栏位（同种只算一个）
func hand_slots(p: Dictionary) -> int:
	var seen := {}
	for c in (p.get("cards", []) as Array):
		seen[str(c)] = true
	return seen.size()


## 往手牌加一张卡。返回 `{added: bool, dropped: String, reason: String}`。
##   · 同种已有 → 直接叠上去（不占新栏位）
##   · 是新种类且栏位已满 → 顶掉**最前方未锁定**的那张
##   · 全部锁着 → 加不进来（reason = all_locked）
func _push_card(p: Dictionary, card_id: String) -> Dictionary:
	var cards: Array = p["cards"]
	if cards.has(card_id):
		cards.append(card_id)
		return {"added": true, "dropped": "", "reason": ""}
	var locks: Dictionary = p.get("card_locks", {})
	# 「最前方」= 获得顺序里的第一个（cards 本来就是 append 出来的，天然有时序）
	var uniq: Array = []
	for c in cards:
		if not uniq.has(c):
			uniq.append(c)
	var dropped := ""
	if uniq.size() >= HAND_MAX:
		var victim := ""
		for c in uniq:                       # 从最前方往后找第一张没锁的
			if not bool(locks.get(str(c), false)):
				victim = str(c)
				break
		if victim == "":
			return {"added": false, "dropped": "", "reason": "all_locked"}
		var keep: Array = []
		for c in cards:
			if str(c) != victim:
				keep.append(c)
		p["cards"] = keep
		dropped = victim
	(p["cards"] as Array).append(card_id)
	return {"added": true, "dropped": dropped, "reason": ""}


## 锁定 / 解锁一张卡（卡片菜单 id 2「锁定」）。锁定的卡不会被新卡顶掉。
func act_lock_card(id: int, card_id: String) -> bool:
	var p: Dictionary = players.get(id, {})
	if p.is_empty() or not (p["cards"] as Array).has(card_id):
		return false
	var locks: Dictionary = p.get("card_locks", {})
	locks[card_id] = not bool(locks.get(card_id, false))
	p["card_locks"] = locks
	log_message.emit("%s %s了「%s」" % [p["name"],
		"锁定" if bool(locks[card_id]) else "解锁", Rules.card_name(card_id)])
	_ev("card_lock", p, {"card": card_id, "locked": bool(locks[card_id])})
	return true


## 手牌是不是锁着的
func card_locked(p: Dictionary, card_id: String) -> bool:
	return bool((p.get("card_locks", {}) as Dictionary).get(card_id, false))

func _prune_card_lock(p: Dictionary, card_id: String) -> void:
	if not (p.get("cards", []) as Array).has(card_id):
		(p.get("card_locks", {}) as Dictionary).erase(card_id)


## 给卡时的统一日志/事件（满栏顶卡、全锁定拿不到）
func _report_card_push(p: Dictionary, res: Dictionary, cname: String) -> void:
	var drop := str(res.get("dropped", ""))
	if drop != "":
		log_message.emit("卡片栏已满，顶掉最前方的「%s」" % Rules.card_name(drop))
		_ev("card_dropped", p, {"card": drop, "name": Rules.card_name(drop)})


func _give_random_card(p: Dictionary, ename: String) -> void:
	var c := _random_card()
	var cname := str(Rules.card_by_id(c).get("name", c))
	var res := _push_card(p, c)
	if not bool(res["added"]):
		log_message.emit("%s 的卡片栏满了（全锁着），「%s」没拿到" % [p["name"], cname])
		_ev("hand_full", p, {"card": c, "name": cname})
		return
	_report_card_push(p, res, cname)
	log_message.emit("%s 在%s获得卡片「%s」" % [p["name"], ename, cname])
	_ev("get_card", p, {"card": c, "name": cname})

## 地图上另一处 platform 格的索引（没有第二处就返回 -1）
## 另一处**传送平台**格（本图没有就返回 -1）。
##
## ⚠ 必须跳过**路径索引相邻**的平台格：埃及的 2 格平台（索引 24 / 25）其实是
##   **同一座传送门的两格** —— 它们在路径上前后脚，世界里却隔了 13.9 单位（≈3 格），
##   也就是说「传送」这件事**已经体现在路径本身**了。
##   若把它们当成互为目的地，玩家从 24 走 1 格到 25 就会被原样传回 24，
##   看起来正是「掷 1 点留在原地」（老板 2026-09-26 反馈）。
func _other_platform(idx: int) -> int:
	var n := map.tile_count()
	for i in range(n):
		if i == idx or str(map.tile(i).get("event", "")) != "platform":
			continue
		if _tile_distance(i, idx) <= 1:
			continue                  # 相邻 → 同一座传送门的两格，不是「另一处」
		return i
	return -1


## 某格的事件 key（`config/Roadevent.txt` 里的英文名：platform / cardshop / coupon20 …）
func _event_key(idx: int) -> String:
	if map == null or idx < 0 or idx >= map.tile_count():
		return ""
	return str(map.tile(idx).get("event", ""))


## 传送到地图上另一处传送平台，返回目标格（-1 = 本图没有第二处）。
##
## ⚠ 由 `_advance` 的**逐格循环**调用 —— 也就是说「**经过**传送平台也会被传送」。
##   原来的实现只在 `_arrive`（停下来那一刻）判，于是玩家可以「路过而停在」传送平台上；
##   此时再掷 1 点走 1 格就正好到了传送门的**另一端**，又被原样传回来 ⇒
##   看起来就是「掷 1 点留在原地」（老板 2026-09-26 反馈的现象）。
##   旁证：埃及这 2 格传送平台在**路径索引上相邻**，世界里却隔了 **13.9 单位（≈3 格）**
##   —— 正是「传送门的两端」该有的样子（`aiji_tilepos.json` 格 24 / 25）。
func _teleport_platform(p: Dictionary, idx: int) -> int:
	var dest := _other_platform(idx)
	if dest < 0:
		return -1
	p["tile"] = dest
	p["progress"] = 0.0
	p["moving"] = 0                  # 传送结束本次移动（原版无明文依据，取更保守的行为）
	p["_teleported"] = true          # 同一段行走内不再被传送（防 A→B→A 死循环）
	log_message.emit("%s 踩上传送平台，被送到另一处" % p["name"])
	_ev("platform", p, {"idx": idx, "to": dest})
	return dest

func _round100(v: int) -> int:
	return int(round(float(v) / 100.0)) * 100

func _random_card() -> String:
	var cs := Rules.cards()
	if cs.is_empty():
		return "step1"
	return cs[rng.randi_range(0, cs.size() - 1)].get("id", "step1")

func _transfer(from_p, to_p, amount: int, reason: String) -> void:
	## 转账；from_p 为 null 表示支付给银行
	amount = int(amount)
	if from_p != null:
		from_p["money"] = int(from_p["money"]) - amount
	if to_p != null:
		to_p["money"] = int(to_p["money"]) + amount
	elif from_p != null:
		lotto_prize += amount
	# 破产判定
	for id in player_ids():
		var q: Dictionary = players[id]
		if q["alive"] and int(q["money"]) < 0:
			q["alive"] = false
			_release_plots(id)
			log_message.emit("%s 破产出局（%s）" % [q["name"], reason])
			_ev("bankrupt", q, {"reason": reason})
			_check_winner()

func _release_plots(id: int) -> void:
	for k in plots.keys():
		if int(plots[k]["owner"]) == id:
			plots.erase(k)

func _check_winner() -> void:
	var alive := []
	for id in player_ids():
		if players[id]["alive"]:
			alive.append(id)
	if alive.size() <= 1:
		running = false
		winner = alive[0] if alive.size() == 1 else -1
		log_message.emit("游戏结束！")
		_ev("win", players.get(winner, null))

# ------------------------------------------------------------- 玩家动作（校验）

func act_roll(id: int, dice_count: int = 1, dreamwalk_auto: bool = false) -> bool:
	## 掷骰 —— 即时制下掷出后角色连续移动。
	## dice_count = 一次同时掷几颗（原版 GO 钮左侧的骰子选择器，见 DICE_PER_ROLL_MAX）。
	var p: Dictionary = players.get(id, {})
	var blocked := _roll_block_code(p)
	if blocked != "" and blocked != "stamina" and not (dreamwalk_auto and blocked == "sleepwalk"):
		return false
	# 挂机惩罚由玩家主动结束；即使当前体力不足，也先退出休息动画。
	if float(p["effects"].get("rest_until", 0.0)) > time:
		p["effects"]["rest_until"] = 0.0
		p["idle"] = 0.0
		_ev("wake", p)
	# 原版「自己走所需要最小体力值」——体力不够不给出发
	if float(p.get("stamina", 0.0)) < stamina_min_start() and not dreamwalk_auto:
		var missing := stamina_min_start() - float(p.get("stamina", 0.0))
		log_message.emit("%s 体力不足（%.0f/%.0f），还要歇 %.0f 秒" % [
			p["name"], float(p["stamina"]), stamina_max(),
			missing / maxf(stamina_regen(), 0.001)])
		_ev("no_stamina", p, {"stamina": float(p["stamina"]), "need": stamina_min_start()})
		return false
	# 卡片造成的冬眠/梦游仍按倒计时生效。
	var d := clampi(dice_count, 1, DICE_PER_ROLL_MAX)
	# Migrate a pending activation from older saves to the same step chooser.
	var remote := int(p["effects"].get("pet_max_dice", 0)) > 0
	if remote:
		p["effects"]["pet_max_dice"] = int(p["effects"]["pet_max_dice"]) - 1
		p["pending_steps"] = true
		p["pending_steps_source"] = "dushen"
		_ev("card_choose_steps", p, {"pet": "dushen"})
		return true
	var faces: Array = []
	var n := 0
	for i in d:
		var f := rng.randi_range(1, 6)
		faces.append(f)
		n += f
	p["moving"] = n
	p["walked_this_move"] = 0
	p["idle"] = 0.0
	# 先播掷骰动画（抛出 → 抛物线落下 → 定格），这段时间角色站着不动；
	# step() 里按这个时刻放行。原版就是这个节奏（老板 2026-09-26 反馈）
	p["move_after"] = time + ROLL_ANIM_SECONDS
	p["last_roll"] = n
	p["last_faces"] = faces          # 每颗骰子各自的点数（GO 钮逐颗亮出来）
	if d > 1:
		var parts: PackedStringArray = []
		for f in faces:
			parts.append(str(f))
		log_message.emit("%s 掷出 %s = %d 点" % [p["name"], " + ".join(parts), n])
	else:
		log_message.emit("%s 掷出 %d 点" % [p["name"], n])
	_ev("roll", p, {"n": n, "dice": d, "faces": faces})
	return true

# ------------------------------------------------------------- 地产主题 / 等级

## 本图允许建设的房屋主题。来源：原版 scene/<map>/<map>.txt 的 buildinfo 行，
## 例：paris 是「industry 0  shop 1  uptown 0」→ 只能建商业区；
##     aiji / china / japan / island / train 是「1 1 1」→ 三种都能建。
## 原版 Info.txt id 92「建设 … 选择房屋」并注明
## 「当场景中只能建一种房屋时不出现该讯息」→ 玩家在**建设时**选主题。
func buildable_types() -> Array:
	var out: Array = []
	var bf: Dictionary = map.build_flags if map != null else {}
	for t in Rules.primary_types():
		if int(bf.get(str(t), 0)) > 0:
			out.append(str(t))
	if out.is_empty():
		# space 关的 buildinfo 是「0 0 0」（原版另有玩法）——兜底放行全部，否则没法玩
		out = Rules.primary_types().duplicate()
	return out

func max_level(type_id: String) -> int:
	return Rules.house_max_level(type_id)

## 把 idx 这块地升到「下一级」要付的费用（元）。
## 原版 House.txt 的「升级费」列 = **建成该等级房屋的造价**，逐条可查
## （空地→一级公寓 1000、一级公寓→二级公寓 1000、
##   四级公寓→一级住宅 2000、一级住宅→一级住宅区 3000，越大越贵，单调递增）。
## want_type 用于「空地首次建设」时按玩家挑的房型算价。
func construction_plan(id: int, idx: int, want_type: String = "") -> Dictionary:
	if not plots.has(idx):
		return {}
	var kind := str(plots[idx].get("type", ""))
	var desired_level := 0
	if kind.is_empty():
		var allowed := buildable_types()
		var parts := want_type.split(":")
		var requested := parts[0]
		kind = requested if allowed.has(requested) else (str(allowed[0]) if not allowed.is_empty() else "uptown")
		if parts.size() == 2 and parts[1].is_valid_int() and requested == kind:
			desired_level = int(parts[1])
			var grades := Rules.house_grades(kind)
			if desired_level < 1 or desired_level > grades.size() or int(grades[desired_level - 1].level) != desired_level:
				return {}
	return PlotAssembly.plan(map, plots, id, idx, kind, desired_level)

func upgrade_cost(p: Dictionary, idx: int, want_type: String = "") -> int:
	var plan := construction_plan(int(p["id"]), idx, want_type)
	return int(plan.get("cost", 0))

func _commit_construction(idx: int, plan: Dictionary, paid_cost: int = 0) -> void:
	lotto_prize += paid_cost
	var estate: Dictionary = plots[idx]
	var seen: Array = []
	var paid_base := 0.0
	for member in plan.members:
		var old: Dictionary = plots.get(int(member), {})
		var old_anchor := int(old.get("anchor", member))
		if seen.has(old_anchor): continue
		seen.append(old_anchor)
		paid_base += float(old.get("paid_base", 200.0))
	estate["paid_base"] = paid_base + float(paid_cost) / maxf(price_scale(), .001)
	if int(estate.level) == 0:
		estate["build_start_level"] = int(plan.level)
	estate["type"] = plan.type
	estate["level"] = plan.level
	estate["building_grade"] = Rules.house_local_grade(str(plan.type), int(plan.level))
	estate["anchor"] = plan.anchor
	estate["members"] = plan.members.duplicate()
	estate["footprint"] = plan.footprint
	estate["build_cell"] = int(plan.get("cell", -1))
	for member in plan.members:
		plots[int(member)] = estate # One authoritative estate, shared by all road frontages.

func unique_plot_keys() -> Array:
	var result: Array = []
	for key in plots.keys():
		var anchor := int(plots[key].get("anchor", key))
		if not result.has(anchor):
			result.append(anchor)
	return result

func stock_portfolio_value(p: Dictionary) -> int:
	var total := 0.0
	for company in (p.get("holdings", {}) as Dictionary):
		total += float(p["holdings"][company]) * stock_price(str(company))
	return int(round(total))

func estate_value(p: Dictionary) -> int:
	var total := 0
	for key in unique_plot_keys():
		var estate: Dictionary = plots[key]
		if int(estate.get("owner", -1)) != int(p.get("id", -1)): continue
		total += estate_asset_value(int(key))
	return total

func estate_asset_value(idx: int) -> int:
	return plot_value(idx) if plots.has(idx) else 0

func act_buy(id: int) -> bool:
	## 买下**本次抵达**的空地（原版 id 91）。买地只拿到「空地」，
	## 房屋要等下一次抵达时用升级/建设来做（原版 id 88 把「空地」和「升级」并列）。
	var p: Dictionary = players.get(id, {})
	if p.is_empty() or not p["alive"]:
		return false
	if int(p["effects"].get("sleepwalk_steps", 0)) > 0: return false
	if int(p["effects"].get("no_upgrade_steps", 0)) > 0:
		_ev("buy_blocked", p, {"idx": int(p.get("last_plot", -1))})
		return false
	if int(p["last_plot"]) < 0 or str(p.get("last_plot_kind", "")) != "buy":
		return false
	var idx: int = int(p["last_plot"])
	if plots.has(idx):
		return false
	var price := empty_plot_price(idx)
	if int(p["money"]) < price:
		log_message.emit("%s 资金不足，无法购地" % p["name"])
		_ev("insufficient_money", p, {"idx": idx, "need": price, "have": int(p["money"])})
		return false
	p["money"] = int(p["money"]) - price
	lotto_prize += price
	# type 为空 = 还没建房（原版 id 92 的「选择房屋」发生在建设时）
	_bind_plot(idx, {"owner": id, "level": 0, "type": "", "paid_base": float(price) / maxf(price_scale(), .001)})
	_clear_chance(p)
	log_message.emit("%s 以 %d 元买下 %s（空地，下次再来才能盖房）" % [
		p["name"], price, map.street_of(idx)])
	_ev("buy", p, {"idx": idx, "price": price, "street": map.street_of(idx)})
	return true

func act_upgrade(id: int, want_type: String = "") -> bool:
	## 升级 / 建设**本次抵达**的那块自己的地。
	##
	## 三条原版规矩：
	##   ① 只有「本次抵达」有资格 —— 站在地上连点是升不上去的（id 93 是抵达时的询问）；
	##   ② 一次机会只升一级，用完即消费（想连续升级要么走开再回来，
	##      要么用**停留卡**再结算一次，要么用**升级卡**指定地块）；
	##   ③ 费用取自 House.txt 逐级「升级费」，不是固定 1000。
	var p: Dictionary = players.get(id, {})
	if p.is_empty() or not p["alive"]:
		return false
	if int(p["effects"].get("sleepwalk_steps", 0)) > 0: return false
	var idx: int = int(p["last_plot"])
	if idx < 0 or str(p.get("last_plot_kind", "")) != "upgrade":
		return false
	if not plots.has(idx):
		return false
	var plot: Dictionary = plots[idx]
	if int(plot["owner"]) != id:
		return false

	if int(p["effects"]["no_upgrade_steps"]) > 0:
		log_message.emit("%s 衰神附身中，无法升级" % p["name"])
		_ev("upgrade_blocked", p, {"idx": idx, "street": map.street_of(idx)})
		return false

	# 空地上第一次盖房要先定房型（原版 id 92「选择房屋」）
	var ptype := str(plot.get("type", ""))
	if ptype == "":
		var al := buildable_types()
		if want_type != "" and al.has(want_type.split(":")[0]):
			ptype = want_type.split(":")[0]
		elif al.size() == 1:
			ptype = str(al[0])          # 只有一种房屋时不询问（原版 id 92 批注）
		else:
			log_message.emit("%s 需要先选择房屋类型：%s" % [p["name"], str(al)])
			_ev("need_house_type", p, {"idx": idx, "street": map.street_of(idx), "options": al})
			return false

	var lv: int = int(plot["level"])
	if lv >= max_level(ptype):
		return false
	var plan := construction_plan(id, idx, want_type if lv == 0 and want_type != "" else ptype)
	if plan.is_empty():
		log_message.emit("需要相邻且同属自己的空地，才能扩建该建筑")
		_ev("upgrade_blocked", p, {"idx": idx, "reason": "需要相邻且同属自己的空地"})
		return false
	var target := int(plan.level)
	var cost := int(plan.cost)
	if int(p["money"]) < cost:
		log_message.emit("%s 资金不足，无法升级（需 %d 元）" % [p["name"], cost])
		_ev("insufficient_money", p, {"idx": idx, "need": cost, "have": int(p["money"])})
		return false

	p["money"] = int(p["money"]) - cost
	_commit_construction(idx, plan, cost)
	_clear_chance(p)
	var gname := str(Rules.house_grade(ptype, target).get("name", "%d 级" % target))
	log_message.emit("%s 将 %s 建到 %s（%d 元）" % [p["name"], map.street_of(idx), gname, cost])
	# 原版 id 82「<SOMEONE>升级<ROAD>房屋」——这条是给**其他玩家**看的广播
	_ev("upgrade", p, {"idx": idx, "level": target, "cost": cost,
		"street": map.street_of(idx), "type": ptype, "grade_name": gname})
	return true

func act_pass(id: int) -> bool:
	## 放弃本次抵达留下的机会（不买也不升），把令牌还回去，
	## 否则人站在格子上会一直攥着机会不动。
	var p: Dictionary = players.get(id, {})
	if p.is_empty() or int(p["last_plot"]) < 0:
		return false
	_clear_chance(p)
	return true

## 直接给某块地升一级（不消耗「抵达令牌」）。供升级卡 / 天使卡等卡片使用。
## free_cost = true 时免费（卡片本身即代价）。
func force_upgrade(owner_id: int, idx: int, free_cost: bool,
		want_type: String = "") -> bool:
	if not plots.has(idx) or not players.has(owner_id):
		return false
	var plot: Dictionary = plots[idx]
	if int(plot["owner"]) != owner_id:
		return false
	var p: Dictionary = players[owner_id]
	if int(p["effects"]["no_upgrade_steps"]) > 0:
		return false                       # 衰神附身中，卡片也盖不了
	var plan := construction_plan(owner_id, idx, want_type)
	if plan.is_empty():
		return false
	var cost := 0 if free_cost else int(plan.cost)
	if int(p["money"]) < cost:
		return false
	p["money"] = int(p["money"]) - cost
	_commit_construction(idx, plan, cost)
	_ev("upgrade", p, {"idx": idx, "level": int(plan.level), "cost": cost,
		"street": map.street_of(idx), "type": str(plan.type), "forced": true})
	return true

## 挑一块「还升得动」的自己的地，等级最高的优先（租金收益最大）
func _own_plot_to_upgrade(id: int) -> int:
	var best := -1
	var best_lv := -1
	for k in unique_plot_keys():
		var pl: Dictionary = plots[k]
		if int(pl["owner"]) != id:
			continue
		var t := str(pl.get("type", ""))
		var mx := max_level(t) if t != "" else Rules.FALLBACK_MAX_LEVEL
		if int(pl["level"]) >= mx or construction_plan(id, int(k)).is_empty():
			continue
		if int(pl["level"]) > best_lv:
			best_lv = int(pl["level"])
			best = int(k)
	return best

## 挑一块对手的、等级最高的地（怪兽卡 / 破坏类卡片的目标）
func _enemy_plot_best(id: int) -> int:
	var best := -1
	var best_lv := -1
	for k in unique_plot_keys():
		var pl: Dictionary = plots[k]
		if int(pl["owner"]) == id:
			continue
		if int(pl["level"]) > best_lv:
			best_lv = int(pl["level"])
			best = int(k)
	return best

## 该地产的「现值」= 买地价 + 已投入的建造费（1..level 级造价累加）。
## 购地卡强制购买时按这个价付给原主。
func plot_value(idx: int) -> int:
	if not plots.has(idx):
		return empty_plot_price(idx)
	var pl: Dictionary = plots[idx]
	var cells := {}
	for member in pl.get("members", [idx]): cells[map.plot_frontages(int(member))[0]] = true
	var factor := 0.0
	for cell in cells: factor += _land_factor(int(cell))
	# 42b320 averages the footprint's coefficients instead of counting entrances.
	factor /= maxi(1, cells.size())
	var v := float(Rules.get_val("economy.empty_grid_price_factor", 200)) * estate_index * factor / 10.0
	var tp := str(pl.get("type", ""))
	for lv in range(maxi(1, mini(int(pl.get("build_start_level", 1)), int(pl["level"]))), int(pl["level"]) + 1):
		v += Rules.house_upgrade_cost(tp, lv) * price_scale() * (1.0 if tp == "industry" else factor / 10.0)
	return int(round(v * float(pl.get("price_mul", 1.0))))


## 这张卡**此刻**能不能用？0 = 能用；非 0 = 原版 String.txt 的原因文案编号：
##   60 现金不足 / 61 不能使用卡片 / 62 当前位置没有地产 / 63 只能用于对手的地产 /
##   64 只能用于自己的地产 / 65 没有建筑 / 66 不能放置道具 / 67 没有可以组合的卡片
## UI 据此**压暗**卡片，点它时把原因说出来 —— 而不是「亮着但点了没反应」。
##
## 判定依据两条：
##   ① `config/String.txt` 第 63..73 行「不能用卡片1..9」，**每条后面带原版自己的批注**
##      点名适用卡（例：id 63 后面写着「（土神卡， 购地卡等）」）；
##   ② 每张效果在 `_apply_card` 里 return false 的前置条件，逐条镜像过来。
## ⚠ 原版没有留下「卡 → 原因码」的映射表，这里是 ①+② 对上来的**推导**，语料里
##   只有这九条可用于此。登记在 docs/ui-audit.md §12。
## 格子的**原版事件编号**（`Roadevent.txt` 的 1..16；非事件格返回 -1）。
##   1 传送平台 · 2 卡片商店 · 3 医院 · **4 卡片点** · 5 电视台 · 6 拉霸 ·
##   **7 市政府** · 8 精灵屋 · 9/10 游戏点 · 11~15 点券5/10/20/30/50 · **16 乐透**
func _event_num(idx: int) -> int:
	if map == null or idx < 0 or idx >= map.tile_count():
		return -1
	var t: Dictionary = map.tile(idx)
	if str(t.get("kind", "")) != "event":
		return -1
	return int(t.get("original_kind", -1))


## 骰子卡：**往前 `steps` 格的落点是否可用** —— 原版 `FUN_004213c0` 的判定。
##
## 原版的四条放行条件（现已**全部**落实）：
##   ① 落点是**卡片点(4) / 市政府(7) / 乐透(16)** ——
##      这三个数来自 `FUN_004213c0` 里的 `type == 4 / 0x10 / 7`，
##      对应 `Roadevent.txt` 的事件编号（见 `docs/rea-2026-10-16/C14-门禁对比-骰子卡.md`）
##   ② 落点**无主**
##   ③ 落点是**自己的**
##   （④ 落点是自己且「没建筑 / 建筑组合合法」= ③ 的细分）
##
## ⚠️ 注意原版**没有**「落点不能是别人的地产」这条排除 —— 别人的地不在放行列表里，
##   所以等价于「不选别人的地」。这里照此实现。
func _step_landing_ok(p: Dictionary, steps: int) -> bool:
	var idx := _wrap(int(p["tile"]) + int(p["dir"]) * steps)
	# ① 好事格：卡片点 / 市政府 / 乐透
	var en := _event_num(idx)
	if en == 4 or en == 7 or en == 16:
		return true
	# ② 无主（空地 / 还没人买）
	if not plots.has(idx):
		return true
	# ③ 自己的
	return int(plots[idx].get("owner", -1)) == int(p["id"])


func card_usable(id: int, card_id: String) -> int:
	var p: Dictionary = players.get(id, {})
	if time < float(p.get("entry_until", 0.0)): return 61
	if p.is_empty() or not bool(p["alive"]):
		return 61
	if time < float(p["effects"].get("hotel_until", 0.0)): return 61
	if time < float(p["effects"].get("hospital_until", 0.0)):
		return 61
	# ⚠ 不拦「正在走」—— 即时制下角色一直在走，而原版的停留卡（9040「原地停留一次」）
	#   正是**走着的时候**用的（强制停下）。只有「骰子卡正在等你点步数」才是真正的
	#   模态状态，不能插队。
	if bool(p.get("pending_steps", false)):
		return 61
	if CARD_UNSUPPORTED.has(card_id):
		return 67
	if Rules.base_card_id(card_id) == "gem":
		for other in p.cards:
			if Rules.can_gem_combine(str(other)): return 0
		return 67
	# 复制卡：手里得有**别的**卡可复制（`String.txt` 67「没有可以组合的卡片」）
	if card_id == "copy":
		var has_other := false
		for cc in (p["cards"] as Array):
			if str(cc) != "copy":
				has_other = true
				break
		if not has_other:
			return 67
	var eff := str(Rules.card_by_id(card_id).get("effect", ""))
	# 骰子卡：**至少要有一个「落点可用」的步数**才允许用。
	# 依据原版 `FUN_004213c0`（骰子卡门禁，见 docs/rea-2026-10-16/C14-门禁对比-骰子卡.md）：
	#   它从 1 步开始逐格试算，要求落点满足「特殊格 / 无主 / 自己的」之一。
	#   ⚠️ 原版还有「落点格子类型 == 4 / 0x10 / 7 → 可用」一条，那三个值含义未明，
	#     这里**只实现能确定的两条**（无主 / 自己的），宁可少给不能多给。
	#   ⚠️ 原版步数只算 `1..5`（`n < 6`）；我们的选择器是 1..6，
	#     这里先按**原版范围**判定（见下文待办）。
	if eff == "reroll":
		var any_ok := false
		for n in range(1, 6):
			if _step_landing_ok(p, n):
				any_ok = true
				break
		if not any_ok:
			return 61                  # String.txt 61「不能使用卡片」
	# 原版 `FUN_00421240`（1~5 步卡共用的门禁）的判定⑥：
	#   **当前状态是 8 或 9 时，步卡不可用** —— 状态 9 就是小财神「免费」。
	#   见 `docs/rea-2026-10-16/共用判定函数.md`。
	#   ⚠️ 这条以前完全没有（被小财神附身的人照样能走步卡）。
	if eff == "move":
		var cur := current_status(p)
		if cur == 8 or cur == 9:
			return 61                  # String.txt 61「不能使用卡片」
	# 红卡 / 黑卡：要有股票可动（本图得有上市公司）
	if eff == "stock_up" or eff == "stock_down":
		if stocks.is_empty():
			return 61
	# 点选类目标是否给得起（红黑卡要选一种股票）
	if card_target(card_id) == "stock" and stocks.is_empty():
		return 61
	var here := int(p["tile"])
	var owned := plots.has(here)
	var enemy_here := owned and int(plots[here]["owner"]) != id
	var street := _current_street(here)
	match eff:
		# ---- String.txt 63 批注点名的那两组：目标必须是**对手的地产** ----
		# （空地本来就能直接买，所以这两张卡只对「已有主的地」才有意义）
		"buy_any_plot":
			if not enemy_here:
				return 63
			if int(p["money"]) < plot_value(here):
				return 60                  # String.txt 60「现金不足」
		"free_land":
			if not enemy_here:
				return 63
		# ---- 要有「自己的地」才能操作的 ----
		"change_building_type":
			if not plots.has(here): return 65
			if int(plots[here].level) <= 0: return 65
			if not Rules.primary_types().has(str(plots[here].type)): return 65
		"upgrade_building":
			if _own_plot_to_upgrade(id) < 0 and not _has_own_plot(id):
				return 64                  # String.txt 64「只能用于自己的地产」
			if eff == "upgrade_building" and _own_plot_to_upgrade(id) < 0:
				return 65                  # 自己的房子都满级了 / 一栋都没有
		"auto_upgrade":
			var can_upgrade := false
			for k in _street_plots(street):
				if int(plots[k]["level"]) > 0 and int(plots[k]["level"]) < Rules.house_max_level(str(plots[k]["type"])):
					can_upgrade = true
			if not can_upgrade: return 65
		# ---- 要有「可破坏的目标」的 ----
		"auto_downgrade":
			var n := 0
			for k in _street_plots(street):
				if int(plots[k]["level"]) > 0:
					n += 1
			if n == 0:
				return 65                  # String.txt 65「没有建筑」
		"downgrade_building":
			if card_map_candidates(id, card_id).is_empty():
				return 65
		"destroy_buildings", "nuke":
			if card_road_candidates(id, card_id).is_empty(): return 61
		# ---- 要有路面道具可清 ----
		"remove_obstacle":
			# ⚠️ 范围**不是写死的 7** —— 原版从 `card.crd` 的 `+0x220` 按地图读
			#   （埃及等 6 图 = 7，**太空 = 9**）。以前这里写死 `range(1, 8)`，
			#   数字碰对了但来源错，太空图会少清 2 格。
			#   见 docs/rea-2026-10-16/card-crd-解析.md
			var span := card_param(card_id)
			if span <= 0:
				span = 7                   # 兜底（数据缺失时维持旧行为）
			var found := false
			for step_ahead in range(1, span + 1):
				var road_ahead := _wrap(here + int(p["dir"]) * step_ahead)
				if not _obstacle_at(road_ahead).is_empty() or road_objs.has(road_ahead):
					found = true
					break
			if not found: return 61
	return 0


func _has_own_plot(id: int) -> bool:
	for k in plots.keys():
		if int(plots[k]["owner"]) == id:
			return true
	return false


func _has_obstacle_ahead(p: Dictionary, n: int) -> bool:
	for i in range(1, n + 1):
		if not _obstacle_at(_wrap(int(p["tile"]) + int(p["dir"]) * i)).is_empty():
			return true
	return false


func act_use_card(id: int, card_id: String, target: int = -1,
		target_name: String = "") -> bool:
	## 使用一张手牌。
	## target = player 卡的目标玩家 id，或 road 卡的目标道路节点索引。
	## target_name = 需要「点选一种股票」时的目标**公司名**（红卡 / 黑卡）。
	## 返回 false 一律**不消耗**卡片 —— 条件不满足时把卡留着，别让玩家白扔。
	var p: Dictionary = players.get(id, {})
	if p.is_empty() or not p["alive"]:
		return false
	var arr: Array = p["cards"]
	var at := arr.find(card_id)
	if at < 0:
		return false

	var cname := Rules.card_name(card_id)

	# 股票 / 卡片组合子系统尚未实现 → 对应卡暂不可用（卡片保留）
	if CARD_UNSUPPORTED.has(card_id):
		var ucode := 67 if card_id == "copy" else 61
		log_message.emit("%s 的「%s」暂时用不了（对应子系统未实现，卡片保留）" % [p["name"], cname])
		_ev("card_unavailable", p, {"card": card_id, "name": cname, "code": ucode})
		return false

	# 使用前的门禁 —— 原版有整套「不能用卡片1..9」的原因码（String.txt 61..70）。
	# 这里必须**发事件**（带原因码），否则 UI 看起来就是「点了没反应」（老板 2026-09-26 反馈）。
	var bad := card_usable(id, card_id)
	if bad != 0:
		log_message.emit("%s 的「%s」用不了：%s" % [p["name"], cname, Rules.ui_string(bad)])
		_ev("card_unavailable", p, {"card": card_id, "name": cname, "code": bad})
		return false

	# 需要点选对手的卡：先要一个合法目标（String.txt 1101「请选择对手」）
	if card_needs_player(card_id):
		var tp: Dictionary = players.get(target, {})
		if tp.is_empty() or not card_target_candidates(id, card_id).has(target):
			_ev("need_card_target", p, {"card": card_id, "name": cname,
				"target_kind": "player", "prompt": Rules.card_target_prompt("player")})
			return false

	if card_target(card_id) == "road" and not card_road_candidates(id, card_id).has(target):
		_ev("need_card_target", p, {"card": card_id, "name": cname,
			"target_kind": "road", "prompt": "请选择亮绿圈的路点"})
		return false
	if card_target(card_id) == "building" and target >= 0 and not card_map_candidates(id, card_id).has(target):
		_ev("card_unavailable", p, {"card": card_id, "name": cname, "code": 65})
		return false
	var c := Rules.card_by_id(card_id)
	# Reserve the consumed slot: effects can replace the hand array.
	var original_hand := arr.duplicate()
	arr.remove_at(at)
	if not _apply_card(p, Rules.base_card_id(card_id), c, p["effects"], target, target_name):
		p["cards"] = original_hand
		# 门禁过了但效果没生效（典型：对手身上没东西可抢）→ 也要给反馈，不静默
		_ev("card_unavailable", p, {"card": card_id, "name": cname, "code": 61})
		return false
	_prune_card_lock(p, card_id)
	log_message.emit("%s 使用 %s" % [p["name"], cname])
	var result := "%s 使用了%s" % [p["name"], cname]
	if Rules.base_card_id(card_id) in ["shuaishen", "qiongshen"]:
		result = "%s 已被%s附身：%d 步内%s" % [players[target]["name"], cname.trim_suffix("卡"),
			int(c.get("steps", 30)), "不能购地或升级" if Rules.base_card_id(card_id) == "shuaishen" else "过路费加倍"]
	elif card_id in ["missile", "nuke"]:
		result = "%s已发射，目标：%s（路点 %d）" % [cname, map.street_of(target), target]
	_ev("use_card", p, {"card": card_id, "name": cname,
		"effect": str(c.get("effect", "")), "target": target,
		"result": result})
	return true


## 丢弃一张手牌（String.txt 卡片菜单 id 3「丢弃」）
func act_discard_card(id: int, card_id: String) -> bool:
	var p: Dictionary = players.get(id, {})
	if p.is_empty():
		return false
	var arr: Array = p["cards"]
	var at := arr.find(card_id)
	if at < 0:
		return false
	arr.remove_at(at)
	_prune_card_lock(p, card_id)
	log_message.emit("%s 丢弃了 %s" % [p["name"], Rules.card_name(card_id)])
	_ev("discard_card", p, {"card": card_id, "name": Rules.card_name(card_id)})
	return true


## 「喂食」：把一张卡喂给小神仙 → **只增加饱食度**（**不升级**）。
##
## Feeding adds the native card record value directly as internal energy.
## ⚠️ 上一轮我做成「喂食让等级 +1」，那是错的，已改。
## 原版卡片字段决定喂食量 1..5 内部能量；显示比例依该宠物上限换算。
func act_feed_card(id: int, card_id: String) -> bool:
	var p: Dictionary = players.get(id, {})
	if p.is_empty() or not bool(p["alive"]):
		return false
	var pets: Array = p["pets"]
	if pets.is_empty():
		_feed_refuse(p, "身上没有小神仙")
		return false
	var at: int = (p["cards"] as Array).find(card_id)
	if at < 0:
		return false
	# 只喂当前出战的精灵；吃饱时保留卡片。
	var current_pet := active_pet(p)
	var best := pets.find(current_pet) if not current_pet.is_empty() and not pet_skill_ready(current_pet) else -1
	if best < 0:
		_feed_refuse(p, "当前出战的小神仙已经吃饱了")
		return false
	(p["cards"] as Array).remove_at(at)
	_prune_card_lock(p, card_id)
	var d: Dictionary = pets[best]
	var gained := pet_feed_value(card_id)
	_set_pet_energy(d, pet_energy(d) + gained)
	var full := float(d["fullness"]) >= PET_FULLNESS_MAX
	if full: d["ready"] = true
	log_message.emit("%s 把「%s」喂给 %s（饱食度 %d/%d%s）" % [p["name"],
		Rules.card_name(card_id), pet_name(str(d["id"])), int(d["fullness"]),
		int(PET_FULLNESS_MAX), "，可以发动技能了" if full else ""])
	_ev("feed_card", p, {"card": card_id, "pet": str(d["id"]),
		"gained": int(gained), "fullness": int(d["fullness"]), "full": full})
	return true


func _feed_refuse(p: Dictionary, why: String) -> void:
	log_message.emit("%s 喂不了卡：%s" % [p["name"], why])
	_ev("feed_refused", p, {"why": why})


## 骰子卡：自选步数（String.txt 9016「自由选择前进的步数」）
func act_walk(id: int, steps: int) -> bool:
	var p: Dictionary = players.get(id, {})
	if p.is_empty() or not p["alive"] or int(p["moving"]) > 0:
		return false
	if _roll_block_code(p) != "choose_steps": return false
	if not bool(p.get("pending_steps", false)):
		return false
	p["pending_steps"] = false
	var n := clampi(steps, 1, 6)
	p["moving"] = n
	p["walked_this_move"] = 0
	p["idle"] = 0.0
	p["move_after"] = time + ROLL_ANIM_SECONDS   # 同掷骰：先把骰子抛出来定格再走
	p["last_roll"] = n
	p["last_faces"] = [n]
	var source := "小赌神" if str(p.get("pending_steps_source", "")) == "dushen" else "骰子卡"
	p.erase("pending_steps_source")
	log_message.emit("%s 用%s前进 %d 步" % [p["name"], source, n])
	_ev("roll", p, {"n": n, "dice": 1, "faces": [n], "by_card": "dice"})
	return true


## 真正执行卡的效果。返回 false = 没生效（卡片保留）。
func _apply_card(p: Dictionary, card_id: String, c: Dictionary, e: Dictionary,
		target: int, target_name: String = "") -> bool:
	var pid := int(p["id"])
	var here := int(p["tile"])
	var street := _current_street(here)
	var eff := str(c.get("effect", ""))
	if eff == "combine_card":
		if not Rules.can_gem_combine(target_name): return false
		var chosen := (p.cards as Array).find(target_name)
		if chosen < 0: return false
		(p.cards as Array).remove_at(chosen)
		var output_card := Rules.gem_result(target_name)
		if not bool(_push_card(p, output_card).get("added", false)): return false
		_ev("combine_card", p, {"card": output_card, "name": Rules.card_name(output_card)})
		return true
	# ---- 复制卡（String.txt 9032「复制一张相同的卡片」）----
	# 把手里**另一张**同名卡再复制一份（自己这张会被消耗掉）
	if eff == "copy_card":
		var hand: Array = p["cards"]
		var other := target_name if hand.has(target_name) and target_name != "copy" else ""
		if target_name != "" and other == "": return false
		for cc in hand:
			if other != "": break
			if str(cc) != card_id:
				other = str(cc)
				break
		if other == "":
			return false                  # String.txt 67「没有可以组合的卡片」
		var res := _push_card(p, other)
		if not bool(res["added"]):
			return false
		log_message.emit("%s 的复制卡复制出了「%s」" % [p["name"], Rules.card_name(other)])
		_ev("copy_card", p, {"card": other, "name": Rules.card_name(other)})
		return true
	# 目标 = 玩家点选的那一种股票（`CARD_TARGET` 里就是 `"stock"`）；
	# 幅度 = `Card_HongKa_Price` / `Card_HeiKa_Price`（Initvar_r.txt 都是 0.20）
	if eff == "stock_up" or eff == "stock_down":
		var ratio := float(Rules.get_val(
			"card.hongka_price" if eff == "stock_up" else "card.heika_price", 0.20))
		if eff == "stock_down":
			ratio = -ratio
		return _shift_stock(target_name, ratio, p, card_id)

	match eff:
		# ---------------- 自身状态 ----------------
		"no_rent":
			_clear_attached_gods(p)
			e["no_rent_steps"] = int(c.get("steps", 20))
			log_message.emit("%s 免费卡：%d 步内免付房租" % [p["name"], int(e["no_rent_steps"])])
		"immune":
			_clear_attached_gods(p)
			set_status(p, 1, time + float(c.get("seconds", 72)))   # 原版状态 1（无敌）
			log_message.emit("%s 进入无敌状态 %.0f 秒" % [p["name"], float(c.get("seconds", 72))])
		"invisible":
			_clear_attached_gods(p)
			set_status(p, 11, time + float(c.get("seconds", 72)))  # 原版状态 11（隐形）
			log_message.emit("%s 进入隐形状态 %.0f 秒" % [p["name"], float(c.get("seconds", 72))])
		"move":
			if int(p["moving"]) == 0: p["walked_this_move"] = 0
			p["moving"] = int(p["moving"]) + int(c.get("distance", 1))
			p["idle"] = 0.0
		"reverse_direction":
			p["dir"] = -int(p["dir"])
		"double_speed":
			# Native 41f970: (closed random 1..6 + 6) * 3, doubled when enhanced.
			e["rush_until"] = time + 60.0
			p["speed"] = MOVE_SPEED * 2.0
			var distance := (rng.randi_range(1, 6) + 6) * 3 * (2 if bool(c.get("enhanced", false)) else 1)
			if int(p["moving"]) == 0: p["walked_this_move"] = 0
			p["moving"] = int(p["moving"]) + distance
			p["idle"] = 0.0
			p["move_after"] = time
			log_message.emit("%s 暴走前进 %d 格（不耗体力）" % [p["name"], distance])
		"reroll":
			# 骰子卡：把「走几步」交给玩家点（UI 弹 1..6）
			p["pending_steps"] = true
			log_message.emit("%s 用骰子卡，请选择前进步数" % p["name"])
			_ev("card_choose_steps", p, {"card": card_id})
		"heal":
			# 汉堡卡（9034「补充自己的体力」）—— 原版的 HP 就是即时制的「体力」
			var inc := float(c.get("hp", 500))
			p["stamina"] = minf(stamina_max(), float(p.get("stamina", 0.0)) + inc)
			log_message.emit("%s 吃掉汉堡，体力 +%d" % [p["name"], int(inc)])
		"gain_money":
			_clear_attached_gods(p)
			var amt := rng.randi_range(int(c.get("min", 10000)), int(c.get("max", 50000)))
			p["money"] = int(p["money"]) + amt
			var nr := int(c.get("no_rent_steps", 0))
			if nr > 0:
				e["no_rent_steps"] = nr      # 财神卡额外给「N 步内免付房租」
				_status_feedback(p, p, card_id, "财神附身：免付过路费", nr)
			log_message.emit("%s 得到 %d 元" % [p["name"], amt])
			_ev("win_money", p, {"amount": amt, "card": card_id})
		"summon_stock_god":
			# 请神卡（9007「召唤一位小神仙」）—— 从 Pet.txt 的 **9 只**里随机来一位。
			# 已有该位则升一级；满 5 位且没有该位 → 用不了（Info.txt 202）。
			var cat: Array = pet_catalog()
			if cat.is_empty():
				return false
			var pick: Dictionary = cat[rng.randi_range(0, cat.size() - 1)]
			var pid2 := str(pick.get("id", ""))
			if add_pet(p, pid2) != 0:
				return false
			_ev("use_pet_card", p, {"pet": pid2, "name": pet_name(pid2), "card": card_id})

		# ---------------- 附到对手身上 ----------------
		"rent_double":
			# 穷神卡（9003「指定穷神附身的对象」）
			var t1: Dictionary = players[target]
			if _protected(t1): return false
			_clear_attached_gods(t1)
			t1["effects"]["rent_double_steps"] = int(c.get("steps", 30))
			var loss := rng.randi_range(int(c.get("target_lose_min", 10000)), int(c.get("target_lose_max", 30000)))
			_transfer(t1, p, loss, "穷神卡")
			_status_feedback(p, t1, card_id, "穷神附身：过路费加倍", int(c.get("steps", 30)))
			log_message.emit("%s 让穷神附上 %s：%d 步内房租加倍" % [
				p["name"], t1["name"], int(c.get("steps", 30))])
		"no_upgrade":
			# 衰神卡（9004「指定衰神附身的对象」）
			var t2: Dictionary = players[target]
			if _protected(t2): return false
			_clear_attached_gods(t2)
			t2["effects"]["no_upgrade_steps"] = int(c.get("steps", 30))
			_status_feedback(p, t2, card_id, "衰神附身：不能购地或升级", int(c.get("steps", 30)))
			log_message.emit("%s 让衰神附上 %s：%d 步内不能升级" % [
				p["name"], t2["name"], int(c.get("steps", 30))])
		"steal_ratio":
			# 查税卡（9036「向对手查徵税款」，Card_ChaShui_MinMoney/MaxMoney = 5%/10%）
			var rate := rng.randf_range(float(c.get("min_rate", 0.05)), float(c.get("max_rate", 0.1)))
			var t3: Dictionary = players[target]
			var take := int(float(t3["money"]) * rate)
			if take <= 0:
				return false
			_transfer(t3, p, take, "查税卡")
			log_message.emit("%s 向 %s 查税得 %d 元" % [p["name"], t3["name"], take])
		"steal_card":
			# 抢夺卡（9037「抢夺对手卡片」）
			var t4: Dictionary = players[target]
			var tc: Array = t4["cards"]
			if tc.is_empty():
				return false
			var ci := rng.randi_range(0, tc.size() - 1)
			var stolen: String = str(tc[ci])
			var res := _push_card(p, stolen)
			if not bool(res["added"]):
				log_message.emit("%s 的卡片栏满了（全锁着），抢来的「%s」没放下" % [
					p["name"], Rules.card_name(stolen)])
				_ev("hand_full", p, {"card": stolen})
				return false
			tc.remove_at(ci)
			_prune_card_lock(t4, stolen)
			_report_card_push(p, res, Rules.card_name(stolen))
			log_message.emit("%s 抢走了 %s 的「%s」" % [
				p["name"], t4["name"], Rules.card_name(stolen)])
			_ev("get_card", p, {"card": stolen, "from": target})
		"even_out_money":
			# 均富卡（9038「和一个对手平分现金」）
			var t5: Dictionary = players[target]
			var avg := int((int(p["money"]) + int(t5["money"])) / 2)
			p["money"] = avg
			t5["money"] = avg
			log_message.emit("%s 与 %s 均富，各 %d 元" % [p["name"], t5["name"], avg])
		"teleport_target":
			# 诱拐卡（9035「诱拐对手的小神仙」，Info.txt 1018/1038「<BABYNAME>被<SOMEONE>诱拐」）
			var t6: Dictionary = players[target]
			var tps: Array = t6["pets"]
			if tps.is_empty():
				return false
			if pet_count(p) >= max_pets():
				_ev("pet_full", p, {"pet": "", "max": max_pets()})
				return false
			var stolen_pet := active_pet(t6)
			if stolen_pet.is_empty() or _protected(t6): return false
			tps.erase(stolen_pet)
			var spid := str(stolen_pet.id)
			t6["pet_active"] = "none"
			# Four reserve slots are separate from the equipped slot.
			if active_pet(p).is_empty() and pet_count(p) >= 4:
				tps.append(stolen_pet)
				t6["pet_active"] = pet_token(stolen_pet)
				return false
			if not stolen_pet.has("uid"):
				stolen_pet["uid"] = "%s:%s:%s:stolen" % [target, spid, tick_count]
			if p.pets.is_empty(): p["pet_active"] = "none"
			(p["pets"] as Array).append(stolen_pet)
			log_message.emit("%s 诱拐了 %s 的「%s」（%d 级）" % [
				p["name"], t6["name"], pet_name(spid), int(stolen_pet.get("level", 1))])
			_ev("steal_pet", p, {"pet": spid, "name": pet_name(spid),
				"from": target, "card": card_id})

		# ---------------- 街道 / 地价 / 查封 ----------------
		"raise_estate_index", "lower_estate_index":
			var d := int(c.get("amount", 5))
			var delta := d if eff == "raise_estate_index" else -d
			_change_land_factors(float(delta), false, street)
			street_index[street] = int(street_index.get(street, 0)) + delta
			log_message.emit("%s：%s 地价 %+d%%（现 %+d%%）" % [
				p["name"], street, delta, int(street_index[street])])
			_ev("estate_index", p, {"street": street, "delta": delta,
				"value": int(street_index[street]), "card": card_id})
		"seal_building":
			# 查封卡（9031「当前街道暂停收取房租」，Card_ChaFeng_Days = 5 天）
			var affected := _street_plots(street)
			if affected.is_empty(): return false
			var days := float(c.get("days", 5))
			street_seal[street] = maxf(time, float(street_seal.get(street, 0.0))) + days * Rules.seconds_per_day()
			log_message.emit("%s 查封了 %s 全部 %d 处地产（%.0f 天内不收租）" % [p["name"], street, affected.size(), days])
			_ev("seal", p, {"street": street, "until": street_seal[street], "card": card_id,
				"count": affected.size()})
		"auto_downgrade":
			# 恶魔卡（9006「袭击一条街道的所有房屋」）
			var cnt := 0
			for k in _street_plots(street):
				if int(plots[k]["level"]) > 0:
					_downgrade_estate(int(k))
					cnt += 1
					_ev("downgrade", p, {"idx": int(k), "level": int(plots[k]["level"]),
						"street": street, "card": card_id})
			if cnt == 0:
				return false
			log_message.emit("%s 的恶魔袭击了 %s 的 %d 栋房屋" % [p["name"], street, cnt])

		# ---------------- 地产 ----------------
		"free_land":
			# 土神卡（9008「强占土地」）—— 目标是**脚下的对手地产**。
			# ⚠ 2026-09-26 修正：原来只判「这格有没有主」，还允许强占空地/自己的地；
			#   String.txt 第 66 行的原版批注明确写着 id 63「只能用于对手的地产」
			#   适用于「（土神卡， 购地卡等）」→ 必须是对手已持有的地产。
			if not (plots.has(here) and int(plots[here]["owner"]) != pid):
				log_message.emit("%s 的土神无处下手：这格不是对手的地产" % p["name"])
				return false
			var old := int(plots[here]["owner"])
			plots[here]["owner"] = pid
			log_message.emit("%s 的土神强占了 %s（原属 %s）" % [
				p["name"], street, _owner_name(old)])
			_ev("own_plot", p, {"idx": here, "street": street, "from": old, "card": card_id})
		"buy_any_plot":
			# 购地卡（9020「强制购买当前土地」）—— 同样是**脚下的对手地产**，但要**付钱**。
			# ⚠ 2026-09-26 修正：原来要求「这格还没有主」（拆了自己的语义：空地本来就能
			#   直接买，用不上这张卡），于是老板用时永远返回 false 且 UI 毫无反馈。
			#   正确语义：把**对手已经持有的地产**强行买过来，按「现值」付给原主。
			if not (plots.has(here) and int(plots[here]["owner"]) != pid):
				log_message.emit("%s 的购地卡落空：这格不是对手的地产" % p["name"])
				return false
			var seller := int(plots[here]["owner"])
			var price := plot_value(here)
			if int(p["money"]) < price:
				_ev("insufficient_money", p, {"idx": here, "need": price, "have": int(p["money"])})
				return false
			_transfer(p, players.get(seller, null), price, "购地卡")
			plots[here]["owner"] = pid
			log_message.emit("%s 用购地卡从 %s 手里买下 %s（%d 元）" % [
				p["name"], _owner_name(seller), street, price])
			_ev("buy", p, {"idx": here, "price": price, "street": street,
				"from": seller, "card": card_id})

		# ---------------- 升级 / 拆除 / 改建（原逻辑保留）----------------
		"free_upgrade":
			_clear_attached_gods(p)
			e["free_upgrade_steps"] = int(c.get("steps", 30))
			_status_feedback(p, p, card_id, "福神附身：抵达自动加盖", int(e["free_upgrade_steps"]))
			var n := int(c.get("cards_gained", 0))
			for _i in range(n):
				var res := _push_card(p, _random_card())
				if not bool(res["added"]):
					break                      # 全锁着就不硬塞了
				_report_card_push(p, res, "")
			log_message.emit("%s 福神附身：%d 步内抵达自动加盖，得 %d 张卡" % [
				p["name"], int(e["free_upgrade_steps"]), n])
		"auto_upgrade":
			var upgraded := 0
			for ti in _street_plots(street):
				if int(plots[ti]["level"]) > 0 and force_upgrade(int(plots[ti]["owner"]), int(ti), true):
					upgraded += 1
			if upgraded == 0: return false
			log_message.emit("%s 的天使让 %s 的 %d 栋房屋升级" % [p["name"], street, upgraded])
		"upgrade_building":
			var ti2 := target if target >= 0 else _own_plot_to_upgrade(pid)
			if ti2 < 0:
				log_message.emit("%s 使用升级卡，但没有可升级的房屋" % p["name"])
				return false
			if not force_upgrade(pid, ti2, true): return false
			log_message.emit("%s 用升级卡把 %s 升了一级" % [p["name"], map.street_of(ti2)])
		"downgrade_building":
			# 怪兽卡（9019「袭击一栋房屋」）：优先拆**当前格**的对手房，否则挑最好的
			var ei := target if target >= 0 else _enemy_plot_best(pid)
			if ei < 0 or not plots.has(ei) or int(plots[ei]["level"]) <= 0:
				return false
			_downgrade_estate(int(ei))
			log_message.emit("%s 的怪兽把 %s 拆了一级" % [p["name"], map.street_of(ei)])
			_ev("downgrade", p, {"idx": ei, "level": int(plots[ei]["level"]),
				"street": map.street_of(ei), "card": card_id})
		"change_building_type":
			if target_name == "": return false
			var plan := rebuild_plan(pid, here, target_name)
			if plan.is_empty(): return false
			var rebuilt: Dictionary = plots[here]
			rebuilt["type"] = str(plan.type)
			rebuilt["level"] = int(plan.level)
			rebuilt["building_grade"] = 1
			for member in plan.members:
				plots[int(member)] = rebuilt
			log_message.emit("%s 用改建卡把 %s 改成%s" % [p["name"], street, str(plan.name)])
			_ev("rebuild", p, {"idx": here, "type": str(plan.type), "level": int(plan.level),
				"name": str(plan.name), "card": card_id})
		"force_stop":
			p["moving"] = 0
			p["progress"] = 0.0
			var here2: int = int(p["tile"])
			_clear_chance(p)
			_arrive(p)
			log_message.emit("%s 用停留卡在 %s 又停了一站" % [p["name"], map.street_of(here2)])

		# ---------------- 路面道具 / 爆炸 ----------------
		"place_mine":
			# String.txt 9023 and 0x41ff10: one road node behind, opposite current direction.
			target = _wrap(here - int(p.dir))
			if not _obstacle_at(target).is_empty() or road_objs.has(target): return false
			_add_obstacle(target, "mine", pid)
			log_message.emit("%s 在身后放了一颗地雷" % p["name"])
		"place_roadblock":
			_add_obstacle(target, "roadblock", pid)
			log_message.emit("%s 在前面放了一个路障" % p["name"])
		"remove_obstacle":
			# ⚠️ 范围**不是写死的 7** —— 原版从 `card.crd` 的 `+0x220` 按地图读
			#   （埃及等 6 图 = 7，**太空 = 9**）。见 docs/rea-2026-10-16/card-crd-解析.md
			var span := card_param(card_id)
			if span <= 0:
				span = 7                   # 兜底
			var cleared := 0
			var path: Array = []
			for step_ahead in range(1, span + 1):
				var road_ahead := _wrap(here + int(p["dir"]) * step_ahead)
				path.append(road_ahead)
				cleared += int(not _obstacle_at(road_ahead).is_empty()) + int(road_objs.has(road_ahead))

			if cleared == 0: return false
			for i in range(path.size()):
				pending_road_clears.append({"idx": path[i], "at": time + float(i + 1) / 2.0})
			_ev("clear_road", p, {"from_idx": here, "path": path, "removed": cleared})
			log_message.emit("%s 的推土机清除了前方 %d 格中的 %d 处路面道具"
				% [p["name"], span, cleared])
		"destroy_buildings", "nuke":
			# 飞弹卡（9027）/ 核弹卡（9042）
			# ⚠️ 范围同样读原版 `+0x220`：飞弹卡 = **2**（**太空 25**），
			#   核弹卡 = 100。以前用 `c.get("range", 5)`，与配置不符。
			var r := card_param(card_id)
			if r <= 0:
				r = int(c.get("range", 5))   # 兜底
			var dec := int(c.get("max_damage", c.get("hp_dec", 0)))
			pending_card_impacts.append({"idx": target, "range": r, "damage": dec,
				"owner": pid, "card": card_id, "at": time + 1.0})
			_ev("missile_launch", p, {"idx": target, "from_idx": here,
				"card": card_id, "seconds": 1.0})
		"sleep_target":
			# 冬眠卡（9028「周围人进入冬眠状态」）
			var secs := float(c.get("seconds", 10))
			var n2 := 0
			for oid in player_ids():
				if int(oid) == pid:
					continue
				var q: Dictionary = players[oid]
				if not bool(q["alive"]):
					continue
				if _protected(q): continue
				_clear_attached_gods(q)
				q["effects"]["sleep_until"] = time + secs
				q["effects"]["sleep_source"] = "%s 的冬眠卡" % str(p["name"])
				q["moving"] = 0
				n2 += 1
				_ev("sleep", q, {"card": card_id, "seconds": secs,
					"by": pid, "by_name": str(p["name"])})
			if n2 == 0:
				return false
			log_message.emit("%s 的冬眠卡让 %d 人睡了 %.0f 秒" % [p["name"], n2, secs])

		_:
			log_message.emit("「%s」的效果尚未实现" % Rules.card_name(card_id))
			return false
	return true


# ------------------------------------------------------- 卡片用得到的辅助

func _owner_name(oid: int) -> String:
	var q: Dictionary = players.get(oid, {})
	return str(q.get("name", "原主"))

## 某条街上的所有地产格索引
func _street_plots(street: String) -> Array:
	var out: Array = []
	for k in unique_plot_keys():
		if map.street_of(int(k)) == street:
			out.append(int(k))
	return out

func _current_street(index: int) -> String:
	var direct := map.street_of(index)
	if direct != "": return direct
	for distance in range(1, map.tile_count()):
		for near in [_wrap(index - distance), _wrap(index + distance)]:
			var name := map.street_of(int(near))
			if name != "": return name
	return ""

## 环形棋盘上的最短格距
func _tile_distance(a: int, b: int) -> int:
	var n := map.tile_count()
	if n <= 0:
		return 0
	var d := absi(a - b)
	return mini(d, n - d)

# ------------------------------------------------- 路边物体（原版 roadobj）

## 本图的「路面物体出现几率」权重（`config/scene/<map>/<map>.txt`，-1 = 不随机生成）
func road_weight(kind: String) -> int:
	if map == null:
		return 0
	return int((map.road_items as Dictionary).get(kind, 0))


## 这种物体隔多少天才能再出一次（Initvar_r.txt 的 `*_Born_Days`；没有的按 1 天）
func _road_cycle_days(kind: String) -> int:
	match kind:
		"crystal":
			return int(Rules.get_val("road.birth.crystal_days", 3))
		"robber":
			return int(Rules.get_val("road.birth.chest_days", 5))   # 宝箱由「强盗」承载
		"petegg":
			return int(Rules.get_val("road.birth.egg_days", 1))
	return 1


## 按权重抽一个能生成的路边物体；抽不到返回 ""
func _roll_road_kind() -> String:
	var kinds: Array = []
	var total: int = 0
	var items: Dictionary = map.road_items if map != null else {}
	for k in items.keys():
		var w: int = int(items[k])
		if w <= 0:
			continue                                # -1 = 本图不随机生成
		var cyc: int = _road_cycle_days(str(k))
		if cyc > 1 and road_day - int(_road_last_day.get(str(k), -9999)) < cyc:
			continue                                # 还在出生周期内
		kinds.append(str(k))
		total += w
	if total <= 0:
		return ""
	var r: int = rng.randi_range(1, total)
	var acc: int = 0
	for k2 in kinds:
		acc += int(items[k2])
		if r <= acc:
			return str(k2)
	return str(kinds[kinds.size() - 1])


## 找一格空位：不占起点格、不覆盖已有的地产 / 路边物体 / 陷阱
func _random_free_tile() -> int:
	var n: int = map.tile_count()
	if n <= 1:
		return -1
	for _try in range(24):
		var i: int = rng.randi_range(1, n - 1)      # 0 是起点格
		if plots.has(i) or road_objs.has(i):
			continue
		if str(map.tile(i).get("kind", "")) == "start":
			continue
		if not _obstacle_at(i).is_empty():
			continue
		return i
	return -1


## 每天一次：按地图的「路面物体出现几率」在棋盘上撒一个路边物体
func _spawn_road_obj(force_kind: String = "") -> void:
	if map == null or road_objs.size() >= ROAD_MAX_ON_BOARD:
		return
	var kind: String = force_kind if force_kind != "" else _roll_road_kind()
	if kind == "":
		return
	var idx: int = _random_free_tile()
	if idx < 0:
		return
	road_objs[idx] = {"kind": kind, "born": road_day}
	_road_last_day[kind] = road_day
	_ev("road_spawn", null, {"idx": idx, "kind": kind})


## 宝箱金额。**定点逆向**自 0x431220：
##   rand(10..20) × 全体存活玩家平均现金 / 100，并有 1000 的下限。
func _chest_gain() -> int:
	var total: int = 0
	var n: int = 0
	for id in player_ids():
		var q: Dictionary = players[id]
		if not bool(q["alive"]):
			continue
		total += int(q["money"])
		n += 1
	if n <= 0:
		return 0
	var pct: Array = Rules.get_val("road.chest_gain_pct", [10, 20]) as Array
	var r: int = rng.randi_range(int(pct[0]), int(pct[1]))
	var gain: int = int(float(total / n) * float(r) / 100.0)
	return maxi(gain, int(Rules.get_val("road.chest_gain_min", 1000)))


## 四神附身（踩到财神 / 福神 / 衰神 / 穷神）。
## 复用卡片那套 effect 字段：财神=按秒的免租、穷神=按秒的罚金加倍、
## 衰神=按步数的不能升级、福神=按步数的免费加盖（原版这两项的步数就是 30）。
func _attach_god(p: Dictionary, kind: String) -> void:
	_clear_attached_gods(p)
	var e: Dictionary = p["effects"]
	var amount := 0
	var cards := 0
	match kind:
		"caishen":
			e["no_rent_steps"] = int(Rules.get_val("card.caishen_steps", 30))
			var cfg := Rules.card_by_id("caishen")
			amount = rng.randi_range(int(cfg.get("min", 10000)), int(cfg.get("max", 50000)))
			p["money"] = int(p["money"]) + amount
		"qiongshen":
			e["rent_double_steps"] = int(Rules.get_val("card.qiongshen_steps", 30))
			var cfg := Rules.card_by_id("qiongshen")
			amount = mini(int(p["money"]), rng.randi_range(int(cfg.get("target_lose_min", 10000)),
				int(cfg.get("target_lose_max", 30000))))
			p["money"] = int(p["money"]) - amount
		"shuaishen":
			e["no_upgrade_steps"] = int(Rules.get_val("card.shuaishen_steps", 30))
		"fushen":
			e["free_upgrade_steps"] = int(Rules.get_val("card.fushen_steps", 30))
			for _i in range(int(Rules.get_val("card.fushen_numcard", 5))):
				var gained := _push_card(p, _random_card())
				if not bool(gained.get("added", false)): break
				cards += 1
				_report_card_push(p, gained, "福神")
	log_message.emit("%s 被%s附身" % [p["name"], god_cn(kind)])
	_ev("road_god", p, {"idx": int(p["tile"]), "god": kind, "god_cn": god_cn(kind),
		"amount": amount, "cards": cards})


func god_cn(kind: String) -> String:
	match kind:
		"caishen":
			return "财神"
		"fushen":
			return "福神"
		"shuaishen":
			return "衰神"
		"qiongshen":
			return "穷神"
	return kind


## 踩到路边物体 → 结算。文案全部取原版 `config/Info.txt` 71..78。
func _pick_road_obj(p: Dictionary, kind: String, idx: int) -> void:
	match kind:
		# 73 拾到卡片 → 得到<CARDNAME>
		"card":
			_give_random_card(p, "")
		# 魔戒：升一级，同时补满能量；满级的小神仙仍可获得一次技能能量。
		"crystal":
			var pets: Array = p["pets"]
			if pets.is_empty():
				log_message.emit("%s 得到魔戒，但身上没有小神仙" % p["name"])
				_ev("road_crystal", p, {"idx": idx, "leveled": false})
				return
			var pi: int = rng.randi_range(0, pets.size() - 1)
			var lv: int = int(pets[pi]["level"])
			var cap: int = int(Rules.get_val("road.crystal_max_pet_level", 4))
			var leveled := lv < cap
			if leveled: pets[pi]["level"] = lv + 1
			_set_pet_energy(pets[pi], pet_max_energy(pets[pi]))
			pets[pi]["ready"] = true
			log_message.emit("%s 得到魔戒：%s 能量已满%s" % [
				p["name"], pet_name(str(pets[pi]["id"])), "，升到 %d 级" % (lv + 1) if leveled else ""])
			_ev("road_crystal", p, {"idx": idx, "leveled": leveled,
				"level": int(pets[pi]["level"]), "recharged": true,
				"pet": str(pets[pi]["id"])})
		# 74 吃到汉堡 体力上升（HanBao_Inc_HP = 1000）
		"hanbao":
			var heal: float = float(Rules.get_val("hp.hamburger_heal", 1000))
			p["stamina"] = minf(stamina_max(), float(p.get("stamina", 0.0)) + heal)
			log_message.emit("%s 吃到汉堡，体力 +%.0f" % [p["name"], heal])
			_ev("road_hanbao", p, {"idx": idx, "heal": int(heal)})
		# 75 神仙蛋 得到<BABYNAME>
		"petegg":
			var cat: Array = pet_catalog()
			if cat.is_empty():
				return
			var newpet: String = str(
				(cat[rng.randi_range(0, cat.size() - 1)] as Dictionary).get("id", ""))
			if add_pet(p, newpet) != 0:
				log_message.emit("%s 捡到神仙蛋，但已经带满小神仙了" % p["name"])
				_ev("pet_full", p, {"pet": newpet})
				return
			log_message.emit("%s 的神仙蛋孵出了「%s」" % [p["name"], pet_name(newpet)])
			_ev("get_pet", p, {"pet": newpet, "from_egg": true})
		# 72 强盗遗失宝箱 获得<NUMBER>元（公式见 _chest_gain）
		"robber":
			var gain: int = _chest_gain()
			p["money"] = int(p["money"]) + gain
			log_message.emit("%s 捡到强盗遗失的宝箱，得到 %d 元" % [p["name"], gain])
			_ev("road_chest", p, {"idx": idx, "gain": gain})
		# 76 遇到炸弹鬼 体力受损
		"bomb":
			if _protected(p):
				return
			var dec: float = float(Rules.get_val("road.bomb_hp_dec", 500))
			log_message.emit("%s 遇到炸弹鬼，体力 -%.0f" % [p["name"], dec])
			_ev("road_bomb", p, {"idx": idx, "dec": int(dec)})
			_send_to_hospital(p, dec, "bomb")
		# 77 遇到小偷 遗失<NUMBER>元（逆向自 0x4313d0：现金的 rand(1..10)%）
		"thief":
			var pct: Array = Rules.get_val("road.thief_loss_pct", [1, 10]) as Array
			var r: int = rng.randi_range(int(pct[0]), int(pct[1]))
			var loss: int = mini(int(float(p["money"]) * float(r) / 100.0), int(p["money"]))
			p["money"] = int(p["money"]) - loss
			log_message.emit("%s 遇到小偷，损失 %d 元（现金的 %d%%）" % [p["name"], loss, r])
			_ev("road_thief", p, {"idx": idx, "loss": loss, "pct": r})
		# 财神 / 福神 / 衰神 / 穷神：附身
		"caishen", "fushen", "shuaishen", "qiongshen":
			_attach_god(p, kind)
		# 隔毁：挡一下
		"block":
			p["moving"] = 0
			p["progress"] = 0.0
			log_message.emit("%s 被路面障碍挡住" % p["name"])
			_ev("roadblock", p, {"idx": idx, "owner": 0})
		_:
			pass


func _obstacle_at(idx: int) -> Dictionary:
	for o in obstacles:
		if int((o as Dictionary).get("idx", -1)) == idx:
			return o
	return {}

func _remove_obstacle(idx: int) -> void:
	var keep: Array = []
	for o in obstacles:
		if int((o as Dictionary).get("idx", -1)) != idx:
			keep.append(o)
	obstacles = keep

func _add_obstacle(idx: int, kind: String, owner: int) -> void:
	_remove_obstacle(idx)
	obstacles.append({"idx": idx, "kind": kind, "owner": owner})

## 卡的作用范围 —— 原版 `card.crd` 的 `+0x220` 字段（**按地图配置**）。
##
## 依据：`docs/rea-2026-10-16/card-crd-解析.md`、`card_alignment.json`。
## 例：清除卡在埃及/中国/海岛/日本/巴黎/铁路 = **7**，**太空 = 9**；
##     地雷卡 4/6（太空 30）· 飞弹卡 2（太空 25）· 隐形/核弹 = 100（全图）。
##
## ⚠️ **语义是推断的**：范围内最像「作用距离（格）」；且 **`param = 0` 表示该地图禁用这张卡**
##    （太空图里四神/天使/恶魔/改建/红黑/查封/诱拐/查税/均富 全是 0）。
##    这里先只用于「取范围」，**禁用逻辑（param==0）还没有接**。
var _card_params: Dictionary = {}     # 地图名 -> {卡id -> param}


func _load_card_params() -> void:
	if not _card_params.is_empty():
		return
	var f := FileAccess.open("res://data/rules/card_alignment.json", FileAccess.READ)
	if f == null:
		push_warning("Sim: 缺 data/rules/card_alignment.json")
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	for r in (d as Dictionary).get("rows", []):
		var by_map: Dictionary = (r as Dictionary).get("param_by_map", {})
		var cid := str((r as Dictionary).get("id", ""))
		for m in by_map:
			if not _card_params.has(m):
				_card_params[m] = {}
			(_card_params[m] as Dictionary)[cid] = int(by_map[m])


## 取某张卡在**当前地图**上的原版参数（`+0x220`）。取不到返回 0。
func card_param(card_id: String) -> int:
	_load_card_params()
	var m := str(map.name) if map != null else ""
	var per: Dictionary = _card_params.get(m, {})
	return int(per.get(Rules.base_card_id(card_id), 0))


## 清除玩家前方 n 格内的路面道具，返回清掉的数量
func _clear_obstacles_ahead(p: Dictionary, n: int) -> int:
	var c := 0
	for i in range(1, n + 1):
		var idx := _wrap(int(p["tile"]) + int(p["dir"]) * i)
		if not _obstacle_at(idx).is_empty():
			_remove_obstacle(idx)
			c += 1
	return c

func _native_road_position(idx: int) -> Vector3:
	# The recovered road records preserve their original, unscaled XYZ positions.
	# Use them directly: the terrain affine can scale X and Z differently.
	if not map.original_layout.is_empty():
		var raw: Array = map.original_layout["roads"][_wrap(idx)].get("position", [])
		if raw.size() == 3: return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
		return map.route_position_3d(idx, 1, 0.0) / float(map.original_layout.get("world_scale", .036))
	# Fallback maps lack native coordinates: normalize one road spacing to 100.
	var spacing := map.pos_of(0).distance_to(map.pos_of(1))
	return map.route_position_3d(idx, 1, 0.0) * (100.0 / maxf(spacing, 0.001))

func _clear_attached_gods(p: Dictionary) -> void:
	for effect in STEP_EFFECTS + ["sleepwalk_steps", "invincible_until", "sleep_until",
		"invisible_until", "no_rent_until", "rent_pay_double_until"]:
		p["effects"][effect] = 0

func _protected(p: Dictionary) -> bool:
	var e: Dictionary = p.get("effects", {})
	return float(e.get("invincible_until", 0.0)) > time or float(e.get("invisible_until", 0.0)) > time

func _status_feedback(caster: Dictionary, target: Dictionary, card: String, message: String, steps: int) -> void:
	_ev("card_status_applied", target, {"caster": int(caster["id"]), "card": card,
		"steps": steps, "message": "%s：%s（%d 步）" % [target["name"], message, steps]})

func _hospital_road_tile() -> int:
	for i in range(map.tiles.size()):
		if str(map.tile(i).get("event", "")) == "hospital": return i
	return -1

func _send_to_hospital(p: Dictionary, damage: float, cause: String) -> void:
	if damage <= 0.0: return
	p["stamina"] = maxf(0.0, float(p.get("stamina", 0.0)) - damage)
	p["moving"] = 0
	p["progress"] = 0.0
	p["pending_steps"] = false
	p["move_after"] = 0.0
	_clear_chance(p)
	var hospital_tile := _hospital_road_tile()
	if hospital_tile >= 0: p["tile"] = hospital_tile
	var seconds := (stamina_max() - float(p["stamina"])) / maxf(stamina_regen(), 7.0)
	p["effects"]["hospital_until"] = time + maxf(seconds, 0.1)
	_ev("hospital", p, {"card": cause, "seconds": int(ceil(seconds)),
		"idx": hospital_tile, "message": "%s 受伤住院，恢复体力后从医院出发" % p["name"]})

## rich6.exe 4287c0/43a6a0: Euclidean player radius range*50, linear missile
## damage; nuclear fixed damage. 41e110: missile -1 level, nuclear -1000 levels.
func _damage_area(idx: int, radius: int, hp_dec: int, owner_id: int, card: String = "missile") -> int:
	var hits := 0
	for k in unique_plot_keys():
		if _estate_in_radius(int(k), idx, int(radius / 2)) and int(plots[k]["level"]) > 0:
			if card == "nuke": plots[k]["level"] = 1
			_downgrade_estate(int(k))
			_ev("downgrade", players.get(owner_id, null), {"idx": int(k), "card": card,
				"level": int(plots[k]["level"])})
			hits += 1
	for offset in range(-int(radius / 2), int(radius / 2) + 1):
		var road := _wrap(idx + offset)
		_remove_obstacle(road)
		road_objs.erase(road)
	var center := _native_road_position(idx)
	for oid in player_ids():
		var q: Dictionary = players[oid]
		if not bool(q["alive"]):
			continue
		if _protected(q):
			continue                       # 无敌卡期间不吃伤害
		if float(q["effects"].get("hospital_until", 0)) > time: continue
		var distance := center.distance_to(_native_road_position(int(q["tile"]))) / maxf(1.0, radius * 50.0)
		if distance < 1.0 and hp_dec > 0:
			var damage := hp_dec if card == "nuke" else int((1.0 - distance) * hp_dec)
			_ev("card_damage", q, {"card": card, "damage": damage, "caster": owner_id})
			if damage > 0:
				_send_to_hospital(q, float(damage), card)
				hits += 1
	_ev("blast", players.get(owner_id, null),
		{"idx": idx, "radius": radius, "hp_dec": hp_dec, "hits": hits, "card": card})
	return hits


# ------------------------------------------------------------------- 序列化

func to_dict() -> Dictionary:
	return {
		"t": time,
		"tick": tick_count,
		"rng_seed": rng.seed,
		"rng_state": rng.state,
		"estate_index": estate_index,
		"initial_company_assets": initial_company_assets,
		"estate_month": estate_month,
		"land_factors": land_factors.duplicate(true),
		"economy_factors": economy_factors.duplicate(true),
		"environment_signature": _environment_signature.duplicate(true),
		"road_last_day": _road_last_day.duplicate(true),
		"lotto_prize": lotto_prize,
		"lotto_numbers": lotto_numbers.duplicate(true),
		"lotto_last_draw_day": lotto_last_draw_day,
		"card_impacts": pending_card_impacts.duplicate(true),
		"road_clears": pending_road_clears.duplicate(true),
		"run": running,
		"win": winner,
		"players": players.duplicate(true),
		"plots": plots.duplicate(true),
		"street_index": street_index.duplicate(true),
		"street_seal": street_seal.duplicate(true),
		"obstacles": obstacles.duplicate(true),
		"road_objs": road_objs.duplicate(true),
		"road_day": road_day,
		"stocks": stocks.duplicate(true),
		# 拉霸状态（`casino`）也要进快照 —— 否则联机时客户端的面板永远是空的
		"casino": casino.duplicate(true),
		"card_shop": card_shop_stock.duplicate(),
		"card_shop_initialized": card_shop_initialized,
		"stock_closed": stock_closed_until_day,
		"auction": auction.duplicate(true),
	}

func apply_dict(d: Dictionary) -> void:
	time = float(d.get("t", time))
	tick_count = int(d.get("tick", tick_count))
	if d.has("rng_seed"): rng.seed = int(d["rng_seed"])
	if d.has("rng_state"): rng.state = int(d["rng_state"])
	estate_index = float(d.get("estate_index", estate_index))
	initial_company_assets = int(d.get("initial_company_assets", initial_company_assets))
	estate_month = int(d.get("estate_month", estate_month))
	land_factors = {}
	_environment_signature = d.get("environment_signature", []).duplicate(true)
	for key in d.get("land_factors", {}):
		land_factors[int(key)] = d.land_factors[key].duplicate(true)
	economy_factors = d.get("economy_factors", {"industry": 1.0, "shop": 1.0, "uptown": 1.0}).duplicate(true)
	_road_last_day = d.get("road_last_day", _road_last_day).duplicate(true)
	lotto_prize = int(d.get("lotto_prize", lotto_prize))
	var saved_lotto: Dictionary = d.get("lotto_numbers", lotto_numbers)
	lotto_numbers = {}
	for number in saved_lotto:
		lotto_numbers[int(number)] = int(saved_lotto[number])
	lotto_last_draw_day = int(d.get("lotto_last_draw_day", lotto_last_draw_day))
	pending_card_impacts = d.get("card_impacts", []).duplicate(true)
	pending_road_clears = d.get("road_clears", []).duplicate(true)
	running = bool(d.get("run", running))
	winner = int(d.get("win", -1))
	var saved_players: Dictionary = d.get("players", players)
	players = {}
	for key in saved_players: players[int(key)] = saved_players[key]
	for pid in player_ids():
		var e: Dictionary = players[pid].get("effects", {})
		var invisible := float(e.get("invisible_until", 0.0))
		# Previous invisible wrote two identical extra timers. Migrate those
		# generated timers, leaving unrelated hospital/rest timers intact.
		if invisible > time:
			for field in ["invincible_until", "no_rent_until"]:
				if is_equal_approx(float(e.get(field, 0.0)), invisible): e[field] = 0.0
	street_index = d.get("street_index", street_index)
	street_seal = d.get("street_seal", street_seal)
	obstacles = d.get("obstacles", obstacles)
	# JSON 往返会把 int 键变成 String 键，需归一化
	var fixed := {}
	for k in d.get("plots", {}).keys():
		fixed[int(k)] = d["plots"][k]
	plots = fixed
	# Deep-copy and network decoding do not preserve Dictionary aliasing.
	for key in plots.keys():
		var anchor := int(plots[key].get("anchor", key))
		if plots.has(anchor):
			plots[key] = plots[anchor]
	var rf := {}
	for k in d.get("road_objs", {}).keys():
		rf[int(k)] = d["road_objs"][k]
	road_objs = rf
	road_day = int(d.get("road_day", road_day))
	stocks = d.get("stocks", stocks)
	var saved_casino: Dictionary = d.get("casino", casino)
	casino = {}
	for key in saved_casino: casino[int(key)] = saved_casino[key]
	card_shop_stock = d.get("card_shop", card_shop_stock)
	card_shop_initialized = bool(d.get("card_shop_initialized", not card_shop_stock.is_empty()))
	auction = d.get("auction", auction)
	stock_closed_until_day = int(d.get("stock_closed", stock_closed_until_day))
	_normalize_plot_frontages()
	for key in unique_plot_keys():
		var estate: Dictionary = plots[key]
		estate["building_grade"] = Rules.house_local_grade(str(estate.get("type", "")), int(estate.get("level", 0)))
	for pid in player_ids():
		for pet in players[pid].get("pets", []): pet_energy(pet)

func _bind_plot(idx: int, estate: Dictionary) -> void:
	var members := map.plot_frontages(idx)
	if members.size() > 1:
		estate["anchor"] = int(members[0])
		estate["members"] = members
	for member in members: plots[int(member)] = estate

## Repair old saves that sold two entrances of one lot separately. Preserve
## developed property first, then the lowest original anchor deterministically.
## Return the rejected duplicate investment once; subsequent snapshots are stable.
func _normalize_plot_frontages() -> void:
	if map == null: return
	var visited := {}
	for idx in plots.keys():
		if visited.has(idx): continue
		var frontages := map.plot_frontages(int(idx))
		if frontages.size() < 2: continue
		var members: Array = frontages.duplicate()
		var estates := {}
		var cursor := 0
		while cursor < members.size():
			var key := int(members[cursor])
			cursor += 1
			visited[key] = true
			for other in map.plot_frontages(key):
				if not members.has(other): members.append(other)
			if not plots.has(key): continue
			var estate: Dictionary = plots[key]
			estates[int(estate.get("anchor", key))] = estate
			for other in estate.get("members", [key]):
				if not members.has(int(other)): members.append(int(other))
		var keys := estates.keys()
		keys.sort()
		var chosen := int(keys[0])
		for key in keys:
			if int(estates[key].get("level", 0)) > int(estates[chosen].get("level", 0)): chosen = int(key)
		var winner_estate: Dictionary = estates[chosen]
		for key in keys:
			if int(key) == chosen: continue
			var owner := int(estates[key].get("owner", -1))
			if players.has(owner):
				players[owner]["money"] = int(players[owner]["money"]) + int(round(
					float(estates[key].get("paid_base", 200.0)) * price_scale()))
		members.sort()
		winner_estate["anchor"] = int(members[0])
		winner_estate["members"] = members
		for member in members: plots[int(member)] = winner_estate

func _estate_in_radius(key: int, center: int, radius: int) -> bool:
	for member in plots[key].get("members", [key]):
		if _tile_distance(int(member), center) <= radius:
			return true
	return false

func _downgrade_estate(idx: int) -> void:
	var estate: Dictionary = plots[idx]
	var old_size := Rules.house_footprint(Rules.house_file(str(estate.get("type", "")), int(estate.level)))
	var kind := str(estate.get("type", ""))
	var local := maxi(0, Rules.house_local_grade(kind, int(estate.level)) - 1)
	estate["level"] = Rules.house_asset_level(kind, old_size, local)
	estate["building_grade"] = local
	if int(estate.level) == 0:
		var reset_cells := {}
		for member in estate.get("members", [idx]):
			var frontages := map.plot_frontages(int(member))
			if reset_cells.has(frontages[0]): continue
			reset_cells[frontages[0]] = true
			var empty := estate.duplicate(true)
			for key in ["anchor", "members", "footprint", "build_cell", "build_start_level", "building_grade"]:
				empty.erase(key)
			empty["type"] = ""
			empty["paid_base"] = float(empty_plot_price()) / price_scale()
			_bind_plot(int(member), empty)
