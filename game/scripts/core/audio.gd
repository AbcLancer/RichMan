extends Node
## Audio —— 原版音频播放中枢（autoload: Audio）
##
## 复刻自原版「大富翁6」的音频分层，共四类：
##   1. effect/NNN.wav  151 个界面/环境音效（id 即文件名，2D/3D 见 sndeffect.txt）
##   2. music/m010NN.mp3  18 首 BGM
##   3. voice/roleK/**    12 角色配音（27 条情景对白 + 42 张卡名 + 12 条"回"话）
##   4. voice/pet/**      9 只宠物 × 9 句
##
## **映射表是原版权威数据，不是猜的**：
##   voice_map.json 由 tools/build_audio_assets.py 从
##   config/Info.txt（消息 id ↔ 配音 id ↔ 中文标签）+ 文件名规律生成，
##   两处独立证据互相印证（例：Info.txt 里 1步卡~5步卡/复制卡/宝石卡 没有配音，
##   而 player/role1/card/ 里恰好也缺 09~13/32/33 这 7 个文件）。
##
## 音效 id 的语义：1 / 2 / 95 由**实证探针**确认，
## 另 29 条由**老板人工试听**确认（2026-09-25）。
## 权威表在 `res://data/rules/sfx.json`（人工 + 实测），本文件的常量与它一一对应；
## `docs/sfx-audition.html` 供把剩下的 120 个音效 + 16 首 BGM 继续标出来。

const MAP_PATH := "res://assets/audio/voice_map.json"
const SFX_PATH := "res://data/rules/sfx.json"

# ---- 音效 id（来源见 res://data/rules/sfx.json）----
# 实证探针（标记音替换 + 回环录音 + FFT 反查）
const SFX_UI_CLICK := 1        # 2D 界面：按钮点击（3 次点击 → 3 次精确命中）
const SFX_UI_CONFIRM := 2      # 2D 界面：确认/进入
const SFX_AMBIENT := 95        # 3D 环境：场景循环底噪
# 老板人工试听（2026-09-25）
const SFX_DICE_STOP := 5       # 骰子滚动结束
const SFX_WIN_SCREEN := 6      # 胜利结算画面
const SFX_LOSE_SCREEN := 7     # 失败结算
const SFX_PET_UPGRADE := 9     # 某个小神仙的地产升级技能（天使/雪精灵类）
const SFX_BUILD_UPGRADE := 12  # 地产升级
const SFX_COIN_SCATTER := 15   # 金币散落声
const SFX_ACTION_DENIED := 19  # 禁止操作的音效
const SFX_DICE_ROLL := 23      # 骰子滚动声
const SFX_CARD_UPGRADE := 24   # 升级卡·全街升级
const SFX_PAY_DEDUCT := 40     # 穷鬼等负面技能导致扣款的声音
const SFX_COIN_DROP := 50      # 金币掉落在桌子上
const SFX_BANK_SETTLE := 52    # 银行结账的声音

# ---- 角色对白的语义键（对应 voice_map.json 里 lines 的键）----
# 键 = 原版消息 id 的后两位（role1 的 1001…1027）
const V_ATTACK := "1"          # 攻击
const V_SELFISH := "3"         # 自利行为
const V_HURT := "5"            # 被害
const V_LIGHT_PUNISH := "7"    # 被轻罚时
const V_HEAVY_PUNISH := "9"    # 被重罚时
const V_NEAR_BANKRUPT := "11"  # 快破产时
const V_WIN := "12"            # 胜利
const V_BANKRUPT := "13"       # 破产
const V_HOSPITAL := "14"       # 住院
const V_LOTTO := "15"          # 中乐透
const V_LAUGH := "16"          # 一般笑
const V_GET_MONEY := "17"      # 得到金钱
const V_LUCKY := "19"          # 大吉事件
const V_FREE_RENT := "21"      # 租金免付
const V_GREET := "23"          # 问候
const V_SLEEP := "25"          # 睡觉
const V_ENTER := "26"          # 登场
const V_MENU := "27"           # 选单

var snd_vol: int = 5           # 0..10，对齐原版 init.txt [sndvol]=5
var music_vol: int = 5         # 0..10，对齐原版 init.txt [musicvol]=5

var mapping: Dictionary = {}   # voice_map.json 内容
var sfx_labels: Dictionary = {}  # sfx.json 内容（音效 id → 用途 / 已接线位置）
var _cache: Dictionary = {}    # path -> AudioStream（命中缓存，避免重复读盘）
var _pool: Array[AudioStreamPlayer] = []
var _pool_idx: int = 0
const POOL_SIZE := 8

var _bgm: AudioStreamPlayer
var _bgm_track: String = ""
var _bgm_playlist: Array = []
var _bgm_index: int = 0
var _bgm_auto: bool = false

var _ready_done: bool = false


func _ready() -> void:
	_load_map()
	_load_labels()
	_bgm = AudioStreamPlayer.new()
	_bgm.name = "Bgm"
	add_child(_bgm)
	_bgm.finished.connect(_on_bgm_finished)
	_apply_volumes()
	_ready_done = true


func _load_map() -> void:
	if not FileAccess.file_exists(MAP_PATH):
		push_warning("[Audio] 缺少 %s —— 先跑 tools/build_audio_assets.py" % MAP_PATH)
		return
	var f := FileAccess.open(MAP_PATH, FileAccess.READ)
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		mapping = parsed
	else:
		push_warning("[Audio] voice_map.json 解析失败")


func _load_labels() -> void:
	## 音效 id → 用途（人工试听 + 实证探针）。缺失不影响播放，只影响自检与文档。
	if not FileAccess.file_exists(SFX_PATH):
		push_warning("[Audio] 缺少 %s" % SFX_PATH)
		return
	var f := FileAccess.open(SFX_PATH, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		sfx_labels = parsed
	else:
		push_warning("[Audio] sfx.json 解析失败")


## 某个音效 id 的用途标签（没有就返回空串）
func sfx_label(id: int) -> String:
	var e: Dictionary = sfx_labels.get("effects", {})
	var v: Variant = e.get("%03d" % id, {})
	if v is Dictionary:
		return str((v as Dictionary).get("label", ""))
	return ""


## 已确认「该在什么时候播」的音效 id 列表（sfx.json 里 wired 非空）
func wired_sfx() -> Array:
	var out: Array = []
	var e: Dictionary = sfx_labels.get("effects", {})
	for k in e.keys():
		var v: Variant = e[k]
		if v is Dictionary and str((v as Dictionary).get("wired", "")) != "":
			out.append(int(str(k)))
	out.sort()
	return out


# ------------------------------------------------------------------ 音量

func set_snd_vol(v: int) -> void:
	snd_vol = clampi(v, 0, 10)
	_apply_volumes()

func set_music_vol(v: int) -> void:
	music_vol = clampi(v, 0, 10)
	_apply_volumes()

func _db(v: int) -> float:
	## 原版 0..10 的线性刻度 → dB；0 = 静音
	if v <= 0:
		return -80.0
	return linear_to_db(float(v) / 10.0)

func _apply_volumes() -> void:
	for p in _pool:
		p.volume_db = _db(snd_vol)
	if _bgm != null:
		_bgm.volume_db = _db(music_vol)


# ------------------------------------------------------------------ 资源

func _stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		_cache[path] = null
		return null
	var s: Resource = load(path)
	_cache[path] = s
	return s


func _player() -> AudioStreamPlayer:
	if _pool.is_empty():
		for i in POOL_SIZE:
			var p := AudioStreamPlayer.new()
			p.volume_db = _db(snd_vol)
			add_child(p)
			_pool.append(p)
	_pool_idx = (_pool_idx + 1) % _pool.size()
	return _pool[_pool_idx]


# ------------------------------------------------------------------ 音效

func effect_kind(id: int) -> String:
	var e: Variant = mapping.get("effects", {}).get("%03d" % id, null)
	if e is Dictionary:
		return str(e.get("kind", "?"))
	return "?"


func play_sfx(id: int) -> bool:
	## 播 2D 界面音效。返回是否真的播了（缺文件时 false，不报错）
	var s := _stream("res://assets/audio/effect/%03d.wav" % id)
	if s == null:
		return false
	var p := _player()
	p.stream = s
	p.play()
	return true


func play_sfx_at(id: int, pos: Vector3, parent: Node = null) -> bool:
	## 播 3D 空间音效（原版 3D 音必须是单声道，素材本身已满足）
	var s := _stream("res://assets/audio/effect/%03d.wav" % id)
	if s == null:
		return false
	var host: Node = parent
	if host == null:
		host = get_tree().current_scene
	if host == null:
		return play_sfx(id)
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = _db(snd_vol)
	p.unit_size = 12.0
	p.max_distance = 120.0
	host.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()
	return true


# ------------------------------------------------------------------ 角色对白

func role_dir(role_idx: int) -> String:
	## 角色序号 1..12 → 素材子目录 role1..role9 / rolea / roleb / rolec
	var roles: Array = mapping.get("roles", [])
	for r in roles:
		if int(r.get("idx", -1)) == role_idx:
			return str(r.get("dir", ""))
	return ""


func role_msgid(role_idx: int, line_key: String) -> int:
	## 后两位键（"1"…"27"）→ 原版消息 id
	## 编号规律（Info.txt）：角色 k 的段号 = 9+k，即 role1→10xx … rolea→19xx … rolec→21xx
	var n := int(line_key)
	if n <= 0:
		return 0
	return (9 + role_idx) * 100 + n


func say(role_idx: int, line_key: String) -> bool:
	## 角色说话（17 种情景，见 V_* 常量）
	var d := role_dir(role_idx)
	if d == "":
		return false
	var mid := role_msgid(role_idx, line_key)
	var s := _stream("res://assets/audio/voice/%s/%d.wav" % [d, mid])
	if s == null:
		return false
	var p := _player()
	p.stream = s
	p.play()
	return true


func say_at(role_idx: int, line_key: String, pos: Vector3) -> bool:
	## 角色在场地上说话 → 3D 定位（原版角色对白是空间音）
	var d := role_dir(role_idx)
	if d == "":
		return false
	var mid := role_msgid(role_idx, line_key)
	var path := "res://assets/audio/voice/%s/%d.wav" % [d, mid]
	var s := _stream(path)
	if s == null:
		return false
	var host: Node = get_tree().current_scene
	if host == null:
		return say(role_idx, line_key)
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = _db(snd_vol)
	p.unit_size = 12.0
	p.max_distance = 150.0
	host.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()
	return true


func say_card(role_idx: int, card_num: int, reply: bool = false) -> bool:
	## 卡片语音：card/<NN>.wav = 卡名；card/<NN>b.wav = 12 张卡的"回"话
	## （原版 exe 的格式串就是 `%ssound\player\%s\card\%.2db.wav`，两位补零）
	var d := role_dir(role_idx)
	if d == "":
		return false
	var name := "%02d%s" % [card_num, "b" if reply else ""]
	var s := _stream("res://assets/audio/voice/%s/card/%s.wav" % [d, name])
	if s == null and reply:
		# 原版数据里的漏网之鱼：role1（钱夫人）只有 `3b.wav` / `4b.wav`（不补零），
		# 而 `03b.wav` 缺失 —— 引擎的格式串要的是补零名，所以**原版这里其实是静音**。
		# 素材既然在盘上，就顺手兜一层让这句能出声；只会影响原版本身就静音的位置。
		s = _stream("res://assets/audio/voice/%s/card/%db.wav" % [d, card_num])
		if s != null:
			push_warning("[Audio] %s 缺 card/%s.wav，回落到不补零写法" % [d, name])
	if s == null:
		return false
	var p := _player()
	p.stream = s
	p.play()
	return true


func say_extra(role_idx: int, extra: String) -> bool:
	## 附加音：w_aside / w_mono / 笑 / 笑2 / 奸笑（只有部分角色带）
	var d := role_dir(role_idx)
	if d == "":
		return false
	var s := _stream("res://assets/audio/voice/%s/%s.wav" % [d, extra])
	if s == null:
		return false
	var p := _player()
	p.stream = s
	p.play()
	return true


func pet_say(pet_idx: int, n: int) -> bool:
	## 宠物语音：pet/<species>/0N.wav（1 发特技 … 9 HP逃离）
	var pets: Array = mapping.get("pets", [])
	for pt in pets:
		if int(pt.get("idx", -1)) == pet_idx:
			var s := _stream("res://assets/audio/voice/pet/%s/%02d.wav" % [str(pt["dir"]), n])
			if s == null:
				return false
			var p := _player()
			p.stream = s
			p.play()
			return true
	return false


# ------------------------------------------------------------------ BGM

## 地图 → BGM 曲目。**实测来源**：把副本里 18 首 MP3 换成唯一频率的 100 秒纯音
## （tools/make_bgm_probe.py），实机走一遍菜单/对局，回环录音后 FFT 反查
## （tools/bgm_identify.py）。详见 docs/sfx-map.md §7.2 / §7.3。
##
## 结论：7 张地图的对局曲**都是 m01009**（740 Hz，7 次独立重复 + 单图复测 = 8/8），
## 菜单/大厅都是 m01001（420 Hz）。所以地图其实不影响选曲，
## 这里仍保留 map→track 表，是为了以后发现差异时一处可改。
const MAP_BGM := {
	"aiji": "m01009",    # 埃及
	"island": "m01009",  # 未来
	"paris": "m01009",   # 法国
	"space": "m01009",   # 太空
	"train": "m01009",   # 美国
	"japan": "m01009",   # 日本
	"china": "m01009",   # 中国
}
const BGM_FALLBACK := "m01009"
const BGM_MENU := "m01001"   # 主菜单/大厅 —— 实测：420 Hz 全程稳定，置信度 1651×–4990×


func map_bgm(map_name: String) -> String:
	## 地图 key（或显示名）→ BGM 曲目 id（"m010NN"）
	if MAP_BGM.has(map_name):
		return str(MAP_BGM[map_name])
	for k in MAP_BGM.keys():
		if map_name.contains(str(k)):
			return str(MAP_BGM[k])
	return BGM_FALLBACK


func play_bgm(track: String, loop: bool = true) -> bool:
	## 单曲播放（loop=true 时循环）。track = "m01001" … "m01018"
	_bgm_auto = false
	return _play_track(track, loop)


func play_bgm_playlist(start_track: String) -> bool:
	## **原版行为**：对局 BGM 不是单曲循环。
	## 实测把标记音做成 100 s 后，引擎播完当前曲目会**自动接下一首**
	## （740 Hz `m01009` 放满 100 s 后转 780 Hz `m01010`），
	## 12 s 标记时每 12.0 s 精确换一首 —— 都是"文件放完就换"。
	## 所以这里按 m01001…m01018 的顺序依次播、放完回卷，单曲本身不循环。
	if bgm_tracks().is_empty():
		return false
	if _bgm_auto and _bgm_track == start_track and _bgm.playing:
		return true   # 已经在放同一首，别因切界面重头来
	_bgm_playlist = bgm_tracks()
	var i: int = _bgm_playlist.find(start_track)
	_bgm_index = i if i >= 0 else 0
	_bgm_auto = true
	return _play_track(str(_bgm_playlist[_bgm_index]), false)


func _play_track(track: String, loop: bool) -> bool:
	var s := _stream("res://assets/audio/music/%s.mp3" % track)
	if s == null:
		# 兼容直接传序号
		if track.is_valid_int():
			return _play_track("m%05d" % int(track), loop)
		return false
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = loop
	_bgm.stream = s
	_bgm.volume_db = _db(music_vol)
	_bgm.play()
	_bgm_track = track
	return true


func _on_bgm_finished() -> void:
	if _bgm_auto:
		advance_bgm()


func advance_bgm() -> bool:
	## 放完一曲接下一首（原版引擎行为，见 docs/sfx-map.md §7.2）
	if _bgm_playlist.is_empty():
		return false
	_bgm_index = (_bgm_index + 1) % _bgm_playlist.size()
	return _play_track(str(_bgm_playlist[_bgm_index]), false)


func bgm_current() -> String:
	return _bgm_track


func stop_bgm() -> void:
	_bgm.stop()
	_bgm_track = ""
	_bgm_auto = false


func bgm_tracks() -> Array:
	return mapping.get("music", [])


# ------------------------------------------------------------------ 环境底噪

var _amb: AudioStreamPlayer3D
var _amb_id: int = -1


func start_ambient(id: int = SFX_AMBIENT, pos: Vector3 = Vector3.ZERO) -> bool:
	## 场景环境底噪（实测：对局中长时间静止时，3D 音效 95 循环不断 285 s）。
	## 素材本身只有 2.023 s，所以这里显式开循环。
	var s := _stream("res://assets/audio/effect/%03d.wav" % id)
	if s == null:
		return false
	if s is AudioStreamWAV:
		var w: AudioStreamWAV = (s as AudioStreamWAV).duplicate()
		var bpf := 2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1
		if w.stereo:
			bpf *= 2
		w.loop_begin = 0
		w.loop_end = w.data.size() / bpf
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s = w
	if _amb == null:
		_amb = AudioStreamPlayer3D.new()
		_amb.name = "Ambient"
		_amb.unit_size = 40.0
		_amb.max_distance = 240.0
		add_child(_amb)
	_amb.stream = s
	_amb.volume_db = _db(snd_vol)
	_amb.position = pos
	_amb.play()
	_amb_id = id
	return true


func stop_ambient() -> void:
	if _amb != null:
		_amb.stop()
	_amb_id = -1


func ambient_id() -> int:
	return _amb_id


func ambient_looping() -> bool:
	## 给 --selftest 用：确认循环真的设上了
	if _amb == null or _amb.stream == null:
		return false
	if _amb.stream is AudioStreamWAV:
		return (_amb.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD
	return false


# ------------------------------------------------------------------ 自检

func audit() -> Dictionary:
	## 给 --selftest 用：核对映射表与素材是否对得上
	var miss: Array = []
	var ok := 0
	for r in mapping.get("roles", []):
		var d := str(r.get("dir", ""))
		for k in r.get("lines", {}).keys():
			var mid := role_msgid(int(r["idx"]), str(k))
			if ResourceLoader.exists("res://assets/audio/voice/%s/%d.wav" % [d, mid]):
				ok += 1
			else:
				miss.append("%s/%d" % [d, mid])
		# 卡名（12 角色 × 35 张）—— 回话不在此列，因为原版盘上 role1/7/8 本身缺/多
		for k in r.get("card_lines", {}).keys():
			if ResourceLoader.exists("res://assets/audio/voice/%s/card/%02d.wav" % [d, int(k)]):
				ok += 1
			else:
				miss.append("%s/card/%02d" % [d, int(k)])
	for pt in mapping.get("pets", []):
		for i in range(1, 10):
			if ResourceLoader.exists("res://assets/audio/voice/pet/%s/%02d.wav" % [str(pt["dir"]), i]):
				ok += 1
			else:
				miss.append("pet/%s/%02d" % [str(pt["dir"]), i])
	for e in mapping.get("effects", {}).keys():
		if ResourceLoader.exists("res://assets/audio/effect/%s.wav" % e):
			ok += 1
		else:
			miss.append("effect/%s" % e)
	for t in mapping.get("music", []):
		if ResourceLoader.exists("res://assets/audio/music/%s.mp3" % t):
			ok += 1
		else:
			miss.append("music/%s" % t)
	return {"ok": ok, "missing": miss}
