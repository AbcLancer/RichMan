extends "res://scripts/ui/card_flow_review.gd"

func run(root) -> void:
	app = root
	output = "res://../docs/screenshots/oct7-review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	app._port_edit.text = "0"
	app._frontend.start_requested.emit({"map": "train", "role": 3, "players": 4, "money": 300000, "credit": 300})
	Net.set_process(false)
	var sim: Sim = Net.sim
	sim.running = false
	sim.time = 10
	var me: Dictionary = sim.players[1]
	me.tile = 53
	me.moving = 0
	me.last_plot = 53
	me.last_plot_kind = "buy"
	check(sim.act_buy(1), "corner lot purchase accepted")
	me.last_plot = 55
	me.last_plot_kind = "upgrade"
	check(sim.act_upgrade(1, "uptown:1"), "corner lot can be built from its second road entrance")
	check(sim.unique_plot_keys().size() == 1 and sim.plots[53] == sim.plots[55], "one shared estate for both entrances")
	# Give the adjacent lots distinct values to compare the estate stacks.
	for key in [50, 51, 52]:
		sim._bind_plot(key, {"owner": 1, "level": 1, "type": "uptown", "paid_base": 3000.0 * (key - 48)})
	for pet in ["dushen", "caishen", "qiongshen", "emo", "jingling"]: sim.add_pet(me, pet)
	me.pet_active = "dushen"
	app._loading.hide()
	app._on_state(sim.to_dict())
	await app.get_tree().create_timer(.3).timeout
	app._open_pet_warehouse()
	await app.get_tree().process_frame
	check(app._shop_base * 256 < 400 * app._ui_scale, "pet warehouse uses compact original proportions")
	var hit := app._shop.get_node("PetHit_caishen") as Button
	var art := app._shop.get_node("PetPortrait_caishen") as TextureRect
	var point := hit.get_global_rect().position + Vector2(10, 10)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await app.get_tree().process_frame
	check(art.modulate.r > 1, "hover brightens the actual pet portrait")
	await shot("pet-warehouse-hover")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = true
	Input.parse_input_event(event)
	await app.get_tree().process_frame
	for pet in me.pets: pet.fullness = float(pet.fullness) - .2
	me.credit -= 1
	app._on_state(sim.to_dict())
	app._sync_shop()
	check(is_instance_valid(hit) and app._shop.get_node("PetHit_caishen") == hit, "changing energy and credit does not rebuild a pressed pet button")
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await app.get_tree().process_frame
	check(app._pet_menu != null, "press-release across a live snapshot opens the pet action menu")
	await shot("pet-use-release-menu")
	if app._pet_menu != null: await click((app._pet_menu.get_child(0).get_child(0) as Button).get_global_rect().get_center())
	check(str(me.pet_active) == "caishen", "pet use menu is clickable")
	app._close_shop()
	app._event_messages.clear()
	app._on_game_event("fate", {"pid": 1, "fate": 12, "text": "被外星人绑架3天！"})
	check(app._event_dialog_art.texture != null and app._event_dialog_art.texture == app._tex_or_null("res://assets/news/31.png"), "question event uses its matching original alien illustration")
	await shot("question-event-illustration")
	await click(app._event_dialog.get_global_rect().get_center())
	check(not app._event_dialog.visible, "illustrated question result closes on click")
	app._show_global_news(7, "银行加发存款利息，\n获得20458元。", 7)
	await shot("bank-event-illustration")
	app._news_pop.hide()
	app._news_left = 0
	sim._send_to_hospital(me, 200, "blast")
	app._on_state(sim.to_dict())
	check(not app._board._player_nodes[1].visible, "hospitalized character is hidden")
	check(not app._board._effects.pets.has("1:caishen"), "hospitalized follower is hidden with the character")
	await shot("hospital-hidden")
	me.effects.hospital_until = 0
	me.stamina = sim.stamina_max()
	app._on_state(sim.to_dict())
	check(app._board._player_nodes[1].visible, "discharged character becomes visible again")
	me.pet_active = "dushen"
	sim.active_pet(me).fullness = 100
	sim.active_pet(me).ready = true
	app._on_state(sim.to_dict())
	await app.get_tree().process_frame
	await click(app._pet_skill_btn.get_global_rect().get_center())
	app._on_state(sim.to_dict())
	check(bool(me.pending_steps) and app._step_picker.visible, "gambling pet activation opens the step selection immediately")
	check(not sim.act_roll(1), "GO cannot bypass pending step selection")
	check(not app._say_bubble.visible or not app._step_picker.get_global_rect().intersects(app._say_bubble.get_global_rect()), "pet speech does not obscure the dice choices")
	await shot("gambling-pet-step-choice")
	await click((app._step_picker.get_child(3) as Control).get_global_rect().get_center())
	check(int(me.last_roll) == 4 and not bool(me.pending_steps), "gambling pet advances by the clicked four steps")
	me.moving = 0
	app._clear_dice_fx()
	var ids := sim.player_ids()
	var sound_before: int = Audio._pool_idx
	var children_before := Audio.get_child_count()
	app._on_game_event("roll", {"pid": ids[1], "role": 2, "faces": [6]})
	app._on_game_event("roll_end", {"pid": ids[1], "role": 2})
	app._on_game_event("pay_rent", {"pid": ids[1], "role": 2, "to": ids[2], "amount": 100})
	check(Audio._pool_idx == sound_before and Audio.get_child_count() == children_before, "other players' dice and rent do not dispatch sound or voices")
	app._on_state(sim.to_dict())
	await click((app._hud.find_child("ViewDataButton", true, false) as Button).get_global_rect().get_center())
	check(app._view_menu.visible, "top magnifier opens the view menu")
	await shot("view-menu")
	await click((app._view_menu.get_child(0).get_child(0) as Button).get_global_rect().get_center())
	check(app._data_view.visible and app._data_view.rows.size() > 0, "stock inspection opens with live market data")
	await shot("stock-inspection")
	var old_first: String = app._data_view.rows[0]["values"][0]
	await click((app._data_view.get_node("NextStockPage") as Button).get_global_rect().get_center())
	check(str(app._data_view.rows[0]["values"][0]) != old_first, "stock inspection can page through every company")
	app._close_topmost()
	# Return from the hospital to the purchased corner before inspecting coins.
	me.tile = 53
	app._on_state(sim.to_dict())
	await app.get_tree().create_timer(.35).timeout
	app._toggle_view_menu()
	await app.get_tree().process_frame
	await click((app._view_menu.get_child(0).get_child(2) as Button).get_global_rect().get_center())
	check(app._data_view.mode == "ranking" and app._data_view.rows.size() == 4, "rankings include every player")
	await shot("ranking")
	app._close_topmost()
	app._toggle_view_menu()
	await app.get_tree().process_frame
	await click((app._view_menu.get_child(0).get_child(1) as Button).get_global_rect().get_center())
	check(app._board.estate_view and app._board._estate_coins.get_child_count() == sim.unique_plot_keys().size(), "estate view creates one value stack for each actual estate")
	check(not app._board._level_nodes[53].visible, "estate view hides buildings")
	var cheap: Node3D = app._board._estate_coins.get_node("EstateCoins53")
	var expensive: Node3D = app._board._estate_coins.get_node("EstateCoins52")
	check(int(expensive.get_meta("coin_count")) > int(cheap.get_meta("coin_count")), "more valuable estates have taller coin stacks")
	await shot("estate-coins")
	await click(Vector2(500, 300))
	check(not app._board.estate_view and app._board._level_nodes[53].visible, "any click restores buildings and exits estate view")
	print("OCT7 REVIEW: %d checks, %s" % [checks, "FAIL" if failed else "PASS"])
	app.get_tree().quit(1 if failed else 0)
