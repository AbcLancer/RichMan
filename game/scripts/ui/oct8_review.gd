extends "res://scripts/ui/card_flow_review.gd"

func run(root) -> void:
	app = root
	output = "res://../docs/screenshots/oct8-review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	app._port_edit.text = "0"
	app._frontend.start_requested.emit({"map": "aiji", "role": 5, "players": 3, "money": 300000, "credit": 200})
	Net.set_process(false)
	var sim: Sim = Net.sim
	sim.running = false
	sim.time = 10
	var me: Dictionary = sim.players[1]
	me.last_plot_kind = ""
	app._loading.hide()
	app._on_state(sim.to_dict())
	await app.get_tree().create_timer(.3).timeout
	check(Audio.ambient_id() == -1, "no repeated activity-like ambient noise")
	var ids := sim.player_ids()
	var before := Audio._pool_idx
	var children := Audio.get_child_count()
	for kind in ["roll", "roll_end", "buy", "upgrade", "get_card", "pay_rent"]:
		app._on_game_event(kind, {"pid": ids[1], "role": 2, "to": ids[2], "amount": 100})
	app._ev_sfx(57, {"pid": ids[1]}, Vector3.ZERO)
	check(Audio._pool_idx == before and Audio.get_child_count() == children, "remote routine actions and 3D-classified footsteps dispatch no audio")
	app._on_game_event("pay_rent", {"pid": ids[1], "role": 2, "to": 1, "amount": 100})
	check(Audio._pool_idx != before, "local landlord retains their own reward voice")
	var board = app._board
	var cam: Camera3D = board._cam()
	var target: Vector3 = board._cam_target
	var screen_before := cam.unproject_position(target)
	board.drag_pan(Vector2(35, 25))
	var screen_after := cam.unproject_position(target)
	check(screen_after.distance_to(screen_before + Vector2(35, 25)) < .2, "left pan follows pointer horizontally and vertically")
	board.drag_rotate(Vector2(60, 20))
	# Even a blocked roll must still provide a way back to the player.
	me.last_plot_kind = "buy"
	app._on_state(sim.to_dict())
	app._on_go_pressed()
	check(board._follow and is_equal_approx(board._cam_yaw, board.CAM_YAW_DEF), "GO restores camera and follow before checking roll eligibility")
	me.last_plot_kind = ""
	me.stamina = sim.stamina_max()
	app._on_state(sim.to_dict())
	board.drag_pan(Vector2(20, 10))
	await app.get_tree().process_frame
	await click(app._go_btn.get_global_rect().get_center())
	check(board._follow, "clicking the actual GO button restores follow")
	me.moving = 0
	var actor := board._player_nodes[1].get_node("OriginalActor") as OriginalMesh
	var opaque_shader: Shader = actor._materials[0].shader
	var skin: Variant = actor._materials[0].get_shader_parameter("skin")
	check(sim._apply_card(me, "invisible", Rules.card_by_id("invisible"), me.effects, -1), "invisible card applies")
	app._on_state(sim.to_dict())
	check(float(me.effects.no_rent_until) == 0.0 and float(me.effects.invisible_until) > sim.time and int(me.effects.no_rent_steps) == 0, "invisible uses its own expiry without pretending a wealth god is attached")
	check(actor._materials[0].shader != opaque_shader and is_equal_approx(float(actor._materials[0].get_shader_parameter("opacity")), .45), "actor uses genuine alpha-blended shader")
	check(actor._materials[0].get_shader_parameter("skin") == skin, "switching alpha shader preserves skin texture")
	check(not board._effects.shields.has(1), "invisible has no invincibility orbit")
	check(not board._player_nodes[1].get_node("GodIcon").visible and board._player_nodes[1].get_node("GodSteps").text == "72", "invisible displays countdown without god icon")
	await shot("invisible-countdown")
	sim.time = float(me.effects.invisible_until)
	app._on_state(sim.to_dict())
	check(actor._materials[0].shader == opaque_shader and float(me.effects.invincible_until) <= sim.time and float(me.effects.no_rent_until) <= sim.time, "opacity and invisible protections end together")
	await shot("visible-after-expiry")
	for idx in range(sim.map.tile_count()):
		if sim.map.is_plot(idx): sim._bind_plot(idx, {"owner": 1, "level": 0, "type": ""})
	var chosen := -1
	for idx in range(sim.map.tile_count()):
		if sim.map.is_plot(idx) and not sim.construction_plan(1, idx, "industry:4").is_empty():
			chosen = idx
			break
	check(chosen >= 0, "found original two-lot heavy factory footprint")
	if chosen >= 0:
		var plan := sim.construction_plan(1, chosen, "industry:4")
		sim._commit_construction(chosen, plan)
		var members: Array = sim.plots[chosen].members.duplicate()
		sim.plots[chosen].level = 5
		sim._downgrade_estate(chosen)
		check(int(sim.plots[chosen].level) == 4 and sim.plots[chosen].has("members"), "second heavy factory grade downgrades to first without splitting")
		sim._downgrade_estate(chosen)
		var split := true
		for member in members:
			split = split and int(sim.plots[member].level) == 0 and not sim.plots[member].has("members") and str(sim.plots[member].type) == ""
		check(split, "first heavy factory grade downgrades to independent empty lots")
		plan = sim.construction_plan(1, chosen, "industry:4")
		sim._commit_construction(chosen, plan)
		check(sim._apply_card(me, "monster", Rules.card_by_id("monster"), me.effects, chosen) and int(sim.plots[chosen].level) == 0, "monster card demolishes first heavy factory tier")
		plan = sim.construction_plan(1, chosen, "industry:4")
		sim._commit_construction(chosen, plan)
		sim._damage_area(chosen, 0, 0, 1, "missile")
		check(int(sim.plots[chosen].level) == 0 and not sim.plots[chosen].has("footprint"), "blast damage also splits first heavy factory tier")
		app._open_house_picker({"options": ["industry"], "idx": chosen, "pid": 1})
		var texts := ""
		for label in app._house_pick.find_children("*", "Label", true, false): texts += label.text
		check(texts.contains("一级重工厂") and texts.contains("一级工业区"), "construction names reflect footprint grades")
		await shot("construction-names")
		app._house_pick.hide()
	# Exercise the real date tick including a legacy midmonth draw marker.
	sim.lotto_last_draw_day = 15
	sim.road_day = 29
	sim.time = 30 * Rules.seconds_per_day() - .1
	sim.running = true
	sim.step(.2)
	sim.running = false
	check(sim.lotto_last_draw_day == 30 and Sim.calendar_at_day(sim.road_day).day == 1, "lottery draws on the first even after legacy day-15 draw")
	app._on_state(sim.to_dict())
	# Wait for a simultaneous monthly news panel to finish.
	for frame in range(360):
		if app._lotto.visible: break
		await app.get_tree().create_timer(.02).timeout
	check(app._lotto.visible, "monthly lottery result opens without being inside lottery shop")
	var locked := true
	for cell in app._lotto._cells: locked = locked and cell.disabled
	check(locked, "draw result cannot accept bets")
	await shot("monthly-lottery-result")
	var last := sim.lotto_last_draw_day
	sim.running = true
	sim.step(.1)
	sim.running = false
	check(sim.lotto_last_draw_day == last, "monthly draw is not repeated each frame")
	await app.get_tree().create_timer(2.2).timeout
	check(not app._lotto.visible, "draw result closes automatically")
	print("OCT8 REVIEW: %d checks, %s" % [checks, "FAIL" if failed else "PASS"])
	app.get_tree().quit(1 if failed else 0)

