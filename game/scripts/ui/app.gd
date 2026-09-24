extends Node
## App —— 根控制器：主菜单 / 大厅 / 对局 三态切换
##
## 界面全部用代码构建（P0 阶段优先保证可运行、可验证；
## 后续做画面升级时再迁移到 .tscn + 主题资源）。

enum Screen { MENU, LOBBY, GAME }

var screen: int = Screen.MENU

var _ui: CanvasLayer
var _world: Node3D
var _board: BoardView
var _camera: Camera3D

var _menu_root: Control
var _lobby_root: Control
var _hud: Control

var _name_edit: LineEdit
var _ip_edit: LineEdit
var _port_edit: LineEdit
var _map_opt: OptionButton
var _host_btn: Button
var _join_btn: Button
var _solo_btn: Button
var _status: Label

var _lobby_list: VBoxContainer
var _start_btn: Button
var _lobby_hint: Label

var _hud_money: Label
var _hud_players: VBoxContainer
var _hud_tile: Label
var _hud_log: RichTextLabel
var _btn_roll: Button
var _btn_buy: Button
var _btn_upgrade: Button
var _btn_card: OptionButton

var _snapshot: Dictionary = {}
var _last_log_count: int = 0
var _log_lines: Array = []

# ---- 演示模式（godot --path game -- --demo），用于离屏验收截图 ----
var _demo := false
var _demo_time := 0.0
var _demo_next_act := 1.0
var _demo_shots := 0
const DEMO_SHOT_AT := [3.0, 5.5, 8.0, 11.0]

# ---- 主菜单截图模式（godot --path game -- --menushot）----
var _menu_shot := false
var _menu_shot_t := 0.0

# ---- 单人练习冒烟测试（godot --path game -- --solotest）----
# 直接走生产入口 _on_solo()，避免"只用 demo 路径自证"
var _solo_test := false
var _solo_test_t := 0.0

const WORLD_HEIGHT := 0.0


func _ready() -> void:
	# 无头自检模式：godot --headless --path game -- --selftest
	if OS.get_cmdline_user_args().has("--selftest"):
		var t := SelfTest.new()
		t.run()
		get_tree().quit(0 if t._fail == 0 else 1)
		return

	_ui = CanvasLayer.new()
	add_child(_ui)
	_world = Node3D.new()
	add_child(_world)
	_setup_world()
	_build_menu()
	_build_lobby()
	_build_hud()
	_show(Screen.MENU)

	Net.lobby_changed.connect(_on_lobby_changed)
	Net.game_started.connect(_on_game_started)
	Net.state_received.connect(_on_state)
	Net.log_received.connect(_on_log)
	Net.connection_failed.connect(_on_conn_fail)
	Net.disconnected.connect(_on_disconnected)

	if OS.get_cmdline_user_args().has("--demo"):
		_start_demo()
	elif OS.get_cmdline_user_args().has("--menushot"):
		_menu_shot = true
	elif OS.get_cmdline_user_args().has("--solotest"):
		_solo_test = true
		_on_solo()          # 生产入口，原样调用


func _report_solo_test() -> void:
	var sim_alive: bool = Net.sim != null
	var running := false
	var n_players := 0
	var map_name := "<无>"
	if sim_alive:
		running = Net.sim.running
		n_players = Net.sim.players.size()
		if Net.sim.map != null:
			map_name = Net.sim.map.name

	var ok: bool = sim_alive and running and n_players == 4 \
		and Net.ai_ids.size() == 3 and map_name == "china"

	print("========== 单人练习冒烟测试 ==========")
	print("  sim 存在   : %s" % str(sim_alive))
	print("  逻辑运行中 : %s" % str(running))
	print("  玩家数     : %d  (期望 4)" % n_players)
	print("  本地 AI 数 : %d  (期望 3)" % Net.ai_ids.size())
	print("  地图       : %s  (期望 china)" % map_name)
	if sim_alive:
		for id in Net.sim.player_ids():
			var p: Dictionary = Net.sim.players[id]
			print("    - %-16s 资金 %7d  位置 %d" % [str(p["name"]), int(p["money"]), int(p["tile"])])
	print("结果: %s" % ("PASS" if ok else "FAIL"))
	print("=====================================")
	get_tree().quit(0 if ok else 1)


func _start_demo() -> void:
	_demo = true
	_name_edit.text = "房主"
	if not Net.host_game("房主"):
		push_error("demo: host 失败")
		get_tree().quit(1)
		return
	Net.add_local_ai(3)
	Net.start_game("china")
	print("[demo] 已开局，开始自动演示")


func _process(delta: float) -> void:
	if _menu_shot:
		_menu_shot_t += delta
		if _menu_shot_t > 0.8:
			_menu_shot = false
			_capture("D:/Projects/RichMan/menu_shot.png")
			await get_tree().create_timer(0.8).timeout
			get_tree().quit(0)
		return

	if _solo_test:
		_solo_test_t += delta
		if _solo_test_t > 2.5:
			_solo_test = false
			_report_solo_test()
		return

	if not _demo:
		return
	_demo_time += delta

	# 只有人类玩家由演示脚本代打；电脑玩家由 Net 的 AI 系统自行驱动
	if _demo_time >= _demo_next_act:
		_demo_next_act += 1.1
		Net.send_action("roll")
		Net.send_action("buy")
		Net.send_action("upgrade")

	if _demo_shots < DEMO_SHOT_AT.size() and _demo_time >= float(DEMO_SHOT_AT[_demo_shots]):
		_capture("D:/Projects/RichMan/demo_shot_%d.png" % _demo_shots)
		_demo_shots += 1

	if _demo_time > float(DEMO_SHOT_AT[-1]) + 2.0:
		print("[demo] 演示结束，退出")
		get_tree().quit(0)


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	print("[demo] 截图 %s -> %s" % [path, "OK" if err == OK else "失败 %d" % err])

func _unhandled_input(e: InputEvent) -> void:
	if screen == Screen.GAME and e.is_action_pressed("roll_dice"):
		if _btn_roll.visible and not _btn_roll.disabled:
			Net.send_action("roll")

# ------------------------------------------------------------------ 3D 世界

func _setup_world() -> void:
	_camera = Camera3D.new()
	_camera.name = "Cam"
	_world.add_child(_camera)
	_camera.position = Vector3(0, 22, 18)
	_camera.rotation_degrees = Vector3(-52, 0, 0)
	_camera.current = true

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -35, 0)
	light.light_energy = 1.1
	_world.add_child(light)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.085, 0.095, 0.12)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.45, 0.45, 0.5)
	e.ambient_light_energy = 0.9
	env.environment = e
	_world.add_child(env)

	_board = BoardView.new()
	_board.name = "Board"
	_world.add_child(_board)
	_board.visible = false

# ------------------------------------------------------------------ 主菜单

func _build_menu() -> void:
	_menu_root = Control.new()
	_menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_menu_root)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(420, 0)
	box.position = Vector2(-210, -190)
	box.add_theme_constant_override("separation", 10)
	_menu_root.add_child(box)

	var title := Label.new()
	title.text = "大富翁 6 · 即时制复刻"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := Label.new()
	sub.text = "权威服务端联机 · 素材取自原版 gamedata.pck"
	sub.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	box.add_child(_spacer(8))

	box.add_child(_label("玩家昵称"))
	_name_edit = LineEdit.new()
	_name_edit.text = "老板"
	box.add_child(_name_edit)

	box.add_child(_label("地图"))
	_map_opt = OptionButton.new()
	var default_idx := 0
	for m in MapData.available_maps():
		var md := MapData.load_from(m)
		var label: String = "%s  (%s · %d 格)" % [md.display_name, m, md.tile_count()] \
			if md != null else m
		_map_opt.add_item(label)
		_map_opt.set_item_metadata(_map_opt.item_count - 1, m)
		if m == "china":
			default_idx = _map_opt.item_count - 1
	_map_opt.select(default_idx)
	box.add_child(_map_opt)

	box.add_child(_spacer(6))

	# 单人练习：一键开局，对阵 3 名电脑（验收表现效果最快的入口）
	_solo_btn = Button.new()
	_solo_btn.text = "▶  单人练习（对阵 3 名电脑）"
	_solo_btn.custom_minimum_size = Vector2(420, 46)
	_solo_btn.add_theme_font_size_override("font_size", 17)
	box.add_child(_solo_btn)
	_solo_btn.pressed.connect(_on_solo)

	var sep := Label.new()
	sep.text = "—— 或者联机 ——"
	sep.add_theme_color_override("font_color", Color(0.45, 0.48, 0.56))
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sep)

	var host_row := HBoxContainer.new()
	host_row.add_theme_constant_override("separation", 8)
	box.add_child(host_row)
	host_row.add_child(_label("端口"))
	_port_edit = LineEdit.new()
	_port_edit.text = str(Net.DEFAULT_PORT)
	_port_edit.custom_minimum_size = Vector2(90, 0)
	host_row.add_child(_port_edit)
	_host_btn = Button.new()
	_host_btn.text = "创建房间（主机）"
	_host_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_row.add_child(_host_btn)

	box.add_child(_spacer(6))

	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	box.add_child(join_row)
	join_row.add_child(_label("主机 IP"))
	_ip_edit = LineEdit.new()
	_ip_edit.text = "127.0.0.1"
	_ip_edit.custom_minimum_size = Vector2(150, 0)
	join_row.add_child(_ip_edit)
	_join_btn = Button.new()
	_join_btn.text = "加入房间"
	_join_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(_join_btn)

	box.add_child(_spacer(10))
	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(1.0, 0.72, 0.35))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(420, 0)
	box.add_child(_status)

	_host_btn.pressed.connect(_on_host)
	_join_btn.pressed.connect(_on_join)

# -------------------------------------------------------------------- 大厅

func _build_lobby() -> void:
	_lobby_root = Control.new()
	_lobby_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_lobby_root)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(400, 0)
	box.position = Vector2(-200, -160)
	box.add_theme_constant_override("separation", 10)
	_lobby_root.add_child(box)

	var t := Label.new()
	t.text = "房间大厅"
	t.add_theme_font_size_override("font_size", 26)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)

	_lobby_hint = Label.new()
	_lobby_hint.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74))
	_lobby_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_lobby_hint)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 180)
	box.add_child(panel)
	_lobby_list = VBoxContainer.new()
	_lobby_list.add_theme_constant_override("separation", 6)
	panel.add_child(_lobby_list)

	_start_btn = Button.new()
	_start_btn.text = "开始游戏"
	box.add_child(_start_btn)
	_start_btn.pressed.connect(func(): Net.start_game(_selected_map()))

	var leave := Button.new()
	leave.text = "返回"
	box.add_child(leave)
	leave.pressed.connect(_on_leave)

# ---------------------------------------------------------------------- HUD

func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_hud)

	# 左上：自己的资产
	var tl := VBoxContainer.new()
	tl.position = Vector2(16, 12)
	tl.add_theme_constant_override("separation", 4)
	_hud.add_child(tl)
	_hud_money = Label.new()
	_hud_money.add_theme_font_size_override("font_size", 22)
	tl.add_child(_hud_money)
	_hud_tile = Label.new()
	_hud_tile.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	tl.add_child(_hud_tile)

	# 右上：全部玩家
	var tr := VBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.position = Vector2(-230, 12)
	tr.custom_minimum_size = Vector2(214, 0)
	tr.add_theme_constant_override("separation", 4)
	_hud.add_child(tr)
	_hud_players = VBoxContainer.new()
	_hud_players.add_theme_constant_override("separation", 4)
	tr.add_child(_hud_players)

	# 左下：日志（半透明，避免遮挡棋盘）
	var bl := PanelContainer.new()
	bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl.position = Vector2(16, -176)
	bl.custom_minimum_size = Vector2(430, 160)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.08, 0.72)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	bl.add_theme_stylebox_override("panel", sb)
	_hud.add_child(bl)
	_hud_log = RichTextLabel.new()
	_hud_log.scroll_following = true
	_hud_log.bbcode_enabled = false
	bl.add_child(_hud_log)

	# 右下：操作按钮
	var br := VBoxContainer.new()
	br.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	br.position = Vector2(-220, -230)
	br.custom_minimum_size = Vector2(200, 0)
	br.add_theme_constant_override("separation", 8)
	_hud.add_child(br)

	_btn_roll = Button.new()
	_btn_roll.text = "掷骰子  (空格)"
	_btn_roll.custom_minimum_size = Vector2(200, 44)
	br.add_child(_btn_roll)
	_btn_roll.pressed.connect(func(): Net.send_action("roll"))

	_btn_buy = Button.new()
	_btn_buy.text = "购买地产"
	_btn_buy.custom_minimum_size = Vector2(200, 40)
	br.add_child(_btn_buy)
	_btn_buy.pressed.connect(func(): Net.send_action("buy"))

	_btn_upgrade = Button.new()
	_btn_upgrade.text = "升级地产"
	_btn_upgrade.custom_minimum_size = Vector2(200, 40)
	br.add_child(_btn_upgrade)
	_btn_upgrade.pressed.connect(func(): Net.send_action("upgrade"))

	_btn_card = OptionButton.new()
	_btn_card.custom_minimum_size = Vector2(200, 40)
	br.add_child(_btn_card)
	_btn_card.item_selected.connect(func(i):
		var cid: Variant = _btn_card.get_item_metadata(i)
		if cid != null:
			Net.send_action("card", [str(cid)]))

	var leave := Button.new()
	leave.text = "退出对局"
	br.add_child(leave)
	leave.pressed.connect(_on_leave)

# ------------------------------------------------------------- 界面切换

func _show(s: int) -> void:
	screen = s
	_menu_root.visible = (s == Screen.MENU)
	_lobby_root.visible = (s == Screen.LOBBY)
	_hud.visible = (s == Screen.GAME)
	_board.visible = (s == Screen.GAME)

func _selected_map() -> String:
	## 下拉项显示的是中文名，真实地图名存在 metadata 里
	var m: Variant = _map_opt.get_item_metadata(_map_opt.selected)
	return str(m) if m != null else "china"

func _on_solo() -> void:
	## 一键人机对战：房主 + 3 名本地电脑，直接开局
	_status.text = ""
	if not Net.host_game(_name_edit.text, int(_port_edit.text)):
		return
	Net.add_local_ai(3)
	Net.start_game(_selected_map())

func _on_host() -> void:
	_status.text = ""
	if Net.host_game(_name_edit.text, int(_port_edit.text)):
		_show(Screen.LOBBY)
		_lobby_hint.text = "等待其他玩家加入…  你的 IP: %s" % _local_ip()

func _on_join() -> void:
	_status.text = "正在连接…"
	if Net.join_game(_name_edit.text, _ip_edit.text, int(_port_edit.text)):
		_show(Screen.LOBBY)
		_lobby_hint.text = "已连接，等待房主开始"

func _on_leave() -> void:
	Net.leave()
	_world_clear_players()
	_show(Screen.MENU)

func _on_conn_fail(msg: String) -> void:
	_status.text = msg
	if screen == Screen.LOBBY:
		_show(Screen.MENU)

func _on_disconnected() -> void:
	if screen != Screen.MENU:
		_show(Screen.MENU)
		_status.text = "已断开连接"

func _local_ip() -> String:
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."):
			return a
	return "127.0.0.1"

# ------------------------------------------------------------------ 回调

func _on_lobby_changed(peers: Array) -> void:
	for c in _lobby_list.get_children():
		c.queue_free()
	for p in peers:
		var l := Label.new()
		l.text = "%s%s" % [p["name"], "   [房主]" if p["host"] else ""]
		l.add_theme_font_size_override("font_size", 17)
		_lobby_list.add_child(l)
	_start_btn.visible = Net.is_host
	_start_btn.disabled = peers.size() < 1

func _on_game_started(map_name: String, _seed_val: int) -> void:
	_log_lines.clear()
	_hud_log.text = ""
	_last_log_count = 0
	_board.build(MapData.load_from(map_name))
	_show(Screen.GAME)
	_on_log("对局开始 · 地图：%s · %d 格" % [_board.map.display_name, _board.map.tile_count()])
	_on_log("实时制：1 天 = %.0f 秒，静止 %.0f 秒会睡着" % [
		Rules.seconds_per_day(), Sim.IDLE_SLEEP_SECONDS])

func _on_state(snap: Dictionary) -> void:
	_snapshot = snap
	if screen != Screen.GAME:
		return
	_board.sync(snap)
	_hud_refresh(snap)

func _on_log(text: String) -> void:
	_log_lines.append(text)
	if _log_lines.size() > 200:
		_log_lines = _log_lines.slice(_log_lines.size() - 200)
	_hud_log.text = "\n".join(_log_lines)

# ------------------------------------------------------------------ HUD 刷新

func _hud_refresh(snap: Dictionary) -> void:
	var my_id := multiplayer.get_unique_id()
	var players: Dictionary = snap.get("players", {})
	var plots: Dictionary = snap.get("plots", {})

	for c in _hud_players.get_children():
		c.queue_free()
	for id in players.keys():
		var p: Dictionary = players[int(id)]
		var l := Label.new()
		var tag := " ◀ 你" if int(id) == my_id else ""
		l.text = "%s%s\n  %d 元" % [p["name"], tag, int(p["money"])]
		l.add_theme_font_size_override("font_size", 14)
		if not p["alive"]:
			l.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
			l.text = "%s（出局）" % p["name"]
		else:
			l.add_theme_color_override("font_color", _hex_to_color(p["color"]))
		_hud_players.add_child(l)

	var me: Dictionary = players.get(my_id, {})
	if not me.is_empty():
		_hud_money.text = "%d 元" % int(me["money"])
		var t: Dictionary = _board.map.tile(int(me["tile"]))
		var desc: String = str(t.get("street", t.get("name", "")))
		if plots.has(int(me["tile"])):
			desc += "（%s 的 %d 级）" % [_owner_name(players, plots[int(me["tile"])]["owner"]),
										int(plots[int(me["tile"])]["level"])]
		_hud_tile.text = "位置 [%d/%d] %s   HP %d" % [
			int(me["tile"]), _board.map.tile_count(), desc, int(me["hp"])]

		var can_act: bool = int(me["moving"]) == 0 and bool(me["alive"])
		_btn_roll.disabled = not can_act
		_btn_buy.disabled = not (can_act and int(me["last_plot"]) >= 0
			and not plots.has(int(me["last_plot"])))
		_btn_upgrade.disabled = not (can_act and plots.has(int(me["tile"]))
			and int(plots[int(me["tile"])]["owner"]) == my_id
			and int(plots[int(me["tile"])]["level"]) < Sim.MAX_BUILD_LEVEL)
		_refresh_card_options(me)

func _refresh_card_options(me: Dictionary) -> void:
	var cards: Array = me.get("cards", [])
	if cards.size() == _btn_card.item_count and cards.size() > 0:
		var same := true
		for i in range(cards.size()):
			if str(_btn_card.get_item_metadata(i)) != str(cards[i]):
				same = false
				break
		if same:
			return
	_btn_card.clear()
	for cid in cards:
		var c := Rules.card_by_id(str(cid))
		_btn_card.add_item("用卡：%s" % c.get("name", cid))
		_btn_card.set_item_metadata(_btn_card.item_count - 1, str(cid))
	if cards.is_empty():
		_btn_card.add_item("（无卡）")
		_btn_card.disabled = true
	else:
		_btn_card.disabled = false

func _owner_name(players: Dictionary, oid) -> String:
	if players.has(int(oid)):
		return str(players[int(oid)]["name"])
	return "?"

func _world_clear_players() -> void:
	if _board != null:
		_board.clear()

# ------------------------------------------------------------------- 小工具

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", Color(0.78, 0.82, 0.9))
	return l

func _hex_to_color(h: String) -> Color:
	if h == "":
		return Color.WHITE
	return Color.html(h)
