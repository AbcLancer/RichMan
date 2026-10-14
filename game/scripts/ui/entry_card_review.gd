extends "res://scripts/ui/card_flow_review.gd"

func hover(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await app.get_tree().create_timer(.18).timeout

func run(root) -> void:
	app = root
	output = "res://../docs/screenshots/entry-card-review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for map_id in ["aiji", "china", "japan", "paris", "island", "space", "train"]:
		var sim := Sim.new()
		sim.setup(MapData.load_from(map_id), 8021)
		for id in range(1, 5): sim.add_player(id, "玩家%d" % id)
		sim.begin_entry()
		var positions: Array = []
		for player in sim.players.values(): positions.append(player.tile)
		check(positions.size() == 4 and positions.duplicate().reduce(func(acc, v):
			if not acc.has(v): acc.append(v)
			return acc, []).size() == 4, map_id + " has distinct random landing nodes")
		check(not sim.act_roll(1) and sim.players[1].moving == 0, map_id + " entry cannot move early")
		var restored := Sim.new()
		restored.setup(sim.map, 0)
		restored.apply_dict(sim.to_dict())
		check(restored.players[1].tile == sim.players[1].tile and restored.players[1].entry_until == Sim.ENTRY_SECONDS, map_id + " landing state survives snapshot/save")
	app._port_edit.text = "0"
	app._frontend.start_requested.emit({"map": "aiji", "role": 5, "players": 4, "money": 300000, "credit": 100})
	Net.set_process(false)
	app._loading.hide()
	var sim: Sim = Net.sim
	var me: Dictionary = sim.players[1]
	sim.time = 1.3
	app._on_state(sim.to_dict())
	await app.get_tree().create_timer(.1).timeout
	var player: Node3D = app._board._player_nodes[1]
	check(player.get_node("Parachute").get_child_count() == 7 and player.get_node("Parachute").visible and player.position.y > app._board._player_target[1].y + 3, "original seven-part parachute descends above the road")
	check(not app._go_btn.visible, "GO stays hidden during entry")
	await shot("parachute-entry")
	sim.time = 3.1
	app._on_state(sim.to_dict())
	await app.get_tree().create_timer(.3).timeout
	check(not player.get_node("Parachute").visible and app._go_btn.visible, "landing removes canopy and unlocks GO")
	me.cards = ["hamburger", "step3", "stay"]
	sim.act_lock_card(1, "hamburger")
	app._on_state(sim.to_dict())
	await app.get_tree().process_frame
	var slot: Dictionary = app._card_slots[0]
	check(slot.lock.visible and slot.lock.size.x <= slot.box.size.x * .25 and slot.lock.size.y <= slot.box.size.y * .25, "lock clamp stays a small bottom icon")
	await hover(slot.btn.get_global_rect().get_center())
	check(slot.box.scale.x > 1.1 and slot.box.z_index == 5 and slot.img.modulate.r > slot.base_modulate.r, "real cursor hover enlarges and highlights a locked card")
	await shot("card-hover-lock")
	await hover(Vector2(5, 100))
	check(is_equal_approx(slot.box.scale.x, 1.0) and slot.img.modulate == slot.base_modulate, "cursor exit restores card size and tint")
	await click(slot.btn.get_global_rect().get_center())
	check(app._card_menu.visible and app._card_menu_btns[0].text == Rules.card_menu_label("lock"), "hovered card retains menu hit area")
	app._hide_card_menu()
	check(sim.act_roll(1, 2), "roll starts after entry")
	app._on_state(sim.to_dict())
	check(player.get_node_or_null("Dice") == null, "no persistent giant dice above actor")
	check(app._dice_fx.size() == 2, "roll creates two temporary dice")
	var arc_origin: Vector2 = app._dice_fx_from[0]
	var arc_end: Vector2 = app._dice_fx_to[0]
	check(arc_end.x < arc_origin.x - 30 * app._ui_scale, "dice land left of the launch point")
	app._dice_fx_t = app.DIE_FLY_TIME * .5
	app._tick_dice(0)
	var center: Vector2 = app._dice_fx[0].position + app._dice_fx[0].size * .5
	check(center.y < arc_origin.lerp(arc_end, .5).y - 80 * app._ui_scale, "dice arc rises then returns toward the landing point")
	await shot("dice-left-arc")
	app._dice_fx_t = app.DIE_FLY_TIME
	app._tick_dice(0)
	check(app._dice_fx_state == "hold", "throw settles on its rolled faces")
	app._tick_dice(app.DIE_HOLD_TIME + .1)
	check(app._dice_fx.is_empty(), "temporary dice clear after result display")
	print("ENTRY CARD REVIEW: %d checks, %s" % [checks, "FAIL" if failed else "PASS"])
	app.get_tree().quit(1 if failed else 0)
