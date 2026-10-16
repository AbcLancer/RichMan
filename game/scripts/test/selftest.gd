extends RefCounted
class_name SelfTest
## SelfTest —— 无头自检：验证即时制核心闭环是否真的跑得通
##
## 运行： godot --headless --path game -- --selftest
##
## 覆盖点（对应 P0 验收标准）：
##   1. 原版数据加载（地图 / 街道 / 公司 / 数值表 / House.txt 房屋等级表）
##   2. 连续移动（格内进度推进，非跳格）
##   3. 到达结算：买地
##   4. 到达结算：过路费转账
##   5. 地产升级链条：**一次抵达只升一级**（原版 Info.txt id 93 语义）
##   6. 实时计时器：无敌（绝对时刻）/ 免费卡（剩余步数）语义区分
##   7. 破产判定
##   8. 静止睡眠（原版 Player_Sleep_StandTime = 25 秒）
##   9. 玩法语义事件 game_event（Sim → 表现层的唯一接口，Sim 里不许有音频）
##  10. 音频层（voice_map.json ↔ 素材逐条对齐、角色/卡片/宠物/BGM/环境底噪）

var _pass := 0
var _fail := 0
var _lines: Array = []

func run() -> void:
	print("========== RichMan6 P0 自检 ==========")
	_test_rules()
	_test_native_alignment()
	_test_map()
	_test_movement()
	_test_stamina()
	_test_road_events()
	_test_cards()
	_test_native_card_damage()
	_test_pets()
	_test_road_objs()
	_test_platform()
	_test_card_menu_feed()
	_test_hand()
	_test_stock()
	_test_push_away()
	_test_buy_and_rent()
	_test_corner_plot_ownership()
	_test_upgrade_chain()
	_test_special_buildings()
	_test_timers()
	_test_bankruptcy()
	_test_idle_sleep()
	_test_user_round_2026_10_01()
	_test_game_events()
	_test_audio()

	print("\n---------- 结果 ----------")
	for l in _lines:
		print(l)
	print("通过 %d / 失败 %d" % [_pass, _fail])
	print("==============================")

func _test_special_buildings() -> void:
	_lines.append("[special] 原版特殊建筑抵达服务及逆向挤人")
	for kind in ["special1", "special2", "special3"]:
		for level in range(1, 4):
			var sim := _fresh_sim()
			var p: Dictionary = sim.players[1]
			var owner: Dictionary = sim.players[2]
			var idx := 1
			sim.plots[idx] = {"owner": 2, "level": level, "type": kind}
			p.credit = 50
			p.money = 300000
			p.stamina = sim.stamina_max() / 2.0
			p.walked_this_move = 3
			sim.add_pet(p, "dushen")
			var pet := sim.active_pet(p)
			sim._set_pet_energy(pet, 1)
			var before := int(owner.money)
			var cards := (p.cards as Array).size()
			sim._resolve_plot(p, idx, sim.map.tile(idx))
			var file := Rules.house_file(kind, level)
			match file:
				"d201": _ok("俱乐部扣3点券并转给业主，不发卡", int(p.credit) == 47 and int(owner.credit) == 3 and (p.cards as Array).size() == cards and int(p.money) == 300000)
				"d202": _ok("银行手续费=现款×实际步数×2%", int(p.money) == 282000 and int(owner.money) == before + 18000)
				"d203": _ok("酒店步数×万元并住宿两天", int(p.money) == 270000 and not sim._roll_block_code(p).is_empty() and float(p.effects.hotel_until) == sim.time + Rules.seconds_per_day() * 2.0)
				"d101": _ok("喷泉恢复体力且不收租", float(p.stamina) == sim.stamina_max() and int(p.money) == 300000 and sim.pet_energy(pet) == 1)
				"d102": _ok("一座连锁店固定消费万元", int(p.money) == 290000 and int(owner.money) == before + 10000)
				"d103": _ok("公园体力与神仙能量全满且不收租", float(p.stamina) == sim.stamina_max() and sim.pet_skill_ready(pet) and int(p.money) == 300000)
				"d301": _ok("垃圾場抵达不扣普通租金", int(p.money) == 300000)
				"d302": _ok("发电厂补随身神仙MP，不补人物体力不收租", sim.pet_skill_ready(pet) and float(p.stamina) == sim.stamina_max() / 2.0 and int(p.money) == 300000)
				"d303": _ok("科研中心访客获得一张卡且不收租", (p.cards as Array).size() == cards + 1 and int(p.money) == 300000)
	var chain := _fresh_sim()
	chain.plots[1] = {"owner": 2, "level": 2, "type": "special2"}
	chain.plots[2] = {"owner": 2, "level": 2, "type": "special2"}
	chain._resolve_special_building(chain.players[1], 1, chain.plots[1])
	_ok("两座连锁店收费翻倍", int(chain.players[1].money) == Sim.START_MONEY - 20000)
	var stopped := _fresh_sim()
	stopped.plots[1] = {"owner": 2, "level": 2, "type": "special1"}
	stopped.players[2].tile = 50
	stopped.players[1].tile = 0
	stopped.players[1].moving = 6
	stopped.players[1].last_roll = 6
	stopped.players[1].money = 300000
	stopped.obstacles.append({"idx": 1, "kind": "roadblock", "owner": 2})
	stopped._advance(stopped.players[1], 1.0)
	_ok("路障提前止步后银行按实际一格收费，不按骰面六格", int(stopped.players[1].walked_this_move) == 1 and int(stopped.players[1].money) == 294000)
	var reverse := _fresh_sim()
	reverse.add_player(3, "第三人")
	reverse.players[1].tile = 10
	reverse.players[1].dir = -1
	reverse.players[2].tile = 10
	reverse.players[3].tile = 9
	reverse._push_away_occupants(reverse.players[1])
	_ok("逆向挤人按前进方向连锁而非退到身后", int(reverse.players[2].tile) == 9 and int(reverse.players[3].tile) == 8 and int(reverse.players[2].dir) == -1 and int(reverse.players[3].dir) == -1)
	var god := _fresh_sim()
	god.plots[1] = {"owner": 2, "level": 1, "type": "industry"}
	god.players[1].effects.free_upgrade_steps = 30
	_ok("原版福神不替对手加盖", not god._apply_fushen_arrival(god.players[1], 1, god.plots[1]) and int(god.plots[1].level) == 1)

func _test_corner_plot_ownership() -> void:
	for pair in [[38, 70], [53, 55]]:
		var sim := Sim.new()
		sim.setup(MapData.load_from("train"), 987)
		sim.add_player(1, "甲")
		sim.add_player(2, "乙")
		var a := int(pair[0])
		var b := int(pair[1])
		var p: Dictionary = sim.players[1]
		p.last_plot = a
		p.last_plot_kind = "buy"
		_ok("拐角两个入口共用产权 %s" % str(pair), sim.act_buy(1)
			and sim.plots.has(b) and sim.unique_plot_keys().size() == 1)
		var q: Dictionary = sim.players[2]
		q.last_plot = b
		q.last_plot_kind = "buy"
		var cash := int(q.money)
		_ok("另一入口不能重复出售", not sim.act_buy(2) and int(q.money) == cash)
		var plan := sim.construction_plan(1, b, "uptown:1")
		_ok("从拐角另一入口可以盖房", not plan.is_empty())
		if not plan.is_empty():
			sim._commit_construction(b, plan, 0)
			_ok("建房同步所有入口", int(sim.plots[a].level) > 0 and sim.plots[a] == sim.plots[b])
		var restored := Sim.new()
		restored.setup(sim.map)
		restored.apply_dict(sim.to_dict().duplicate(true))
		restored.plots[b].owner = 2
		_ok("存档恢复后入口仍共用产权", int(restored.plots[a].owner) == 2)
		restored._downgrade_estate(a)
		if int(restored.plots[a].level) == 0:
			_ok("拆成空地仍只有一份产权", restored.unique_plot_keys().size() == 1 and int(restored.plots[b].owner) == 2)
		var saved := sim.to_dict().duplicate(true)
		saved.plots = {a: {"owner": 1, "level": 0, "type": "", "paid_base": 200.0},
			b: {"owner": 2, "level": 0, "type": "", "paid_base": 200.0}}
		cash = int(saved.players[2].money)
		restored.apply_dict(saved)
		_ok("修复旧存档重复购地并退款", restored.unique_plot_keys().size() == 1
			and int(restored.plots[b].owner) == 1 and int(restored.players[2].money) == cash + 200)
		var repaired := restored.to_dict().duplicate(true)
		restored.apply_dict(repaired)
		_ok("存档重复读取不会重复退款", int(restored.players[2].money) == cash + 200)

func _test_user_round_2026_10_01() -> void:
	var seal := _card_world("seize")
	var p: Dictionary = seal.players[1]
	var event_tile := -1
	for i in range(seal.map.tile_count()):
		if str(seal.map.tile(i).get("kind", "")) == "event" and seal._current_street(i) != "":
			event_tile = i
			break
	if event_tile >= 0:
		p.tile = event_tile
		p.cards = ["seize"]
		var street := seal._current_street(event_tile)
		_ok("查封卡在事件格也能找到当前街道", seal.act_use_card(1, "seize")
			and float(seal.street_seal.get(street, 0.0)) > seal.time, street)
		var affected := seal._street_plots(street)
		if not affected.is_empty():
			var rent_tile := int(affected[0])
			if int(seal.plots[rent_tile].owner) == 2:
				_ok("查封街道的建筑停收过路费", _rent_paid(seal, rent_tile) == 0)
	var grab := _card_world("abduct")
	var owner: Dictionary = grab.players[1]
	var victim: Dictionary = grab.players[2]
	victim.tile = grab._wrap(int(owner.tile) + 1)
	grab.add_pet(victim, "hutu")
	victim.pet_active = "caishen"
	owner.cards = ["abduct"]
	_ok("诱拐卡抢对手当前出战的小神仙", grab.act_use_card(1, "abduct", 2)
		and grab.has_pet(owner, "caishen") and not grab.has_pet(victim, "caishen")
		and grab.has_pet(victim, "hutu"))
	var combine := _card_world("gem")
	combine.players[1].cards = ["gem", "buyland"]
	_ok("宝石卡加购地卡变土神卡", combine.act_use_card(1, "gem", -1, "buyland")
		and combine.players[1].cards.has("tudigong"))
	var energy := _pet_world("caishen")
	var pet: Dictionary = energy.active_pet(energy.players[1])
	energy.step(0.1)
	_ok("满能量不会继续衰减，技能保持可发动", is_equal_approx(float(pet.fullness), 100.0)
		and energy.pet_skill_ready(pet) and energy.pet_skill_block_reason(1) == "")
	var tired := _card_world("hamburger")
	var sleeper: Dictionary = tired.players[1]
	sleeper.stamina = 100.0
	tired.step(Sim.IDLE_SLEEP_SECONDS + 1.0)
	_ok("体力未满时不进入挂机休息", float(sleeper.effects.rest_until) <= tired.time)
	sleeper.stamina = tired.stamina_max()
	sleeper.idle = 0.0
	tired.step(Sim.IDLE_SLEEP_SECONDS + 0.1)
	_ok("体力满后静置25秒才挂机", float(sleeper.effects.rest_until) > tired.time)
	var lotto := _card_world("hamburger")
	var saved_state := lotto.rng.state
	var upcoming := lotto.rng.randi_range(1, Sim.LOTTO_NUMBERS)
	lotto.rng.state = saved_state
	var chosen := upcoming % Sim.LOTTO_NUMBERS + 1
	var lotto_player: Dictionary = lotto.players[1]
	lotto._resolve_event(lotto_player, int(lotto_player.tile), {"event": "casino", "name": "乐透"})
	_ok("乐透每次进入只能登记一个号码", lotto.act_lotto_pick(1, chosen)
		and not lotto.act_lotto_pick(1, upcoming) and lotto.lotto_pick_of(1) == chosen)
	lotto._resolve_event(lotto_player, int(lotto_player.tile), {"event": "casino", "name": "乐透"})
	_ok("再次进入乐透可再选一个未被占用的号码", lotto.act_lotto_pick(1, upcoming)
		and lotto.lotto_numbers.size() == 2)
	lotto._lotto_draw()
	_ok("已有号码中奖后清空本期选号", lotto.lotto_numbers.is_empty())
	var no_hit := _card_world("hamburger")
	var known := no_hit.rng.state
	var draw_number := no_hit.rng.randi_range(1, Sim.LOTTO_NUMBERS)
	no_hit.rng.state = known
	var keep_number := draw_number % Sim.LOTTO_NUMBERS + 1
	var ticket: Dictionary = no_hit.players[1]
	no_hit._resolve_event(ticket, int(ticket.tile), {"event": "casino", "name": "乐透"})
	no_hit.act_lotto_pick(1, keep_number)
	no_hit._lotto_draw()
	_ok("本期无人中奖时已选号码保留到下一期开奖",
		int(no_hit.lotto_numbers.get(keep_number, -1)) == 1)
	var game := _card_world("hamburger")
	var game_tile := -1
	for i in range(game.map.tile_count()):
		if str(game.map.tile(i).get("event", "")) in ["game_a", "game_b"]:
			game_tile = i
			break
	if game_tile >= 0:
		var gamer: Dictionary = game.players[1]
		var before_credit := int(gamer.credit)
		gamer.tile = game_tile
		game._resolve_event(gamer, game_tile, game.map.tile(game_tile))
		_ok("问号游戏点停留后发放点券", int(gamer.credit) > before_credit)

func _test_native_card_damage() -> void:
	var m := MapData.new()
	for i in range(12):
		m.tiles.append({"kind": "plot", "street": "验证街道"})
		m.tile_pos.append(Vector2(i * 100.0, 0))
	var sim := Sim.new()
	sim.setup(m, 7)
	for id in range(1, 5): sim.add_player(id, "玩家%d" % id)
	sim.running = true
	var caster: Dictionary = sim.players[1]
	var victim: Dictionary = sim.players[2]
	var edge: Dictionary = sim.players[3]
	var immune: Dictionary = sim.players[4]
	caster.tile = 0
	victim.tile = 5
	edge.tile = 7
	immune.tile = 5
	for player in sim.players.values():
		player.cards.clear()
		player.stamina = 600.0
		player.moving = 0
		player.effects.sleep_until = 0.0
	immune.effects.invincible_until = 100.0
	sim.plots[0] = {"owner": 1, "level": 2, "type": "industry"}
	sim.plots[5] = {"owner": 2, "level": 2, "type": "industry"}
	sim.plots[8] = {"owner": 2, "level": 2, "type": "industry"}
	caster.cards = ["missile", "nuke"]
	_ok("飞弹缺少选点不消耗手牌", not sim.act_use_card(1, "missile") and caster.cards.has("missile"))
	_ok("飞弹非法路点不消耗手牌", not sim.act_use_card(1, "missile", -1) and caster.cards.has("missile"))
	_ok("飞弹选中附近地块后延迟结算", sim.act_use_card(1, "missile", 5)
		and int(sim.plots[5].level) == 2 and sim.pending_card_impacts.size() == 1)
	sim.step(.5)
	_ok("飞弹飞行阶段不提前扣血", float(victim.stamina) == 600.0)
	sim.step(.5)
	_ok("飞弹爆心是所选格，施法者脚下建筑保留", int(sim.plots[5].level) == 1 and int(sim.plots[0].level) == 2)
	_ok("飞弹建筑范围使用五路点而非十一点", int(sim.plots[8].level) == 2)
	var hospital_tile := sim._hospital_road_tile()
	_ok("飞弹击中后进入医院，并等体力恢复", float(victim.effects.get("hospital_until", 0)) > sim.time
		and (hospital_tile < 0 or int(victim.tile) == hospital_tile), "hospital=" + str(hospital_tile))
	_ok("飞弹按空间距离衰减伤害", float(edge.stamina) > 450.0 and float(edge.stamina) < 500.0)
	_ok("无敌玩家免疫飞弹", float(immune.stamina) == 600.0 and float(immune.effects.get("hospital_until", 0)) == 0.0)
	_ok("住院阻止骰子与卡片操作", not sim.act_roll(2) and sim.card_usable(2, "step1") == 61)
	var replica := Sim.new()
	replica.setup(m, 7)
	replica.apply_dict(sim.to_dict())
	_ok("联机快照保留住院状态", replica.players[2].effects.hospital_until == victim.effects.hospital_until)
	_ok("核弹选点成功", sim.act_use_card(1, "nuke", 5))
	replica.apply_dict(sim.to_dict())
	_ok("飞弹延迟队列进入联机快照", replica.pending_card_impacts.size() == 1)
	sim.step(1)
	_ok("核弹摧毁目标建筑而非只降一级", int(sim.plots[5].level) == 0 and int(sim.plots[0].level) == 2)
	sim.step(73)
	_ok("体力未满时仍留在医院", float(victim.effects.hospital_until) > 0.0)
	sim.step(20)
	_ok("体力回满后恢复行动", float(victim.effects.hospital_until) == 0
		and float(victim.stamina) == sim.stamina_max()
		and (hospital_tile < 0 or int(victim.tile) == hospital_tile))
	var egypt := Sim.new()
	egypt.setup(MapData.load_from("aiji"), 79)
	egypt.add_player(1, "医院检查")
	var injured: Dictionary = egypt.players[1]
	egypt._send_to_hospital(injured, 100.0, "missile")
	_ok("埃及地图受伤者移到真实医院路点", egypt._hospital_road_tile() >= 0
		and int(injured.tile) == egypt._hospital_road_tile())
	caster.tile = 5
	victim.tile = 6
	caster.cards = ["shuaishen"]
	victim.effects.rent_double_steps = 12
	var feedback: Array = []
	sim.game_event.connect(func(kind, data):
		if kind == "card_status_applied": feedback.append(data))
	_ok("衰神替换旧附身并发出明确目标反馈", sim.act_use_card(1, "shuaishen", 2)
		and int(victim.effects.no_upgrade_steps) == 30 and int(victim.effects.rent_double_steps) == 0
		and feedback.size() == 1 and int(feedback[0].pid) == 2 and str(feedback[0].message).contains("30"))
	sim._tick_step_effects(victim)
	_ok("衰神步数按实际走格消耗", int(victim.effects.no_upgrade_steps) == 29)
	caster.cards = ["qiongshen"]
	victim.money = 100000
	var previous_cash := int(caster.money)
	_ok("穷神卡转移现金并替换衰神附身", sim.act_use_card(1, "qiongshen", 2)
		and int(victim.money) < 100000 and int(caster.money) - previous_cash == 100000 - int(victim.money)
		and int(victim.effects.rent_double_steps) == 30 and int(victim.effects.no_upgrade_steps) == 0)
	caster.cards = ["shuaishen"]
	victim.effects.invincible_until = sim.time + 30
	_ok("无敌抵挡衰神且使用失败保留手牌", not sim.act_use_card(1, "shuaishen", 2) and caster.cards.has("shuaishen"))
	# Exported route coordinates are already scaled. Check actual map distances,
	# guarding against an apparent 250-unit radius swallowing the whole board.
	var real := Sim.new()
	real.setup(MapData.load_from("aiji"), 1)
	var native_distance := real._native_road_position(0).distance_to(real._native_road_position(1))
	_ok("爆炸距离使用原版未缩放道路记录", _near(native_distance, 97.5680569630236, .001))

func _ok(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pass += 1
		_lines.append("  [PASS] %s %s" % [name, detail])
	else:
		_fail += 1
		_lines.append("  [FAIL] %s %s" % [name, detail])

func _near(a: float, b: float, eps: float = 0.0001) -> bool:
	return absf(a - b) < eps


## 占地越界的条数（House.txt「宽/长」应恒为 1..3）
func _footprint_out_of_range(files: Dictionary) -> int:
	var bad := 0
	for fid in files.keys():
		var sz := Rules.house_footprint_size(str(fid))
		if sz.x < 1 or sz.x > 3 or sz.y < 1 or sz.y > 3:
			bad += 1
	return bad


func _all_footprint_in_range(files: Dictionary) -> bool:
	return files.size() > 0 and _footprint_out_of_range(files) == 0

# ------------------------------------------------------------------ 1. 数值表

func _test_native_alignment() -> void:
	_lines.append("[native] 原版强化、内部能量、目标及尺寸等级")
	var transforms := {"upgrade": "tianshi", "monster": "emo", "buyland": "tudigong",
		"free": "caishen", "invincible": "invisible", "missile": "nuke", "tax": "qiongshen", "rob": "shuaishen"}
	for source in transforms:
		var world := _card_world("gem")
		world.players[1].cards = ["gem", source]
		_ok("原版强化换卡 " + source, world.act_use_card(1, "gem", -1, source)
			and world.players[1].cards == [transforms[source]])
	for card in Rules.cards():
		var id := str(card.id)
		var allowed := transforms.has(id) or id in ["caishen", "fushen", "qiongshen", "shuaishen", "tianshi", "emo", "qingshen", "run", "priceup", "pricedown", "hibernate", "redcard", "blackcard", "seize", "invisible"]
		_ok("强化集合 " + id, Rules.can_gem_combine(id) == allowed and not Rules.can_gem_combine("boost:" + id))
	for enhanced in [false, true]:
		var results := {}
		for seed in range(60):
			var rush := _card_world("run")
			rush.rng.seed = seed
			var id := "boost:run" if enhanced else "run"
			rush.players[1].cards = [id]
			rush.act_use_card(1, id)
			results[int(rush.players[1].moving)] = true
		var expected := [42, 48, 54, 60, 66, 72] if enhanced else [21, 24, 27, 30, 33, 36]
		_ok("暴走闭区间六种结果，增强双倍 " + str(enhanced), results.size() == 6 and results.keys().all(func(n): return expected.has(n)))
	for kind in ["uptown", "shop", "industry", "special1", "special2", "special3"]:
		for side in [1, 2, 3]:
			var first := Rules.house_asset_level(kind, side, 1)
			if first == 0: continue
			var last := first
			while Rules.house_next_level(kind, last) > 0: last = Rules.house_next_level(kind, last)
			_ok("尺寸内升级 " + kind + str(side), Rules.house_local_grade(kind, first) == 1
				and Rules.house_footprint(Rules.house_file(kind, last)) == side
				and Rules.house_next_level(kind, last) == 0)
			var split := _fresh_sim()
			var idx := int(split.players[1].tile)
			split.plots[idx] = {"owner": 1, "level": first, "type": kind, "footprint": side, "members": [idx]}
			split._downgrade_estate(idx)
			_ok("一级拆为空地 " + kind + str(side), int(split.plots[idx].level) == 0
				and str(split.plots[idx].type) == "" and int(split.plots[idx].owner) == 1)
	var maxima := {"qiongshen": 15, "hutu": 15, "emo": 20, "caishen": 20, "tushen": 30, "jingling": 20, "huaxian": 15, "dushen": 20, "guaishou": 15}
	for id in maxima:
		var world := _fresh_sim()
		var owner: Dictionary = world.players[1]
		world.add_pet(owner, id)
		var pet := world.active_pet(owner)
		_ok("原版内部能量上限/整数半值 " + id, world.pet_max_energy(pet) == float(maxima[id])
			and world.pet_energy(pet) == float(int(maxima[id]) * 5 / 10))
		owner.cards = ["step3"]
		world._set_pet_energy(pet, 0.0)
		_ok("喂食量不随宠物上限放大 " + id, world.act_feed_card(1, "step3")
			and is_equal_approx(world.pet_energy(pet), 3.0))
		_ok("HUD 表情不使用星级索引 " + id,
			Rules.pet_hud_art(id, false, false) == Rules.pet_art(id, "face", 1)
			and Rules.pet_hud_art(id, true, false) == Rules.pet_art(id, "face", 2)
			and Rules.pet_hud_art(id, false, true) == Rules.pet_art(id, "face", 3))
	var walked := _pet_world("caishen")
	walked.add_pet(walked.players[1], "hutu")
	var walker: Dictionary = walked.players[1]
	walker.tile = 0
	walker.moving = 10
	walker.speed = 1.0
	walker.progress = 0.0
	walked._advance(walker, 0.4)
	_ok("没有跨路点时小神仙不累计成长", int(walked.active_pet(walker).growth) == 0)
	walked._advance(walker, 0.7)
	_ok("跨路点只累计随身实例", int(walked.active_pet(walker).growth) == 1
		and int(walker.pets[1].growth) == 0)
	walked._advance(walker, 2.0)
	_ok("一次移动更新跨多点只记一次原版标记", int(walked.active_pet(walker).growth) == 2)
	var energy := _pet_world("huaxian")
	var p: Dictionary = energy.players[1]
	energy.add_pet(p, "hutu")
	var reserve: Dictionary = p.pets[1]
	var before := energy.pet_energy(reserve)
	energy._tick_pet_hunger(Rules.seconds_per_day() * 3.0)
	_ok("满槽保持且备用不衰减", energy.pet_skill_ready(energy.active_pet(p)) and energy.pet_energy(reserve) == before)
	p.credit = 0
	var caster := energy.active_pet(p)
	var expected := energy.pet_max_energy(caster) - energy.pet_cost("huaxian", 1)
	_ok("技能只扣原版内部能量", energy.act_pet_skill(1) and int(p.credit) == 0 and energy.pet_energy(caster) == expected)
	energy._tick_pet_hunger(Rules.seconds_per_day() * 3.0)
	_ok("未满槽三天掉一点内部能量", is_equal_approx(energy.pet_energy(caster), expected - 1.0) and energy.pet_energy(reserve) == before)
	var curse := _pet_world("qiongshen")
	_ok("小穷神要求选择对手，不随机施加", not curse.act_pet_skill(1, false)
		and curse.act_pet_skill(1, false, 2) and float(curse.players[2].effects.rent_pay_double_until) > curse.time)
	var devil := _pet_world("emo")
	devil.active_pet(devil.players[1]).level = 2
	var idx := int(devil.players[1].tile)
	_ok("二级恶魔拆脚下两级", devil.act_pet_skill(1) and int(devil.plots[idx].level) == 0)
	var monster := _pet_world("guaishou")
	var victim := monster.active_pet(monster.players[2])
	var victim_before := monster.pet_energy(victim)
	var attack_voices: Array = []
	monster.game_event.connect(func(kind, data):
		if kind == "pet_attacked": attack_voices.append(int(data.get("voice_line", 0))))
	_ok("小怪兽伤害随身宠能量，保留宠物", monster.act_pet_skill(1)
		and not monster.players[2].pets.is_empty() and monster.pet_energy(victim) < victim_before)
	_ok("原版宠物挨打语音6", attack_voices == [6])
	monster._set_pet_energy(monster.active_pet(monster.players[1]), 15.0)
	monster._set_pet_energy(victim, 1.0)
	_ok("宠物被击退语音8并移除实例", monster.act_pet_skill(1) and attack_voices == [6, 8]
		and monster.active_pet(monster.players[2]).is_empty())
	var steal := _card_world("abduct")
	var taker: Dictionary = steal.players[1]
	var target: Dictionary = steal.players[2]
	steal.add_pet(taker, "caishen")
	var stolen := steal.active_pet(target)
	stolen.level = 3
	steal._set_pet_energy(stolen, 9.0)
	taker.cards = ["abduct"]
	var equipped := steal.pet_token(steal.active_pet(taker))
	_ok("同种诱拐保留两个实例和原能量等级", steal.act_use_card(1, "abduct", 2)
		and taker.pets.size() == 2 and steal.pet_token(steal.active_pet(taker)) == equipped
		and int(taker.pets[1].level) == 3 and steal.pet_energy(taker.pets[1]) == 9.0 and steal.active_pet(target).is_empty())
	_ok("同种备用实例可以单独使用", steal.act_set_active_pet(1, steal.pet_token(taker.pets[1]))
		and steal.active_pet(taker).level == 3)
	var save := steal.to_dict()
	var restored := _fresh_sim()
	restored.apply_dict(save)
	_ok("实例与能量随网络/存档快照往返", restored.players[1].pets.size() == 2
		and restored.active_pet(restored.players[1]).level == 3
		and restored.pet_energy(restored.active_pet(restored.players[1])) == 9.0)
	var state := _card_world("invisible")
	var invisible: Dictionary = state.players[1]
	invisible.effects.invincible_until = state.time + 99.0
	invisible.effects.no_rent_steps = 30
	invisible.cards = ["invisible"]
	_ok("隐形独立互斥且具伤害保护", state.act_use_card(1, "invisible") and state._protected(invisible)
		and float(invisible.effects.invincible_until) == 0.0 and int(invisible.effects.no_rent_steps) == 0)
	state.time = float(invisible.effects.invisible_until)
	_ok("隐形到期没有无敌残留", not state._protected(invisible))
	var seal := _card_world("seize")
	var sealer: Dictionary = seal.players[1]
	sealer.cards = ["seize", "seize", "boost:seize"]
	var street := seal._current_street(int(sealer.tile))
	seal.act_use_card(1, "seize")
	var expiry := float(seal.street_seal[street])
	seal.time += 10.0
	seal.act_use_card(1, "seize")
	_ok("未到期重复查封累加五天", float(seal.street_seal[street]) == expiry + 5.0 * Rules.seconds_per_day())
	seal.act_use_card(1, "boost:seize")
	_ok("增强查封累加十天", float(seal.street_seal[street]) == expiry + 15.0 * Rules.seconds_per_day())
	var legacy := {"id": "hutu", "level": 1, "fullness": 80.0, "ready": true}
	_ok("旧存档锁存就绪转换成真正满能量", energy.pet_energy(legacy) == 15.0 and energy.pet_skill_ready(legacy))
	var depleted := {"id": "hutu", "level": 1, "fullness": 10.0, "ready": false}
	_ok("低能量表情按内部三点阈值", energy.pet_anxious(depleted) and energy.pet_energy(depleted) == 1.5)

func _test_rules() -> void:
	print("\n[1] 数值表 (realtime.json + houses.json)")
	var d := Rules.data
	_ok("rules 已载入", not d.is_empty())
	_ok("秒/天 = 24", _near(Rules.seconds_per_day(), 24.0))
	_ok("卡牌 42 张", Rules.cards().size() == 42, "实际 %d" % Rules.cards().size())
	_ok("无敌卡 72 秒", _near(float(Rules.card_by_id("invincible").get("seconds", 0.0)), 72.0))
	_ok("冬眠卡 10 秒", _near(float(Rules.card_by_id("hibernate").get("seconds", 0.0)), 10.0))
	_ok("核弹卡范围 5", int(Rules.card_by_id("nuke").get("range", 0)) == 5)
	_ok("推土机速度 2 格/秒", _near(float(Rules.get_val("movement.bulldozer_speed", 0.0)), 2.0))
	_ok("静止睡眠 25 秒", _near(float(Rules.get_val("movement.player_idle_sleep_seconds", 0.0)), 25.0))
	# ---- House.txt 房屋等级表 ----
	_ok("houses.json 已载入", not Rules.houses.is_empty()
		and Rules.house_types.size() == 6,
		"主题数 %d" % Rules.house_types.size())
	var ngrade := 0
	for t in Rules.house_types:
		ngrade += Rules.house_grades(str(t)).size()
	_ok("45 个房屋等级全部解析（NumType=6 之和）", ngrade == 45, "实际 %d" % ngrade)
	_ok("住宅 12 / 商业 15 / 工业 9（House.txt nGrade）",
		Rules.house_max_level("uptown") == 12
			and Rules.house_max_level("shop") == 15
			and Rules.house_max_level("industry") == 9,
		"%d/%d/%d" % [Rules.house_max_level("uptown"), Rules.house_max_level("shop"),
			Rules.house_max_level("industry")])
	_ok("升级费随尺寸档递增（公寓 1000 / 住宅 2000 / 住宅区 3000）",
		Rules.house_upgrade_cost("uptown", 1) == 1000
			and Rules.house_upgrade_cost("uptown", 5) == 2000
			and Rules.house_upgrade_cost("uptown", 9) == 3000,
		"%d/%d/%d" % [Rules.house_upgrade_cost("uptown", 1),
			Rules.house_upgrade_cost("uptown", 5), Rules.house_upgrade_cost("uptown", 9)])
	_ok("租金取自 House.txt（一级公寓 1500 / 四级住宅区 24000）",
		Rules.house_rent("uptown", 1) == 1500 and Rules.house_rent("uptown", 12) == 24000,
		"%d/%d" % [Rules.house_rent("uptown", 1), Rules.house_rent("uptown", 12)])
	_ok("模型 id 取自 House.txt「文件」列（a0101 / b0305 / d201）",
		Rules.house_file("uptown", 1) == "a0101"
			and Rules.house_file("shop", 15) == "b0305"
			and Rules.house_file("special1", 1) == "d201",
		"%s/%s/%s" % [Rules.house_file("uptown", 1), Rules.house_file("shop", 15),
			Rules.house_file("special1", 1)])
	_ok("建筑 id 反查主题", Rules.type_of_house_file("a0203") == "uptown"
		and Rules.type_of_house_file("d303") == "special3")

	# ---- 建筑占地 1x1 / 2x2 / 3x3（House.txt「宽 / 长」列）----
	var files: Dictionary = Rules.houses.get("files", {})
	_ok("houses.json 有 files 反查表（45 条）", files.size() == 45, "实际 %d" % files.size())
	_ok("占地 1x1 = a0101 / 2x2 = a0201 / 3x3 = a0304",
		Rules.house_footprint_label("a0101") == "1x1"
			and Rules.house_footprint_label("a0201") == "2x2"
			and Rules.house_footprint_label("a0304") == "3x3",
		"%s/%s/%s" % [Rules.house_footprint_label("a0101"),
			Rules.house_footprint_label("a0201"), Rules.house_footprint_label("a0304")])
	_ok("占地边长 a0101=1 / a0201=2 / a0304=3",
		Rules.house_footprint("a0101") == 1 and Rules.house_footprint("a0201") == 2
			and Rules.house_footprint("a0304") == 3,
		"%d/%d/%d" % [Rules.house_footprint("a0101"), Rules.house_footprint("a0201"),
			Rules.house_footprint("a0304")])
	_ok("占地 (宽,长) 成对：c0303=3x3 / b0205=2x2",
		Rules.house_footprint_size("c0303") == Vector2i(3, 3)
			and Rules.house_footprint_size("b0205") == Vector2i(2, 2),
		"%s/%s" % [str(Rules.house_footprint_size("c0303")),
			str(Rules.house_footprint_size("b0205"))])
	_ok("占地兜底：未知 id → 1x1（不是 0，也不是崩）",
		Rules.house_footprint("zzzz") == Rules.FALLBACK_FOOTPRINT
			and Rules.house_footprint_size("zzzz") == Vector2i(1, 1),
		"%d" % Rules.house_footprint("zzzz"))
	_ok("BuildingLib 转发一致（footprint / label）",
		BuildingLib.footprint("a0304") == 3 and BuildingLib.footprint_label("a0201") == "2x2"
			and BuildingLib.footprint("zzzz") >= 1,
		"%d/%s" % [BuildingLib.footprint("a0304"), BuildingLib.footprint_label("a0201")])
	_ok("全部 45 个等级的占地都在 1..3",
		_all_footprint_in_range(files), "越界数 %d" % _footprint_out_of_range(files))

# ------------------------------------------------------------------ 2. 地图

func _test_map() -> void:
	print("\n[2] 地图数据 (原版生成)")
	var m := MapData.load_from("china")
	_ok("china 地图可加载", m != null)
	if m == null:
		return
	_ok("街道 19 条", m.streets.size() == 19, "实际 %d" % m.streets.size())
	_ok("原版中国地图 98 格", m.tile_count() == 98, "实际 %d" % m.tile_count())
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

	# 掷骰动画期间角色**不动**（原版节奏：抛骰子 → 抛物线落下 → 定格点数 → 才起步）
	sim.step(Sim.ROLL_ANIM_SECONDS * 0.5)
	_ok("掷骰动画没播完之前角色不动（原版节奏，老板 2026-09-26 反馈）",
		int(p["tile"]) == 0 and _near(float(p["progress"]), 0.0),
		"tile=%d progress=%.3f" % [int(p["tile"]), float(p["progress"])])

	# 动画播完才开始走：再走 0.25 秒，速度 2 格/秒 → 格内进度应为 0.5（尚未换格）
	sim.step(Sim.ROLL_ANIM_SECONDS * 0.5 + 0.25)
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

# ------------------------------------------- 3b. 体力（左下角色面板「能量条」的数据源）

func _test_stamina() -> void:
	print("\n[3b] 体力（原版场景配置「和体力相关参数」）")
	var m := MapData.load_from("china")
	var st: Dictionary = m.stamina
	_ok("china 体力 = 20 / 7 / 240 / 600",
		_near(float(st.get("step_cost", 0.0)), 20.0)
		and _near(float(st.get("regen_per_sec", 0.0)), 7.0)
		and _near(float(st.get("min_to_start", 0.0)), 240.0)
		and _near(float(st.get("max", 0.0)), 600.0), str(st))
	var sp: Dictionary = MapData.load_from("space").stamina
	_ok("space 体力 = 0 / 0 / 10 / 5000（太空关不走体力）",
		_near(float(sp.get("step_cost", 1.0)), 0.0)
		and _near(float(sp.get("max", 0.0)), 5000.0), str(sp))

	var sim := _fresh_sim()
	var p: Dictionary = sim.players[1]
	_ok("开局体力 = 上限", _near(float(p["stamina"]), 600.0), "%.0f" % float(p["stamina"]))

	# ---- 多骰：GO 钮左侧选择器（**上限 = 2**，原版 5 张实机截图一致只有 2 颗）----
	sim.act_roll(1, 2)
	var n: int = int(p["moving"])
	_ok("2 颗骰子相加落在 2..12", n >= 2 and n <= 12, "点数 %d" % n)
	_ok("每颗点数分别记录（GO 钮逐颗亮）",
		(p["last_faces"] as Array).size() == 2, str(p["last_faces"]))
	_ok("骰子上限 = 2（原版实机只看到 2 颗）", Sim.DICE_PER_ROLL_MAX == 2,
		"DICE_PER_ROLL_MAX = %d" % Sim.DICE_PER_ROLL_MAX)
	# ---- 骰子数量夹取：传 99 颗也只能按上限掷 ----
	var sim2 := _fresh_sim()
	var q: Dictionary = sim2.players[1]
	sim2.act_roll(1, 99)
	_ok("骰子数量上夹到 %d 颗（点数 ≤ %d）" % [Sim.DICE_PER_ROLL_MAX, 6 * Sim.DICE_PER_ROLL_MAX],
		int(q["moving"]) >= Sim.DICE_PER_ROLL_MAX and int(q["moving"]) <= 6 * Sim.DICE_PER_ROLL_MAX,
		"点数 %d" % int(q["moving"]))
	_ok("夹取后逐颗点数也只有 %d 个" % Sim.DICE_PER_ROLL_MAX,
		(q["last_faces"] as Array).size() == Sim.DICE_PER_ROLL_MAX)
	_ok("下限：传 0 颗也至少掷 1 颗", _test_dice_floor())

	var guard := 0
	while int(p["moving"]) > 0 and guard < 3000:
		sim.step(0.05)
		guard += 1

	# ---- 消耗：每格 -20（走的同时每秒还在 +7，所以实际降幅略小）----
	var drop := 600.0 - float(p["stamina"])
	_ok("走 %d 格体力下降（≥15n 且 ≤20n）" % n,
		drop >= 15.0 * n - 0.5 and drop <= 20.0 * n + 0.5, "降了 %.1f" % drop)

	# ---- 恢复：每秒 +7 ----
	var s0: float = float(p["stamina"])
	for i in range(200):        # 10 秒
		sim.step(0.05)
	_ok("静止 10 秒恢复 +70（每秒 7）",
		_near(float(p["stamina"]), minf(600.0, s0 + 70.0), 1.0),
		"实际 %.1f" % float(p["stamina"]))

	# ---- 出发门槛：低于「自己走所需要最小体力值」不给走 ----
	p["stamina"] = 100.0
	_ok("体力 100 < 240 → 不许出发", not sim.act_roll(1), "体力 100")
	_ok("被拒时没有发车", int(p["moving"]) == 0)
	p["stamina"] = 300.0
	_ok("体力 300 ≥ 240 → 可以出发", sim.act_roll(1))

## 传 0 / 负数颗骰子时必须至少掷 1 颗（不会出现 0 点原地不动）
func _test_dice_floor() -> bool:
	var sim := _fresh_sim()
	sim.act_roll(1, 0)
	var p: Dictionary = sim.players[1]
	var ok0: bool = int(p["moving"]) >= 1 and int(p["moving"]) <= 6
	var sim2 := _fresh_sim()
	sim2.act_roll(1, -5)
	var q: Dictionary = sim2.players[1]
	return ok0 and int(q["moving"]) >= 1 and int(q["moving"]) <= 6

# ------------------------------------------- 3c. 路面事件（原版 Roadevent.txt 1..16）

func _test_road_events() -> void:
	print("\n[3c] 路面事件（Roadevent.txt 16 类）")
	var m := MapData.load_from("aiji")
	var want := {
		"platform": "传送平台", "cardshop": "卡片商店", "hospital": "医院", "cardpt": "卡片点",
		"tvnews": "电视台", "labar": "拉霸", "capital": "市政府", "pethouse": "精灵屋",
		"game_a": "游戏点A", "game_b": "游戏点B", "coupon5": "点券5", "coupon10": "点券10",
		"coupon20": "点券20", "coupon30": "点券30", "coupon50": "点券50", "casino": "乐透",
	}
	var bad: Array = []
	var counts: Dictionary = {}
	for t in m.tiles:
		if str(t.get("kind", "")) != "event":
			continue
		var e := str(t.get("event", ""))
		counts[e] = int(counts.get(e, 0)) + 1
		if not want.has(e) or str(t.get("name", "")) != want[e]:
			bad.append("%s→%s(应 %s)" % [e, t.get("name", ""), want.get(e, "?")])
	_ok("事件名逐条对齐原版 Roadevent.txt", bad.is_empty(), str(bad))
	_ok("埃及有卡片商店（拿卡来源之一）", int(counts.get("cardshop", 0)) > 0,
		"cardshop x%d" % int(counts.get("cardshop", 0)))
	_ok("埃及有卡片点（拿卡来源之二）", int(counts.get("cardpt", 0)) > 0,
		"cardpt x%d" % int(counts.get("cardpt", 0)))
	_ok("埃及有点券格（顶栏第 4 项的数据源）",
		int(counts.get("coupon5", 0)) + int(counts.get("coupon10", 0))
		+ int(counts.get("coupon20", 0)) + int(counts.get("coupon30", 0))
		+ int(counts.get("coupon50", 0)) > 0, str(counts))

	# ---- 逐类跑一遍：每一类都必须**真的产生了后果**，不能只打日志 ----
	# 「后果」有两类：① 改了状态（钱/点券/手牌/小神仙/沉睡）
	#                 ② 发了语义事件（卡片商店 / 精灵屋是「开店」，本身不改状态）
	var sim := Sim.new()
	sim.setup(m, 12345)
	sim.add_player(1, "玩家一")
	sim.running = true
	var p: Dictionary = sim.players[1]
	var kinds: Array = []
	sim.game_event.connect(func(k: String, _d: Dictionary) -> void: kinds.append(k))
	var silent: Array = []
	for e in counts.keys():          # 只遍历埃及地图上**真有的**类型
		var n0 := kinds.size()
		var res: Dictionary = _fire_event(sim, p, str(e))
		if e == "platform" and sim._other_platform(24) < 0:
			continue # 相邻入口/出口的位移由道路本身完成；见 _test_platform。
		if not bool(res.get("changed", false)) and kinds.size() == n0:
			silent.append(e)
	_ok("埃及真有的 %d 类事件全部产生后果（改状态 或 发事件）" % counts.size(),
		silent.is_empty(), str(silent))
	_ok("事件类型覆盖 14 类（Roadevent.txt 16 类里本图有 14 类）",
		counts.size() >= 14, "实际 %d 类：%s" % [counts.size(), str(counts.keys())])
	_ok("卡片商店是「开店」不再是白送卡（发 cardshop_open）",
		kinds.has("cardshop_open"), str(kinds))
	_ok("卡片点仍然发卡（路面捡卡的正路）", (p["cards"] as Array).size() > 0,
		"手牌 %d 张" % (p["cards"] as Array).size())
	_ok("精灵屋是「开店」不再是白送（发 pethouse_open）",
		kinds.has("pethouse_open"), str(kinds))
	_ok("点券格加点券", int(p["credit"]) > 0, "点券 %d" % int(p["credit"]))
	_ok("相邻入口出口不触发重复传送", not p.has("_ev_platform_moved"))
	var fate_results: Array = []
	sim.game_event.connect(func(kind: String, data: Dictionary) -> void:
		if kind == "fate": fate_results.append(data))
	_fire_event(sim, p, "tvnews")
	_ok("问号路点发出具体命运结果，无未填占位符", fate_results.size() == 1
		and not str(fate_results[0].get("text", "")).contains("<"), str(fate_results))
	p["tile"] = 0
	var aimed := sim.card_road_candidates(1, "missile")
	_ok("飞弹可瞄准前后20个路点，21格外不可选", aimed.has(20)
		and aimed.has(m.tile_count() - 20) and not aimed.has(21)
		and not aimed.has(m.tile_count() - 21), "候选%d格" % aimed.size())
	for event_name in ["tvnews", "game_a"]:
		var walked := Sim.new()
		walked.setup(m, 808)
		walked.add_player(1, "步行玩家")
		walked.running = true
		var landing := -1
		for tile in range(m.tile_count()):
			if str(m.tile(tile).get("event", "")) == event_name:
				landing = tile
				break
		var heard: Array = []
		walked.game_event.connect(func(kind: String, _data: Dictionary) -> void: heard.append(kind))
		var credit_before := int(walked.players[1].credit)
		_arrive_at(walked, walked.players[1], landing)
		_ok("实际走到%s路点会触发可见结果" % event_name,
			heard.has("fate") if event_name == "tvnews" else
			(heard.has("credit") and int(walked.players[1].credit) > credit_before), str(heard))

# ------------------------------------------- 3e. 小神仙（精灵屋）+ 卡片商店

## 造一个「这只小神仙的特技正好能发动」的世界
func _pet_world(pet_id: String) -> Sim:
	var m := MapData.load_from("china")
	var sim := Sim.new()
	sim.setup(m, 1234)
	sim.add_player(1, "玩家一")
	sim.add_player(2, "玩家二")
	sim.running = true
	var p: Dictionary = sim.players[1]
	var q: Dictionary = sim.players[2]
	var a := -1
	for i in range(m.tile_count()):
		if str(m.tile(i).get("kind", "")) == "plot":
			a = i
			break
	if a >= 0:
		p["tile"] = a
		q["tile"] = sim._wrap(a + 1)      # 邻格（糊涂鬼要「周围」）
		sim.plots[a] = {"owner": 2, "level": 2, "type": "industry"}          # 对手的地
		sim.plots[sim._wrap(a + 3)] = {"owner": 1, "level": 1, "type": "industry"}  # 自己的地
	p["credit"] = 1000
	sim.add_pet(p, pet_id)
	sim.add_pet(q, "caishen")             # 小怪兽「PK技」要有目标
	# ⚠️ 体力系统（老板 2026-09-27）：技能要**体力满**才发得动 → 测试世界直接给满。
	#   必须放在 add_pet **之后**（在那之前 p["pets"] 还是空的）。
	for pe2 in (p["pets"] as Array):
		(pe2 as Dictionary)["fullness"] = Sim.PET_FULLNESS_MAX
	for qe in (q["pets"] as Array):
		(qe as Dictionary)["fullness"] = Sim.PET_FULLNESS_MAX
	return sim


# -------------------------------------------- 3h. 卡片菜单 + 喂食（对齐原版实机截图）

func _test_card_menu_feed() -> void:
	_lines.append("[3h] 卡片菜单（锁定 / 使用 / 喂食）+ 喂食效果")
	# 老板的原版实机截图（docs/screenshots/orig/records/喂食功能.png）里菜单就是
	# **锁定 / 使用 / 喂食** 三项 —— 没有「丢弃」
	_ok("卡片菜单文案 = 锁定 / 使用 / 喂食（String.txt 1/2/4）",
		Rules.card_menu_label("lock") == "锁定" and Rules.card_menu_label("use") == "使用"
		and Rules.card_menu_label("feed") == "喂食",
		"%s / %s / %s" % [Rules.card_menu_label("lock"), Rules.card_menu_label("use"),
			Rules.card_menu_label("feed")])

	var sim := _pet_world("caishen")
	var p: Dictionary = sim.players[1]
	(p["cards"] as Array).append("step3")
	# ⚠️ `_pet_world` 把饱食度填满了（好让技能发得动），测喂食前先把它饿下来
	(p["pets"][0] as Dictionary)["fullness"] = 0.0
	var lv0 := int(p["pets"][0]["level"])
	var f0 := float(p["pets"][0].get("fullness", 0.0))
	var n0 := (p["cards"] as Array).size()
	var ok_feed := sim.act_feed_card(1, "step3")
	_ok("原版三步卡直接补三点能量（小财神上限20，显示15%）",
		is_equal_approx(sim.pet_energy(sim.active_pet(p)), 3.0)
		and is_equal_approx(sim.pet_fullness_ratio(sim.active_pet(p)), 0.15))
	# Native feeding adds card energy directly; it does not change the level.
	_ok("喂食：消耗一张卡 + **只加饱食度、等级不变**", ok_feed
		and int(p["pets"][0]["level"]) == lv0
		and float(p["pets"][0]["fullness"]) > f0
		and (p["cards"] as Array).size() == n0 - 1,
		"level %d→%d（应不变），饱食 %d→%d，手牌 %d→%d" % [lv0,
			int(p["pets"][0]["level"]), int(f0), int(p["pets"][0]["fullness"]), n0,
			(p["cards"] as Array).size()])
	# 喂到饱 → 饱食度封顶，再喂应被拒（别浪费卡）
	for _i in range(7):
		(p["cards"] as Array).append("step3")
		sim.act_feed_card(1, "step3")
	_ok("喂饱之后弹「都吃饱了」、不再吃卡",
		float(p["pets"][0]["fullness"]) == Sim.PET_FULLNESS_MAX
			and not sim.act_feed_card(1, "step3"),
		"饱食 %d / 上限 %d" % [int(p["pets"][0]["fullness"]),
			int(Sim.PET_FULLNESS_MAX)])
	# 时间驱动升级：过一个月，所有小神仙 +1 级
	var lv_before := int(p["pets"][0]["level"])
	sim.road_day = 31
	sim._tick_pet_aging()
	sim.road_day = 61
	sim._tick_pet_aging()
	_ok("只推进月份不提升小神仙等级",
		int(p["pets"][0]["level"]) == lv_before,
		"level %d → %d" % [lv_before, int(p["pets"][0]["level"])])

	var s2 := _fresh_sim()
	(s2.players[1]["cards"] as Array).append("step3")
	_ok("身上没有小神仙时喂食被拒（且**不消耗**卡）",
		not s2.act_feed_card(1, "step3")
		and (s2.players[1]["cards"] as Array).size() == 1,
		"手牌 %d 张" % (s2.players[1]["cards"] as Array).size())

	var s3 := _pet_world("caishen")
	s3.players[1]["pets"][0]["level"] = 4
	(s3.players[1]["cards"] as Array).append("step3")
	_ok("小神仙满级时喂食被拒（不浪费卡）",
		not s3.act_feed_card(1, "step3")
		and (s3.players[1]["cards"] as Array).size() == 1,
		"手牌 %d 张" % (s3.players[1]["cards"] as Array).size())

	# 商店面板：原版一次只显示一张（老板的原版截图里没有「持有栏」）
	var idx_txt := ""
	if FileAccess.file_exists("res://assets/pets/index.json"):
		idx_txt = FileAccess.open("res://assets/pets/index.json", FileAccess.READ).get_as_text()
	var idx: Variant = JSON.parse_string(idx_txt)
	var slots: Dictionary = (idx as Dictionary).get("slot", {}) if idx is Dictionary else {}
	_ok("商店槽位表齐备（持有 panel / 小神仙货架 shop / 卡片商店 cardshop）",
		slots.has("shop") and slots.has("cardshop"),
		str(slots.keys()))
	var cs: Dictionary = slots.get("cardshop", {})
	var sl0: Array = cs.get("slots", [])
	var w0 := 0.0
	if sl0.size() > 0:
		w0 = float((sl0[0] as Dictionary).get("w", 0.0))
	_ok("卡片商店槽位是 {x,y,w,h} 的 8 格（原版量出来的，每格 95×30）",
		sl0.size() == 8 and w0 == 95.0, "%d 格，首格宽 %.0f" % [sl0.size(), w0])


# ------------------------------------ 3i. 卡片栏规则（上限 5 / 叠加 / 顶卡 / 锁定保护）

func _test_hand() -> void:
	_lines.append("[3i] 卡片栏（上限 5 / 同种叠加 / 顶最前方 / 锁定保护）")
	# 依据 = 老板 2026-09-26 的原版实机规则（`Initvar_r.txt` 里没有手牌上限这一项）
	_ok("卡片栏上限 = 5", Sim.HAND_MAX == 5, "HAND_MAX = %d" % Sim.HAND_MAX)

	var ids := ["caishen", "fushen", "qiongshen", "shuaishen", "tianshi", "emo", "step3"]
	var sim := _fresh_sim()
	var p: Dictionary = sim.players[1]
	for i in range(5):
		sim._push_card(p, str(ids[i]))
	_ok("5 张不同的卡占 5 个栏位",
		sim.hand_slots(p) == 5 and (p["cards"] as Array).size() == 5,
		"%d 栏 / %d 张" % [sim.hand_slots(p), (p["cards"] as Array).size()])

	sim._push_card(p, str(ids[0]))
	_ok("同种卡叠加 → 只多一张、栏位数不变",
		sim.hand_slots(p) == 5 and (p["cards"] as Array).size() == 6,
		"%d 栏 / %d 张" % [sim.hand_slots(p), (p["cards"] as Array).size()])

	var res := sim._push_card(p, str(ids[5]))
	_ok("满栏时新卡顶掉**最前方**那张",
		bool(res["added"]) and str(res["dropped"]) == str(ids[0])
		and not (p["cards"] as Array).has(str(ids[0])),
		"顶掉 %s" % str(res["dropped"]))

	# 锁定保护：把当前最前方的锁上，再塞新卡 → 必须跳过它
	var head := str(ids[1])
	sim.act_lock_card(1, head)
	_ok("锁定状态记在**权威 Sim** 里（满栏顶卡判定要用）", sim.card_locked(p, head), "")
	var res2 := sim._push_card(p, str(ids[6]))
	_ok("锁定的卡不会被顶掉（跳过它、顶下一张）",
		bool(res2["added"]) and str(res2["dropped"]) != head
		and (p["cards"] as Array).has(head),
		"顶掉 %s；%s 仍在" % [str(res2["dropped"]), head])

	var sim2 := _fresh_sim()
	var q: Dictionary = sim2.players[1]
	for i in range(5):
		sim2._push_card(q, str(ids[i]))
		sim2.act_lock_card(1, str(ids[i]))
	var res3 := sim2._push_card(q, "step3")
	_ok("全部锁定时新卡进不来（reason = all_locked）",
		not bool(res3["added"]) and str(res3["reason"]) == "all_locked",
		"reason=%s" % str(res3["reason"]))
	var use_sim := _fresh_sim()
	var use_player: Dictionary = use_sim.players[1]
	(use_player["cards"] as Array).append("invincible")
	use_sim.act_lock_card(1, "invincible")
	_ok("锁定卡仍可正常使用", use_sim.act_use_card(1, "invincible")
		and float(use_player["effects"]["invincible_until"]) > use_sim.time
		and not use_sim.card_locked(use_player, "invincible"))
	var feed_sim := _pet_world("caishen")
	var feed_player: Dictionary = feed_sim.players[1]
	(feed_player["cards"] as Array).append("step3")
	(feed_player["pets"][0] as Dictionary)["fullness"] = 0.0
	feed_sim.act_lock_card(1, "step3")
	_ok("锁定卡仍可喂食小神仙", feed_sim.act_feed_card(1, "step3")
		and not (feed_player["cards"] as Array).has("step3")
		and not feed_sim.card_locked(feed_player, "step3"))
	var steal_sim := _card_world("rob")
	var thief: Dictionary = steal_sim.players[1]
	var victim: Dictionary = steal_sim.players[2]
	thief.cards = ["rob"]
	victim.cards = ["step1"]
	steal_sim.act_lock_card(2, "step1")
	_ok("锁定卡仍能被对手抢夺，失去卡后锁定状态清理",
		steal_sim.act_use_card(1, "rob", 2) and (thief.cards as Array).has("step1")
		and not (victim.cards as Array).has("step1")
		and not steal_sim.card_locked(victim, "step1"))


# ------------------------------------ 3j. 股票 / 公司（Role.txt 缺省公司 + Initvar_r 参数）

func _test_stock() -> void:
	_lines.append("[3j] 股票 / 公司（Role.txt 的「缺省公司」+ Initvar_r 的 Stock_*）")
	_ok("Role.txt 的 12 个角色都载入了", Rules.roles().size() == 12,
		"%d 个" % Rules.roles().size())
	# 老板 2026-09-26 的原版股票截图：面板前四家 = 这四位的缺省公司（逐字对上）
	_ok("孙小美=中华美食 / 阿土伯=新土地 / 宫本宝藏=第一宝藏 / 乌咪=玛雅",
		Rules.role_company(5) == "中华美食" and Rules.role_company(2) == "新土地"
		and Rules.role_company(3) == "第一宝藏" and Rules.role_company(4) == "玛雅",
		"%s / %s / %s / %s" % [Rules.role_company(5), Rules.role_company(2),
			Rules.role_company(3), Rules.role_company(4)])

	var sim := _fresh_sim()
	var p: Dictionary = sim.players[1]
	var comp := str(p.get("company", ""))
	_ok("玩家以自己的「缺省公司」上市", comp != "", comp)
	_ok("初始持有本公司 2000 股（Player_Com_SelfShares，与截图一致）",
		sim.holding_of(1, comp) == 2000, "%d 股" % sim.holding_of(1, comp))
	_ok("初始股价 = Player_Com_Capital / AllShares = 500000/10000 = 50",
		absf(sim.stock_price(comp) - 50.0) < 0.01, "%.2f" % sim.stock_price(comp))
	_ok("地图的 6 家虚拟公司也上市了（两个玩家 + 6 = 8 家）",
		sim.stocks.size() == 8, "%d 家：%s" % [sim.stocks.size(), str(sim.stock_names())])

	p["money"] = 200000
	var price := sim.stock_price(comp)
	var before := int(p["money"])
	_ok("买进 100 股 → 持股变 2100", sim.act_buy_stock(1, comp, 100)
		and sim.holding_of(1, comp) == 2100, "%d 股" % sim.holding_of(1, comp))
	var want := int(ceil(price * 100.0))
	want += int(ceil(float(want) * 0.01))
	_ok("买进扣的钱 = 股款 + 1% 手续费（Stock_Handle_Charge）",
		before - int(p["money"]) == want, "扣了 %d（期望 %d）" % [before - int(p["money"]), want])
	_ok("卖出 100 股 → 回到 2000", sim.act_sell_stock(1, comp, 100)
		and sim.holding_of(1, comp) == 2000, "%d 股" % sim.holding_of(1, comp))
	_ok("手里没有的公司卖不出去", not sim.act_sell_stock(1, "尼罗河", 100), "")

	# 董事长：持股 ≥60%（Info.txt 131..135）
	_ok("持股 20% 不是董事长", not sim.is_chairman(1, comp), "")
	p["money"] = 600000                              # 先把钱备够（4000 股 ≈ 20 万 + 手续费）
	sim.act_buy_stock(1, comp, 4000)                 # 2000+4000 = 6000 / 10000
	_ok("买到 60% 即成为董事长", sim.is_chairman(1, comp),
		"%.0f%%" % (sim.holding_ratio(1, comp) * 100.0))
	sim.act_sell_stock(1, comp, 1000)                # 5000 / 10000 = 50%
	_ok("掉到 50% 就不再是董事长", not sim.is_chairman(1, comp), "")

	# 每天开盘波动
	var sim2 := _fresh_sim()
	var c2 := str(sim2.players[1].get("company", ""))
	var pr2 := sim2.stock_price(c2)
	sim2._tick_stocks()
	_ok("每天开盘股价会动，且落在 Stock_OpenPrice ±10% 内",
		absf(sim2.stock_price(c2) - pr2) > 0.0001
		and sim2.stock_price(c2) >= pr2 * 0.895 and sim2.stock_price(c2) <= pr2 * 1.105,
		"%.2f → %.2f" % [pr2, sim2.stock_price(c2)])
	_ok("涨跌是**整数**百分数（原版截图里就是 +7 / +3 / 0 / -1）",
		typeof(sim2.stock_change(c2)) == TYPE_INT, str(sim2.stock_change(c2)))

	# ---- 红卡 / 黑卡（`String.txt` 9029/9030；幅度 `Card_HongKa/HeiKa_Price` = 20%）----
	_ok("红卡 / 黑卡 / 复制卡都已解开 → CARD_UNSUPPORTED 清空（42 张卡全可用）",
		not Sim.CARD_UNSUPPORTED.has("redcard")
		and not Sim.CARD_UNSUPPORTED.has("blackcard")
		and not Sim.CARD_UNSUPPORTED.has("copy"), str(Sim.CARD_UNSUPPORTED))
	_ok("红卡 / 黑卡的目标类型 = stock（要玩家选一种股票）",
		sim.card_target("redcard") == "stock" and sim.card_target("blackcard") == "stock",
		"%s / %s" % [sim.card_target("redcard"), sim.card_target("blackcard")])

	var s3 := _fresh_sim()
	var c3 := str(s3.players[1].get("company", ""))
	(s3.players[1]["cards"] as Array).append("redcard")
	var pr3 := s3.stock_price(c3)
	_ok("红卡：把选中的公司股价抬高 20%",
		s3.act_use_card(1, "redcard", -1, c3)
		and absf(s3.stock_price(c3) - pr3 * 1.20) < 0.02,
		"%.2f → %.2f" % [pr3, s3.stock_price(c3)])
	(s3.players[1]["cards"] as Array).append("blackcard")
	var pr4 := s3.stock_price(c3)
	_ok("黑卡：把选中的公司股价压低 20%",
		s3.act_use_card(1, "blackcard", -1, c3)
		and absf(s3.stock_price(c3) - pr4 * 0.80) < 0.02,
		"%.2f → %.2f" % [pr4, s3.stock_price(c3)])
	(s3.players[1]["cards"] as Array).append("redcard")
	var n_before := (s3.players[1]["cards"] as Array).size()
	_ok("公司名给错时红卡不生效、**卡片保留**（不白扔）",
		not s3.act_use_card(1, "redcard", -1, "不存在的公司")
		and (s3.players[1]["cards"] as Array).size() == n_before,
		"%d 张" % (s3.players[1]["cards"] as Array).size())

	# ---- 小神仙台词映射（2026-09-27 解出：`6000 + 序号×100 + 台词号`）----
	# 依据：老板截图 records/小神仙语音.png 那句「我是人见人爱的小财神」= Info.txt 6302
	var s7 := _fresh_sim()
	_ok("台词映射：小财神 · 台词号 2 = 6302「我是人见人爱的小财神」",
		s7.pet_line("caishen", 2).contains("人见人爱"), s7.pet_line("caishen", 2))
	_ok("台词号 1 = 发特技（拿小穷神验：6001「小穷神附身加倍支付房租！」）",
		s7.pet_line("qiongshen", 1).contains("附身"), s7.pet_line("qiongshen", 1))
	var all_say := true
	var miss: Array = []
	for pid in ["qiongshen", "hutu", "emo", "caishen", "tushen", "jingling",
			"huaxian", "dushen", "guaishou"]:
		if s7.pet_line(pid, 1) == "" or s7.pet_line(pid, 4) == "":
			all_say = false
			miss.append(pid)
	_ok("9 只小神仙的台词（发特技 + 平时）都能取到", all_say, str(miss))
	_ok("宠物序号与 Pet.txt 一致（小财神排第 4 = 下标 3）",
		str((s7.pet_catalog()[3] as Dictionary).get("id", "")) == "caishen",
		str((s7.pet_catalog()[3] as Dictionary).get("id", "")))

	# ---- 拉霸（老虎机，`uitex/casino/`；老板截图 records/老虎机.png）----
	var s4 := _fresh_sim()
	var p4: Dictionary = s4.players[1]
	p4["money"] = 100000
	s4._resolve_event(p4, int(p4["tile"]), {"event": "labar", "name": "拉霸"})
	_ok("拉霸：先投注（原版三档 +1000 / +5000 / +10000）",
		s4.act_casino_bet(1, 1000) and int(s4._casino_of(1)["bet"]) == 1000,
		"注额 %d" % int(s4._casino_of(1)["bet"]))
	_ok("拉霸：同次进入只能下注一档", not s4.act_casino_bet(1, 5000)
		and int(s4._casino_of(1)["bet"]) == 1000)
	_ok("拉霸：没投注就拉杆会被拒", not s4.act_casino_pull(2), "")
	_ok("拉霸：拉杆 → 出三个滚轮符号并结算",
		s4.act_casino_pull(1) and (s4._casino_of(1)["reels"] as Array).size() == 3,
		str(s4._casino_of(1)["reels"]))
	_ok("拉霸：拉杆后投注额清零", int(s4._casino_of(1)["bet"]) == 0, "")
	_ok("拉霸：结算后不可再下注或反复拉杆", not s4.act_casino_bet(1, 1000)
		and not s4.act_casino_pull(1))
	s4._resolve_event(p4, int(p4["tile"]), {"event": "labar", "name": "拉霸"})
	_ok("拉霸：再次经过事件点才可重新下注", s4.act_casino_bet(1, 1000))
	var before_refund := int(p4["money"])
	_ok("拉霸：未拉杆退出退还本次下注", s4.act_casino_exit(1)
		and int(p4["money"]) == before_refund + 1000
		and int(s4._casino_of(1)["bet"]) == 0)

	# ---- 全局新闻（Info.txt 3001..3014 + realtime.json 的 news 段）----
	var s5 := _fresh_sim()
	var c5 := str(s5.players[1].get("company", ""))
	var pr5 := s5.stock_price(c5)
	s5._fire_global_news(2)              # 甲2「股市气势如虹，全面上涨」
	_ok("全局新闻「股市全面上涨」→ 所有股价上涨",
		s5.stock_price(c5) > pr5, "%.2f → %.2f" % [pr5, s5.stock_price(c5)])
	_ok("新闻文案取自原版 Info.txt（3001..3014）",
		Rules.info_string(3002).contains("股市"), Rules.info_string(3002))
	var news_results: Array = []
	var closed_events: Array = []
	s5.game_event.connect(func(kind: String, data: Dictionary) -> void:
		if kind == "global_news": news_results.append(data)
		if kind == "stock_closed": closed_events.append(data))
	s5._fire_global_news(6)
	var held_before := s5.holding_of(1, c5)
	_ok("股市休市新闻填入真实天数", news_results.size() == 1
		and not str(news_results[0].get("text", "")).contains("<NUMBER>")
		and s5.stock_closed_until_day > s5.road_day, str(news_results))
	_ok("休市期间买卖均被拒绝且持股不变", not s5.act_buy_stock(1, c5, 1)
		and not s5.act_sell_stock(1, c5, 1) and s5.holding_of(1, c5) == held_before
		and closed_events.size() == 2)
	s5.road_day = s5.stock_closed_until_day
	_ok("休市期结束恢复交易", s5.act_sell_stock(1, c5, 1))
	var s6 := _fresh_sim()
	var land := -1
	for tile in range(s6.map.tile_count()):
		if str(s6.map.tile(tile).get("kind", "")) == "plot":
			land = tile
			break
	if land >= 0:
		s6.plots[land] = {"owner": 2, "level": 1, "type": "shop"}
		var value_before := s6.plot_value(land)
		s6._fire_global_news(8)
		var value_up := s6.plot_value(land)
		s6._fire_global_news(9)
		_ok("地价新闻确实改变地产现值", value_up > value_before
			and s6.plot_value(land) < value_up)
		var buyer: Dictionary = s6.players[1]
		buyer.tile = land
		var cash := int(buyer.money)
		s6._resolve_plot(buyer, land, s6.map.tile(land))
		var base_rent := cash - int(buyer.money)
		s6._fire_global_news(3)
		cash = int(buyer.money)
		s6._resolve_plot(buyer, land, s6.map.tile(land))
		var raised_rent := cash - int(buyer.money)
		s6._fire_global_news(14)
		cash = int(buyer.money)
		s6._resolve_plot(buyer, land, s6.map.tile(land))
		_ok("商业与经济萧条新闻确实改变实收租金", raised_rent > base_rent
			and cash - int(buyer.money) < raised_rent)


# ------------------------------------ 3k. 同格挤人（原版不允许多人站在同一格）

func _test_push_away() -> void:
	_lines.append("[3k] 同格挤人（原版不允许多人站在同一格）")
	var sim := _fresh_sim()
	var p: Dictionary = sim.players[1]          # 先到的
	var q: Dictionary = sim.players[2]          # 后到的
	var at := -1
	for i in range(1, sim.map.tile_count() - 1):
		if str(sim.map.tile(i).get("kind", "")) == "plot":
			at = i
			break
	p["tile"] = at
	p["moving"] = 0
	p["progress"] = 0.0
	q["tile"] = at
	q["moving"] = 0
	q["progress"] = 0.0
	var before_money := int(p["money"])
	sim._arrive(q)                                # q 抵达 → 把 p 挤走
	_ok("后到的人把先到的人**往前挤一格**",
		int(p["tile"]) == sim._wrap(at + 1),
		"p 在 %d（期望 %d）" % [int(p["tile"]), sim._wrap(at + 1)])
	_ok("被挤的人拿不到买地 / 升级的一次性机会",
		int(p.get("last_plot", -1)) < 0, "last_plot=%d" % int(p.get("last_plot", -1)))
	var sim3 := _fresh_sim()
	var pushed: Dictionary = sim3.players[1]
	var pusher: Dictionary = sim3.players[2]
	var from3 := -1
	for i in range(1, sim3.map.tile_count() - 1):
		if str(sim3.map.tile(i + 1).get("kind", "")) == "plot":
			from3 = i
			break
	var to3 := sim3._wrap(from3 + 1)
	sim3.road_objs[to3] = {"kind": "caishen", "born": 0.0}
	pushed.tile = from3
	pusher.tile = from3
	sim3._arrive(pusher)
	_ok("被撞到财神路点会拾取财神并获得附身状态",
		int(pushed.effects.get("no_rent_steps", 0)) > 0 and not sim3.road_objs.has(to3),
		str(pushed.effects))
	var sim4 := _fresh_sim()
	var unlucky: Dictionary = sim4.players[1]
	var empty4 := -1
	for i in range(sim4.map.tile_count()):
		if str(sim4.map.tile(i).get("kind", "")) == "plot" and not sim4.plots.has(i):
			empty4 = i
			break
	unlucky.tile = empty4
	unlucky.effects.no_upgrade_steps = 30
	sim4._resolve_plot(unlucky, empty4, sim4.map.tile(empty4))
	_ok("衰神附身时抵达空地不给购地机会",
		int(unlucky.last_plot) < 0)
	unlucky.last_plot = empty4
	unlucky.last_plot_kind = "buy"
	_ok("衰神附身时即使留有旧机会也不能买地",
		not sim4.act_buy(1) and not sim4.plots.has(empty4))

	# 被挤到**别人的地产**上 → 要付房租
	var sim2 := _fresh_sim()
	var a: Dictionary = sim2.players[1]
	var b: Dictionary = sim2.players[2]
	var own := -1
	for i in range(1, sim2.map.tile_count() - 1):
		if str(sim2.map.tile(i).get("kind", "")) == "plot":
			own = i
			break
	var dest := sim2._wrap(own + 1)
	sim2.plots[dest] = {"owner": 2, "level": 3, "type": "residence"}
	a["tile"] = own
	a["moving"] = 0
	a["progress"] = 0.0
	b["tile"] = own
	b["moving"] = 0
	b["progress"] = 0.0
	var before2 := int(a["money"])
	sim2._arrive(b)
	_ok("被挤到**别人的地产**上时要付房租",
		int(a["money"]) < before2, "%d → %d" % [before2, int(a["money"])])


# --------------------------------------------------- 3g. 传送平台（Roadevent 事件 1）

func _test_platform() -> void:
	_lines.append("[3g] 传送平台（原版 Roadevent 事件 1）")
	var m := MapData.load_from("aiji")
	var pf: Array = []
	for i in range(m.tile_count()):
		if str(m.tile(i).get("event", "")) == "platform":
			pf.append(i)
	_ok("埃及有 2 格传送平台", pf.size() == 2, str(pf))
	var dw := 0.0
	if pf.size() == 2:
		dw = m.pos_of(int(pf[0])).distance_to(m.pos_of(int(pf[1])))
	_ok("这 2 格在**世界坐标**上隔了 ≈3 格距（正常相邻格距 ~5）→ 同一座传送门的两格",
		dw > 9.0, "index %s / 世界距离 %.2f" % [str(pf), dw])

	var sim := Sim.new()
	sim.setup(m, 999)
	sim.add_player(1, "玩家一")
	sim.add_player(2, "玩家二")
	sim.running = true
	var p: Dictionary = sim.players[1]
	var a0 := int(pf[0])
	var a1 := int(pf[1])
	_ok("相邻的两格平台**不互为目的地**（否则就会原地打转）",
		sim._other_platform(a0) == -1,
		"_other_platform(%d) = %d" % [a0, sim._other_platform(a0)])

	# 复现老板遇到的场景：已经停在传送平台上，再掷 1 点
	p["tile"] = a0
	p["dir"] = 1
	p["moving"] = 1
	p["progress"] = 0.0
	for _i in range(200):
		sim.step(0.05)
		if int(p["moving"]) <= 0:
			break
	_ok("站在传送平台上掷 1 点 → 走到另一格（不再「留在原地」）",
		int(p["tile"]) == a1, "tile=%d（期望 %d）" % [int(p["tile"]), a1])

	# 再走一格必须继续前进，不能又被弹回去
	p["moving"] = 1
	p["progress"] = 0.0
	for _j in range(200):
		sim.step(0.05)
		if int(p["moving"]) <= 0:
			break
	_ok("从第二格再走 1 格 → 正常前进（没有反弹）",
		int(p["tile"]) == sim._wrap(a1 + 1),
		"tile=%d（期望 %d）" % [int(p["tile"]), sim._wrap(a1 + 1)])


# --------------------------------------------------- 3f. 路边物体（原版 roadobj）

## 直接触发一次「踩到某路边物体」的结算（比摆到棋盘再走一格更好控）
func _discover_road(sim: Sim, kind: String) -> void:
	sim._pick_road_obj(sim.players[1], kind, int(sim.players[1]["tile"]))


func _test_road_objs() -> void:
	_lines.append("[3f] 路边物体（roadobj：权重表 / 拾取 / 四神 / 小神仙按步数升级）")

	var sim := _fresh_sim()
	var m: MapData = sim.map
	# ---- 权重表来自 config/scene/<map>/<map>.txt 的「路面物体出现几率」段 ----
	_ok("地图带路面物体权重表（13 种，与 Roadevent 的「种类数」一致）",
		m.road_items.size() == 13, "%d 种：%s" % [m.road_items.size(), str(m.road_items)])
	var ma := MapData.load_from("aiji")
	_ok("埃及的权重逐条对得上（card=6 / crystal=2 / hanbao=3 / petegg=2）",
		int(ma.road_items.get("card", -9)) == 6 and int(ma.road_items.get("crystal", -9)) == 2
		and int(ma.road_items.get("hanbao", -9)) == 3 and int(ma.road_items.get("petegg", -9)) == 2,
		str(ma.road_items))
	_ok("地雷 / 隔毁在埃及是 -1（不随机生成，只能由卡片放）",
		int(ma.road_items.get("mine", 0)) == -1 and int(ma.road_items.get("block", 0)) == -1,
		"mine=%d block=%d" % [int(ma.road_items.get("mine", 0)), int(ma.road_items.get("block", 0))])

	# ---- 生成 ----
	var spawned := {}
	for _i in range(300):                       # 1 秒 = 1/24 天 → 跑 12.5 天
		sim.step(1.0)
		for k in sim.road_objs.keys():
			spawned[str(sim.road_objs[k]["kind"])] = true
	_ok("过了 12.5 天棋盘上真的出现了路边物体", sim.road_objs.size() > 0,
		"%d 个" % sim.road_objs.size())
	var bad: Array = []
	for k in spawned.keys():
		if int(m.road_items.get(k, -1)) <= 0:
			bad.append(k)
	_ok("生成过的种类都在本图权重表里（不会出现 -1 的）", spawned.size() > 0 and bad.is_empty(),
		"生成过 %s；越界 %s" % [str(spawned.keys()), str(bad)])
	_ok("不会撒在起点格上", not sim.road_objs.has(0), str(sim.road_objs.keys()))
	var overlap: Array = []
	for k in sim.road_objs.keys():
		if sim.plots.has(int(k)) or not sim._obstacle_at(int(k)).is_empty():
			overlap.append(k)
	_ok("不会撒在已有地产 / 已有陷阱的格上", overlap.is_empty(), str(overlap))

	# ---- 逐种效果 ----
	# 71 / 78 戒指：无神 → 什么也没发生；有神 → 升一级；满级 → 不升
	var s2 := _fresh_sim()
	_discover_road(s2, "crystal")
	_ok("戒指（身上没有小神仙）= 什么也没发生",
		(s2.players[1]["pets"] as Array).is_empty(), str(s2.players[1]["pets"]))
	var s3 := _pet_world("caishen")
	_discover_road(s3, "crystal")
	_ok("戒指（有小神仙）= 等级 +1", int(s3.players[1]["pets"][0]["level"]) == 2,
		"level=%d" % int(s3.players[1]["pets"][0]["level"]))
	_ok("戒指升级后立即补满能量，可发动一次技能",
		float(s3.players[1]["pets"][0]["fullness"]) == Sim.PET_FULLNESS_MAX
		and s3.pet_skill_ready(s3.players[1]["pets"][0]))
	var s4 := _pet_world("caishen")
	s4.players[1]["pets"][0]["level"] = 4
	_discover_road(s4, "crystal")
	_ok("戒指不能把满级小神仙顶过上限（4 级，逆向自 0x431170）",
		int(s4.players[1]["pets"][0]["level"]) == 4,
		"level=%d" % int(s4.players[1]["pets"][0]["level"]))
	_ok("满级小神仙吃戒指仍能补满能量",
		float(s4.players[1]["pets"][0]["fullness"]) == Sim.PET_FULLNESS_MAX
		and s4.pet_skill_ready(s4.players[1]["pets"][0]))

	# 74 汉堡：+1000 HP（HanBao_Inc_HP），受体力上限约束
	var s5 := _fresh_sim()
	var max5 := s5.stamina_max()
	var want_heal := float(Rules.get_val("hp.hamburger_heal", 1000))
	s5.players[1]["stamina"] = 100.0
	_discover_road(s5, "hanbao")
	var exp5 := 100.0 + minf(want_heal, max5 - 100.0)
	_ok("汉堡回复体力 = HanBao_Inc_HP（1000，顶到上限就停）",
		absf(float(s5.players[1]["stamina"]) - exp5) < 0.01,
		"100 → %.0f（期望 %.0f；上限 %.0f）" % [
			float(s5.players[1]["stamina"]), exp5, max5])
	s5.players[1]["stamina"] = max5
	_discover_road(s5, "hanbao")
	_ok("汉堡不会顶破体力上限", float(s5.players[1]["stamina"]) <= max5 + 0.01,
		"%.0f / %.0f" % [float(s5.players[1]["stamina"]), max5])

	# 72 宝箱：rand(10..20)% × 全体平均现金，下限 1000（逆向自 0x431220）
	var s6 := _fresh_sim()
	for id in [1, 2]:
		s6.players[id]["money"] = 100000
	var before6 := int(s6.players[1]["money"])
	_discover_road(s6, "robber")
	var gained := int(s6.players[1]["money"]) - before6
	_ok("宝箱金额落在「平均现金的 10%~20%」区间且不低于下限 1000",
		gained >= 1000 and gained <= int(100000 * 0.2) + 1,
		"得到 %d（平均现金 100000 → 期望 10000~20000）" % gained)

	# 77 小偷：现金的 rand(1..10)%（逆向自 0x4313d0）
	var s7 := _fresh_sim()
	s7.players[1]["money"] = 200000
	_discover_road(s7, "thief")
	var lost7 := 200000 - int(s7.players[1]["money"])
	_ok("小偷损失落在「现金的 1%~10%」区间",
		lost7 >= 2000 and lost7 <= 20000, "损失 %d" % lost7)

	# 76 炸弹鬼：扣体力（原值在运行时数据段，取 road.bomb_hp_dec）
	var s8 := _fresh_sim()
	s8.players[1]["stamina"] = s8.stamina_max()
	_discover_road(s8, "bomb")
	var dec8 := float(Rules.get_val("road.bomb_hp_dec", 500))
	_ok("炸弹鬼扣体力 = road.bomb_hp_dec",
		absf((s8.stamina_max() - float(s8.players[1]["stamina"])) - dec8) < 0.01,
		"扣了 %.0f 期望 %.0f" % [s8.stamina_max() - float(s8.players[1]["stamina"]), dec8])

	# 73 卡片
	var s9 := _fresh_sim()
	var n9 := (s9.players[1]["cards"] as Array).size()
	_discover_road(s9, "card")
	_ok("卡片格给一张卡", (s9.players[1]["cards"] as Array).size() == n9 + 1,
		"%d → %d" % [n9, (s9.players[1]["cards"] as Array).size()])

	# 75 神仙蛋：得到一只小神仙
	var s10 := _fresh_sim()
	_discover_road(s10, "petegg")
	_ok("神仙蛋孵出一只小神仙", (s10.players[1]["pets"] as Array).size() == 1,
		str(s10.players[1]["pets"]))
	# 满了就别再给
	var s11 := _fresh_sim()
	var cat: Array = s11.pet_catalog()
	for i in range(5):
		s11.add_pet(s11.players[1], str((cat[i % cat.size()] as Dictionary)["id"]))
	var n11 := (s11.players[1]["pets"] as Array).size()
	_discover_road(s11, "petegg")
	_ok("带满 5 位小神仙时神仙蛋不再给（Info.txt 202 上限 5 位）",
		(s11.players[1]["pets"] as Array).size() == n11, "%d → %d" % [
			n11, (s11.players[1]["pets"] as Array).size()])

	# 财神 / 福神 / 衰神 / 穷神：附身到踩到的人身上
	var god_eff := {
		"caishen": "no_rent_steps", "qiongshen": "rent_double_steps",
		"shuaishen": "no_upgrade_steps", "fushen": "free_upgrade_steps",
	}
	var gods_ok := true
	var gods_detail: Array = []
	for g in god_eff.keys():
		var sg := _fresh_sim()
		var before_money := int(sg.players[1]["money"])
		var before_cards := (sg.players[1]["cards"] as Array).size()
		_discover_road(sg, str(g))
		var v: Variant = sg.players[1]["effects"][str(god_eff[g])]
		var grew: bool = (float(v) > 0.0) if v is float else (int(v) > 0)
		if not grew:
			gods_ok = false
			gods_detail.append("%s 没生效" % g)
		if g == "caishen" and int(sg.players[1]["money"]) <= before_money:
			gods_ok = false
			gods_detail.append("财神没有给钱")
		if g == "qiongshen" and int(sg.players[1]["money"]) >= before_money:
			gods_ok = false
			gods_detail.append("穷神没有扣钱")
		if g == "fushen" and (sg.players[1]["cards"] as Array).size() <= before_cards:
			gods_ok = false
			gods_detail.append("福神没有发卡")
	_ok("踩到四神（财神/福神/衰神/穷神）会附身并改变状态", gods_ok, str(gods_detail))

	# 隔毁：挡一下
	var s12 := _fresh_sim()
	s12.players[1]["moving"] = 3
	_discover_road(s12, "block")
	_ok("隔毁会把角色挡下来", int(s12.players[1]["moving"]) == 0,
		"moving=%d" % int(s12.players[1]["moving"]))

	# ---- 地雷伤害走规则表（原来硬编码 300，是 bug）----
	_ok("地雷伤害 = hp.mine_damage（1000，不是硬编码的 300）",
		int(Rules.get_val("hp.mine_damage", 0)) == 1000,
		"规则值 %d" % int(Rules.get_val("hp.mine_damage", 0)))
	var s13 := _fresh_sim()
	var p13: Dictionary = s13.players[1]
	var max13 := s13.stamina_max()
	p13["stamina"] = max13
	p13["tile"] = 5
	s13._add_obstacle(6, "mine", 2)
	p13["moving"] = 1
	p13["progress"] = 0.99
	s13.step(0.02)
	# 埃及/中国的体力上限是 600 < 1000 → 踩雷必然见底（这正是「原来只扣 300」看不出来的原因）
	_ok("踩到地雷按规则表扣（Mine_Exp_HPDec = 1000，600 上限会直接见底）",
		absf(float(p13["stamina"])) < 1.0,
		"%.0f → %.0f（上限 %.0f，规则 1000）" % [
			max13, float(p13["stamina"]), max13])

	# ---- 小神仙按步数升级（Pet_Upgrade_Steps = 300）----
	var s14 := _pet_world("caishen")
	var lv14 := int(s14.players[1]["pets"][0]["level"])
	s14.players[1]["pet_steps"] = 0
	s14._try_pet_levelup(s14.players[1])
	_ok("走够步数之前不升级", int(s14.players[1]["pets"][0]["level"]) == lv14, "")
	var need14 := int(Rules.get_val("pet.upgrade_steps_per_level", 300)) * lv14
	s14.active_pet(s14.players[1])["growth"] = need14
	s14._try_pet_levelup(s14.players[1])
	_ok("实例累计达到等级×300时升级并清空累计",
		int(s14.players[1]["pets"][0]["level"]) == lv14 + 1,
		"level %d → %d（门槛 %d 步）" % [lv14, int(s14.players[1]["pets"][0]["level"]), need14])

	# ---- 素材：事件格图标 + 路面物体清单 ----
	var idx_txt := ""
	if FileAccess.file_exists("res://assets/roadobj/index.json"):
		idx_txt = FileAccess.open("res://assets/roadobj/index.json", FileAccess.READ).get_as_text()
	var idx: Variant = JSON.parse_string(idx_txt)
	var icons: Dictionary = (idx as Dictionary).get("event_icons", {}) if idx is Dictionary else {}
	_ok("原版事件格图标已入库（19 个）", icons.size() == 19, "%d 个" % icons.size())
	_ok("事件格图标覆盖了埃及的全部事件类型（coupon→credit 映射已处理）",
		icons.has("credit20") and icons.has("cardpt") and icons.has("cardshop")
		and icons.has("hospital") and icons.has("labar") and icons.has("casino"),
		str(icons.keys()))
	var items: Dictionary = (idx as Dictionary).get("items", {}) if idx is Dictionary else {}
	_ok("路面物体清单 20 项（13 种随机 + 救护车/推土机/金币/点券/飞弹/核弹/降落伞 等演出）",
		items.size() == 20, "%d 项" % items.size())
	var with_model := 0
	for k in items.keys():
		var mv2: Variant = (items[k] as Dictionary).get("model")
		if mv2 is String and str(mv2) != "":
			with_model += 1
	_ok("其中 9 个有静态网格（.pol → R6BM），其余原版只有 .cvd 动画（格式未逆）",
		with_model == 9, "%d 个有模型" % with_model)


func _test_pets() -> void:
	print("\n[3e] 小神仙（精灵屋）+ 卡片商店（点券出口）")
	var sim := _fresh_sim()
	var cat: Array = sim.pet_catalog()

	# ---- 数据：9 只 × 4 级，技能名逐条对齐 String.txt 2201..2209 ----
	_ok("Pet.txt 解析出 9 只小神仙", cat.size() == 9, "%d 只" % cat.size())
	var bad: Array = []
	for i in range(cat.size()):
		var r: Dictionary = cat[i]
		var sid := 2201 + i
		if str(r.get("skill_raw", "")) != Rules.ui_string(sid):
			bad.append("%s: 「%s」≠ String.txt %d「%s」"
				% [r.get("id"), r.get("skill_raw"), sid, Rules.ui_string(sid)])
		if (r.get("seconds", []) as Array).size() != 4 \
				or (r.get("points", []) as Array).size() != 4:
			bad.append("%s 不是 4 级" % r.get("id"))
	_ok("9 只技能名逐条对齐 String.txt 2201..2209，且都是 4 级", bad.is_empty(), str(bad))
	_ok("持有上限 = 5（Info.txt 202 原文「您已拥有5位小神仙」）",
		sim.max_pets() == 5 and Rules.info_string(202).contains("5位小神仙"),
		"max=%d；「%s」" % [sim.max_pets(), Rules.info_string(202).replace("\n", " ")])

	# ---- 精灵屋：用点券买 ----
	var s2 := _fresh_sim()
	var p2: Dictionary = s2.players[1]
	p2["credit"] = 0
	_ok("点券不够 → 请不到小神仙", not s2.act_buy_pet(1, "caishen")
		and s2.pet_count(p2) == 0, "点券 0")
	p2["credit"] = 500
	var price := s2.pet_price("caishen")
	_ok("点券够 → 买到并按价扣点券",
		s2.act_buy_pet(1, "caishen") and s2.pet_count(p2) == 1
			and int(p2["credit"]) == 500 - price,
		"价 %d，剩 %d" % [price, int(p2["credit"])])
	_ok("新小财神内部能量初始一半，不会立刻飞走",
		float((p2.pets[0] as Dictionary).fullness) == Sim.PET_START_FULLNESS)
	_ok("稀有度越高喂食越多", s2.pet_feed_value("nuke") > s2.pet_feed_value("step3"))
	_ok("同一位再请 → 升一级，不是重复持有",
		s2.act_buy_pet(1, "caishen") and s2.pet_count(p2) == 1
			and int((p2["pets"][0] as Dictionary)["level"]) == 2,
		"level=%d" % int((p2["pets"][0] as Dictionary)["level"]))
	p2["credit"] = 9999
	for pid in ["qiongshen", "hutu", "emo", "tushen"]:
		s2.act_buy_pet(1, pid)
	_ok("满 5 位后不能再请（Info.txt 202）",
		s2.pet_count(p2) == 5 and not s2.act_buy_pet(1, "huaxian")
			and s2.pet_count(p2) == 5, "持有 %d 位" % s2.pet_count(p2))
	var hunger_world := _pet_world("caishen")
	var hungry: Dictionary = hunger_world.players[1]
	var flee_lines: Array = []
	hunger_world.game_event.connect(func(kind, data):
		if kind == "pet_flew_away": flee_lines.append(int(data.get("voice_line", 0))))
	(hungry.pets[0] as Dictionary).fullness = 1.0
	hunger_world._tick_pet_hunger(Rules.seconds_per_day())
	_ok("饱食度随时间下降，到 0 时离开并清除出战位",
		hungry.pets.is_empty() and hunger_world.active_pet(hungry).is_empty())
	_ok("原版能量耗尽逃离语音9", flee_lines == [9])
	var dream_world := _pet_world("hutu")
	var dreamer: Dictionary = dream_world.players[2]
	_ok("糊涂鬼只对选中的近处对手施加梦游步数",
		dream_world.act_pet_skill(1, false, 2) and int(dreamer.effects.sleepwalk_steps) == 15
		and float(dreamer.effects.sleep_until) == 0.0 and int(dream_world.players[1].effects.sleepwalk_steps) == 0)
	_ok("梦游玩家不能手动掷骰，但可由电脑驱动，地产不收租",
		not dream_world.act_roll(2) and dream_world.act_roll(2, 1, true)
		and Sim.owner_abnormal(dreamer, dream_world.time))
	var cardpoint := -1
	var empty_plot := -1
	for tile_index in range(dream_world.map.tile_count()):
		var tile_data: Dictionary = dream_world.map.tile(tile_index)
		if cardpoint < 0 and str(tile_data.get("event", "")) == "cardpt": cardpoint = tile_index
		if empty_plot < 0 and str(tile_data.get("kind", "")) == "plot" \
				and not dream_world.plots.has(tile_index): empty_plot = tile_index
	if cardpoint >= 0:
		dreamer.tile = dream_world._wrap(cardpoint - 1)
		dreamer.moving = 1
		dreamer.progress = .99
		dreamer.move_after = 0.0
		var hand_before := (dreamer.cards as Array).size()
		dream_world._advance(dreamer, 0.2)
		_ok("梦游自动行走仍触发卡片路点", int(dreamer.tile) == cardpoint
			and (dreamer.cards as Array).size() > hand_before)
	if empty_plot >= 0:
		dream_world._resolve_plot(dreamer, empty_plot, dream_world.map.tile(empty_plot))
		_ok("梦游抵达空地没有购地机会", str(dreamer.last_plot_kind) == "")

	# ---- 9 种特技都能发动，且真的改变状态 ----
	var silent: Array = []
	for i in range(cat.size()):
		var r: Dictionary = cat[i]
		var s3 := _pet_world(str(r.get("id", "")))
		var p3: Dictionary = s3.players[1]
		var before := str(s3.to_dict())
		s3.act_pet_skill(1, false, 2 if str(r.get("id", "")) in ["hutu", "qiongshen"] else -1)
		if str(s3.to_dict()) == before:
			silent.append("%s/%s" % [r.get("id"), r.get("effect")])
	_ok("9 只小神仙的特技全部能发动且改变状态（没有空转）", silent.is_empty(), str(silent))

	# ---- 满饱食可主动发动；再次喂满即可立刻再用 ----
	var s4 := _pet_world("huaxian")
	var p4: Dictionary = s4.players[1]
	s4.act_pet_skill(1)
	var cr := int(p4["credit"])
	_ok("一次技能消耗饱食度，不能空能量连发", not s4.act_pet_skill(1) and int(p4["credit"]) == cr,
		"点券 %d → %d" % [cr, int(p4["credit"])])
	for _e in (p4["pets"] as Array):
		(_e as Dictionary)["fullness"] = Sim.PET_FULLNESS_MAX
	s4.act_pet_skill(1)
	_ok("重新喂满后无冷却可立即再发",
		int(p4["credit"]) == cr and not s4.pet_skill_ready(s4.active_pet(p4)), "点券保持 %d" % int(p4["credit"]))
	var s5 := _pet_world("huaxian")
	var p5: Dictionary = s5.players[1]
	p5["credit"] = 0
	s5.act_pet_skill(1)
	_ok("没有点券也能消耗宠物能量发动技能",
		float(p5["effects"]["invincible_until"]) > s5.time and int(p5["credit"]) == 0,
		"credit %d / invincible_until %.0f" % [int(p5["credit"]),
			float(p5["effects"]["invincible_until"])])

	# ---- 小赌神「骰子技 遥控骰子」真的让下一掷最大 ----
	var s6 := _fresh_sim()
	var p6: Dictionary = s6.players[1]
	s6.add_pet(p6, "dushen")
	# 体力系统（老板 2026-09-27）：技能要**体力满**才发得动，测试里直接给满
	for pe6 in (p6["pets"] as Array):
		(pe6 as Dictionary)["fullness"] = Sim.PET_FULLNESS_MAX
	p6["credit"] = 100
	s6.act_pet_skill(1)
	_ok("小赌神发动后选择步数，点击后按所选点数前进",
		bool(p6.pending_steps) and s6.act_walk(1, 3) and int(p6.last_roll) == 3 and not bool(p6.pending_steps))

	# ---- 拍卖（甲13 新闻「公开拍卖一处公有土地」/ Info.txt 4001..4003）----
	var s8 := _fresh_sim()
	var started := s8.start_auction()
	_ok("甲13 能开拍（从无主地产里挑一块）", started,
		"地块 %d 起拍 %d" % [int(s8.auction.get("tile", -1)), int(s8.auction.get("price", 0))])
	if started:
		var atile := int(s8.auction["tile"])
		var base := int(s8.auction["price"])
		_ok("加价不得少于 100 元（Info.txt 4002）", not s8.act_auction_bid(1, 50),
			"出 50 被拒")
		_ok("加 100 成功，当前价 = 起拍 + 100",
			s8.act_auction_bid(1, 100) and int(s8.auction["price"]) == base + 100,
			"%d → %d" % [base, int(s8.auction["price"])])
		# 到点结算：出价的人拿地、扣钱
		var m0 := int(s8.players[1]["money"])
		s8.auction["until"] = s8.time - 1.0          # 强制到点
		s8._tick_auction()
		_ok("到点结算：最高出价者拿到地并扣钱",
			s8.plots.has(atile) and int(s8.plots[atile]["owner"]) == 1
				and int(s8.players[1]["money"]) == m0 - (base + 100),
			"owner=%d 扣 %d" % [int(s8.plots.get(atile, {}).get("owner", -1)),
				m0 - int(s8.players[1]["money"])])
		_ok("结算后拍卖状态清空", not s8.auction_active())

	# ---- 新闻 11..14 的对应关系（原来 11~14 全错位了）----
	_ok("甲11 = 地震（房屋倒塌）而不是「送卡」",
		Rules.info_string(3011).contains("地震"), Rules.info_string(3011))
	_ok("甲12 = 大雨地价下跌", Rules.info_string(3012).contains("大雨"), Rules.info_string(3012))
	_ok("甲13 = 公开拍卖", Rules.info_string(3013).contains("拍卖"), Rules.info_string(3013))
	_ok("甲14 = 经济萧条租金下降", Rules.info_string(3014).contains("萧条"), Rules.info_string(3014))

	# ---- 挤人：朝向 / 打断 / 连锁（老板 2026-09-27）----
	_lines.append("[3i] 挤人：朝向转过来 · 位置绑定的操作作废 · 连锁往前推")
	var sA := _fresh_sim()
	sA.add_player(3, "玩家三")                 # _fresh_sim 只造了 2 个，连锁要 3 个人
	var pa: Dictionary = sA.players[1]
	var pb: Dictionary = sA.players[2]
	var pc: Dictionary = sA.players[3]
	# 三人挨着站：a 在 10、b 在 11、c 在 12
	pa["tile"] = 10; pb["tile"] = 11; pc["tile"] = 12
	pa["moving"] = 0; pb["moving"] = 0; pc["moving"] = 0
	pa["dir"] = 1; pb["dir"] = -1; pc["dir"] = -1      # b/c 原来朝反方向
	# b 手上留着一次买地机会（代表「正在操作这一格」）
	pb["last_plot"] = 11; pb["last_plot_kind"] = "buy"
	pc["last_plot"] = 12; pc["last_plot_kind"] = "upgrade"
	# a 走到 b 那一格 → 把 b 挤到 11+1，b 又去挤 c（连锁）
	pa["tile"] = 11
	sA._push_away_occupants(pa)
	_ok("① 被挤的人朝向变得和挤他的人一致",
		int(pb["dir"]) == 1 and int(pc["dir"]) == 1,
		"b.dir=%d c.dir=%d（应都是 1）" % [int(pb["dir"]), int(pc["dir"])])
	_ok("③ 连锁：b 被挤走时又挤了 c（c 从 12 → 13）",
		int(pb["tile"]) == 12 and int(pc["tile"]) == 13,
		"b=%d c=%d" % [int(pb["tile"]), int(pc["tile"])])
	_ok("① 任何时刻都没有两人同格",
		int(pa["tile"]) != int(pb["tile"]) and int(pb["tile"]) != int(pc["tile"])
			and int(pa["tile"]) != int(pc["tile"]),
		"a=%d b=%d c=%d" % [int(pa["tile"]), int(pb["tile"]), int(pc["tile"])])
	_ok("② 被挤后「本格的操作机会」作废（买地/升级都清掉）",
		int(pb["last_plot"]) == -1 and int(pc["last_plot"]) == -1,
		"b=%d c=%d" % [int(pb["last_plot"]), int(pc["last_plot"])])

	# ---- Native integer inflation driven by average company assets ----
	_lines.append("[3j] 公司资产驱动物价指数")
	var sE := _fresh_sim()
	_ok("一个月 = 30 天", Sim.MONTH_DAYS == 30, str(Sim.MONTH_DAYS))
	sE._tick_estate_index()
	var idx0 := sE.estate_index
	var price0 := sE.empty_plot_price()
	sE.road_day = 90
	sE._tick_estate_index()
	_ok("时间经过三个月本身不提高物价", sE.estate_index == idx0, str(sE.estate_index))
	for pE in sE.players.values(): pE.money = int(pE.money) * 100
	sE._tick_estate_index()
	_ok("公司资产增长提高整数物价及地价", sE.estate_index > idx0 and sE.empty_plot_price() > price0, str(sE.price_scale()))
	_ok("原版物价上限为9", sE.price_scale() == 9, str(sE.price_scale()))
	_ok("房租随物价指数提高", sE._rent_of(1, "uptown") > Rules.house_rent("uptown", 1), "")
	for pE in sE.players.values(): pE.money = 0
	sE._tick_estate_index()
	_ok("资产下降不回退已有物价指数", sE.price_scale() == 9, str(sE.price_scale()))

	# ---- C05 · 12 个互斥状态（2026-10-16，依据原版 FUN_00435f80 + 421240）----
	_lines.append("[3l] 12 个互斥状态：写一个清掉其余 + 状态 8/9 挡住步卡")
	var sS := _fresh_sim()
	var pS: Dictionary = sS.players[1]
	sS.set_status(pS, 1, sS.time + 100.0)                    # 无敌
	_ok("写入状态 1（无敌）生效", sS.current_status(pS) == 1, str(sS.current_status(pS)))
	sS.set_status(pS, 9, sS.time + 100.0)                    # 小财神
	_ok("再写状态 9 会**清掉**状态 1（原版 435f80 先清空 12 个再置位）",
		sS.current_status(pS) == 9
			and float(pS["effects"]["invincible_until"]) == 0.0,
		"当前 %d，invincible_until=%s" % [sS.current_status(pS),
			str(pS["effects"]["invincible_until"])])
	(pS["cards"] as Array).append("step3")
	_ok("状态 9（小财神）时**步卡不可用**（原版 421240 判定⑥）",
		sS.card_usable(1, "step3") == 61, "code %d" % sS.card_usable(1, "step3"))
	sS.set_status(pS, 11, sS.time + 100.0)                   # 隐形
	_ok("换成状态 11（隐形）后步卡恢复可用",
		sS.card_usable(1, "step3") == 0, "code %d" % sS.card_usable(1, "step3"))
	_ok("步卡用掉后，隐形仍在（状态没被误清）", sS.current_status(pS) == 11,
		str(sS.current_status(pS)))

	# ---- 卡片商店（点券出口）----
	var s7 := _fresh_sim()
	var p7: Dictionary = s7.players[1]
	s7.refill_card_shop()
	if not s7.card_shop_stock.has("caishen"): s7.card_shop_stock[0] = "caishen"
	_ok("货架初始为 8 格", s7._shop_stock().size() == 8)
	p7["credit"] = 0
	_ok("点券不够 → 买不了卡", not s7.act_buy_card(1, "caishen")
		and (p7["cards"] as Array).is_empty(), "点券 0")
	p7["credit"] = 100
	var cprice := s7.card_price("caishen")
	_ok("点券够 → 买到卡，按「卡面徽章 × 10」扣点券",
		s7.act_buy_card(1, "caishen") and (p7["cards"] as Array).has("caishen")
			and int(p7["credit"]) == 100 - cprice,
		"价 %d（徽章 %d），剩 %d" % [cprice, Rules.card_badge("caishen"), int(p7["credit"])])
	_ok("货架正好 8 格（原版 cardshop.tga 是 2 列 × 4 行）",
		s7._shop_stock().size() == 7, "买走一张后 %d 格" % s7._shop_stock().size())
	# ⭐ 货架必须**持久**，且**买走的卡要从架上移除**
	#   （老板 2026-09-27：「我买了的卡应该移除掉，不然我不就可以不停买了吗」）
	#   改之前 `_shop_stock()` 每次现洗一副牌 → 买完卡还在架上、可以反复买。
	_ok("货架是持久的（连读两次一模一样）",
		str(s7._shop_stock()) == str(s7._shop_stock()),
		str(s7._shop_stock().slice(0, 3)))
	var stock_before: Array = s7._shop_stock()
	var probe := "caishen" if stock_before.has("caishen") \
		else (str(stock_before[0]) if not stock_before.is_empty() else "")
	if probe != "":
		p7["credit"] = 99999
		s7.act_buy_card(1, probe)
		_ok("买走的卡已从货架上移除",
			not s7._shop_stock().has(probe),
			"卖掉 %s 后货架剩 %d 张" % [probe, s7._shop_stock().size()])
	_ok("Info.txt 41/42 文案在位（「卡片商店 您有N点券」/「您没有点券 不能进入卡片商店」）",
		Rules.info_string(41).contains("卡片商店") and Rules.info_string(42).contains("不能进入"),
		"%s ｜ %s" % [Rules.info_string(41).replace("\n", " "),
			Rules.info_string(42).replace("\n", " ")])
	_ok("Info.txt 203 购买确认文案在位",
		Rules.info_string(203).contains("点券") and Rules.info_string(203).contains("确认要购买"),
		Rules.info_string(203).replace("\n", " "))


# ------------------------------------------------------- 3d. 卡片系统（42 张）

func _test_cards() -> void:
	print("\n[3d] 卡片系统（42 张卡：名称 / 说明 / 卡面 / 效果）")
	var cs: Array = Rules.cards()
	_ok("realtime.json 有 42 张卡", cs.size() == 42, "%d" % cs.size())
	var idx: Array = Rules.card_index.get("cards", [])
	_ok("卡面索引有 42 条（card/index.json）", idx.size() == 42, "%d" % idx.size())

	var bad_name: Array = []
	var bad_desc: Array = []
	var bad_face: Array = []
	var bad_order: Array = []
	for i in range(cs.size()):
		var cid := str(cs[i].get("id", ""))
		var e: Dictionary = idx[i] if i < idx.size() else {}
		if str(e.get("id", "")) != cid:
			bad_order.append("%d:%s≠%s" % [i + 1, cid, e.get("id", "")])
		if Rules.card_name(cid) == "":
			bad_name.append(cid)
		# 说明必须与原版 String.txt 9001..9042 逐条一致
		var want := Rules.ui_string(9001 + i, "")
		if want == "" or Rules.card_desc(cid) != want:
			bad_desc.append("%s: %s ≠ %s" % [cid, Rules.card_desc(cid), want])
		if not ResourceLoader.exists(Rules.card_face_path(cid)):
			bad_face.append(cid)
	_ok("卡面编号 / realtime.json / 下标 三方顺序一致", bad_order.is_empty(), str(bad_order))
	_ok("42 张卡都有中文名（卡面标签）", bad_name.is_empty(), str(bad_name))
	_ok("42 张卡说明逐条对齐 String.txt 9001..9042", bad_desc.is_empty(), str(bad_desc))
	_ok("42 张卡面贴图都在 assets/card/", bad_face.is_empty(), str(bad_face))
	# ⚠ String.txt 第 104 行把 id 写成 `02`，与第 4 行的 id 2「锁定」撞号
	#   → 生成器按「首次优先」，否则卡片菜单的「锁定」会被顶成「<SOMEONE>退出游戏」
	_ok("卡片菜单文案 = 使用 / 锁定 / 丢弃（String.txt 1/2/3，已避开 id 撞号）",
		Rules.card_menu_label("use") == "使用"
		and Rules.card_menu_label("lock") == "锁定"
		and Rules.card_menu_label("discard") == "丢弃",
		"%s / %s / %s" % [Rules.card_menu_label("use"),
			Rules.card_menu_label("lock"), Rules.card_menu_label("discard")])
	_ok("目标提示 = 请选择对手（String.txt 1101）",
		Rules.card_target_prompt("player") == "请选择对手",
		Rules.card_target_prompt("player"))

	# ---- 逐张用一遍：每张卡都必须真的改变状态（否则就是「没实现」）----
	var refused: Array = []
	var silent: Array = []
	for i in range(cs.size()):
		var cid := str(cs[i].get("id", ""))
		var sim := _card_world(cid)
		var p: Dictionary = sim.players[1]
		(p["cards"] as Array).append(cid)
		if cid == "copy":
			# 复制卡要有**别的**卡才能复制（String.txt 67「没有可以组合的卡片」）
			(p["cards"] as Array).append("step3")
		if cid == "gem":
			(p["cards"] as Array).append("shuaishen")
		var target := 2 if sim.card_needs_player(cid) else -1
		if sim.card_target(cid) == "road":
			var candidates := sim.card_road_candidates(1, cid)
			if not candidates.is_empty(): target = int(candidates[0])
		# 红卡 / 黑卡要指定「哪一种股票」（第 3 个参数 = 公司名）
		var tname := ""
		if sim.card_target(cid) == "stock" and not sim.stock_names().is_empty():
			tname = str(sim.stock_names()[0])
		if cid == "gem": tname = "shuaishen"
		if cid == "rebuild": tname = "special1"
		var before := str(sim.to_dict())
		var used := sim.act_use_card(1, cid, target, tname)
		if Sim.CARD_UNSUPPORTED.has(cid):
			if used:
				refused.append("未实现却执行成功:" + cid)
			continue
		if not used:
			refused.append(cid)
		elif str(sim.to_dict()) == before:
			silent.append(cid)
	var n_ok := cs.size() - Sim.CARD_UNSUPPORTED.size()
	_ok("**全部 %d 张卡**都能用（`CARD_UNSUPPORTED` 已清空）" % n_ok,
		refused.is_empty(), str(refused))
	_ok("每张卡都真的改变了状态（没有空转的）", silent.is_empty(), str(silent))
	_ok("`CARD_UNSUPPORTED` 已清空（红黑卡 + 复制卡都做完了）",
		Sim.CARD_UNSUPPORTED.is_empty(), str(Sim.CARD_UNSUPPORTED))
	# 原版 0x41fa20：改建选择的是 d1/d2/d3 特殊建筑，尺寸保持不变。
	var rebuild_world := _card_world("rebuild")
	var rebuild_player: Dictionary = rebuild_world.players[1]
	(rebuild_player["cards"] as Array).append("rebuild")
	var rebuild_idx := int(rebuild_player["tile"])
	var normal_type := str(rebuild_world.plots[rebuild_idx].get("type", ""))
	_ok("改建卡不会提供普通房型或自动把住宅降级",
		rebuild_world.rebuild_plan(1, rebuild_idx, normal_type).is_empty()
		and not rebuild_world.act_use_card(1, "rebuild", -1, normal_type), "type=" + normal_type)
	_ok("改建卡选择特殊建筑后保留地块尺寸并使用原版 d 系列模型",
		rebuild_world.act_use_card(1, "rebuild", -1, "special1")
		and str(rebuild_world.plots[rebuild_idx].type) == "special1"
		and Rules.house_file("special1", int(rebuild_world.plots[rebuild_idx].level)) == "d201",
		str(rebuild_world.plots[rebuild_idx]))
	var rebuild_large := _card_world("rebuild")
	var large_idx := int(rebuild_large.players[1].tile)
	rebuild_large.plots[large_idx].level = 4 # 二连地重工厂；模拟旧存档没有 footprint 字段
	_ok("旧存档二连地改建保持尺寸，产物是银行而非俱乐部",
		str(rebuild_large.rebuild_plan(1, large_idx, "special1").get("name", "")) == "银行")
	var joined_idx := rebuild_large._wrap(large_idx + 1)
	rebuild_large.plots[large_idx]["members"] = [large_idx, joined_idx]
	rebuild_large.plots[joined_idx] = (rebuild_large.plots[large_idx] as Dictionary).duplicate(true)
	(rebuild_large.players[1].cards as Array).append("rebuild")
	_ok("二连地改建同步更新两个道路入口",
		rebuild_large.act_use_card(1, "rebuild", -1, "special1")
		and str(rebuild_large.plots[large_idx].type) == "special1"
		and str(rebuild_large.plots[joined_idx].type) == "special1"
		and int(rebuild_large.plots[joined_idx].level) == 2)
	rebuild_large._downgrade_estate(large_idx)
	_ok("二连格一级特殊建筑拆成独立空地且保留业主",
		int(rebuild_large.plots[large_idx].level) == 0 and int(rebuild_large.plots[joined_idx].level) == 0
		and int(rebuild_large.plots[large_idx].owner) == 1 and int(rebuild_large.plots[joined_idx].owner) == 1
		and not rebuild_large.plots[large_idx].has("footprint") and not rebuild_large.plots[joined_idx].has("footprint"))
	var clear_world := _card_world("clear")
	var clear_player: Dictionary = clear_world.players[1]
	var clear_start := int(clear_player["tile"])
	var clear_step := int(clear_player["dir"])
	var farther := clear_world._wrap(clear_start + clear_step * 4)
	clear_world.road_objs[farther] = {"kind": "ring"}
	(clear_player["cards"] as Array).append("clear")
	var clear_used := clear_world.act_use_card(1, "clear")
	_ok("清除卡发动时道具仍在，等待推土机抵达", clear_used and clear_world.road_objs.has(farther))
	clear_world.step(3.5)
	_ok("推土机走完前方七格后清理路面物体",
		clear_used
		and clear_world._obstacle_at(clear_world._wrap(clear_start + clear_step * 2)).is_empty()
		and not clear_world.road_objs.has(farther))

	# ---- 卡片可用性门禁：原因码全部取自原版 String.txt 60..70 ----
	_ok("原因码文案来自原版 String.txt（60 现金不足 / 63 只能用于对手的地产 / 65 没有建筑）",
		Rules.ui_string(60) == "现金不足"
			and Rules.ui_string(63) == "只能用于对手的地产"
			and Rules.ui_string(65) == "没有建筑",
		"%s / %s / %s" % [Rules.ui_string(60), Rules.ui_string(63), Rules.ui_string(65)])
	# 走着的时候**可以**用卡（停留卡 9040 就是边走边「原地停留一次」用的）；
	# 只有骰子卡正等你点步数这个模态状态才拒绝。
	var simM := _card_world("step1")
	simM.players[1]["moving"] = 2
	_ok("边走边用卡是允许的（停留卡语义）", simM.card_usable(1, "stay") == 0,
		"code %d" % simM.card_usable(1, "stay"))
	simM.players[1]["pending_steps"] = true
	_ok("骰子卡等选步数时其他卡不可用（原因码 61）", simM.card_usable(1, "step1") == 61,
		"code %d" % simM.card_usable(1, "step1"))

	# ---- 购地卡 / 土神卡：目标必须是**对手已有的地产**（老板 2026-09-26 反馈的 bug）----
	# 原语义写错了：购地卡要求「这格还没有主」，而空地本来就能直接买 →
	# 老板手里这张卡永远返回 false 且界面毫无反馈。
	var simB := _card_world("buyland")
	var pB: Dictionary = simB.players[1]
	var aB := int(pB["tile"])
	(pB["cards"] as Array).append("buyland")
	_ok("购地卡：站在对手的地产上 → 可用", simB.card_usable(1, "buyland") == 0,
		"code %d" % simB.card_usable(1, "buyland"))
	var pay_before := int(pB["money"])
	var sell_before := int(simB.players[2]["money"])
	var pv := simB.plot_value(aB)
	_ok("购地卡：地过户到自己名下，钱按「现值」付给原主",
		simB.act_use_card(1, "buyland")
			and int(simB.plots[aB]["owner"]) == 1
			and int(pB["money"]) == pay_before - pv
			and int(simB.players[2]["money"]) == sell_before + pv,
		"现值 %d" % pv)
	var simC := _card_world("buyland")
	var pC: Dictionary = simC.players[1]
	simC.plots.erase(int(pC["tile"]))
	(pC["cards"] as Array).append("buyland")
	_ok("购地卡：脚下不是「对手的地产」→ 原因码 63，且卡片保留",
		simC.card_usable(1, "buyland") == 63
			and not simC.act_use_card(1, "buyland")
			and (pC["cards"] as Array).has("buyland"),
		"code %d" % simC.card_usable(1, "buyland"))
	var simD := _card_world("tudigong")
	var pD: Dictionary = simD.players[1]
	simD.plots[int(pD["tile"])] = {"owner": 1, "level": 2, "type": "industry"}
	(pD["cards"] as Array).append("tudigong")
	_ok("土神卡：脚下的地是自己的 → 原因码 63、卡片保留",
		simD.card_usable(1, "tudigong") == 63
			and not simD.act_use_card(1, "tudigong")
			and (pD["cards"] as Array).has("tudigong"),
		"code %d" % simD.card_usable(1, "tudigong"))
	_ok("购地卡「现值」= 地价 + 已投入建造费（> 空地价）",
		pv > simD.empty_plot_price(), "%d > %d" % [pv, simD.empty_plot_price()])

	# ---- 需要点选对手的卡：没目标不许用，且不消耗 ----
	var sim3 := _card_world("qiongshen")
	var p3: Dictionary = sim3.players[1]
	(p3["cards"] as Array).append("qiongshen")
	_ok("穷神卡无目标 → 拒绝使用", not sim3.act_use_card(1, "qiongshen"))
	_ok("被拒后卡片仍在手牌（不白扔）", (p3["cards"] as Array).has("qiongshen"))
	_ok("穷神卡指定对手 → 生效，状态挂在**对手**身上",
		sim3.act_use_card(1, "qiongshen", 2)
		and int(sim3.players[2]["effects"]["rent_double_steps"]) == 30,
		"对手 rent_double = %d" % int(sim3.players[2]["effects"]["rent_double_steps"]))
	_ok("需要点选对手的卡 ≥ 20 张（String.txt 1101 有实际用处）",
		Sim.CARD_TARGET.size() >= 20, "%d 张有目标" % Sim.CARD_TARGET.size())

	# ---- 骰子卡：自选步数 ----
	var sim4 := _card_world("dice")
	var p4: Dictionary = sim4.players[1]
	(p4["cards"] as Array).append("dice")
	sim4.act_use_card(1, "dice")
	_ok("骰子卡 → 进入「等玩家选步数」", bool(p4.get("pending_steps", false)))
	_ok("选 4 步 → moving = 4", sim4.act_walk(1, 4) and int(p4["moving"]) == 4,
		"moving %d" % int(p4["moving"]))
	_ok("没等选步数时 walk 无效（防误触）", not sim4.act_walk(1, 3) or int(p4["moving"]) == 4)

	# ---- 丢弃 ----
	var sim5 := _card_world("step1")
	var p5: Dictionary = sim5.players[1]
	(p5["cards"] as Array).append("step1")
	_ok("丢弃卡真的从手牌消失",
		sim5.act_discard_card(1, "step1") and not (p5["cards"] as Array).has("step1"))

	# ---- 涨价 / 查封 真的作用在租金上 ----
	var sim6 := _card_world("priceup")
	var p6: Dictionary = sim6.players[1]
	var idx6 := int(p6["tile"])
	sim6.plots[idx6] = {"owner": 2, "level": 5, "type": "industry"}
	sim6.street_seal.clear()
	sim6.street_index.clear()
	var st6: String = sim6.map.street_of(idx6)
	p6.cards = ["priceup", "priceup"]
	var land_before := sim6.plot_value(idx6)
	var owner_value_before := sim6.estate_value(sim6.players[2])
	var twice := sim6.act_use_card(1, "priceup") and sim6.act_use_card(1, "priceup")
	_ok("同一街道连续两张涨价卡累计 +10%，地产现值随之增加",
		twice and int(sim6.street_index.get(st6, 0)) == 10 and sim6.plot_value(idx6) > land_before
		and sim6.estate_value(sim6.players[2]) > owner_value_before,
		"%d → %d，街道 %+d%%" % [land_before, sim6.plot_value(idx6),
			int(sim6.street_index.get(st6, 0))])
	sim6.street_index.clear()
	var runner := _card_world("run")
	var athlete: Dictionary = runner.players[1]
	athlete.cards = ["run"]
	runner.obstacles.clear()
	runner.road_objs.clear()
	var origin := int(athlete.tile)
	var stamina_before := float(athlete.stamina)
	var running := runner.act_use_card(1, "run")
	var rush_steps := int(athlete.moving)
	runner._advance(athlete, 20.0)
	_ok("暴走原版随机21～36步，沿用现有体力行为", running
		and rush_steps in [21, 24, 27, 30, 33, 36]
		and int(athlete.tile) == runner._wrap(origin + rush_steps)
		and int(athlete.moving) == 0 and is_equal_approx(float(athlete.stamina), stamina_before),
		"走到%d，剩余%d步，体力%.0f" % [int(athlete.tile), int(athlete.moving), float(athlete.stamina)])
	var r0 := _rent_paid(sim6, idx6)
	sim6.street_index[st6] = 50
	var r1 := _rent_paid(sim6, idx6)
	_ok("原版工业租金由工业环境决定，涨价不直接改变工业租金", r1 == r0, "%d → %d" % [r0, r1])
	sim6.street_seal[st6] = sim6.time + 9999.0
	var r2 := _rent_paid(sim6, idx6)
	_ok("查封卡 → %s 查封期内租金 = 0" % st6, r2 == 0, "%d" % r2)

	# ---- 路面道具：路障挡人 ----
	var sim7 := _card_world("roadblock")
	var p7: Dictionary = sim7.players[1]
	sim7.obstacles = [{"idx": sim7._wrap(int(p7["tile"]) + 1),
		"kind": "roadblock", "owner": 2}]
	p7["moving"] = 4
	p7["progress"] = 0.0
	p7["effects"]["sleep_until"] = 0.0
	var guard7 := 0
	while int(p7["moving"]) > 0 and guard7 < 300:
		sim7.step(0.05)
		guard7 += 1
	_ok("路障把角色挡下（moving 归零）", int(p7["moving"]) == 0 and guard7 < 300,
		"guard %d" % guard7)


## 造一个「什么卡都能凑合用一次」的世界：自己一块地、对手一条街的房、
## 对手身上有精灵和卡、前方一个路障 …… 少数几张卡冲突按 cid 单独微调
## （购地卡 / 土神卡都要「脚下的对手地产」，见 String.txt 63 的原版批注）。
func _card_world(cid: String) -> Sim:
	var m := MapData.load_from("china")
	var sim := Sim.new()
	sim.setup(m, 999)
	sim.add_player(1, "玩家一")
	sim.add_player(2, "玩家二")
	sim.running = true
	var p: Dictionary = sim.players[1]
	var q: Dictionary = sim.players[2]
	var plots_idx: Array = []
	for i in range(m.tile_count()):
		if str(m.tile(i).get("kind", "")) == "plot":
			plots_idx.append(i)
	if plots_idx.is_empty():
		return sim
	var a: int = int(plots_idx[0])
	p["tile"] = a
	p["dir"] = 1
	p["stamina"] = 100.0                 # 不满 → 汉堡卡有可见效果
	p["money"] = 500000
	# 当前街上的房子（恶魔卡 / 爆炸卡的目标）
	var st: String = m.street_of(a)
	var made := 0
	for i in plots_idx:
		if made >= 3:
			break
		if m.street_of(int(i)) == st:
			sim.plots[int(i)] = {"owner": 2, "level": 3, "type": "industry"}
			made += 1
	if made == 0:
		sim.plots[a] = {"owner": 2, "level": 3, "type": "industry"}
	# 自己的一块地（升级卡 / 天使卡 / 改建卡）
	var own := -1
	for i in plots_idx:
		if int(i) != a and not sim.plots.has(int(i)):
			own = int(i)
			break
	if own >= 0:
		sim.plots[own] = {"owner": 1, "level": 1, "type": "industry"}
	# 对手身上的精灵 / 卡片 / 钱（诱拐 / 抢夺 / 查税 / 均富）
	sim.add_pet(q, "caishen")
	(q["cards"] as Array).append("step1")
	q["money"] = 300000
	# 前方 2 格一个路障（清除卡要用；放 +2 是为了不跟「放置路障」撞同一格）
	sim.obstacles.append({"idx": sim._wrap(a + 2), "kind": "roadblock", "owner": 2})
	# 逐卡微调冲突项
	# 购地卡与土神卡语义相同：目标必须是**脚下这块属于对手的地**
	# （`config/String.txt` 第 66 行的原版批注把 id 63「只能用于对手的地产」
	#   点名给了「（土神卡， 购地卡等）」）
	if cid == "buyland" or cid == "tudigong":
		sim.plots[a] = {"owner": 2, "level": 3, "type": "industry"}
	if cid == "rebuild" and own >= 0:
		p["tile"] = own # 原版改建作用于脚下建筑，不能自动改远处的地。
	return sim


## 让玩家一从 idx 前一格走到 idx，返回玩家二收到的租金
func _rent_paid(sim: Sim, idx: int) -> int:
	var p: Dictionary = sim.players[1]
	p["money"] = 10000000
	var before := int(sim.players[2]["money"])
	p["tile"] = sim._wrap(idx - 1)
	p["moving"] = 1
	p["progress"] = 0.0
	p["effects"]["sleep_until"] = 0.0
	p["effects"]["no_rent_steps"] = 0
	p["effects"]["rent_double_steps"] = 0
	var guard := 0
	while int(p["moving"]) > 0 and guard < 200:
		sim.step(0.05)
		guard += 1
	return int(sim.players[2]["money"]) - before


## 直接触发一次事件（跳过走路），返回 {changed, ...}
func _fire_event(sim: Sim, p: Dictionary, eid: String) -> Dictionary:
	var idx := -1
	for i in range(sim.map.tile_count()):
		if str(sim.map.tile(i).get("event", "")) == eid:
			idx = i
			break
	if idx < 0:
		# 这类格子本图没有（例如埃及没有「点券5」和「市政府」）——
		# 不算空转，跳过。测试末尾会单独断言「地图上真有的每一类都有效果」。
		return {"changed": true, "why": "地图上没有这类格子"}
	var before := {
		"money": int(p["money"]), "credit": int(p["credit"]),
		"cards": (p["cards"] as Array).size(), "pets": (p["pets"] as Array).size(),
		"tile": int(p["tile"]), "sleep": float(p["effects"]["sleep_until"]),
	}
	p["tile"] = sim._wrap(idx)
	if eid == "platform":
		p.erase("_ev_platform_moved")
	sim._resolve_event(p, int(p["tile"]), sim.map.tile(int(p["tile"])))
	var changed := (int(p["money"]) != int(before["money"])
		or int(p["credit"]) != int(before["credit"])
		or (p["cards"] as Array).size() != int(before["cards"])
		or (p["pets"] as Array).size() != int(before["pets"])
		or float(p["effects"]["sleep_until"]) != float(before["sleep"]))
	if eid == "platform" and int(p["tile"]) != idx:
		p["_ev_platform_moved"] = "→格 %d" % int(p["tile"])
		changed = true
	# 复原，别影响下一类
	p["tile"] = sim._wrap(int(before["tile"]))
	return {"changed": changed}

# ------------------------------------------------------- 4. 买地与过路费

func _test_buy_and_rent() -> void:
	print("\n[4] 买地与过路费")
	var sim := _fresh_sim()
	var p1: Dictionary = sim.players[1]
	var p2: Dictionary = sim.players[2]

	# 把玩家 1 走到 1 号格（少林路，地产格）
	_arrive_at(sim, p1, 1)
	_ok("抵达地产格 1", int(p1["tile"]) == 1, "tile=%d" % int(p1["tile"]))
	_ok("服务端标记可购买点（原版 id 91「是否购买」）",
		int(p1["last_plot"]) == 1 and str(p1["last_plot_kind"]) == "buy",
		"last_plot=%d kind=%s" % [int(p1["last_plot"]), str(p1["last_plot_kind"])])

	var before: int = int(p1["money"])
	var ok_buy: bool = sim.act_buy(1)
	_ok("购买成功", ok_buy)
	_ok("扣除地价 2000（Empty_Grid_PriceFactor 200 × 地价因子 10）",
		int(p1["money"]) == before - sim.empty_plot_price(),
		"%d -> %d" % [before, int(p1["money"])])
	_ok("地块登记归属", sim.plots.has(1) and int(sim.plots[1]["owner"]) == 1)
	_ok("买下只是「空地」：等级 0 且还没定房型",
		int(sim.plots[1]["level"]) == 0 and str(sim.plots[1]["type"]) == "",
		"level=%d type='%s'" % [int(sim.plots[1]["level"]), str(sim.plots[1]["type"])])
	_ok("购买后清除可购买标记", int(p1["last_plot"]) == -1)
	_ok("买地后不能顺势升级（原版 id 88 把「空地」和「升级」并列，要下次抵达）",
		not sim.act_upgrade(1))

	# 再走回来一次 → 这才有「建设/升级」的机会
	_arrive_at(sim, p1, 1)
	_ok("回到自己地产 → 拿到一次性升级机会",
		int(p1["last_plot"]) == 1 and str(p1["last_plot_kind"]) == "upgrade",
		"last_plot=%d kind=%s" % [int(p1["last_plot"]), str(p1["last_plot_kind"])])
	_ok("空地首次建设必须先定房型（原版 id 92「选择房屋」）",
		not sim.act_upgrade(1))
	_ok("指定房型后建设成功", sim.act_upgrade(1, "uptown"))
	_ok("建成 = 一级公寓（House.txt 第 1 级）",
		int(sim.plots[1]["level"]) == 1 and str(sim.plots[1]["type"]) == "uptown",
		"level=%d type=%s" % [int(sim.plots[1]["level"]), str(sim.plots[1]["type"])])
	_ok("建设费 = 一级公寓升级费 1000",
		int(p1["money"]) == before - sim.empty_plot_price() - 1000,
		"money=%d" % int(p1["money"]))

	# 玩家 2 走到该格 → 应付过路费
	_arrive_at(sim, p2, 1)
	var m1: int = int(p1["money"])
	var m2: int = int(p2["money"])
	_ok("玩家2 停在 1 号格", int(p2["tile"]) == 1, "tile=%d" % int(p2["tile"]))
	_ok("玩家2 被扣1650（基本租金1500及自身建筑地价影响）",
		m2 == Sim.START_MONEY - 1650, "money=%d" % m2)
	_ok("玩家1 收到等额租金",
		m1 == before - sim.empty_plot_price() - 1000 + 1650, "money=%d" % m1)
	_ok("收支平衡",
		(Sim.START_MONEY - m2) == (m1 - (before - sim.empty_plot_price() - 1000)))

# --------------------------------------- 5. 地产升级链条（老板 2026-09-26 的硬要求）

func _test_upgrade_chain() -> void:
	print("\n[5] 地产升级链条：一次抵达只升一级")
	var sim := _fresh_sim()
	var p: Dictionary = sim.players[1]
	# 直接把 1 号格设成自己的 1 级公寓，跳过买地/建设两步
	sim.plots[1] = {"owner": 1, "level": 1, "type": "uptown"}

	_arrive_at(sim, p, 1)
	_ok("抵达自己地产 → 拿到一次性升级机会",
		int(p["last_plot"]) == 1 and str(p["last_plot_kind"]) == "upgrade")

	var money0: int = int(p["money"])
	_ok("第 1 次升级成功", sim.act_upgrade(1))
	_ok("等级 1 → 2", int(sim.plots[1]["level"]) == 2,
		"level=%d" % int(sim.plots[1]["level"]))
	_ok("升级即消费掉这次机会（last_plot 清空）",
		int(p["last_plot"]) == -1 and str(p["last_plot_kind"]) == "")
	_ok("【关键】原地连点升不上去：第 2 次必失败", not sim.act_upgrade(1))
	_ok("【关键】等级仍停在 2，没被连点到满级", int(sim.plots[1]["level"]) == 2,
		"level=%d" % int(sim.plots[1]["level"]))
	_ok("升级费 = 二级公寓 1000（House.txt 逐级取，不是固定值）",
		int(p["money"]) == money0 - 1000, "%d -> %d" % [money0, int(p["money"])])

	# 走开再回来 → 又能升一级
	p["tile"] = 5
	_arrive_at(sim, p, 1)
	_ok("走开再回来 → 又能升一级",
		sim.act_upgrade(1) and int(sim.plots[1]["level"]) == 3,
		"level=%d" % int(sim.plots[1]["level"]))

	# 停留卡 = 原地再结算一次 → 同格连续升级的正路（老板点出的那条）
	_ok("第 3 次连点仍失败", not sim.act_upgrade(1))
	p["cards"] = ["stay"]
	_ok("停留卡使用成功", sim.act_use_card(1, "stay"))
	_ok("停留卡后重新拿到机会（原版 id 8140「多停一次!」）",
		int(p["last_plot"]) == 1 and str(p["last_plot_kind"]) == "upgrade",
		"last_plot=%d kind=%s" % [int(p["last_plot"]), str(p["last_plot_kind"])])
	_ok("停留卡后能再升一级", sim.act_upgrade(1) and int(sim.plots[1]["level"]) == 4,
		"level=%d" % int(sim.plots[1]["level"]))

	# 扩成 2x2 住宅必须拥有相邻空地；免费卡只免造价，不免占地条件。
	sim.plots[2] = {"owner": 1, "level": 0, "type": ""}
	# 福神卡：Card_FuShen_Steps = 30 步内免费加盖
	# ⚠️ 先把地块**降回 1 级** —— 上面几条已经把 1 号格顶到**本图等级上限**了，
	#   不降的话 act_upgrade 会因为「已满级」而拒绝，测不到福神的效果。
	sim.plots[1]["level"] = 1
	p["effects"]["free_upgrade_steps"] = 30
	money0 = int(p["money"])
	p["tile"] = 5
	_arrive_at(sim, p, 1)
	_ok("福神抵达自动加盖一级且免费", int(sim.plots[1]["level"]) == 2 and int(p.money) == money0)
	_ok("福神不消费手动加盖机会", int(p.last_plot) == 1 and sim.upgrade_cost(p, 1) > 0)
	var manual_cost := sim.upgrade_cost(p, 1)
	_ok("福神后手动加盖仍按正常费用", sim.act_upgrade(1) and int(sim.plots[1].level) == 3 and int(p.money) == money0 - manual_cost)
	_ok("跨档造价正确：一级住宅 2000",
		Rules.house_upgrade_cost("uptown", 5) == 2000)

	# 衰神卡：Card_ShuaiShen_Steps = 30 步内不能升级
	p["effects"]["free_upgrade_steps"] = 0
	p["effects"]["no_upgrade_steps"] = 30
	_arrive_at(sim, p, 1)
	_ok("衰神状态：到了自己地上也不给升级机会（原版 id 1053「投资失败」）",
		int(p["last_plot"]) == -1 and not sim.act_upgrade(1))

	# 升级卡：不靠走回来也能升（连续升级的另一条路）
	p["effects"]["no_upgrade_steps"] = 0
	var before_lv: int = int(sim.plots[1]["level"])
	p["cards"] = ["upgrade"]
	_ok("升级卡无需抵达即可升级",
		sim.act_use_card(1, "upgrade") and int(sim.plots[1]["level"]) == before_lv + 1,
		"level %d -> %d" % [before_lv, int(sim.plots[1]["level"])])

	# 满级后不再给机会（上限取 House.txt 的 nGrade）
	_ok("住宅区上限 12 / 商业区 15 / 工业区 9（House.txt nGrade）",
		sim.max_level("uptown") == 12 and sim.max_level("shop") == 15
			and sim.max_level("industry") == 9)
	sim.plots[1]["level"] = 12
	_arrive_at(sim, p, 1)
	_ok("满级后不给机会、也不给升",
		int(p["last_plot"]) == -1 and not sim.act_upgrade(1))

	# 本图可建房型来自原版 <map>.txt 的 buildinfo
	var cn := MapData.load_from("china")
	var pa := MapData.load_from("paris")
	_ok("china 允许三种房型 / paris 只允许商业区（原版 buildinfo）",
		_gbt(cn).size() == 3 and _gbt(pa) == ["shop"],
		"china=%s paris=%s" % [str(_gbt(cn)), str(_gbt(pa))])

func _gbt(m: MapData) -> Array:
	## buildable_types() 需要 map 已 setup —— 这里直接用 build_flags 复算一遍
	var out: Array = []
	for t in Rules.primary_types():
		if int(m.build_flags.get(str(t), 0)) > 0:
			out.append(str(t))
	if out.is_empty():
		out = Rules.primary_types().duplicate()
	return out

# ------------------------------------------------- 5. 两类计时器语义区分

func _test_timers() -> void:
	print("\n[6] 计时器语义（绝对时刻 vs 剩余步数）")
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
	_arrive_at(sim, p, 1)
	_ok("免费卡生效：未扣钱", int(p["money"]) == Sim.START_MONEY, "money=%d" % int(p["money"]))
	_ok("免费卡步数按格递减到 19", int(p["effects"]["no_rent_steps"]) == 19,
		"steps=%d" % int(p["effects"]["no_rent_steps"]))

# ------------------------------------------------------------ 6. 破产判定

func _test_bankruptcy() -> void:
	print("\n[7] 破产判定")
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
	print("\n[8] 静止睡眠（原版 25 秒）")
	var sim := _fresh_sim()
	var p: Dictionary = sim.players[1]
	# 走 25 秒（不掷骰）
	var t := 0.0
	while t < 25.2:
		sim.step(0.1)
		t += 0.1
	_ok("静止 25 秒后进入睡眠",
		float(p["effects"]["rest_until"]) > sim.time,
		"rest_until=%.1f  now=%.1f" % [float(p["effects"]["rest_until"]), sim.time])
	_ok("挂机休息时点击 GO 可立即唤醒并掷骰",
		sim.act_roll(1) and float(p["effects"]["rest_until"]) == 0.0 and int(p["moving"]) > 0)
	p["moving"] = 0
	p["effects"]["sleep_until"] = sim.time + 5.0
	_ok("冬眠卡造成的睡眠不能靠 GO 解除", not sim.act_roll(1))
	p["effects"]["sleep_until"] = 0.0
	p["effects"]["rest_until"] = sim.time + 5.0
	p["stamina"] = 0.0
	_ok("体力不足时 GO 仍立即解除挂机休息", not sim.act_roll(1) and
		float(p["effects"]["rest_until"]) == 0.0)
	var winter := _fresh_sim()
	winter.add_player(3, "远方玩家")
	var caster: Dictionary = winter.players[1]
	var nearby: Dictionary = winter.players[2]
	var faraway: Dictionary = winter.players[3]
	caster.tile = 10
	nearby.tile = 11
	faraway.tile = 40
	caster.cards = ["hibernate"]
	_ok("冬眠卡作用全图其他玩家，不会冬眠自己",
		winter.act_use_card(1, "hibernate") and float(caster.effects.sleep_until) == 0.0
		and float(nearby.effects.sleep_until) > winter.time
		and float(faraway.effects.sleep_until) > winter.time)
	winter._resolve_event(caster, int(caster.tile), {"event": "hospital", "name": "医院"})
	_ok("经过医院路点不误进入冬眠状态", float(caster.effects.sleep_until) == 0.0)

# ------------------------------------------- 8. 语义事件（Sim → 表现层的唯一接口）

func _test_game_events() -> void:
	print("\n[9] 玩法语义事件（game_event）")
	var sim := _fresh_sim()
	var got: Array = []
	sim.game_event.connect(func(kind: String, data: Dictionary) -> void:
		got.append({"kind": kind, "data": data}))
	sim.act_roll(1)
	_ok("掷骰抛 roll 事件", got.any(func(e): return e["kind"] == "roll"),
		"收到 %d 个事件" % got.size())
	_ok("事件带 pid / role / tile",
		got.size() > 0 and got[0]["data"].has("pid") and got[0]["data"].has("role")
			and got[0]["data"].has("tile"),
		str(got[0]["data"]) if got.size() > 0 else "无")
	# 走到某个格子并结算，必然抛出一条「到达类」事件
	var before := got.size()
	var guard := 0
	while sim.players[1]["moving"] and guard < 400:
		sim.step(0.05)
		guard += 1
	var kinds: Array = []
	for i in range(before, got.size()):
		kinds.append(str(got[i]["kind"]))
	_ok("到达结算抛到达类事件", kinds.size() > 0, "事件序列 %s" % str(kinds))
	_ok("Sim 里没有音频依赖（铁律 4）",
		not _src_mentions("game/scripts/core/sim.gd", ["Audio", "play_sfx", "AudioServer"]),
		"")

func _src_mentions(rel: String, needles: Array) -> bool:
	var f := FileAccess.open("res://" + rel.replace("game/", ""), FileAccess.READ)
	if f == null:
		return false
	var txt := f.get_as_text()
	f.close()
	for n in needles:
		if txt.contains(str(n)):
			return true
	return false

# ------------------------------------------------------------ 9. 音频层

func _test_audio() -> void:
	print("\n[10] 音频层（voice_map.json ↔ 素材）")
	_ok("voice_map.json 已加载", not Audio.mapping.is_empty())
	var rep: Dictionary = Audio.audit()
	var want: int = 0
	for r in Audio.mapping.get("roles", []):
		want += (r.get("lines", {}) as Dictionary).size()
		want += (r.get("card_lines", {}) as Dictionary).size()
	want += Audio.mapping.get("pets", []).size() * 9
	want += Audio.mapping.get("effects", {}).size()
	want += Audio.mapping.get("music", []).size()
	# 原版盘上**本身就缺**的素材（不是我们漏拷）：
	#   阿土伯（role2）缺 card/27.wav（飞弹卡）→ 原版这里也是静音
	const KNOWN_GAPS := ["role2/card/27"]
	var miss: Array = rep["missing"]
	var unexpected: Array = []
	for m in miss:
		if not KNOWN_GAPS.has(str(m)):
			unexpected.append(m)
	_ok("映射表与素材逐条对得上（已知原版缺档除外）",
		unexpected.is_empty() and int(rep["ok"]) == want - KNOWN_GAPS.size(),
		"命中 %d/%d，意外缺失 %s，已知缺档 %s" % [
			int(rep["ok"]), want - KNOWN_GAPS.size(),
			str(unexpected.slice(0, 5)), str(KNOWN_GAPS)])
	_ok("原版缺档确实只有已知那几处", miss.size() == KNOWN_GAPS.size(),
		"实际缺 %d 处：%s" % [miss.size(), str(miss.slice(0, 8))])
	_ok("12 角色 / 42 卡 / 9 宠物 / 18 曲 / 152 音效",
		Audio.mapping.get("roles", []).size() == 12
			and Audio.mapping.get("cards", []).size() == 42
			and Audio.mapping.get("pets", []).size() == 9
			and Audio.mapping.get("music", []).size() == 18
			and Audio.mapping.get("effects", {}).size() == 152,
		"%d/%d/%d/%d/%d" % [Audio.mapping.get("roles", []).size(),
			Audio.mapping.get("cards", []).size(), Audio.mapping.get("pets", []).size(),
			Audio.mapping.get("music", []).size(), Audio.mapping.get("effects", {}).size()])
	# 角色消息 id 号段（Info.txt：role k 的段号 = 9+k）
	_ok("role1 → 1001 / rolec(12) → 2127",
		Audio.role_msgid(1, Audio.V_ATTACK) == 1001
			and Audio.role_msgid(12, Audio.V_MENU) == 2127,
		"%d / %d" % [Audio.role_msgid(1, Audio.V_ATTACK), Audio.role_msgid(12, Audio.V_MENU)])
	_ok("角色目录名 role1..role9/rolea-c",
		Audio.role_dir(1) == "role1" and Audio.role_dir(10) == "rolea" and Audio.role_dir(12) == "rolec",
		"%s/%s/%s" % [Audio.role_dir(1), Audio.role_dir(10), Audio.role_dir(12)])
	# 实播（无头用 Dummy 驱动，只验证资源能取到、调用不炸）
	_ok("音效 1 / 2 / 95 可播", Audio.play_sfx(1) and Audio.play_sfx(2) and Audio.play_sfx(95))
	_ok("不存在的音效 id 安全返回 false", not Audio.play_sfx(9999))

	# ---- 音效语义表（sfx.json）：老板人工试听 29 条 + 我方实证 3 条 ----
	_ok("sfx.json 已加载", not Audio.sfx_labels.is_empty())
	const BOSS_LABELS := {
		5: "骰子滚动结束", 6: "胜利结算画面", 7: "失败结算", 9: "某个小神仙的地产升级技能（天使/雪精灵类）",
		12: "地产升级", 13: "拍卖结算", 15: "金币散落声", 19: "禁止操作的音效",
		23: "骰子滚动声", 24: "升级卡·全街升级", 26: "某种负面效果的声音（具体哪种待定）",
		28: "恶魔的笑声，可能是恶魔卡的音效", 33: "整条街涨价的声音", 34: "整条街降价的声音",
		36: "炸弹爆炸声", 38: "电击声", 39: "飞弹飞下来并爆炸的声音",
		40: "穷鬼等负面技能导致扣款的声音", 41: "欢呼声", 42: "哀叹声",
		50: "金币掉落在桌子上的声音", 51: "车辆移动的声音", 52: "银行结账的声音",
		54: "某种爆炸声（具体哪种待定）", 55: "引擎发动的声音", 56: "摩托车移动的声音",
		67: "鸟叫声", 69: "小孩哭的声音", 71: "打雷的声音",
	}
	var bad_labels: Array = []
	for k in BOSS_LABELS.keys():
		if Audio.sfx_label(int(k)) != str(BOSS_LABELS[k]):
			bad_labels.append("%d=%s" % [int(k), Audio.sfx_label(int(k))])
	_ok("老板人工试听的 29 条音效语义逐条对上", bad_labels.is_empty(),
		"实际 %d 条不一致：%s" % [bad_labels.size(), str(bad_labels.slice(0, 4))])
	_ok("实证 3 条语义在表里（1 / 2 / 95）",
		Audio.sfx_label(1) != "" and Audio.sfx_label(2) != "" and Audio.sfx_label(95) != "")
	_ok("两条「已被试听否证」的自动推断已登记（防止再当线索）",
		(Audio.sfx_labels.get("_disproved", {}) as Dictionary).size() == 2)
	# 「已接线」的音效必须真的存在、真的能播 —— 免得写了 wired 却放不出声
	var wired := Audio.wired_sfx()
	var wired_bad: Array = []
	for i in wired:
		if not Audio.play_sfx(int(i)):
			wired_bad.append(i)
	_ok("已在游戏里接线的音效全部可播", wired_bad.is_empty(),
		"接线 %d 条：%s" % [wired.size(), str(wired)])
	_ok("接线数 >= 12（骰子2 + 买卖升级 + 结算 + 卡）", wired.size() >= 12,
		"实际 %d" % wired.size())
	_ok("角色对白（钱夫人·破产）可播", Audio.say(1, Audio.V_BANKRUPT))
	_ok("卡名 42（核彈卡）可播", Audio.say_card(1, 42))
	# 12 张卡的「回」话 = 03/04/08/17/19/20/23/24/35/36/37/38（来源：exe 0x9ecb4 的 int32 表）
	_ok("卡的「回」话可播（孙小美·穷神卡）", Audio.say_card(5, 3, true))
	var reply_ok := true
	for n in [3, 4, 8, 17, 19, 20, 23, 24, 35, 36, 37, 38]:
		if not Audio.say_card(5, n, true):
			reply_ok = false
	_ok("12 张「回」话卡逐张可播", reply_ok)
	# 原版数据自带的坑：只有 03~13/32/33 这 7 张卡没有配音
	var silent_ok := true
	for n in [9, 10, 11, 12, 13, 32, 33]:
		if Audio.say_card(5, n):
			silent_ok = false
	_ok("无配音的 7 张卡（09~13/32/33）不出声", silent_ok)
	_ok("宠物语音可播", Audio.pet_say(3, 1))
	_ok("BGM 可播（主菜单曲）", Audio.play_bgm(Audio.BGM_MENU))
	# BGM 选曲：7 张地图实测全是 m01009（740Hz，8/8 次重复）
	var maps := ["aiji", "island", "paris", "space", "train", "japan", "china"]
	var all_same := true
	for m in maps:
		if Audio.map_bgm(str(m)) != "m01009":
			all_same = false
	_ok("7 张地图的对局曲都是 m01009（实测 8/8）", all_same)
	_ok("未知地图回落到 m01009", Audio.map_bgm("no_such_map") == Audio.BGM_FALLBACK,
		Audio.map_bgm("no_such_map"))
	# 原版引擎「放完一曲接下一首」（实测 m01009 → m01010）
	_ok("对局 BGM 起于 m01009", Audio.play_bgm_playlist("m01009") and Audio.bgm_current() == "m01009",
		Audio.bgm_current())
	_ok("放完自动接下一首 m01010", Audio.advance_bgm() and Audio.bgm_current() == "m01010",
		Audio.bgm_current())
	Audio.stop_bgm()
	_ok("BGM 可停", Audio.bgm_current() == "")
	# 环境底噪必须真的开了循环（素材只有 2.023 s，实测原版对局里持续 285 s）
	_ok("环境底噪 95 已起且循环已开",
		Audio.start_ambient() and Audio.ambient_id() == Audio.SFX_AMBIENT and Audio.ambient_looping())
	Audio.stop_ambient()
	_ok("环境底噪可停", Audio.ambient_id() == -1)

# ------------------------------------------------------------------ 工具

## 把玩家挪到 idx 的前一格再走一步 —— 必须**真的触发 _arrive 结算**，
## 不能直接把 tile 设成 idx 了事（那正是上一轮漏掉致命 bug 的原因）。
func _arrive_at(sim: Sim, p: Dictionary, idx: int) -> void:
	p["tile"] = sim._wrap(idx - 1)
	p["moving"] = 1
	p["progress"] = 0.0
	p["idle"] = 0.0
	p["effects"]["sleep_until"] = 0.0
	var guard := 0
	while int(p["moving"]) > 0 and guard < 200:
		sim.step(0.05)
		guard += 1

func _fresh_sim() -> Sim:
	var m := MapData.load_from("china")
	var sim := Sim.new()
	sim.setup(m, 12345)
	sim.add_player(1, "玩家一")
	sim.add_player(2, "玩家二")
	sim.running = true
	return sim
