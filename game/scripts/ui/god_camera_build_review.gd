extends "res://scripts/ui/card_flow_review.gd"
## Focused regression for road gods, world badges, camera drag and construction cards.

func run(root) -> void:
	app = root
	output = "res://../docs/screenshots/god-camera-build-review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	app._port_edit.text = "0"
	app._frontend.start_requested.emit({"map": "aiji", "role": 5, "players": 2,
		"money": 300000, "credit": 200})
	Net.set_process(false)
	var sim: Sim = Net.sim
	sim.time = Sim.ENTRY_SECONDS + .2
	var me: Dictionary = sim.players[1]
	me.last_plot_kind = ""
	me.last_plot = -1
	app._loading.hide()
	app._on_state(sim.to_dict())
	await app.get_tree().create_timer(.2).timeout
	var root3d := app._board._player_nodes[1] as Node3D
	check(not (root3d.get_node("Tag") as Label3D).visible, "ordinary player head has no name or cash")
	var initial_cards := (me.cards as Array).size()
	sim._attach_god(me, "fushen")
	app._on_state(sim.to_dict())
	var portrait := root3d.get_node("GodIcon") as Sprite3D
	var steps := root3d.get_node("GodSteps") as Label3D
	check((me.cards as Array).size() > initial_cards and int(me.effects.free_upgrade_steps) == 30,
		"road fortune god gives cards and thirty free-build steps")
	check(portrait.visible and portrait.texture != null and steps.text == "30" and
		steps.modulate.g > steps.modulate.r, "god portrait and green remaining steps replace overhead text")
	await shot("fortune-status")
	var prior_cash := int(me.money)
	sim._attach_god(me, "caishen")
	app._on_state(sim.to_dict())
	check(int(me.money) > prior_cash and int(me.effects.no_rent_steps) == 30,
		"wealth god grants money and rent-free steps")
	check(app._money_reel != null and app._money_reel.visible,
		"wealth god shows six-digit money reel")
	await shot("wealth-reel")
	prior_cash = int(me.money)
	sim._attach_god(me, "qiongshen")
	app._on_state(sim.to_dict())
	check(int(me.money) < prior_cash and int(me.effects.rent_double_steps) == 30,
		"poverty god takes money and doubles rent for thirty steps")
	await shot("poverty-reel")
	check(sim.add_pet(me, "caishen") == 0, "player can acquire original wealth pet for skill preview")
	var active: Dictionary = sim.active_pet(me)
	active.fullness = Sim.PET_FULLNESS_MAX
	app._on_state(sim.to_dict())
	check(app._pet_skill_btn.visible and app._pet_skill_btn.texture_normal != null
		and app._pet_slot.texture == app._tex_or_null(Rules.pet_art("caishen", "faceb", 1)),
		"full pet uses happy portrait and its glowing original skill icon")
	await shot("pet-skill-ready")
	app._on_pet_skill_quick()
	check(float(active.fullness) == Sim.PET_START_FULLNESS,
		"glowing skill icon activates the pet and resets its energy to the normal starting level")

	# Drive the same mouse-input entry points used by live play, over the clear board center.
	app._money_reel.hide()
	app._money_reel_time = 0.0
	Input.warp_mouse(Vector2(620, 370))
	await app.get_tree().process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = Vector2(620, 370)
	app._input(press)
	var yaw: float = app._board._cam_yaw
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(660, 390)
	motion.relative = Vector2(40, 20)
	app._input(motion)
	press.pressed = false
	press.position = motion.position
	app._input(press)
	check(not is_equal_approx(app._board._cam_yaw, yaw) and not app._tile_info_panel.visible,
		"right drag rotates camera without opening road explanation")
	press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(620, 370)
	app._input(press)
	var old_target: Vector3 = app._board._cam_target
	motion.position = Vector2(660, 390)
	motion.relative = Vector2(40, 20)
	app._input(motion)
	press.pressed = false
	app._input(press)
	check(app._board._cam_target.distance_to(old_target) > .01 and not app._board._follow,
		"left drag pans camera and releases follow mode")
	await app.get_tree().process_frame
	check(app._follow_btn.visible, "camera pan exposes a clear follow-player button")
	await shot("camera-follow-control")
	app._follow_btn.emit_signal("pressed")
	check(app._board._follow and not app._board.is_overview(),
		"follow-player button resumes tracking")
	app._board.drag_pan(Vector2(30, 10))
	app._board.set_overview(false)
	check(app._board._follow, "leaving overview also resumes tracking")
	app._toggle_br()
	await app.get_tree().process_frame
	var bar_rect: Rect2 = app._icon_bar.get_global_rect()
	var screen_rect: Rect2 = app.get_viewport().get_visible_rect()
	check(app._br_collapsed and app._br_box.visible and app._icon_bar.visible
		and screen_rect.encloses(bar_rect),
		"collapsed utility area keeps its expansion icon bar")
	await shot("collapsed-utility-bar")
	await click((app._icon_btns[5] as TextureButton).get_global_rect().get_center())
	check(not app._br_collapsed and app._br_map_panel.visible,
		"the visible last icon expands the utility area again")

	# Own vacant squares, then choose the first heavy factory from the actual card row.
	for idx in range(sim.map.tile_count()):
		if sim.map.is_plot(idx):
			sim.plots[idx] = {"owner": 1, "level": 0, "type": ""}
	var chosen := -1
	for idx in range(sim.map.tile_count()):
		if sim.map.is_plot(idx) and not sim.construction_plan(1, idx, "industry:4").is_empty():
			chosen = idx
			break
	check(chosen >= 0, "Egypt has connected lots for a heavy factory")
	if chosen >= 0:
		me.tile = chosen
		me.last_plot = chosen
		me.last_plot_kind = "upgrade"
		app._on_state(sim.to_dict())
		check(app._house_pick != null and not app._pop.visible,
			"owned empty property opens building cards directly")
		var buttons: Array = app._house_pick.find_children("*", "Button", true, false)
		check(buttons.size() == sim.buildable_types().size() * 3
			and app._house_pick.position.x > app.get_viewport().get_visible_rect().size.x * .45,
			"three build tiers per allowed type appear on the right")
		await shot("building-choices")
		app._open_house_picker({"options": Rules.primary_types(), "idx": chosen, "pid": 1})
		check(app._house_pick.find_children("*", "Button", true, false).size() == 9,
			"maps allowing all three property classes show factory, shop and housing rows")
		await shot("multi-type-building-choices")
		app._open_house_picker({"options": sim.buildable_types(), "idx": chosen, "pid": 1})
		buttons = app._house_pick.find_children("*", "Button", true, false)
		var selected: Button = null
		for item in buttons:
			if not item.disabled and item.tooltip_text.contains("一级重工厂"):
				selected = item
				break
		check(selected != null, "heavy factory choice is enabled on connected land")
		if selected != null:
			var before := int(me.money)
			selected.emit_signal("pressed")
			check(int(sim.plots[chosen].level) == 4 and str(sim.plots[chosen].type) == "industry"
				and int(me.money) < before, "selected first heavy-factory grade is built and charged once")
	print("GOD CAMERA BUILD REVIEW: %d checks, %s" % [checks, "FAIL" if failed else "PASS"])
	app.get_tree().quit(1 if failed else 0)
