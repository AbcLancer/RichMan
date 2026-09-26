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
const EMPTY_PLOT_PRICE := 2000      # Empty_Grid_PriceFactor(200) × 地价因子(10)
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

## ---- 卡片目标类型 ----
## 提示文案来自原版 `config/String.txt` 1101..1106（Rules.card_target_prompt）。
## ⚠ 这张「哪张卡点谁」的映射是**推导**出来的（依据每张卡的说明文字 + 作用对象），
##   原版配置里没有这张表 → 代码改动必须同步这里。
##   player = 需要玩家真的点一个对手；street/plot/road = 取「当前所在格」即可；
##   stock/card = 对应子系统（股票 / 卡片组合）尚未实现。
const CARD_TARGET := {
	"qiongshen": "player", "shuaishen": "player", "abduct": "player",
	"tax": "player", "rob": "player", "sharewealth": "player",
	"tudigong": "plot", "rebuild": "plot", "upgrade": "plot", "monster": "plot",
	"buyland": "plot", "missile": "plot", "nuke": "plot",
	"tianshi": "street", "emo": "street", "priceup": "street",
	"pricedown": "street", "seize": "street",
	"mine": "road", "roadblock": "road", "clear": "road",
	"redcard": "stock", "blackcard": "stock",
	"copy": "card", "gem": "card",
}

## 需要玩家真的点一个对手才能用的卡（只有这一类的使用是两步：选卡 → 选人）
func card_target(card_id: String) -> String:
	return str(CARD_TARGET.get(card_id, ""))

func card_needs_player(card_id: String) -> bool:
	return card_target(card_id) == "player"

## 这几个子系统没做 → 对应的卡**不消耗**（宁可留着，也别让玩家白扔一张卡）
const CARD_UNSUPPORTED := ["redcard", "blackcard", "copy"]

## 「按步数」计的效果（原版 Initvar_r.txt 里写「多少步」的项）。
## 每前进 1 格消耗 1 —— 与「按绝对时刻」的 invincible_until / sleep_until 严格区分。
const STEP_EFFECTS := ["no_rent_steps", "rent_double_steps",
	"free_upgrade_steps", "no_upgrade_steps"]

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

var rng := RandomNumberGenerator.new()

func setup(m: MapData, seed_val: int = 0) -> void:
	map = m
	if seed_val == 0:
		rng.randomize()
	else:
		rng.seed = seed_val
	_load_pets()


# ------------------------------------------------------------ 小神仙（精灵）数据

## 权威来源：`config/Pet.txt`（9 只 × 4 级的即时制秒数 / 回合制次数 / 消耗点数）
## + `config/String.txt` 2201..2209（技能名）+ `config/Info.txt` 202（持有上限 5 位）。
## 由 `tools/build_pet_data.py` 编译成 `res://data/rules/pets.json`。
const PET_DATA_PATH := "res://data/rules/pets.json"

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


## 1 级价格（点券）。⚠ Info.txt 203 的 <NUMBER> 原版没给值 → 取 Pet.txt「消耗点数」第 1 级
func pet_price(pet_id: String) -> int:
	return int(pet_record(pet_id).get("buy_price", 0))


## 特技持续时间（秒，即时制第 ① 行）
func pet_seconds(pet_id: String, level: int) -> float:
	return _pet_val(pet_id, "seconds", level)


## 发动一次消耗的点券（Pet.txt「消耗点数」列）
func pet_cost(pet_id: String, level: int) -> int:
	return int(_pet_val(pet_id, "points", level))


# ------------------------------------------------------- 持有 / 增减（都是字典表）

## p["pets"] 里每项 = {"id": 小神仙 id, "level": 1..4, "cool": 下次可发动的绝对时刻}
func pet_index_of(p: Dictionary, pet_id: String) -> int:
	var arr: Array = p.get("pets", [])
	for i in range(arr.size()):
		if str((arr[i] as Dictionary).get("id", "")) == pet_id:
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
	(p["pets"] as Array).append({"id": pet_id, "level": 1, "cool": 0.0})
	log_message.emit("%s 得到小神仙「%s」" % [p["name"], pet_name(pet_id)])
	_ev("get_pet", p, {"pet": pet_id, "name": pet_name(pet_id)})
	return 0


## 精灵屋购买（Info.txt 203：「<BABYNAME>价格<NUMBER>点券 确认要购买吗？」）
func act_buy_pet(id: int, pet_id: String) -> bool:
	var p: Dictionary = players.get(id, {})
	if p.is_empty() or not bool(p["alive"]):
		return false
	if pet_record(pet_id).is_empty():
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
	log_message.emit("%s 花 %d 点券请到「%s」" % [p["name"], price, pet_name(pet_id)])
	_ev("buy_pet", p, {"pet": pet_id, "price": price})
	return true


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


func _shop_stock() -> Array:
	var all: Array = Rules.cards()
	if all.is_empty():
		return []
	# 洗一副牌取前 8 张（不重复）
	var ids: Array = []
	for c in all:
		ids.append(str(c.get("id", "")))
	ids.shuffle()
	return ids.slice(0, mini(CARD_SHOP_SLOTS, ids.size()))


func act_buy_card(id: int, card_id: String) -> bool:
	## 卡片商店购买（Info.txt 41「卡片商店 您有<NUMBER>点券」/ 42 点券不够不能进）
	var p: Dictionary = players.get(id, {})
	if p.is_empty() or not bool(p["alive"]):
		return false
	if Rules.card_by_id(card_id).is_empty():
		return false
	var price := card_price(card_id)
	if int(p["credit"]) < price:
		_ev("cardshop_refused", p, {"card": card_id, "need": price, "have": int(p["credit"])})
		log_message.emit("%s 点券不够（%d/%d），买不了「%s」" % [
			p["name"], int(p["credit"]), price, Rules.card_name(card_id)])
		return false
	p["credit"] = int(p["credit"]) - price
	(p["cards"] as Array).append(card_id)
	log_message.emit("%s 花 %d 点券买下「%s」" % [p["name"], price, Rules.card_name(card_id)])
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


## 每次「抵达格子」之后给小神仙一次发动机会。
##
## 规则（**推导**，依据 = Pet.txt 的两列数字的语义 + Info.txt 191..196 的受害者文案）：
##   · 冷却：同一只小神仙两次发动之间要隔 `seconds[level-1]` 秒（即时制那一行）
##   · 花费：每次发动消耗 `points[level-1]` **点券**（Pet.txt「消耗点数」列）——
##     这就是点券的第二个出口；点券不够就不发动（不扣也不发动）
##   · 条件不满足（例如没有可拆的对手房）时**不扣点券、不进冷却**，换下一只试
func _tick_pets(p: Dictionary) -> void:
	if pets_data.is_empty():
		return
	for e in (p["pets"] as Array).duplicate():
		var d: Dictionary = e
		var pid := str(d.get("id", ""))
		if pid == "":
			continue
		var lv := int(d.get("level", 1))
		if time < float(d.get("cool", 0.0)):
			continue
		var cost := pet_cost(pid, lv)
		if int(p["credit"]) < cost:
			continue
		if not _pet_apply(p, pid, lv):
			continue
		p["credit"] = int(p["credit"]) - cost
		d["cool"] = time + pet_seconds(pid, lv)
		log_message.emit("  （%s 发动「%s」，耗 %d 点券，剩 %d）" % [
			pet_name(pid), pet_skill(pid), cost, int(p["credit"])])
		_ev("pet_skill", p, {"pet": pid, "name": pet_name(pid), "level": lv,
			"skill": pet_skill(pid), "effect": str(pet_record(pid).get("effect", "")),
			"cost": cost, "seconds": pet_seconds(pid, lv), "credit": int(p["credit"])})


## 真正施加特技。返回 false = 条件不满足（不消耗、不进冷却）。
func _pet_apply(p: Dictionary, pet_id: String, lv: int) -> bool:
	var secs := pet_seconds(pet_id, lv)
	var eff := str(pet_record(pet_id).get("effect", ""))
	var here := int(p["tile"])
	var me := int(p["id"])
	match eff:
		# 小财神「免费技 免付房租」（String.txt 2204 / Info.txt 194）
		"free_rent":
			p["effects"]["no_rent_until"] = maxf(
				float(p["effects"].get("no_rent_until", 0.0)), time + secs)
			log_message.emit("%s 的小财神显灵：%.0f 秒内免付租金" % [p["name"], secs])
		# 小穷神「穷神技 罚金加倍」（2201 / Info.txt 191）
		"curse_rent_double":
			var t := _random_other(p)
			if t.is_empty():
				return false
			t["effects"]["rent_pay_double_until"] = maxf(
				float(t["effects"].get("rent_pay_double_until", 0.0)), time + secs)
			log_message.emit("%s 的小穷神附上 %s：%.0f 秒内罚金加倍" % [p["name"], t["name"], secs])
			_ev("pet_curse", t, {"pet": pet_id, "from": me, "seconds": secs})
		# 糊涂鬼「梦游技 强迫梦游」（2202 / Info.txt 192）：周围对手冬眠
		"sleep_nearby":
			var n := 0
			for oid in player_ids():
				if int(oid) == me:
					continue
				var q: Dictionary = players[oid]
				if not bool(q["alive"]):
					continue
				if _tile_distance(int(q["tile"]), here) > 2:
					continue
				q["effects"]["sleep_until"] = maxf(
					float(q["effects"]["sleep_until"]), time + secs)
				q["moving"] = 0
				n += 1
				_ev("sleep", q, {"pet": pet_id, "seconds": secs})
			if n == 0:
				return false
			log_message.emit("%s 的糊涂鬼让周围 %d 人梦游 %.0f 秒" % [p["name"], n, secs])
		# 小恶魔「拆除技 拆除房屋」（2203 / Info.txt 193）
		"demolish_enemy":
			var ei := _enemy_plot_best(me)
			if ei < 0 or int(plots[ei]["level"]) <= 0:
				return false
			plots[ei]["level"] = int(plots[ei]["level"]) - 1
			log_message.emit("%s 的小恶魔把 %s 拆了一级" % [p["name"], map.street_of(ei)])
			_ev("downgrade", p, {"idx": ei, "level": int(plots[ei]["level"]),
				"street": map.street_of(ei), "pet": pet_id})
		# 小土神「土神技 强制占地」（2205 / Info.txt 196）
		"seize_enemy_plot":
			var si := _enemy_plot_best(me)
			if si < 0:
				return false
			var old := int(plots[si]["owner"])
			plots[si]["owner"] = me
			log_message.emit("%s 的小土神强占了 %s（原属 %s）" % [
				p["name"], map.street_of(si), _owner_name(old)])
			_ev("own_plot", p, {"idx": si, "street": map.street_of(si),
				"from": old, "pet": pet_id})
		# 雪精灵「加盖技 升级房屋」（2206）
		"free_upgrade":
			var ui := _own_plot_to_upgrade(me)
			if ui < 0:
				return false
			force_upgrade(me, ui, true)
			log_message.emit("%s 的雪精灵把 %s 升了一级" % [p["name"], map.street_of(ui)])
		# 花仙子「无敌技 无敌状态」（2207）
		"invincible":
			p["effects"]["invincible_until"] = maxf(
				float(p["effects"]["invincible_until"]), time + secs)
			log_message.emit("%s 的花仙子让主人无敌 %.0f 秒" % [p["name"], secs])
		# 小赌神「骰子技 遥控骰子」（2208）—— 只备一次，掷骰时消费
		"max_dice":
			p["effects"]["pet_max_dice"] = int(p["effects"].get("pet_max_dice", 0)) + 1
			log_message.emit("%s 的小赌神准备好遥控下一次骰子" % p["name"])
		# 小怪兽「PK技 攻击小神仙」（2209 / Info.txt 195）
		"attack_pet":
			var tp := _random_other(p)
			if tp.is_empty() or (tp["pets"] as Array).is_empty():
				return false
			var lost: Dictionary = (tp["pets"] as Array).pop_back()
			log_message.emit("%s 的小怪兽打跑了 %s 的「%s」" % [
				p["name"], tp["name"], pet_name(str(lost.get("id", "")))])
			_ev("pet_attacked", tp, {"pet": str(lost.get("id", "")), "from": me})
		_:
			return false
	return true

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

## 现在能不能出发（呼吸 / 体力两项都够）。表现层用它决定 GO 钮亮不亮。
func can_start_walk(p: Dictionary) -> bool:
	if not bool(p["alive"]) or int(p["moving"]) > 0:
		return false
	if time < float(p["effects"]["sleep_until"]):
		return false
	return float(p.get("stamina", 0.0)) >= stamina_min_start()

func add_player(id: int, pname: String) -> Dictionary:
	var idx := players.size()
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
		"tile": 0,
		"progress": 0.0,
		"dir": 1,
		"moving": 0,
		"speed": MOVE_SPEED,
		"alive": true,
		"idle": 0.0,
		"color": PLAYER_COLORS[idx % PLAYER_COLORS.size()].to_html(false),
		"cards": [],
		"effects": {
			"invincible_until": 0.0,      # 绝对时刻（秒）
			"sleep_until": 0.0,           # 绝对时刻（秒）
			"invisible_until": 0.0,       # 绝对时刻（秒，隐形卡 Card_YinXing_Ticks = 72）
			"rush_until": 0.0,            # 绝对时刻（秒，暴走卡：加速且不走体力）
			"no_rent_steps": 0,           # 剩余步数（免费卡 / Card_MianFei_Steps）
			"no_rent_until": 0.0,         # 绝对时刻（小财神「免费技」按**秒**算，与上面的步数版区分）
			"rent_pay_double_until": 0.0, # 绝对时刻（小穷神「穷神技」：被附身者付双倍罚金）
			"pet_max_dice": 0,            # 小赌神「骰子技 遥控骰子」：下次掷骰取最大点数的次数
			"rent_double_steps": 0,       # 剩余步数（穷神卡 / Card_QiongShen_Steps）
			"free_upgrade_steps": 0,      # 剩余步数（福神卡 / Card_FuShen_Steps = 30）
			"no_upgrade_steps": 0,        # 剩余步数（衰神卡 / Card_ShuaiShen_Steps = 30）
		},
		"pending_steps": false,   # 骰子卡：等玩家点「走几步」（String.txt 9016「自由选择前进的步数」）
		"last_plot": -1,
		"last_plot_kind": "",     # "buy" / "upgrade" —— 本次抵达留下的**一次性**机会
		"last_roll": 0,
		"role": idx + 1,          # 角色序号 1..12，对应原版 Role.txt 行序 / sound/player/roleN
	}
	players[id] = p
	log_message.emit("%s 加入游戏" % pname)
	return p


func _ev(kind: String, p, extra: Dictionary = {}) -> void:
	## 发一条语义事件（表现层据此配音效与语音）
	var d: Dictionary = extra.duplicate()
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
	time += dt
	tick_count += 1

	for id in player_ids():
		var p: Dictionary = players[id]
		if not p["alive"]:
			continue

		# 体力随时间恢复（原版「每秒恢复体力」）—— 睡着了也恢复
		p["stamina"] = minf(stamina_max(),
			float(p.get("stamina", 0.0)) + stamina_regen() * dt)

		# 暴走卡到点 → 速度恢复正常
		if float(p["effects"]["rush_until"]) > 0.0 \
				and time >= float(p["effects"]["rush_until"]):
			p["effects"]["rush_until"] = 0.0
			p["speed"] = MOVE_SPEED

		# 睡眠 / 冬眠状态
		if time < float(p["effects"]["sleep_until"]):
			continue

		if p["moving"] > 0:
			_advance(p, dt)
		else:
			p["idle"] = float(p["idle"]) + dt
			if float(p["idle"]) >= IDLE_SLEEP_SECONDS:
				p["idle"] = 0.0
				var delay := rng.randf_range(6.0, 12.0)
				p["effects"]["sleep_until"] = time + delay
				log_message.emit("%s 打了个盹，%.0f 秒后继续" % [p["name"], delay])
				_ev("sleep", p)

func _advance(p: Dictionary, dt: float) -> void:
	var step_dist: float = float(p["speed"]) * dt
	p["progress"] = float(p["progress"]) + step_dist
	while float(p["progress"]) >= 1.0 and int(p["moving"]) > 0:
		p["progress"] = float(p["progress"]) - 1.0
		p["tile"] = _wrap(int(p["tile"]) + int(p["dir"]))
		p["moving"] = int(p["moving"]) - 1
		_tick_step_effects(p)
		# 每前进 1 格扣体力（原版「每走一步消耗体力」）。
		# ⚠️ 出发门槛（min_to_start）只在 act_roll 判定；已经上路的不因为半路见底而原地卡住
		#   —— 原版注释里那一项写的是「自己走**所需要**最小体力值」，是出发条件。
		# 暴走卡（9015「不消耗体力疯狂前进」）期间不扣。
		if float(p["effects"]["rush_until"]) <= time:
			p["stamina"] = maxf(0.0, float(p.get("stamina", 0.0)) - stamina_step_cost())
		# 踩到路面道具（地雷卡 / 路障卡）
		var ob := _obstacle_at(int(p["tile"]))
		if not ob.is_empty():
			_remove_obstacle(int(ob["idx"]))
			if str(ob["kind"]) == "mine":
				if float(p["effects"]["invincible_until"]) <= time:
					p["stamina"] = maxf(0.0, float(p.get("stamina", 0.0)) - 300.0)
					p["effects"]["sleep_until"] = time + 3.0
					log_message.emit("%s 踩到地雷，损失体力并停留 3 秒" % p["name"])
					_ev("mine", p, {"idx": int(p["tile"]), "owner": int(ob["owner"])})
				p["moving"] = 0
				p["progress"] = 0.0
			else:
				p["moving"] = 0
				p["progress"] = 0.0
				log_message.emit("%s 被路障挡住" % p["name"])
				_ev("roadblock", p, {"idx": int(p["tile"]), "owner": int(ob["owner"])})
	if int(p["moving"]) <= 0:
		p["moving"] = 0
		p["progress"] = 0.0
		p["idle"] = 0.0
		# 骰子在这一刻停住（音效 005「骰子滚动结束」的时机，老板试听确认）
		_ev("roll_end", p)
		_arrive(p)

func _tick_step_effects(p: Dictionary) -> void:
	## 每走 1 格，把所有「多少步」类的状态各减 1
	## （原版 Initvar_r.txt：Card_MianFei_Steps / Card_FuShen_Steps / Card_ShuaiShen_Steps …）
	var e: Dictionary = p["effects"]
	for k in STEP_EFFECTS:
		if int(e[k]) > 0:
			e[k] = int(e[k]) - 1

func _wrap(i: int) -> int:
	var n := map.tile_count()
	return ((i % n) + n) % n

# --------------------------------------------------------------- 到达格结算

func _arrive(p: Dictionary) -> void:
	var idx: int = int(p["tile"])
	var t: Dictionary = map.tile(idx)
	# 上一次抵达留下的「一次性机会」作废 —— 想再动这块地，必须再走回来
	# （原版 Info.txt id 93：升级是抵达时的一次询问，不是随时可点）
	_clear_chance(p)

	match t.get("kind", ""):
		"plot":
			_resolve_plot(p, idx, t)
		"event":
			_resolve_event(p, idx, t)
		"start":
			pass
	# 格子结算完之后再给小神仙一次发动机会（它们的效果不再回头触发本函数）
	_tick_pets(p)

func _clear_chance(p: Dictionary) -> void:
	p["last_plot"] = -1
	p["last_plot_kind"] = ""

func _resolve_plot(p: Dictionary, idx: int, t: Dictionary) -> void:
	var street: String = t.get("street", "")
	if not plots.has(idx):
		# 空地：原版 Info.txt id 91「<ROAD>\n购买价格<NUMBER>元\n是否购买」
		p["last_plot"] = idx
		p["last_plot_kind"] = "buy"
		log_message.emit("%s 抵达 %s（空地，可购买）" % [p["name"], street])
		_ev("arrive_empty", p, {"idx": idx, "street": street, "price": EMPTY_PLOT_PRICE})
		return

	var plot: Dictionary = plots[idx]
	var owner: int = int(plot["owner"])
	var level: int = int(plot["level"])
	var ptype: String = str(plot.get("type", ""))

	if owner == int(p["id"]):
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
		var target := level + 1
		var mx := max_level(ptype)
		if level >= mx:
			_ev("arrive_own", p, {"idx": idx, "street": street, "level": level,
				"type": ptype, "maxed": true})
			log_message.emit("  已是最高等级（%s）" % str(Rules.house_grade(ptype, mx).get("name", "")))
			return
		p["last_plot"] = idx
		p["last_plot_kind"] = "upgrade"
		var cost := upgrade_cost(p, idx, "")
		var opts: Array = buildable_types() if ptype == "" else []
		_ev("arrive_own", p, {"idx": idx, "street": street, "level": level, "type": ptype,
			"target": target, "cost": cost, "options": opts,
			"free": int(p["effects"]["free_upgrade_steps"]) > 0})
		log_message.emit("  可升级到 %d 级%s，费用 %d 元" % [
			target, "（需选择房型）" if ptype == "" else "", cost])
		return

	# ---- 踩到别人的地：交租（原版 id 94）----
	# 免费卡按**步数**、小财神「免费技」按**秒**（Pet.txt 即时制那一行）—— 语义不同，
	# Info.txt 1051 也把「免费状态」单独列了一条，所以两个字段并存。
	if int(p["effects"]["no_rent_steps"]) > 0:
		log_message.emit("%s 使用免费卡，免付过路费" % p["name"])
		_ev("free_rent", p, {"idx": idx, "street": street})
		return
	if float(p["effects"].get("no_rent_until", 0.0)) > time:
		log_message.emit("%s 的小财神显灵，免付租金" % p["name"])
		_ev("free_rent", p, {"idx": idx, "street": street, "by_pet": "caishen"})
		return

	# 查封卡（9031）：查封期内这条街不收租
	var sealed_until := float(street_seal.get(street, 0.0))
	if sealed_until > time:
		log_message.emit("%s 踩到查封中的 %s，免收过路费" % [p["name"], street])
		_ev("sealed_rent", p, {"idx": idx, "street": street, "until": sealed_until})
		return

	var rent := _rent_of(level, ptype)
	# 涨价卡 / 降价卡（9021/9022）：街道地价系数直接作用在租金上
	var bang := int(street_index.get(street, 0))
	if bang != 0:
		rent = int(round(float(rent) * (1.0 + float(bang) / 100.0)))
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
		"level": level, "type": ptype})

## 该等级被踩到时的过路费（元）。等级 0 = 尚未建设的空地。
func _rent_of(level: int, type_id: String = "") -> int:
	if level <= 0:
		return EMPTY_PLOT_RENT
	return Rules.house_rent(type_id, level)

## 路面事件（权威表 = 原版 config/Roadevent.txt 的 1..16，地图 JSON 的 event 字段即这张表的 key）
func _resolve_event(p: Dictionary, idx: int, t: Dictionary) -> void:
	var eid: String = t.get("event", "")
	var ename: String = t.get("name", eid)
	match eid:
		"hospital":
			# Event_Hospital_MinTime/MaxTime 在即时制下为 0，此处给固定 8 秒以示差异
			p["effects"]["sleep_until"] = time + 8.0
			log_message.emit("%s 进入%s，住院 8 秒" % [p["name"], ename])
			_ev("hospital", p, {"eid": eid})
		"platform":
			# 传送平台：挪到地图上另一处 platform（原版 Roadevent.txt 事件 1）
			var dest := _other_platform(idx)
			if dest >= 0:
				p["tile"] = dest
				p["progress"] = 0.0
				log_message.emit("%s 踩上%s，被送到另一处平台" % [p["name"], ename])
			_ev("platform", p, {"eid": eid, "to": dest})
		"cardshop":
			# 卡片商店：**用点券买卡**（Info.txt 41「卡片商店 您有<NUMBER>点券」/
			# 42「您没有点券 不能进入卡片商店」）。这里是「开架」——
			# 真正的购买走 act_buy_card()，由 UI 的商店面板发指令（uitex/other/cardshop.tga）。
			_ev("cardshop_open", p, {"eid": eid, "credit": int(p["credit"]),
				"stock": _shop_stock(), "have": int(p["credit"])})
			log_message.emit("%s 走进%s（点券 %d）" % [p["name"], ename, int(p["credit"])])
		"cardpt":
			# 卡片点：直接捡一张卡（原版路面物体 roadobj/card/ 的 3D 实体未接入）
			_give_random_card(p, ename)
		"coupon5", "coupon10", "coupon20", "coupon30", "coupon50":
			# 点券格：事件名就是面额（Roadevent.txt 事件 11..15）
			var amount := int(eid.substr(6))
			p["credit"] = int(p["credit"]) + amount
			log_message.emit("%s 在%s获得 %d 点券" % [p["name"], ename, amount])
			_ev("credit", p, {"eid": eid, "amount": amount})
		"tvnews":
			# 电视台：上新闻拿奖励（XinWen 系列，奖励区间 Event_News_BonusMin/Max）
			var lo := int(Rules.get_val("events.news_bonus_min", 1000))
			var hi := int(Rules.get_val("events.news_bonus_max", 10000))
			var bonus := _round100(rng.randi_range(lo, hi))
			p["money"] = int(p["money"]) + bonus
			log_message.emit("%s 上了%s，获得通告费 %d 元" % [p["name"], ename, bonus])
			_ev("news", p, {"eid": eid, "amount": bonus})
		"labar":
			# 拉霸（原名 labar，即 slot）：押一次，赢了翻倍、输了交钱
			var stake := 1000
			if int(p["money"]) >= stake * 2 and rng.randi_range(0, 2) == 0:
				p["money"] = int(p["money"]) + stake
				log_message.emit("%s 在%s拉中大奖，赢 %d 元" % [p["name"], ename, stake])
				_ev("win_money", p, {"eid": eid, "amount": stake})
			else:
				_transfer(p, null, stake, ename)
				log_message.emit("%s 在%s输掉 %d 元" % [p["name"], ename, stake])
				_ev("lose_money", p, {"eid": eid, "amount": stake})
		"capital":
			# 市政府：按市政基金征收 / 发放（Event_CityFund_MinValue）
			var fund := int(Rules.get_val("economy.city_fund_min", 1000))
			if rng.randi_range(0, 1) == 0:
				_transfer(p, null, fund, ename)
				log_message.emit("%s 在%s缴纳市政基金 %d 元" % [p["name"], ename, fund])
				_ev("lose_money", p, {"eid": eid, "amount": fund})
			else:
				p["money"] = int(p["money"]) + fund
				log_message.emit("%s 在%s领到市政补助 %d 元" % [p["name"], ename, fund])
				_ev("win_money", p, {"eid": eid, "amount": fund})
		"pethouse":
			# 精灵屋：**用点券买**（Info.txt 201「精灵屋 请选购小神仙」/ 202 上限 5 位 /
			# 203「<BABYNAME>价格<NUMBER>点券 确认要购买吗？」）。
			# 这里是「开店」——真正的购买走 act_buy_pet()，由 UI 的商店面板发指令。
			log_message.emit("%s 走进%s，点券 %d" % [p["name"], ename, int(p["credit"])])
			_ev("pethouse_open", p, {"eid": eid, "credit": int(p["credit"]),
				"owned": pet_count(p), "max": max_pets()})
		"game_a", "game_b":
			# 游戏点：记忆游戏，按成绩给点券（Event_MemoryGame_CreditMin/Max）
			var lo2 := int(Rules.get_val("events.memory_game_credit_min", 1))
			var hi2 := int(Rules.get_val("events.memory_game_credit_max", 50))
			var g := rng.randi_range(lo2, hi2)
			p["credit"] = int(p["credit"]) + g
			log_message.emit("%s 在%s玩了一把，赢得 %d 点券" % [p["name"], ename, g])
			_ev("credit", p, {"eid": eid, "amount": g})
		"casino":
			var fee := int(Rules.get_val("events.casino_fee", 2500))
			_transfer(p, null, fee, "乐透")
			log_message.emit("%s 在%s花费 %d 元" % [p["name"], ename, fee])
			_ev("casino", p, {"eid": eid, "fee": fee})
		_:
			log_message.emit("%s 抵达 %s" % [p["name"], ename])
			_ev("event", p, {"eid": eid, "ename": ename})

## 给玩家一张随机卡（卡片商店 / 卡片点共用）
func _give_random_card(p: Dictionary, ename: String) -> void:
	var c := _random_card()
	(p["cards"] as Array).append(c)
	var cname := str(Rules.card_by_id(c).get("name", c))
	log_message.emit("%s 在%s获得卡片「%s」" % [p["name"], ename, cname])
	_ev("get_card", p, {"card": c, "name": cname})

## 地图上另一处 platform 格的索引（没有第二处就返回 -1）
func _other_platform(idx: int) -> int:
	for i in range(map.tile_count()):
		if i != idx and str(map.tile(i).get("event", "")) == "platform":
			return i
	return -1

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

func act_roll(id: int, dice_count: int = 1) -> bool:
	## 掷骰 —— 即时制下掷出后角色连续移动。
	## dice_count = 一次同时掷几颗（原版 GO 钮左侧的骰子选择器，见 DICE_PER_ROLL_MAX）。
	var p: Dictionary = players.get(id, {})
	if p.is_empty() or not p["alive"] or int(p["moving"]) > 0:
		return false
	if time < float(p["effects"]["sleep_until"]):
		return false
	# 原版「自己走所需要最小体力值」——体力不够不给出发
	if float(p.get("stamina", 0.0)) < stamina_min_start():
		var missing := stamina_min_start() - float(p.get("stamina", 0.0))
		log_message.emit("%s 体力不足（%.0f/%.0f），还要歇 %.0f 秒" % [
			p["name"], float(p["stamina"]), stamina_max(),
			missing / maxf(stamina_regen(), 0.001)])
		_ev("no_stamina", p, {"stamina": float(p["stamina"]), "need": stamina_min_start()})
		return false
	var d := clampi(dice_count, 1, DICE_PER_ROLL_MAX)
	# 小赌神「骰子技 遥控骰子」（String.txt 2208）：下一掷必出最大点数
	var remote := int(p["effects"].get("pet_max_dice", 0)) > 0
	if remote:
		p["effects"]["pet_max_dice"] = int(p["effects"]["pet_max_dice"]) - 1
	var faces: Array = []
	var n := 0
	for i in d:
		var f := 6 if remote else rng.randi_range(1, 6)
		faces.append(f)
		n += f
	if remote:
		log_message.emit("%s 的小赌神遥控骰子 → %d 点" % [p["name"], n])
		_ev("pet_dice", p, {"n": n, "faces": faces})
	p["moving"] = n
	p["idle"] = 0.0
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
func upgrade_cost(p: Dictionary, idx: int, want_type: String = "") -> int:
	if idx < 0 or not plots.has(idx):
		return 0
	var plot: Dictionary = plots[idx]
	var ptype := str(plot.get("type", ""))
	if ptype == "":
		var al := buildable_types()
		ptype = want_type if (want_type != "" and al.has(want_type)) \
			else (str(al[0]) if not al.is_empty() else "uptown")
	if int(p["effects"]["free_upgrade_steps"]) > 0:
		return 0                      # 福神卡：「<NUMBER>步之内免费加盖」（id 1001）
	return Rules.house_upgrade_cost(ptype, int(plot["level"]) + 1)

func act_buy(id: int) -> bool:
	## 买下**本次抵达**的空地（原版 id 91）。买地只拿到「空地」，
	## 房屋要等下一次抵达时用升级/建设来做（原版 id 88 把「空地」和「升级」并列）。
	var p: Dictionary = players.get(id, {})
	if p.is_empty() or not p["alive"]:
		return false
	if int(p["last_plot"]) < 0 or str(p.get("last_plot_kind", "")) != "buy":
		return false
	var idx: int = int(p["last_plot"])
	if plots.has(idx):
		return false
	var price := EMPTY_PLOT_PRICE
	if int(p["money"]) < price:
		log_message.emit("%s 资金不足，无法购地" % p["name"])
		_ev("insufficient_money", p, {"idx": idx, "need": price, "have": int(p["money"])})
		return false
	p["money"] = int(p["money"]) - price
	# type 为空 = 还没建房（原版 id 92 的「选择房屋」发生在建设时）
	plots[idx] = {"owner": id, "level": 0, "type": ""}
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
		if want_type != "" and al.has(want_type):
			ptype = want_type
		elif al.size() == 1:
			ptype = str(al[0])          # 只有一种房屋时不询问（原版 id 92 批注）
		else:
			log_message.emit("%s 需要先选择房屋类型：%s" % [p["name"], str(al)])
			_ev("need_house_type", p, {"idx": idx, "street": map.street_of(idx), "options": al})
			return false
		plot["type"] = ptype

	var lv: int = int(plot["level"])
	if lv >= max_level(ptype):
		return false
	var target := lv + 1
	var cost := upgrade_cost(p, idx, ptype)
	if int(p["money"]) < cost:
		log_message.emit("%s 资金不足，无法升级（需 %d 元）" % [p["name"], cost])
		_ev("insufficient_money", p, {"idx": idx, "need": cost, "have": int(p["money"])})
		return false

	p["money"] = int(p["money"]) - cost
	plot["level"] = target
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
	var ptype := str(plot.get("type", ""))
	if ptype == "":
		var al := buildable_types()
		ptype = want_type if (want_type != "" and al.has(want_type)) \
			else (str(al[0]) if not al.is_empty() else "uptown")
		plot["type"] = ptype
	var lv: int = int(plot["level"])
	if lv >= max_level(ptype):
		return false
	var cost := Rules.house_upgrade_cost(ptype, lv + 1)
	if free_cost:
		cost = 0
	else:
		if int(p["money"]) < cost:
			return false
		p["money"] = int(p["money"]) - cost
	plot["level"] = lv + 1
	_ev("upgrade", p, {"idx": idx, "level": lv + 1, "cost": cost,
		"street": map.street_of(idx), "type": ptype, "forced": true})
	return true

## 挑一块「还升得动」的自己的地，等级最高的优先（租金收益最大）
func _own_plot_to_upgrade(id: int) -> int:
	var best := -1
	var best_lv := -1
	for k in plots.keys():
		var pl: Dictionary = plots[k]
		if int(pl["owner"]) != id:
			continue
		var t := str(pl.get("type", ""))
		var mx := max_level(t) if t != "" else Rules.FALLBACK_MAX_LEVEL
		if int(pl["level"]) >= mx:
			continue
		if int(pl["level"]) > best_lv:
			best_lv = int(pl["level"])
			best = int(k)
	return best

## 挑一块对手的、等级最高的地（怪兽卡 / 破坏类卡片的目标）
func _enemy_plot_best(id: int) -> int:
	var best := -1
	var best_lv := -1
	for k in plots.keys():
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
		return EMPTY_PLOT_PRICE
	var pl: Dictionary = plots[idx]
	var v := EMPTY_PLOT_PRICE
	var tp := str(pl.get("type", ""))
	for lv in range(1, int(pl["level"]) + 1):
		v += Rules.house_upgrade_cost(tp, lv)
	return v


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
func card_usable(id: int, card_id: String) -> int:
	var p: Dictionary = players.get(id, {})
	if p.is_empty() or not bool(p["alive"]):
		return 61
	# ⚠ 不拦「正在走」—— 即时制下角色一直在走，而原版的停留卡（9040「原地停留一次」）
	#   正是**走着的时候**用的（强制停下）。只有「骰子卡正在等你点步数」才是真正的
	#   模态状态，不能插队。
	if bool(p.get("pending_steps", false)):
		return 61
	if CARD_UNSUPPORTED.has(card_id):
		return 67 if card_id == "copy" else 61
	var eff := str(Rules.card_by_id(card_id).get("effect", ""))
	var here := int(p["tile"])
	var owned := plots.has(here)
	var enemy_here := owned and int(plots[here]["owner"]) != id
	var street := map.street_of(here)
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
		"upgrade_building", "change_building_type":
			if _own_plot_to_upgrade(id) < 0 and not _has_own_plot(id):
				return 64                  # String.txt 64「只能用于自己的地产」
			if eff == "upgrade_building" and _own_plot_to_upgrade(id) < 0:
				return 65                  # 自己的房子都满级了 / 一栋都没有
		"auto_upgrade":
			if _own_plot_to_upgrade(id) < 0:
				return 65                  # 没有可升级的房屋
		# ---- 要有「可破坏的目标」的 ----
		"auto_downgrade":
			var n := 0
			for k in _street_plots(street):
				if int(plots[k]["level"]) > 0:
					n += 1
			if n == 0:
				return 65                  # String.txt 65「没有建筑」
		"downgrade_building":
			if _enemy_plot_best(id) < 0:
				return 65
		"destroy_buildings", "nuke":
			var r := int(Rules.card_by_id(card_id).get("range", 5))
			var h := 0
			for k in plots.keys():
				if _tile_distance(int(k), here) <= r and int(plots[k]["level"]) > 0:
					h += 1
			if h == 0:
				return 65
		# ---- 要有路面道具可清 ----
		"remove_obstacle":
			if not _has_obstacle_ahead(p, 3):
				return 61
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


func act_use_card(id: int, card_id: String, target: int = -1) -> bool:
	## 使用一张手牌。
	## target = 需要「点选对手」时的目标玩家 id（其余卡忽略；见 CARD_TARGET）。
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
		if tp.is_empty() or int(target) == id or not bool(tp["alive"]):
			_ev("need_card_target", p, {"card": card_id, "name": cname,
				"target_kind": "player", "prompt": Rules.card_target_prompt("player")})
			return false

	var c := Rules.card_by_id(card_id)
	if not _apply_card(p, card_id, c, p["effects"], target):
		# 门禁过了但效果没生效（典型：对手身上没东西可抢）→ 也要给反馈，不静默
		_ev("card_unavailable", p, {"card": card_id, "name": cname, "code": 61})
		return false
	arr.remove_at(at)                       # 只有真的生效才把卡拿走
	log_message.emit("%s 使用 %s" % [p["name"], cname])
	_ev("use_card", p, {"card": card_id, "name": cname,
		"effect": str(c.get("effect", "")), "target": target})
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
	log_message.emit("%s 丢弃了 %s" % [p["name"], Rules.card_name(card_id)])
	_ev("discard_card", p, {"card": card_id, "name": Rules.card_name(card_id)})
	return true


## 骰子卡：自选步数（String.txt 9016「自由选择前进的步数」）
func act_walk(id: int, steps: int) -> bool:
	var p: Dictionary = players.get(id, {})
	if p.is_empty() or not p["alive"] or int(p["moving"]) > 0:
		return false
	if not bool(p.get("pending_steps", false)):
		return false
	p["pending_steps"] = false
	var n := clampi(steps, 1, 6)
	p["moving"] = n
	p["idle"] = 0.0
	p["last_roll"] = n
	p["last_faces"] = [n]
	log_message.emit("%s 用骰子卡前进 %d 步" % [p["name"], n])
	_ev("roll", p, {"n": n, "dice": 1, "faces": [n], "by_card": "dice"})
	return true


## 真正执行卡的效果。返回 false = 没生效（卡片保留）。
func _apply_card(p: Dictionary, card_id: String, c: Dictionary, e: Dictionary,
		target: int) -> bool:
	var pid := int(p["id"])
	var here := int(p["tile"])
	var street := map.street_of(here)
	var eff := str(c.get("effect", ""))

	match eff:
		# ---------------- 自身状态 ----------------
		"no_rent":
			e["no_rent_steps"] = int(c.get("steps", 20))
			log_message.emit("%s 免费卡：%d 步内免付房租" % [p["name"], int(e["no_rent_steps"])])
		"immune":
			e["invincible_until"] = time + float(c.get("seconds", 72))
			log_message.emit("%s 进入无敌状态 %.0f 秒" % [p["name"], float(c.get("seconds", 72))])
		"invisible":
			e["invisible_until"] = time + float(c.get("seconds", 72))
			log_message.emit("%s 进入隐形状态 %.0f 秒" % [p["name"], float(c.get("seconds", 72))])
		"move":
			p["moving"] = int(p["moving"]) + int(c.get("distance", 1))
			p["idle"] = 0.0
		"reverse_direction":
			p["dir"] = -int(p["dir"])
		"double_speed":
			# 暴走卡（9015「不消耗体力疯狂前进」）
			e["rush_until"] = time + 12.0
			p["speed"] = MOVE_SPEED * 2.0
			log_message.emit("%s 暴走 12 秒（不耗体力）" % p["name"])
		"reroll":
			# 骰子卡：把「走几步」交给玩家点（UI 弹 1..6）
			p["pending_steps"] = true
			log_message.emit("%s 用骰子卡，请选择前进步数" % p["name"])
			_ev("card_choose_steps", p, {"card": card_id})
		"heal":
			# 汉堡卡（9034「补充自己的体力」）—— 原版的 HP 就是即时制的「体力」
			var inc := float(c.get("hp", 500))
			p["stamina"] = minf(stamina_max(), float(p.get("stamina", 0.0)) + inc)
			p["hp"] = int(p["hp"]) + int(inc)
			log_message.emit("%s 吃掉汉堡，体力 +%d" % [p["name"], int(inc)])
		"gain_money":
			var amt := rng.randi_range(int(c.get("min", 10000)), int(c.get("max", 50000)))
			p["money"] = int(p["money"]) + amt
			var nr := int(c.get("no_rent_steps", 0))
			if nr > 0:
				e["no_rent_steps"] = nr      # 财神卡额外给「N 步内免付房租」
			log_message.emit("%s 得到 %d 元" % [p["name"], amt])
			_ev("win_money", p, {"amount": amt, "card": card_id})
		"gain_gems":
			p["gems"] = int(p.get("gems", 0)) + 1
			log_message.emit("%s 得到 1 颗宝石（共 %d）" % [p["name"], int(p["gems"])])
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
			t1["effects"]["rent_double_steps"] = int(c.get("steps", 30))
			log_message.emit("%s 让穷神附上 %s：%d 步内房租加倍" % [
				p["name"], t1["name"], int(c.get("steps", 30))])
		"no_upgrade":
			# 衰神卡（9004「指定衰神附身的对象」）
			var t2: Dictionary = players[target]
			t2["effects"]["no_upgrade_steps"] = int(c.get("steps", 30))
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
			tc.remove_at(ci)
			(p["cards"] as Array).append(stolen)
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
			var stolen_pet: Dictionary = tps.pop_back()
			var spid := str(stolen_pet.get("id", ""))
			(p["pets"] as Array).append(stolen_pet)
			log_message.emit("%s 诱拐了 %s 的「%s」（%d 级）" % [
				p["name"], t6["name"], pet_name(spid), int(stolen_pet.get("level", 1))])
			_ev("steal_pet", p, {"pet": spid, "name": pet_name(spid),
				"from": target, "card": card_id})

		# ---------------- 街道 / 地价 / 查封 ----------------
		"raise_estate_index", "lower_estate_index":
			var d := int(c.get("amount", 5))
			var delta := d if eff == "raise_estate_index" else -d
			street_index[street] = int(street_index.get(street, 0)) + delta
			log_message.emit("%s：%s 地价 %+d%%（现 %+d%%）" % [
				p["name"], street, delta, int(street_index[street])])
			_ev("estate_index", p, {"street": street, "delta": delta,
				"value": int(street_index[street]), "card": card_id})
		"seal_building":
			# 查封卡（9031「当前街道暂停收取房租」，Card_ChaFeng_Days = 5 天）
			var days := float(c.get("days", 5))
			street_seal[street] = time + days * Rules.seconds_per_day()
			log_message.emit("%s 查封了 %s（%.0f 天内不收租）" % [p["name"], street, days])
			_ev("seal", p, {"street": street, "until": street_seal[street], "card": card_id})
		"auto_downgrade":
			# 恶魔卡（9006「袭击一条街道的所有房屋」）
			var cnt := 0
			for k in _street_plots(street):
				if int(plots[k]["level"]) > 0:
					plots[k]["level"] = int(plots[k]["level"]) - 1
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
			e["free_upgrade_steps"] = int(c.get("steps", 30))
			var n := int(c.get("cards_gained", 0))
			for _i in range(n):
				(p["cards"] as Array).append(_random_card())
			log_message.emit("%s 福神附身：%d 步内免费加盖，得 %d 张卡" % [
				p["name"], int(e["free_upgrade_steps"]), n])
		"auto_upgrade":
			var ti := _own_plot_to_upgrade(pid)
			if ti < 0:
				log_message.emit("%s 使用天使卡，但没有可升级的房屋" % p["name"])
				return false
			force_upgrade(pid, ti, true)
			log_message.emit("%s 的天使把 %s 升了一级" % [p["name"], map.street_of(ti)])
		"upgrade_building":
			var ti2 := _own_plot_to_upgrade(pid)
			if ti2 < 0:
				log_message.emit("%s 使用升级卡，但没有可升级的房屋" % p["name"])
				return false
			force_upgrade(pid, ti2, true)
			log_message.emit("%s 用升级卡把 %s 升了一级" % [p["name"], map.street_of(ti2)])
		"downgrade_building":
			# 怪兽卡（9019「袭击一栋房屋」）：优先拆**当前格**的对手房，否则挑最好的
			var ei := here if (plots.has(here) and int(plots[here]["owner"]) != pid) \
				else _enemy_plot_best(pid)
			if ei < 0 or not plots.has(ei) or int(plots[ei]["level"]) <= 0:
				return false
			plots[ei]["level"] = int(plots[ei]["level"]) - 1
			log_message.emit("%s 的怪兽把 %s 拆了一级" % [p["name"], map.street_of(ei)])
			_ev("downgrade", p, {"idx": ei, "level": int(plots[ei]["level"]),
				"street": map.street_of(ei), "card": card_id})
		"change_building_type":
			var mi := here if (plots.has(here) and int(plots[here]["owner"]) == pid) else -1
			if mi < 0:
				for k in plots.keys():
					if int(plots[k]["owner"]) == pid:
						mi = int(k)
						break
			if mi < 0:
				return false
			var al := buildable_types()
			var cur := str(plots[mi].get("type", ""))
			var ic := al.find(cur)
			var nxt := str(al[(ic + 1) % al.size()]) if al.size() > 0 else "uptown"
			var lv: int = int(plots[mi]["level"])
			plots[mi]["type"] = nxt
			if lv > 0:
				plots[mi]["level"] = mini(lv, max_level(nxt))
			log_message.emit("%s 用改建卡把 %s 改成%s" % [
				p["name"], map.street_of(mi), Rules.house_type_cn(nxt)])
			_ev("rebuild", p, {"idx": mi, "type": nxt, "level": int(plots[mi]["level"]),
				"card": card_id})
		"force_stop":
			p["moving"] = 0
			p["progress"] = 0.0
			var here2: int = int(p["tile"])
			_clear_chance(p)
			_arrive(p)
			log_message.emit("%s 用停留卡在 %s 又停了一站" % [p["name"], map.street_of(here2)])

		# ---------------- 路面道具 / 爆炸 ----------------
		"place_mine":
			_add_obstacle(_wrap(here - int(p["dir"])), "mine", pid)
			log_message.emit("%s 在身后放了一颗地雷" % p["name"])
		"place_roadblock":
			_add_obstacle(_wrap(here + int(p["dir"])), "roadblock", pid)
			log_message.emit("%s 在前面放了一个路障" % p["name"])
		"remove_obstacle":
			# 清除卡（9039「清除前方道路垃圾」）
			var removed := _clear_obstacles_ahead(p, 3)
			if removed == 0:
				return false
			log_message.emit("%s 清除了前方 %d 处路障" % [p["name"], removed])
		"destroy_buildings", "nuke":
			# 飞弹卡（9027）/ 核弹卡（9042）
			var r := int(c.get("range", 5))
			var dec := int(c.get("max_damage", c.get("hp_dec", 0)))
			var hits := _damage_area(here, r, dec, pid)
			if hits == 0:
				return false
			log_message.emit("%s 引爆，波及 %d 处" % [p["name"], hits])
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
				q["effects"]["sleep_until"] = maxf(float(q["effects"]["sleep_until"]), time + secs)
				q["moving"] = 0
				n2 += 1
				_ev("sleep", q, {"card": card_id, "seconds": secs})
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
	for k in plots.keys():
		if map.street_of(int(k)) == street:
			out.append(int(k))
	return out

## 环形棋盘上的最短格距
func _tile_distance(a: int, b: int) -> int:
	var n := map.tile_count()
	if n <= 0:
		return 0
	var d := absi(a - b)
	return mini(d, n - d)

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

## 清除玩家前方 n 格内的路面道具，返回清掉的数量
func _clear_obstacles_ahead(p: Dictionary, n: int) -> int:
	var c := 0
	for i in range(1, n + 1):
		var idx := _wrap(int(p["tile"]) + int(p["dir"]) * i)
		if not _obstacle_at(idx).is_empty():
			_remove_obstacle(idx)
			c += 1
	return c

## 以 idx 为中心、半径 radius 内的房屋各降一级，并给范围内玩家扣体力
func _damage_area(idx: int, radius: int, hp_dec: int, owner_id: int) -> int:
	var hits := 0
	for k in plots.keys():
		if _tile_distance(int(k), idx) <= radius and int(plots[k]["level"]) > 0:
			plots[k]["level"] = int(plots[k]["level"]) - 1
			hits += 1
	for oid in player_ids():
		var q: Dictionary = players[oid]
		if not bool(q["alive"]):
			continue
		if float(q["effects"]["invincible_until"]) > time:
			continue                       # 无敌卡期间不吃伤害
		if _tile_distance(int(q["tile"]), idx) <= radius and hp_dec > 0:
			q["stamina"] = maxf(0.0, float(q.get("stamina", 0.0)) - float(hp_dec))
			hits += 1
	_ev("blast", players.get(owner_id, null),
		{"idx": idx, "radius": radius, "hp_dec": hp_dec, "hits": hits})
	return hits


# ------------------------------------------------------------------- 序列化

func to_dict() -> Dictionary:
	return {
		"t": time,
		"run": running,
		"win": winner,
		"players": players.duplicate(true),
		"plots": plots.duplicate(true),
		"street_index": street_index.duplicate(true),
		"street_seal": street_seal.duplicate(true),
		"obstacles": obstacles.duplicate(true),
	}

func apply_dict(d: Dictionary) -> void:
	time = float(d.get("t", time))
	running = bool(d.get("run", running))
	winner = int(d.get("win", -1))
	players = d.get("players", players)
	street_index = d.get("street_index", street_index)
	street_seal = d.get("street_seal", street_seal)
	obstacles = d.get("obstacles", obstacles)
	# JSON 往返会把 int 键变成 String 键，需归一化
	var fixed := {}
	for k in d.get("plots", {}).keys():
		fixed[int(k)] = d["plots"][k]
	plots = fixed
