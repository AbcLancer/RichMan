extends Node3D
## Local ENet integration check: host plus two independent client processes.
var board: BoardView
var seen: Dictionary = {}
var _started := false

func _ready() -> void:
	Net.game_started.connect(started)
	Net.state_received.connect(func(snapshot):
		if board != null: board.sync(snapshot))
	if OS.get_cmdline_user_args().has("--effects-host"):
		host.call_deferred()
	else:
		client.call_deferred()

func started(_map: String, _seed: int) -> void:
	board = BoardView.new()
	add_child(board)
	board.build(Net.sim.map)
	Net.sim.game_event.connect(func(kind, data):
		seen[kind] = true
		board.on_game_event(kind, data))
	_started = true

func host() -> void:
	assert(Net.host_game("EffectsHost", 31076))
	for i in range(150):
		if Net.players_info.size() == 3: break
		await get_tree().create_timer(.1).timeout
	assert(Net.players_info.size() == 3, "Two local peers must register")
	Net.start_game("aiji", 42)
	Net.sim.running = false
	Net.sim.time = 10
	var ids: Array = Net.sim.player_ids()
	for i in range(ids.size()):
		var player: Dictionary = Net.sim.players[ids[i]]
		player.tile = 0 # This fixture tests nearby network actions after entry.
		player.entry_until = 0.0
		Net.sim.add_pet(player, ["qiongshen", "jingling", "emo"][i])
		Net.sim.add_pet(player, "caishen") # Inactive ownership must not create a second follower.
		player.credit = 1000
		player.pets[1].fullness = 100.0
		player.pets[0].skill_at = 10.0
		player.cards = ["roadblock"]
	Net.sim.players[1].effects.invincible_until = 20
	Net._broadcast_state()
	await get_tree().create_timer(.4).timeout
	Net.sim._ev("pay_rent", Net.sim.players[1], {"to": ids[1], "amount": 12345})
	Net.sim._ev("blast", Net.sim.players[1], {"idx": 0, "radius": 1})
	Net.sim._ev("pet_skill", Net.sim.players[ids[2]], {"pet": "emo"})
	assert(board._effects.pets.size() == 3 and board._effects.shields.size() == 1)
	await get_tree().create_timer(2).timeout
	assert(Net.sim.obstacles.size() == 2, "Both clients must place their selected roadblock through server actions")
	for remote_id in ids.slice(1):
		var remote: Dictionary = Net.sim.players[remote_id]
		var active := Net.sim.active_pet(remote)
		assert(str(active.id) == "caishen" and Net.sim.pet_energy(active) == 15.0)
		assert(remote.credit == 1000, "Remote skill consumes energy, not player credits")
	Net.sim.act_set_active_pet(1, "caishen")
	Net._broadcast_state()
	await get_tree().create_timer(.6).timeout
	assert(board._effects.pets.size() == 3 and board._effects.pets.has("1:caishen") and not board._effects.pets.has("1:qiongshen"))
	Net.sim.time = 22
	Net.sim.players[1].pets.clear()
	Net._broadcast_state()
	await get_tree().create_timer(.4).timeout
	Net.set_process(false)
	var caster: Dictionary = Net.sim.players[1]
	var victim: Dictionary = Net.sim.players[ids[1]]
	caster.tile = 0
	Net.sim.players[ids[2]].tile = Net.sim._wrap(2 + 15)
	caster.moving = 0
	caster.cards = ["shuaishen", "missile"]
	victim.tile = 2
	victim.moving = 0
	victim.stamina = 100.0
	victim.effects.invincible_until = 0.0
	Net.sim.plots[2] = {"owner": int(victim.id), "level": 2, "type": "industry"}
	assert(Net.sim.act_use_card(1, "shuaishen", int(victim.id)))
	caster.tile = Net.sim._wrap(2 - 10) # Within missile aim range, outside the blast.
	assert(Net.sim.act_use_card(1, "missile", 2))
	Net._broadcast_state()
	await get_tree().create_timer(.4).timeout
	Net.sim.running = true
	Net.sim.step(1.01)
	Net.sim.running = false
	assert(float(victim.effects.get("hospital_until", 0)) > Net.sim.time)
	assert(int(Net.sim.plots[2].level) == 1)
	Net._broadcast_state()
	await get_tree().create_timer(6).timeout
	print("EFFECTS ENET HOST PASS: broadcast state and events to two peers")
	get_tree().quit()

func client() -> void:
	assert(Net.join_game("EffectsClient", "127.0.0.1", 31076))
	var visible_remote := false
	var switched_remote := false
	var card_requested := false
	var pet_requested := false
	var pet_confirmed := false
	var card_confirmed := false
	var saw_card_flight := false
	var saw_card_impact := false
	var mine := multiplayer.get_unique_id()
	var chosen_tile := -1
	for i in range(180):
		await get_tree().create_timer(.1).timeout
		if not _started or Net.sim == null: continue
		if not Net.sim.pending_card_impacts.is_empty(): saw_card_flight = true
		for player in Net.sim.players.values():
			if float(player.effects.get("hospital_until", 0)) > Net.sim.time and int(player.effects.get("no_upgrade_steps", 0)) == 30:
				var actor: Node3D = board._player_nodes[int(player.id)].get_node("OriginalActor")
				saw_card_impact = not actor.is_visible_in_tree() and int(Net.sim.plots[2].level) == 1
		if not visible_remote and board._effects.pets.size() == 3 and board._effects.shields.size() == 1 and board._effects.casts.size() >= 3:
			visible_remote = true
			assert(Net.sim.players[1].pets.size() == 2 and not board._effects.pets.has("1:caishen"), "Initial active/inactive pet state: " + str(board._effects.pets.keys()))
		if visible_remote and not card_requested:
			card_requested = true
			chosen_tile = Net.sim.player_ids().find(mine) + 1
			assert(Net.sim.card_road_candidates(mine, "roadblock").has(chosen_tile))
			Net.send_action("card", ["roadblock", 30]) # Invalid range must preserve the hand.
			await get_tree().create_timer(.15).timeout
			assert(Net.sim.players[mine].cards.has("roadblock"))
			Net.send_action("card", ["roadblock", chosen_tile])
		if visible_remote and not pet_requested:
			pet_requested = true
			var pet_count: int = Net.sim.players[mine].pets.size()
			Net.debug_command("/pet 花仙子")
			assert(Net.sim.players[mine].pets.size() == pet_count and not Net.sim.has_pet(Net.sim.players[mine], "huaxian"), "Remote debug request must be refused")
			Net.send_action("set_pet", ["caishen"])
			Net.send_action("pet_skill")
			Net.send_action("pet_skill") # Reliable repeat is refused because energy is no longer full.
		if pet_requested and not pet_confirmed:
			var active := Net.sim.active_pet(Net.sim.players[mine])
			pet_confirmed = str(active.id) == "caishen" and Net.sim.pet_energy(active) == 15.0 and int(Net.sim.players[mine].credit) == 1000 and float(Net.sim.players[mine].effects.no_rent_until) > 10.0
		if card_requested and not card_confirmed and not Net.sim.players[mine].cards.has("roadblock"):
			var obstacle := Net.sim._obstacle_at(chosen_tile)
			card_confirmed = not obstacle.is_empty() and int(obstacle.owner) == mine
		if board._effects.pets.has("1:caishen") and not board._effects.pets.has("1:qiongshen"): switched_remote = true
		if visible_remote and switched_remote and card_confirmed and pet_confirmed and saw_card_flight and saw_card_impact and seen.has("card_status_applied") and seen.has("missile_launch") and seen.has("pay_rent") and seen.has("blast") and seen.has("pet_skill") and board._effects.pets.size() == 1 and board._effects.shields.is_empty():
			print("EFFECTS ENET CLIENT PASS: one active pet, remote switch, authoritative card selection/rejection, cast, shield, rent/explosion and removal")
			# Keep both observers connected until the host finishes its checks.
			await get_tree().create_timer(4).timeout
			get_tree().quit()
			return
	assert(false, "Remote effects/state did not arrive: " + str([visible_remote, switched_remote, card_confirmed, saw_card_flight, saw_card_impact, seen.keys()]))
