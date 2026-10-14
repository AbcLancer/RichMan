extends "res://scripts/ui/card_flow_review.gd"
## Deterministic arrivals plus production mouse controls, with rendered evidence.

func hover(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	Input.parse_input_event(event)
	await app.get_tree().process_frame

func run(root) -> void:
	app = root
	output = "res://../docs/screenshots/presentation-review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	app._port_edit.text = "0"
	app._frontend.start_requested.emit({"map": "aiji", "role": 5, "players": 3, "money": 300000, "credit": 1000})
	Net.set_process(false)
	var sim: Sim = Net.sim
	sim.time = 10.0
	var me: Dictionary = sim.players[1]
	me.last_plot_kind = ""
	app._loading.hide()
	app._on_state(sim.to_dict())
	await app.get_tree().create_timer(.3).timeout
	var ids := sim.player_ids()
	var actor := app._board._player_nodes[1].get_node("OriginalActor") as OriginalMesh
	# Each remote event may animate on the board, but must not alter local feedback.
	var remote_events := ["roll", "roll_end", "buy", "upgrade", "get_card", "pay_rent", "get_pet", "pet_skill", "use_card",
		"road_god", "road_crystal", "road_hanbao", "road_chest", "road_bomb", "road_thief", "stock_buy", "stock_sell", "sealed_rent"]
	for kind in remote_events:
		app._toast_lbl.text = "本地提示"
		var voices := Audio._pool_idx
		app._on_game_event(kind, {"pid": ids[1], "role": 2, "to": ids[2], "amount": 500, "gain": 500,
			"pet": "caishen", "card": "missile", "name": "对手", "god": "caishen", "god_cn": "财神"})
		check(Audio._pool_idx == voices and app._toast_lbl.text == "本地提示",
			"remote %s cannot play local audio or overwrite local text" % kind)
	check(app._money_reel == null or not app._money_reel.visible, "remote god does not open local money reel")
	check(app._char_expression == "01", "remote actions cannot change local portrait")
	app._on_game_event("win_money", {"pid": 1, "role": 5, "amount": 500})
	check(actor._clip == "glad" and app._char_avatar.texture == app._role_texture(4, "03"), "reward synchronizes actor and original happy portrait")
	app._on_state(sim.to_dict())
	check(app._char_avatar.texture == app._role_texture(4, "03"), "snapshot cannot immediately erase reward expression")
	await shot("role-reward")
	app._on_game_event("pay_rent", {"pid": 1, "role": 5, "to": ids[1], "amount": 500, "idx": 0})
	check(actor._clip == "sad" and app._char_avatar.texture == app._role_texture(4, "02"), "rent payment synchronizes sad animation and portrait")
	await shot("role-pay-rent")
	app._on_game_event("pay_rent", {"pid": ids[1], "to": 1, "amount": 500, "idx": 0})
	check(app._char_avatar.texture == app._role_texture(4, "03"), "local landlord receives own rent reward expression")
	await app.get_tree().create_timer(2.7).timeout
	check(app._char_avatar.texture == app._role_texture(4, "01"), "temporary expression returns to idle")
	# Card-specific voice must be selected rather than a generic actor line.
	me.cards = ["missile", "hamburger", "step3", "step3", "step3"]
	app._on_state(sim.to_dict())
	await app.get_tree().process_frame
	var count_badge: Label = app._card_slots[2].cnt
	check(count_badge != null and count_badge.get_global_rect().position.y > app._card_slots[2].box.get_global_rect().position.y + app._card_slots[2].box.size.y * .65, "stack count occupies the actual lower left corner")
	app._on_game_event("use_card", {"pid": 1, "role": 5, "card": "missile"})
	var voice_path := "res://assets/audio/voice/role5/card/%02d.wav" % app._card_n("missile")
	check(Audio._pool.any(func(player): return player.playing and player.stream.resource_path == voice_path), "card-specific original narration is connected")
	check(is_instance_valid(app._used_card_face) and app._used_card_face.mouse_filter == Control.MOUSE_FILTER_IGNORE, "used card flight preserves underlying input")
	await app.get_tree().create_timer(.55).timeout
	await shot("card-flight")
	app._clear_used_card()
	# Whole portrait including its corner, hover and context actions.
	for pet_id in ["dushen", "caishen", "emo", "hutu", "jingling"]: sim.add_pet(me, pet_id)
	app._on_state(sim.to_dict())
	await click((app._char_panel.get_node("PetInventoryButton") as Button).get_global_rect().get_center())
	check(app.shop_open() and app._shop_mode == "warehouse", "actual HUD portrait opens warehouse")
	var targets: Array = app._shop.find_children("PetHit_*", "Button", true, false)
	check(targets.size() == 4, "five owned pets produce exactly four reserve targets")
	var hit := targets[0] as Button
	var pet_id := str(hit.name).trim_prefix("PetHit_")
	var portrait := app._shop.get_node("PetPortrait_" + pet_id) as TextureRect
	await hover(hit.get_global_rect().get_center())
	check(portrait.modulate.r > 1.0, "reserve pet brightens under cursor")
	await shot("pet-hover")
	await click(hit.get_global_rect().position + Vector2(2, 2))
	check(is_instance_valid(app._pet_menu), "portrait outer edge opens actions on one click")
	var actions: Array = app._pet_menu.find_children("*", "Button", true, false)
	check(actions.size() == 2 and actions[0].text == "使用" and actions[1].text == "放生", "original two-action menu is readable")
	check(actions[0].get_theme_color("font_color").r > .7 and (actions[0].get_theme_stylebox("normal") as StyleBoxFlat).bg_color.g > .9, "pet actions use pale buttons and red labels")
	app._show_say("我是人见人爱的小财神", 1)
	check(not app._say_bubble.visible, "foreground pet controls cannot be obscured by world dialogue")
	await shot("pet-actions")
	await click((actions[0] as Button).get_global_rect().get_center())
	check(str(sim.active_pet(me).id) == pet_id and not is_instance_valid(app._pet_menu), "actual use action swaps pet and closes menu")
	app._close_shop()
	# Native step selection is an actual actionable UI, not a successful-looking toast.
	sim.act_set_active_pet(1, "dushen")
	var pet := sim.active_pet(me)
	pet.fullness = 10.0
	app._on_state(sim.to_dict())
	check(app._pet_slot.texture == app._tex_or_null(Rules.pet_art("dushen", "face", 2)), "low-energy gambler uses native HUD state 1")
	await shot("pet-low-energy")
	pet.fullness = 100.0
	app._on_state(sim.to_dict())
	check(app._pet_slot.texture == app._tex_or_null(Rules.pet_art("dushen", "face", 3)) and app._pet_skill_btn.visible, "full-energy pet uses native HUD state 2 and skill entrance")
	await shot("pet-ready")
	await click(app._pet_skill_btn.get_global_rect().get_center())
	check(app._step_picker.visible and bool(me.pending_steps), "gambler skill opens step selection")
	check(Audio._pool.any(func(player): return player.playing and player.stream.resource_path == "res://assets/audio/voice/pet/dushen/01.wav"), "pet skill uses its original skill voice")
	await shot("gambler-step-selection")
	await click((app._step_picker.get_child(2) as Control).get_global_rect().get_center())
	check(not bool(me.pending_steps) and int(me.moving) == 3, "step selection starts exactly the chosen movement")
	me.moving = 0
	app._on_state(sim.to_dict())
	# Native victim pet lines, filtered to the owning player.
	for line in [6, 8, 9]:
		for player in Audio._pool: player.stop()
		var kind := "pet_flew_away" if line == 9 else "pet_attacked"
		app._on_game_event(kind, {"pid": 2, "pet": "dushen", "voice_line": line})
		check(not Audio._pool.any(func(player): return player.playing), "remote pet voice remains silent " + str(line))
		app._on_game_event(kind, {"pid": 1, "pet": "dushen", "voice_line": line})
		var sound := "res://assets/audio/voice/pet/dushen/%02d.wav" % line
		check(Audio._pool.any(func(player): return player.playing and player.stream.resource_path == sound), "native local pet voice " + str(line))
	# Question-only illustrated confirmation and ordered queued messages.
	app._on_game_event("fate", {"pid": 1, "text": "意外获得奖励20458元。", "fate": 4})
	check(app._event_dialog.visible and app._event_dialog_art.texture != null and app._event_dialog_text.text.contains("20458"), "question event combines original illustration and populated result")
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	Input.parse_input_event(space)
	await app.get_tree().process_frame
	space = InputEventKey.new()
	space.keycode = KEY_SPACE
	Input.parse_input_event(space)
	await app.get_tree().process_frame
	check(int(me.moving) == 0 and app._event_dialog.visible, "space cannot start movement through an unconfirmed question panel")
	app._on_game_event("fate", {"pid": 1, "text": "被外星人绑架3天！", "fate": 10})
	await shot("question-illustration")
	var confirm := app._event_dialog.get_node("EventResultOK") as Button
	await click(confirm.get_global_rect().get_center())
	check(app._event_dialog.visible and app._event_dialog_text.text.contains("绑架3天"), "one confirmation advances to the queued result")
	await click(confirm.get_global_rect().get_center())
	check(not app._event_dialog.visible, "last question confirmation closes the panel")
	app._on_game_event("road_god", {"pid": 1, "role": 5, "god": "qiongshen", "god_cn": "穷神", "amount": 48363})
	check(app._money_reel.visible, "local god opens its money reel")
	check(app._money_reel_digits.reels.size() == 6 and app._money_reel_digits.reels[0].clip_contents, "money display uses six independently clipped reels")
	var real_digit := app._money_reel_digits.reels[0].get_child(0) as Label
	check(real_digit.get_theme_color("font_color").g > .9 and real_digit.get_theme_font_size("font_size") >= 26, "rendered reel glyph itself is large and yellow")
	await app.get_tree().create_timer(.25).timeout
	await shot("god-money-reel")
	await app.get_tree().create_timer(.75).timeout
	var settled := ""
	for reel in app._money_reel_digits.reels: settled += (reel.get_child(0) as Label).text
	check(settled == "048363", "all money reels settle on the authoritative amount")
	await shot("god-money-reel-settled")
	# Construction and demolition effects belong on the building, not the road.
	var plot_idx := -1
	for idx in range(sim.map.tile_count()):
		if sim.map.is_plot(idx): plot_idx = idx; break
	sim.plots[plot_idx] = {"owner": 1, "level": 1, "type": "industry", "anchor": plot_idx}
	app._on_state(sim.to_dict())
	var place: Vector3 = app._board.plot_pos_of(plot_idx)
	for kind in ["upgrade", "downgrade"]:
		app._on_game_event(kind, {"pid": 1, "role": 5, "idx": plot_idx})
		var effects: WorldEffects = app._board._effects
		var last: Dictionary = effects.transients.back()
		check(last.kind == "mesh" and last.node.global_position.distance_to(place) < .001, kind + " visual is centered on the estate")
	await shot("construction-effects")
	# A joint-rent event flashes every physical building, then restores shared
	# textures/materials without permanently tinting another property.
	var second_plot := -1
	for idx in range(plot_idx + 1, sim.map.tile_count()):
		if sim.map.is_plot(idx): second_plot = idx; break
	sim.plots[second_plot] = {"owner": 1, "level": 1, "type": "industry", "anchor": second_plot}
	app._on_state(sim.to_dict())
	var models: Array = []
	var bases: Array = []
	for idx in [plot_idx, second_plot]:
		var model := app._board._level_nodes[idx].get_node("Model") as MeshInstance3D
		models.append(model)
		bases.append(model.material_override)
	app._on_game_event("pay_rent", {"pid": ids[1], "to": 1, "amount": 500, "idx": plot_idx,
		"joint_members": [plot_idx, second_plot, second_plot]})
	await app.get_tree().create_timer(.39).timeout
	for i in range(models.size()):
		var red := models[i].material_override as StandardMaterial3D
		check(red != bases[i] and red.albedo_color == Color(1, 0, 0), "joint rent highlights building %d" % i)
		check(red.albedo_texture == bases[i].albedo_texture, "rent highlight preserves building %d texture" % i)
	await shot("joint-rent-buildings")
	await app.get_tree().create_timer(1.8).timeout
	check(models[0].material_override == bases[0] and models[1].material_override == bases[1], "both rent highlights restore after native two seconds")
	# Real view menu entrances, safe closures and reopening the collapsed HUD.
	await click((app._hud.find_child("ViewDataButton", true, false) as Button).get_global_rect().get_center())
	check(app._view_menu.visible, "magnifier responds to actual click")
	var view_actions: Array = app._view_menu.find_children("*", "Button", true, false)
	await click((view_actions[0] as Button).get_global_rect().get_center())
	check(is_instance_valid(app._data_view) and app._data_view.visible and app._data_view.rows.size() > 0, "stock inspection opens populated data")
	await shot("stocks")
	app._close_topmost()
	app._open_data_view("排行榜")
	check(app._data_view.visible and app._data_view.rows.size() == 3, "rankings include every player")
	await shot("ranking")
	app._close_topmost()
	app._open_data_view("地产图")
	check(app._board.estate_view, "estate inspection switches world presentation")
	await click(Vector2(400, 80))
	check(not app._board.estate_view, "one click restores normal buildings")
	app._toggle_br()
	check(app._br_collapsed and app._br_box.visible, "collapsed HUD keeps its control bar visible")
	app._set_br_page(2)
	check(not app._br_collapsed and app._minimap.visible, "choosing map restores expanded HUD")
	print("PRESENTATION REVIEW: %d checks, %s" % [checks, "FAIL" if failed else "PASS"])
	app.get_tree().quit(1 if failed else 0)
