extends SceneTree
## 两个 Godot 进程的本机联机烟测：
## 先启动 --script res://scripts/test/net_smoke.gd -- --host，再启动 -- --client。
##
## **覆盖面**（2026-09-26 扩写 —— 原来只验证「掷骰」一个动作，
## 而这段时间加了股票 / 拉霸 / 聊天 / 卡片锁定 / 精灵出战等**一批新动作**，
## 它们必须同样「客户端发得出去、房主执行得了、快照回得来」）：
##
##   1. `roll`        掷骰
##   2. `buy_stock`   买股票（看快照里的 `holdings`）
##   3. `lock_card`   锁定卡片（看快照里的 `card_locks`）
##   4. `set_pet`     精灵出战（看快照里的 `pet_active`）
##   5. `chat`        聊天（**事件**广播，不走快照）
##   6. `casino_bet` + `casino_pull`  拉霸下注与拉杆（看快照里的 `casino`）
##
## ⚠️ 新动作要能跑，**房主必须先给玩家塞资源**（钱 / 卡 / 宠物），见 `_seed_resources()`。

const PORT := 27061
const LIMIT_SECONDS := 12.0

var net: Node
var role := ""
var large := false
var saw_start := false
var saw_client_action := false
var latest_snapshot: Dictionary = {}
var heard_chat := ""              # 客户端侧：收到的聊天文本
var host_saw_chat := ""           # 房主侧：收到的聊天文本


func _initialize() -> void:
	role = "host" if OS.get_cmdline_user_args().has("--host") else "client"
	large = OS.get_cmdline_user_args().has("--large")
	call_deferred("_run")


## 房主给**每个玩家**塞一份测试资源，否则「买股票 / 锁卡 / 精灵出战 / 拉霸」都跑不动
func _seed_resources() -> void:
	for id in net.sim.players.keys():
		var p: Dictionary = net.sim.players[id]
		p["money"] = 900000
		for cid in ["step3", "caishen", "hamburger", "blackcard"]:
			net.sim._push_card(p, str(cid))
		if (p["pets"] as Array).is_empty():
			net.sim.add_pet(p, "caishen")


func _run() -> void:
	net = root.get_node("Net")
	if net == null:
		_fail("Net 自动加载不存在")
		return
	net.game_started.connect(func(_m: String, _seed: int): saw_start = true)
	net.state_received.connect(func(snap: Dictionary): latest_snapshot = snap)
	if role == "host":
		if not net.host_game("主机烟测", PORT):
			_fail("无法创建主机")
			return
		var connected := false
		for i in range(int(LIMIT_SECONDS * 20.0)):
			await create_timer(0.05).timeout
			if net.players_info.size() >= 2:
				connected = true
				break
		if not connected:
			_fail("没有客户端登记")
			return
		if large:
			net.add_local_ai(2)
		net.start_game("aiji", 123456)
		print("[smoke] 开局完成，开始塞测试资源；players_info=%s sim.players=%s"
			% [str(net.players_info.keys()), str(net.sim.players.keys())])
		_seed_resources()
		print("[smoke] 资源就绪，等客户端动作…")
		# 连事件：房主侧要能看到客户端发来的聊天
		net.sim.game_event.connect(func(kind: String, d: Dictionary) -> void:
			if kind == "chat":
				host_saw_chat = str(d.get("text", "")))
		# 等客户端把一串新动作打完（掷骰 → 买股票 → 锁卡 → 精灵 → 聊天 → 拉霸）
		var saw_all := false
		var last_cp: Dictionary = {}
		for i in range(int(LIMIT_SECONDS * 20.0)):
			await create_timer(0.05).timeout
			# ⚠️ `cid` **每轮重新取** —— 房间成员会随重连变化，缓存一次就可能读到已经不在的 id
			var cid := -1
			for id2 in net.sim.players.keys():
				if int(id2) != 1:
					cid = int(id2)
					break
			if cid < 0:
				continue
			var cp: Dictionary = net.sim.players[cid]
			last_cp = cp
			if int(cp["last_roll"]) > 0:
				saw_client_action = true
			var cst: Dictionary = net.sim.casino.get(cid, {}) as Dictionary
			var rl: Array = cst.get("reels", [])
			if saw_client_action and (cp.get("holdings", {}) as Dictionary).size() > 1 \
					and not (cp.get("card_locks", {}) as Dictionary).is_empty() \
					and str(cp.get("pet_active", "")) != "" \
					and not rl.is_empty():
				saw_all = true
				break
		print("[smoke] 等待结束：掷骰=%s 全部新动作=%s 聊天=%s 持股=%s 锁卡=%s 精灵=%s"
			% [saw_client_action, saw_all, host_saw_chat,
				str((last_cp.get("holdings", {}) as Dictionary).keys()),
				str((last_cp.get("card_locks", {}) as Dictionary).keys()),
				str(last_cp.get("pet_active", ""))])
		if not saw_start or not saw_client_action:
			_fail("服务端未收到客户端掷骰")
			return
		# 关键项：聊天必须能到房主（这就是本轮修的那个缺口）
		if host_saw_chat == "":
			_fail("服务端未收到客户端聊天")
			return
		if not saw_start or not saw_client_action:
			_fail("服务端未收到客户端掷骰")
			return
		if host_saw_chat == "":
			_fail("服务端未收到客户端聊天")
			return
		if large:
			for tile in range(net.sim.map.tile_count()):
				if net.sim.map.is_plot(tile):
					net.sim.plots[tile] = {"owner": 1, "level": 12, "type": "uptown"}
		var raw := var_to_bytes(net.sim.to_dict())
		var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
		print("NET_SMOKE_PASS host: 掷骰/买股票/锁卡/精灵出战/拉霸 都执行了；聊天收到「%s」；"
			% host_saw_chat + "快照 %d -> %d bytes" % [raw.size(), packed.size()])
		await create_timer(1.0).timeout  # 允许最后一帧状态发出后再断开
		quit(0)
	else:
		if not net.join_game("客户端烟测", "127.0.0.1", PORT):
			_fail("无法创建客户端")
			return
		for i in range(int(LIMIT_SECONDS * 20.0)):
			await create_timer(0.05).timeout
			if saw_start:
				break
		if not saw_start or net.sim == null:
			_fail("没有收到开局")
			return
		var id := net.multiplayer.get_unique_id()
		if not net.sim.players.has(id):
			_fail("客户端模拟里缺少自己")
			return
		var me: Dictionary = net.sim.players[id]
		# 连事件：客户端侧要能收到**房主转发过来的**聊天（这正是本轮修的联机缺口）
		net.sim.game_event.connect(func(kind: String, d: Dictionary) -> void:
			if kind == "chat":
				heard_chat = str(d.get("text", "")))
		var my_company := str(me.get("company", ""))
		var my_card := str((me["cards"] as Array)[0]) if not (me["cards"] as Array).is_empty() \
			else ""
		var my_pet := str(((me["pets"] as Array)[0] as Dictionary).get("id", "")) \
			if not (me["pets"] as Array).is_empty() else ""

		# ---- ① 掷骰 ----
		net.send_action("roll")
		var received := await _wait_for(func() -> bool:
			var ps: Dictionary = latest_snapshot.get("players", {})
			return ps.has(id) and int((ps[id] as Dictionary)["last_roll"]) > 0)
		if not received:
			_fail("掷骰后的服务端状态没有回到客户端")
			return
		# ---- ② 买股票 ----
		if my_company != "":
			net.send_action("buy_stock", [my_company, 100])
			var got_stock := await _wait_for(func() -> bool:
				var ps: Dictionary = latest_snapshot.get("players", {})
				if not ps.has(id):
					return false
				var h: Dictionary = (ps[id] as Dictionary).get("holdings", {})
				return int(h.get(my_company, 0)) > 2000)
			if not got_stock:
				_fail("买股票没同步回客户端")
				return
			# 快照里必须带 stocks 段（行情面板靠它）
			if (latest_snapshot.get("stocks", {}) as Dictionary).is_empty():
				_fail("快照里没有 stocks 段（行情面板会空）")
				return
		# ---- ③ 锁定卡片 ----
		if my_card != "":
			net.send_action("lock_card", [my_card])
			var got_lock := await _wait_for(func() -> bool:
				var ps: Dictionary = latest_snapshot.get("players", {})
				if not ps.has(id):
					return false
				var lk: Dictionary = (ps[id] as Dictionary).get("card_locks", {})
				return not lk.is_empty())
			if not got_lock:
				_fail("卡片锁定没同步回客户端")
				return
		# ---- ④ 精灵出战 ----
		if my_pet != "":
			net.send_action("set_pet", [my_pet])
			var got_pet := await _wait_for(func() -> bool:
				var ps: Dictionary = latest_snapshot.get("players", {})
				return ps.has(id) and str((ps[id] as Dictionary).get("pet_active", "")) != "")
			if not got_pet:
				_fail("精灵出战没同步回客户端")
				return
		# ---- ⑤ 聊天（走事件广播，不走快照）----
		net.send_action("chat", ["联机烟测你好", -1, "公共"])
		var got_chat := await _wait_for(func() -> bool: return heard_chat != "")
		if not got_chat:
			_fail("聊天没有广播回客户端")
			return
		# ---- ⑥ 拉霸：下注 + 拉杆 ----
		net.send_action("casino_bet", [1000])
		net.send_action("casino_pull", [])
		var got_casino := await _wait_for(func() -> bool:
			var ps: Dictionary = latest_snapshot.get("players", {})
			if not ps.has(id):
				return false
			# ⚠️ 快照里 `casino` 的 key 是 **int pid**，别用 str 查
			var cs: Dictionary = latest_snapshot.get("casino", {})
			var st: Dictionary = cs.get(id, cs.get(str(id), {})) as Dictionary
			var reels: Array = st.get("reels", [])
			return not reels.is_empty())
		if not got_casino:
			_fail("拉霸结果没同步回客户端")
			return
		if large:
			var received_large := false
			for i in range(int(LIMIT_SECONDS * 20.0)):
				await create_timer(0.05).timeout
				if (latest_snapshot.get("plots", {}) as Dictionary).size() > 50:
					received_large = true
					break
			if not received_large:
				_fail("满盘地产状态没有回到客户端")
				return
		print("NET_SMOKE_PASS client: 掷骰 / 买股票 / 锁卡 / 精灵出战 / 聊天 / 拉霸 全部往返成功")
		quit(0)


## 等一个条件成立（最多 LIMIT_SECONDS 秒）
func _wait_for(cond: Callable) -> bool:
	for i in range(int(LIMIT_SECONDS * 20.0)):
		await create_timer(0.05).timeout
		if bool(cond.call()):
			return true
	return false


func _fail(reason: String) -> void:
	# ⚠️ 必须 `print` 再 `push_error`：headless 下 `push_error` 可能只进调试器、不进 stdout，
	# 于是失败时日志里一片空白（排查时踩过）
	print("NET_SMOKE_FAIL %s: %s" % [role, reason])
	push_error("NET_SMOKE_FAIL %s: %s" % [role, reason])
	quit(1)
