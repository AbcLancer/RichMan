extends SceneTree
## 两个 Godot 进程的本机联机烟测：
## 先启动 --script res://scripts/test/net_smoke.gd -- --host，再启动 -- --client。

const PORT := 27061
const LIMIT_SECONDS := 12.0

var net: Node
var role := ""
var large := false
var saw_start := false
var saw_client_action := false
var latest_snapshot: Dictionary = {}


func _initialize() -> void:
	role = "host" if OS.get_cmdline_user_args().has("--host") else "client"
	large = OS.get_cmdline_user_args().has("--large")
	call_deferred("_run")


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
		for i in range(int(LIMIT_SECONDS * 20.0)):
			await create_timer(0.05).timeout
			for id in net.sim.players.keys():
				if int(id) != 1 and int(net.sim.players[id]["last_roll"]) > 0:
					saw_client_action = true
					break
			if saw_client_action:
				break
		if not saw_start or not saw_client_action:
			_fail("服务端未收到客户端掷骰")
			return
		if large:
			for tile in range(net.sim.map.tile_count()):
				if net.sim.map.is_plot(tile):
					net.sim.plots[tile] = {"owner": 1, "level": 12, "type": "uptown"}
		var raw := var_to_bytes(net.sim.to_dict())
		var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
		print("NET_SMOKE_PASS host: joined, started, remote roll accepted; snapshot %d -> %d bytes"
			% [raw.size(), packed.size()])
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
		net.send_action("roll")
		var received := false
		for i in range(int(LIMIT_SECONDS * 20.0)):
			await create_timer(0.05).timeout
			var players: Dictionary = latest_snapshot.get("players", {})
			if players.has(id) and int(players[id]["last_roll"]) > 0:
				received = true
				break
		if not received:
			_fail("掷骰后的服务端状态没有回到客户端")
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
		print("NET_SMOKE_PASS client: connected, started, action confirmed by snapshot")
		quit(0)


func _fail(reason: String) -> void:
	push_error("NET_SMOKE_FAIL %s: %s" % [role, reason])
	quit(1)
