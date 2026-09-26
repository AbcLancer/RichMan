extends Node
## Net —— 联机层（autoload）
##
## 架构：权威服务端（房主即 peer 1）
##   - 服务端跑 Sim.step()，把权威状态按固定频率广播
##   - 客户端只发「意图」（掷骰/买地/升级/用卡），由服务端校验后生效
##   - 客户端不做本地预测（P0 阶段：状态量极小，直接同步最稳）
##
## 后续 P2 会把「房主即服务端」换成独立大厅 + 专用服务器；
## 因为 Sim 与 IO 完全解耦，届时只需替换本文件。

signal lobby_changed(peers: Array)
signal game_started(map_name: String, seed_val: int)
signal state_received(snapshot: Dictionary)
signal log_received(text: String)
signal connection_failed(reason: String)
signal disconnected()

const DEFAULT_PORT := 27060
const MAX_PLAYERS := 4
const TICK_RATE := 20.0          # 服务端逻辑帧率
const SNAPSHOT_RATE := 10.0      # 状态广播频率
const SNAPSHOT_UDP_BUDGET := 1200 # 留出 RPC/ENet 头部；超限则走可靠通道
const SNAPSHOT_MAX_RAW := 1000000

# ---- 本地 AI（权威服务端直接模拟，不走网络）----
# 名字与颜色按原版 Role.txt 的角色顺序对齐（洋红=钱夫人 / 土黄=阿土伯 / 蓝=宫本宝藏 …）
const AI_BASE_ID := 1000
const AI_NAMES := ["电脑·阿土伯", "电脑·宫本宝藏", "电脑·乌咪"]
# 注意：这是【演示节奏】，不是原版参数。
# 原版 AI 停留时间为 6~20 秒（AI_Player_MinPause1..3），已如实记录在
# data/rules/realtime.json 的 ai.pause_seconds；验收时用原版节奏会太闷，故调快。
const AI_THINK_MIN := 1.1
const AI_THINK_MAX := 2.2

var ai_ids: Array = []
var _ai_next: Dictionary = {}

var is_host: bool = false


## 有没有真正的对端（单机时没有 → 别发 RPC，否则报 "RPC on yourself is not allowed"）
func has_remote_peers() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return false
	return multiplayer.get_peers().size() > 0
var in_lobby: bool = false
var map_name: String = "china"
var sim: Sim = null

var players_info: Dictionary = {}   # peer_id -> String(name)

var _tick_acc: float = 0.0
var _snap_acc: float = 0.0
var _pending_seed: int = 0
var _snap_seq: int = 0
var _last_remote_seq: int = -1

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connect_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	set_process(false)

# ------------------------------------------------------------------ 建立连接

func host_game(pname: String, port: int = DEFAULT_PORT) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		connection_failed.emit("无法监听端口 %d（错误 %d）" % [port, err])
		return false
	multiplayer.multiplayer_peer = peer
	is_host = true
	in_lobby = true
	players_info = {1: pname if pname != "" else "房主"}
	_emit_lobby()
	set_process(true)
	return true

func join_game(pname: String, ip: String, port: int = DEFAULT_PORT) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		connection_failed.emit("无法连接 %s:%d（错误 %d）" % [ip, port, err])
		return false
	multiplayer.multiplayer_peer = peer
	is_host = false
	in_lobby = true
	players_info = {}
	_my_name = pname if pname != "" else "玩家"
	set_process(true)
	return true

var _my_name: String = "玩家"

func leave() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_host = false
	in_lobby = false
	sim = null
	players_info.clear()
	ai_ids.clear()
	_ai_next.clear()
	_snap_seq = 0
	_last_remote_seq = -1
	set_process(false)
	disconnected.emit()

# ------------------------------------------------------------------ 本地 AI

func add_local_ai(count: int) -> void:
	## 房主专用：往房间里塞本地电脑玩家（由服务端直接驱动，不占网络连接）
	if not is_host:
		return
	for i in range(count):
		var id: int = AI_BASE_ID + i
		if players_info.has(id):
			continue
		ai_ids.append(id)
		players_info[id] = AI_NAMES[i % AI_NAMES.size()]
	_emit_lobby()

func _drive_ai() -> void:
	if sim == null:
		return
	for id in ai_ids:
		if not sim.players.has(id):
			continue
		var p: Dictionary = sim.players[id]
		if not bool(p["alive"]) or int(p["moving"]) > 0:
			continue
		if sim.time < float(p["effects"]["sleep_until"]):
			continue
		if sim.time < float(_ai_next.get(id, 0.0)):
			continue
		_ai_next[id] = sim.time + randf_range(AI_THINK_MIN, AI_THINK_MAX)
		_ai_think(id, p)

func _ai_think(id: int, p: Dictionary) -> void:
	## 极简 AI：能用本次抵达的机会就用，用不上就掷骰。
	## 「机会」= 走到空地可买 / 走到自己的地可升一级（原版一次一格只给一次机会）。
	## 后续 P1 会按原版 Role.txt 的三项性格权重（害人/股票/买地）重写。
	var kind := str(p.get("last_plot_kind", ""))
	if kind == "buy":
		if sim.act_buy(id):
			return
		sim.act_pass(id)          # 钱不够就放弃，别攥着令牌不动
	elif kind == "upgrade":
		if int(p["money"]) > 120000 and sim.act_upgrade(id):
			return
		sim.act_pass(id)
	sim.act_roll(id)

# ------------------------------------------------------------ 连接事件回调

func _on_peer_connected(id: int) -> void:
	if is_host:
		# 新客户端加入，等服务端收到其 register 后再广播
		pass

func _on_peer_disconnected(id: int) -> void:
	if is_host:
		players_info.erase(id)
		if sim != null:
			sim.remove_player(id)
			sim.log_message.emit("有玩家断线")
		_emit_lobby()

func _on_connected_ok() -> void:
	# 客户端连上后向服务端登记
	_rpc_register.rpc_id(1, _my_name)

func _on_connect_fail() -> void:
	connection_failed.emit("连接失败：目标未响应或版本不一致")
	leave()

func _on_server_disconnected() -> void:
	leave()

# ---------------------------------------------------------------- 大厅同步

@rpc("any_peer", "call_remote", "reliable")
func _rpc_register(pname: String) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	players_info[id] = pname
	_emit_lobby()

@rpc("authority", "call_remote", "reliable")
func _rpc_lobby(peers: Dictionary) -> void:
	players_info = {}
	for k in peers.keys():
		players_info[int(k)] = peers[k]
	_emit_lobby()

func _emit_lobby() -> void:
	var arr: Array = []
	for id in players_info.keys():
		arr.append({"id": id, "name": players_info[id], "host": id == 1})
	arr.sort_custom(func(a, b): return a["id"] < b["id"])
	lobby_changed.emit(arr)
	if is_host:
		_rpc_lobby.rpc(players_info)

# ---------------------------------------------------------------- 开局

func start_game(m: String, seed_val: int = 0) -> void:
	if not is_host:
		return
	map_name = m
	_pending_seed = seed_val if seed_val != 0 else randi()
	_internal_start(map_name, _pending_seed)
	_rpc_start.rpc(map_name, _pending_seed)

@rpc("authority", "call_remote", "reliable")
func _rpc_start(m: String, seed_val: int) -> void:
	_internal_start(m, seed_val)

func _internal_start(m: String, seed_val: int) -> void:
	var md := MapData.load_from(m)
	if md == null:
		push_error("Net: 地图加载失败 %s" % m)
		return
	sim = Sim.new()
	_snap_seq = 0
	_last_remote_seq = -1
	sim.setup(md, seed_val)
	sim.log_message.connect(func(t): log_received.emit(t))
	# 把本地事件转发给客户端（单机 / 没有对端时不做，免得 RPC 报 "on yourself"）
	if is_host and has_remote_peers():
		sim.game_event.connect(func(kind: String, d: Dictionary) -> void:
			_rpc_event.rpc(kind, d))
	for id in players_info.keys():
		sim.add_player(int(id), str(players_info[id]))
	sim.running = true          # 必须显式开启，否则 Sim.step() 会直接返回
	in_lobby = false
	game_started.emit(m, seed_val)

# ---------------------------------------------------------------- 玩家动作

func send_action(action: String, args: Array = []) -> void:
	if is_host:
		_apply_action(multiplayer.get_unique_id(), action, args)
	else:
		_rpc_action.rpc_id(1, action, args)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_action(action: String, args: Array) -> void:
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	_apply_action(sender, action, args)


## ⭐ 房主把 `Sim` 的**语义事件**转发给所有客户端。
##
## 为什么必须有：`Sim._ev()` 只在**本地** `game_event.emit()` —— **房主自己的 UI 接得到**，
## 而客户端的 `Sim` 只是回放快照（`apply_dict`），**不会自己产生事件**
## → 联机时**客户端完全收不到 toast / 音效 / 语音 / 气泡**（2026-09-26 复查联机时发现）。
##
## 客户端收到后在本地**重新 emit** 到 `sim.game_event`，于是 UI 一行都不用改
## （它连的一直是 `Net.sim.game_event`）。`call_remote` 不会回环给房主自己。
@rpc("authority", "call_remote", "reliable")
func _rpc_event(kind: String, data: Dictionary) -> void:
	if sim != null:
		sim.game_event.emit(kind, data)

func _apply_action(who: int, action: String, args: Array) -> void:
	if sim == null:
		return
	match action:
		"roll":
			# args[0] 可选：一次掷几颗骰子（原版 GO 钮左侧的骰子选择器，见 Sim.DICE_PER_ROLL_MAX）
			sim.act_roll(who, int(args[0]) if args.size() > 0 else 1)
		"buy":
			sim.act_buy(who)
		"pass":
			sim.act_pass(who)
		"upgrade":
			# args[0] 可选：空地首次建设时要选的房型（原版 id 92「选择房屋」）
			sim.act_upgrade(who, str(args[0]) if args.size() > 0 else "")
		"card":
			# args[0] = 卡 id；args[1] 可选 = 需要点选对手时的目标玩家 id
			if args.size() > 0:
				sim.act_use_card(who, str(args[0]),
					int(args[1]) if args.size() > 1 else -1,
					str(args[2]) if args.size() > 2 else "")
		"discard":
			# 卡片菜单 id 3「丢弃」
			if args.size() > 0:
				sim.act_discard_card(who, str(args[0]))
		"feed":
			# 卡片菜单 id 4「喂食」（原版菜单第三项）
			if args.size() > 0:
				sim.act_feed_card(who, str(args[0]))
		"lock_card":
			# 卡片菜单 id 2「锁定」：锁着的卡不会被新卡顶掉
			if args.size() > 0:
				sim.act_lock_card(who, str(args[0]))
		"buy_stock":
			# args[0] = 公司名，args[1] = 股数
			if args.size() > 1:
				sim.act_buy_stock(who, str(args[0]), int(args[1]))
		"sell_stock":
			# args[0] = 公司名，args[1] = 股数
			if args.size() > 1:
				sim.act_sell_stock(who, str(args[0]), int(args[1]))
		"chat":
			# args[0] = 文本，args[1] = 私聊目标玩家 id（-1 = 公共），args[2] = 频道名
			if args.size() > 0:
				sim.act_chat(who, str(args[0]),
					int(args[1]) if args.size() > 1 else -1,
					str(args[2]) if args.size() > 2 else "公共")
		"casino_bet":
			# 拉霸：加注（原版三档 +1000 / +5000 / +10000）
			if args.size() > 0:
				sim.act_casino_bet(who, int(args[0]))
		"casino_pull":
			# 拉霸：拉杆
			sim.act_casino_pull(who)
		"lotto_pick":
			# 乐透：挑一个号码（1..12）
			if args.size() > 0:
				sim.act_lotto_pick(who, int(args[0]))
		"walk":
			# 骰子卡：玩家自选前进步数（1..6）
			if args.size() > 0:
				sim.act_walk(who, int(args[0]))
		"buy_pet":
			# 精灵屋：用点券请一位小神仙（Info.txt 203）
			if args.size() > 0:
				sim.act_buy_pet(who, str(args[0]))
		"set_pet":
			# 精灵仓库：选一只设为「出战」
			if args.size() > 0:
				sim.act_set_active_pet(who, str(args[0]))
		"buy_card":
			# 卡片商店：用点券买一张卡（Info.txt 41/42）
			if args.size() > 0:
				sim.act_buy_card(who, str(args[0]))
	# 动作产生的结果立即回灌，降低主观延迟
	_broadcast_state()

# ---------------------------------------------------------------- 主循环

func _process(delta: float) -> void:
	if not is_host or sim == null:
		return
	_tick_acc += delta
	var step_dt := 1.0 / TICK_RATE
	var guard := 0
	while _tick_acc >= step_dt and guard < 8:
		sim.step(step_dt)
		_tick_acc -= step_dt
		guard += 1
	_snap_acc += delta
	if _snap_acc >= 1.0 / SNAPSHOT_RATE:
		_snap_acc = 0.0
		_drive_ai()
		_broadcast_state()

func _broadcast_state() -> void:
	if sim == null:
		return
	var snap := sim.to_dict()
	state_received.emit(snap)          # 房主本地直接用
	var raw := var_to_bytes(snap)
	var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	if packed.is_empty():
		push_warning("Net: 状态快照压缩失败")
		return
	_snap_seq += 1
	if packed.size() <= SNAPSHOT_UDP_BUDGET:
		_rpc_state.rpc(packed, raw.size(), _snap_seq)
	else:
		_rpc_state_large.rpc(packed, raw.size(), _snap_seq)

@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_state(packed: PackedByteArray, raw_size: int, seq: int) -> void:
	if is_host:
		return
	_accept_state(packed, raw_size, seq)


@rpc("authority", "call_remote", "reliable")
func _rpc_state_large(packed: PackedByteArray, raw_size: int, seq: int) -> void:
	if is_host:
		return
	_accept_state(packed, raw_size, seq)


func _accept_state(packed: PackedByteArray, raw_size: int, seq: int) -> void:
	if seq <= _last_remote_seq or raw_size <= 0 or raw_size > SNAPSHOT_MAX_RAW:
		return
	var raw := packed.decompress(raw_size, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != raw_size:
		push_warning("Net: 状态快照解压失败")
		return
	var snap: Variant = bytes_to_var(raw)
	if snap is not Dictionary:
		push_warning("Net: 状态快照格式错误")
		return
	_last_remote_seq = seq
	state_received.emit(snap)
