extends "res://scripts/ui/card_flow_review.gd"
## Walk real frontend and menu controls; deterministic fixtures exercise arrivals
## that otherwise require several laps. Test saves never overwrite the user's slot.

func press(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await app.get_tree().process_frame
	event = InputEventKey.new()
	event.keycode = key
	event.pressed = false
	Input.parse_input_event(event)
	await app.get_tree().process_frame

func menu_click(name: String) -> void:
	await app.get_tree().process_frame
	var node: Control = app._session_menu_box.get_node(name)
	await click(node.get_global_rect().get_center())

func frontend_click(name: String) -> void:
	await app.get_tree().process_frame
	var node: Control = app._frontend.canvas.get_node(name)
	await click(node.get_global_rect().get_center())
	await app.get_tree().process_frame

func run(root) -> void:
	app = root
	output = "res://../docs/screenshots/play-flow-review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	app._save_path = "user://saves/play-flow-review.r6save"
	app._port_edit.text = "0"
	await frontend_click("Single")
	check(app._frontend.page == "single", "single-player page opens by actual click")
	await frontend_click("NewGame")
	check(app._frontend.page == "selmap", "new-game map page opens by actual click")
	await frontend_click("Map_china")
	await frontend_click("Confirm")
	check(app._frontend.page == "start" and app._frontend.selected_map == "china", "map choice reaches options")
	await frontend_click("Role_1")
	await frontend_click("StartGame")
	check(app.screen == app.Screen.GAME and Net.sim.players[1].role == 1, "selected role and map start a real session")
	Net.set_process(false)
	app._loading.hide()
	var sim: Sim = Net.sim
	sim.time = Sim.ENTRY_SECONDS + .1 # The separate entry review covers the landing phase.
	var me: Dictionary = sim.players[1]
	me.moving = 0
	me.effects.sleep_until = 0.0
	me.last_plot_kind = ""
	app._on_state(sim.to_dict())
	await press(KEY_ESCAPE)
	check(app._session_menu.visible and Net.sim == sim and app.get_tree().paused, "ESC opens safe game menu without destroying session")
	await shot("game-menu")
	var cash := int(me.money)
	Net.send_action("roll")
	check(int(me.moving) == 0 and int(me.money) == cash, "paused menu rejects gameplay actions")
	await press(KEY_ESCAPE)
	check(not app._session_menu.visible and not app.get_tree().paused and Net.sim == sim, "ESC closes menu and resumes same game")
	app._toggle_pause()
	await press(KEY_SPACE)
	check(not app._paused and int(me.moving) == 0, "any-key pause resume does not also roll dice")
	# Pick a legal China parcel that permits all available first-level types.
	var tile := -1
	for i in range(sim.map.tile_count()):
		if str(sim.map.tile(i).get("kind", "")) != "plot": continue
		sim.plots[i] = {"owner": 1, "level": 0, "type": ""}
		for tid in sim.buildable_types():
			if not sim.construction_plan(1, i, str(tid)).is_empty(): tile = i
		if tile >= 0: break
	check(tile >= 0, "map contains a buildable parcel")
	me.tile = tile
	me.last_plot = tile
	me.last_plot_kind = "upgrade"
	me.money = 300000
	app._on_state(sim.to_dict())
	# The original opens construction cards directly on an owned empty parcel.
	app._board.focus_on(app._board._player_target[1])
	await app.get_tree().create_timer(.15).timeout
	check(app._house_pick != null and me.last_plot_kind == "upgrade", "owned empty parcel opens construction choices directly")
	if app._house_pick == null:
		await shot("failed-construction")
		print("CONSTRUCTION STATE: ", [me.last_plot_kind, app._pop_mode, app._btn_bldtype.visible, sim.buildable_types()])
		app.get_tree().quit(1)
		return
	var selected: Button
	for node in app._house_pick.find_children("*", "Button", true, false):
		if not node.disabled: selected = node; break
	check(selected != null, "house picker receives parcel id and enables valid choices")
	await shot("house-picker")
	if selected != null: await click(selected.get_global_rect().get_center())
	check(int(sim.plots[tile].level) > 0 and int(me.money) < 300000 and me.last_plot_kind == "", "actual house choice builds, charges once and releases GO")
	# Persist the moving timer, statuses, active pet, merged estate aliases,
	# economy/lottery/RNG and pending impact, then load through the real frontend.
	me.cards = ["missile", "shuaishen", "dice"]
	sim.add_pet(me, "caishen")
	sim.estate_index = 15.0
	sim.estate_month = 5
	sim.lotto_prize = 12345
	sim.lotto_numbers[4] = 1
	sim.lotto_last_draw_day = 3
	sim.pending_card_impacts = [{"idx": tile, "owner": 1, "range": 5, "damage": 700, "card": "missile", "at": sim.time + 1}]
	me.effects.no_upgrade_steps = 29
	sim.road_objs[tile] = {"kind": "caishen"}
	app._on_state(sim.to_dict())
	var saved_cash := int(me.money)
	# Keep autonomous AI decisions outside the save-restore assertion window.
	for ai_id in Net.ai_ids: Net._ai_next[ai_id] = sim.time + 10.0
	var expected_rng := sim.rng.state
	var ids := Net.ai_ids.duplicate()
	await press(KEY_ESCAPE)
	await menu_click("Save")
	check(FileAccess.file_exists(app._save_path) and not app.get_tree().paused, "actual save button writes test slot and resumes")
	Net.set_process(false)
	check(Net.save_singleplayer(app._save_path) == OK and FileAccess.file_exists(app._save_path + ".bak"), "saving again replaces slot and preserves previous backup")
	await press(KEY_ESCAPE)
	await menu_click("Return")
	check(Net.sim == sim and app._session_menu.visible, "return requires a separate confirmation")
	await menu_click("Leave")
	check(Net.sim == null and not app.get_tree().paused and app._frontend.page == "entry", "confirmed return clears pause and returns to main menu")
	await frontend_click("Single")
	await frontend_click("LoadGame")
	Net.set_process(false)
	app._loading.hide()
	check(app.screen == app.Screen.GAME and Net.sim != sim, "actual load-game button restores session")
	var restored: Sim = Net.sim
	check(int(restored.players[1].money) == saved_cash and restored.players[1].cards == ["missile", "shuaishen", "dice"], "save restores money and card order")
	check(str(restored.active_pet(restored.players[1]).get("id", "")) == "caishen" and restored.players[1].effects.no_upgrade_steps == 29, "save restores active pet instance and remaining effects")
	check(restored.estate_index == 15.0 and restored.estate_month == 5 and restored.lotto_prize == 12345 and restored.lotto_numbers[4] == 1, "save restores economy and lottery state")
	check(restored.rng.state == expected_rng and restored.pending_card_impacts.size() == 1 and Net.ai_ids == ids, "save restores random sequence, impact queue and AI membership")
	await app.get_tree().process_frame
	check(app._board._road_nodes.has(tile) and is_instance_valid(app._board._road_nodes[tile]) and app._board._road_nodes[tile].visible, "road objects are recreated after reading a save without freed-node references")
	var event_nodes_valid := true
	for node in app._board._event_nodes.values():
		event_nodes_valid = event_nodes_valid and is_instance_valid(node)
	check(event_nodes_valid, "event icon registry contains only current map nodes")
	await shot("restored-session")
	check(Net.load_singleplayer("user://saves/missing-play-flow-slot.r6save") != OK and Net.sim == restored, "missing save leaves current game intact")
	var invalid_path := "user://saves/invalid-play-flow-slot.r6save"
	var invalid_file := FileAccess.open(invalid_path, FileAccess.WRITE)
	invalid_file.store_var({"format": 1, "map": "china", "state": {}}, false)
	invalid_file.close()
	check(Net.load_singleplayer(invalid_path) == ERR_FILE_CORRUPT and Net.sim == restored, "invalid save leaves current game intact")
	# Repeat entry after leaving while paused, guarding the original frozen-new-game bug.
	app._toggle_pause()
	app._on_leave()
	await app.get_tree().process_frame
	await frontend_click("Single")
	await frontend_click("NewGame")
	await frontend_click("Confirm")
	await frontend_click("StartGame")
	check(not app.get_tree().paused and not Net.game_paused and app.screen == app.Screen.GAME, "new session after paused exit is not frozen")
	print("PLAY FLOW REVIEW: %d checks, %s" % [checks, "FAIL" if failed else "PASS"])
	app.get_tree().quit(1 if failed else 0)
