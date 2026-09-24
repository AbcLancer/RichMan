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

# ---- 经济常量（对齐原版 House.txt / Initvar_r.txt）----
const EMPTY_PLOT_PRICE := 2000      # Empty_Grid_PriceFactor(200) × 地价因子(10)
const EMPTY_PLOT_RENT := 250        # Empty_Grid_RentFactor(25) × 地价因子(10)
const BUILD_UPGRADE_COST := 1000    # 对齐 House.txt「公寓」升级费 1000
const BUILD_BASE_RENT := 1500       # 对齐 House.txt「一级公寓」基本租金 1500
const MAX_BUILD_LEVEL := 4          # 对齐 House.txt「四级公寓」
const START_MONEY := 500000         # 对齐 Player_Com_Capital 量级
const START_HP := 3000
const MOVE_SPEED := 2.0             # 格/秒（对齐 BullDozer_Speed / Ambulance_Speed）
const IDLE_SLEEP_SECONDS := 25.0

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

var rng := RandomNumberGenerator.new()

func setup(m: MapData, seed_val: int = 0) -> void:
	map = m
	if seed_val == 0:
		rng.randomize()
	else:
		rng.seed = seed_val

# ------------------------------------------------------------------ 玩家管理

func add_player(id: int, pname: String) -> Dictionary:
	var idx := players.size()
	var p := {
		"id": id,
		"name": pname,
		"money": START_MONEY,
		"hp": START_HP,
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
			"invincible_until": 0.0,
			"sleep_until": 0.0,
			"no_rent_steps": 0,
			"rent_double_steps": 0,
		},
		"last_plot": -1,
	}
	players[id] = p
	log_message.emit("%s 加入游戏" % pname)
	return p

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

func _advance(p: Dictionary, dt: float) -> void:
	var step_dist: float = float(p["speed"]) * dt
	p["progress"] = float(p["progress"]) + step_dist
	while float(p["progress"]) >= 1.0 and int(p["moving"]) > 0:
		p["progress"] = float(p["progress"]) - 1.0
		p["tile"] = _wrap(int(p["tile"]) + int(p["dir"]))
		p["moving"] = int(p["moving"]) - 1
	if int(p["moving"]) <= 0:
		p["moving"] = 0
		p["progress"] = 0.0
		p["idle"] = 0.0
		_arrive(p)

func _wrap(i: int) -> int:
	var n := map.tile_count()
	return ((i % n) + n) % n

# --------------------------------------------------------------- 到达格结算

func _arrive(p: Dictionary) -> void:
	var idx: int = int(p["tile"])
	var t: Dictionary = map.tile(idx)
	p["last_plot"] = -1

	match t.get("kind", ""):
		"plot":
			_resolve_plot(p, idx, t)
		"event":
			_resolve_event(p, idx, t)
		"start":
			pass

func _resolve_plot(p: Dictionary, idx: int, t: Dictionary) -> void:
	var street: String = t.get("street", "")
	if not plots.has(idx):
		# 空地：等待玩家决定购买（服务端仅标记可购买点）
		p["last_plot"] = idx
		log_message.emit("%s 抵达 %s（空地，可购买）" % [p["name"], street])
		return

	var plot: Dictionary = plots[idx]
	var owner: int = int(plot["owner"])
	var level: int = int(plot["level"])

	if owner == int(p["id"]):
		log_message.emit("%s 回到自己的 %s（%d 级）" % [p["name"], street, level])
		return

	# 过路费
	if int(p["effects"]["no_rent_steps"]) > 0:
		p["effects"]["no_rent_steps"] = int(p["effects"]["no_rent_steps"]) - 1
		log_message.emit("%s 使用免费卡，免付过路费" % p["name"])
		return

	var rent := _rent_of(level)
	if int(p["effects"]["rent_double_steps"]) > 0:
		rent *= 2
		p["effects"]["rent_double_steps"] = int(p["effects"]["rent_double_steps"]) - 1

	_transfer(p, players.get(owner), rent, "%s 的 %s" % [players[owner]["name"], street])
	log_message.emit("%s 向 %s 支付过路费 %d 元" % [p["name"], players[owner]["name"], rent])

func _rent_of(level: int) -> int:
	if level <= 0:
		return EMPTY_PLOT_RENT
	return BUILD_BASE_RENT * level

func _resolve_event(p: Dictionary, idx: int, t: Dictionary) -> void:
	var eid: String = t.get("event", "")
	var ename: String = t.get("name", eid)
	match eid:
		"hospital":
			# Event_Hospital_MinTime/MaxTime 在即时制下为 0，此处给固定 8 秒以示差异
			p["effects"]["sleep_until"] = time + 8.0
			log_message.emit("%s 进入%s，住院 8 秒" % [p["name"], ename])
		"credit":
			var g := rng.randi_range(1, 50)
			p["money"] = int(p["money"]) + g * 100
			log_message.emit("%s 在%s获得 %d 点券" % [p["name"], ename, g])
		"casino":
			var fee := int(Rules.get_val("events.casino_fee", 2500))
			_transfer(p, null, fee, "乐透")
			log_message.emit("%s 在%s花费 %d 元" % [p["name"], ename, fee])
		"cardshop":
			var c := _random_card()
			(p["cards"] as Array).append(c)
			log_message.emit("%s 在%s获得卡片：%s" % [p["name"], ename, c])
		_:
			log_message.emit("%s 抵达 %s" % [p["name"], ename])

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

# ------------------------------------------------------------- 玩家动作（校验）

func act_roll(id: int) -> bool:
	## 掷骰 —— 即时制下掷出后角色连续移动
	var p: Dictionary = players.get(id, {})
	if p.is_empty() or not p["alive"] or int(p["moving"]) > 0:
		return false
	if time < float(p["effects"]["sleep_until"]):
		return false
	var n := rng.randi_range(1, 6)
	p["moving"] = n
	p["idle"] = 0.0
	log_message.emit("%s 掷出 %d 点" % [p["name"], n])
	return true

func act_buy(id: int) -> bool:
	## 购买当前所在空地
	var p: Dictionary = players.get(id, {})
	if p.is_empty() or int(p["last_plot"]) < 0:
		return false
	var idx: int = int(p["last_plot"])
	if plots.has(idx):
		return false
	var price := EMPTY_PLOT_PRICE
	if int(p["money"]) < price:
		log_message.emit("%s 资金不足，无法购地" % p["name"])
		return false
	p["money"] = int(p["money"]) - price
	plots[idx] = {"owner": id, "level": 0, "type": "uptown"}
	p["last_plot"] = -1
	log_message.emit("%s 以 %d 元买下 %s" % [p["name"], price, map.street_of(idx)])
	return true

func act_upgrade(id: int) -> bool:
	## 升级自己脚下的地产
	var p: Dictionary = players.get(id, {})
	if p.is_empty():
		return false
	var idx: int = int(p["tile"])
	if not plots.has(idx) or int(plots[idx]["owner"]) != id:
		return false
	var lv: int = int(plots[idx]["level"])
	if lv >= MAX_BUILD_LEVEL:
		return false
	var cost := BUILD_UPGRADE_COST * (lv + 1)
	if int(p["money"]) < cost:
		return false
	p["money"] = int(p["money"]) - cost
	plots[idx]["level"] = lv + 1
	log_message.emit("%s 将 %s 升级到 %d 级（花费 %d）" % [p["name"], map.street_of(idx), lv + 1, cost])
	return true

func act_use_card(id: int, card_id: String) -> bool:
	var p: Dictionary = players.get(id, {})
	if p.is_empty():
		return false
	var arr: Array = p["cards"]
	var at := arr.find(card_id)
	if at < 0:
		return false
	arr.remove_at(at)
	var c := Rules.card_by_id(card_id)
	match c.get("effect", ""):
		"no_rent":
			p["effects"]["no_rent_steps"] = int(c.get("steps", 20))
		"rent_double":
			p["effects"]["rent_double_steps"] = int(c.get("steps", 30))
		"immune":
			p["effects"]["invincible_until"] = time + float(c.get("seconds", 72))
		"move":
			p["moving"] = int(c.get("distance", 1))
		"reverse_direction":
			p["dir"] = -int(p["dir"])
		"gain_money":
			var amt := rng.randi_range(int(c.get("min", 10000)), int(c.get("max", 50000)))
			p["money"] = int(p["money"]) + amt
		"heal":
			p["hp"] = int(p["hp"]) + int(c.get("hp", 500))
		_:
			pass
	log_message.emit("%s 使用 %s" % [p["name"], c.get("name", card_id)])
	return true

# ------------------------------------------------------------------- 序列化

func to_dict() -> Dictionary:
	return {
		"t": time,
		"run": running,
		"win": winner,
		"players": players.duplicate(true),
		"plots": plots.duplicate(true),
	}

func apply_dict(d: Dictionary) -> void:
	time = float(d.get("t", time))
	running = bool(d.get("run", running))
	winner = int(d.get("win", -1))
	players = d.get("players", players)
	# JSON 往返会把 int 键变成 String 键，需归一化
	var fixed := {}
	for k in d.get("plots", {}).keys():
		fixed[int(k)] = d["plots"][k]
	plots = fixed
