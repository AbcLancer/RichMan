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

var _hud_money: HudNumber
var _hud_deposit: HudNumber
var _hud_houses: HudNumber
var _hud_cards: HudNumber
var _hud_credit: HudNumber
var _hud_day: HudNumber
var _hud_log: RichTextLabel
var _btn_bldtype: OptionButton     # 空地首次建设时的房型（原版 Info.txt id 92「选择房屋」）

# ---- 卡片手牌（原版 `uitex/card/1..42_<名>.tga` = samples/card/）----
# 文案全部取自原版 config/String.txt：卡片菜单 1/2/3（使用/锁定/丢弃）、
# 目标提示 1101（请选择对手）、每张卡的说明 9001..9042。
# ⚠ 原版卡片界面的**确切版式没有留下可核对的证据**（实机截图里看不到手牌区，
#   uitex 里也没有卡片面板底图）→ 这里是按原版素材 + 原版文案重建的版式，
#   位置/尺寸属于「刻意偏差」，登记在 docs/ui-audit.md §8。
var _card_bar: Control                         # 手牌条
var _card_bar_open: bool = true                # 卡片夹是否展开
var _card_slots: Array = []                    # [{box, img, btn, cnt}]
var _card_ids: Array = []                      # 每个槽位的卡 id（与 _card_slots 一一对应）
var _card_sig: Array = []                      # 手牌原始列表（排序后，用于变化检测）
var _card_sig_state: Array = []                # 每张卡的可用性原因码（0=能用），同用于变化检测
## 锁定状态**不在这里**（在权威 Sim 的 `p["card_locks"]`，见 `_card_is_locked()`）——
## 满栏顶卡时要跳过锁定的卡，那个判定必须服务端做。
var _card_menu: PanelContainer                 # 点卡片后的菜单
var _card_menu_at: int = -1                    # 菜单当前针对的 slot 下标
var _card_menu_btns: Array = []
var _clamp_btn: TextureButton                  # 卡片夹开关（uitex/other/clamp.png）
var _card_pending: String = ""                 # 正在等「点选对手」的卡 id
var _card_confirm_id: String = ""              # 正在等「是/否」二次确认的卡 id
var _card_hint: Label                          # 「请选择对手」提示条

## 需要「是 / 否」二次确认的卡：会**动到别人已有的资产**的那两张。
## 老板 2026-09-26 反馈「购地卡使用之后没有反应，我记得应该是使用之后出一个二次确认框」。
## 对照 `config/String.txt` id 9020「强制购买当前土地」/ 9008「强占土地」——
## 两张都是「把对手的地产变成自己的」，属不可逆操作，确认一下是对的。
const CARD_CONFIRM_IDS := ["buyland", "tudigong"]
var _step_picker: Control                      # 骰子卡：1..6 步数选择器
var _step_picker_i: int = -1                   # 当前选中步数（-1 = 未选）

## 卡面素材是 128×128（samples/card/<n>_<名>.tga）。老板 2026-09-26 反馈
## 「卡牌太小了」→ 由 62 调到 100 native（卡面自身的 78%），接近原版一张卡
## 占屏宽的 1/10 左右。手牌最多 9 张，1280×720 下总宽 ≈ 835 px。
const CARD_PX := 130.0                         # 手牌里每张卡的显示边长（native）
## 130 = 原版 100 × 1.3 —— 手牌上限收到 5 张之后（`Sim.HAND_MAX`）一排有富余，
## 老板 2026-09-26：「卡片可以再放大个 1.3 倍吧，因为现在只有五张卡了」
const CARD_GAP := 4.0
const CARD_SHOW_MAX := 9                       # 手牌最多显示几张（再多就折叠成 +N）
const CARD_MENU_W := 96.0

# ---- 原版结构 HUD：顶栏 / 左下角色面板 / 右下小地图与图标条 ----
var _topbar: PanelContainer
var _pause_overlay: TextureRect
var _paused: bool = false
var _minimap: Minimap
## 右下角功能区（原版「最下一栏是功能切换按钮」）：
##   ① 新闻 → 日志页 ② 股票 → 股票页 ③ 地图 → 小地图（**默认页**）
##   ④ 聊天区 → 聊天记录页 ⑤ 聊天 → 额外弹出聊天栏 ⑥ 最右下角 → 收起 / 展开
var _br_box: Control = null
var _br_map_panel: Control = null
## 地图面板的底框（切到别的页时要换成透明，但**面板本身得留着占位**）
var _br_map_sb: StyleBox = null
var _br_page := 2                     # 0=日志 1=股票 2=地图 3=聊天记录
var _br_collapsed := false
var _chat_bar: Control = null
var _chat_ch: Button = null
var _chat_input: LineEdit = null
var _chat_log: Label = null
var _chat_lines: Array = []
var _chat_channels: Array = []
var _chat_ch_idx := 0
## ① 日志页 ④ 聊天记录页 —— 都占右下角功能区**同一块地方**，与其他页互斥
var _br_log_page: Control = null
var _br_chat_page: Control = null
## 全局事件**全屏插画**（原版截图 `records/全局事件.png`：浅黄绿描边的插画 + 一行文案）
var _news_pop: Control = null
var _news_art: TextureRect = null
var _news_text: Label = null
var _news_left := 0.0
## 拉霸（老虎机）面板（原版 `uitex/casino/`；老板截图 records/老虎机.png）
var _casino: CasinoPanel = null
var _log_panel: PanelContainer

# 左下角色面板（版式 = 原版 uitex/other/atb.png）
var _char_panel: Control
## 左下角角色面板**右侧**那一排：持有的小神仙（原版就在这里显示 —— 见
## `docs/screenshots/orig/records/使用卡片.png`，「钱夫人」右边就是「小财神」）。
## ⚠️ 原版**没有**「持有小神仙」的独立面板；我们原来在精灵屋左边放的那块是多余的（已去掉）。
var _pet_strip: Control = null
## 右下角常驻的**股票行情面板**（原版就在这里 —— 老板 2026-09-26 的原版截图）
var _stock: StockPanel = null
var _pet_slot: TextureRect = null          # 精灵栏里的**出战精灵头像**
var _pet_strip_nodes: Array = []
const PET_STRIP_PX := 44.0             # 每只小神仙图标的边长（native）
var _char_avatar: TextureRect
var _char_info: Label
var _char_name: Label
var _char_stat: Label
var _char_bar_a: ProgressBar
var _char_bar_b: ProgressBar

# 右侧玩家头像列
var _avatar_col: VBoxContainer
var _avatar_rows: Array = []          # [{node, img, id}, ...]

# 右下图标按钮条
var _icon_bar: Control
var _icon_btns: Array = []

# 动作入口（原版是角色头顶的 GO 气泡 / 落点气泡）
var _go_btn: TextureButton
var _pop: PanelContainer
var _pop_text: Label
var _pop_yes: TextureButton
var _pop_no: TextureButton
var _pop_mode: String = ""            # "" / "buy" / "upgrade"

# ---- GO 钮上的骰子：数量选择器 + 掷出动画（素材 uitex/labar/{骰子,anim}.tga）----
var _dice_count: int = 1                       # 当前选了几颗（1..Sim.DICE_PER_ROLL_MAX）
var _dice_sel: Array = []                      # 选择器上的骰子（TextureRect，未选中=灰）
var _dice_hit: Array = []                      # 盖在骰子上的透明点击区（Button）
var _dice_sel_t: float = 0.0                   # 待机慢转计时
var _dice_fx: Array = []                       # 掷出去的那几颗
var _dice_fx_from: Array = []
var _dice_fx_to: Array = []
var _dice_fx_faces: Array = []
var _dice_fx_t: float = 0.0
var _dice_fx_state: String = ""                # "" / "fly" / "hold"
var _tex_spin: Array = []                      # 16 帧翻滚（懒加载）
var _tex_face: Array = []                      # 6 个面（懒加载）

const DIE_PX := 32.0                           # 素材单帧 32×32
const DIE_FLY_TIME := 1.15                     # 掷出飞行时长（秒）
## ⚠ 必须与 `Sim.ROLL_ANIM_SECONDS` 对齐：这段时间服务端也**不让角色起步**，
##   动画播完（骰子定格）角色才走 —— 原版节奏（老板 2026-09-26 反馈）。
const DIE_HOLD_TIME := 1.9                     # 定格展示点数时长
const DIE_SPIN_FPS := 26.0                     # 飞行中的翻滚速度（帧/秒）
const DIE_IDLE_FPS := 3.5                      # 待机慢转（一眼能看出在转，又不吵）
const DIE_SEL_SIZE := 24.0                     # 选择器骰子显示尺寸（native，量自原版实机）
const DIE_SEL_STEP := 26.0                     # 竖排步距（native）
const DIE_SEL_DX := 2.6                        # 相对 GO 钮左上角（native）
const DIE_SEL_DY := 14.7
const DIE_FLY_SIZE := 46.0                     # 飞出的骰子显示尺寸（native）
## 掷出去的骰子**先上抛再落下**的高度（native）。老板 2026-09-26：
## 「骰子会有抛物线落下的感觉」—— 原来只是直线 lerp，没有弧。
const DIE_FLY_ARC := 120.0

## GO 钮的**屏幕锚点**（视口比例，取的是圆钮中心）。
## 证据：原版实机 07/08/09_牌桌*.png + new_session_board.png **四张截图里
## GO 钮始终停在同一处**（实测归一化 ≈ 0.691, 0.599），而四张里角色位置并不相同
## → 它**不是**贴在角色头上的（角色头顶那个圆盘是三岔路方向选择盘，另一回事）。
## 老板 2026-09-26 标注的目标位在右侧 ≈ (0.782, 0.508)，故取该值。
## ⚠ 这是**固定屏幕位**：相机跟随角色平移时 GO 不动。
const GO_ANCHOR_NORM := Vector2(0.782, 0.508)

# 一次性提示
var _toast_lbl: Label
var _toast_t: float = 0.0


var _snapshot: Dictionary = {}
var _last_log_count: int = 0
var _log_lines: Array = []
var _sim_connected: bool = false   # 是否已把 Audio 接到本局的 Sim.game_event

# ---- 开发用：--showcase 建筑展示（逐类型逐等级摆一排，截图后退出）----
var _showcase := false
var _showcase_t := 0.0
var _showcase_shot := false

# ---- 开发用：--probe=<type>:<level> 单栋对照（只摆一栋，用于逐栋核对模型/贴图）----
var _probe_spec := ""              # 形如 "uptown:1"；空串 = 非 probe 模式

# ---- 演示模式（godot --path game -- --demo），用于离屏验收截图 ----
var _demo := false
var _demo_time := 0.0
var _demo_next_act := 1.0
var _demo_shots := 0
var _demo_overview_done := false
var _demo_cards_done := false
var _demo_map := "aiji"
const DEMO_SHOT_AT := [3.0, 5.5, 8.0, 11.0, 14.0, 16.0]
const DEMO_OVERVIEW_AT := 12.0

# ---- 主菜单截图模式（godot --path game -- --menushot）----
var _menu_shot := false
var _menu_shot_t := 0.0

# ---- 单人练习冒烟测试（godot --path game -- --solotest）----
# 直接走生产入口 _on_solo()，避免"只用 demo 路径自证"
var _solo_test := false
var _solo_test_t := 0.0

# ---- UI 验收截图（godot --path game -- --uishot）----
var _ui_shot := false
var _ui_shot_t := 0.0
var _ui_shot_idle_done := false
var _ui_shot_dice_done := false     # 骰子掷出（飞行中）那一张
var _ui_shot_pop_done := false
var _ui_shot_pop_t := 0.0
var _ui_shot_confirm_done := false   # 卡片二次确认框那张（待机时摆出来拍）
var _ui_shot_confirm_active := false # 拍确认框期间别让并发 _process 抢着掷骰
var _ui_shot_confirm_done2 := false  # 两家商店那两张
var _ui_shot_last_roll := 0.0
var _ui_shot_tired_done := false     # 体力见底（GO 压暗 + 能量条掉下来）那一张
var _ui_shot_tired_t := 0.0
var _ui_shot_cards_done := false     # 手牌 + 卡片菜单那一张
var _ui_shot_cards_t := 0.0

const WORLD_HEIGHT := 0.0


## 全局默认字体 = 原版真字体。
## 原版是 TNFT 点阵字库 gbdata/unicode16.tft（16px）/ unicode24.tft（24px），
## 已由 tools/r6_tft.py 转成 BMFont（assets/fonts/r6_16.fnt 等）。
## 设到 Window.theme 上 → 整个界面（菜单/大厅/对局）的中文都变成原版点阵字。
func _apply_ui_theme() -> void:
	var f: Font = load("res://assets/fonts/r6_16.fnt")
	if f == null:
		push_warning("[ui] 找不到原版点阵字体 r6_16.fnt，退回系统字体")
		return
	var th := Theme.new()
	th.default_font = f
	th.default_font_size = 16
	get_window().theme = th


func _ready() -> void:
	# 单栋对照模式：--probe=<type>:<level>（如 --probe=uptown:1），只摆一栋、相机贴近
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--probe="):
			_probe_spec = a.substr(8)
	# 无头自检模式：godot --headless --path game -- --selftest
	if OS.get_cmdline_user_args().has("--selftest"):
		var t := SelfTest.new()
		t.run()
		get_tree().quit(0 if t._fail == 0 else 1)
		return

	_ui = CanvasLayer.new()
	add_child(_ui)
	_apply_ui_theme()
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
	elif OS.get_cmdline_user_args().has("--showcase"):
		_start_showcase()
	elif _probe_spec != "":
		_start_showcase()      # 复用 showcase 的截图流程，但只摆一栋
	elif OS.get_cmdline_user_args().has("--menushot"):
		_menu_shot = true
	elif OS.get_cmdline_user_args().has("--solotest"):
		_solo_test = true
		_on_solo()          # 生产入口，原样调用
	elif OS.get_cmdline_user_args().has("--uishot"):
		_ui_shot = true
		_on_solo()          # 单人开局后**什么都不自动做** → 角色静止，GO 气泡在头上


## ------------------------------------------------------------------- UI 验收
## godot --path game --resolution 1280x720 -- --uishot
## 单人开局后一动不动地等几秒再截图 —— 这是**唯一能稳定拍到
## 「角色头顶 GO 气泡」与「落点气泡」**的方式（demo 模式动作太密，抓不到静止帧）。
## 落点气泡要等它**真的出现**才拍（掷骰子点数随机，落到空地才有买地机会）。
func _run_ui_shot(delta: float) -> void:
	_ui_shot_t += delta

	if not _ui_shot_idle_done and _ui_shot_t >= 3.0:
		# ⚠ 两处坑（2026-09-25 各踩一次）：
		#  a) 不能按固定时刻拍 —— 开局头几秒角色还在「入场」状态（me.moving != 0），
		#     GO 钮这时是**隐藏**的，硬拍只能拍到头上那颗骰子。所以等它真出现。
		#  b) 必须 `await _capture(...)` 再发动作 —— `_capture` 里 await 了
		#     `RenderingServer.frame_post_draw`，不等它就直接 send_action，会让角色
		#     先动起来、下一帧把 GO 钮置回 false，**抓到的帧里按钮已经没了**。
		if _go_btn != null and _go_btn.visible:
			_ui_shot_idle_done = true
			await _capture("D:/Projects/RichMan/ui_shot_idle.png")
		elif _ui_shot_t > 12.0:
			# ⚠ 这里必须真的拍一张 —— 原来只 push_warning 没 await _capture，
			#   于是「GO 钮没出现」时 idle 那张会**整个丢掉**（掷骰节奏变长后暴露出来）
			_ui_shot_idle_done = true
			push_warning("[uishot] 12 秒内 GO 钮一直没出现（仍在入场/掷骰动画？），照拍一张")
			await _capture("D:/Projects/RichMan/ui_shot_idle.png")
			await _capture("D:/Projects/RichMan/ui_shot_idle.png")
		if _ui_shot_idle_done:
			# 顺带验收「卡片二次确认」：此刻角色是**待机**的，确认框才不会被
			# _sync_action_entry 当过期框收掉（真实路径要求脚下正好是对手的地产，
			# 演示里造不出来，所以直接摆出来验收 UI 形态）。
			if not _ui_shot_confirm_done:
				_ui_shot_confirm_done = true
				# ⚠ `_process` 是协程：await 期间 Godot 会**再起一次 _process**，
				#   两个并发实例都会往下走。所以拿一个「活动锁」挡住掷骰路径 ——
				#   包括下面 ③「再走一次」那段（它原本会因为 `_ui_shot_last_roll`
				#   还是 0 而立刻满足 `> 3.0`，抢先掷骰把角色推进运动态，
				#   于是确认框刚摆出来就被判「过期」收掉，截图永远拍不到）。
				_ui_shot_confirm_active = true
				_ui_shot_last_roll = _ui_shot_t
				_open_card_confirm("buyland")
				await get_tree().create_timer(0.25).timeout
				await _capture("D:/Projects/RichMan/ui_shot_cardconfirm.png")
				_close_card_confirm()
				_ui_shot_confirm_active = false
			if not _ui_shot_confirm_done2:
				# 顺带验收两家商店（点券出口）：给点券 + 两只小神仙再开店
				_ui_shot_confirm_done2 = true
				_ui_shot_confirm_active = true
				var my_s := multiplayer.get_unique_id()
				if Net.sim != null and Net.sim.players.has(my_s):
					var mes: Dictionary = Net.sim.players[my_s]
					mes["credit"] = 300
					Net.sim.add_pet(mes, "caishen")
					Net.sim.add_pet(mes, "huaxian")
				_snapshot["players"] = Net.sim.players if Net.sim != null else _snapshot.get("players", {})
				_shop_stock = []
				_open_shop("pethouse")
				_shop_sig = ""
				_sync_shop()
				await get_tree().create_timer(0.25).timeout
				await _capture("D:/Projects/RichMan/ui_shot_pethouse.png")
				# 商店购买二次确认：验证它落在**面板下方居中**，而不是贴角色头顶被压住
				_confirm_buy_pet("caishen")
				await get_tree().create_timer(0.3).timeout
				await _capture("D:/Projects/RichMan/ui_shot_shopconfirm.png")
				_pop_cancel()
				_shop_stock = _shop_stock_for_me()
				_open_shop("cardshop")
				_shop_sig = ""
				_sync_shop()
				await get_tree().create_timer(0.25).timeout
				await _capture("D:/Projects/RichMan/ui_shot_cardshop.png")
				_close_shop()
				# 精灵仓库（角色面板的精灵栏位点开）：验证「可以选择要使用的精灵」
				_open_pet_warehouse()
				_shop_sig = ""
				_sync_shop()
				await get_tree().create_timer(0.25).timeout
				await _capture("D:/Projects/RichMan/ui_shot_warehouse.png")
				_close_shop()
				# 路边物体（roadobj）：把时间快进 12 天，让它们按原版权重表**真的生成**出来，
				# 再切全盘视角，一次看全棋盘上的事件格图标与路边物体
				if Net.sim != null:
					Net.sim.time += Rules.seconds_per_day() * 12.0
					await get_tree().create_timer(0.4).timeout
					# 把角色挪到第一个路边物体前一格，近景才看得到实物（只为截图摆位）
					if Net.sim.road_objs.size() > 0:
						var first := int(Net.sim.road_objs.keys()[0])
						var me2: Dictionary = Net.sim.players.get(multiplayer.get_unique_id(), {})
						if not me2.is_empty():
							me2["tile"] = Net.sim._wrap(first - 1)
							me2["progress"] = 0.0
					if _board != null:
						_board.set_overview(true)
						await get_tree().create_timer(0.35).timeout
					await _capture("D:/Projects/RichMan/ui_shot_road.png")
					if _board != null:
						_board.set_overview(false)
						await get_tree().create_timer(3.0).timeout   # 相机跟随有平滑，等它追过去
					await _capture("D:/Projects/RichMan/ui_shot_roadnear.png")
					# 股票买进对话框：验证「滑动条是唯一输入点、每跳 100」
					if _stock != null and Net.sim != null and not Net.sim.stock_names().is_empty():
						# ① 先拍**股票页**本身 —— 重点看「切到股票后功能区那 6 个按钮还在不在」
						_set_br_page(1)
						await get_tree().create_timer(0.35).timeout
						await _capture("D:/Projects/RichMan/ui_shot_stockpage.png")
						# ② 再开买进对话框
						_stock.open_trade(str(Net.sim.stock_names()[0]), true)
						await get_tree().create_timer(0.3).timeout
						await _capture("D:/Projects/RichMan/ui_shot_stock.png")
						_stock.close_all()
						_set_br_page(2)
				_ui_shot_confirm_active = false
			if not _ui_shot_confirm_active:
				# 顺带验收「骰子数量选择」：切到 2 颗再掷（选择器第 1/2 颗亮、第 2 颗灰）
				_set_dice_count(2)
				_ui_shot_last_roll = _ui_shot_t  # 从这次掷骰起算「再走一次」的间隔
				Net.send_action("roll", [2])

	# ② 掷出动画中：骰子正在从 GO 钮飞向头顶（_dice_fx_state == "fly" 只持续 0.55 秒）
	if _ui_shot_idle_done and not _ui_shot_dice_done \
			and _dice_fx_state == "fly" and _dice_fx_t > 0.16:
		_ui_shot_dice_done = true
		await _capture("D:/Projects/RichMan/ui_shot_dice.png")

	# ①b 手牌 + 卡片菜单（**验收专用**：直接往手牌里塞几张，好让截图一定拍得到。
	#     真实的「卡片商店 / 卡片点会发卡」由 --selftest 的 _test_road_events 断言。）
	if _ui_shot_idle_done and not _ui_shot_cards_done:
		if _ui_shot_cards_t == 0.0:
			# 末尾故意混一张**此刻用不了**的卡（购地卡要「脚下是对手的地」）
			# → 用来验收「用不了的卡会压暗 + 点它会说出原因」。
			# 手牌上限 5（老板 2026-09-26 的规则）→ 这里就给 5 种
			_dev_give_cards(["qiongshen", "step3", "hamburger", "monster", "caishen"])
			_ui_shot_cards_t = _ui_shot_t
		elif _ui_shot_t - _ui_shot_cards_t > 0.4:
			_ui_shot_cards_done = true
			await _capture("D:/Projects/RichMan/ui_shot_cards.png")
			if _card_slots.size() > 0:
				_on_card_clicked(0)                     # 弹出使用/锁定/丢弃菜单
				await get_tree().create_timer(0.3).timeout
				await _capture("D:/Projects/RichMan/ui_shot_cardmenu.png")
				_hide_card_menu()
				# 再演一次「要选对手」的卡：点穷神卡 → 进入请选择对手模式
				for i in range(_card_ids.size()):
					if Net.sim != null and Net.sim.card_needs_player(str(_card_ids[i])):
						_set_card_target_mode(str(_card_ids[i]))
						break
				await get_tree().create_timer(0.4).timeout
				await _capture("D:/Projects/RichMan/ui_shot_cardtarget.png")
				_clear_card_target_mode()

	# ③ 落点气泡（买地 / 升级）—— 排除卡片二次确认（它也复用 _pop，
	#    但已经有自己那张 ui_shot_cardconfirm.png 了）
	if not _ui_shot_pop_done and _pop != null and _pop.visible and _pop_mode != "card":
		_ui_shot_pop_done = true
		_ui_shot_pop_t = _ui_shot_t
		await _capture("D:/Projects/RichMan/ui_shot_pop.png")

	# 没落到空地（踩到事件格/别人地盘）就再走一次
	if _ui_shot_idle_done and not _ui_shot_pop_done and not _ui_shot_confirm_active \
			and _ui_shot_t - _ui_shot_last_roll > 3.0:
		_ui_shot_last_roll = _ui_shot_t
		Net.send_action("pass")
		Net.send_action("roll", [2])

	# ④ 一直走到**体力见底**（< min_to_start）→ GO 钮压暗 + 角色面板能量条掉下来
	if _ui_shot_pop_done and not _ui_shot_tired_done:
		if _ui_shot_t - _ui_shot_last_roll > 2.4:
			_ui_shot_last_roll = _ui_shot_t
			Net.send_action("buy")
			Net.send_action("upgrade")
			Net.send_action("pass")
			Net.send_action("roll", [_dice_count])
		var pl: Dictionary = (_snapshot.get("players", {}) as Dictionary)
		var me2: Dictionary = pl.get(multiplayer.get_unique_id(), {})
		# 判据直接盯**「GO 钮可见但被压暗」**——这才是原版「体力不够不让出发」的样子。
		# （不能只判 stamina 数值：移动中 GO 钮本来就不显示，那样只拍到半张。）
		var me2_ok := not me2.is_empty() and float(me2.get("stamina", 99999.0)) < 260.0
		if me2_ok and _go_btn != null and _go_btn.visible and _go_btn.modulate.r < 0.9:
			_ui_shot_tired_done = true
			_ui_shot_tired_t = _ui_shot_t
			await _capture("D:/Projects/RichMan/ui_shot_tired.png")

	# 四张都拍齐 → 收工；或 90 秒兜底
	if _ui_shot_tired_done and _ui_shot_t - _ui_shot_tired_t > 0.8:
		get_tree().quit(0)
	if _ui_shot_t > 170.0:
		if not _ui_shot_pop_done:
			push_warning("[uishot] 90 秒内没等到落点气泡（一直没落到空地）")
		if not _ui_shot_tired_done:
			push_warning("[uishot] 90 秒内体力没掉到 250 以下")
		get_tree().quit(0)


## 开发用验收模式：godot --path game -- --showcase --map=aiji
## 在起点附近的连续地产格上按 House.txt 摆一排「主题 × 等级」的房屋，
## 拉近相机截一张图，用于逐级核对模型/贴图（议题 4 / 议题 20）。
func _start_showcase() -> void:
	_showcase = true
	_name_edit.text = "房主"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			_demo_map = a.substr(6)
	if not Net.host_game("房主"):
		push_error("showcase: host 失败")
		get_tree().quit(1)
		return
	Net.start_game(_demo_map)
	print("[showcase] 已开局 %s" % _demo_map)


func _run_showcase(delta: float) -> void:
	_showcase_t += delta
	if not _showcase_shot and _showcase_t >= 1.5:
		_showcase_shot = true
		_fill_showcase()
		# 相机可用命令行微调，避免为了取景反复改代码
		var probe := _probe_spec != ""
		var zoom := 0.55 if probe else 3.4
		var pitch := 14.0 if probe else 20.0
		var yaw := 90.0
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--zoom="):
				zoom = float(a.substr(7))
			elif a.begins_with("--pitch="):
				pitch = float(a.substr(8))
			elif a.begins_with("--yaw="):
				yaw = float(a.substr(6))
		_board.zoom_camera(zoom)
		_board.tilt_camera(pitch)
		_board.rotate_camera(yaw)
		# 逐家族取景：把玩家挪到该组中段，让整组落在画面中间（一屏一组，才看得清贴图）
		for grp in _showcase_groups:
			var tiles: Array = grp["tiles"]
			if tiles.is_empty():
				continue
			Net.sim.players[1]["tile"] = int(tiles[tiles.size() / 2])
			await get_tree().create_timer(0.7).timeout
			if probe:
				await _capture("D:/Projects/RichMan/docs/screenshots/v3/probe_%s.png"
						% _probe_spec.replace(":", "_"))
			else:
				await _capture("D:/Projects/RichMan/docs/screenshots/v3/buildings_%s.png" % str(grp["type"]))
	elif _showcase_t > 14.0:
		print("[showcase] 结束")
		get_tree().quit(0)


## 展示清单：按家族分 3 组，组内逐等级；同组内相邻等级之间留 SHOWCASE_STRIDE 格。
const SHOWCASE_GROUPS := [
	{"type": "uptown", "levels": [1, 3, 5, 9, 12]},
	{"type": "shop", "levels": [1, 5, 10, 15]},
	{"type": "industry", "levels": [1, 5, 9]},
]

## 展示格距。最大占地是 3x3（House.txt 宽/长），相邻摆放必然沿路径互相穿插
## —— 原版是靠「占地预订」（吃掉邻格、禁别人盖）避免的，我们还没实现 →
## 展示时按 stride=3 铺开，每栋都能看全（也贴近原版「大地块独占一片」的观感）。
const SHOWCASE_STRIDE := 3

var _showcase_groups: Array = []   # [{type: String, tiles: Array[int]}]


func _fill_showcase() -> void:
	if Net.sim == null or _board == null or _board.map == null:
		return
	var md: MapData = Net.sim.map
	_showcase_groups.clear()
	var names: Array = []
	var cursor := 1

	# ---- 单栋对照：只摆一栋，摆在地图起点后第 1 格 ----
	if _probe_spec != "":
		var parts := _probe_spec.split(":")
		var pt := parts[0]
		var pl: int = clampi(int(parts[1]) if parts.size() > 1 else 1, 0, Net.sim.max_level(pt))
		Net.sim.plots[1] = {"owner": 1, "level": pl, "type": pt if pl > 0 else ""}
		if pl == 0:
			names.append("空地#0")
		else:
			var g1 := Rules.house_grade(pt, pl)
			names.append("%s#%d(%s)" % [g1.get("file", "?"), pl, str(g1.get("name", ""))])
		_showcase_groups.append({"type": pt, "tiles": [1]})
		# Geometry review: show the original first five adjacent plots together.
		if OS.get_cmdline_user_args().has("--probe-row"):
			var row_tiles: Array = []
			for tile in range(5):
				if md.is_plot(tile):
					Net.sim.plots[tile] = {"owner": 1, "level": pl, "type": pt if pl > 0 else ""}
					row_tiles.append(tile)
			_showcase_groups[0]["tiles"] = row_tiles
		cursor = 4

	for g in SHOWCASE_GROUPS:
		if _probe_spec != "":
			break                       # 单栋模式：只摆这一栋
		var t := str(g["type"])
		if not Net.sim.buildable_types().has(t):
			continue                       # 本图不允许的房型直接跳过（不硬塞）
		var tiles: Array = []
		for lv in g["levels"]:
			if cursor >= md.tile_count():
				break
			var l: int = clampi(int(lv), 1, Net.sim.max_level(t))
			Net.sim.plots[cursor] = {"owner": 1, "level": l, "type": t}
			var gg := Rules.house_grade(t, l)
			names.append("%s#%d(%s)" % [gg.get("file", "?"), l, str(gg.get("name", ""))])
			tiles.append(cursor)
			cursor += SHOWCASE_STRIDE
		if not tiles.is_empty():
			_showcase_groups.append({"type": t, "tiles": tiles})
		cursor += SHOWCASE_STRIDE       # 组间再留一格，免得两组边界的 3x3 撞上
	# 让棋盘静止下来（关掉 AI 与步进）
	for id in Net.ai_ids:
		if Net.sim.players.has(id):
			Net.sim.players[id]["moving"] = 0
	Net.sim.running = false
	print("[showcase] 摆好 %d 处地产，房型 %s" % [Net.sim.plots.size(), str(Net.sim.buildable_types())])
	print("[showcase] 依次：%s" % str(names))


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
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			_demo_map = a.substr(6)
	if not Net.host_game("房主"):
		push_error("demo: host 失败")
		get_tree().quit(1)
		return
	Net.add_local_ai(3)
	Net.start_game(_demo_map)
	print("[demo] 已开局 %s，开始自动演示" % _demo_map)


func _process(delta: float) -> void:
	if screen == Screen.GAME:
		_sync_action_ui()
		_tick_dice(delta)
		if _toast_t > 0.0:
			_toast_t -= delta
			if _toast_t <= 0.0 and _toast_lbl != null:
				_toast_lbl.visible = false
		# 全局新闻插画：展示 4 秒后自动收起
		if _news_left > 0.0:
			_news_left -= delta
			if _news_left <= 0.0 and _news_pop != null:
				_news_pop.visible = false
		# 拉霸面板：滚轮动画 + 下注额刷新
		if _casino != null and _casino.visible and Net.sim != null:
			var st: Dictionary = Net.sim._casino_of(multiplayer.get_unique_id())
			_casino.tick(delta, int(st.get("bet", 0)), st.get("reels", []))

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

	if _ui_shot:
		_run_ui_shot(delta)
		return

	if _showcase:
		_run_showcase(delta)
		return

	if not _demo:
		return
	_demo_time += delta

	# 只有人类玩家由演示脚本代打；电脑玩家由 Net 的 AI 系统自行驱动。
	# 顺序有讲究：本次抵达的机会（买地/升级）先处理掉，再掷骰子走人。
	if not _demo_cards_done and _demo_time >= 1.5:
		_demo_cards_done = true
		# 给演示玩家几张卡，让手牌条在截图里可见（真实获得路径见 --selftest）
		_dev_give_cards(["caishen", "step3", "dice", "hamburger", "stay"])
	if _demo_time >= _demo_next_act:
		_demo_next_act += 1.1
		Net.send_action("buy")
		Net.send_action("upgrade")
		# 每 5 轮用一张卡（挑不需要点对手的，保证自动演示不会卡在「请选择对手」）
		if int(_demo_time) % 6 == 0:
			Net.send_action("card", ["hamburger"])
			Net.send_action("card", ["caishen"])
		Net.send_action("roll")
		Net.send_action("pass")     # 兜底：机会用不上时别攥着不放

	if _demo_shots < DEMO_SHOT_AT.size() and _demo_time >= float(DEMO_SHOT_AT[_demo_shots]):
		_capture("D:/Projects/RichMan/demo_shot_%d.png" % _demo_shots)
		_demo_shots += 1

	# 第 5、6 张切到"全盘视角"，给验收文档留一张整体图
	if not _demo_overview_done and _demo_time >= DEMO_OVERVIEW_AT:
		_demo_overview_done = true
		if _board != null and _board.map != null:
			_board.set_overview(true)

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
		if _go_btn != null and _go_btn.visible:
			_on_go_pressed()      # 空格 = 点 GO（带当前选的骰子颗数）
	if screen != Screen.GAME:
		return
	# 右键：先关商店 / 购买确认（原版 Info.txt 62 的批注就是「点击右键界面消失」）
	if e is InputEventMouseButton and e.pressed 			and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		if _pop_mode == "shop":
			_pop_cancel()
		elif shop_open():
			_close_shop()
		return
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_L:
				_toggle_log()
			KEY_F11:
				_toggle_fullscreen()
			KEY_C:
				_toggle_log()
			KEY_M, KEY_TAB:
				if _board != null and _board.map != null:
					_board.set_overview(not _board.is_overview())
			KEY_S:
				_toggle_sfx()
			KEY_Q:
				# 卡片夹开/关（原版 String.txt 2010「卡片夹子」）
				_card_bar_open = not _card_bar_open
				_card_sig.clear()
			KEY_ESCAPE:
				if _pop_mode == "shop":
					_pop_cancel()
				elif shop_open():
					_close_shop()
				elif _pop_mode == "card":
					_close_card_confirm()          # 先关掉卡片二次确认框
				elif _card_pending != "":
					_clear_card_target_mode()      # 再退「选对手」模式，别直接退游戏
				else:
					_on_leave()

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
	_sfx(_solo_btn, true)

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
	_sfx(_host_btn)
	_sfx(_join_btn)

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
	_sfx(_start_btn, true)

	var leave := Button.new()
	leave.text = "返回"
	box.add_child(leave)
	leave.pressed.connect(_on_leave)
	_sfx(leave)

# ---------------------------------------------------------------------- HUD
#
# 版式对齐原版实机（docs/screenshots/orig/07~09_牌桌*.png），尺寸口径见 docs/ui-audit.md：
#   UI_SCALE = 视口高 / 768      （原版设计分辨率 1024×768）
#   顶栏      —— 竖向蓝色渐变条 + 5 个「椭圆图徽 + 数字」计数项 + 右侧 x/y 面板 + 3 个图标按钮
#   左下      —— 角色头像面板
#   右下      —— 小地图 + 图标按钮条
#   左上      —— 战况日志（原版没有，保留作调试与可读性，L 键收起）
#   ⚠️ 顶栏底条与原版图徽**在资源包里没有贴图**（原版是程序绘制的），
#      图徽由 tools/make_hud_ui.py 从原版实机截图裁出，数字用游戏真字体（见 hud_number.gd）。

var _ui_scale: float = 1.0

# 原版测量值（1024×768 像素）—— 全部来自 docs/ui-audit.md，改前先量
const UI_BAR_H := 26.67
const UI_COIN_W := 52.0          # 图徽贴图（78px 截图 / 1.5）
const UI_COIN_H := 25.33
const UI_COUNTER_GAP := 12.0
const UI_COUNTER_PAD := 3.0
const UI_XY_W := 113.0
const UI_XY_H := 27.0
const UI_BTN_W := 158.67
const UI_BTN_H := 28.0
const UI_RIGHT_MARGIN := 4.0
const UI_GAP_XY_BTN := 6.0

# 顶栏底条的竖向渐变（自原版截图逐行采样，位置为 0..1 的条内比例）
const UI_BAR_STOPS := [
	[0.00, Color8(97, 167, 255)],
	[0.08, Color8(36, 122, 255)],
	[0.25, Color8(68, 152, 255)],
	[0.50, Color8(130, 187, 255)],
	[0.70, Color8(153, 204, 255)],
	[0.95, Color8(170, 204, 255)],
]

# ============================================================================
#  牌桌 HUD 版式（单位 = 原版 1024×768 设计像素，乘 _ui_scale 得屏幕像素）
#
#  全部量自原版实机截图 docs/screenshots/orig/07_牌桌.png（1536×1152 = native×1.5）；
#  换算与素材出处见 tools/make_panel_ui.py 的 panel.json / layout 段。
#  ⚠️ 改任何数字前先回截图重量，别凭手感。
# ============================================================================

# --- 左下：角色面板（底框 = assets/ui/panel/frame_atb.png）---
const ATB_SIZE := Vector2(176.0, 123.0)      # frame_atb.png 的像素尺寸
const ATB_AVATAR := Rect2(10, 9, 73, 73)     # 大圆头像槽
const ATB_INFO := Rect2(93, 10, 64, 64)      # 右上信息槽（原版留空）
const ATB_NAME := Rect2(12, 86, 69, 14)      # 名字胶囊（左 navy）
const ATB_STAT := Rect2(91, 79, 69, 14)      # 状态胶囊（右 navy）
const ATB_BAR_A := Rect2(9, 103, 76, 14)     # 左细条（原版 = 亮黄，位置/血量）
const ATB_BAR_B := Rect2(90, 103, 76, 14)    # 右细条（原版留空）
const UI_CHAR_X := 1.3                       # 面板左外边距
const UI_CHAR_BOTTOM := 2.7                  # 面板底外边距
const UI_CHAR_W := 220.0
const UI_CHAR_H := 149.3

# --- 右下：小地图框 + 图标按钮条 ---
const UI_BR_W := 292.0
const UI_BR_MAP_H := 156.7
const UI_BR_BAR_H := 36.7
const UI_BR_GAP := 2.6
const UI_BR_MARGIN := 0.7
const UI_ICON_SIZE := 35.0                  # 条内每个图标显示边长（原版 32px 素材显示成 ~35）
const UI_ICON_PAD := 6.8                    # 图标间距（原版实测步距 41.8 - 图标 35）
const UI_ICON_NAMES := ["icon_tv", "icon_chart", "icon_map", "icon_chat", "icon_mic", "icon_play"]
const UI_ICON_TIPS := ["角色情报 (C)", "股价行情 (K)", "地图/MAP (M)", "聊天 (T)", "音效开关 (S)", "全盘视角 (Tab)"]

# --- 右侧：玩家头像列（原版贴在右边缘的竖排圆头像）---
const UI_AVA_RIGHT := 2.0
const UI_AVA_TOP := 216.7
const UI_AVA_W := 35.3
const UI_AVA_H := 42.0
const UI_AVA_STEP := 52.0
const UI_AVA_MAX := 6

# --- 动作入口：原版是「角色头顶的 GO 气泡 + 落点提示气泡」---
const UI_GO_SIZE := 78.0                     # GO 钮 = 原版 labar/背景.png(蓝球) + go.png(青球) 叠成 78x78 native
                                             # ⚠ 两张单图都是贴边裁切的残图，必须用 tools/make_panel_ui.py 合成的 go_btn.png
## 角色头顶在**世界空间**的高度（世界单位，不是 native）：角色本体顶 ≈1.4、
## 名字 Label3D 在 1.50、骰子在 1.85（见 board_view 里的角色构建）。
## 取 2.0 → 气泡稳定压在它们之上；锚世界点再投影，自动随相机远近缩放。
const UI_HEAD_UP := 2.0
const UI_POP_W := 330.0                      # 落点气泡 / 确认框目标宽
## 尺寸按原版那个 `infobk` 对话框来（老板 2026-09-26 反馈「二次确认框没有现在这么小」：
## 原版 records/小神仙商店购买确认.png 里的框约占 1024 宽屏的 1/3）
const UI_POP_H := 160.0



func _build_hud() -> void:
	_ui_scale = maxf(get_viewport().get_visible_rect().size.y / 768.0, 0.3)
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_hud)

	_build_topbar()
	_build_pause_overlay()
	_build_avatar_column()
	_build_log_panel()
	_build_character_panel()
	_build_bottom_right()
	_build_action_entry()
	_build_card_hand()
	# （原来这里会 `_build_pet_strip()` 在角色面板**右侧**贴一排小神仙小图标 ——
	#   老板 2026-09-26 说「把精灵头像放在了右侧缩到了很小，完全不对」→ 已去掉，
	#   改成精灵栏里显示出战精灵的头像，见 `_build_char_panel` / `_sync_char_panel`）
	# 右下角常驻行情面板（原版「名称 / 股价 / 持股 / %」那张表）
	_stock = StockPanel.new()
	_hud.add_child(_stock)
	_stock.setup(_ui_scale)
	_stock.act_requested.connect(_on_stock_action)
	# 拉霸（老虎机）面板 —— 素材 uitex/casino/，走到「拉霸」格时打开
	_casino = CasinoPanel.new()
	_hud.add_child(_casino)
	_casino.setup(_ui_scale)
	_casino.act.connect(_on_casino_action)
	_build_shop()
	_build_toast()


## 把「frame_atb.png 内部像素」换算到屏幕像素
func _kt() -> float:
	return (UI_CHAR_W * _ui_scale) / ATB_SIZE.x


func _slot(r: Rect2, k: float) -> Rect2:
	return Rect2(r.position * k, r.size * k)



## 顶栏底条：程序生成的竖向渐变（原版没有这张贴图）
func _make_bar_texture() -> ImageTexture:
	var n := 64
	var img := Image.create(1, n, false, Image.FORMAT_RGBA8)
	for y in n:
		var t := float(y) / float(n - 1)
		img.set_pixel(0, y, _bar_color_at(t))
	return ImageTexture.create_from_image(img)


func _bar_color_at(t: float) -> Color:
	var stops := UI_BAR_STOPS
	var a: Array = stops[0]
	if t <= float(a[0]):
		return a[1]
	for i in range(1, stops.size()):
		var b: Array = stops[i]
		if t <= float(b[0]):
			var prev: Array = stops[i - 1]
			var span := maxf(float(b[0]) - float(prev[0]), 0.0001)
			var k := (t - float(prev[0])) / span
			return (prev[1] as Color).lerp(b[1] as Color, k)
	return (stops[stops.size() - 1][1] as Color)


func _build_topbar() -> void:
	var bar_h := UI_BAR_H * _ui_scale
	_topbar = PanelContainer.new()
	_topbar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_topbar.custom_minimum_size = Vector2(0, bar_h)
	_topbar.add_theme_stylebox_override("panel", _sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0))
	_hud.add_child(_topbar)

	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.texture = _make_bar_texture()
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	_topbar.add_child(bg)

	var edge := ColorRect.new()
	edge.color = Color8(86, 120, 137)
	edge.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	edge.custom_minimum_size = Vector2(0, maxf(1.0, 1.5 * _ui_scale))
	_topbar.add_child(edge)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", int(round(UI_COUNTER_GAP * _ui_scale)))
	row.add_theme_constant_override("margin_left", int(round(6.0 * _ui_scale)))
	_topbar.add_child(row)

	_hud_money = _top_counter(row, "coin1_money", false)
	_hud_deposit = _top_counter(row, "coin2_stock", false)
	_hud_houses = _top_counter(row, "coin3_house", false)
	_hud_cards = _top_counter(row, "coin4_cards", false)
	_hud_credit = _top_counter(row, "coin5_face", true)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)

	# 右侧：x/y 面板 + 三个图标按钮（都贴右边缘）
	row.add_child(_top_xy_panel())
	row.add_child(_gap(int(round(UI_GAP_XY_BTN * _ui_scale))))
	row.add_child(_top_btnstrip())
	row.add_child(_gap(int(round(UI_RIGHT_MARGIN * _ui_scale))))


## 一个计数项 = 胶囊（浅青 / 第 5 项深蓝）+ 椭圆图徽 + 数字
func _top_counter(parent: Node, coin: String, navy: bool) -> HudNumber:
	var cap := PanelContainer.new()
	var h := UI_COIN_H * _ui_scale
	var pad := UI_COUNTER_PAD * _ui_scale
	var fill := Color8(17, 34, 187) if navy else Color8(131, 238, 255)
	var line := Color8(205, 249, 255)
	cap.add_theme_stylebox_override("panel", _sb_round(fill, line, maxi(2, int(round(h * 0.5))),
		int(round(pad)), maxf(1.0, 1.4 * _ui_scale)))
	parent.add_child(cap)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", int(round(3.0 * _ui_scale)))
	cap.add_child(hb)

	var ic := TextureRect.new()
	ic.texture = load("res://assets/ui/hud/%s.png" % coin)
	ic.custom_minimum_size = Vector2(UI_COIN_W * _ui_scale, h)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_SCALE
	hb.add_child(ic)

	var num := HudNumber.new()
	num.ui_scale = _ui_scale
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(num)
	return num


## x/y 面板（深蓝绿）+ 数字 + 斜杠
func _top_xy_panel() -> Control:
	var p := PanelContainer.new()
	var h := UI_XY_H * _ui_scale
	p.custom_minimum_size = Vector2(UI_XY_W * _ui_scale, h)
	p.add_theme_stylebox_override("panel", _sb_round(Color8(17, 85, 153), Color8(120, 190, 230),
		maxi(2, int(round(h * 0.5))), int(round(5.0 * _ui_scale)), maxf(1.0, 1.4 * _ui_scale)))
	_hud_day = HudNumber.new()
	_hud_day.ui_scale = _ui_scale
	_hud_day.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hud_day.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(_hud_day)
	return p


## 右侧三按钮：直接用原版截图裁出的整条（暂停 / 放大镜 / 监视器），
## 上面盖三个透明按钮负责点击。
func _top_btnstrip() -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(UI_BTN_W * _ui_scale, UI_BTN_H * _ui_scale)
	var tex := TextureRect.new()
	tex.texture = load("res://assets/ui/hud/btnstrip.png")
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	holder.add_child(tex)
	var zones := [
		[0.00, 0.36, "暂停 / 继续", func(): _toggle_pause()],
		[0.38, 0.70, "全盘视角 (Tab)", func():
			if _board != null and _board.map != null:
				_board.set_overview(not _board.is_overview())],
		[0.72, 1.00, "全屏 (F11)", func(): _toggle_fullscreen()],
	]
	for z in zones:
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = z[2]
		var x0 := float(z[0]) * UI_BTN_W * _ui_scale
		var x1 := float(z[1]) * UI_BTN_W * _ui_scale
		b.position = Vector2(x0, 0)
		b.size = Vector2(x1 - x0, UI_BTN_H * _ui_scale)
		b.pressed.connect(z[3])
		_sfx(b)
		holder.add_child(b)
	return holder


## 原版 ⏸ = 暂停游戏。用 SceneTree.paused 冻结世界与 Net/Sim，
## 但把 App 与 _ui 设成 ALWAYS，否则连"取消暂停"都点不了。
func _toggle_pause() -> void:
	_paused = not _paused
	get_tree().paused = _paused
	process_mode = Node.PROCESS_MODE_ALWAYS if _paused else Node.PROCESS_MODE_INHERIT
	if _ui != null:
		_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	if _world != null:
		_world.process_mode = Node.PROCESS_MODE_PAUSABLE if _paused else Node.PROCESS_MODE_INHERIT
	if _pause_overlay != null:
		_pause_overlay.visible = _paused


## 原版素材里就有「暂停 按任意键返回」这张图（uitex/other/pause.tga）
func _build_pause_overlay() -> void:
	_pause_overlay = TextureRect.new()
	_pause_overlay.set_anchors_preset(Control.PRESET_CENTER)
	_pause_overlay.texture = load("res://assets/uitex/other/pause.png")
	_pause_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pause_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var w := 420.0 * _ui_scale
	_pause_overlay.size = Vector2(w, w * 0.28)
	_pause_overlay.position = -_pause_overlay.size * 0.5
	_pause_overlay.visible = false
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_pause_overlay)


## 圆角胶囊（原版顶栏/面板的通用形状）
func _sb_round(fill: Color, border: Color, radius: int, margin: int, bw: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.border_width_left = int(round(bw))
	s.border_width_top = int(round(bw))
	s.border_width_right = int(round(bw))
	s.border_width_bottom = int(round(bw))
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	return s


## 右侧：玩家头像列（原版=贴在右边缘的竖排圆头像，无底板）
## 素材 uitex/player/roleN_21.png（32×32 头特写）；出局者压灰。
func _build_avatar_column() -> void:
	_avatar_col = VBoxContainer.new()
	_avatar_col.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_avatar_col.alignment = BoxContainer.ALIGNMENT_BEGIN
	_avatar_col.add_theme_constant_override("separation",
		int(round((UI_AVA_STEP - UI_AVA_H) * _ui_scale)))
	_avatar_col.position = Vector2(
		-(UI_AVA_W + UI_AVA_RIGHT) * _ui_scale, UI_AVA_TOP * _ui_scale)
	_avatar_col.custom_minimum_size = Vector2(UI_AVA_W * _ui_scale, 0)
	_avatar_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_avatar_col)


## 左上：战况日志（**原版没有这块**，是我们加的调试/可读性面板）
## → 默认隐藏，按 L / C、点齿轮、点图标条第 1 个都能开合。
func _build_log_panel() -> void:
	_log_panel = PanelContainer.new()
	_log_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_log_panel.position = Vector2(12, 48)
	_log_panel.custom_minimum_size = Vector2(336, 190)
	_log_panel.add_theme_stylebox_override("panel",
		_sb(Color(0.05, 0.08, 0.14, 0.80), Color(0.30, 0.45, 0.65, 0.7), 6, 7))
	_log_panel.visible = false        # ← 对齐原版：默认不显示
	_hud.add_child(_log_panel)

	_hud_log = RichTextLabel.new()
	_hud_log.scroll_following = true
	_hud_log.bbcode_enabled = false
	_hud_log.add_theme_font_size_override("normal_font_size", 13)
	_log_panel.add_child(_hud_log)


## 左下：角色面板 —— 直接用原版底框 uitex/other/atb.png（裁到主框 176×123），
## 再按 panel.json 量出的槽位叠内容：
##   左上大方块 = 大圆头像（roleN_01.png）      右上大方块 = 当前格/状态文字
##   左 navy 胶囊 = 角色名                      右 navy 胶囊 = 名次/头衔
##   左细条 = 位置进度（亮黄，同原版）          右细条 = 血量
##   左下角外侧 = 紫齿轮按钮（角色情报）
func _build_character_panel() -> void:
	var w := UI_CHAR_W * _ui_scale
	var h := UI_CHAR_H * _ui_scale
	var k := _kt()

	_char_panel = Control.new()
	_char_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_char_panel.position = Vector2(UI_CHAR_X * _ui_scale,
		-(h + UI_CHAR_BOTTOM * _ui_scale))
	_char_panel.size = Vector2(w, h)
	_char_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_char_panel)

	var fr := TextureRect.new()
	fr.texture = load("res://assets/ui/panel/frame_atb.png")
	fr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fr.stretch_mode = TextureRect.STRETCH_SCALE
	fr.size = Vector2(w, h)
	fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_char_panel.add_child(fr)

	# 大圆头像
	var av := _slot(ATB_AVATAR, k)
	_char_avatar = TextureRect.new()
	_char_avatar.position = av.position
	_char_avatar.size = av.size
	_char_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_char_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_char_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_char_panel.add_child(_char_avatar)

	# 右上信息槽 = **精灵栏**：显示出战小神仙的**头像**（点一下 → 精灵仓库）。
	# ⚠️ 老板 2026-09-26：「精灵栏不对，没有放精灵的头像，反而是把精灵头像放在了右侧缩到了很小；
	#   其实精灵栏点开是有一个单独的界面的，现在这样放完全不对。」
	#   → 那块地方改成**直接显示头像**；原来贴在角色面板右侧那排小图标（`_pet_strip`）**去掉**。
	var inf := _slot(ATB_INFO, k)
	_pet_slot = TextureRect.new()
	_pet_slot.position = inf.position + Vector2(3, 2) * _ui_scale
	_pet_slot.size = inf.size - Vector2(6, 17) * _ui_scale
	_pet_slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pet_slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pet_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_char_panel.add_child(_pet_slot)

	_char_info = Label.new()
	_char_info.position = Vector2(inf.position.x, inf.position.y + inf.size.y
		- 15.0 * _ui_scale)
	_char_info.size = Vector2(inf.size.x, 14.0 * _ui_scale)
	_char_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_char_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_char_info.add_theme_font_size_override("font_size", maxi(8, int(round(9.0 * k))))
	_char_info.add_theme_color_override("font_color", Color8(28, 46, 92))
	_char_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_char_panel.add_child(_char_info)
	# 这块就是**精灵栏位** —— 点一下打开**精灵仓库**（选一只出战）。
	# 老板 2026-09-26：「左下角角色右侧这个头像应该是精灵的栏位，点开之后是精灵的
	# 仓库，可以选择要使用的精灵」。
	var pbtn := Button.new()
	pbtn.flat = true
	pbtn.focus_mode = Control.FOCUS_NONE
	pbtn.tooltip_text = "小神仙仓库（选一只出战）"
	pbtn.position = inf.position
	pbtn.size = inf.size
	pbtn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	pbtn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	pbtn.add_theme_stylebox_override("hover", _sb_round(Color8(255, 255, 255, 70),
		Color8(255, 226, 130), int(round(5.0 * _ui_scale)), 0, maxf(1.0, 1.5 * _ui_scale)))
	pbtn.pressed.connect(func(): _open_pet_warehouse())
	_char_panel.add_child(pbtn)

	# 名字（左 navy 胶囊）
	var nm := _slot(ATB_NAME, k)
	_char_name = Label.new()
	_char_name.position = nm.position
	_char_name.size = nm.size
	_char_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_char_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_char_name.add_theme_font_size_override("font_size", maxi(10, int(round(12.0 * k))))
	_char_name.add_theme_color_override("font_color", Color8(255, 255, 255))
	_char_name.add_theme_color_override("font_shadow_color", Color8(10, 10, 60, 220))
	_char_name.add_theme_constant_override("shadow_offset_x", 1)
	_char_name.add_theme_constant_override("shadow_offset_y", 1)
	_char_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_char_panel.add_child(_char_name)

	# 右 navy 胶囊（名次）
	var st := _slot(ATB_STAT, k)
	_char_stat = Label.new()
	_char_stat.position = st.position
	_char_stat.size = st.size
	_char_stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_char_stat.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_char_stat.add_theme_font_size_override("font_size", maxi(9, int(round(9.5 * k))))
	_char_stat.add_theme_color_override("font_color", Color8(230, 240, 255))
	_char_stat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_char_panel.add_child(_char_stat)

	_char_bar_a = _slot_bar(ATB_BAR_A, k, Color8(255, 236, 0))
	_char_bar_b = _slot_bar(ATB_BAR_B, k, Color8(90, 220, 90))

	# 齿轮按钮（叠在面板左下角，略压出边框 —— 同原版）
	var g := TextureButton.new()
	g.texture_normal = load("res://assets/ui/panel/gear.png")
	g.ignore_texture_size = true
	g.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var gs := 44.0 * _ui_scale
	g.position = Vector2(0.0, h - gs * 0.78)
	g.size = Vector2(gs, gs)
	g.tooltip_text = "角色情报 (C)"
	g.pressed.connect(func(): _toggle_log())
	_sfx(g)
	_char_panel.add_child(g)


## 在 frame_atb 的细条槽里放一条填充（原版：左条亮黄，右条空）
func _slot_bar(r: Rect2, k: float, fill: Color) -> ProgressBar:
	var s := _slot(r, k)
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.max_value = 100.0
	pb.value = 0.0
	pb.position = s.position + Vector2(3, 3) * _ui_scale
	pb.size = s.size - Vector2(6, 6) * _ui_scale
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pb.add_theme_stylebox_override("background",
		_sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0))
	pb.add_theme_stylebox_override("fill", _sb(fill, fill, maxi(1, int(round(4.0 * _ui_scale))), 0))
	_char_panel.add_child(pb)
	return pb


## 右下：小地图框（原版配色：圆角 + 浅蓝白描边 + 深蓝底）+ 图标按钮条
func _build_bottom_right() -> void:
	var w := UI_BR_W * _ui_scale
	_br_box = VBoxContainer.new()
	_br_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_br_box.add_theme_constant_override("separation", int(round(UI_BR_GAP * _ui_scale)))
	_br_box.position = Vector2(
		-(w + UI_BR_MARGIN * _ui_scale),
		-(UI_BR_MAP_H + UI_BR_BAR_H + UI_BR_GAP + UI_BR_MARGIN) * _ui_scale)
	_br_box.custom_minimum_size = Vector2(w, 0)
	_br_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_br_box)

	var mp := PanelContainer.new()
	mp.custom_minimum_size = Vector2(w, UI_BR_MAP_H * _ui_scale)
	_br_map_sb = _sb_round(Color8(22, 62, 122), Color8(170, 232, 250),
		int(round(9.0 * _ui_scale)), maxi(2, int(round(4.0 * _ui_scale))),
		maxf(2.0, 3.0 * _ui_scale))
	mp.add_theme_stylebox_override("panel", _br_map_sb)
	_br_map_panel = mp
	_br_box.add_child(mp)
	_minimap = Minimap.new()
	mp.add_child(_minimap)

	_icon_bar = _make_icon_bar(w)
	_br_box.add_child(_icon_bar)
	_build_br_extra_pages()
	# 保险：把股票面板压到**最底层**，让功能区按钮永远在上（不被它盖住点击）
	_hud.move_child(_stock, 0)


## 图标按钮条：底 = 浅薄荷青圆角条 + 蓝描边；6 个图标全部用原版 uitex/subc/*.png
func _make_icon_bar(w: float) -> Control:
	var holder := PanelContainer.new()
	holder.custom_minimum_size = Vector2(w, UI_BR_BAR_H * _ui_scale)
	holder.add_theme_stylebox_override("panel", _sb_round(
		Color8(212, 250, 238), Color8(10, 80, 200), int(round(12.0 * _ui_scale)),
		maxi(2, int(round(4.0 * _ui_scale))), maxf(2.0, 3.0 * _ui_scale)))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(round(UI_ICON_PAD * _ui_scale)))
	holder.add_child(row)

	var s := UI_ICON_SIZE * _ui_scale
	for i in UI_ICON_NAMES.size():
		var b := TextureButton.new()
		b.texture_normal = load("res://assets/ui/panel/%s.png" % UI_ICON_NAMES[i])
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(s, s)
		b.tooltip_text = UI_ICON_TIPS[i]
		var idx := i
		b.pressed.connect(func(): _on_icon(idx))
		_sfx(b)
		row.add_child(b)
		_icon_btns.append(b)
	return holder


## 图标条回调。原版 6 个图标依次是：角色情报 / 股价 / 地图 / 聊天 / 话筒 / 播放。
## 我们只接已实现的功能，其余给一条提示，别假装能用。
func _on_icon(i: int) -> void:
	match i:
		0:                      # ① 新闻 → 面板切成「日志」（记录买卖股票 / 土地等行为）
			_set_br_page(0)
		1:                      # ② 股票 → 面板切成「股票页」
			_set_br_page(1)
		2:                      # ③ 地图 → 面板切成「小地图」（默认页）
			_set_br_page(2)
		3:                      # ④ 聊天区 → 面板切成「聊天记录」
			_set_br_page(3)
		4:                      # ⑤ 聊天 → **额外**弹出聊天栏（不占用功能区小面板）
			_toggle_chat_bar()
		5:                      # ⑥ 最右下角 → 收起 / 展开整个功能区
			_toggle_br()


## ① 日志 / ④ 聊天记录 —— 做成「占同一块地方」的页（与地图页 / 股票页互斥）
func _build_br_extra_pages() -> void:
	_br_log_page = _make_br_page()
	_br_chat_page = _make_br_page()


func _make_br_page() -> Control:
	var pc := PanelContainer.new()
	pc.visible = false
	pc.z_index = 5
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_theme_stylebox_override("panel", _sb_round(
		Color8(22, 62, 122), Color8(170, 232, 250), int(round(9.0 * _ui_scale)),
		maxi(2, int(round(4.0 * _ui_scale))), maxf(2.0, 3.0 * _ui_scale)))
	_hud.add_child(pc)
	var lb := RichTextLabel.new()
	lb.scroll_following = true
	lb.scroll_active = false
	lb.add_theme_font_size_override("normal_font_size", maxi(8, int(round(11.0 * _ui_scale))))
	lb.add_theme_color_override("default_color", Color8(226, 240, 255))
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(lb)
	pc.set_meta("label", lb)
	return pc


func _br_page_text(pc: Control, lines: Array, keep: int) -> void:
	if pc == null or not pc.visible:
		return
	var lb: RichTextLabel = pc.get_meta("label")
	var tail: Array = lines.slice(maxi(0, lines.size() - keep))
	lb.text = "\n".join(tail) if not tail.is_empty() else "（暂无记录）"


## 切换右下角功能区的页
func _set_br_page(n: int) -> void:
	_br_page = n
	_br_collapsed = false
	if _br_box != null:
		_br_box.visible = true
	_sync_br_pages()


## 右下角功能区：地图页 / 股票页 / 日志页 / 聊天记录页 —— **同一块地方互斥显示**
func _sync_br_pages() -> void:
	var on := not _br_collapsed
	var r := Rect2()
	if _br_map_panel != null:
		# ⚠⚠ **地图面板必须始终占位**（只把里面的小地图藏掉、把底框透明化）。
		#   一旦 `_br_map_panel.visible = false`，`_br_box` 这个 VBoxContainer 会
		#   重新布局，把下面的**按钮条整体上移**到地图那块地方 ——
		#   于是按钮正好钻到股票页底下被盖住，看起来就是「切到股票后按钮全没了」
		#   （老板 2026-09-26 反馈）。
		_br_map_panel.visible = on
		var on_map: bool = on and _br_page == 2
		if _minimap != null:
			_minimap.visible = on_map
		_br_map_panel.add_theme_stylebox_override("panel",
			_br_map_sb if on_map else _sb_empty())
		r = Rect2(_br_map_panel.global_position, _br_map_panel.size)
	if _stock != null:
		_stock.set_embed_rect(r, on and _br_page == 1)
	for p in [_br_log_page, _br_chat_page]:
		var pc: Control = p
		if pc == null:
			continue
		var want: bool = on and _br_page == (0 if pc == _br_log_page else 3)
		if pc.visible != want:
			pc.visible = want
		pc.position = r.position
		pc.size = r.size
	_br_page_text(_br_log_page, _log_lines, 9)
	_br_page_text(_br_chat_page, _chat_lines, 9)


func _sb_empty() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


## ⑥ 收起 / 展开整个右下角功能区
func _toggle_br() -> void:
	_br_collapsed = not _br_collapsed
	if _br_box != null:
		_br_box.visible = not _br_collapsed
	if _br_collapsed and _chat_bar != null:
		_chat_bar.visible = false
	_sync_br_pages()


## ---------------------------------------------------------------- 动作入口
## 原版的地产操作不是常驻按钮，而是**角色头顶的 GO 圆钮**（掷骰子）
## 和**落点提示气泡**（买地 / 升级 / 放弃）。
## 我们用 GUI 控件跟随当前玩家的屏幕投影位置，逐帧更新（见 _process 里的 _sync_action_ui）。
func _build_action_entry() -> void:
	# ---- GO 圆钮 = 掷骰子 ----
	_go_btn = TextureButton.new()
	_go_btn.texture_normal = load("res://assets/ui/panel/go_btn.png")
	_go_btn.texture_pressed = load("res://assets/ui/panel/go_btn_dn.png")
	_go_btn.ignore_texture_size = true
	_go_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var gs := UI_GO_SIZE * _ui_scale
	_go_btn.size = Vector2(gs, gs)
	_go_btn.tooltip_text = "掷骰子（空格）"
	_go_btn.visible = false
	_go_btn.pressed.connect(_on_go_pressed)
	_sfx(_go_btn, true)
	_hud.add_child(_go_btn)

	# ---- 骰子数量选择器（原版 GO 圆钮**左侧竖排的两颗骰子**）----
	# 白/亮 = 选中、灰/暗 = 未选中。原版实机截图 `08_牌桌_2.png` 里只看到 2 颗，
	# 这里按 Sim.DICE_PER_ROLL_MAX 建，多出来的自动隐藏。
	_ensure_die_textures()
	for i in range(Sim.DICE_PER_ROLL_MAX):
		var d := TextureRect.new()
		d.texture = _tex_face[0]
		d.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		d.stretch_mode = TextureRect.STRETCH_SCALE
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		d.pivot_offset = Vector2(DIE_PX, DIE_PX) * 0.5
		d.visible = false
		_hud.add_child(d)
		_dice_sel.append(d)
	# 选择器要能点 —— 用一个透明按钮盖在上面（TextureRect 不接收输入）
	_dice_hit = []
	for i in range(Sim.DICE_PER_ROLL_MAX):
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", _sb_round(Color8(255, 255, 255, 40),
			Color8(255, 255, 255, 0), int(round(6.0 * _ui_scale)), 0, 0.0))
		b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		b.tooltip_text = "掷 %d 颗骰子" % (i + 1)
		b.visible = false
		var n := i + 1
		b.pressed.connect(func(): _set_dice_count(n))
		_hud.add_child(b)
		_dice_hit.append(b)

	# ---- 落点气泡 = 买 / 升级 / 放弃（是 / 否 用原版 yes_up/no_up 贴图）----
	_pop = PanelContainer.new()
	_pop.visible = false
	# 层级：气泡要在**商店面板之上** —— 商店购买确认复用的就是它，
	# 否则「是/否」会被面板压住，点不到（老板 2026-09-26 反馈）
	_pop.z_index = 60
	_pop.custom_minimum_size = Vector2(UI_POP_W * _ui_scale, UI_POP_H * _ui_scale)
	# 底图 = 原版 `uitex/other/infobk.tga`（灰白圆角 + 蓝底边）——
	# 就是老板原版截图里那个「小财神价格100点券 确认要购买吗？」的对话框
	var fb := StyleBoxTexture.new()
	var ftex := _tex_or_null("res://assets/ui/shop/infobk.png")
	if ftex != null:
		fb.texture = ftex
		var m := int(round(26.0 * _ui_scale))
		fb.texture_margin_left = m
		fb.texture_margin_right = m
		fb.texture_margin_top = m
		fb.texture_margin_bottom = int(round(34.0 * _ui_scale))
		fb.content_margin_left = 16.0 * _ui_scale
		fb.content_margin_right = 16.0 * _ui_scale
		fb.content_margin_top = 10.0 * _ui_scale
		fb.content_margin_bottom = 6.0 * _ui_scale
		_pop.add_theme_stylebox_override("panel", fb)
	else:
		_pop.add_theme_stylebox_override("panel", _sb_round(
			Color8(255, 250, 236), Color8(206, 78, 92), int(round(8.0 * _ui_scale)),
			maxi(3, int(round(5.0 * _ui_scale))), maxf(1.5, 2.0 * _ui_scale)))
	_hud.add_child(_pop)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", maxi(2, int(round(3.0 * _ui_scale))))
	_pop.add_child(pv)

	_pop_text = Label.new()
	_pop_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pop_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pop_text.add_theme_font_size_override("font_size", maxi(10, int(round(12.0 * _ui_scale))))
	# 原版对话框的文字是**深色**（白底黑字），别用默认浅色
	_pop_text.add_theme_color_override("font_color", Color8(38, 58, 108))
	_pop_text.add_theme_color_override("font_color", Color8(44, 34, 66))
	pv.add_child(_pop_text)

	# 房型选择（原版 id 92「选择房屋」；只有一种可建房型时不出现）
	_btn_bldtype = OptionButton.new()
	_btn_bldtype.add_theme_font_size_override("font_size", maxi(9, int(round(11.0 * _ui_scale))))
	_btn_bldtype.visible = false
	pv.add_child(_btn_bldtype)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)   # 是|否 两块半胶囊要贴紧成一整颗
	pv.add_child(row)

	_pop_yes = _pop_btn("yes", func(): _pop_confirm())
	row.add_child(_pop_yes)
	_pop_no = _pop_btn("no", func(): _pop_cancel())
	row.add_child(_pop_no)


## ============================ GO 钮上的骰子 ============================
## 素材（原版 `uitex/labar/`，已由 tools/make_panel_ui.py 整理）：
##   `dice_anim.png` 128×128 = 4×4 共 **16 帧翻滚**（点击前慢转、掷出时快转都用它）
##   `die_faces.png` 192×32  = **6 个骰子面**（1..6，1/4 红点），停下后定格用
## 原版行为（`08_牌桌_2.png`）：GO 圆钮左边缘竖排两颗骰子，白的选中 / 灰的没选。

func _ensure_die_textures() -> void:
	## AtlasTexture 缓存一次即可（每帧 new 会漏资源）
	if not _tex_spin.is_empty():
		return
	var spin_base: Texture2D = load("res://assets/ui/panel/dice_anim.png")
	if spin_base != null:
		for i in range(16):
			var a := AtlasTexture.new()
			a.atlas = spin_base
			a.region = Rect2(float(i % 4) * DIE_PX, float(i / 4) * DIE_PX, DIE_PX, DIE_PX)
			_tex_spin.append(a)
	var face_base: Texture2D = load("res://assets/ui/panel/die_faces.png")
	if face_base != null:
		for i in range(6):
			var a2 := AtlasTexture.new()
			a2.atlas = face_base
			a2.region = Rect2(float(i) * DIE_PX, 0.0, DIE_PX, DIE_PX)
			_tex_face.append(a2)


## 选择几颗骰子（点 GO 钮左侧那排骰子）
func _set_dice_count(n: int) -> void:
	_dice_count = clampi(n, 1, Sim.DICE_PER_ROLL_MAX)
	if _go_btn != null:
		_go_btn.tooltip_text = "掷骰子（空格）· %d 颗" % _dice_count
	Audio.play_sfx(Audio.SFX_UI_CLICK)


## GO 钮被按下：把当前选择的颗数一起发出去（服务端掷骰）
func _on_go_pressed() -> void:
	Net.send_action("roll", [_dice_count])


## 收到 `roll` 语义事件 → 播放「骰子掷出」动画
func _start_dice_fly(faces: Array) -> void:
	if faces.is_empty() or _go_btn == null or not _go_btn.visible:
		# 自己没在看着自己的 GO（例如引擎刚开局）就只定格一下，不做飞行动画
		if faces.is_empty():
			return
	_ensure_die_textures()
	_clear_dice_fx()
	var n: int = faces.size()
	var base: Vector2 = _go_btn.position + _go_btn.size * 0.5
	for i in range(n):
		var t := TextureRect.new()
		t.texture = _tex_spin[0] if not _tex_spin.is_empty() else null
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.pivot_offset = Vector2(DIE_PX, DIE_PX) * 0.5
		var s := DIE_FLY_SIZE * 0.7 * _ui_scale
		t.size = Vector2(s, s)
		t.position = base - t.size * 0.5
		_hud.add_child(t)
		_dice_fx.append(t)
		var side := 0.0 if n == 1 else (float(i) - float(n - 1) * 0.5)
		_dice_fx_from.append(base + Vector2(side * 22.0 * _ui_scale, -4.0 * _ui_scale))
		# 飞到角色头顶更高处，几颗呈扇形散开
		_dice_fx_to.append(base + Vector2(side * 40.0 * _ui_scale, -104.0 * _ui_scale))
	_dice_fx_faces = faces.duplicate()
	_dice_fx_t = 0.0
	_dice_fx_state = "fly"


func _clear_dice_fx() -> void:
	for t in _dice_fx:
		if is_instance_valid(t):
			t.queue_free()
	_dice_fx.clear()
	_dice_fx_from.clear()
	_dice_fx_to.clear()
	_dice_fx_faces.clear()
	_dice_fx_state = ""
	_dice_fx_t = 0.0


## 每帧推进（选择器慢转 + 掷出飞行 + 定格展示）
func _tick_dice(delta: float) -> void:
	if _tex_spin.is_empty():
		return
	# ---- 待机：选中的骰子缓慢翻滚（一眼能看出「它在转」）----
	_dice_sel_t += delta * DIE_IDLE_FPS
	var f: int = int(_dice_sel_t) % _tex_spin.size()
	for i in range(_dice_sel.size()):
		var d: TextureRect = _dice_sel[i]
		if not d.visible:
			continue
		if i < _dice_count:
			d.texture = _tex_spin[f]
			d.modulate = Color(1, 1, 1, 1)
		else:
			d.texture = _tex_face[0]                  # 未选中：静止 1 点 + 压灰
			d.modulate = Color(0.42, 0.42, 0.46, 0.85)

	if _dice_fx_state == "":
		return
	_dice_fx_t += delta

	if _dice_fx_state == "fly":
		var k := clampf(_dice_fx_t / DIE_FLY_TIME, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 3.0)              # ease-out
		for i in range(_dice_fx.size()):
			var t: TextureRect = _dice_fx[i]
			if not is_instance_valid(t):
				continue
			# 抛物线：掷出去的骰子**先上抛再落下**（sin(k·π) 两端为 0、中间最高，
			# 正好是一条弧）。老板 2026-09-26：「骰子会有抛物线落下的感觉」。
			var arc := sin(k * PI) * DIE_FLY_ARC * _ui_scale
			t.position = (_dice_fx_from[i] as Vector2).lerp(_dice_fx_to[i], e) \
				+ Vector2(0.0, -arc)
			t.rotation = TAU * 2.0 * e * (1.0 if i % 2 == 0 else -1.0)
			if not _tex_spin.is_empty():
				t.texture = _tex_spin[int(_dice_fx_t * DIE_SPIN_FPS) % _tex_spin.size()]
			var s := (0.7 + 0.3 * e) * DIE_FLY_SIZE * _ui_scale
			t.size = Vector2(s, s)
			t.pivot_offset = t.size * 0.5
		if k >= 1.0:
			_dice_fx_state = "hold"
			_dice_fx_t = 0.0
			for i in range(_dice_fx.size()):
				var t2: TextureRect = _dice_fx[i]
				if not is_instance_valid(t2):
					continue
				t2.rotation = 0.0
				var face := clampi(int(_dice_fx_faces[i]) - 1, 0, _tex_face.size() - 1)
				if not _tex_face.is_empty():
					t2.texture = _tex_face[face]
	elif _dice_fx_state == "hold":
		if _dice_fx_t >= DIE_HOLD_TIME:
			_clear_dice_fx()


func _pop_btn(kind: String, cb: Callable) -> TextureButton:
	var b := TextureButton.new()
	# 素材 64x32，但**可见区只有左边 56x32**（右边 8px 全透明）。
	# `yes` 只有**左**圆头、`no` 只有**右**圆头 → 两张**并排贴紧**才凑成一整颗胶囊，
	# 所以用 AtlasTexture 先裁掉那 8px 透明边，再让 row 的 separation = 0。
	# ⚠ 若用 KEEP_ASPECT_* 且容器给窄了，胶囊会被**裁掉一半**（实测过）。
	var mk := func(p: String) -> AtlasTexture:
		var at := AtlasTexture.new()
		at.atlas = load(p)
		at.region = Rect2(0, 0, 56, 32)
		return at
	b.texture_normal = mk.call("res://assets/uitex/other/%s_up.png" % kind)
	b.texture_pressed = mk.call("res://assets/uitex/other/%s_dn.png" % kind)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.custom_minimum_size = Vector2(56.0, 32.0) * _ui_scale
	b.pressed.connect(cb)
	_sfx(b)
	return b


## 落点气泡的「是」：按当前模式发买地 / 升级 / 卡片二次确认
func _pop_confirm() -> void:
	if _pop_mode == "buy":
		Net.send_action("buy")
	elif _pop_mode == "upgrade":
		var t: Variant = _btn_bldtype.get_item_metadata(_btn_bldtype.selected) \
			if _btn_bldtype.visible and _btn_bldtype.item_count > 0 else null
		Net.send_action("upgrade", [str(t)] if t != null else [])
	elif _pop_mode == "card":
		var cid := _card_confirm_id
		_close_card_confirm()
		if cid != "":
			Net.send_action("card", [cid])
	elif _pop_mode == "shop":
		_pop_buy_confirm()
	else:
		Net.send_action("pass")


## 落点气泡的「否」：
##   · 卡片二次确认 → 只是关掉确认框（**别发 pass**，那会把这次落地机会也放弃掉）
##   · 买地 / 升级 → 原版就是「放弃本次机会」
func _pop_cancel() -> void:
	if _pop_mode == "card":
		_close_card_confirm()
		return
	if _pop_mode == "shop":
		_shop_pending = ""
		_pop_mode = ""
		_pop.visible = false
		return
	Net.send_action("pass")


## 购买确认的「是」：按 _shop_pending 发对应动作
func _pop_buy_confirm() -> void:
	var pend := _shop_pending
	_shop_pending = ""
	_pop_mode = ""
	_pop.visible = false
	if pend.begins_with("pet:"):
		Net.send_action("buy_pet", [pend.substr(4)])
	elif pend.begins_with("card:"):
		Net.send_action("buy_card", [pend.substr(5)])


## ============================================================ 卡片手牌
## 原版有独立卡片界面；我们按原版素材与文案重建为「底部手牌条」：
##   · 每张卡 = 原版卡面 `res://assets/card/<id>.png`（左上角带徽章数字）
##   · 点卡片 → 弹原版卡片菜单（String.txt 1/2/3 = 使用 / 锁定 / 丢弃）
##   · 需要点对手的卡（String.txt 1101）→ 进入选目标模式，点亮右侧头像列
##   · 悬停 → 原版卡面说明（String.txt 9001..9042）
## 小神仙条（角色面板右侧）。原版把持有的小神仙画在角色面板旁边，
## 而没有单独的「持有」面板 —— 所以精灵屋那边只显示商店。
## 股票面板的「买进 / 卖出 / 股东 / 走势」（原版点一行弹出的四个按钮）
func _on_stock_action(kind: String, comp: String, shares: int) -> void:
	match kind:
		"buy":
			Net.send_action("buy_stock", [comp, shares])
		"sell":
			Net.send_action("sell_stock", [comp, shares])
		"holder":
			# 股东名单（持股 ≥60% 当董事长，见 Info.txt 131..135）
			if Net.sim == null:
				return
			var rows: Array = []
			for pid in Net.sim.player_ids():
				var h := Net.sim.holding_of(int(pid), comp)
				if h > 0:
					rows.append("%s %d" % [str((Net.sim.players[pid] as Dictionary)["name"]), h])
			var ch := int((Net.sim.stocks.get(comp, {}) as Dictionary).get("chairman", -1))
			var who := "—"
			if ch >= 0 and Net.sim.players.has(ch):
				who = str((Net.sim.players[ch] as Dictionary)["name"])
			_toast("%s ｜ 董事长：%s ｜ %s" % [comp, who,
				"、".join(rows) if not rows.is_empty() else "暂无股东"])
		"trend":
			if Net.sim != null:
				_toast("%s 当前涨跌 %+d%%（走势图待做）" % [comp, Net.sim.stock_change(comp)])
		"pick":
			# 红卡 / 黑卡：在行情面板上选中了公司 → 正式用卡（第 3 个参数 = 公司名）
			var cid := _card_pending
			_card_pending = ""
			if _card_hint != null:
				_card_hint.visible = false
			if cid != "":
				Net.send_action("card", [cid, -1, comp])


func _build_pet_strip() -> void:
	_pet_strip = Control.new()
	_pet_strip.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_pet_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_pet_strip)
	for _i in range(5):                        # Info.txt 202：最多 5 位
		var t := TextureRect.new()
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.visible = false
		_pet_strip.add_child(t)
		_pet_strip_nodes.append(t)


func _sync_pet_strip(me: Dictionary) -> void:
	if _pet_strip == null or _char_panel == null:
		return
	var ps: Array = me.get("pets", [])
	var px := PET_STRIP_PX * _ui_scale
	var gap := 3.0 * _ui_scale
	for i in range(_pet_strip_nodes.size()):
		var t: TextureRect = _pet_strip_nodes[i]
		if i >= ps.size():
			t.visible = false
			continue
		var e: Dictionary = ps[i]
		var pid := str(e.get("id", ""))
		var lv := int(e.get("level", 1))
		t.texture = _tex_or_null(Rules.pet_art(pid, "face", lv))
		t.visible = t.texture != null
		t.size = Vector2(px, px)
		t.position = Vector2(float(i) * (px + gap), 0.0)
		var pname := pid
		if Net.sim != null:
			pname = Net.sim.pet_name(pid)
		t.tooltip_text = "%s Lv%d" % [pname, lv]
	# 整条贴在角色面板**右边**（锚点同 _char_panel）
	_pet_strip.position = Vector2(
		_char_panel.position.x + _char_panel.size.x + 4.0 * _ui_scale,
		_char_panel.position.y)


func _build_card_hand() -> void:
	# ---- 卡片夹开关：原版 uitex/other/clamp.png（String.txt id 2010「卡片夹子」）----
	_clamp_btn = TextureButton.new()
	_clamp_btn.texture_normal = load("res://assets/uitex/other/clamp.png")
	_clamp_btn.ignore_texture_size = true
	_clamp_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_clamp_btn.custom_minimum_size = Vector2(30.0, 30.0) * _ui_scale
	_clamp_btn.size = Vector2(30.0, 30.0) * _ui_scale
	_clamp_btn.tooltip_text = "卡片夹（原版 String.txt 2010）"
	_clamp_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_clamp_btn.position = Vector2((UI_CHAR_W + 8.0) * _ui_scale,
		-(34.0 + UI_BR_MARGIN) * _ui_scale)
	_clamp_btn.pressed.connect(func():
		_card_bar_open = not _card_bar_open
		Audio.play_sfx(Audio.SFX_UI_CLICK))
	_hud.add_child(_clamp_btn)

	# ---- 手牌条 ----
	_card_bar = Control.new()
	_card_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_card_bar)

	# ---- 菜单（使用 / 锁定 / 丢弃）----
	_card_menu = PanelContainer.new()
	_card_menu.visible = false
	_card_menu.custom_minimum_size = Vector2(CARD_MENU_W * _ui_scale, 0)
	# 底框借用原版 uitex/other/infobk.png 的配色（粉底 + 深蓝描边），与说明条同一家族
	_card_menu.add_theme_stylebox_override("panel", _sb_round(
		Color8(255, 234, 247), Color8(10, 40, 150), int(round(8.0 * _ui_scale)),
		maxi(3, int(round(5.0 * _ui_scale))), maxf(1.5, 2.0 * _ui_scale)))
	_hud.add_child(_card_menu)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", maxi(1, int(round(2.0 * _ui_scale))))
	_card_menu.add_child(mv)
	_card_menu_btns = []
	# 菜单项与顺序都对齐原版：老板原版截图（records/喂食功能.png）里是
	# **「锁定 / 使用 / 喂食」**三项 —— 没有「丢弃」。
	for which in ["lock", "use", "feed"]:
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_font_size_override("font_size", maxi(10, int(round(12.0 * _ui_scale))))
		b.add_theme_color_override("font_color", Color8(30, 30, 90))
		# Godot 的 disabled 字色默认近乎全透明 → 压暗后的「使用」会整条看不见，
		# 看起来像菜单少了一项（实测截图如此）。这里显式给一个灰字。
		b.add_theme_color_override("font_disabled_color", Color8(146, 146, 164))
		b.add_theme_stylebox_override("hover", _sb_round(Color8(180, 230, 255),
			Color8(255, 255, 255, 0), int(round(5.0 * _ui_scale)), 0, 0.0))
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		var m: String = which
		b.pressed.connect(func(): _on_card_menu(m))
		mv.add_child(b)
		_card_menu_btns.append(b)

	# ---- 「请选择对手」提示条（String.txt 1101）----
	_card_hint = Label.new()
	_card_hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_card_hint.offset_top = (UI_BAR_H + 30.0) * _ui_scale
	_card_hint.offset_bottom = _card_hint.offset_top + 22.0 * _ui_scale
	_card_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card_hint.add_theme_font_size_override("font_size", maxi(10, int(round(14.0 * _ui_scale))))
	_card_hint.add_theme_color_override("font_color", Color8(255, 230, 120))
	_card_hint.add_theme_color_override("font_outline_color", Color8(20, 20, 40))
	_card_hint.add_theme_constant_override("outline_size", 5)
	_card_hint.visible = false
	_card_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_card_hint)

	# ---- 骰子卡的步数选择器（String.txt 9016「自由选择前进的步数」）----
	_step_picker = HBoxContainer.new()
	_step_picker.visible = false
	_step_picker.add_theme_constant_override("separation", maxi(2, int(round(3.0 * _ui_scale))))
	_hud.add_child(_step_picker)
	for n in range(1, 7):
		var sb := Button.new()
		sb.text = str(n)
		sb.custom_minimum_size = Vector2(28.0, 30.0) * _ui_scale
		sb.focus_mode = Control.FOCUS_NONE
		sb.add_theme_font_size_override("font_size", maxi(11, int(round(15.0 * _ui_scale))))
		sb.add_theme_color_override("font_color", Color8(20, 30, 90))
		sb.add_theme_stylebox_override("normal", _sb_round(Color8(212, 250, 238),
			Color8(10, 80, 200), int(round(6.0 * _ui_scale)), 0, maxf(1.0, 2.0 * _ui_scale)))
		sb.add_theme_stylebox_override("hover", _sb_round(Color8(255, 246, 190),
			Color8(10, 80, 200), int(round(6.0 * _ui_scale)), 0, maxf(1.0, 2.0 * _ui_scale)))
		var k := n
		sb.pressed.connect(func(): _on_step_picked(k))
		_sfx(sb)
		_step_picker.add_child(sb)


## 手牌同步：按当前玩家的 cards 重建（只在变化时重建，避免每帧抖动）
## 这张卡是不是被玩家锁定着。锁定状态在**权威 Sim** 里（`p["card_locks"]`），
## 因为满栏顶卡时要跳过它 —— 那个判定在服务端。
func _card_is_locked(cid: String) -> bool:
	var me: Dictionary = (_snapshot.get("players", {}) as Dictionary).get(
		multiplayer.get_unique_id(), {})
	return bool((me.get("card_locks", {}) as Dictionary).get(cid, false))


func _sync_card_hand(me: Dictionary) -> void:
	if _card_bar == null:
		return
	# ⚠ **不要 sort**！手牌的「获得顺序」是有意义的 —— 满栏时被顶掉的是**最前方**那张
	#   （老板 2026-09-26 的原版规则）。同种的卡由下面的「按首次出现去重」合并成 ×N。
	var cards: Array = (me.get("cards", []) as Array).duplicate()
	# 可用性（亮/暗）会随「站到哪一格 / 钱够不够 / 有没有目标」而变，
	# 所以必须一并纳入变化检测，否则走过去之后卡片还停在上一帧的明暗状态。
	var sig: Array = []
	if Net.sim != null:
		for cid in cards:
			sig.append(Net.sim.card_usable(multiplayer.get_unique_id(), str(cid)))
	else:
		sig = cards.duplicate()
	# ⚠ 别在这里加「商店开着就隐藏手牌条」：那会顺带清空 _card_slots，
	#   把 --uishot 的卡片菜单/选目标两张连累拍不到。商店面板在手牌条之上，
	#   二者本来就不重叠（老板截图里也是分开的）。
	var want_visible: bool = _card_bar_open and not cards.is_empty()
	if cards == _card_sig and sig == _card_sig_state and _card_bar.visible == want_visible:
		return
	_card_sig = cards
	_card_sig_state = sig
	_hide_card_menu()
	for s in _card_slots:
		var b: Variant = (s as Dictionary).get("box", null)
		if b != null and is_instance_valid(b):
			(b as Node).queue_free()
	_card_slots.clear()
	_card_ids.clear()
	_card_bar.visible = want_visible
	if not want_visible:
		return

	# 同种卡合并成一张 + 数量角标。
	# ⚠️ 必须按**首次出现顺序**去重（不能用「相邻相同才合并」）—— 手牌不再排序了，
	#    同种的卡可能不相邻；而栏位顺序 = 获得顺序（满栏顶卡看的就是它）。
	var groups: Array = []                          # [{id, n}]
	var gidx: Dictionary = {}                       # 卡 id -> groups 下标
	for cid in cards:
		var key := str(cid)
		if gidx.has(key):
			var g0: Dictionary = groups[int(gidx[key])]
			g0["n"] = int(g0["n"]) + 1
		else:
			gidx[key] = groups.size()
			groups.append({"id": key, "n": 1})

	var shown: int = mini(groups.size(), CARD_SHOW_MAX)
	# 卡面边长：默认 CARD_PX（100 native），但**一排要放得进**
	# 「左下角色面板 → 右下小地图」之间的空档。放不下就等比缩（下限 = 旧布局的 62），
	# 这样 9 张也不会压住右下角的小地图（卡面调大后实测会顶到 1077 px，见 2026-09-26）。
	var free_l := (UI_CHAR_X + UI_CHAR_W + 6.0) * _ui_scale
	var free_r := get_viewport().get_visible_rect().size.x \
		- (UI_BR_W + UI_BR_MARGIN + 6.0) * _ui_scale
	var avail := maxf(free_r - free_l, 120.0 * _ui_scale)
	var cw := CARD_PX * _ui_scale
	var step := (CARD_PX + CARD_GAP) * _ui_scale
	if step * float(shown) - CARD_GAP * _ui_scale > avail:
		cw = maxf((avail + CARD_GAP * _ui_scale) / float(shown) - CARD_GAP * _ui_scale,
			62.0 * _ui_scale)
		step = cw + CARD_GAP * _ui_scale
	var total := step * float(shown) - CARD_GAP * _ui_scale
	var x0 := free_l + (avail - total) * 0.5
	var y0 := get_viewport().get_visible_rect().size.y - cw - UI_BR_MARGIN * _ui_scale

	for i in range(shown):
		var g: Dictionary = groups[i]
		var cid := str(g["id"])
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", _sb_round(
			Color8(246, 250, 255), Color8(10, 60, 170), int(round(6.0 * _ui_scale)),
			maxi(1, int(round(2.0 * _ui_scale))), maxf(1.0, 1.6 * _ui_scale)))
		box.position = Vector2(x0 + step * float(i), y0)
		box.size = Vector2(cw, cw)
		_card_bar.add_child(box)

		var img := TextureRect.new()
		img.texture = _card_face(cid)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(img)

		# 数量角标（同种多张时）
		var cnt: Label = null
		if int(g["n"]) > 1:
			cnt = Label.new()
			cnt.text = "×%d" % int(g["n"])
			cnt.add_theme_font_size_override("font_size", maxi(9, int(round(11.0 * _ui_scale))))
			cnt.add_theme_color_override("font_color", Color8(255, 245, 160))
			cnt.add_theme_color_override("font_outline_color", Color8(20, 20, 40))
			cnt.add_theme_constant_override("outline_size", 4)
			# PanelContainer 会把子节点撑满 → 用对齐把角标压到右下
			cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			cnt.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(cnt)

		var btn := Button.new()
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("hover", _sb_round(Color8(255, 255, 255, 60),
			Color8(255, 246, 120), int(round(6.0 * _ui_scale)), 0, maxf(1.0, 2.0 * _ui_scale)))
		btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		# 「此刻能不能用」——原版有整套原因码（String.txt 61..70）。
		# 老板 2026-09-26 反馈：用不了的卡不该一直亮着，应该**压暗**。
		var code := 0
		if Net.sim != null:
			code = Net.sim.card_usable(multiplayer.get_unique_id(), cid)
		btn.tooltip_text = "%s\n%s\n（原版 String.txt %d）%s" % [
			Rules.card_name(cid), Rules.card_desc(cid), 9000 + _card_n(cid),
			"" if code == 0 else "\n⚠ 现在用不了：%s" % Rules.ui_string(code)]
		var idx := i
		btn.pressed.connect(func(): _on_card_clicked(idx))
		box.add_child(btn)

		# 压暗的两种情况（前者优先）：玩家自己「锁定」了这张卡（菜单 id 2）、
		# 或者这张卡此刻条件不满足。
		if bool((me.get("card_locks", {}) as Dictionary).get(cid, false)):
			img.modulate = Color(0.55, 0.55, 0.6, 0.9)
		elif code != 0:
			img.modulate = Color(0.62, 0.62, 0.68, 0.72)
		_card_slots.append({"box": box, "img": img, "btn": btn, "cnt": cnt, "code": code})
		_card_ids.append(cid)


func _card_n(cid: String) -> int:
	var arr: Array = Rules.card_index.get("cards", [])
	for e in arr:
		if str((e as Dictionary).get("id", "")) == cid:
			return int((e as Dictionary).get("n", 0))
	return 0


func _card_face(cid: String) -> Texture2D:
	var p := Rules.card_face_path(cid)
	if not ResourceLoader.exists(p):
		return null
	var r: Resource = load(p)
	return r if r is Texture2D else null


## 点了一张卡 → 弹菜单（使用 / 锁定 / 丢弃）
func _on_card_clicked(slot: int) -> void:
	Audio.play_sfx(Audio.SFX_UI_CLICK)
	if slot < 0 or slot >= _card_slots.size():
		return
	_card_menu_at = slot
	var box: Control = (_card_slots[slot] as Dictionary)["box"]
	var labels := [Rules.card_menu_label("lock"), Rules.card_menu_label("use"),
		Rules.card_menu_label("feed")]
	var cid := str(_card_ids[slot]) if slot < _card_ids.size() else ""
	var locked := _card_is_locked(cid)
	var code := int((_card_slots[slot] as Dictionary).get("code", 0))
	# 用不了的卡：当场把原版原因说出来（String.txt 61..70），
	# 而不是让玩家对着「点了没反应」发呆（老板 2026-09-26 反馈）
	if code != 0 and not locked:
		_toast("「%s」用不了：%s" % [Rules.card_name(cid), Rules.ui_string(code)])
	var blocked := locked or code != 0
	for i in range(_card_menu_btns.size()):
		var b: Button = _card_menu_btns[i]
		b.text = labels[i]
		# 「锁定」永远可用；「使用」「喂食」在锁定 / 条件不满足时禁用
		b.disabled = blocked and i != 0
	var mh := _card_menu.get_combined_minimum_size().y
	if mh <= 0.0:
		mh = 84.0 * _ui_scale
	_card_menu.size = Vector2(CARD_MENU_W * _ui_scale, mh)
	var vp := get_viewport().get_visible_rect().size
	_card_menu.position = Vector2(
		clampf(box.global_position.x, 4.0, vp.x - _card_menu.size.x - 4.0),
		maxf(4.0, box.global_position.y - _card_menu.size.y - 4.0 * _ui_scale))
	_card_menu.visible = true


func _hide_card_menu() -> void:
	_card_menu_at = -1
	if _card_menu != null:
		_card_menu.visible = false


## 菜单项：use / lock / discard
func _on_card_menu(which: String) -> void:
	var slot := _card_menu_at
	_hide_card_menu()
	if slot < 0 or slot >= _card_slots.size():
		return
	var cid := str(_card_ids[slot]) if slot < _card_ids.size() else ""
	if cid == "":
		return
	match which:
		"use":
			Audio.play_sfx(Audio.SFX_UI_CONFIRM)
			if Net.sim == null:
				return
			var bad := Net.sim.card_usable(multiplayer.get_unique_id(), cid)
			if bad != 0:
				_toast("「%s」用不了：%s" % [Rules.card_name(cid), Rules.ui_string(bad)])
				return
			if CARD_CONFIRM_IDS.has(cid):
				# 会动到**别人的已有地产** → 先弹原版「是 / 否」二次确认
				# （老板 2026-09-26 反馈：购地卡使用之后应该出一个二次确认框）
				_open_card_confirm(cid)
			elif Net.sim.card_needs_player(cid):
				# 需要点对手的卡 → 先进「选目标」模式（原版 String.txt 1101「请选择对手」）
				_set_card_target_mode(cid)
			elif Net.sim.card_target(cid) == "stock":
				# 红卡 / 黑卡要**选一种股票**（CARD_TARGET 里就是 "stock"）→
				# 让右下角行情面板进入「请选择」模式，点一行完成
				_card_pending = cid
				var tip := "%s  →  %s" % [Rules.card_name(cid), "请选择一种股票"]
				_card_hint.text = tip
				_card_hint.visible = true
				if _stock != null:
					_stock.begin_pick(tip)
			else:
				Net.send_action("card", [cid])
		"lock":
			# 锁定状态放在**权威 Sim** 里（`p["card_locks"]`）—— 满栏顶卡时要跳过锁定的卡，
			# 那个判定在服务端做，不能再放本地字典（老板 2026-09-26 的卡片栏规则）
			Audio.play_sfx(Audio.SFX_UI_CLICK)
			Net.send_action("lock_card", [cid])
			_card_sig.clear()        # 强制重建以刷新压暗
		"discard":
			Audio.play_sfx(Audio.SFX_UI_CLICK)
			Net.send_action("discard", [cid])
		"feed":
			# 「喂食」：把卡片喂给小神仙（原版卡片菜单第三项，String.txt 4 = 喂食）
			Audio.play_sfx(Audio.SFX_UI_CONFIRM)
			Net.send_action("feed", [cid])
		_:
			pass


## 进入「请选择对手」模式：点亮右侧头像列，点头像即用卡
func _set_card_target_mode(cid: String) -> void:
	_card_pending = cid
	_card_hint.text = "%s  →  %s" % [Rules.card_name(cid), Rules.card_target_prompt("player")]
	_card_hint.visible = true
	_sync_avatar_column(_player_ids(), _snapshot.get("players", {}), multiplayer.get_unique_id())


func _clear_card_target_mode() -> void:
	_card_pending = ""
	if _card_hint != null:
		_card_hint.visible = false
	if _avatar_rows.size() > 0:
		_sync_avatar_column(_player_ids(), _snapshot.get("players", {}), multiplayer.get_unique_id())


## 卡片二次确认（购地卡 / 土神卡）—— 复用落点气泡那套**原版是/否贴图**，
## 只是模式标成 "card"、文案换成「是否购买」。
func _open_card_confirm(cid: String) -> void:
	if _pop == null or _board == null or Net.sim == null:
		return
	var my := multiplayer.get_unique_id()
	var me: Dictionary = (_snapshot.get("players", {}) as Dictionary).get(my, {})
	var lidx := int(me.get("tile", -1))
	_card_confirm_id = cid
	_pop_mode = "card"
	_btn_bldtype.visible = false
	var price := Net.sim.plot_value(lidx)
	_pop_text.text = "%s\n%s\n%d 元 · 是否购买？" % [
		Rules.card_name(cid), _plot_name(lidx), price]
	_pop.visible = true


func _close_card_confirm() -> void:
	_card_confirm_id = ""
	if _pop_mode == "card":
		_pop_mode = ""
	if _pop != null:
		_pop.visible = false


func _player_ids() -> Array:
	var ids: Array = (_snapshot.get("players", {}) as Dictionary).keys()
	ids.sort()
	return ids


## 点了某个玩家的头像（只有选目标模式下有效）
func _on_avatar_clicked(pid: int) -> void:
	if _card_pending == "":
		return
	if pid == multiplayer.get_unique_id():
		_toast("不能对自己用这张卡")
		return
	Audio.play_sfx(Audio.SFX_UI_CONFIRM)
	Net.send_action("card", [_card_pending, pid])
	_clear_card_target_mode()


## ⚠ 仅供 `--uishot` / `--demo` 验收：直接往本机玩家手牌里塞卡。
## 真实的获得路径是踩到「卡片商店 / 卡片点」（由 Sim._resolve_event 发卡，
## --selftest 的 _test_road_events 会断言它真的发了）。
func _dev_give_cards(ids: Array) -> void:
	if Net.sim == null:
		return
	var my := multiplayer.get_unique_id()
	if not Net.sim.players.has(my):
		return
	var p: Dictionary = Net.sim.players[my]
	for c in ids:
		Net.sim._push_card(p, str(c))       # 走正规发卡（受 5 栏上限约束）
	_card_sig.clear()


## 骰子卡：步数选择器（1..6）
func _show_step_picker() -> void:
	if _step_picker == null:
		return
	_step_picker.position = Vector2(
		(get_viewport().get_visible_rect().size.x - 200.0 * _ui_scale) * 0.5,
		get_viewport().get_visible_rect().size.y * 0.5 - 40.0 * _ui_scale)
	_step_picker.visible = true
	_step_picker_i = -1
	_toast("骰子卡：请选择前进步数")


func _on_step_picked(n: int) -> void:
	if _step_picker != null:
		_step_picker.visible = false
	_step_picker_i = n
	Net.send_action("walk", [n])


## ==================================================== 两家商店（精灵屋 / 卡片商店）
## 底图**全部是原版现成的**（`tools/build_pet_assets.py` 转进 `assets/ui/shop/`）：
##   `pethouse_panel.png` = 「小神仙」持有面板（标题「小神仙」，2×2 共 4 格）
##   `pethouse_shop.png`  = 「小神仙商店」货架（2×2 共 4 格）
##   `cardshop.png`       = 「卡片商店」（2 列 × 4 行 = 8 格 + 顶部「您有 N 点券」深色条）
## 槽位坐标不硬编码，读 `assets/pets/index.json` 的 `slot` 表（对着原版底图量的）。
## 文案全部取 `config/Info.txt`：201 精灵屋 / 202 上限 / 203 购买确认 / 41、42 卡片商店。
var _shop: Control
var _shop_mode: String = ""              # "" / "pethouse" / "cardshop" / "pets"
var _shop_sig: String = ""               # 变化检测：换一次内容就重建
var _shop_nodes: Array = []
var _shop_stock: Array = []              # 货架上的 id 列表
var _shop_bg: TextureRect
var _shop_panel: TextureRect             # 持有面板（只有 pethouse 模式显示）
var _shop_credit: Label
var _shop_title: Label                   # 浮动条上的说明
var _shop_hint: Label                    # 底部操作提示
var _shop_base := 1.0                    # 底图缩放（每帧算，保证两块并排放得下）
var _shop_pending: String = ""          # 待确认的购买："pet:<id>" / "card:<id>"
# 顶部浮动条上「您有 N 点券」的落点（原版底图上那个深色条，量自两张底图）
const SHOP_CREDIT_RECT := {"cardshop": [84, 80, 88, 23], "pethouse": [78, 42, 100, 20]}
const SHOP_NATIVE := 256.0
const SHOP_BASE_MAX := 2.2                      # 两块并排（精灵屋）时的上限
const SHOP_BASE_MAX_ONE := 2.8                  # 单块（卡片商店）可以更大


func _build_shop() -> void:
	_shop = Control.new()
	_shop.visible = false
	_shop.mouse_filter = Control.MOUSE_FILTER_STOP
	_hud.add_child(_shop)

	_shop_panel = TextureRect.new()
	_shop_panel.texture = _tex_or_null(Rules.shop_ui_path("pethouse_panel.png"))
	_shop_panel.stretch_mode = TextureRect.STRETCH_SCALE
	_shop_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_panel.visible = false
	_shop.add_child(_shop_panel)

	_shop_bg = TextureRect.new()
	_shop_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_shop_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop.add_child(_shop_bg)

	# 顶部浮动条（原版 uitex/pethouse/浮动条.tga / other/cardshop1.tga）——放「您有 N 点券」
	_shop_credit = Label.new()
	_shop_credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_credit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_shop_credit.add_theme_color_override("font_color", Color8(255, 255, 255))
	_shop_credit.add_theme_color_override("font_outline_color", Color8(10, 40, 90))
	_shop_credit.add_theme_constant_override("outline_size", 4)
	_shop_credit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop.add_child(_shop_credit)

	_shop_hint = Label.new()
	_shop_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_hint.add_theme_color_override("font_color", Color8(255, 240, 180))
	_shop_hint.add_theme_color_override("font_outline_color", Color8(20, 20, 40))
	_shop_hint.add_theme_constant_override("outline_size", 4)
	_shop_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop.add_child(_shop_hint)

	# 底图上的按钮：关闭（原版是右键/ESC 关，这里补一个可见的「✕」）
	var close := Button.new()
	close.text = "✕"
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", maxi(12, int(round(15.0 * _ui_scale))))
	close.add_theme_color_override("font_color", Color8(255, 255, 255))
	close.add_theme_stylebox_override("normal", _sb_round(Color8(196, 70, 90),
		Color8(255, 255, 255), int(round(8.0 * _ui_scale)), 0, maxf(1.0, 2.0 * _ui_scale)))
	close.add_theme_stylebox_override("hover", _sb_round(Color8(226, 96, 116),
		Color8(255, 255, 255), int(round(8.0 * _ui_scale)), 0, maxf(1.0, 2.0 * _ui_scale)))
	close.pressed.connect(_close_shop)
	_sfx(close, true)
	_shop.add_child(close)
	_shop.set_meta("close", close)


func _tex_or_null(p: String) -> Texture2D:
	if p == "" or not ResourceLoader.exists(p):
		return null
	var r: Resource = load(p)
	return r if r is Texture2D else null


func shop_open() -> bool:
	return _shop != null and _shop.visible


func _open_shop(mode: String) -> void:
	if _shop == null:
		return
	_shop_mode = mode
	_shop_sig = ""
	_shop.visible = true
	_hide_card_menu()


## 精灵仓库（角色面板的精灵栏位点开）：列出**持有**的小神仙，点一只设为出战。
## 底图用 `uitex/pethouse/精灵屋.tga`（标题就是「小神仙」）。
func _open_pet_warehouse() -> void:
	if Net.sim == null:
		return
	var me: Dictionary = Net.sim.players.get(multiplayer.get_unique_id(), {})
	if (me.get("pets", []) as Array).is_empty():
		_toast("还没有小神仙 —— 到精灵屋请一位吧")
		return
	_shop_stock = []
	_open_shop("warehouse")


func _close_shop() -> void:
	if _shop == null:
		return
	_shop.visible = false
	_shop_mode = ""
	_shop_sig = ""


## 每帧（或在事件到达时）刷新商店内容
func _sync_shop() -> void:
	if _shop == null or not _shop.visible:
		return
	var my := multiplayer.get_unique_id()
	var me: Dictionary = (_snapshot.get("players", {}) as Dictionary).get(my, {})
	var credit := int(me.get("credit", 0))
	var owned: Array = me.get("pets", [])
	# 变化检测：点券 / 持有 / 货架 变了才重建
	var sig := "%s|%d|%s|%s" % [_shop_mode, credit, str(owned), str(_shop_stock)]
	if sig == _shop_sig:
		return
	_shop_sig = sig
	_render_shop(me, credit, owned)


func _render_shop(me: Dictionary, credit: int, owned: Array) -> void:
	for n in _shop_nodes:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_shop_nodes.clear()

	var vp := get_viewport().get_visible_rect().size
	var two := _shop_mode == "pethouse"
	# 原版**一次只显示一张面板**（老板的原版截图
	# docs/screenshots/orig/records/小神仙商店.png：屏幕上就只有「小神仙商店」一块）。
	# ⚠️ 原来我把「持有栏 + 商店」两块并排显示 —— 原版**没有**那个持有栏；
	#   已持有的小神仙改为显示在**左下角角色面板旁边**（同原版截图）。
	var cols := 1
	var fit := (vp.x * 0.94) / float(cols * SHOP_NATIVE)
	_shop_base = minf(SHOP_BASE_MAX_ONE, fit / maxf(_ui_scale, 0.001)) * _ui_scale
	# 同时别把底下的手牌条压住（原版底图 256 高，留 150 native 给 HUD）
	_shop_base = minf(_shop_base, (vp.y - 150.0 * _ui_scale) / SHOP_NATIVE)
	var side := SHOP_NATIVE * _shop_base
	var total := side * float(cols)
	var x0 := (vp.x - total) * 0.5
	var y0 := (vp.y - side) * 0.5 - 14.0 * _ui_scale

	# 只有一块底图：小神仙商店 / 卡片商店 / **精灵仓库**（三张都是原版图）
	# ⚠️ 「持有 → 选择使用哪只」的界面就是 `uitex/pethouse/精灵屋.tga`（标题「小神仙」），
	#   由**角色面板的精灵栏位**点开 —— 老板 2026-09-26：「应该是精灵的栏位，
	#   点开之后是精灵的仓库，可以选择要使用的精灵」。
	_shop_panel.visible = false
	var bg_name := "cardshop.png"
	if _shop_mode == "pethouse":
		bg_name = "pethouse_shop.png"
	elif _shop_mode == "warehouse":
		bg_name = "pethouse_panel.png"
	_shop_bg.texture = _tex_or_null(Rules.shop_ui_path(bg_name))
	_shop_bg.position = Vector2(x0, y0)
	_shop_bg.size = Vector2(side, side)

	var shop_x := _shop_bg.position.x
	var shop_y := _shop_bg.position.y

	# 顶部浮动条上的「您有 N 点券」——位置就是原版底图上那个深色条
	var cr: Array = SHOP_CREDIT_RECT["pethouse" if two else "cardshop"]
	# 顶部那条深色条：**原版只显示点券数字**（截图里就是「135」/「50」，没有文字）
	_shop_credit.text = "%d" % credit
	_shop_credit.add_theme_font_size_override("font_size",
		maxi(10, int(round(20.0 * _shop_base))))
	_shop_credit.size = Vector2(float(cr[2]) * _shop_base, float(cr[3]) * _shop_base)
	_shop_credit.position = Vector2(shop_x + float(cr[0]) * _shop_base,
		shop_y + float(cr[1]) * _shop_base)

	var slots: Variant = Rules.pet_slots("shop" if two else "cardshop")
	if slots == null:
		return

	if _shop_mode == "warehouse":
		# 精灵仓库：列出**持有**的小神仙，点一只 → 设为「出战」
		_shop_credit.visible = false          # 这张底图自带「小神仙」标题
		_place_owned_pets(shop_x, shop_y, owned)
		_shop_hint.text = "点一只小神仙设为出战 ｜ 右键 / ESC 关闭"
	elif two:
		_shop_credit.visible = true
		_shop_stock = _pet_shop_stock()
		var list: Array = slots
		for i in range(mini(list.size(), _shop_stock.size())):
			var s: Dictionary = list[i]
			_add_pet_slot(shop_x, shop_y, s, str(_shop_stock[i]), credit)
		_shop_hint.text = "%s ｜ 右键 / ESC 关闭" % Rules.info_string(202).replace("\n", "")
	else:
		_shop_credit.visible = true
		if _shop_stock.is_empty() or _shop_stock.size() != Sim.CARD_SHOP_SLOTS:
			_shop_stock = _shop_stock_for_me()
		var d: Dictionary = slots
		var arr: Array = d.get("slots", [])
		for i in range(mini(arr.size(), _shop_stock.size())):
			_add_card_slot(shop_x, shop_y, arr[i], str(_shop_stock[i]), credit)
		_shop_hint.text = "右键 / ESC 关闭"

	_shop_hint.add_theme_font_size_override("font_size", maxi(10, int(round(12.0 * _ui_scale))))
	_shop_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# 贴在面板**左上角**：放屏幕顶会跟 toast 打架，放底部会压手牌条
	_shop_hint.size = Vector2(side - 16.0 * _ui_scale, 22.0 * _ui_scale)
	_shop_hint.position = Vector2(x0 + 8.0 * _ui_scale, y0 + 4.0 * _ui_scale)

	var close: Button = _shop.get_meta("close")
	var cs := 28.0 * _ui_scale
	close.size = Vector2(cs, cs)
	close.position = Vector2(x0 + total - cs, y0 - cs * 0.6)


## 精灵屋货架：从 9 只里随机摆 4 只（原版底图正好 4 格）
func _pet_shop_stock() -> Array:
	if _shop_stock.size() == 4:
		return _shop_stock          # 同一次开店期间货架不变（免得每帧洗牌）
	var cat: Array = Net.sim.pet_catalog() if Net.sim != null else []
	if cat.is_empty():
		return []
	var ids: Array = []
	for r in cat:
		ids.append(str((r as Dictionary).get("id", "")))
	ids.shuffle()
	return ids.slice(0, 4)


func _shop_stock_for_me() -> Array:
	return Net.sim._shop_stock() if Net.sim != null else []


func _add_pet_slot(ox: float, oy: float, slot: Dictionary, pet_id: String, credit: int) -> void:
	var r: Dictionary = Net.sim.pet_record(pet_id) if Net.sim != null else {}
	if r.is_empty():
		return
	var img: Array = slot.get("img", [])
	var bar: Array = slot.get("bar", [])
	var price := int(r.get("buy_price", 0))
	var art := TextureRect.new()
	art.texture = _tex_or_null(Rules.pet_art(pet_id, "big", 1))
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.position = Vector2(ox + float(img[0]) * _shop_base, oy + float(img[1]) * _shop_base)
	art.size = Vector2(float(img[2]) * _shop_base, float(img[3]) * _shop_base)
	_shop.add_child(art)
	_shop_nodes.append(art)

	# 原版标签条 = 「名字  价格」（价格就是数字，**没有「点券」二字**）
	var txt := "%s  %d" % [str(r.get("name", pet_id)), price]
	var owned_lv := 0
	var me: Dictionary = (_snapshot.get("players", {}) as Dictionary).get(
		multiplayer.get_unique_id(), {})
	for e in me.get("pets", []):
		if str((e as Dictionary).get("id", "")) == pet_id:
			owned_lv = int((e as Dictionary).get("level", 1))
	if owned_lv > 0:
		txt = "%s  Lv%d → %d" % [str(r.get("name", pet_id)), owned_lv, price]
	_shop_nodes.append(_slot_button(ox, oy, bar, txt, credit >= price, func() -> void:
		_confirm_buy_pet(pet_id)))


## 卡片商店的槽位。
## ⚠️ **原版这里没有卡面**，就是一行文字「卡名-价格」（见
## `docs/screenshots/orig/records/卡片商店.png`：「冬眠卡-30」「汉堡卡-40」「2步卡-40」…）。
## 我们原来塞了「卡面 + 文字」，而槽位只有 95×30 native → 卡面把文字压住，
## 老板 2026-09-26 反馈「文本和价格几乎看不清」。现在改成纯文字、居中。
func _add_card_slot(ox: float, oy: float, slot: Dictionary, card_id: String, credit: int) -> void:
	var price := Net.sim.card_price(card_id) if Net.sim != null else 0
	# ⚠ 卡片商店的槽位是 {x,y,w,h} 字典（不是 [x,y,w,h] 数组）→ 转一下再交给 _slot_button
	var rect: Array = [float(slot.get("x", 0)), float(slot.get("y", 0)),
		float(slot.get("w", 0)), float(slot.get("h", 0))]
	var txt := "%s-%d" % [Rules.card_name(card_id), price]
	_shop_nodes.append(_slot_button(ox, oy, rect, txt, credit >= price, func() -> void:
		_confirm_buy_card(card_id)))


## 货架上的一格：透明按钮 + 居中文字（贴在原版底图的标签条上）
func _slot_button(ox: float, oy: float, rect: Array, text: String, afford: bool,
		cb: Callable, align: int = HORIZONTAL_ALIGNMENT_CENTER, fs: float = 0.0) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.text = text
	b.alignment = align
	b.clip_text = true
	b.add_theme_font_size_override("font_size",
		maxi(9, int(round((fs if fs > 0.0 else 13.0) * _shop_base))))   # 原版槽位里那行字约 13 native
	b.add_theme_color_override("font_color",
		Color8(40, 30, 60) if afford else Color8(150, 140, 150))
	b.add_theme_color_override("font_pressed_color", Color8(200, 60, 90))
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", _sb_round(Color8(255, 255, 255, 90),
		Color8(255, 220, 120), int(round(5.0 * _ui_scale)), 0, maxf(1.0, 2.0 * _ui_scale)))
	b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	b.position = Vector2(ox + float(rect[0]) * _shop_base, oy + float(rect[1]) * _shop_base)
	b.size = Vector2(float(rect[2]) * _shop_base, float(rect[3]) * _shop_base)
	b.disabled = not afford
	b.pressed.connect(cb)
	_shop.add_child(b)
	if afford:
		_sfx(b)
	return b


## 持有面板上的 4 格（原版「小神仙」面板底图）
func _place_owned_pets(ox: float, oy: float, owned: Array) -> void:
	var slots: Variant = Rules.pet_slots("panel")
	if slots == null:
		return
	var list: Array = slots
	# 当前「出战」的那只标个 ▶（原版：仓库里选一只使用）
	var me: Dictionary = (_snapshot.get("players", {}) as Dictionary).get(
		multiplayer.get_unique_id(), {})
	var act_id := ""
	if Net.sim != null:
		act_id = str(Net.sim.active_pet(me).get("id", ""))
	for i in range(mini(list.size(), owned.size())):
		var e: Dictionary = owned[i]
		var pid := str(e.get("id", ""))
		var lv := int(e.get("level", 1))
		var s: Dictionary = list[i]
		var img: Array = s.get("img", [])
		var bar: Array = s.get("bar", [])
		var art := TextureRect.new()
		art.texture = _tex_or_null(Rules.pet_art(pid, "face", lv))
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.position = Vector2(ox + float(img[0]) * _shop_base,
			oy + float(img[1]) * _shop_base)
		art.size = Vector2(float(img[2]) * _shop_base, float(img[3]) * _shop_base)
		_shop.add_child(art)
		_shop_nodes.append(art)
		# 等级星（uitex/pet/星01..04）
		var st := TextureRect.new()
		st.texture = _tex_or_null(Rules.pet_star(lv))
		st.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		st.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		st.position = Vector2(ox + float(img[0] + img[2] - 18) * _shop_base,
			oy + float(img[1] + 2) * _shop_base)
		st.size = Vector2(16.0 * _shop_base, 16.0 * _shop_base)
		_shop.add_child(st)
		_shop_nodes.append(st)
		var nm := ("▶ " if pid == act_id else "") + pet_label(pid, lv)
		# 仓库模式下点这一格 = 把它设为「出战」（原版「可以选择要使用的精灵」）；
		# 别的场合沿用「点一下看技能说明」
		var in_wh := _shop_mode == "warehouse"
		var cb := func() -> void:
			if in_wh:
				Net.send_action("set_pet", [pid])
			else:
				_show_pet_skill(pid, lv)
		# 槽位只有 80 native 宽 → 字号收一点，否则「小财神 Lv1」会被裁掉尾巴
		_shop_nodes.append(_slot_button(ox, oy, bar, nm, true, cb,
			HORIZONTAL_ALIGNMENT_CENTER, 10.5))


func pet_label(pet_id: String, lv: int) -> String:
	var nm := ""
	if Net.sim != null:
		nm = str(Net.sim.pet_record(pet_id).get("name", pet_id))
	return "%s Lv%d" % [nm, lv]


func _show_pet_skill(pet_id: String, lv: int) -> void:
	if Net.sim == null:
		return
	var r: Dictionary = Net.sim.pet_record(pet_id)
	_toast("%s：%s（%.0f 秒 / %d 点券）" % [str(r.get("name", pet_id)),
		str(r.get("skill_raw", "")), Net.sim.pet_seconds(pet_id, lv),
		Net.sim.pet_cost(pet_id, lv)])


## 二次确认（Info.txt 203 / 卡片商店）——复用落点气泡那套原版「是│否」
func _confirm_buy_pet(pet_id: String) -> void:
	if Net.sim == null:
		return
	var r: Dictionary = Net.sim.pet_record(pet_id)
	var price := int(r.get("buy_price", 0))
	_card_confirm_id = ""             # 走 _shop_pending 这条线
	_shop_pending = "pet:" + pet_id
	_pop_mode = "shop"
	_btn_bldtype.visible = false
	_pop_text.text = Rules.info_fill(203,
		{"babyname": str(r.get("name", pet_id)), "number": str(price)},
		"%s 价格 %d 点券\n确认要购买吗？" % [str(r.get("name", pet_id)), price])
	_pop.visible = true


func _confirm_buy_card(card_id: String) -> void:
	if Net.sim == null:
		return
	var price := Net.sim.card_price(card_id)
	_shop_pending = "card:" + card_id
	_pop_mode = "shop"
	_btn_bldtype.visible = false
	_pop_text.text = "%s\n%d 点券\n确认要购买吗？" % [Rules.card_name(card_id), price]
	_pop.visible = true


## 一次性提示条（原版没有；用于「未实现」这类诚实告知，1.6 秒自动消失）
func _build_toast() -> void:
	_toast_lbl = Label.new()
	_toast_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast_lbl.offset_top = UI_BAR_H * _ui_scale + 8.0 * _ui_scale
	_toast_lbl.offset_bottom = _toast_lbl.offset_top + 20.0 * _ui_scale
	_toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_lbl.add_theme_font_size_override("font_size", maxi(10, int(round(13.0 * _ui_scale))))
	_toast_lbl.add_theme_color_override("font_color", Color8(255, 240, 180))
	_toast_lbl.add_theme_color_override("font_outline_color", Color8(20, 20, 40))
	_toast_lbl.add_theme_constant_override("outline_size", 4)
	_toast_lbl.visible = false
	_toast_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_toast_lbl)


## 取一条 Info.txt 消息并填占位符（换行压成空格，适配 toast 单行）
func _info_disp(id: int, fallback: String, keys: Dictionary = {}) -> String:
	return Rules.info_fill(id, keys, fallback).replace("\n", " ")


func _toast(msg: String) -> void:
	if _toast_lbl == null:
		return
	_toast_lbl.text = msg
	_toast_lbl.visible = true
	_toast_t = 1.6


func _toggle_sfx() -> void:
	## 原版图标条里的「话筒」= 音效开关
	var bus := AudioServer.get_bus_index("Master")
	var muted := AudioServer.is_bus_mute(bus)
	AudioServer.set_bus_mute(bus, not muted)
	_toast("音效已%s" % ("关闭" if not muted else "开启"))


## --------------------------------------------------------------- 动作 UI 跟随
## 两个动作入口走**不同**的定位规则（依原版实机截图）：
##   · GO 圆钮（掷骰子）= **固定屏幕位**（GO_ANCHOR_NORM）。原版四张实机截图里
##     它纹丝不动地停在右下区，角色站位不同也不影响 → 它不是贴角色头的。
##   · 落点气泡（买地 / 升级 / 放弃）= 贴**角色头顶**（这是「你脚下这格」的询问，
##     必须指着手里的这格，跟着角色走才对）。
func _sync_action_ui() -> void:
	if _go_btn == null or _pop == null or _board == null or screen != Screen.GAME:
		return
	var my_id := multiplayer.get_unique_id()
	var wp: Variant = _board.player_pos(my_id)
	var cam := get_viewport().get_camera_3d()
	if wp == null or cam == null:
		_go_btn.visible = false
		_pop.visible = false
		return
	var sp: Vector2 = cam.unproject_position((wp as Vector3) + Vector3.UP * UI_HEAD_UP)

	var pad := 4.0 * _ui_scale
	if _go_btn.visible:
		# 锚的是**圆钮中心**（老板标注的那个方块中心）
		var anchor: Vector2 = get_viewport().get_visible_rect().size * GO_ANCHOR_NORM
		_go_btn.position = anchor - _go_btn.size * 0.5
	if _pop.visible:
		if _pop_mode == "shop" and _shop != null and _shop.visible:
			# 商店购买确认：**屏幕居中**（模态对话框该在的位置）。
			# ❌ 原来一律贴角色头顶 —— 商店面板在屏幕中间、角色在别处，确认框会落到
			#    面板边缘甚至被压住，很难点（老板 2026-09-26 反馈）。
			# ❌ 也别贴面板下缘：面板几乎占满屏高，下方就是手牌条。
			var vp := get_viewport().get_visible_rect()
			_pop.position = Vector2(
				vp.position.x + (vp.size.x - _pop.size.x) * 0.5,
				vp.position.y + vp.size.y * 0.56 - _pop.size.y * 0.5)
		else:
			_pop.position = sp - Vector2(_pop.size.x * 0.5, _pop.size.y + pad)

	# 骰子数量选择器贴着 GO 圆钮的左边缘竖排（原版实机 08_牌桌_2.png 的位置）
	var gp := _go_btn.position
	var ds := DIE_SEL_SIZE * _ui_scale
	for i in range(_dice_sel.size()):
		var d: TextureRect = _dice_sel[i]
		var hb: Button = _dice_hit[i]
		var show := _go_btn.visible
		d.visible = show
		hb.visible = show
		if not show:
			continue
		var p := gp + Vector2(DIE_SEL_DX, DIE_SEL_DY + i * DIE_SEL_STEP) * _ui_scale
		d.size = Vector2(ds, ds)
		d.pivot_offset = d.size * 0.5
		d.position = p
		hb.position = p - Vector2(3, 3) * _ui_scale
		hb.size = Vector2(ds + 6.0 * _ui_scale, ds + 6.0 * _ui_scale)


func _sfx(b: BaseButton, confirm: bool = false) -> void:
	## 接上原版界面音效。音效 1 = 按钮点击、音效 2 = 确认/进入 —— 两个 id 都由
	## 标记音替换法实测确认（docs/sfx-map.md §7.1，各 2~3 次精确命中）。
	b.pressed.connect(func() -> void:
		Audio.play_sfx(Audio.SFX_UI_CONFIRM if confirm else Audio.SFX_UI_CLICK))


func _sb(bg: Color, border: Color, radius: int, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s


func _gap(w: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 0)
	return c


func _toggle_log() -> void:
	if _log_panel != null:
		_log_panel.visible = not _log_panel.visible


## ⑤ 聊天栏 —— **额外**弹出，**不占用**右下角功能区的小面板
## （老板原版截图里它就在小面板上方，带频道/私聊头像 + 输入框 + Send）。
func _toggle_chat_bar() -> void:
	if _chat_bar == null:
		_build_chat_bar()
	if _chat_bar == null:
		return
	_chat_bar.visible = not _chat_bar.visible
	if _chat_bar.visible:
		_sync_chat_bar()


func _build_chat_bar() -> void:
	_chat_bar = PanelContainer.new()
	_chat_bar.visible = false
	_chat_bar.z_index = 30
	_chat_bar.add_theme_stylebox_override("panel", _sb_round(
		Color8(18, 38, 92, 240), Color8(120, 190, 250), int(round(6.0 * _ui_scale)),
		maxi(2, int(round(3.0 * _ui_scale))), maxf(1.5, 2.0 * _ui_scale)))
	_hud.add_child(_chat_bar)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", maxi(1, int(round(3.0 * _ui_scale))))
	_chat_bar.add_child(vb)

	# 顶部一行：[公共/私聊] 切频道 · 输入框 · Send
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", maxi(2, int(round(4.0 * _ui_scale))))
	vb.add_child(hb)
	_chat_ch = Button.new()
	_chat_ch.focus_mode = Control.FOCUS_NONE
	_chat_ch.custom_minimum_size = Vector2(46.0 * _ui_scale, 20.0 * _ui_scale)
	_chat_ch.add_theme_font_size_override("font_size", maxi(9, int(round(11.0 * _ui_scale))))
	_chat_ch.pressed.connect(func(): _chat_cycle_channel())
	hb.add_child(_chat_ch)
	_chat_input = LineEdit.new()
	_chat_input.custom_minimum_size = Vector2(150.0 * _ui_scale, 20.0 * _ui_scale)
	_chat_input.placeholder_text = "说点什么…"
	_chat_input.add_theme_font_size_override("font_size", maxi(9, int(round(11.0 * _ui_scale))))
	_chat_input.text_submitted.connect(func(_t: String): _chat_send())
	hb.add_child(_chat_input)
	var sb := Button.new()
	sb.text = "Send"
	sb.focus_mode = Control.FOCUS_NONE
	sb.custom_minimum_size = Vector2(52.0 * _ui_scale, 20.0 * _ui_scale)
	sb.add_theme_font_size_override("font_size", maxi(9, int(round(11.0 * _ui_scale))))
	sb.add_theme_color_override("font_color", Color8(230, 245, 255))
	sb.add_theme_stylebox_override("normal", _sb_round(Color8(60, 110, 200),
		Color8(150, 210, 255), int(round(6.0 * _ui_scale)),
		maxi(1, int(round(2.0 * _ui_scale))), 0.0))
	sb.pressed.connect(func(): _chat_send())
	hb.add_child(sb)

	# 下面几行聊天记录
	vb.add_child(_chat_view_box())
	_chat_channels = ["公共"]
	var me: Dictionary = _snapshot.get("players", {}).get(multiplayer.get_unique_id(), {})
	for pid in _snapshot.get("players", {}).keys():
		if int(pid) != multiplayer.get_unique_id():
			var nm := str((_snapshot["players"][pid] as Dictionary).get("name", str(pid)))
			_chat_channels.append("私聊:" + nm)
	_chat_cycle_channel()


func _chat_view_box() -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(250.0 * _ui_scale, 52.0 * _ui_scale)
	p.add_theme_stylebox_override("panel", _sb_round(Color8(10, 22, 60, 220),
		Color8(70, 120, 200), int(round(4.0 * _ui_scale)),
		maxi(1, int(round(2.0 * _ui_scale))), 0.0))
	_chat_log = Label.new()
	_chat_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chat_log.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_chat_log.add_theme_font_size_override("font_size", maxi(9, int(round(11.0 * _ui_scale))))
	_chat_log.add_theme_color_override("font_color", Color8(226, 240, 255))
	_chat_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(_chat_log)
	return p


func _chat_cycle_channel() -> void:
	if _chat_channels.is_empty():
		_chat_channels = ["公共"]
	_chat_ch_idx = (_chat_ch_idx + 1) % _chat_channels.size()
	_chat_ch.text = str(_chat_channels[_chat_ch_idx])


func _chat_send() -> void:
	if _chat_input == null:
		return
	var txt := _chat_input.text.strip_edges()
	if txt == "":
		return
	_chat_input.text = ""
	var ch := str(_chat_channels[_chat_ch_idx]) if _chat_ch_idx < _chat_channels.size() \
		else "公共"
	var to := -1
	if ch.begins_with("私聊:"):
		var who := ch.substr(3)
		for pid in _snapshot.get("players", {}).keys():
			if str((_snapshot["players"][pid] as Dictionary).get("name", "")) == who:
				to = int(pid)
				break
	Net.send_action("chat", [txt, to, ch])


func _sync_chat_bar() -> void:
	if _chat_bar == null:
		return
	var vp := get_viewport().get_visible_rect()
	var sz := _chat_bar.get_combined_minimum_size()
	# 贴在右下角功能区的**正上方**（原版截图里聊天栏就在小面板上面）
	var bw := (UI_BR_W + UI_BR_MARGIN) * _ui_scale
	var by := (UI_BR_MAP_H + UI_BR_BAR_H + UI_BR_GAP + UI_BR_MARGIN) * _ui_scale
	_chat_bar.position = Vector2(vp.size.x - bw, vp.size.y - by - sz.y - 2.0 * _ui_scale)
	_chat_bar.size = Vector2(maxf(sz.x, bw), sz.y)


## 往聊天记录里追加一行
func _chat_append(who: String, text: String) -> void:
	_chat_lines.append("%s: %s" % [who, text])
	if _chat_lines.size() > 50:
		_chat_lines = _chat_lines.slice(_chat_lines.size() - 50)
	if _chat_log != null:
		_chat_log.text = "\n".join(_chat_lines.slice(maxi(0, _chat_lines.size() - 3)))


## 拉霸面板的按钮回调（下注 / 拉杆 / 离开）
func _on_casino_action(kind: String, amount: int) -> void:
	match kind:
		"bet":
			Net.send_action("casino_bet", [amount])
		"pull":
			Net.send_action("casino_pull", [])
		"exit":
			if _casino != null:
				_casino.close()


## 全局新闻的全屏插画（`assets/news/01..37.png` = 原版 `samples/news/*.tga`）
func _show_global_news(idx: int, text: String, art: int) -> void:
	if _news_pop == null:
		_build_news_popup()
	var n := ((maxi(art, 1) - 1) % 37) + 1        # 37 张插画，按事件序号取（无力据，见 alignment-gap）
	_news_art.texture = _tex_or_null("res://assets/news/%02d.png" % n)
	_news_text.text = text.replace("\n", " ")
	_news_pop.visible = true
	_news_left = 4.0
	var vp := get_viewport().get_visible_rect()
	var w := minf(vp.size.x * 0.42, 430.0 * _ui_scale)
	var h := minf(vp.size.y * 0.62, 430.0 * _ui_scale)
	_news_pop.size = Vector2(w, h)
	_news_pop.position = Vector2((vp.size.x - w) * 0.5, (vp.size.y - h) * 0.5)


func _build_news_popup() -> void:
	_news_pop = Control.new()
	_news_pop.visible = false
	_news_pop.z_index = 80
	_news_pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_news_pop)
	var pc := PanelContainer.new()
	pc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pc.add_theme_stylebox_override("panel", _sb_round(
		Color8(246, 250, 226, 248), Color8(150, 190, 60), int(round(10.0 * _ui_scale)),
		maxi(3, int(round(6.0 * _ui_scale))), maxf(2.0, 3.0 * _ui_scale)))
	_news_pop.add_child(pc)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", maxi(3, int(round(8.0 * _ui_scale))))
	pc.add_child(col)
	_news_art = TextureRect.new()
	_news_art.custom_minimum_size = Vector2(230.0 * _ui_scale, 230.0 * _ui_scale)
	_news_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_news_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_news_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_news_art)
	_news_text = Label.new()
	_news_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_news_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_news_text.add_theme_font_size_override("font_size", maxi(11, int(round(17.0 * _ui_scale))))
	_news_text.add_theme_color_override("font_color", Color8(40, 60, 20))
	_news_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_news_text)


func _toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

# ------------------------------------------------------------- 界面切换

func _show(s: int) -> void:
	screen = s
	_menu_root.visible = (s == Screen.MENU)
	_lobby_root.visible = (s == Screen.LOBBY)
	_hud.visible = (s == Screen.GAME)
	_board.visible = (s == Screen.GAME)
	# 音频随界面走：菜单/大厅 = 实测的主菜单曲 m01001；对局曲按地图选，在 _on_game_started 里起
	if s == Screen.MENU or s == Screen.LOBBY:
		Audio.stop_ambient()
		Audio.play_bgm_playlist(Audio.BGM_MENU)

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
	if _minimap != null:
		_minimap.setup(_board.map)
	_show(Screen.GAME)
	_sim_connected = false
	_connect_sim()
	Audio.play_bgm_playlist(Audio.map_bgm(map_name))
	Audio.start_ambient()
	_on_log("对局开始 · 地图：%s · %d 格" % [_board.map.display_name, _board.map.tile_count()])
	_on_log("实时制：1 天 = %.0f 秒，静止 %.0f 秒会睡着" % [
		Rules.seconds_per_day(), Sim.IDLE_SLEEP_SECONDS])
	_on_log("操作：空格掷骰 · Q/E 转视角 · R/F 调俯角 · 滚轮缩放 · Tab 全盘 · L 收起日志")


# ------------------------------------------------------------ 音频接线

func _connect_sim() -> void:
	## 本局的 Sim 一旦就绪就把语义事件接到音频层（Sim 本身不含任何音频代码）
	if _sim_connected or Net.sim == null:
		return
	if not Net.sim.game_event.is_connected(_on_game_event):
		Net.sim.game_event.connect(_on_game_event)
	_sim_connected = true


func _say(role: int, key: String, pos: Variant) -> void:
	if pos == null:
		Audio.say(role, key)
	else:
		Audio.say_at(role, key, pos)


## 结算画面（006 胜利 / 007 失败）是**全桌共见**的结果 → 不受「2D 只给当事人」限制
const SFX_GLOBAL_IDS := [6, 7]


func _ev_sfx(id: int, data: Dictionary, _pos: Variant) -> void:
	## 事件音效派发。规则来自原版自己的分类表 `sound/effect/sndeffect.txt`
	## （已解析进 assets/audio/voice_map.json 的 effects[].kind）：
	##
	##   · **2D = 界面音**（按钮 / 掷骰 / 金币掉在「桌子上」…）→ 是**本机操作的听觉反馈**，
	##     只有「这件事的当事人」听得到。老板 2026-09-26 反馈的核心 bug 就在这：
	##     我们此前把 023 骰子滚动声无条件播了，于是电脑玩家掷骰子也吵到自己。
	##   · **3D = 场景空间音**（地产升级、爆炸、金币散落…）→ 场景里真的发生了，人人可听。
	##
	## 例外：SFX_GLOBAL_IDS 里的 2D 结算音全员可听。
	##
	## ⚠ 3D 音这里仍走**非定位**播放（与今天之前一致）—— 改成 Audio.play_sfx_at 会让
	## 远处声音直接听不见：棋盘跨度 200 世界单位、相机离角色 300~400 单位，而
	## play_sfx_at 写死 unit_size=12 / max_distance=120（超出即静音）。要做空间音必须
	## 先把这两个参数调到 ≈200 / ≈2000，属未做的后续项，登记在 docs/ui-audit.md。
	var mine: bool = (not data.has("pid")) or int(data["pid"]) == multiplayer.get_unique_id()
	if Audio.effect_kind(id) == "2D" and not SFX_GLOBAL_IDS.has(id):
		if not mine:
			return
		Audio.play_sfx(id)
		return
	Audio.play_sfx(id)


func _on_game_event(kind: String, data: Dictionary) -> void:
	## 语义事件 → 音效 / 角色对白（对白语义键见 docs/sfx-map.md §2.3，
	## 音效 id 见 game/data/rules/sfx.json）
	var role := int(data.get("role", 1))
	var pos: Variant = null
	if _board != null and data.has("pid"):
		pos = _board.player_pos(int(data["pid"]))
	var effect := str(data.get("effect", ""))
	match kind:
		"roll":
			_ev_sfx(Audio.SFX_DICE_ROLL, data, pos)      # 23 骰子滚动声（2D → 只有掷的人听得到）
			# 掷骰是**自己的**才播「骰子飞出 → 定格点数」动画（自己才看得见自己的 GO 钮）
			if int(data.get("pid", -1)) == multiplayer.get_unique_id():
				_start_dice_fly(data.get("faces", []))
		"roll_end":
			_ev_sfx(Audio.SFX_DICE_STOP, data, pos)      # 5 骰子滚动结束
		"buy":
			_ev_sfx(Audio.SFX_COIN_DROP, data, pos)      # 50 金币掉落在桌子上
			_say(role, Audio.V_SELFISH, pos)
		"upgrade", "rebuild":
			_ev_sfx(Audio.SFX_BUILD_UPGRADE, data, pos)  # 12 地产升级
			_say(role, Audio.V_SELFISH, pos)
		"pay_rent":
			_ev_sfx(Audio.SFX_BANK_SETTLE, data, pos)    # 52 银行结账
			_say(role, Audio.V_LIGHT_PUNISH, pos)
		"casino":
			_ev_sfx(Audio.SFX_PAY_DEDUCT, data, pos)     # 40 负面技能扣款
			_say(role, Audio.V_LIGHT_PUNISH, pos)
		"credit":
			_ev_sfx(Audio.SFX_COIN_SCATTER, data, pos)   # 15 金币散落
			_say(role, Audio.V_GET_MONEY, pos)
		"news":
			_ev_sfx(Audio.SFX_COIN_SCATTER, data, pos)
			_say(role, Audio.V_LUCKY, pos)
		"win_money":
			_ev_sfx(Audio.SFX_COIN_DROP, data, pos)
			_say(role, Audio.V_GET_MONEY, pos)
		"lose_money":
			_ev_sfx(Audio.SFX_PAY_DEDUCT, data, pos)
			_say(role, Audio.V_LIGHT_PUNISH, pos)
		"get_pet":
			_ev_sfx(Audio.SFX_UI_CONFIRM, data, pos)
			_say(role, Audio.V_GREET, pos)
		"platform":
			_ev_sfx(Audio.SFX_UI_CONFIRM, data, pos)
		"no_stamina":
			# 体力不够，出发被拒（原版「自己走所需要最小体力值」）
			_ev_sfx(Audio.SFX_ACTION_DENIED, data, pos)
		"win":
			_ev_sfx(Audio.SFX_WIN_SCREEN, data, pos)     # 6 胜利结算画面（全局例外）
			_say(role, Audio.V_WIN, pos)
		"bankrupt":
			_ev_sfx(Audio.SFX_LOSE_SCREEN, data, pos)    # 7 失败结算（全局例外）
			_say(role, Audio.V_BANKRUPT, pos)
		"insufficient_money", "need_house_type", "upgrade_blocked":
			_ev_sfx(Audio.SFX_ACTION_DENIED, data, pos)  # 19 禁止操作的音效
			if kind == "upgrade_blocked":
				_say(role, Audio.V_LIGHT_PUNISH, pos)    # 衰神附身：投资失败（id 1053）
		"use_card", "get_card":
			match effect:
				"upgrade_building":
					_ev_sfx(Audio.SFX_CARD_UPGRADE, data, pos)   # 24 升级卡·全街升级
				"auto_upgrade":
					_ev_sfx(Audio.SFX_PET_UPGRADE, data, pos)    # 9 小神仙的地产升级技能
				_:
					_ev_sfx(Audio.SFX_UI_CONFIRM, data, pos)
			_say(role, Audio.V_SELFISH, pos)
			if kind == "get_card":
				_toast("得到卡片「%s」" % str(data.get("name", "")))
		"discard_card":
			_ev_sfx(Audio.SFX_UI_CLICK, data, pos)
		"card_unavailable":
			_ev_sfx(Audio.SFX_ACTION_DENIED, data, pos)
			# 原因文案用原版 String.txt 的「不能用卡片N」（61..70）逐条对上
			_toast("「%s」用不了：%s" % [str(data.get("name", "")),
				Rules.ui_string(int(data.get("code", 61)), "条件不满足")])
		"need_card_target":
			# 需要点选对手（String.txt 1101）—— 点卡片后其实已进选目标模式，这里兜底
			if int(data.get("pid", -1)) == multiplayer.get_unique_id():
				_set_card_target_mode(str(data.get("card", "")))
		"card_choose_steps":
			# 骰子卡：弹 1..6 步数选择器
			if int(data.get("pid", -1)) == multiplayer.get_unique_id():
				_show_step_picker()
		# ---- 两家商店（点券的出口）----
		"pethouse_open":
			if int(data.get("pid", -1)) == multiplayer.get_unique_id():
				_shop_stock = []
				_open_shop("pethouse")
				_toast(_info_disp(201, "精灵屋\n请选购小神仙"))
		"cardshop_open":
			if int(data.get("pid", -1)) == multiplayer.get_unique_id():
				_shop_stock = _shop_stock_for_me()
				_open_shop("cardshop")
				_toast(_info_disp(41, "卡片商店", {"number": str(int(data.get("credit", 0)))}))
		"buy_pet":
			_ev_sfx(Audio.SFX_UI_CONFIRM, data, pos)
			if int(data.get("pid", -1)) == multiplayer.get_unique_id():
				_show_pet_skill(str(data.get("pet", "")), 1)
		"buy_card":
			_ev_sfx(Audio.SFX_UI_CONFIRM, data, pos)
			_toast("买下「%s」（%d 点券）" % [str(data.get("name", "")), int(data.get("price", 0))])
		"pet_full":
			_ev_sfx(Audio.SFX_ACTION_DENIED, data, pos)
			if int(data.get("pid", -1)) == multiplayer.get_unique_id():
				_toast(_info_disp(202, "您已拥有5位小神仙，\n此时不能请神！"))
		"pet_shop_refused", "cardshop_refused":
			_ev_sfx(Audio.SFX_ACTION_DENIED, data, pos)
			if int(data.get("pid", -1)) == multiplayer.get_unique_id():
				_toast(_info_disp(42 if kind == "cardshop_refused" else 42,
					"您没有点券\n不能进入卡片商店"))
		"pet_skill":
			_ev_sfx(Audio.SFX_UI_CONFIRM, data, pos)
			if int(data.get("pid", -1)) == multiplayer.get_unique_id():
				_toast("%s：%s" % [str(data.get("name", "")), str(data.get("skill", ""))])
		"pet_levelup":
			_ev_sfx(Audio.SFX_PET_UPGRADE, data, pos)
		"pet_curse", "pet_attacked", "steal_pet":
			_ev_sfx(Audio.SFX_ACTION_DENIED, data, pos)
		"pet_dice":
			_ev_sfx(Audio.SFX_DICE_STOP, data, pos)
		"mine":
			_ev_sfx(Audio.SFX_PAY_DEDUCT, data, pos)
			_say(role, Audio.V_LIGHT_PUNISH, pos)
		# ---- 路边物体（原版 roadobj）—— 文案取 config/Info.txt 71..78 ----
		"road_crystal":
			_ev_sfx(Audio.SFX_UI_CONFIRM, data, pos)
			if bool(data.get("leveled", false)):
				_toast(_info_disp(78, "得到魔戒 小神仙等级上升！"))
			else:
				_toast(_info_disp(71, "得到魔戒 什么也没发生"))
		"road_hanbao":
			_ev_sfx(Audio.SFX_UI_CONFIRM, data, pos)
			_toast(_info_disp(74, "吃到汉堡 体力上升"))
		"road_chest":
			_ev_sfx(Audio.SFX_COIN_DROP, data, pos)
			_toast(_info_disp(72, "强盗遗失宝箱 获得{NUMBER}元",
				{"NUMBER": str(int(data.get("gain", 0)))}))
		"road_bomb":
			_ev_sfx(Audio.SFX_PAY_DEDUCT, data, pos)
			_toast(_info_disp(76, "遇到炸弹鬼 体力受损"))
		"road_thief":
			_ev_sfx(Audio.SFX_PAY_DEDUCT, data, pos)
			_toast(_info_disp(77, "遇到小偷 遗失{NUMBER}元",
				{"NUMBER": str(int(data.get("loss", 0)))}))
		"road_god":
			_ev_sfx(Audio.SFX_ACTION_DENIED, data, pos)
			_toast(_info_disp(0, "%s附身" % str(data.get("god_cn", ""))))
		# ---- 股票 / 公司 ----
		"stock_buy":
			_ev_sfx(Audio.SFX_COIN_DROP, data, pos)
			_toast("买进 %s %d 股（%d 元）" % [str(data.get("company", "")),
				int(data.get("shares", 0)), int(data.get("cost", 0))])
		"stock_sell":
			_ev_sfx(Audio.SFX_COIN_SCATTER, data, pos)
			_toast("卖出 %s %d 股（得 %d 元）" % [str(data.get("company", "")),
				int(data.get("shares", 0)), int(data.get("gain", 0))])
		"stock_shift":
			_ev_sfx(Audio.SFX_UI_CONFIRM, data, pos)
			_toast("%s 股价 %.1f → %.1f（%+.0f%%）" % [str(data.get("company", "")),
				float(data.get("from", 0.0)), float(data.get("to", 0.0)),
				float(data.get("ratio", 0.0)) * 100.0])
		"push_away":
			# 被挤：对方占了你的格子，把你挤到下一格（可能因此付房租）
			if int(data.get("pid", -1)) == multiplayer.get_unique_id():
				_ev_sfx(Audio.SFX_ACTION_DENIED, data, pos)
				_toast("你被 %s 挤到了下一格" % str(data.get("name", "")))
		"chat":
			_chat_append(str(data.get("name", "")), str(data.get("text", "")))
		"global_news":
			_ev_sfx(Audio.SFX_UI_CONFIRM, data, pos)
			_show_global_news(int(data.get("idx", 1)), str(data.get("text", "")),
				int(data.get("art", 1)))
		"casino_open":
			# 走到「拉霸」格 → 打开老虎机面板（自己下注）
			if int(data.get("pid", -1)) == multiplayer.get_unique_id() and _casino != null:
				_casino.open()
		"casino_bet":
			_ev_sfx(Audio.SFX_UI_CLICK, data, pos)
			if int(data.get("pid", -1)) == multiplayer.get_unique_id():
				_toast("加注 %d（本局共 %d）" % [int(data.get("amount", 0)),
					int(data.get("bet", 0))])
		"casino_result":
			_ev_sfx(Audio.SFX_COIN_DROP if int(data.get("win", 0)) > 0
				else Audio.SFX_ACTION_DENIED, data, pos)
			if int(data.get("pid", -1)) == multiplayer.get_unique_id():
				_toast("拉霸结果：%s" % ("赢 %d 元" % int(data.get("win", 0))
					if int(data.get("win", 0)) > 0 else "没中"))
		"casino_need_bet":
			_ev_sfx(Audio.SFX_ACTION_DENIED, data, pos)
			if int(data.get("pid", -1)) == multiplayer.get_unique_id():
				_toast("请先投注")
		"chairman":
			_ev_sfx(Audio.SFX_UI_CONFIRM, data, pos)
			if int(data.get("pid", -1)) == multiplayer.get_unique_id():
				_toast(("你成为 %s 公司董事长" % str(data.get("company", "")))
					if bool(data.get("on", false))
					else "持股低于 60%%，不再担任 %s 公司董事长" % str(data.get("company", "")))
		"stock_no_holding":
			_ev_sfx(Audio.SFX_ACTION_DENIED, data, pos)
			if int(data.get("pid", -1)) == multiplayer.get_unique_id():
				_toast("你没有 %s 的股票" % str(data.get("company", "")))
		"roadblock":
			_ev_sfx(Audio.SFX_ACTION_DENIED, data, pos)
		"blast":
			_ev_sfx(Audio.SFX_PAY_DEDUCT, data, pos)
			_say(role, Audio.V_ATTACK, pos)
		"estate_index":
			_ev_sfx(Audio.SFX_UI_CONFIRM, data, pos)
		"seal":
			_ev_sfx(Audio.SFX_UI_CONFIRM, data, pos)
		"own_plot":
			_ev_sfx(Audio.SFX_UI_CONFIRM, data, pos)
		"sealed_rent":
			_toast("该街道查封中，免收过路费")
		"downgrade":
			_say(role, Audio.V_ATTACK, pos)
		"arrive_own":
			# 衰神附身中回到自己土地 —— 原版这里会播「衰神附身 投资失败」
			if bool(data.get("blocked", false)):
				_say(role, Audio.V_LIGHT_PUNISH, pos)
		"free_rent":
			_say(role, Audio.V_FREE_RENT, pos)
		"hospital":
			_say(role, Audio.V_HOSPITAL, pos)
		"sleep":
			_say(role, Audio.V_SLEEP, pos)
		"meet":
			_say(role, Audio.V_GREET, pos)
		_:
			pass

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
	var ids := players.keys()
	ids.sort()

	# ---- 顶栏（5 个计数项 + x/y，版式见 docs/ui-audit.md）----
	var me: Dictionary = players.get(my_id, {})
	var day := int(float(snap.get("t", 0.0)) / maxf(Rules.seconds_per_day(), 0.001)) + 1
	_hud_day.set_text("%d/1" % day)     # ⚠️ 原版 x/y 的确切语义未考证，暂用「第 N 天 / 1」占位
	if not me.is_empty():
		_hud_money.set_text(_comma(int(me["money"])))
		_hud_deposit.set_text("0")      # ⚠️ 存款系统未实现 → 占位
		var mine := 0
		for k in plots.keys():
			if int(plots[k]["owner"]) == my_id:
				mine += 1
		_hud_houses.set_text(str(mine))
		var cards: Array = me.get("cards", [])
		_hud_cards.set_text(str(cards.size()))
		_hud_credit.set_text(str(int(me.get("credit", 0))))   # 点券（事件格 5/10/20/30/50 加）

	# ---- 右侧：玩家头像列（原版 = 贴右边缘的竖排圆头像）----
	_sync_avatar_column(ids, players, my_id)

	# ---- 左下：角色面板 ----
	if not me.is_empty():
		_sync_char_panel(me, players, plots, ids, my_id)
		_sync_action_entry(me, plots, my_id)
		_sync_card_hand(me)
		# （原 `_sync_pet_strip(me)` —— 右侧那排小头像已去掉）
		if _stock != null:
			_stock._sync(0.0, str(int(me.get("id", 0))))
		# 右下角功能区：地图页 / 股票页互斥 + 聊天栏贴在其上方
		_sync_br_pages()
		if _chat_bar != null and _chat_bar.visible:
			_sync_chat_bar()
		_sync_shop()
		# 骰子卡的步数选择器只在「待选步数」时出现
		if _step_picker != null:
			_step_picker.visible = bool(me.get("pending_steps", false))

	# ---- 右下：小地图 ----
	if _minimap != null:
		_minimap.update_state(snap, my_id)


## 右侧头像列：每个玩家一个「头特写」圆图（原版 uitex/player/roleN_21.png）。
## 轮到谁，谁的框亮一圈 —— 原版也是用亮边圈住当前行动者。
func _sync_avatar_column(ids: Array, players: Dictionary, my_id: int) -> void:
	if _avatar_col == null:
		return
	var shown: Array = ids.slice(0, UI_AVA_MAX)
	while _avatar_rows.size() < shown.size():
		var box := PanelContainer.new()
		box.custom_minimum_size = Vector2(UI_AVA_W, UI_AVA_H) * _ui_scale
		box.add_theme_stylebox_override("panel",
			_sb_round(Color(0, 0, 0, 0), Color(0, 0, 0, 0),
				int(round(6.0 * _ui_scale)), 0, 0.0))
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var t := TextureRect.new()
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(t)
		# 透明点击区（只在「请选择对手」模式下启用 —— 见 _set_card_target_mode）
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", _sb_round(Color8(255, 246, 120, 90),
			Color8(255, 246, 120), int(round(6.0 * _ui_scale)), 0, maxf(1.0, 2.0 * _ui_scale)))
		b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		b.disabled = true
		b.pressed.connect(func(): _on_avatar_clicked(int(b.get_meta("pid", -1))))
		box.add_child(b)
		_avatar_col.add_child(box)
		_avatar_rows.append({"box": box, "img": t, "btn": b})

	var act := _active_player_id(players)
	for i in _avatar_rows.size():
		var row: Dictionary = _avatar_rows[i]
		var box: PanelContainer = row["box"]
		var img: TextureRect = row["img"]
		var ab: Button = row["btn"]
		if i >= shown.size():
			box.visible = false
			continue
		var id := int(shown[i])
		var p: Dictionary = players[id]
		box.visible = true
		img.texture = _role_texture(int(p.get("role", i + 1)) - 1, "21")
		img.modulate = Color(1, 1, 1, 1) if bool(p["alive"]) else Color(0.5, 0.5, 0.55, 0.7)
		# 「请选择对手」模式：除自己外都能点（String.txt 1101）
		var selectable := _card_pending != "" and id != my_id and bool(p["alive"])
		ab.set_meta("pid", id)
		ab.disabled = not selectable
		ab.mouse_filter = Control.MOUSE_FILTER_STOP if selectable else Control.MOUSE_FILTER_IGNORE
		var mine := int(id) == my_id
		var turn := int(id) == act
		var col := Color8(255, 246, 120) if turn else Color(0, 0, 0, 0)
		if turn and not mine:
			col = Color8(160, 235, 255)
		if selectable:
			col = Color8(255, 120, 160)          # 选目标时全体高亮成粉红
		box.add_theme_stylebox_override("panel",
			_sb_round(Color(0, 0, 0, 0), col, int(round(6.0 * _ui_scale)),
				maxi(0, int(round(1.0 * _ui_scale))), maxf(1.0, 2.0 * _ui_scale)))


## 「现在该看谁的头上」——原版是即时制，没有回合，所以按优先级挑：
##   ① 手上有未处理的「本次抵达机会」的人（买/升级提示气泡正飘在他头上）
##   ② 正在移动的人
##   ③ 都没有 → -1（不圈任何人）
func _active_player_id(players: Dictionary) -> int:
	for id in players:
		if str(players[id].get("last_plot_kind", "")) != "":
			return int(id)
	for id in players:
		if int(players[id].get("moving", 0)) != 0:
			return int(id)
	return -1


## 左下角色面板内容（版式见 _build_character_panel 的注释）
func _sync_char_panel(me: Dictionary, players: Dictionary, plots: Dictionary,
		ids: Array, my_id: int) -> void:
	var rank := 1
	for id in ids:
		if int(players[int(id)]["money"]) > int(me["money"]):
			rank += 1
	_char_avatar.texture = _role_texture(int(me.get("role", 1)) - 1, "01")
	_char_name.text = str(me["name"])
	_char_stat.text = "第 %d 名" % rank

	# 左细条 = **体力**（满 = 亮黄）。这一条是即时制里真正一直在动的量：
	#   每走 1 格 -20、每秒 +7，低于「自己走所需要最小体力值」就不能出发。
	#   参数来自地图场景配置（config/scene/<map>/<map>.txt），见 Sim.stamina_*()。
	# 右细条 = 现金 / 目标额（原版这条留空，我们的刻意偏差，见 docs/ui-audit.md §2）
	var smax := Sim.STAMINA_MAX
	if Net.sim != null:
		smax = Net.sim.stamina_max()
	_char_bar_a.value = clampf(float(me.get("stamina", 0.0)) / maxf(smax, 1.0) * 100.0, 0.0, 100.0)
	var goal := 1000000.0
	_char_bar_b.value = clampf(float(me["money"]) / goal * 100.0, 0.0, 100.0)

	var t: Dictionary = {}
	if _board != null and _board.map != null:
		t = _board.map.tile(int(me["tile"]))
	# 这块是**精灵栏**：显示出战小神仙的**头像**（点一下 → 精灵仓库）。
	# ⚠️ 原来这里显示「所在地块的名字 + 等级」，老板说「很奇怪」；也不该用文字。
	var ap: Dictionary = {}
	if Net.sim != null:
		ap = Net.sim.active_pet(me)
	if _pet_slot != null:
		if ap.is_empty():
			_pet_slot.texture = null
		else:
			_pet_slot.texture = _tex_or_null(Rules.pet_art(str(ap.get("id", "")), "face",
				int(ap.get("level", 1))))
	if ap.is_empty():
		_char_info.text = "精灵栏（空）"
	else:
		var nm2 := str(ap.get("id", ""))
		if Net.sim != null:
			nm2 = Net.sim.pet_name(nm2)
		_char_info.text = "%s Lv%d" % [nm2, int(ap.get("level", 1))]


## 动作入口：GO 圆钮（掷骰子）+ 落点气泡（买 / 升级 / 放弃）
## 手上有「本次抵达的一次性机会」时不给掷骰子，先把它处理掉（原版语义）。
func _sync_action_entry(me: Dictionary, plots: Dictionary, my_id: int) -> void:
	var can_act: bool = int(me["moving"]) == 0 and bool(me["alive"]) \
		and int(me.get("id", my_id)) == my_id
	var kind := str(me.get("last_plot_kind", ""))
	var lidx := int(me["last_plot"])

	# 骰子正在飞出的那 0.55 秒里 GO 钮**保持可见**，否则观感是「按钮突然消失、
	# 骰子凭空出现在天上」，接不上「从这里飞出去」。
	_go_btn.visible = (can_act and kind == "") or _dice_fx_state == "fly"
	# 体力不够时压暗 GO 钮（原版「自己走所需要最小体力值」——见 Sim.stamina_min_start）
	var smin := Sim.STAMINA_MIN_START
	if Net.sim != null:
		smin = Net.sim.stamina_min_start()
	var tired: bool = float(me.get("stamina", 0.0)) < smin
	_go_btn.modulate = Color(0.55, 0.55, 0.62, 0.85) if tired else Color(1, 1, 1, 1)
	if tired:
		_go_btn.tooltip_text = "体力不足（%.0f/%.0f），歇一会儿" % [
			float(me.get("stamina", 0.0)), smin]

	# 卡片二次确认（购地卡 / 土神卡）自己管文案与显隐，别被落点逻辑覆盖；
	# 一旦不能再操作（走起来了 / 不是自己了 / 又冒出一个落点机会）就收掉，
	# 免得留着一个已经过期、价钱不对的确认框。
	if _pop_mode == "card":
		if not (can_act and kind == ""):
			_close_card_confirm()
			return
		_pop.visible = true
		return
	# 商店购买确认：不受「能不能操作」影响，等玩家答是/否（或 ESC）
	if _pop_mode == "shop":
		_pop.visible = true
		return

	var show_pop := can_act and kind != ""
	_pop.visible = show_pop
	if not show_pop:
		_pop_mode = ""
		return

	_pop_mode = kind
	# 提示语文案对齐原版 Info.txt：
	#   id 91「<ROAD>\n购买价格<NUMBER>元\n是否购买」
	#   id 93「<ROAD>\n升级费用<NUMBER>元\n是否升级」
	if kind == "buy":
		_pop_text.text = "%s\n买地 %d 元" % [_plot_name(lidx), Sim.EMPTY_PLOT_PRICE]
		_btn_bldtype.visible = false
		return
	if kind == "upgrade" and lidx >= 0 and plots.has(lidx):
		var plot: Dictionary = plots[lidx]
		var lv := int(plot["level"])
		var ptype := str(plot.get("type", ""))
		var opts: Array = Net.sim.buildable_types() if Net.sim != null else Rules.primary_types()
		if ptype == "" and opts.size() > 1:
			_fill_bldtype(opts)
			_btn_bldtype.visible = true
			var sel: Variant = _btn_bldtype.get_item_metadata(maxi(_btn_bldtype.selected, 0))
			ptype = str(sel) if sel != null else str(opts[0])
		elif ptype == "" and opts.size() == 1:
			ptype = str(opts[0])      # 只有一种房屋时不询问（原版 id 92 批注）
		else:
			_btn_bldtype.visible = false
		var free := int((me.get("effects", {}) as Dictionary).get("free_upgrade_steps", 0)) > 0
		var gname := str(Rules.house_grade(ptype, lv + 1).get("name", "下一级"))
		if free:
			_pop_text.text = "%s\n免费加盖 → %s" % [_plot_name(lidx), gname]
		else:
			_pop_text.text = "%s\n升级 → %s（%d 元）" % [
				_plot_name(lidx), gname, Rules.house_upgrade_cost(ptype, lv + 1)]
		return

	_pop.visible = false
	_pop_mode = ""


func _plot_name(idx: int) -> String:
	if _board == null or _board.map == null or idx < 0:
		return ""
	var t: Dictionary = _board.map.tile(idx)
	return str(t.get("street", t.get("name", "空地")))


func _fill_bldtype(opts: Array) -> void:
	## 房型下拉：只在可选项变化时重建，避免每帧把玩家的选择重置掉
	var parts := PackedStringArray()
	for o in opts:
		parts.append(str(o))
	var sig := ",".join(parts)
	if str(_btn_bldtype.get_meta("sig", "")) == sig:
		return
	_btn_bldtype.set_meta("sig", sig)
	var keep: Variant = _btn_bldtype.get_item_metadata(_btn_bldtype.selected) \
		if _btn_bldtype.item_count > 0 else null
	_btn_bldtype.clear()
	for i in range(opts.size()):
		var t := str(opts[i])
		_btn_bldtype.add_item(Rules.house_type_cn(t))
		_btn_bldtype.set_item_metadata(i, t)
	if keep != null:
		for i in range(_btn_bldtype.item_count):
			if str(_btn_bldtype.get_item_metadata(i)) == str(keep):
				_btn_bldtype.select(i)
				break


## 玩家一览/头像用原版角色立绘（uitex/player/roleN_01.tga）
static func _role_tag(n: int) -> String:
	## 角色序号 1..12 → 素材目录后缀 role1..role9 / rolea / roleb / rolec
	## （原版 actor/roleN 与 uitex/player/roleN 同名；10/11/12 就是 a/b/c）
	if n <= 9:
		return "role%d" % n
	return "role" + char(96 + (n - 9))


func _role_texture(idx: int, kind: String = "01") -> Texture2D:
	## kind 取值（uitex/player/）：
	##   "01".."04" = 4 种表情的大圆头像（128px）→ 左下角色面板
	##   "21"       = 头特写小图标（32px）      → 右侧玩家头像列
	##   "31"       = 随身物/徽章（32px）
	var tag := _role_tag(clampi(idx + 1, 1, 12))
	var p := "res://assets/uitex/player/%s_%s.png" % [tag, kind]
	if not ResourceLoader.exists(p):
		return null
	var r: Resource = load(p)
	return r if r is Texture2D else null


func _comma(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out

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
