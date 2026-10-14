extends RefCounted
class_name DebugCommands
## Local single-player test commands. Networking authorization stays in Net.

static func card_id(value: String) -> String:
	if value.is_valid_int(): return Rules.card_id_at(int(value))
	for card in Rules.cards():
		var id := str(card.id)
		if value in [id, str(card.get("name", "")), Rules.card_name(id)]: return id
	return ""

static func pet_id(sim: Sim, value: String) -> String:
	if value.is_valid_int():
		var index := int(value) - 1
		if index >= 0 and index < sim.pet_catalog().size(): return str(sim.pet_catalog()[index].id)
	for pet in sim.pet_catalog():
		if value in [str(pet.id), str(pet.name)]: return str(pet.id)
	return ""

static func execute(sim: Sim, player_id: int, text: String) -> String:
	if sim == null or not sim.players.has(player_id): return "请先开始单人游戏"
	var args := text.strip_edges().split(" ", false)
	if args.is_empty(): return "请输入 /help 查看指令"
	var player: Dictionary = sim.players[player_id]
	var command := str(args[0]).to_lower()
	match command:
		"/help":
			return "/card 名称或编号 [数量]；/cards 页码或clear；/pet 名称或编号 [等级]；/petready；/pets clear；/credit 数值；/money 数值；/goto 路点"
		"/card":
			if args.size() < 2: return "例：/card 飞弹卡 2 或 /card 27"
			var id := card_id(args[1])
			if id == "": return "卡片名称/编号不存在（编号1～42）"
			if args.size() > 2 and not args[2].is_valid_int(): return "数量应为1～99"
			var count := int(args[2]) if args.size() > 2 else 1
			if count < 1 or count > 99: return "数量应为1～99"
			var added := 0
			for i in count:
				if bool(sim._push_card(player, id).get("added", false)): added += 1
			return "已添加%s ×%d（仍受5种手牌上限及锁定保护约束）" % [Rules.card_name(id), added]
		"/cards":
			if args.size() > 1 and args[1] == "clear":
				player.cards.clear()
				player.card_locks.clear()
				return "已清空测试手牌"
			if args.size() < 2 or not args[1].is_valid_int(): return "42张卡分9页：/cards 1 ～ /cards 9；/cards clear 清空"
			var page := int(args[1])
			if page < 1 or page > 9: return "页码应为1～9"
			var names: Array[String] = []
			for number in range((page - 1) * 5 + 1, mini(page * 5, 42) + 1):
				var id := Rules.card_id_at(number)
				if bool(sim._push_card(player, id).get("added", false)): names.append(Rules.card_name(id))
			return "测试卡片第%d页：%s" % [page, "、".join(names)]
		"/pet":
			if args.size() < 2: return "例：/pet 小财神 4 或 /pet 4 4；编号1～9"
			var id := pet_id(sim, args[1])
			if id == "": return "小神仙名称/编号不存在"
			if args.size() > 2 and not args[2].is_valid_int(): return "等级应为1～4"
			var level := int(args[2]) if args.size() > 2 else 1
			if level < 1 or level > 4: return "等级应为1～4"
			if not sim.has_pet(player, id) and sim.add_pet(player, id) != 0: return "背包已满（最多5只），可先 /pets clear"
			player.pets[sim.pet_index_of(player, id)].level = level
			return "已添加%s Lv%d；在左下角精灵仓库选择出战" % [sim.pet_name(id), level]
		"/pets":
			if args.size() > 1 and args[1] == "clear":
				player.pets.clear()
				player.pet_active = ""
				return "已清空测试小神仙背包"
			var names: Array[String] = []
			for pet in sim.pet_catalog(): names.append("%s=%s" % [pet.id, pet.name])
			return "；".join(names)
		"/petready":
			var pet := sim.active_pet(player)
			if pet.is_empty(): return "还没有出战小神仙，请先 /pet 小财神"
			sim._set_pet_energy(pet, sim.pet_max_energy(pet))
			return "%s 能量已满；点击角色栏发光按钮发动技能" % sim.pet_name(str(pet.id))
		"/credit", "/money":
			if args.size() < 2 or not args[1].is_valid_int(): return "例：%s 10000" % command
			var amount := int(args[1])
			if amount < 0 or amount > 100000000: return "数值应为0～100000000"
			player["credit" if command == "/credit" else "money"] = amount
			return "测试%s已设为%d" % ["点券" if command == "/credit" else "现金", amount]
		"/goto":
			if args.size() < 2 or not args[1].is_valid_int(): return "例：/goto 10（只移动，不触发落点事件）"
			var tile := int(args[1])
			if tile < 0 or tile >= sim.map.tile_count(): return "路点编号超出地图范围"
			player.tile = tile
			player.entry_until = 0.0
			player.moving = 0
			player.progress = 0.0
			player.move_after = sim.time
			sim._clear_chance(player)
			return "已移到路点%d：%s" % [tile, sim.map.street_of(tile)]
	return "未知测试指令，请输入 /help"
