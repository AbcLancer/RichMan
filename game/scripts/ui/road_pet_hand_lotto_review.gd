extends "res://scripts/ui/card_flow_review.gd"

func hover(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await app.get_tree().create_timer(.18).timeout

func run(root) -> void:
	app = root
	output = "res://../docs/screenshots/road-pet-hand-lotto-review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	app._port_edit.text = "0"
	app._frontend.start_requested.emit({"map": "aiji", "role": 5, "players": 2, "money": 300000, "credit": 200})
	Net.set_process(false)
	var sim: Sim = Net.sim
	sim.time = Sim.ENTRY_SECONDS + .1
	var me: Dictionary = sim.players[1]
	me.cards = ["hamburger", "stay", "roadblock"]
	app._on_state(sim.to_dict())
	app._loading.hide()
	await app.get_tree().create_timer(.3).timeout
	check(app._card_ids.size() == 3 and app._card_ids == me.cards, "all three distinct cards appear in acquisition order")
	var rects: Array[Rect2] = []
	for slot in app._card_slots:
		var rect: Rect2 = slot.box.get_global_rect()
		for old in rects: check(not rect.intersects(old), "hand cards have separate hit areas")
		rects.append(rect)
		check(not app.get_node("UiWorkbench").targets.has(slot.box) and slot.box.get_meta("ui_inspector_skip", false), "dynamic card ignores stale saved geometry")
	check(rects.size() == 3 and rects[0].position.x < rects[1].position.x and rects[1].position.x < rects[2].position.x, "three cards fit in one ordered row")
	var empty_plot_has_frame := false
	for surface in app._board._tile_nodes:
		for child in (surface as Node).get_children():
			if str(child.name).begins_with("EmptyEdge"): empty_plot_has_frame = true
	check(not empty_plot_has_frame, "empty plots have no added green frame")
	var static_road_label := false
	for child in app._board.get_children():
		if child is Label3D: static_road_label = true
	check(not static_road_label, "road points and street names have no permanent 3D labels")
	await shot("three-cards")
	var info_point := Vector2(-1, -1)
	for plot_idx in range(sim.map.tile_count()):
		if not sim.map.is_plot(plot_idx): continue
		var world: Vector3 = sim.map.plot_transform(plot_idx).origin
		if app._board._cam().is_position_behind(world): continue
		var candidate: Vector2 = app._board._cam().unproject_position(world)
		if candidate.x > 240 and candidate.x < 920 and candidate.y > 110 and candidate.y < 460:
			info_point = candidate
			break
	if info_point.x >= 0:
		var right := InputEventMouseButton.new()
		right.button_index = MOUSE_BUTTON_RIGHT
		right.position = info_point
		right.global_position = info_point
		right.pressed = true
		app._input(right)
		await app.get_tree().process_frame
		right.pressed = false
		app._input(right)
		await app.get_tree().process_frame
	check(app._tile_info_panel.visible and app._tile_info_label.text.contains("路") and
		app._tile_info_label.text.contains("空地"), "right-clicking an empty plot opens its road and price explanation")
	await shot("road-right-click-info")
	app._close_topmost()
	check(not app._tile_info_panel.visible, "right-click road explanation can be dismissed")
	for player in app._board._player_nodes.values():
		check(not player.get_node("PColorDisc").visible, "idle player has no colored foot disc")
	var prices := {"jingling": 40, "caishen": 100, "qiongshen": 40, "dushen": 80,
		"tushen": 60, "guaishou": 60, "emo": 80}
	for pet_id in prices:
		check(sim.pet_price(pet_id) == prices[pet_id], "original screenshot shop price for " + pet_id)
	app._shop_stock = ["jingling", "caishen", "qiongshen", "dushen"]
	me.pet_shop_stock = app._shop_stock.duplicate()
	me.pet_shop_open = true
	app._open_shop("pethouse")
	await app.get_tree().process_frame
	check(app._shop_bg.size.x <= 1.7 * app._ui_scale * 256, "pet shop matches original compact panel scale")
	var avatar: Button
	var label: Label
	for node in app._shop_nodes:
		if node is Button and node.name == "BuyPet_caishen": avatar = node
		if node is Label and node.name == "PetName_caishen": label = node
	check(avatar != null and label != null, "portrait button and separate passive name label exist")
	check(label.mouse_filter == Control.MOUSE_FILTER_IGNORE and avatar.tooltip_text.contains("100"), "price shown on avatar target and name cannot buy")
	for node in app._shop_nodes:
		if node is Label and node.name.begins_with("Pet"):
			check(app._shop_bg.get_global_rect().encloses(node.get_global_rect()), "pet labels stay inside shop artwork")
	await shot("pet-shop-aligned")
	await click(avatar.get_global_rect().get_center())
	check(app._shop_pending == "pet:caishen" and app._pop_text.text.contains("100"), "clicking avatar opens correct 100-point confirmation")
	app._pop_confirm()
	check(int(me.credit) == 100 and sim.has_pet(me, "caishen"), "confirmation buys pet and deducts the shown price")
	app._on_state(sim.to_dict())
	check(str(me.pet_shop_stock[1]) == "" and not sim.act_buy_pet(1, "caishen"), "bought pet vanishes from its slot and cannot be bought again")
	var stale_sold_label := false
	for node in app._shop_nodes:
		if is_instance_valid(node) and str(node.name) in ["BuyPet_caishen", "PetName_caishen", "PetPrice_caishen"]:
			stale_sold_label = true
	check(not stale_sold_label, "sold pet portrait, name and price are all removed from its shelf slot")
	await shot("pet-shop-after-purchase")
	app._close_shop()
	var active_pet: Dictionary = sim.active_pet(me)
	active_pet.fullness = Sim.PET_FULLNESS_MAX
	app._on_state(sim.to_dict())
	check(app._pet_skill_btn.visible, "full pet bar reveals the character-panel skill button")
	await shot("pet-skill-ready")
	await click(app._pet_skill_btn.get_global_rect().get_center())
	check(is_equal_approx(sim.pet_energy(active_pet), sim.pet_max_energy(active_pet) - sim.pet_cost(str(active_pet.id), int(active_pet.level))) and float(me.effects.no_rent_until) > sim.time,
		"character-panel skill button activates the selected pet")
	var fresh_shelf := ["tushen", "emo", "hutu", "huaxian"]
	app._on_game_event("pethouse_open", {"pid": 1, "stock": fresh_shelf})
	check(app._shop_stock == fresh_shelf, "new pet shop visit keeps its fresh shelf despite an older state snapshot")
	await shot("pet-shop-reopened")
	for sold_index in range(4):
		var shelf_with_hole := fresh_shelf.duplicate()
		var sold_id := str(shelf_with_hole[sold_index])
		shelf_with_hole[sold_index] = ""
		app._on_game_event("buy_pet", {"pid": 1, "stock": shelf_with_hole})
		var visible_names: Array = []
		for node in app._shop_nodes:
			if is_instance_valid(node) and str(node.name).begins_with("PetName_"):
				visible_names.append(str(node.name).trim_prefix("PetName_"))
		check(visible_names.size() == 3 and not visible_names.has(sold_id),
			"selling slot %d removes only its pet name and keeps three aligned items" % sold_index)
	app._close_shop()
	var candidates: Array = sim.card_map_candidates(1, "roadblock")
	check(not candidates.is_empty(), "roadblock offers selectable road points")
	app._set_card_target_mode("roadblock")
	var tile := -1
	for candidate in candidates:
		var world: Vector3 = app._board.tile_pos_of(int(candidate))
		if app._board._cam().is_position_behind(world): continue
		var screen: Vector2 = app._board._cam().unproject_position(world)
		if screen.x > 200 and screen.x < app.get_viewport().get_visible_rect().size.x - 350 and screen.y > 120 and screen.y < 480:
			tile = int(candidate)
			break
	if tile < 0: tile = int(candidates[0])
	var point: Vector2 = app._board._cam().unproject_position(app._board.tile_pos_of(tile))
	await hover(point)
	var marker := app._board._road_target_nodes[tile] as MeshInstance3D
	check((marker.material_override as StandardMaterial3D).albedo_color.r > .9 and (marker.material_override as StandardMaterial3D).albedo_color.g < .5, "hovered road point turns red")
	await shot("roadblock-target-red")
	await hover(Vector2(5, 5))
	check((marker.material_override as StandardMaterial3D).albedo_color.g > .8, "unhovered candidate returns green")
	app._clear_card_target_mode()
	Net.send_action("card", ["roadblock", tile])
	await app.get_tree().process_frame
	check(not me.cards.has("roadblock") and sim._obstacle_at(tile).get("kind", "") == "roadblock", "actual card action creates authoritative roadblock")
	var block := app._board._obstacle_nodes.get(tile) as Node3D
	check(block != null and block.visible and block.get_child(0) is MeshInstance3D, "original roadblock model rendered at chosen tile")
	await shot("roadblock-placed")
	var next := (tile + 3) % sim.map.tile_count()
	var next2 := (tile + 6) % sim.map.tile_count()
	sim.road_objs[next] = {"kind": "card", "born": sim.road_day}
	sim.road_objs[next2] = {"kind": "crystal", "born": sim.road_day}
	app._on_state(sim.to_dict())
	for pair in [[next, "card"], [next2, "crystal"]]:
		var model := (app._board._road_nodes[pair[0]] as Node3D).get_node("OriginalRoadItem") as OriginalMesh
		check(model != null and model._frames.size() > 1, "original animated %s CVD mesh used" % pair[1])
	me.tile = next
	app._on_state(sim.to_dict())
	await app.get_tree().create_timer(.5).timeout
	await shot("original-card-model")
	me.tile = next2
	app._on_state(sim.to_dict())
	await app.get_tree().create_timer(.5).timeout
	await shot("original-ring-model")
	sim._remove_obstacle(tile)
	app._on_state(sim.to_dict())
	check(not (app._board._obstacle_nodes[tile] as Node3D).visible, "cleared roadblock disappears from board")
	for kind in ["caishen", "fushen", "qiongshen", "shuaishen", "thief", "robber", "hanbao", "petegg", "dianjuan"]:
		var item: Node3D = app._board._make_road_node(tile, kind)
		var native_model := item.get_node_or_null("OriginalRoadItem") as OriginalMesh
		check(native_model != null and native_model._frames.size() > 1, "original animated roadside model for " + kind)
		var native_skin := native_model._materials[0] as ShaderMaterial if native_model != null else null
		check(native_skin != null and bool(native_skin.get_shader_parameter("has_skin")),
			"original roadside texture imported for " + kind)
		item.queue_free()
	var god_tile := 20
	sim.road_objs[god_tile] = {"kind": "caishen", "born": sim.road_day}
	me.tile = 18
	app._on_state(sim.to_dict())
	var god_model := (app._board._road_nodes[god_tile] as Node3D).get_node("OriginalRoadItem") as OriginalMesh
	var god_skin := god_model._materials[0] as ShaderMaterial
	check(god_skin != null and bool(god_skin.get_shader_parameter("has_skin")),
		"Caishen roadside animation binds its original texture")
	app._board.focus_on(app._board.tile_pos_of(god_tile))
	await app.get_tree().create_timer(.35).timeout
	await shot("road-caishen-model")
	check(app._board._tile_nodes[24].visible and app._board._tile_nodes[25].visible,
		"Egyptian teleport endpoints keep their carpets")
	check(not app._board._tile_nodes[9].visible, "ordinary road event has no carpet")
	var owned_tile := 0
	var renter: Dictionary = sim.players[sim.player_ids()[1]]
	sim.plots[owned_tile] = {"owner": 1, "level": 0, "type": "",
		"paid_base": float(sim.empty_plot_price()) / sim.price_scale()}
	var renter_cash := int(renter.money)
	me.effects.rest_until = sim.time + 8.0
	sim._resolve_plot(renter, owned_tile, sim.map.tile(owned_tile))
	check(int(renter.money) == renter_cash, "idling property owner cannot collect rent")
	app._on_state(sim.to_dict())
	check(str((app._board._player_nodes[1] as Node3D).get_meta("base_clip", "")) == "slee",
		"idling player uses original sleep animation")
	var owned_border := (app._board._plot_nodes[owned_tile] as Node3D).get_node("Edge0") as MeshInstance3D
	check((owned_border.material_override as StandardMaterial3D).albedo_color.r < .05, "abnormal owner property border turns black")
	check(app._hud_stock_value._text == app._comma(sim.stock_portfolio_value(me)) and
		app._hud_estate_value._text == app._comma(sim.estate_value(me)) and
		app._hud_points._text == str(int(me.credit)) and
		app._hud_price_index._text == ("%.1f" % sim.price_scale()).trim_suffix(".0"),
		"top bar reports stocks, estate value, points and price index")
	me.effects.rest_until = 0.0
	sim._resolve_plot(renter, owned_tile, sim.map.tile(owned_tile))
	check(int(renter.money) < renter_cash, "rent resumes immediately after owner wakes")
	app._on_state(sim.to_dict())
	check((owned_border.material_override as StandardMaterial3D).albedo_color.r > .05, "property border restores owner color")
	for abnormal_key in ["sleep_until", "hospital_until", "alien_until"]:
		var cash_before := int(renter.money)
		me.effects[abnormal_key] = sim.time + 8.0
		sim._resolve_plot(renter, owned_tile, sim.map.tile(owned_tile))
		app._on_state(sim.to_dict())
		check(int(renter.money) == cash_before and
			(owned_border.material_override as StandardMaterial3D).albedo_color.r < .05,
			"%s makes owner's property black and rent-free" % abnormal_key)
		me.effects[abnormal_key] = 0.0
	app._on_state(sim.to_dict())
	app._lotto.open(300, {})
	var chosen := 4
	var spot: Vector2 = app._lotto._cells[chosen - 1].get_global_rect().get_center()
	await hover(spot)
	var pencil := app._lotto._cursors[chosen - 1] as TextureRect
	check(pencil.visible and (pencil.position + pencil.size * Vector2(.78, .86)).distance_to(app._lotto.get_local_mouse_position()) < 2, "pencil nib follows mouse pointer")
	app._lotto.mark_picked(chosen)
	check(app._lotto._marks[chosen - 1].visible and not app._lotto._marks[chosen - 2].visible, "selected lotto number gets red circle")
	await shot("lotto-pencil-ring")
	app._lotto.close()
	var warp_events: Array = []
	sim.game_event.connect(func(kind: String, data: Dictionary):
		if kind == "platform" and bool(data.get("visual_only", false)): warp_events.append(data))
	me.tile = 24
	me.dir = 1
	me.moving = 1
	me.progress = .9
	me.move_after = 0.0
	me.effects.sleep_until = 0.0
	me.effects.rest_until = 0.0
	sim.running = true
	sim.step(.1)
	sim.running = false
	check(int(me.tile) == 25 and warp_events.size() == 1, "Egyptian route jump starts one carpet transfer")
	var flying := false
	for effect in app._board._effects.transients:
		if str(effect.kind) == "teleport": flying = true
	check(flying, "moving carpet is visible beneath the transferring player")
	app._board._follow = false
	app._board._cam_target = (app._board.tile_pos_of(24) + app._board.tile_pos_of(25)) * .5 + Vector3.UP * 1.8
	app._board._cam_dist = 20.0
	app._board._apply_camera(app._board._cam())
	await app.get_tree().create_timer(.35).timeout
	await shot("egypt-carpet-transfer")
	me.credit = 999
	sim._resolve_event(me, int(me.tile), {"event": "cardshop", "name": "卡片商店"})
	await app.get_tree().process_frame
	var card_buttons: Array = []
	for node in app._shop_nodes:
		if node is Button: card_buttons.append(node)
	check(card_buttons.size() == 8 and app._shop.visible, "card shop opens eight clickable ordinary card slots")
	var card_id := str(sim._shop_stock(1)[0])
	var credit_before := int(me.credit)
	await click((card_buttons[0] as Button).get_global_rect().get_center())
	check(app._shop_pending == "card:" + card_id, "card shelf click opens purchase confirmation")
	app._pop_confirm()
	await app.get_tree().process_frame
	check(int(me.credit) == credit_before - sim.card_price(card_id) and str(sim._shop_stock(1)[0]) == "", "purchase charges shown price and leaves a fixed empty slot")
	app._sync_shop()
	card_buttons.clear()
	for node in app._shop_nodes:
		if node is Button: card_buttons.append(node)
	check(card_buttons.size() == 7, "sold slot has no stale clickable label")
	await shot("card-shop-sold-slot")
	app._close_shop()
	print("ROAD PET HAND LOTTO REVIEW: %d checks, %s" % [checks, "FAIL" if failed else "PASS"])
	app.get_tree().quit(1 if failed else 0)
