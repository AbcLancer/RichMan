extends Node
var checks := 0
var failed := false
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error("ECONOMY FAIL: " + label)

func _ready() -> void:
	var s := Sim.new()
	s.setup(MapData.load_from("aiji"), 82)
	s.add_player(1, "Visitor")
	s.add_player(2, "Owner")
	s.time = 10
	var land := -1
	for i in range(s.map.tile_count()):
		if s.map.is_plot(i):
			land = i
			break
	var base := s.empty_plot_price(land)
	check(s._news_all_plots(1.2) > 0 and s.empty_plot_price(land) == int(base * 1.2), "news changes unowned purchase prices")
	s._bind_plot(land, {"owner": 2, "level": 1, "type": "shop"})
	check(s.estate_asset_value(land) == s.plot_value(land), "asset and acquisition price share valuation")
	var rent := s.plot_rent(land)
	s._news_type_rent("shop", 1.1)
	s._news_type_rent("shop", 1.1)
	check(is_equal_approx(float(s.economy_factors.shop), 1.2) and s.plot_rent(land) > rent, "industry news adds global category factors")
	var street := s.map.street_of(land)
	var second := -1
	for i in range(s.map.tile_count()):
		if s.map.is_plot(i) and s.map.street_of(i) == street and not s.map.plot_frontages(land).has(i):
			second = i
			break
	check(second >= 0, "same street provides distinct physical plots")
	s._bind_plot(second, {"owner": 2, "level": 1, "type": "shop"})
	check(s.joint_rent_members(land).size() == 2 and s.plot_rent(land) == s._single_plot_rent(land) + s._single_plot_rent(second), "same owner and category rents sum once per building")
	s.plots[second].type = "industry"
	check(s.joint_rent_members(land).size() == 1, "different categories do not join")
	s.plots[second].type = "shop"
	s.plots[second].level = 0
	check(s.joint_rent_members(land).size() == 1 and s.joint_rent_members(second).size() == 1, "empty land neither contributes nor collects joint rent")
	s.plots[second].level = 1
	s.players[2].effects.sleep_until = s.time + 20
	check(s.plot_rent(land) == 0, "abnormal owner cannot collect joint rent")
	s.players[2].effects.sleep_until = 0
	var old_factor := s._land_factor(land)
	s._change_land_factors(5.0, false, street)
	check(is_equal_approx(s._land_factor(land), old_factor + 5), "price cards add five coefficient points")
	var mirror := Sim.new()
	mirror.setup(s.map, 1)
	mirror.apply_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check(mirror.plot_value(land) == s.plot_value(land) and mirror.plot_rent(land) == s.plot_rent(land), "save and network JSON roundtrip preserve economy")
	for i in range(30): s._news_all_plots(1.3)
	check(is_equal_approx(s._land_factor(land), 100.0) and s._news_all_plots(1.3) == 0, "native cell ceiling reports no changes")
	var news: Array = []
	s.game_event.connect(func(kind, data):
		if kind == "global_news": news.append(data))
	s._fire_global_news(8)
	check(news.size() == 1 and str(news[0].text).contains("没有变化"), "news cannot announce a rise after the native ceiling")
	check(s.casino_multiplier(["sym_god", "sym_god", "sym_god"]) == 17, "three gods pay 17 times")
	check(s.casino_multiplier(["sym7", "sym7", "sym7"]) == 5, "three sevens pay five times")
	check(s.casino_multiplier(["sym_banana", "sym_banana", "sym_banana"]) == 3, "three bananas pay three times")
	check(s.casino_multiplier(["sym_god", "sym7", "sym_god"]) == 2 and s.casino_multiplier(["sym7", "sym7", "sym_banana"]) == 0, "only two gods produce a two-symbol payout")
	var lotto := Sim.new()
	lotto.setup(s.map, 123)
	lotto.add_player(1, "Lotto")
	lotto.time = 10
	var visitor: Dictionary = lotto.players[1]
	var before := int(visitor.money)
	lotto._resolve_event(visitor, land, {"event": "casino", "name": "乐透"})
	check(int(visitor.money) == before and bool(visitor.lotto_can_pick), "lotto entry does not charge")
	var fund_before := lotto.lotto_prize
	check(lotto.act_lotto_pick(1, 1) and int(visitor.money) == before - 1000 and lotto.lotto_prize == fund_before + 1000, "number purchase charges 1000 into city fund")
	for n in range(2, 7):
		visitor.lotto_can_pick = true
		lotto.act_lotto_pick(1, n)
	visitor.lotto_can_pick = true
	check(lotto.lotto_owned_count(1) == 6 and not lotto.act_lotto_pick(1, 7), "six retained numbers is native ownership limit")
	lotto.lotto_numbers = {}
	for n in range(1, 13): lotto.lotto_numbers[n] = 1
	before = int(visitor.money)
	var fund := lotto.lotto_prize
	lotto._lotto_draw()
	check(int(visitor.money) == before + fund and lotto.lotto_numbers.is_empty(), "winner receives entire fund and clears numbers")
	lotto.running = true
	lotto.step(Rules.seconds_per_day() * 13 - lotto.time + .01)
	check(lotto.lotto_last_draw_day == 0, "no premature monthly draw on day 14")
	lotto.step(Rules.seconds_per_day())
	check(lotto.lotto_last_draw_day == 14 and lotto.lotto_prize >= int(10000 * lotto.price_scale()), "draw fires on displayed day 15 with minimum fund")
	var shops := Sim.new()
	shops.setup(s.map, 72)
	shops.add_player(1, "First")
	shops.add_player(2, "Second")
	var shopper: Dictionary = shops.players[1]
	shopper.credit = 999
	shops._resolve_event(shopper, land, {"event": "cardshop", "name": "商店"})
	var shelf := shops._shop_stock(1)
	check(shelf.size() == 8 and not shelf.has("gem") and not shelf.has("nuke"), "native shop has eight ordinary cards and excludes gem/nuke")
	var sold := str(shelf[0])
	check(shops.act_buy_card(1, sold) and not shops._shop_stock(1).has(sold), "sold item disappears from visitor shelf")
	shops._resolve_event(shops.players[2], land, {"event": "cardshop", "name": "商店"})
	check(not shops._shop_stock(1).has(sold) and shops._shop_stock(2).size() == 8, "simultaneous visitors retain independent shelves")
	shops._resolve_event(shopper, land, {"event": "cardshop", "name": "商店"})
	check(shops._shop_stock(1).size() == 8, "new arrival requests a fresh shelf")
	print("ECONOMY FOLLOWUP: %d checks, %s" % [checks, "FAIL" if failed else "PASS"])
	get_tree().quit(1 if failed else 0)
