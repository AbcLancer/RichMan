extends RefCounted
class_name SelfTest
## SelfTest —— 无头自检：验证即时制核心闭环是否真的跑得通
##
## 运行： godot --headless --path game -- --selftest
##
## 覆盖点（对应 P0 验收标准）：
##   1. 原版数据加载（地图 / 街道 / 公司 / 数值表）
##   2. 连续移动（格内进度推进，非跳格）
##   3. 到达结算：买地
##   4. 到达结算：过路费转账
##   5. 破产判定
##   6. 实时计时器：无敌（绝对时刻）/ 免费卡（剩余步数）语义区分
##   7. 静止睡眠（原版 Player_Sleep_StandTime = 25 秒）

var _pass := 0
var _fail := 0
var _lines: Array = []

func run() -> void:
	print("========== RichMan6 P0 自检 ==========")
	_test_rules()
	_test_map()
	_test_movement()
	_test_buy_and_rent()
	_test_timers()
	_test_bankruptcy()
	_test_idle_sleep()

	print("\n---------- 结果 ----------")
	for l in _lines:
		print(l)
	print("通过 %d / 失败 %d" % [_pass, _fail])
	print("==============================")

func _ok(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pass += 1
		_lines.append("  [PASS] %s %s" % [name, detail])
	else:
		_fail += 1
		_lines.append("  [FAIL] %s %s" % [name, detail])

func _near(a: float, b: float, eps: float = 0.0001) -> bool:
	return absf(a - b) < eps

# ------------------------------------------------------------------ 1. 数值表

func _test_rules() -> void:
	print("\n[1] 数值表 (realtime.json)")
	var d := Rules.data
	_ok("rules 已载入", not d.is_empty())
	_ok("秒/天 = 24", _near(Rules.seconds_per_day(), 24.0))
	_ok("卡牌 42 张", Rules.cards().size() == 42, "实际 %d" % Rules.cards().size())
	_ok("无敌卡 72 秒", _near(float(Rules.card_by_id("invincible").get("seconds", 0.0)), 72.0))
	_ok("冬眠卡 10 秒", _near(float(Rules.card_by_id("hibernate").get("seconds", 0.0)), 10.0))
	_ok("核弹卡范围 5", int(Rules.card_by_id("nuke").get("range", 0)) == 5)
	_ok("推土机速度 2 格/秒", _near(float(Rules.get_val("movement.bulldozer_speed", 0.0)), 2.0))
	_ok("静止睡眠 25 秒", _near(float(Rules.get_val("movement.player_idle_sleep_seconds", 0.0)), 25.0))

# ------------------------------------------------------------------ 2. 地图

func _test_map() -> void:
	print("\n[2] 地图数据 (原版生成)")
	var m := MapData.load_from("china")
	_ok("china 地图可加载", m != null)
	if m == null:
		return
	_ok("街道 19 条", m.streets.size() == 19, "实际 %d" % m.streets.size())
	_ok("格子 96 格", m.tile_count() == 96, "实际 %d" % m.tile_count())
	_ok("首街道 = 少林路", str(m.streets[0]) == "少林路", str(m.streets[0]))
	_ok("虚拟公司 6 家", m.virtual_companies.size() == 6)
	_ok("首公司 = 武当派", str(m.virtual_companies[0]["name"]) == "武当派")
	_ok("医院坐标取自原版", m.landmarks.has("hospital"))
	_ok("相机俯角 30° (原 .r6m)", _near(float(m.camera.get("yaw", 0.0)), 30.0))

# -------------------------------------------------- 3. 连续移动（即时制核心）

func _test_movement() -> void:
	print("\n[3] 连续移动")
	var sim := _fresh_sim()
	var p: Dictionary = sim.players[1]
	sim.act_roll(1)
	var target: int = int(p["moving"])
	_ok("掷骰得到 1~6 点", target >= 1 and target <= 6, "点数 %d" % target)

	# 走 0.25 秒，速度 2 格/秒 → 格内进度应为 0.5（尚未换格）
	sim.step(0.25)
	_ok("0.25s 后仍在原地格", int(p["tile"]) == 0, "tile=%d" % int(p["tile"]))
	_ok("格内进度 = 0.5（连续移动）", _near(float(p["progress"]), 0.5),
		"progress=%.3f" % float(p["progress"]))

	# 再走 0.25 秒 → 跨过 1 格
	sim.step(0.25)
	_ok("0.5s 后前进 1 格", int(p["tile"]) == 1, "tile=%d" % int(p["tile"]))

	# 走完全程
	var guard := 0
	while int(p["moving"]) > 0 and guard < 1000:
		sim.step(0.05)
		guard += 1
	_ok("最终抵达目标格", int(p["tile"]) == target, "tile=%d 期望 %d" % [int(p["tile"]), target])
	_ok("抵达后停止移动", int(p["moving"]) == 0 and _near(float(p["progress"]), 0.0))

# ------------------------------------------------------- 4. 买地与过路费

func _test_buy_and_rent() -> void:
	print("\n[4] 买地与过路费")
	var sim := _fresh_sim()
	var p1: Dictionary = sim.players[1]
	var p2: Dictionary = sim.players[2]

	# 把玩家 1 直接放到 1 号格（少林路，地产格）并结算
	p1["tile"] = 0
	p1["moving"] = 1
	var g := 0
	while int(p1["moving"]) > 0 and g < 200:
		sim.step(0.05)
		g += 1
	_ok("抵达地产格 1", int(p1["tile"]) == 1, "tile=%d" % int(p1["tile"]))
	_ok("服务端标记可购买点", int(p1["last_plot"]) == 1)

	var before: int = int(p1["money"])
	var ok_buy: bool = sim.act_buy(1)
	_ok("购买成功", ok_buy)
	_ok("扣除地价 2000", int(p1["money"]) == before - Sim.EMPTY_PLOT_PRICE,
		"%d -> %d" % [before, int(p1["money"])])
	_ok("地块登记归属", sim.plots.has(1) and int(sim.plots[1]["owner"]) == 1)
	_ok("购买后清除可购买标记", int(p1["last_plot"]) == -1)

	# 升级到 2 级 → 租金应为 BUILD_BASE_RENT * 2
	_ok("升级成功", sim.act_upgrade(1))
	_ok("等级 = 1", int(sim.plots[1]["level"]) == 1)
	_ok("租金 = 1500", sim._rent_of(1) == Sim.BUILD_BASE_RENT)

	# 玩家 2 走到该格 → 应付过路费
	p2["tile"] = 0
	p2["moving"] = 1
	g = 0
	while int(p2["moving"]) > 0 and g < 200:
		sim.step(0.05)
		g += 1
	var m1: int = int(p1["money"])
	var m2: int = int(p2["money"])
	_ok("玩家2 停在 1 号格", int(p2["tile"]) == 1, "tile=%d" % int(p2["tile"]))
	_ok("玩家2 被扣租金", m2 < Sim.START_MONEY, "money=%d" % m2)
	_ok("玩家1 收到等额租金", m1 == Sim.START_MONEY - Sim.EMPTY_PLOT_PRICE
		- Sim.BUILD_UPGRADE_COST + Sim.BUILD_BASE_RENT, "money=%d" % m1)
	_ok("收支平衡", (Sim.START_MONEY - m2) == (m1 - (Sim.START_MONEY
		- Sim.EMPTY_PLOT_PRICE - Sim.BUILD_UPGRADE_COST)))

# ------------------------------------------------- 5. 两类计时器语义区分

func _test_timers() -> void:
	print("\n[5] 计时器语义（绝对时刻 vs 剩余步数）")
	var sim := _fresh_sim()
	var p: Dictionary = sim.players[1]
	p["cards"] = ["invincible", "free"]

	sim.act_use_card(1, "invincible")
	_ok("无敌卡写入绝对时刻 72s",
		_near(float(p["effects"]["invincible_until"]), sim.time + 72.0),
		"until=%.1f" % float(p["effects"]["invincible_until"]))

	sim.act_use_card(1, "free")
	_ok("免费卡写入剩余步数 20",
		int(p["effects"]["no_rent_steps"]) == 20,
		"steps=%d" % int(p["effects"]["no_rent_steps"]))

	# 免费卡：被收租时应递减步数且不扣钱
	var p2: Dictionary = sim.players[2]
	sim.plots[1] = {"owner": 2, "level": 1, "type": "uptown"}
	p["tile"] = 0
	p["moving"] = 1
	var g := 0
	while int(p["moving"]) > 0 and g < 200:
		sim.step(0.05)
		g += 1
	_ok("免费卡生效：未扣钱", int(p["money"]) == Sim.START_MONEY, "money=%d" % int(p["money"]))
	_ok("免费卡步数递减到 19", int(p["effects"]["no_rent_steps"]) == 19)

# ------------------------------------------------------------ 6. 破产判定

func _test_bankruptcy() -> void:
	print("\n[6] 破产判定")
	var sim := _fresh_sim()
	var p: Dictionary = sim.players[1]
	p["money"] = 100
	# 玩家1 自有一块地（破产时应被释放）
	sim.plots[5] = {"owner": 1, "level": 1, "type": "uptown"}
	# 玩家2 的豪华地产（租金 6000 > 100 元，必然破产）
	sim.plots[1] = {"owner": 2, "level": 4, "type": "uptown"}
	p["tile"] = 0
	p["moving"] = 1
	var g := 0
	while int(p["moving"]) > 0 and g < 200:
		sim.step(0.05)
		g += 1
	_ok("资不抵债 → 出局", not bool(p["alive"]))
	_ok("破产后释放自己的地产", not sim.plots.has(5))
	_ok("他人地产不受影响", sim.plots.has(1))
	_ok("仅剩 1 人 → 结束并产生赢家", sim.winner == 2, "winner=%d" % sim.winner)

# ------------------------------------------------------------ 7. 静止睡眠

func _test_idle_sleep() -> void:
	print("\n[7] 静止睡眠（原版 25 秒）")
	var sim := _fresh_sim()
	var p: Dictionary = sim.players[1]
	# 走 25 秒（不掷骰）
	var t := 0.0
	while t < 25.2:
		sim.step(0.1)
		t += 0.1
	_ok("静止 25 秒后进入睡眠",
		float(p["effects"]["sleep_until"]) > sim.time,
		"sleep_until=%.1f  now=%.1f" % [float(p["effects"]["sleep_until"]), sim.time])
	_ok("睡眠期间无法掷骰", not sim.act_roll(1))

# ------------------------------------------------------------------ 工具

func _fresh_sim() -> Sim:
	var m := MapData.load_from("china")
	var sim := Sim.new()
	sim.setup(m, 12345)
	sim.add_player(1, "玩家一")
	sim.add_player(2, "玩家二")
	sim.running = true
	return sim
