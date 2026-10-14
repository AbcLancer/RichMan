extends "res://scripts/ui/card_flow_review.gd"

func run(root) -> void:
	app = root
	output = "res://../docs/screenshots/settlement-shop-camera-review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	app._port_edit.text = "0"
	app._frontend.start_requested.emit({"map": "aiji", "role": 5, "players": 2, "money": 300000, "credit": 1000})
	Net.set_process(false)
	var sim: Sim = Net.sim
	sim.time = Sim.ENTRY_SECONDS + 1
	var me: Dictionary = sim.players[1]
	me.last_plot_kind = ""
	app._loading.hide()
	app._on_state(sim.to_dict())
	await app.get_tree().create_timer(.2).timeout
	var expected := {"qiongshen": 40, "hutu": 40, "emo": 80, "caishen": 100, "tushen": 60,
		"jingling": 40, "huaxian": 60, "dushen": 80, "guaishou": 60}
	for pet in expected:
		me.pets = []
		me.pet_active = ""
		me.credit = int(expected[pet]) - 1
		check(sim.pet_price(pet) == expected[pet] and not sim.act_buy_pet(1, pet), pet + " rejects one point short of native price")
		me.credit = int(expected[pet])
		check(sim.act_buy_pet(1, pet) and me.credit == 0, pet + " purchase deducts exact native price")
	# Actual shop button theme states and hover geometry.
	me.credit = 30
	me.card_shop_stock = ["step1", "caishen", "step2", "step5", "step3", "missile", "step4", "hibernate"]
	app._on_state(sim.to_dict())
	app._open_shop("cardshop")
	var available: Button
	var unavailable: Button
	for node in app._shop_nodes:
		if node is Button:
			if node.disabled: unavailable = node
			else: available = node
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color"]:
		check(available.get_theme_color(state).r < .5 and unavailable.get_theme_color(state).r < .5, "shop readable dark text in " + state)
	check(unavailable.disabled, "unaffordable button cannot buy")
	var hover := InputEventMouseMotion.new()
	hover.position = available.get_global_rect().get_center()
	hover.global_position = hover.position
	Input.parse_input_event(hover)
	await app.get_tree().create_timer(.2).timeout
	await shot("card-shop-hover-disabled")
	app._close_shop()
	# GO is not a camera reset. Tracking resumes only once movement starts.
	app._board.drag_rotate(Vector2(100, 50))
	app._board.drag_pan(Vector2(40, 30))
	var yaw: float = app._board._cam_yaw
	var pitch: float = app._board._cam_pitch
	var distance: float = app._board._cam_dist
	me.last_plot_kind = "buy"
	app._on_state(sim.to_dict())
	app._on_go_pressed()
	check(not app._board._follow and app._board._cam_yaw == yaw, "rejected GO preserves orbit and detached follow")
	me.last_plot_kind = ""
	me.moving = 1
	me.move_after = sim.time
	app._on_state(sim.to_dict())
	check(app._board._follow and app._board._cam_yaw == yaw and app._board._cam_pitch == pitch and app._board._cam_dist == distance,
		"actual movement restores follow without resetting orbit tilt or zoom")
	me.moving = 0
	# Real bankruptcy -> win -> final snapshot, not a fabricated UI-only win.
	var opponent: Dictionary = sim.players[sim.player_ids()[1]]
	sim._transfer(opponent, null, int(opponent.money) + 1, "结算回归")
	app._on_state(sim.to_dict())
	check(not sim.running and sim.winner == 1 and is_instance_valid(app._settlement), "real final bankruptcy opens settlement")
	check(app._settlement.result_title == "胜利" and app._settlement.ranking.rows.size() == 2, "settlement contains winner and every player's final assets")
	check(app._dialogue_obscured(), "settlement blocks gameplay actions")
	Net.send_action("roll", [1])
	check(me.moving == 0, "server rejects gameplay after final result")
	var panel: Control = app._settlement
	app._on_state(sim.to_dict())
	check(app._settlement == panel, "repeated finished snapshots do not duplicate settlement")
	await shot("victory-settlement")
	app._close_settlement()
	var defeat: Dictionary = sim.to_dict()
	defeat.win = int(opponent.id)
	app._on_state(defeat)
	check(app._settlement.result_title == "败北", "losing client gets its own defeat result")
	await shot("defeat-settlement")
	app._close_settlement()
	app._on_state(sim.to_dict())
	panel = app._settlement
	await click((panel.find_child("ReturnToMenu", true, false) as Button).get_global_rect().get_center())
	check(app.screen == app.Screen.MENU and not is_instance_valid(app._settlement) and Net.sim == null, "return button closes match and returns to menu")
	app._frontend.start_requested.emit({"map": "aiji", "role": 5, "players": 2, "money": 300000, "credit": 1000})
	Net.set_process(false)
	app._loading.hide()
	app._on_state(Net.sim.to_dict())
	check(app.screen == app.Screen.GAME and not is_instance_valid(app._settlement), "new match has no stale settlement")
	print("SETTLEMENT SHOP CAMERA REVIEW: %d checks, %s" % [checks, "FAIL" if failed else "PASS"])
	app.get_tree().quit(1 if failed else 0)
