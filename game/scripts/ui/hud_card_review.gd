extends "res://scripts/ui/card_flow_review.gd"

func run(root) -> void:
	app = root
	output = "res://../docs/screenshots/hud-card-review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	app._port_edit.text = "0"
	app._frontend.start_requested.emit({"map": "aiji", "role": 1, "players": 4, "money": 300000, "credit": 100})
	Net.set_process(false)
	var sim: Sim = Net.sim
	sim.time = Sim.ENTRY_SECONDS + .1
	var me: Dictionary = sim.players[1]
	me.tile = 0
	me.stamina = sim.stamina_max() * .8
	me.cards = ["hamburger"]
	sim.add_pet(me, "caishen")
	var pet := sim.active_pet(me)
	pet.fullness = 75.0
	app._on_state(sim.to_dict())
	app._loading.hide()
	await app.get_tree().create_timer(.4).timeout
	check(app._char_name.text == Rules.role_name(1), "original role name below avatar")
	check(app._char_stat.text == sim.pet_name("caishen"), "pet name below full-size pet portrait")
	check(app._pet_bar == app._char_bar_b and app._char_info == app._char_stat, "exactly two bars and no duplicate portrait text")
	check(app._pet_slot.size.y > 70 * app._ui_scale and app._pet_level_star.visible, "full pet portrait and original level star")
	check(is_equal_approx(app._char_bar_a.value, 80) and is_equal_approx(app._char_bar_b.value, 75), "stamina and fullness independent of money")
	check(app._char_identity.texture_normal == app._role_texture(0, "31"), "role-specific diamond identity icon")
	await shot("character-panel")
	var source: Rect2 = app._card_slots[0].box.get_global_rect()
	Net.send_action("card", ["hamburger"])
	check(is_instance_valid(app._used_card_face) and not me.cards.has("hamburger"), "successful authoritative card use creates flight")
	check(app._used_card_face.position.distance_to(source.position) < 1, "flight starts at consumed hand card")
	await app.get_tree().create_timer(.55).timeout
	check(app._used_card_face.position.x < 1 and app._used_card_face.size.y > 250 * app._ui_scale, "used card enlarged on left")
	check(is_equal_approx(app._used_card_face.modulate.a, 1), "left-side display stays opaque during hold")
	check(app._used_card_face.mouse_filter == Control.MOUSE_FILTER_IGNORE, "card presentation never blocks input")
	await shot("card-used-left")
	await app.get_tree().create_timer(1.8).timeout
	check(not is_instance_valid(app._used_card_face), "used card presentation clears")
	Net.send_action("card", ["hamburger"])
	check(not is_instance_valid(app._used_card_face), "failed card does not show a success flight")
	var effects: WorldEffects = app._board._effects
	effects.set_process(false)
	var target := 0
	for tile in sim.map.tiles:
		if str(tile.get("kind", "")) == "land":
			target = int(tile.get("index", sim.map.tiles.find(tile)))
			break
	sim.plots[target] = {"owner": 1, "level": 1, "type": "", "anchor": target}
	app._on_state(sim.to_dict())
	await app.get_tree().process_frame
	var destination: Vector3 = app._board.plot_pos_of(target)
	var alias := (target + 1) % sim.map.tiles.size()
	sim.plots[alias] = {"owner": 1, "level": 1, "type": "", "anchor": target}
	app._on_state(sim.to_dict())
	check((app._board.plot_pos_of(alias) as Vector3).distance_to(destination) < .001, "merged estate routes rent to shared building anchor")
	for amount in [250, 2500, 25000]:
		var count_before := effects.transients.size()
		app._on_game_event("pay_rent", {"pid": 1, "to": sim.player_ids()[1], "amount": amount, "idx": target})
		var coins: Array = []
		for record in effects.transients.slice(count_before):
			if record.kind == "coin": coins.append(record)
		check(coins.size() == WorldEffects.rent_coin_count(amount), "coin count scales with fee %d" % amount)
		if coins.is_empty(): continue
		var first: Dictionary = coins[0]
		check(first.destination.distance_to(destination + Vector3.UP * .6 * effects.world_scale) < .001, "coins target paying estate, not owner")
		effects._process(.36)
		check(first.node.global_position.y > (first.origin as Vector3).lerp(first.destination, .5).y + 1.0 * effects.world_scale, "parabolic midpoint rises above straight line")
		await shot("rent-coins-%d" % amount)
		effects._process(.36)
		check(first.node.global_position.distance_to(first.destination) < .001 or first.node.is_queued_for_deletion(), "coins reach estate")
		effects._process(3)
	check(WorldEffects.rent_coin_count(250) < WorldEffects.rent_coin_count(2500) and WorldEffects.rent_coin_count(2500) < WorldEffects.rent_coin_count(25000), "increasing fee tiers and bounded maximum")
	check(WorldEffects.rent_coin_count(100000000) == 24 and WorldEffects.rent_coin_count(0) == 0, "large fees capped and zero fees emit no coins")
	print("HUD CARD REVIEW: %d checks, %s" % [checks, "FAIL" if failed else "PASS"])
	app.get_tree().quit(1 if failed else 0)
