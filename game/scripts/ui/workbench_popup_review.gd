extends "res://scripts/ui/card_flow_review.gd"

func run(root) -> void:
	app = root
	output = "res://../docs/screenshots/workbench-popup-review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	app._port_edit.text = "0"
	app._frontend.start_requested.emit({"map": "aiji", "role": 1, "players": 2, "money": 300000, "credit": 100})
	Net.set_process(false)
	var sim: Sim = Net.sim
	sim.time = Sim.ENTRY_SECONDS + .1
	var me: Dictionary = sim.players[1]
	me.tile = 0
	me.last_plot = 0
	me.last_plot_kind = ""
	app._on_state(sim.to_dict())
	app._loading.hide()
	var tool: UiWorkbench = app.get_node("UiWorkbench")
	tool.panel.show()
	tool.refresh()
	check(not tool.targets.has(app._pop), "closed confirmation is absent from visible list")
	var old_hud_key := str(app._hud_day.get_meta("ui_id"))
	me.last_plot_kind = "buy"
	app._on_state(sim.to_dict())
	await app.get_tree().create_timer(.6).timeout
	check(app._pop.visible and tool.targets.has(app._pop), "opening buy prompt automatically adds separate modal layer")
	check(tool.targets.has(app._pop_yes) and tool.targets.has(app._pop_no) and tool.targets.has(app._pop_text), "prompt text and both buttons are selectable")
	check(not tool.targets.has(app._pop.get_parent().get_node("InputBlocker")), "invisible input shield excluded")
	check(str(app._hud_day.get_meta("ui_id")) == old_hud_key, "main UI calibration IDs preserved")
	var index := tool.targets.find(app._pop)
	check(tool.list.get_item_text(index).contains("买地"), "buy confirmation has recognizable name")
	tool.select(index)
	tool._move_panel(Vector2(800, 40))
	await app.get_tree().process_frame
	check(tool.highlight.visible and tool.highlight.position == app._pop.get_global_rect().position and tool.highlight.size == app._pop.size, "modal selection outlined red above confirmation layer")
	check(tool.layer > app._pop.get_parent().layer and tool.layer > app._session_menu.layer, "tool remains above all secondary UI layers")
	await shot("buy-prompt-selected")
	var initial: Vector2 = app._pop.position
	tool.fields[0].value = 140
	tool.fields[1].value = 180
	await app.get_tree().create_timer(.6).timeout
	check(app._pop.position.distance_to(Vector2(140, 180)) < 1 and app._pop.position != initial, "calibration persists despite per-frame actor-follow placement")
	var key := str(app._pop.get_meta("ui_id"))
	tool.save_path = "user://workbench-popup-review.json"
	tool.save()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(tool.save_path))
	check(saved.has(key) and saved[key].rect[0] == 140 and saved[key].rect[1] == 180, "popup layout saved under stable modal key without touching user file")
	tool.select(tool.targets.find(app._pop_yes))
	await app.get_tree().process_frame
	check(tool.highlight.visible and tool.highlight.position == app._pop_yes.get_global_rect().position, "yes button individually marked red")
	check(not tool.fields[0].editable and tool.fields[4].editable, "container-managed geometry clearly disabled")
	await shot("confirm-button-selected")
	tool.search.text = "确认：是"
	tool.search.text_changed.emit(tool.search.text)
	await app.get_tree().process_frame
	check(tool.targets.size() == 1 and tool.targets[0] == app._pop_yes, "semantic name search finds exact button")
	tool.search.clear()
	var money := int(me.money)
	app._pop_cancel()
	await app.get_tree().create_timer(.6).timeout
	check(not tool.targets.has(app._pop) and not tool.highlight.visible and me.money == money, "closing prompt removes list entries and highlight without buying")
	# Reopening reused modal must retain its calibration, then reset must restore following.
	me.last_plot_kind = "buy"
	app._on_state(sim.to_dict())
	await app.get_tree().create_timer(.6).timeout
	check(tool.targets.has(app._pop) and app._pop.position.distance_to(Vector2(140, 180)) < 1, "reopened confirmation keeps calibration")
	tool.select(tool.targets.find(app._pop))
	tool.reset()
	await app.get_tree().create_timer(.2).timeout
	check(not tool.overrides.has(key) and app._pop.position.distance_to(Vector2(140, 180)) > 1, "reset restores actor-follow placement")
	app._pop_cancel()
	app._open_session_menu()
	await app.get_tree().create_timer(.6).timeout
	var menu_target: Control = app._session_menu_box
	check(tool.targets.has(menu_target), "other independent menu layer discovered too")
	tool.select(tool.targets.find(menu_target))
	await app.get_tree().process_frame
	check(tool.highlight.visible and tool.highlight.position == menu_target.get_global_rect().position, "secondary menu also outlined red")
	await shot("session-menu-selected")
	print("WORKBENCH POPUP REVIEW: %d checks, %s" % [checks, "FAIL" if failed else "PASS"])
	app.get_tree().quit(1 if failed else 0)

