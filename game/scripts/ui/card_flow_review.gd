extends RefCounted
## Regression review through production controls and real mouse events.
var app
var checks := 0
var failed := false
var output := "res://../docs/screenshots/card-flow-review"

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("CARD FLOW FAIL: " + message)
	print("CARD FLOW %s: %s" % ["PASS" if value else "FAIL", message])

func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await app.get_tree().process_frame
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await app.get_tree().process_frame
	await app.get_tree().process_frame

func shot(name: String) -> void:
	if OS.get_cmdline_user_args().has("--audit-no-shots"): return
	await RenderingServer.frame_post_draw
	app.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(output + "/" + name + ".png"))

func run(root) -> void:
	app = root
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	app._port_edit.text = "0"
	app._frontend.start_requested.emit({"map": "aiji", "role": 3, "players": 4, "money": 300000, "credit": 100})
	Net.set_process(false)
	Net.sim.running = false
	var sim: Sim = Net.sim
	sim.time = Sim.ENTRY_SECONDS + .1 # This review starts after the entry presentation.
	var ids := sim.player_ids()
	var me: Dictionary = sim.players[1]
	var rival: Dictionary = sim.players[ids[1]]
	var roles: Array = []
	for player in sim.players.values():
		check(not roles.has(player.role), "role %d is unique" % player.role)
		roles.append(player.role)
	me.tile = 0
	rival.tile = 1
	me.last_plot_kind = ""
	me.effects.sleep_until = 0.0
	app._on_state(sim.to_dict())
	app._loading.hide()
	await app.get_tree().create_timer(.5).timeout
	# The confirmation sits over the nuclear card as in the reported screenshot.
	sim.card_shop_stock = ["stay", "qingshen", "step3", "nuke", "emo", "run", "dice", "mine"]
	app._shop_stock = sim.card_shop_stock.duplicate()
	app._open_shop("cardshop")
	await app.get_tree().process_frame
	var selected: Button
	for node in app._shop_nodes:
		if node is Button and node.text.begins_with(Rules.card_name("qingshen")): selected = node
	check(selected != null, "real shop button exists")
	if selected == null:
		app.get_tree().quit(1)
		return
	await click(selected.get_global_rect().get_center())
	check(app._shop_pending == "card:qingshen", "shop selection opens the intended confirmation")
	await shot("shop-confirmation")
	# A click elsewhere is swallowed without replacing the pending purchase.
	await click(app._shop_bg.get_global_rect().get_center() + Vector2(100, 120))
	check(app._shop_pending == "card:qingshen", "modal blocks underlying shop clicks")
	var credit_before := int(me.credit)
	await click(app._pop_yes.get_global_rect().get_center())
	check(me.cards.has("qingshen") and not me.cards.has("nuke"), "yes buys the selected card and never nuclear card underneath")
	check(int(me.credit) == credit_before - sim.card_price("qingshen"), "purchase charged once")
	check(not app._pop.visible, "confirmation closes after purchase")
	check(not app._shop_stock.has("qingshen"), "purchased card disappears from visible stock")
	check(not sim.act_buy_card(1, "qingshen"), "stale repeat purchase is rejected")
	app._close_shop()
	# Enter through the card menu, then click a highlighted route point.
	me.cards = ["roadblock", "clear", "rob"]
	app._on_state(sim.to_dict())
	await app.get_tree().process_frame
	app._on_card_clicked(app._card_ids.find("roadblock"))
	app._on_card_menu("use")
	check(app._card_pending == "roadblock" and sim.obstacles.is_empty(), "roadblock waits for point selection")
	var target := 2
	var point: Vector2 = app._board._cam().unproject_position(app._board._pos_of(target))
	check(app._board._road_target_nodes[target].visible, "eligible road points are highlighted")
	await shot("road-targets")
	await click(point)
	check(not sim._obstacle_at(target).is_empty() and sim._obstacle_at(1).is_empty(), "mouse-selected roadblock is placed on chosen point")
	check(not me.cards.has("roadblock"), "roadblock consumed exactly after success")
	# Road garbage belongs to a separate dictionary from placed obstacles.
	sim.road_objs[3] = {"kind": "bomb", "born": 0}
	check(sim.card_usable(1, "clear") == 0, "clear recognizes road garbage")
	check(sim.act_use_card(1, "clear", 3) and not sim.road_objs.has(3), "clear removes chosen garbage")
	me.cards.append("roadblock")
	check(not sim.act_use_card(1, "roadblock", 30) and me.cards.has("roadblock"), "out-of-range road target rejected without losing card")
	app._on_state(sim.to_dict())
	app._set_card_target_mode("roadblock")
	app._close_topmost()
	check(app._card_pending == "" and me.cards.has("roadblock"), "cancel retains card and exits selection")
	# Green player selection survives repeated snapshots.
	rival.cards = ["step2"]
	app._on_state(sim.to_dict())
	app._set_card_target_mode("rob")
	app._on_state(sim.to_dict())
	var material: StandardMaterial3D = app._board._player_mats[int(rival.id)]
	check(material.albedo_color.g > .8 and material.albedo_color.r < .5, "valid rival remains green after snapshot")
	await shot("player-targets")
	await click(app._board.player_screen_positions()[int(rival.id)])
	check(me.cards.has("step2") and not me.cards.has("rob") and rival.cards.is_empty(), "real world click selects rival and steals card")
	# Unusable clear can still be fed to the selected hungry pet.
	sim.obstacles.clear()
	sim.road_objs.clear()
	sim.add_pet(me, "qiongshen")
	sim.add_pet(me, "tushen")
	me.cards = ["clear"]
	app._on_state(sim.to_dict())
	app._on_card_clicked(app._card_ids.find("clear"))
	check(app._card_menu_btns[1].disabled and not app._card_menu_btns[2].disabled, "use disabled and feed enabled independently")
	app._on_card_menu("feed")
	check(not me.cards.has("clear") and float(me.pets[0].fullness) > Sim.PET_START_FULLNESS
		and float(me.pets[1].fullness) == Sim.PET_START_FULLNESS,
		"feed increases only selected pet fullness")
	check(app._board._effects.pets.size() == 1, "two owned pets produce only one follower")
	me.credit = 1000
	me.pets[1].fullness = Sim.PET_FULLNESS_MAX
	sim.time = 100
	sim._tick_pets(me)
	check(float(me.pets[1].fullness) == Sim.PET_FULLNESS_MAX and int(me.credit) == 1000, "inactive full pet does not activate or charge")
	app._open_pet_warehouse()
	await app.get_tree().process_frame
	var pet_button: Button
	for node in app._shop_nodes:
		if node is Button and node.text.contains(sim.pet_name("tushen")): pet_button = node
	check(pet_button != null, "owned inactive pet appears in backpack")
	if pet_button != null:
		await click(pet_button.get_global_rect().get_center())
		if app._pet_menu != null:
			await click((app._pet_menu.get_child(0).get_child(0) as Button).get_global_rect().get_center())
	check(str(me.pet_active) == "tushen", "actual backpack click switches active pet")
	app._close_shop()
	check(app._board._effects.pets.has("1:tushen") and not app._board._effects.pets.has("1:qiongshen"), "switch replaces previous follower")
	# Dice phase must stay standing, then move into run at scheduled start.
	check(sim.act_roll(1), "real roll action accepted")
	app._on_state(sim.to_dict())
	var actor: OriginalMesh = app._board._player_nodes[1].get_node("OriginalActor")
	check(actor._clip == "stan", "dice delay keeps standing")
	sim.time = float(me.move_after) + .01
	app._on_state(sim.to_dict())
	check(actor._clip == "run", "run starts at actual movement time")
	me.moving = 0
	# Both bidding and PASS must work with real pointer clicks.
	sim.auction = {"tile": 0, "price": 2760, "best": -1, "name": "", "until": 150.0, "passed": []}
	app._auction.open("测试街道", 2760, "", .8)
	app._show_global_news(13, "公开拍卖测试街道一处公有土地", 13)
	check(app._auction.position.x < 30, "auction positioned on left")
	await shot("auction-left")
	await click(app._auction.get_node("BidButton").get_global_rect().get_center())
	check(int(sim.auction.price) == 2860 and int(sim.auction.best) == 1,
		"actual auction bid works while its global news illustration is visible")
	app._news_pop.hide()
	await click(app._auction.get_node("PassButton").get_global_rect().get_center())
	check(not app._auction.visible and sim.auction.passed.has(1), "actual PASS click closes and withdraws")
	check(not sim.act_auction_bid(1, 100), "passed player cannot bid again in this auction")
	sim.act_auction_bid(int(rival.id), 100)
	await app.get_tree().process_frame
	check(not app._auction.visible, "other player bid never reopens passed auction")
	# Full hands used to lose a different card because effects replaced the array.
	me.cards = ["rob", "step1", "step2", "step3", "step4"]
	rival.cards = ["hamburger"]
	check(sim.act_use_card(1, "rob", int(rival.id)) and me.cards.has("hamburger") and not me.cards.has("rob") and me.cards.has("step1"), "full-hand theft uses consumed slot without deleting another card")
	me.cards = ["rob"]
	rival.cards = []
	check(not sim.act_use_card(1, "rob", int(rival.id)) and me.cards.has("rob"), "failed theft restores used card")
	me.cards = ["copy", "step1", "hamburger"]
	app._on_state(sim.to_dict())
	app._on_card_clicked(app._card_ids.find("copy"))
	app._on_card_menu("use")
	check(app._card_pending == "copy", "copy waits for another hand card selection")
	var copied_slot: Control = app._card_slots[app._card_ids.find("hamburger")].box
	await click(copied_slot.get_global_rect().get_center())
	check(me.cards.count("hamburger") == 2 and not me.cards.has("copy") and me.cards.count("step1") == 1, "actual hand click copies chosen card instead of first card")
	# Missile targeting uses the same production menu and mouse path as road cards,
	# including the building platform rather than only the road center.
	me.tile = 0
	me.moving = 0
	me.effects.hospital_until = 0.0
	rival.tile = 2
	rival.effects.invincible_until = 0.0
	rival.effects.sleep_until = 0.0
	rival.stamina = 100.0
	me.cards = ["missile", "shuaishen"]
	sim.plots[2] = {"owner": int(rival.id), "level": 2, "type": "industry"}
	app._on_state(sim.to_dict())
	app._on_card_clicked(app._card_ids.find("missile"))
	app._on_card_menu("use")
	check(app._card_pending == "missile" and sim.pending_card_impacts.is_empty(), "missile waits for map selection instead of exploding under caster")
	var platform_point: Vector2 = app._board._cam().unproject_position(app._board._building_spot(2))
	check(app._board.nearest_card_tile_to_screen(platform_point, sim.card_road_candidates(1, "missile"), true) == 2, "building platform resolves to its original road frontage")
	await click(platform_point)
	check(sim.pending_card_impacts.size() == 1 and int(sim.pending_card_impacts[0].idx) == 2, "actual building click launches missile at selected plot")
	check(int(sim.plots[2].level) == 2, "building remains intact during flight")
	await shot("missile-flight")
	sim.running = true
	sim.step(1.01)
	sim.running = false
	app._on_state(sim.to_dict())
	check(int(sim.plots[2].level) == 1 and float(rival.effects.get("hospital_until", 0)) > sim.time, "selected plot downgrades and nearby exhausted player is hospitalized")
	var rival_tag: Label3D = app._board._player_nodes[int(rival.id)].get_node("Tag")
	check(not rival_tag.visible, "ordinary names, cash and hospital text stay off the player's head")
	await shot("missile-impact")
	rival.effects.hospital_until = 0.0
	me.effects.hospital_until = 0.0
	me.cards = ["shuaishen"]
	check(sim.act_use_card(1, "shuaishen", int(rival.id)), "shuaishen target action succeeds")
	app._on_state(sim.to_dict())
	var god_icon := app._board._player_nodes[int(rival.id)].get_node("GodIcon") as Sprite3D
	var god_steps := app._board._player_nodes[int(rival.id)].get_node("GodSteps") as Label3D
	check(god_icon.visible and god_steps.visible and god_steps.text == "30" and
		god_steps.modulate.g > god_steps.modulate.r, "god portrait and green remaining steps stay visible after the toast")
	await app.get_tree().create_timer(1.6).timeout
	await shot("shuaishen-status")
	sim.card_shop_stock.clear()
	sim.card_shop_initialized = true
	check(sim._shop_stock().is_empty(), "sold-out shop never silently refills")
	print("CARD FLOW REVIEW: %d checks, %s" % [checks, "FAIL" if failed else "PASS"])
	app.get_tree().quit(1 if failed else 0)
