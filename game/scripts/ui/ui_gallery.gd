extends RefCounted
class_name UiGallery
## Production controls, populated with deterministic inspection data.
var app: Node
var output: String
var report: Dictionary = {}
var workbench: UiWorkbench

func run(root: Node) -> void:
	app = root
	workbench = app.get_node("UiWorkbench")
	output = ProjectSettings.globalize_path("res://../docs/screenshots/ui-review")
	if app.get_viewport().get_visible_rect().size.aspect() < 1.5:
		output += "-4x3"
	DirAccess.make_dir_recursive_absolute(output)
	await check_frontend_clicks()
	await check_editor()
	for page in ["entry", "single", "selmap", "start"]:
		app._frontend.show_page(page)
		await shot(page)
	app._open_menu_more("mp")
	await shot("multiplayer")
	app._close_menu_panels()
	app._open_menu_more("sys")
	await shot("system")
	app._close_menu_panels()
	assert(is_instance_valid(app._menu_more))
	app._show(1)
	await shot("lobby")
	app._show(0)
	# Start through the actual option-screen callback, on a free temporary port.
	app._port_edit.text = "0"
	app._frontend.start_requested.emit({"map": "aiji", "role": 5, "players": 3, "money": 300000, "credit": 50})
	assert(Net.sim != null and Net.sim.players.size() == 3)
	assert(int(Net.sim.players[1].money) == 300000 and int(Net.sim.players[1].credit) == 50)
	assert(int(Net.sim.players[1].role) == 5)
	Net.set_process(false)
	Net.sim.running = false
	app._on_state(Net.sim.to_dict())
	await shot("loading")
	app._loading.hide()
	await shot("game-hud")
	for page in range(4):
		app._set_br_page(page)
		await shot("hud-page-%d" % page)
	app._set_br_page(2)
	app._toggle_chat_bar()
	await shot("chat-input")
	app._toggle_chat_bar()
	app._pause_overlay.show()
	await shot("pause")
	app._pause_overlay.hide()
	app._casino.open()
	await shot("casino")
	app._casino.close()
	app._lotto.open(500000, {})
	await shot("lotto")
	app._lotto.show_draw(12, "这是一个用于检查边界的长玩家名称", 99999999)
	await shot("lotto-result")
	app._lotto.hide()
	app._auction.open("这是用于验证超长名称显示的道路", 99999999, "长名称玩家", 0.75)
	await shot("auction")
	app._auction.hide()
	app._set_br_page(1)
	var company: String = str(Net.sim.stock_names()[0])
	for buy in [true, false]:
		app._stock.open_trade(company, buy)
		await shot("stock-buy" if buy else "stock-sell")
		app._stock.close_all()
	app._stock._show_holders(company)
	await shot("stock-holders")
	app._stock.close_all()
	app._stock._show_trend(company)
	await shot("stock-chart")
	app._stock.close_all()
	app._set_br_page(2)
	var me: Dictionary = Net.sim.players[1]
	for record in Net.sim.pet_catalog().slice(0, 4):
		Net.sim.add_pet(me, str(record.id))
	app._on_state(Net.sim.to_dict())
	for mode in ["cardshop", "pethouse", "warehouse"]:
		app._shop_stock = app._pet_shop_stock() if mode == "pethouse" else []
		app._open_shop(mode)
		await shot(mode)
		app._close_shop()
	app._show_global_news(1, "新闻文字边界检查：本段包含长名称及金额 99999999，验证换行与图片比例。", 1)
	await shot("news")
	app._news_pop.hide()
	app._pop_mode = "card"
	app._pop_text.text = "这是一个很长的地块名称\n价格：99999999 元\n确定购买这块土地吗？"
	app._pop.show()
	await shot("confirmation")
	app._pop.hide()
	app._pop_mode = ""
	app._show_step_picker()
	await shot("dice-selection")
	app._step_picker.hide()
	app._open_house_picker({"options": Net.sim.buildable_types()})
	await shot("house-selection")
	app._close_house_picker()
	app._dev_give_cards(["caishen", "step3", "dice", "hamburger", "stay"])
	app._on_state(Net.sim.to_dict())
	app._on_card_clicked(0)
	await shot("card-actions")
	app._hide_card_menu()
	app._show_say("长角色名称与对话：这是一段用于检查自动换行的台词。", 1)
	await shot("speech-bubble")
	app._say_bubble.hide()
	workbench.panel.show()
	workbench.refresh()
	await shot("layout-editor")
	workbench.panel.hide()
	var audit_name := "ui-layout-audit-4x3.json" if output.ends_with("-4x3") else "ui-layout-audit.json"
	var file := FileAccess.open(ProjectSettings.globalize_path("res://../docs/" + audit_name), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("UI REVIEW PASS: ", report.size(), " screens; menu settings and reusable panels verified")
	app.get_tree().quit()

func click_frontend(name: String, expected_page: String) -> void:
	var button := app._frontend.canvas.get_node(name) as Control
	assert(button != null)
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await app.get_tree().process_frame
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await app.get_tree().process_frame
	await app.get_tree().process_frame
	assert(app._frontend.page == expected_page, "Mouse navigation failed: " + name)
	assert(app._frontend.canvas.get_node_or_null("Background") != null)

func check_frontend_clicks() -> void:
	app._frontend.show_page("entry")
	await app.get_tree().process_frame
	await app.get_tree().process_frame
	for cycle in range(2):
		await click_frontend("Single", "single")
		assert(app._frontend.canvas.get_node_or_null("NewGame") != null)
		assert(app._frontend.canvas.get_node_or_null("LoadGame") != null)
		await click_frontend("NewGame", "selmap")
		if cycle == 0:
			var expected := ["aiji", "island", "paris", "space", "train", "japan", "china"]
			var titles := ["埃及", "未来人工岛", "法国", "宇宙空间站", "美国", "日本", "中国"]
			var positions := [Vector2(132, 106), Vector2(272, 106), Vector2(62, 226), Vector2(202, 226), Vector2(342, 226), Vector2(132, 346), Vector2(272, 346)]
			for i in range(expected.size()):
				var map_name: String = expected[i]
				var hex := app._frontend.canvas.get_node("Map_" + map_name) as TextureButton
				assert(hex.position == positions[i], "Map occupies the wrong original slot: " + map_name)
				await click_frontend("Map_" + map_name, "selmap")
				assert(app._frontend.selected_map == map_name)
				assert(app._frontend.canvas.get_node("MapDescription").text.begins_with(titles[i]))
				assert(app._frontend.canvas.get_node("MapPreview").texture.resource_path.ends_with("/" + map_name + ".png"))
			await click_frontend("Map_island", "selmap")
		await click_frontend("Confirm", "start")
		if cycle == 0:
			assert(app._frontend.selected_map == "island")
			assert(app._frontend.canvas.get_node("SelectedMap").texture.resource_path.ends_with("/island.png"))
		await click_frontend("Back", "selmap")
		await click_frontend("Back", "single")
		await click_frontend("Back", "entry")
	# The second original hex must also start the island map, not just show its art.
	app._port_edit.text = "0"
	await click_frontend("Single", "single")
	await click_frontend("NewGame", "selmap")
	await click_frontend("Map_island", "selmap")
	await click_frontend("Confirm", "start")
	await click_frontend("StartGame", "start")
	assert(Net.sim != null and Net.sim.map.name == "island", "Second hex started the wrong board")
	app._on_leave()
	await app.get_tree().process_frame
	print("FRONTEND MOUSE NAVIGATION PASS: all seven slots and island start verified")

func check_editor() -> void:
	app._frontend.show_page("start")
	await app.get_tree().process_frame
	workbench.refresh()
	var target: Control = app._frontend._role_name
	workbench.select(workbench.targets.find(target))
	var key := str(target.get_meta("ui_id"))
	var before := workbench.properties(target)
	var previous: Variant = workbench.overrides.get(key)
	workbench.fields[0].value += 7
	assert(is_equal_approx(target.position.x, float(before.rect[0]) + 7))
	workbench.save_path = "user://ui-layout-editor-verification.json"
	workbench.save()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(workbench.save_path))
	assert(saved.has(key))
	workbench.apply(target, before)
	workbench.apply(target, saved[key])
	assert(is_equal_approx(target.position.x, float(before.rect[0]) + 7))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(workbench.save_path))
	workbench.save_path = UiWorkbench.SAVE_PATH
	workbench.apply(target, before)
	if previous == null: workbench.overrides.erase(key)
	else: workbench.overrides[key] = previous
	workbench.selected = null

func shot(id: String) -> void:
	await app.get_tree().process_frame
	await app.get_tree().process_frame
	await app.get_tree().create_timer(0.45).timeout
	workbench.scan()
	await RenderingServer.frame_post_draw
	var image := app.get_viewport().get_texture().get_image()
	assert(image.save_png(output + "/" + id + ".png") == OK)
	var rows: Array = []
	workbench.audit(app._ui, rows)
	report[id] = rows
	print("UI SHOT ", id)
