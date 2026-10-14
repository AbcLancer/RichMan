extends Node
## Three independent ENet processes, exercising authority and lifecycle boundaries.
const PORT := 31077
var checks := 0
var failed := false
var received_steps := false
var stock_closed_days := 0
var rejected := false
var disconnected := false
var acted: Dictionary = {}

func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("FLOW ENET FAIL: " + label)
		get_tree().quit(1)
		return
	checks += 1

func wait_for(predicate: Callable, label: String) -> void:
	for i in range(120):
		if predicate.call(): return
		await get_tree().create_timer(.05).timeout
	check(false, "timeout: " + label)

func _ready() -> void:
	Net.game_started.connect(func(_map, _seed):
		Net.sim.game_event.connect(func(kind, data):
			if kind == "pet_skill" and int(data.pid) == multiplayer.get_unique_id():
				received_steps = bool(Net.sim.players[data.pid].pending_steps)
			if kind == "stock_closed" and int(data.pid) == multiplayer.get_unique_id():
				stock_closed_days = int(data.days)))
	Net.connection_failed.connect(func(_reason): rejected = true)
	Net.disconnected.connect(func(): disconnected = true)
	if OS.get_cmdline_user_args().has("--flow-host"): host.call_deferred()
	else: client.call_deferred()

func phase(n: int) -> void:
	for p in Net.sim.players.values(): p._probe_phase = n
	Net._broadcast_state()

func host() -> void:
	Net.pick_role = 5
	check(Net.host_game("FlowHost", PORT), "host starts")
	await wait_for(func(): return Net.players_info.size() == 3, "two registrations")
	Net.start_game("aiji", 42)
	Net.set_process(false)
	Net.sim.running = false
	Net.sim.time = 10
	var remote := Net.sim.player_ids().slice(1)
	var land := -1
	for i in range(Net.sim.map.tiles.size()):
		if str(Net.sim.map.tile(i).get("kind", "")) == "plot":
			land = i
			break
	check(land >= 0, "test estate found")
	Net.sim._news_all_plots(1.2)
	Net.sim._tick_estate_index()
	for id in remote:
		var p: Dictionary = Net.sim.players[id]
		check(int(p.role) == int(Net.player_roles[id]), "remote selected role preserved")
		p._probe_land = land
		p._probe_land_price = Net.sim.empty_plot_price(land)
		p._probe_initial_assets = Net.sim.initial_company_assets
		p.entry_until = 0.0
		p.money = 900000
		p.tile = land
		p.last_plot = land
		p.last_plot_kind = "buy"
		Net.sim.add_pet(p, "dushen")
		Net.sim._set_pet_energy(Net.sim.active_pet(p), 16.0)
		p.cards = ["hamburger"]
		p._probe_land = land
	phase(1)
	await wait_for(func(): return Net.sim.plots.has(land), "competing purchase")
	await get_tree().create_timer(.25).timeout
	var owner := int(Net.sim.plots[land].owner)
	check(remote.has(owner), "one remote owns contested land")
	for id in remote:
		check(int(Net.sim.players[id].money) == 900000 - (Net.sim.empty_plot_price(land) if id == owner else 0), "purchase charged once only")
		Net.sim.players[id].last_plot_kind = "upgrade"
		Net.sim.players[id].last_plot = land
	phase(2)
	await wait_for(func(): return int(Net.sim.plots[land].level) > 0, "remote build")
	check(int(Net.sim.plots[land].owner) == owner and Net.sim.plots[land].type == "industry", "build retains owner and type")
	phase(3)
	await wait_for(func():
		for id in remote:
			if int(Net.sim.players[id].moving) != 3: return false
		return true, "feed, skill and selected steps")
	for id in remote:
		var p: Dictionary = Net.sim.players[id]
		check(not p.cards.has("hamburger") and Net.sim.pet_energy(Net.sim.active_pet(p)) == 15.0, "feed adds four, skill consumes once")
		p.moving = 0
		p.lotto_can_pick = true
	phase(4)
	await wait_for(func(): return Net.sim.lotto_numbers.size() == 2, "lotto picks")
	await get_tree().create_timer(.2).timeout
	check(Net.sim.lotto_numbers.size() == 2, "repeat lotto picks rejected per visit")
	Net.sim.stock_closed_until_day = Net.sim.road_day + 3
	for id in remote: Net.sim.players[id].cards = ["gem", "buyland"]
	phase(5)
	await wait_for(func():
		for id in remote:
			if not Net.sim.players[id].cards.has("tudigong"): return false
		return true, "remote gem conversion")
	for id in remote:
		check(Net.sim.players[id].cards == ["tudigong"] and int(Net.sim.players[id].holdings.get(Net.sim.players[id].company, 0)) == 2000, "gem consumes both cards; closed market refuses trade")
	check(Net.sim.start_auction(), "auction opens")
	var base := int(Net.sim.auction.price)
	phase(6)
	await wait_for(func(): return int(Net.sim.auction.price) == base + 200, "both remote bids")
	await get_tree().create_timer(.2).timeout
	check(int(Net.sim.auction.price) == base + 200, "undersized bids rejected")
	var auction_tile := int(Net.sim.auction.tile)
	var winner := int(Net.sim.auction.best)
	var cash := int(Net.sim.players[winner].money)
	Net.sim._auction_settle()
	check(int(Net.sim.plots[auction_tile].owner) == winner and int(Net.sim.players[winner].money) == cash - base - 200, "auction settlement charges winner and grants estate")
	for p in Net.sim.players.values():
		p._probe_auction_tile = auction_tile
		p._probe_auction_winner = winner
	# Paused actions are refused; disconnect still publishes resulting ownership.
	Net.game_paused = true
	phase(7)
	await wait_for(func(): return Net.sim.players.size() == 2, "paused disconnect")
	await get_tree().create_timer(1.5).timeout
	check(Net.sim.players.size() == 2 and Net.players_info.size() == 2, "late join creates no phantom player")
	Net._apply_action(999999, "chat", ["unknown player"])
	check(Net.sim.players.size() == 2, "unknown sender rejected")
	if failed:
		get_tree().quit(1)
		return
	print("FLOW ENET HOST PASS: ", checks, " checks")
	Net.leave()
	await get_tree().create_timer(.3).timeout
	get_tree().quit()

func client() -> void:
	var exits := OS.get_cmdline_user_args().has("--flow-exit")
	Net.pick_role = 8 if exits else 6
	check(Net.join_game("FlowClient", "127.0.0.1", PORT), "client connects")
	await wait_for(func(): return Net.sim != null and Net.sim.players.has(multiplayer.get_unique_id()) and Net.sim.players[multiplayer.get_unique_id()].has("_probe_phase"), "fixture arrives")
	var mine := multiplayer.get_unique_id()
	check(int(Net.sim.players[mine].role) == Net.pick_role, "client selected role agrees with authority")
	var fixture: Dictionary = Net.sim.players[mine]
	check(Net.sim.empty_plot_price(int(fixture._probe_land)) == int(fixture._probe_land_price) and Net.sim.initial_company_assets == int(fixture._probe_initial_assets), "land news factors and inflation baseline survive real network snapshot")
	for i in range(300):
		await get_tree().create_timer(.05).timeout
		if Net.sim == null:
			if disconnected and not exits:
				print("FLOW ENET CLIENT PASS: ", checks, " checks; server disconnect handled")
				get_tree().quit()
				return
			continue
		var p: Dictionary = Net.sim.players[mine]
		var n := int(p.get("_probe_phase", 0))
		if acted.has(n): continue
		acted[n] = true
		match n:
			1:
				Net.send_action("buy")
				Net.send_action("buy")
			2:
				Net.send_action("upgrade", ["industry:1"])
				Net.send_action("upgrade", ["industry:1"])
			3:
				Net.send_action("feed", ["hamburger"])
				Net.send_action("pet_skill")
				await wait_for(func(): return received_steps, "skill event sees pending selection state")
				check(received_steps, "event and authoritative state arrive together")
				Net.send_action("walk", [3])
			4:
				var choice := Net.sim.player_ids().find(mine) + 1
				Net.send_action("lotto_pick", [choice])
				Net.send_action("lotto_pick", [choice + 5])
			5:
				Net.send_action("card", ["gem", -1, "buyland"])
				Net.send_action("buy_stock", [p.company, 100])
				await wait_for(func(): return stock_closed_days > 0, "market closure feedback")
				check(stock_closed_days == 3, "closed market returns populated remaining days")
			6:
				Net.send_action("auction_bid", [100])
				Net.send_action("auction_bid", [1])
			7:
				check(Net.sim.auction.is_empty() and int(Net.sim.plots[int(p._probe_auction_tile)].owner) == int(p._probe_auction_winner), "auction outcome synchronizes")
				if exits:
					Net.leave()
					disconnected = false
					Net.join_game("LateJoin", "127.0.0.1", PORT)
					await wait_for(func(): return rejected, "midgame rejection")
					check(rejected and Net.sim == null and not Net.in_lobby, "late join has clear failure and clean teardown")
					print("FLOW ENET EXIT CLIENT PASS: ", checks, " checks")
					get_tree().quit()
					return
				else:
					await wait_for(func(): return Net.sim.players.size() == 2, "paused removal snapshot")
					check(Net.sim.players.size() == 2, "paused disconnect reaches remaining client")
	check(false, "client flow did not finish")


