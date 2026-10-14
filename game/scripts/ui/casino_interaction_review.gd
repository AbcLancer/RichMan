extends "res://scripts/ui/card_flow_review.gd"
## The real UI and authority path for one slot-machine visit.

func run(root) -> void:
	app = root
	output = "res://../docs/screenshots/casino-interaction-review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	app._port_edit.text = "0"
	app._frontend.start_requested.emit({"map": "aiji", "role": 3, "players": 2,
		"money": 300000, "credit": 100})
	Net.set_process(false)
	var sim: Sim = Net.sim
	sim.time = Sim.ENTRY_SECONDS + .2
	var me: Dictionary = sim.players[1]
	app._loading.hide()
	app._on_state(sim.to_dict())
	sim._resolve_event(me, int(me.tile), {"event": "labar", "name": "拉霸"})
	await app.get_tree().process_frame
	check(app._casino.visible, "slot machine opens on the original labar road event")
	await shot("before-bet")
	await click((app._casino._bet_buttons[0] as TextureButton).get_global_rect().get_center())
	check(int(sim._casino_of(1).bet) == 1000, "first stake reaches authority")
	check((app._casino._bet_buttons[1] as TextureButton).disabled,
		"other stakes become unavailable after the one allowed bet")
	await click(app._casino._pull.get_global_rect().get_center())
	check(bool(sim._casino_of(1).played) and (sim._casino_of(1).reels as Array).size() == 3,
		"pull resolves three reels exactly once")
	check(app._casino._resolved, "result arrives at the visible panel")
	await app.get_tree().create_timer(2.1).timeout
	var expected: Texture2D = app._casino._tex(
		"casino_girl2.png" if app._casino._won else "casino_girl3.png")
	check(app._casino._girl.texture.get_image().get_data() == expected.get_image().get_data(),
		"bunny reacts with a happy or disappointed original frame")
	await shot("result-expression")
	await app.get_tree().create_timer(2.6).timeout
	check(not app._casino.visible, "machine closes itself after showing the result")
	check(not sim.act_casino_bet(1, 1000) and not sim.act_casino_pull(1),
		"completed visit cannot be played again")
	sim._resolve_event(me, int(me.tile), {"event": "labar", "name": "拉霸"})
	await app.get_tree().process_frame
	await click((app._casino._bet_buttons[0] as TextureButton).get_global_rect().get_center())
	var money_with_bet := int(me.money)
	app._on_casino_action("exit", 0)
	check(not app._casino.visible and int(me.money) == money_with_bet + 1000,
		"exit returns an unpulled stake")
	print("CASINO INTERACTION REVIEW: %d checks, %s" % [checks, "FAIL" if failed else "PASS"])
	app.get_tree().quit(1 if failed else 0)
