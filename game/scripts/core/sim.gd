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

## 掷骰动画时长：点数定下后，**先播「骰子抛出 → 抛物线落下 → 定格点数」**，
## 这段时间角色**站着不动**，动画完了才起步 —— 这就是原版的节奏。
## ⚠️ 我们原来是把 `moving` 一设就走、骰子只是「同时」显示数字，节奏是错的
##    （老板 2026-09-26 反馈）。这个值要和表现层的 `DIE_FLY_TIME` 对齐。
const ROLL_ANIM_SECONDS := 1.15

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

## 还没做的子系统对应的卡 → **不消耗**（宁可留着，也别让玩家白扔一张卡）。
## ✅ 2026-09-26：**红卡 / 黑卡**（股票系统上线）与**复制卡**（本轮）都已解开 → 现在**没有了**，
##   42 张卡全部可用。留这个常量是为了以后加新子系统时继续用同一套门禁。
const CARD_UNSUPPORTED: Array = []

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
	if str(p.get("pet_active", "")) == "":
		p["pet_active"] = pet_id        # 第一只自动「出战」（显示在角色面板的精灵栏位）
	log_message.emit("%s 得到小神仙「%s」" % [p["name"], pet_name(pet_id)])
	_ev("get_pet", p, {"pet": pet_id, "name": pet_name(pet_id)})
	return 0


## 设「出战」的小神仙（原版：点角色面板的精灵栏位打开**仓库**，在里面选一只使用）。
##
## ⚠ 「出战」的**玩法含义**没有明文依据 —— 原版截图只能看出「可以选择要使用的精灵」。
##   这里取最保守的做法：只影响**角色面板精灵栏位显示哪一只**，特技仍然是全部生效。
##   登记在 `docs/alignment-gap.md`。
func act_set_active_pet(id: int, pet_id: String) -> bool:
	var p: Dictionary = players.get(id, {})
	if p.is_empty():
		return false
	if pet_record(pet_id).is_empty() or pet_index_of(p, pet_id) < 0:
		return false
	p["pet_active"] = pet_id
	log_message.emit("%s 把「%s」设为出战" % [p["name"], pet_name(pet_id)])
	_ev("pet_active", p, {"pet": pet_id, "name": pet_name(pet_id)})
	return true


## 当前出战的小神仙（没设过就取第一只；一只都没有返回空字典）
func active_pet(p: Dictionary) -> Dictionary:
	var pets: Array = p.get("pets", [])
	if pets.is_empty():
		return {}
	var want := str(p.get("pet_active", ""))
	for e in pets:
		if str((e as Dictionary).get("id", "")) == want:
			return e
	return pets[0]


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
	var res := _push_card(p, card_id)
	if not bool(res["added"]):
		# 全锁着 → 买不进来，钱退回去
		p["credit"] = int(p["credit"]) + price
		_ev("hand_full", p, {"card": card_id})
		log_message.emit("%s 的卡片栏满了（全锁着），买不下「%s」" % [
			p["name"], Rules.card_name(card_id)])
		return false
	_report_card_push(p, res, Rules.card_name(card_id))
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
	var price := stock_price(comp)
	var cost := int(ceil(price * float(shares)))
	var fee := int(ceil(float(cost) * stock_charge_rate()))
	var need := cost + fee
	if int(p["money"]) < need:
		_ev("insufficient_money", p, {"need": need, "have": int(p["money"])})
		return false
	p["money"] = int(p["money"]) - need
	var h: Dictionary = p.get("holdings", {})
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
	shares = mini(shares, holding_of(id, comp))
	if shares <= 0:
		_ev("stock_no_holding", p, {"company": comp})
		return false
	var price := stock_price(comp)
	var gross := int(price * float(shares))
	var fee := int(ceil(float(gross) * stock_charge_rate()))
	p["money"] = int(p["money"]) + gross - fee
	var h: Dictionary = p.get("holdings", {})
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
		for pid in player_ids():
			_ev("chat", players[pid], payload)
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
	match idx:
		1:   # 股市低迷不振，重挫崩盘
			_news_all_stocks(-float(_news_cfg("stock_down", 1.0)))
		2:   # 股市气势如虹，全面上涨
			_news_all_stocks(float(_news_cfg("stock_up", 0.5)))
		8:   # 外来投资增加，地价上涨 N%
			_news_all_plots(1.0 + float((_news_cfg("all_price_up", [0.1, 0.3]) as Array)[0]))
		9:   # 经济萧条，所有房租下降 N%
			_news_all_plots(1.0 - float((_news_cfg("all_price_down", [0.1, 0.2]) as Array)[1]))
		10:  # 政府向每位市民发放一张卡片
			for pid in player_ids():
				_push_card(players[pid], _random_card())
		11:  # 卡片商店赠送 N 张
			var lo1: Array = _news_cfg("gift_cards", [1, 3]) as Array
			for pid in player_ids():
				for _i in range(rng.randi_range(int(lo1[0]), int(lo1[1]))):
					_push_card(players[pid], _random_card())
		12:  # 卡片商店散落 N 张（撒到棋盘上）
			var lo2: Array = _news_cfg("scatter_cards", [1, 9]) as Array
			for _i in range(rng.randi_range(int(lo2[0]), int(lo2[1]))):
				_spawn_road_obj("card")
		13:  # 强盗遗失宝箱
			for _i in range(rng.randi_range(1, 3)):
				_spawn_road_obj("robber")
		14:  # 精灵遗失魔戒
			for _i in range(rng.randi_range(1, 3)):
				_spawn_road_obj("crystal")
		_:
			pass                          # 3/4/5/6/7：景气 / 停牌 / 利息 —— 只播新闻（效果待做）
	var msg := Rules.info_string(3000 + idx)
	log_message.emit("[新闻] %s" % msg.replace("\n", ""))
	_ev("global_news", null, {"idx": idx, "text": msg, "art": art,
		"info_id": 3000 + idx})


## 新闻「所有股票一起涨 / 跌」
func _news_all_stocks(ratio: float) -> void:
	for nm in stocks.keys():
		var s: Dictionary = stocks[nm]
		var old := float(s["price"])
		s["price"] = maxf(0.1, old * (1.0 + ratio))
		s["prev"] = old


## 新闻「所有地价 / 房租一起变」—— 直接按倍率调地块的地价系数
func _news_all_plots(mul: float) -> void:
	for k in plots.keys():
		var pl: Dictionary = plots[k]
		var v := float(pl.get("price_mul", 1.0)) * mul
		pl["price_mul"] = clampf(v, 0.3, 3.0)


# ------------------------------------------------------------ 拉霸（老虎机）

## 原版「拉霸」= 老虎机（`Info.txt` 66「请投注」；素材 `uitex/casino/`：
## 拱形面板底图 / 兔子女郎 / 拉杆 / `+1000`·`+5000`·`+10000` 三档下注 /
## 滚轮符号 `7`·苹果·香蕉·财神）。
## 参数 = `realtime.json` 的 `events.casino_fee` / `casino_top_rate` / `casino_middle_rate`。
##
## ⚠️ **赔率算法原版没写**（只给了 top / middle 两个倍率）→ 取
##    「三同 = 注额 ×(1+top)；两同 = 注额 ×(1+middle)；否则输掉注额」，登记为推断。
const CASINO_SYMBOLS := ["sym7", "sym_apple", "sym_banana", "sym_god"]

var casino: Dictionary = {}          # {pid: {bet, reels, last}}


func _casino_of(pid: int) -> Dictionary:
	if not casino.has(pid):
		casino[pid] = {"bet": 0, "reels": [], "last": ""}
	return casino[pid]


## 加注（原版那三个 `+1000` / `+5000` / `+10000` 按钮）
func act_casino_bet(id: int, amount: int) -> bool:
	var p: Dictionary = players.get(id, {})
	if p.is_empty() or amount <= 0 or not bool(p["alive"]):
		return false
	if int(p["money"]) < amount:
		_ev("insufficient_money", p, {"need": amount, "have": int(p["money"])})
		return false
	p["money"] = int(p["money"]) - amount
	var st := _casino_of(id)
	st["bet"] = int(st["bet"]) + amount
	_ev("casino_bet", p, {"amount": amount, "bet": int(st["bet"])})
	return true


## 拉杆：转三个滚轮并结算
func act_casino_pull(id: int) -> bool:
	var p: Dictionary = players.get(id, {})
	if p.is_empty():
		return false
	var st := _casino_of(id)
	if int(st["bet"]) <= 0:
		_ev("casino_need_bet", p, {})
		return false
	var reels: Array = []
	for _i in range(3):
		reels.append(CASINO_SYMBOLS[rng.randi_range(0, CASINO_SYMBOLS.size() - 1)])
	st["reels"] = reels
	var bet := int(st["bet"])
	st["bet"] = 0
	var same := 0
	if reels[0] == reels[1] and reels[1] == reels[2]:
		same = 3
	elif reels[0] == reels[1] or reels[1] == reels[2] or reels[0] == reels[2]:
		same = 2
	var win := 0
	if same == 3:
		win = int(round(float(bet) * (1.0 + float(Rules.get_val("events.casino_top_rate", 1.0)))))
	elif same == 2:
		win = int(round(float(bet)
			* (1.0 + float(Rules.get_val("events.casino_middle_rate", 0.3)))))
	if win > 0:
		p["money"] = int(p["money"]) + win
	st["last"] = "赢 %d" % win if win > 0 else "没中"
	_ev("casino_result", p, {"reels": reels, "bet": bet, "win": win, "same": same})
	log_message.emit("%s 拉霸：%s → %s" % [p["name"], str(reels),
		("赢 %d 元" % win) if win > 0 else "没中"])
	return true


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
	# 以自己的「缺省公司」上市（Role.txt 第 6 列）+ 初始持有本公司 2000 股
	_init_player_company(p)
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
	var t_before := time
	time += dt
	tick_count += 1

	# 天数推进 → 路边物体生成。
	# 节奏是**推断**：原版权重表只写了各类型的相对几率，没写判定频率；这里取「每天 roll 一次」，
	# 并对三种有 `*_Born_Days` 的（水晶 3 天 / 宝箱 5 天 / 神仙蛋 1 天）按周期节流。
	var now_day := int(time / Rules.seconds_per_day())
	while road_day < now_day:
		road_day += 1
		_spawn_road_obj()
		_tick_stocks()              # 每天开盘：股价按 Stock_OpenPrice_Min/Max 波动
		_maybe_global_news()        # 全局新闻（甲1..甲14）
		if road_day % MONTH_DAYS == 0:
			_pay_dividends()        # 每 30 天（一个月）分红一次

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
			# 掷骰动画还没播完就先站着（原版：抛骰子 → 定格点数 → 才起步）。
			# ⚠️ 只走「本帧里动画终点之后」的那一段 —— 否则等待的时间会被算进移动距离
			var seg: float = time - maxf(t_before, float(p.get("move_after", 0.0)))
			if seg > 0.0:
				_advance(p, seg)
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
		# 踩到**玩家放的陷阱**（地雷卡 / 路障卡）
		var ob := _obstacle_at(int(p["tile"]))
		if not ob.is_empty():
			_remove_obstacle(int(ob["idx"]))
			if str(ob["kind"]) == "mine":
				if float(p["effects"]["invincible_until"]) <= time:
					# ⚠ 伤害值取规则表（Initvar_r.txt 的 Mine_Exp_HPDec = 1000），
					#   不要再写死常量 —— 这里原来硬编码 300，是 bug。
					p["stamina"] = maxf(0.0, float(p.get("stamina", 0.0))
						- float(Rules.get_val("hp.mine_damage", 1000)))
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
		# 踩到**路边物体**（原版 roadobj）：踩到即触发，随即从棋盘上消失
		elif road_objs.has(int(p["tile"])):
			var rob: Dictionary = road_objs[int(p["tile"])]
			road_objs.erase(int(p["tile"]))
			_pick_road_obj(p, str(rob["kind"]), int(p["tile"]))
		# 踩到**传送平台**（原版 Roadevent 事件 1）：经过就传送，并结束本次移动。
		# ⚠ 必须放在**逐格循环里**判 —— 原来只在 _arrive（停下那一刻）判，
		#   于是「路过」不传送，玩家可以站在传送平台上；此时再掷 1 点走 1 格到
		#   「另一处平台」，又被原样传回来 ⇒ 看起来「留在原地」（老板 2026-09-26 反馈）。
		#   埃及的 2 格传送平台在路径上相邻、世界里却隔 13.9 单位（≈3 格），正是传送门的两端。
		elif _event_key(int(p["tile"])) == "platform" \
				and not bool(p.get("_teleported", false)):
			_teleport_platform(p, int(p["tile"]))
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
	# 小神仙也按**步数**升级（原版 Initvar_r.txt「Pet_Upgrade_Steps = 300
	# 宠物每走多少步（此值 × 级数）升级」）—— 与「在精灵屋重复购买升级」是两条并行途径
	p["pet_steps"] = int(p.get("pet_steps", 0)) + 1
	_try_pet_levelup(p)


## 走够步数就把一只小神仙升一级。门槛 = Pet_Upgrade_Steps × 当前等级。
func _try_pet_levelup(p: Dictionary) -> void:
	var pets: Array = p["pets"]
	if pets.is_empty():
		p["pet_steps"] = 0
		return
	var base: int = int(Rules.get_val("pet.upgrade_steps_per_level", 300))
	var cap: int = int(Rules.get_val("road.crystal_max_pet_level", 4))   # 上限 4 级（Pet.txt）
	var steps: int = int(p.get("pet_steps", 0))
	for pet in pets:
		var lv: int = int(pet["level"])
		if lv >= cap:
			continue
		if steps >= base * lv:
			pet["level"] = lv + 1
			p["pet_steps"] = 0
			log_message.emit("%s 的「%s」走满 %d 步，升到 %d 级" % [
				p["name"], pet_name(str(pet["id"])), base * lv, lv + 1])
			_ev("pet_levelup", p, {"pet": str(pet["id"]), "level": lv + 1,
				"steps": base * lv})
			return

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
func _push_away_occupants(p: Dictionary) -> void:
	if map == null:
		return
	var here := int(p["tile"])
	for oid in player_ids():
		if int(oid) == int(p["id"]):
			continue
		var o: Dictionary = players[oid]
		if not bool(o["alive"]) or int(o["moving"]) > 0:
			continue
		if int(o["tile"]) != here:
			continue
		var dest := _wrap(here + 1)
		o["tile"] = dest
		o["progress"] = 0.0
		o["idle"] = 0.0
		log_message.emit("%s 站在 %d 格，被 %s 挤到了 %d 格" % [
			o["name"], here, p["name"], dest])
		_ev("push_away", o, {"by": int(p["id"]), "name": str(p["name"]),
			"from": here, "tile": dest})
		var t: Dictionary = map.tile(dest)
		if str(t.get("kind", "")) == "plot":
			_resolve_plot(o, dest, t)   # 会付房租（如果那是别人的地）
			_clear_chance(o)            # 买地 / 升级的机会当场作废


func _arrive(p: Dictionary) -> void:
	var idx: int = int(p["tile"])
	var t: Dictionary = map.tile(idx)
	# 原版**不允许多人站在同一格** —— 后到的人把先到的人往前挤一格。
	# 必须在「本次抵达结算」之前做，否则被挤的人会先吃到本格的结算。
	_push_away_occupants(p)
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
			# 传送平台（原版 Roadevent.txt 事件 1）。
			# ⚠ 主体逻辑在 `_advance` 的逐格循环里（**经过就传送**），这里只是「刚好停在上面」的
			#   兜底；本段行走已经传过就不再传（否则 A→B 再 B→A 会原地打转）。
			if not bool(p.get("_teleported", false)) and _teleport_platform(p, idx) < 0:
				log_message.emit("%s 站在传送平台上，但本图没有第二处平台" % p["name"])
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
			# 拉霸（老虎机）：**打开面板让玩家自己下注**
			# （原版截图 records/老虎机.png：从左侧滑出 + 三档下注 + 拉杆）
			# ⚠️ 原来的实现是「到了就直接扣 casino_fee」，那是没界面时的简化版
			_ev("casino_open", p, {"eid": eid})
		_:
			log_message.emit("%s 抵达 %s" % [p["name"], ename])
			_ev("event", p, {"eid": eid, "ename": ename})

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


func act_use_card(id: int, card_id: String, target: int = -1,
		target_name: String = "") -> bool:
	## 使用一张手牌。
	## target = 需要「点选对手」时的目标玩家 id（其余卡忽略；见 CARD_TARGET）。
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
		if tp.is_empty() or int(target) == id or not bool(tp["alive"]):
			_ev("need_card_target", p, {"card": card_id, "name": cname,
				"target_kind": "player", "prompt": Rules.card_target_prompt("player")})
			return false

	var c := Rules.card_by_id(card_id)
	if not _apply_card(p, card_id, c, p["effects"], target, target_name):
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


## 「喂食」：把一张卡喂给小神仙（原版卡片菜单第三项，`String.txt` 4 = 喂食）。
##
## ⚠ 效果**没有明文依据** —— `Info.txt` 里没有「喂食」相关的文案，`Initvar_r.txt` 也没有对应
##   参数。这里取**最保守**的实现：消耗卡片 → 让**等级最低**的一只小神仙升 1 级
##   （与「魔戒」同效果，只是来源不同）。登记在 `docs/alignment-gap.md`。
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
	var cap: int = int(Rules.get_val("road.crystal_max_pet_level", 4))
	# 挑等级最低的那只喂；全都满级就不喂，别浪费卡
	var best: int = -1
	var best_lv: int = cap + 1
	for i in range(pets.size()):
		var lv: int = int((pets[i] as Dictionary)["level"])
		if lv >= cap:
			continue                  # 满级的不能再喂（否则会顶破 4 级上限）
		if lv < best_lv:
			best_lv = lv
			best = i
	if best < 0:
		_feed_refuse(p, "小神仙都满级了")
		return false
	(p["cards"] as Array).remove_at(at)
	(pets[best] as Dictionary)["level"] = best_lv + 1
	log_message.emit("%s 把「%s」喂给 %s，升到 %d 级" % [
		p["name"], Rules.card_name(card_id),
		pet_name(str((pets[best] as Dictionary)["id"])), best_lv + 1])
	_ev("feed_card", p, {"card": card_id,
		"pet": str((pets[best] as Dictionary)["id"]), "level": best_lv + 1})
	return true


func _feed_refuse(p: Dictionary, why: String) -> void:
	log_message.emit("%s 喂不了卡：%s" % [p["name"], why])
	_ev("feed_refused", p, {"why": why})


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
	p["move_after"] = time + ROLL_ANIM_SECONDS   # 同掷骰：先把骰子抛出来定格再走
	p["last_roll"] = n
	p["last_faces"] = [n]
	log_message.emit("%s 用骰子卡前进 %d 步" % [p["name"], n])
	_ev("roll", p, {"n": n, "dice": 1, "faces": [n], "by_card": "dice"})
	return true


## 真正执行卡的效果。返回 false = 没生效（卡片保留）。
func _apply_card(p: Dictionary, card_id: String, c: Dictionary, e: Dictionary,
		target: int, target_name: String = "") -> bool:
	var pid := int(p["id"])
	var here := int(p["tile"])
	var street := map.street_of(here)
	var eff := str(c.get("effect", ""))
	# ---- 复制卡（String.txt 9032「复制一张相同的卡片」）----
	# 把手里**另一张**同名卡再复制一份（自己这张会被消耗掉）
	if eff == "copy_card":
		var hand: Array = p["cards"]
		var other := ""
		for cc in hand:
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
			var res := _push_card(p, stolen)
			if not bool(res["added"]):
				log_message.emit("%s 的卡片栏满了（全锁着），抢来的「%s」没放下" % [
					p["name"], Rules.card_name(stolen)])
				_ev("hand_full", p, {"card": stolen})
				return false
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
				var res := _push_card(p, _random_card())
				if not bool(res["added"]):
					break                      # 全锁着就不硬塞了
				_report_card_push(p, res, "")
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
	var secs: float = float(Rules.get_val("road.god_seconds", 30.0))
	var e: Dictionary = p["effects"]
	match kind:
		"caishen":
			e["no_rent_until"] = maxf(float(e.get("no_rent_until", 0.0)), time + secs)
		"qiongshen":
			e["rent_pay_double_until"] = maxf(
				float(e.get("rent_pay_double_until", 0.0)), time + secs)
		"shuaishen":
			e["no_upgrade_steps"] = maxi(int(e.get("no_upgrade_steps", 0)), 30)
		"fushen":
			e["free_upgrade_steps"] = maxi(int(e.get("free_upgrade_steps", 0)), 30)
	log_message.emit("%s 被%s附身" % [p["name"], god_cn(kind)])
	_ev("road_god", p, {"idx": int(p["tile"]), "god": kind, "god_cn": god_cn(kind),
		"seconds": secs})


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
		# 71 / 78 魔戒：身上有小神仙才能升一级，上限 4 级（逆向自 0x431170）
		"crystal":
			var pets: Array = p["pets"]
			if pets.is_empty():
				log_message.emit("%s 得到魔戒，但身上没有小神仙" % p["name"])
				_ev("road_crystal", p, {"idx": idx, "leveled": false})
				return
			var pi: int = rng.randi_range(0, pets.size() - 1)
			var lv: int = int(pets[pi]["level"])
			var cap: int = int(Rules.get_val("road.crystal_max_pet_level", 4))
			if lv >= cap:
				log_message.emit("%s 得到魔戒，但小神仙已是最高等级" % p["name"])
				_ev("road_crystal", p, {"idx": idx, "leveled": false, "level": lv})
				return
			pets[pi]["level"] = lv + 1
			log_message.emit("%s 得到魔戒：%s 升到 %d 级" % [
				p["name"], pet_name(str(pets[pi]["id"])), lv + 1])
			_ev("road_crystal", p, {"idx": idx, "leveled": true, "level": lv + 1,
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
			if float(p["effects"]["invincible_until"]) > time:
				return
			var dec: float = float(Rules.get_val("road.bomb_hp_dec", 500))
			p["stamina"] = maxf(0.0, float(p.get("stamina", 0.0)) - dec)
			log_message.emit("%s 遇到炸弹鬼，体力 -%.0f" % [p["name"], dec])
			_ev("road_bomb", p, {"idx": idx, "dec": int(dec)})
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
		"road_objs": road_objs.duplicate(true),
		"road_day": road_day,
		"stocks": stocks.duplicate(true),
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
	var rf := {}
	for k in d.get("road_objs", {}).keys():
		rf[int(k)] = d["road_objs"][k]
	road_objs = rf
	road_day = int(d.get("road_day", road_day))
	stocks = d.get("stocks", stocks)
