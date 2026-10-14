extends "res://scripts/ui/card_flow_review.gd"
## Every base card and all nine pets get an independent world and outcome check.
## Uses the same command parser exposed to the player; does not random-roll for setup.
var rows: Array = []
var pet_rows: Array = []
var fixtures := SelfTest.new()

func audit_card(id: String) -> void:
	var sim := fixtures._card_world(id)
	sim.time = 10.0
	var p: Dictionary = sim.players[1]
	var q: Dictionary = sim.players[2]
	q.tile = sim._wrap(int(p.tile) + 1)
	DebugCommands.execute(sim, 1, "/cards clear")
	DebugCommands.execute(sim, 1, "/card " + id)
	var target := 2 if sim.card_needs_player(id) else -1
	var selection := ""
	if id in ["copy", "gem"]:
		selection = "step3" if id == "copy" else "shuaishen"
		DebugCommands.execute(sim, 1, "/card " + selection)
	if sim.card_target(id) in ["road", "building"]:
		var candidates := sim.card_map_candidates(1, id)
		if not candidates.is_empty(): target = int(candidates[0])
	if sim.card_target(id) == "stock": selection = str(sim.stock_names()[0])
	if id == "rebuild": selection = "special1"
	if id == "stay": p.moving = 3; p.progress = .4
	var cash := int(p.money)
	var enemy_cash := int(q.money)
	var levels := {}
	for index in sim.plots: levels[index] = int(sim.plots[index].level)
	var street := sim.map.street_of(int(p.tile))
	var value := sim.plot_value(int(p.tile))
	var price := sim.stock_price(selection)
	var events: Array = []
	sim.game_event.connect(func(kind, _data): events.append(kind))
	var used := sim.act_use_card(1, id, target, selection)
	var outcome := false
	var note := ""
	match id:
		"caishen": outcome = int(p.money) - cash >= 10000 and int(p.money) - cash <= 50000 and p.effects.no_rent_steps == 30; note = "现金增加1～5万元，免租30步"
		"fushen": outcome = p.effects.free_upgrade_steps == 30 and p.cards.size() == 5; note = "免费加盖30步并获得5张卡"
		"qiongshen": outcome = q.effects.rent_double_steps == 30 and int(q.money) < enemy_cash and int(p.money) - cash == enemy_cash - int(q.money); note = "转移现金，目标过路费加倍30步"
		"shuaishen": outcome = q.effects.no_upgrade_steps == 30 and events.has("card_status_applied"); note = "目标不能购地/升级30步且有反馈"
		"tianshi", "emo":
			var changed := 0
			for index in levels:
				if sim.map.street_of(int(index)) == street and int(sim.plots[index].level) != int(levels[index]): changed += 1
			outcome = changed > 0; note = "当前街道的已有建筑升级/降级"
		"qingshen": outcome = p.pets.size() == 1 and not sim.active_pet(p).is_empty(); note = "获得一只小神仙并自动出战"
		"tudigong": outcome = int(sim.plots[p.tile].owner) == 1 and int(p.money) == cash; note = "脚下对手地产免费转移所有权"
		"step1", "step2", "step3", "step4", "step5": outcome = int(p.moving) == int(id.trim_prefix("step")); note = "增加对应步数"
		"turn": outcome = p.dir == -1; note = "改变前进方向"
		"run": outcome = p.speed == Sim.MOVE_SPEED * 2 and p.effects.rush_until > sim.time and int(p.moving) in [21, 24, 27, 30, 33, 36]; note = "原版随机暴走21～36步"
		"dice": outcome = p.pending_steps and sim.act_walk(1, 4) and p.moving == 4; note = "进入选点数状态，自选四步后移动"
		"rebuild": outcome = str(sim.plots[p.tile].type) == "special1"; note = "普通建筑改建成相同占地尺寸的特殊建筑"
		"upgrade": outcome = target >= 0 and int(sim.plots[target].level) == int(levels[target]) + 1 and int(p.money) == cash; note = "选中自己的建筑免费升级一级"
		"monster": outcome = target >= 0 and int(sim.plots[target].level) == int(levels[target]) - 1; note = "选中建筑降一级"
		"buyland": outcome = int(sim.plots[p.tile].owner) == 1 and int(p.money) == cash - value and int(q.money) == enemy_cash + value; note = "按现值支付原主并转移脚下地产"
		"priceup": outcome = int(sim.street_index.get(street, 0)) == 5; note = "当前街道地价指数增加5"
		"pricedown": outcome = int(sim.street_index.get(street, 0)) == -5; note = "当前街道地价指数减少5"
		"mine": outcome = str(sim._obstacle_at(sim._wrap(int(p.tile) - int(p.dir))).get("kind", "")) == id; note = "按原版在身后一格放置地雷"
		"roadblock": outcome = str(sim._obstacle_at(target).get("kind", "")) == id and int(sim._obstacle_at(target).owner) == 1; note = "放置在指定路点"
		"free": outcome = p.effects.no_rent_steps == 20; note = "免租20步"
		"invincible": outcome = p.effects.invincible_until == 82.0; note = "无敌72秒"
		"missile", "nuke":
			var index := int(p.tile)
			p.tile = sim._wrap(index + sim.map.tile_count() / 2)
			q.tile = target
			q.stamina = 100
			sim.pending_card_impacts.clear()
			# Retry against the selected building rather than an empty first road candidate.
			DebugCommands.execute(sim, 1, "/card " + id)
			p.tile = index
			used = sim.act_use_card(1, id, index)
			outcome = used and sim.pending_card_impacts.size() == 1 and int(sim.plots[index].level) == int(levels[index])
			q.tile = index
			sim.step(1.01)
			outcome = outcome and int(sim.plots[index].level) == (0 if id == "nuke" else int(levels[index]) - 1) and float(q.effects.hospital_until) > sim.time
			note = "选中爆心延迟命中、建筑受损、附近体力不足角色住院"
		"hibernate": outcome = float(q.effects.sleep_until) == 20.0 and q.moving == 0; note = "其他有效角色冬眠10秒"
		"redcard": outcome = is_equal_approx(sim.stock_price(selection), price * 1.2); note = "指定公司股价增加20%"
		"blackcard": outcome = is_equal_approx(sim.stock_price(selection), price * .8); note = "指定公司股价减少20%"
		"seize": outcome = float(sim.street_seal.get(street, 0)) == 130.0; note = "当前街道查封5天"
		"copy": outcome = p.cards.count("step3") == 2 and not p.cards.has("copy"); note = "复制选中的手牌"
		"gem":
			outcome = p.cards == ["boost:shuaishen"] and int(p.gems) == 0
			outcome = outcome and sim.act_use_card(1, "boost:shuaishen", 2) and q.effects.no_upgrade_steps == 60
			note = "组合衰神卡并验证强化后60步；目前组合支持四神卡"
		"hamburger": outcome = float(p.stamina) == sim.stamina_max(); note = "补充原版500体力并限制到上限"
		"abduct": outcome = p.pets.size() == 1 and q.pets.is_empty() and sim.active_pet(p).is_empty() and str(p.pets[0].id) == "caishen"; note = "对手随身实例转入备用栏"
		"tax": outcome = int(p.money) - cash >= 15000 and int(p.money) - cash <= 30000 and int(p.money) - cash == enemy_cash - int(q.money); note = "目标现金5%～10%转移"
		"rob": outcome = p.cards.has("step1") and not q.cards.has("step1"); note = "目标手牌转移给自己"
		"sharewealth": outcome = int(p.money) == 400000 and int(q.money) == 400000; note = "与选中对手平分现金"
		"clear":
			target = sim._wrap(int(p.tile) + int(p.dir) * 2)
			var queued := not sim.pending_road_clears.is_empty() and not sim._obstacle_at(target).is_empty()
			sim.step(3.5)
			outcome = queued and sim._obstacle_at(target).is_empty(); note = "推土机沿途抵达后清除"
		"stay": outcome = p.moving == 0 and p.progress == 0.0; note = "停止并重新结算当前格"
		"invisible": outcome = p.effects.invisible_until == 82.0 and p.effects.invincible_until == 0.0 and p.effects.no_rent_until == 0.0 and sim._protected(p); note = "独立隐形72秒，免租免伤无额外状态残留"
	check(used and outcome and events.has("use_card"), "%s: %s" % [Rules.card_name(id), note])
	rows.append({"id": id, "name": Rules.card_name(id), "passed": used and outcome, "expected": note})
	# Universal refusal checks must not consume the selected card.
	DebugCommands.execute(sim, 1, "/cards clear")
	DebugCommands.execute(sim, 1, "/card " + id)
	p.effects.hospital_until = sim.time + 10
	check(not sim.act_use_card(1, id, target, selection) and p.cards.has(id), id + " hospital gate preserves card")
	DebugCommands.execute(sim, 1, "/cards clear")
	p.effects.hospital_until = 0.0
	DebugCommands.execute(sim, 1, "/card " + id)
	sim.act_lock_card(1, id)
	check(sim.card_locked(p, id) and p.cards.has(id), id + " lock protects the held card from replacement")

func check_lock_actions() -> void:
	var use_sim := fixtures._card_world("step3")
	var user: Dictionary = use_sim.players[1]
	user.cards = ["step3"]
	check(use_sim.act_lock_card(1, "step3") and use_sim.act_use_card(1, "step3")
		and not user.cards.has("step3") and int(user.moving) == 3,
		"a locked card remains usable")
	var feed_sim := fixtures._pet_world("caishen")
	var feeder: Dictionary = feed_sim.players[1]
	feeder.cards = ["hamburger"]
	(feed_sim.active_pet(feeder) as Dictionary).fullness = 0.0
	check(feed_sim.act_lock_card(1, "hamburger") and feed_sim.act_feed_card(1, "hamburger")
		and not feeder.cards.has("hamburger") and
		float((feed_sim.active_pet(feeder) as Dictionary).fullness) > 0.0,
		"a locked card can be fed to the active pet")
	var rob_sim := fixtures._card_world("rob")
	var robber: Dictionary = rob_sim.players[1]
	var victim: Dictionary = rob_sim.players[2]
	robber.cards = ["rob"]
	victim.cards = ["step1"]
	victim.tile = rob_sim._wrap(int(robber.tile) + 1)
	check(rob_sim.act_lock_card(2, "step1") and rob_sim.act_use_card(1, "rob", 2)
		and robber.cards.has("step1") and not victim.cards.has("step1"),
		"a locked card can still be stolen")

func command(text: String) -> void:
	app._chat_input.text = text
	app._chat_send()
	await app.get_tree().process_frame

func reset_ui(sim: Sim) -> void:
	app._close_shop()
	app._close_house_picker()
	app._clear_card_target_mode()
	app._pop_mode = ""
	app._pop.hide()
	Net.sim.apply_dict(sim.to_dict())
	app._on_state(Net.sim.to_dict())
	await app.get_tree().process_frame

func run(root) -> void:
	app = root
	check_pet_refusals()
	output = "res://../docs/screenshots/card-pet-audit"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for card in Rules.cards(): audit_card(str(card.id))
	check_lock_actions()
	app._port_edit.text = "0"
	app._frontend.start_requested.emit({"map": "china", "role": 3, "players": 2, "money": 500000, "credit": 1000})
	Net.set_process(false)
	app._loading.hide()
	app._build_chat_bar()
	for record in Net.sim.pet_catalog():
		var id := str(record.id)
		var sim := fixtures._pet_world(id)
		sim.time = 10
		sim.players[1].pets.clear()
		sim.players[1].pet_active = ""
		await reset_ui(sim)
		await command("/pet " + id)
		await command("/petready")
		var p: Dictionary = Net.sim.players[1]
		var q: Dictionary = Net.sim.players[2]
		var cash := int(p.credit)
		var own := Net.sim._own_plot_to_upgrade(1)
		var enemy := Net.sim._enemy_plot_best(1)
		var old_owner := int(Net.sim.plots[enemy].owner)
		var enemy_level := int(Net.sim.plots[enemy].level)
		var own_level := int(Net.sim.plots[own].level)
		await app.get_tree().process_frame
		await click(app._pet_skill_btn.get_global_rect().get_center())
		if id in ["hutu", "qiongshen"]:
			check(app._pet_target_pending and int(q.effects.sleepwalk_steps) == 0,
				"hutu waits for a nearby opponent instead of sleeping everyone")
			await click((app._avatar_rows[1].btn as Button).get_global_rect().get_center())
		var pet := Net.sim.active_pet(p)
		var applied := false
		match id:
			"caishen": applied = float(p.effects.no_rent_until) > Net.sim.time
			"qiongshen": applied = float(q.effects.rent_pay_double_until) > Net.sim.time
			"hutu": applied = int(q.effects.sleepwalk_steps) > 0 and float(q.effects.sleep_until) == 0.0
			"emo": applied = int(Net.sim.plots[enemy].level) == enemy_level - 1
			"tushen": applied = old_owner == 2 and int(Net.sim.plots[enemy].owner) == 1
			"jingling": applied = int(Net.sim.plots[p.tile].level) == enemy_level + 1
			"huaxian": applied = float(p.effects.invincible_until) > Net.sim.time
			"dushen": applied = bool(p.pending_steps)
			"guaishou": applied = not q.pets.is_empty() and Net.sim.pet_energy(Net.sim.active_pet(q)) < Net.sim.pet_max_energy(Net.sim.active_pet(q))
		check(applied and Net.sim.pet_energy(pet) == Net.sim.pet_max_energy(pet) - Net.sim.pet_cost(id, 1) and int(p.credit) == cash, id + " real skill button applies effect and consumes exactly once")
		check(app._board._effects.pets.size() == 2, id + " follows only active owned pet")
		var remaining_credit := int(p.credit)
		await app.get_tree().process_frame
		app._on_pet_skill_quick()
		check(int(p.credit) == remaining_credit and app._toast_lbl.text.contains("饱食度不足"), id + " low energy refuses repeat without charge and explains why")
		pet_rows.append({"id": id, "name": str(record.name), "passed": applied, "skill": str(record.skill_raw)})
		await shot("pet-" + id)
	await check_extra_ui()
	await check_shop_after_purchase()
	await check_pet_hud_state()
	await check_lotto_and_notices()
	var report := {"cards": rows, "pets": pet_rows, "checks": checks, "failed": failed,
		"scope": "42 card outcomes plus real UI commands/skill clicks for nine pets; remaining native uncertainties are documented separately"}
	var file := FileAccess.open("res://../docs/card-pet-audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("CARD PET AUDIT: %d cards, %d pets, %d checks, %s" % [rows.size(), pet_rows.size(), checks, "FAIL" if failed else "PASS"])
	app.get_tree().quit(1 if failed else 0)

func check_extra_ui() -> void:
	var sim := fixtures._pet_world("caishen")
	sim.time = 10
	sim.players[1].pets.clear()
	sim.players[1].pet_active = ""
	await reset_ui(sim)
	for id in ["caishen", "huaxian", "emo", "dushen", "jingling"]: await command("/pet " + id)
	app._open_pet_warehouse()
	await app.get_tree().process_frame
	var fifth: Label
	for node in app._shop_nodes:
		if node is Label and node.text.contains("雪精灵"): fifth = node
	check(fifth != null and app._shop.get_node_or_null("PetSelect_caishen") == null,
		"warehouse shows four reserve slots while the active pet stays on the character panel")
	var pet_hit := app._shop.get_node_or_null("PetHit_jingling") as Button
	if pet_hit != null: await click(pet_hit.get_global_rect().position + Vector2(8, 8) * app._ui_scale)
	check(app._pet_menu != null, "the enlarged pet slot opens its menu even near the portrait edge")
	await shot("pet-action-menu")
	if app._pet_menu != null: await click((app._pet_menu.get_child(0).get_child(0) as Button).get_global_rect().get_center())
	check(str(Net.sim.active_pet(Net.sim.players[1]).id) == "jingling", "fifth pet switches active follower by actual click")
	app._close_shop()
	app._open_pet_warehouse()
	await app.get_tree().process_frame
	var to_release := app._shop.get_node("PetSelect_caishen") as Label
	await click(to_release.get_global_rect().get_center())
	if app._pet_menu != null: await click((app._pet_menu.get_child(0).get_child(1) as Button).get_global_rect().get_center())
	check(not Net.sim.has_pet(Net.sim.players[1], "caishen") and Net.sim.players[1].pets.size() == 4,
		"reserve pet can be released from its action menu")
	await shot("five-pet-warehouse")
	app._close_shop()
	var active_button := app._char_panel.get_node("PetInventoryButton") as Button
	var right := InputEventMouseButton.new()
	right.position = active_button.get_global_rect().get_center()
	right.global_position = right.position
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	Input.parse_input_event(right)
	await app.get_tree().process_frame
	right.pressed = false
	Input.parse_input_event(right)
	await app.get_tree().process_frame
	check(app._pet_menu != null, "right-clicking the active pet opens its action menu")
	if app._pet_menu != null:
		app._pet_menu.queue_free()
		app._pet_menu = null
	await command("/cards clear")
	await command("/card 汉堡卡 2")
	var p: Dictionary = Net.sim.players[1]
	var pet_before_feed := Net.sim.pet_energy(Net.sim.active_pet(p))
	var slot: int = app._card_ids.find("hamburger")
	app._on_card_clicked(slot)
	await app.get_tree().process_frame
	await click(app._card_menu_btns[2].get_global_rect().get_center())
	check(is_equal_approx(Net.sim.pet_energy(Net.sim.active_pet(p)), pet_before_feed + 4.0)
		and p.cards.count("hamburger") == 1, "actual feed menu adds four native energy points")
	Net.sim._set_pet_energy(Net.sim.active_pet(p), Net.sim.pet_max_energy(Net.sim.active_pet(p)))
	app._on_state(Net.sim.to_dict())
	app._on_card_clicked(app._card_ids.find("hamburger"))
	await app.get_tree().process_frame
	await click(app._card_menu_btns[2].get_global_rect().get_center())
	check(Net.sim.active_pet(p).fullness == 100 and p.cards.has("hamburger"), "full pet refuses the next feed and preserves the card")
	await command("/cards clear")
	# Combination goes through the hand menu and another real card click.
	app._close_shop()
	await command("/cards clear")
	await command("/card gem")
	await command("/card shuaishen")
	app._on_card_clicked(app._card_ids.find("gem"))
	await click(app._card_menu_btns[1].get_global_rect().get_center())
	check(app._card_pending == "gem", "gem menu waits for a compatible card")
	var card_slot: int = app._card_ids.find("shuaishen")
	var gem_slot: int = app._card_ids.find("gem")
	check((app._card_slots[card_slot].img as TextureRect).modulate.r >
		(app._card_slots[gem_slot].img as TextureRect).modulate.r,
		"gem selection brightens compatible cards and dims incompatible cards")
	await click(app._card_slots[card_slot].btn.get_global_rect().get_center())
	check(p.cards == ["boost:shuaishen"] and app._card_pending == "", "actual second card click creates enhanced card")
	await shot("enhanced-card")

func check_shop_after_purchase() -> void:
	var sim := fixtures._pet_world("hutu")
	sim.players[1].pet_shop_stock = ["jingling", "emo", "caishen", "hutu"]
	sim.players[1].pet_shop_open = true
	await reset_ui(sim)
	app._shop_stock = sim.players[1].pet_shop_stock.duplicate()
	app._open_shop("pethouse")
	await app.get_tree().process_frame
	await click((app._shop.get_node("BuyPet_jingling") as Button).get_global_rect().get_center())
	check(app._pop_mode == "shop", "pet portrait opens purchase confirmation")
	await click(app._pop_yes.get_global_rect().get_center())
	await app.get_tree().process_frame
	var me: Dictionary = Net.sim.players[1]
	check(Net.sim.has_pet(me, "jingling") and str(app._shop_stock[0]) == "",
		"bought pet leaves an empty shop slot")
	var bounds: Rect2 = app._shop_bg.get_global_rect()
	var fits := true
	for pet_id in ["emo", "caishen", "hutu"]:
		for prefix in ["PetName_", "PetPrice_"]:
			var node := app._shop.get_node(prefix + pet_id) as Label
			fits = fits and bounds.encloses(node.get_global_rect())
	check(fits, "remaining pet names and prices stay inside shop panel after purchase")
	await shot("pet-shop-after-buy")
	var dream := fixtures._pet_world("hutu")
	dream.players[1].effects.sleepwalk_steps = 15
	await reset_ui(dream)
	Net._ai_next[1] = 0.0
	Net._drive_ai()
	check(int(Net.sim.players[1].moving) > 0 and int(Net.sim.players[1].effects.sleepwalk_steps) == 15,
		"network host automatically rolls for a dreamwalking human player")

func check_pet_hud_state() -> void:
	var sim := fixtures._pet_world("caishen")
	await reset_ui(sim)
	var me: Dictionary = Net.sim.players[1]
	var pet: Dictionary = Net.sim.active_pet(me)
	pet.fullness = 10.0
	app._on_state(Net.sim.to_dict())
	check(app._pet_level_star.text == "★" and not app._pet_anxious.visible
		and app._pet_slot.texture == app._tex_or_null(Rules.pet_art("caishen", "face", 2)),
		"level-one pet shows one star and native worried portrait")
	pet.fullness = Sim.PET_FULLNESS_MAX
	Net.sim.step(0.1)
	app._on_state(Net.sim.to_dict())
	check(is_equal_approx(float(pet.fullness), Sim.PET_FULLNESS_MAX) and app._pet_skill_btn.visible,
		"full energy is retained with the skill button visible")
	var before := int(me.credit)
	await click(app._pet_skill_btn.get_global_rect().get_center())
	var once := int(me.credit)
	check(once == before and Net.sim.pet_energy(pet) == Net.sim.pet_max_energy(pet) - Net.sim.pet_cost("caishen", 1), "full HUD skill button casts once")
	pet.fullness = Sim.PET_FULLNESS_MAX
	app._on_state(Net.sim.to_dict())
	await click(app._pet_skill_btn.get_global_rect().get_center())
	check(int(me.credit) == once and not Net.sim.pet_skill_ready(pet),
		"full HUD skill button can cast again immediately after feeding")

func check_lotto_and_notices() -> void:
	app._event_messages.clear()
	app._event_dialog.hide()
	var lotto = app._lotto
	lotto.open(5000, {2: 1}, -1)
	check(lotto._picked == -1 and (lotto._cells[1] as Button).disabled
		and not (lotto._cells[3] as Button).disabled,
		"next lotto entry can choose another free number while purchased numbers stay unavailable")
	lotto.close()
	lotto.open(5000, {})
	lotto.mark_picked(3)
	await app.get_tree().create_timer(1.7).timeout
	check(not lotto.visible, "lotto closes shortly after number purchase")
	app._toast_lbl.text = "本地提示"
	app._on_game_event("get_card", {"pid": 2, "card": "step1", "name": "1步卡"})
	check(app._toast_lbl.text == "本地提示", "opponent card rewards do not masquerade as local rewards")
	app._on_game_event("credit", {"pid": 1, "eid": "game_a", "amount": 17})
	check(not app._event_dialog.visible and app._toast_lbl.text.contains("17"),
		"amusement park reports the actual reward without opening a dialog")
	app._on_game_event("fate", {"pid": 1, "text": "被外星人绑架3天！"})
	check(app._event_dialog.visible and app._event_dialog_text.text.contains("绑架3天"),
		"question tile opens its concrete fate result")
	var confirm := app._event_dialog.find_child("EventResultOK", true, false) as Button
	await app.get_tree().process_frame
	await click(confirm.get_global_rect().get_center())
	check(not app._event_dialog.visible, "event result closes after confirmation")
	var sim := Net.sim
	var me: Dictionary = sim.players[1]
	me.effects.invisible_until = sim.time + 72.0
	app._on_state(sim.to_dict())
	var actor := app._board._player_nodes[1].get_node("OriginalActor") as OriginalMesh
	check(is_equal_approx(float(actor._materials[0].get_shader_parameter("opacity")), 0.45), "invisible card renders the character half transparent")
	me.effects.invisible_until = 0.0
	app._on_state(sim.to_dict())
	var first_plot := -1
	for i in range(sim.map.tile_count()):
		if str(sim.map.tile(i).get("kind", "")) == "plot":
			first_plot = i
			break
	app._open_house_picker({"options": sim.buildable_types(), "idx": first_plot, "pid": 1})
	var picker := app._house_pick as PanelContainer
	var style := picker.get_theme_stylebox("panel") as StyleBoxFlat
	check(style != null and style.bg_color.a > 0.8
		and picker.position.x >= app.get_viewport().get_visible_rect().size.x * 0.55
		and picker.find_child("HouseChoiceBack", true, false) != null,
		"construction choices use original card backings on an opaque panel farther to the right")
	app._close_house_picker()

func check_pet_refusals() -> void:
	for record in fixtures._pet_world("caishen").pet_catalog():
		var id := str(record.id)
		for condition in ["hungry", "hospital", "sleep"]:
			var sim := fixtures._pet_world(id)
			var p: Dictionary = sim.players[1]
			var pet := sim.active_pet(p)
			match condition:
				"hungry": pet.fullness = 50.0
				"poor": p.credit = 0
				"hospital": p.effects.hospital_until = sim.time + 10
				"sleep": p.effects.sleep_until = sim.time + 10
			var credit := int(p.credit)
			var fullness := float(pet.fullness)
			check(not sim.act_pet_skill(1) and p.credit == credit and pet.fullness == fullness, id + " " + condition + " refuses without charge")
	var sim := fixtures._pet_world("jingling")
	var p: Dictionary = sim.players[1]
	sim.plots[p.tile]["level"] = Rules.house_asset_level("industry", 1, 3)
	check(not sim.act_pet_skill(1) and p.credit == 1000 and sim.active_pet(p).fullness == 100, "blocked snow elf upgrade preserves resources")
	var monster_sim := fixtures._pet_world("guaishou")
	monster_sim.add_player(3, "无精灵对手")
	check(monster_sim.act_pet_skill(1) and not monster_sim.players[2].pets.is_empty() and monster_sim.pet_energy(monster_sim.active_pet(monster_sim.players[2])) < 20.0, "monster damages a nearby equipped pet instead of deleting a reserve")
