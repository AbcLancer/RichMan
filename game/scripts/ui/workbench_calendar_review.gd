extends "res://scripts/ui/card_flow_review.gd"

func drag(from: Vector2, to: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = from
	Input.parse_input_event(motion)
	await app.get_tree().process_frame
	var button := InputEventMouseButton.new()
	button.position = from
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = true
	Input.parse_input_event(button)
	await app.get_tree().process_frame
	for i in range(1, 7):
		motion = InputEventMouseMotion.new()
		motion.position = from.lerp(to, i / 6.0)
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(motion)
		await app.get_tree().process_frame
	button = InputEventMouseButton.new()
	button.position = to
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = false
	Input.parse_input_event(button)
	await app.get_tree().process_frame

func run(root) -> void:
	app = root
	output = "res://../docs/screenshots/workbench-calendar-review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for entry in [[0, 1, 1, 1], [29, 30, 1, 1], [30, 1, 2, 1], [39, 10, 2, 1], [59, 30, 2, 1], [60, 1, 3, 1], [359, 30, 12, 1], [360, 1, 1, 2]]:
		var date := Sim.calendar_at_day(entry[0])
		check(date.day == entry[1] and date.month == entry[2] and date.year == entry[3], "calendar elapsed day %d maps to %d/%d year %d" % [entry[0], entry[1], entry[2], entry[3]])
	app._port_edit.text = "0"
	app._frontend.start_requested.emit({"map": "aiji", "role": 5, "players": 2, "money": 300000, "credit": 100})
	Net.set_process(false)
	app._loading.hide()
	var sim: Sim = Net.sim
	for player in sim.players.values(): player.alive = false # Isolate the calendar from arrivals and AI.
	sim.running = true
	var events: Array = []
	sim.game_event.connect(func(kind, data):
		if kind == "estate_index_up": events.append(data))
	sim.step(Rules.seconds_per_day() * 29)
	app._on_state(sim.to_dict())
	check(app._hud_day._text == "30/1" and sim.estate_index == 10 and events.is_empty(), "January 30 has no early inflation")
	sim.step(Rules.seconds_per_day())
	app._on_state(sim.to_dict())
	check(app._hud_day._text == "1/2" and sim.estate_index == 11 and sim.empty_plot_price() == 2200, "real day tick advances month and raises land price")
	check(events.size() == 1 and events[0].month == 2 and app._toast_lbl.text.contains("物价指数涨至11"), "monthly inflation gives visible feedback")
	check(sim._rent_of(0) == 275 and app._hud_day.tooltip_text.contains("物价指数：11"), "empty parcel rent and date tooltip use current index")
	sim.step(1)
	check(sim.estate_index == 11 and events.size() == 1, "same month does not double-charge inflation")
	sim.step(Rules.seconds_per_day() * 31)
	app._on_state(sim.to_dict())
	check(app._hud_day._text == "2/3" and sim.estate_index == 12 and events.size() == 2, "next month raises index exactly once")
	if app._news_pop != null: app._news_pop.visible = false
	await app.get_tree().create_timer(.1).timeout
	var restored := Sim.new()
	restored.setup(sim.map, 0)
	restored.apply_dict(sim.to_dict())
	restored._tick_estate_index()
	check(restored.estate_index == 12 and restored.estate_month == 2, "save/restore preserves calendar and prevents duplicate monthly increase")
	var tool: UiWorkbench = app.get_node("UiWorkbench")
	tool.panel.show()
	tool.refresh()
	var index := tool.targets.find(app._hud_day)
	var selected_before: Color = app._hud_day.modulate
	tool.select(index)
	await app.get_tree().create_timer(.1).timeout
	check(tool.highlight.get_parent() == tool and tool.highlight.visible and tool.highlight.size == app._hud_day.get_global_rect().size, "highlight belongs to independent overlay and matches selected bounds")
	var style := tool.highlight.get_theme_stylebox("panel") as StyleBoxFlat
	check(style.border_color.r == 1 and style.bg_color.a > .1 and app._hud_day.modulate == selected_before, "selected item marked red without changing its stored appearance")
	check(tool.list.get_item_text(index).contains("/"), "similar nodes show parent context in list")
	await shot("selected-red")
	var start := tool.panel.position
	var before := tool.highlight.position
	await drag(tool.drag_handle.get_global_rect().get_center(), tool.drag_handle.get_global_rect().get_center() + Vector2(600, 0))
	check(tool.panel.position.x > start.x + 400 and not tool._dragging, "actual header drag moves inspector and releases cleanly")
	check(tool.highlight.position == before and app._hud_day.modulate == selected_before, "moving inspector leaves the selection marker on its target")
	await shot("inspector-moved")
	await drag(tool.drag_handle.get_global_rect().get_center(), tool.drag_handle.get_global_rect().get_center() + Vector2(3000, 3000))
	check(tool.panel.position.x + tool.panel.size.x <= app.get_viewport().get_visible_rect().size.x + 1, "drag keeps panel reachable at screen edge")
	tool.panel.hide()
	await app.get_tree().process_frame
	check(not tool.highlight.visible, "closing inspector hides red overlay")
	print("WORKBENCH CALENDAR REVIEW: %d checks, %s" % [checks, "FAIL" if failed else "PASS"])
	app.get_tree().quit(1 if failed else 0)
