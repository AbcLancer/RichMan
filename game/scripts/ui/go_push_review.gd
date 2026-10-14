extends "res://scripts/ui/card_flow_review.gd"

## A pushed player can still have a sleep timer. Exercise the real GO control
## before and after that timer, not just the simulation predicate.
func run(root) -> void:
	app = root
	app._port_edit.text = "0"
	app._frontend.start_requested.emit({"map": "aiji", "role": 3, "players": 2, "money": 300000, "credit": 100})
	Net.set_process(false)
	var sim: Sim = Net.sim
	sim.time = Sim.ENTRY_SECONDS + 0.1
	var me: Dictionary = sim.players[1]
	var rival: Dictionary = sim.players[sim.player_ids()[1]]
	me.moving = 0
	me.entry_until = 0.0
	me.effects.sleep_until = sim.time + 2.0
	me.last_plot_kind = "buy"
	rival.tile = int(me.tile)
	app._loading.hide()
	var start_tile := int(me.tile)
	sim._push_away_occupants(rival)
	check(int(me.tile) == (start_tile + 1) % sim.map.tile_count() and me.last_plot_kind == "", "push advances one tile and cancels the plot choice")
	app._on_state(sim.to_dict())
	await app.get_tree().process_frame
	app._sync_action_ui()
	check(app._go_btn.visible and app._go_btn.modulate.r < 0.9 and app._go_btn.tooltip_text.contains("冬眠中"), "GO shows the sleep countdown after a push")
	await click(app._go_btn.get_global_rect().get_center())
	check(int(me.moving) == 0 and app._toast_lbl.text.contains("冬眠中"), "early GO click explains why the roll is blocked")
	me.effects.sleep_until = sim.time
	me.effects.hospital_until = sim.time + 3.0
	app._on_state(sim.to_dict())
	check(app._go_btn.modulate.r < 0.9 and app._go_btn.tooltip_text.contains("住院中"), "hospital countdown also dims GO")
	await click(app._go_btn.get_global_rect().get_center())
	check(int(me.moving) == 0 and app._toast_lbl.text.contains("住院中"), "hospital click explains the remaining wait")
	me.effects.hospital_until = sim.time
	app._on_state(sim.to_dict())
	await app.get_tree().process_frame
	app._sync_action_ui()
	check(app._go_btn.visible and app._go_btn.modulate.r > 0.9, "GO lights up when the countdown expires")
	await click(app._go_btn.get_global_rect().get_center())
	check(int(me.moving) > 0, "GO click rolls immediately after the countdown")
	me.moving = 0
	me.effects.rest_until = sim.time + 10.0
	app._on_state(sim.to_dict())
	check(app._go_btn.modulate.r > .9 and app._go_btn.tooltip_text.contains("立即唤醒"), "idle rest keeps GO actionable")
	await click(app._go_btn.get_global_rect().get_center())
	check(float(me.effects.rest_until) == 0.0 and int(me.moving) > 0, "GO wakes an idling player and rolls in one click")
	# 完成一次实际行走并落在非购买事件格，下一次 GO 应立即可用。
	me.tile = 9
	me.moving = 1
	me.progress = .95
	me.move_after = 0.0
	sim.step(.1)
	app._on_state(sim.to_dict())
	await app.get_tree().process_frame
	check(int(me.moving) == 0 and app._go_btn.visible and
		app._go_btn.modulate.r > .9 and sim.roll_block_reason(me) == "",
		"GO is ready again immediately after an idling player's walk ends")
	await click(app._go_btn.get_global_rect().get_center())
	check(int(me.moving) > 0, "second GO click rolls after waking and finishing a walk")
	me.tile = sim.map.tile_count() - 1
	me.moving = 1
	me.progress = .95
	me.move_after = 0.0
	sim.step(.1)
	app._on_state(sim.to_dict())
	check(app._pop.visible and not app._go_btn.visible,
		"landing on an empty plot shows its choice instead of a misleading bright GO")
	app._pop_cancel()
	app._on_state(sim.to_dict())
	check(app._go_btn.visible and not app._pop.visible,
		"declining the plot immediately restores GO")
	print("GO PUSH REVIEW: %d checks, %s" % [checks, "FAIL" if failed else "PASS"])
	app.get_tree().quit(1 if failed else 0)
