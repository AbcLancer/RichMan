# MEMORY.md —— RichMan（大富翁6 即时制复刻）· 铁律索引

复刻《大富翁6》（软星 2002）**即时制玩法** + 重做联机；素材复用 `F:\游戏\Rich6`。
引擎 **Godot 4.x + GDScript**。

> ⚠️ **本文件是索引**（注入有长度上限，太长会被截断）。
> **每条铁律的全文 / 证据 / 已排除的错误猜测 → `docs/iron-rules.md`，编号一致。**
> 相关清单：`docs/alignment-gap.md`（未对齐）· `docs/ui-audit.md`（界面）·
> `docs/decision-log.md`（逐轮决策）· `docs/original-visual-reference.md`（画面）。
> **编号是稳定引用**（代码注释写「铁律 #12」「见 #28」）→ 增删条目**不要重排号**。

## 铁律

### A. 方法论

1. **玩法数值必须溯源原版配置**（`config/Initvar_r.txt` → `rules/realtime.json`，带 `_source`）。
2. **即时制 ≠ 回合制换算** → **只取 `_r` 分支**。
3. **两类计时器分清**：绝对时刻 `_until = time + N` 秒 vs 剩余步数 `_steps = N`。
4. **`Sim` 不得引入渲染/网络代码**（服务端与客户端共用逻辑的前提）。
5. 素材版权属软星，**仅限个人学习研究，不得商用分发**。
6. **画面必须对齐原版实机截图**（`docs/screenshots/orig/`）：牌桌 = 连续 3D 地形 + 地面贴花 +
   低机位斜视，**不是矩形跑道**。
7. **跑原版做参考时游戏要常开、一步步走**（老板要求）。沙箱改不了工作区外文件 →
   `tools/make_r6_runtime_copy.py` 造副本 `F:\游戏\Rich6run\` + `r6_drive.py` 保活。

### B. 原版数据（已逆完，别再重啃）

8. **`.r6m`(R6MP)** = 街道名表 + 20 个**街区矩形**（`48×A + 76`）→ **不是逐格坐标**。`tools/r6m_blocks.py`。
9. **`.r6s`(R6SM)** = 场景节点树（路线 = 一条 Bezier，节点数 = 格数）；**1 格 = 100 世界单位**。
10. **`.pol`**：位置 `(f1,f2,f3)` / 法线 `(f0,f6,f7)` / UV `(f4,f5)` 是 **UVW「盒投影」**。
11. **房屋唯一权威 = `config/House.txt`** → `rules/houses.json`。上限 `nGrade` **住宅 12 / 商业 15 /
    工业 9**（别写死 4）；另有 `special1/2/3` 特殊建筑 9 级 —— **有数据但不可建、无效果**（#45）。
12. **升级 = 抵达自己地产时的「一次性」选择**（`last_plot` + `last_plot_kind`，用完即清）。
    ❌ **绝不按 `tile` 判权限**。

### C. 音频

13. **音频 4 层**：音效 152（id = 文件名，2D/3D 看 `sndeffect.txt`）/ BGM 18 / 配音 / 宠物；
    总映射 `assets/audio/voice_map.json`。
14. **音效「何时播哪个」**：场景物体**有表**（`anim/*.gae` 内嵌 `.cvd`）；UI/玩法调用点**没有表**。
    已实测 **1=按钮、2=确认、95=底噪**。
15. **音效语义唯一权威 = `rules/sfx.json`**。❗两条「数量吻合」推断已被老板试听**否证，永不再捡**。
16. **BGM 一曲接一曲不是循环**。菜单 = `m01001`；7 张地图对局曲全是 `m01009` →
    用 `Audio.play_bgm_playlist()`，**别用 `play_bgm()`**。

### D. 画面（血泪）

17. **棋盘贴图三张**：`ditu.tga` = **游戏真身**（与 `assets/terrain/aiji_ground.png` 逐像素相同）
    → **看对齐只看它**；`ditu_noshadow` = 去阴影；`ditu2_1024` = 编辑器版。
18. **UV 必须 `v = z/S + 0.5`**；❌ `0.5 - z/S` 让整张贴图**沿 Z 镜像**（＝「地毯没对齐石子路」的真因）。
    顶点-UV 必须**双边同口径**。判向法见 `docs/original-visual-reference.md`。
19. **量对齐必须 `--tex ditu`**；另两张得**假数字**。
20. **相机 = 跟随角色的近距低机位**（3~4 格远），**不是俯视全盘**。
21. **只有埃及有 `ditu*` 棋盘美术**，其余 7 图走兜底布局。
22. **小地图路线只能当拓扑参考**（2:1 压扁示意图）→ 不能产坐标。

### E. 棋盘格数

23. **棋盘 = 94 格（老板拍板，✅ 不再压缩）**。产 `game/data/maps/aiji_tilepos.json` ←
    `tools/route_from_walkway.py`（`alpha=0.70`、`mode=quantile`）。指标：→中心线中位 **5.0 px**。
24. **坐标口径**：`x=(px/1024-0.5)*200`、`z=(py/1024-0.5)*200`；文件 `"u"/"v"` = `x/S+0.5`/`z/S+0.5`。

### F. 界面（UI）

25. **口径**：原版 **1024×768**；截图 px **÷1.5 = native**；`UI_SCALE = 视口高 / 768`。
    ⚠️ 原版 4:3 / 我们 16:9 → 宽屏下 HUD **占屏比更小是正确行为**。
26. **原版 UI 有贴图**（旧记忆「都是程序绘制」**只对顶栏底条成立**）。
27. **动作入口定位规则不同**（旧记忆「都在角色头顶」**错了**）：掷骰子 = **GO 钮 = 固定屏幕位**（#40）；
    买地/升级 = **落点气泡 = 贴角色头顶**（锚世界点再投影）。铁律 #12 照旧。
28. **小地图底图第 98 行往下是装饰蓝条** → 原版**裁蓝条、地形铺满整框**；标记按全图 v 映射整框。
29. **角色头像三套** `uitex/player/roleN_*`（`_01..04` 大头像 / `_21` 列头 / `_31` 随身物）；
    序号 **1..12 → role1..9 / a / b / c**（**没有 role10/11/12**）。
30. **真字体 = `gbdata/unicode16/24.tft`（TNFT 点阵，已破）**，已设为 `theme.default_font`。
31. **没用上的 UI 素材**：`other/saybk.png`、`{buystock,auction,pet,pethouse,house,up_info,casino,
    form,option,gold}/`、`roadobj/`、`event/`。
32. **GO 钮 = 两张残图叠出来的**（都贴边裁切 → 只能按「可见区中心」对齐）。
33. **是/否 = 两块半胶囊拼一整颗**（`separation=0` + `STRETCH_SCALE`(56×32)）；❌ `KEEP_ASPECT_*` 会裁一半。

### G. 骰子 / 卡片 / 小神仙 / 音效（2026-09-26）

34. **骰子颗数选择器上限 = 2**（`Sim.DICE_PER_ROLL_MAX`）；原版实机 5 张截图一致。默认 1 颗。
35. **骰子素材口径（旧记录错了）**：`anim.tga` = **4×4 = 16 帧**；`骰子.tga` = **6 个面**。
36. **`config/String.txt` = 原版**界面标签**唯一权威**（UTF-8）：卡片菜单 1/2/3、目标提示 1101..1106、
    卡说明 9001..9042、**卡片不可用原因码 60..70**。⚠️ 第 104 行编号写成 `02` **撞号**（同 id 保留首次）。
37. **卡片 42 张，39 张真生效**。`CARD_TARGET`（点谁）是**推导表**；红/黑/复制卡在 `CARD_UNSUPPORTED`
    （**用了不消耗**）。卡面显示 **100 native**。
38. **原版卡片界面版式没有证据** → 我们的手牌条是**重建版式**（刻意偏差），文案 100% 用原版。
39. **多格建筑占地仍不合并**（相邻两格盖满级房会穿插）。
40. **⭐ GO 钮不在角色头上**。原版 4 张截图里它**固定在归一化 (0.691, 0.599)** → **固定屏幕位**；
    角色头顶那个蓝色圆盘是**三岔路方向选择盘**。⚠️ 4:3 与 16:9 的归一化**不可换算** →
    取老板实机标注 `GO_ANCHOR_NORM = (0.782, 0.508)`。
41. **⭐ 卡片可用性门禁**：原因码就在 `String.txt` **60..70**（63 =「只能用于对手的地产（土神卡，购地卡等）」）。
    `Sim.card_usable()` 返回码 → UI **压暗** + 菜单「使用」**置灰** + toast 原因。
    ⚠️ 原版没有「卡→码」映射表 → **这是推导**。⚠️ **走着时允许用卡**（停留卡就是边走边用）。
42. **⭐ 购地卡/土神卡目标 = 脚下的「对手地产」**（旧实现写反了，写成「无主空地」）。购地卡按
    `Sim.plot_value()` 付给原主，土神卡不付钱；两张都先弹**原版「是│否」二次确认**。
43. **⭐ 音效 2D/3D 的含义**：**2D = 界面音 = 只给「当事人」听**；3D = 场景音，人人可听。
    ❌ **3D 空间音仍未做**（`play_sfx_at` 的 `unit_size/max_distance` 是旧值，会让远处静音）。
44. **⭐ 原版「逻辑全貌」不存在**：包内**没有脚本**（`*.gbf` 是着色器）；`rich6.exe`（688 KB 未加壳）
    **零符号 / 零 RTTI**；`rich6.asm.txt` 是**线性扫描**。→ 只能**定点逆向**：**`tools/r6_re.py`**
    （`info`/`strs`/`xref <VA|off:偏移>`/`dis`/`calls`）。
    ⚠️ `executable-references.txt` 的 `0x0009DF4C` 是**文件偏移**（+0x400000 才是 VA）。
45. **⭐ 未对齐总表 = `docs/alignment-gap.md`**（问「还有哪里不对」先看它）。✅ 2026-09-26 已补掉
    「点券出口 + 小神仙」（#46）；**瓶颈转到路面物体 / 神仙蛋**。
    ⚠️ **`Info.txt`（1490 行）= 原版功能全图** ——查「原版有什么」的首选。
46. **⭐ 小神仙 + 点券出口（已做）**：数据 = `config/Pet.txt`（9 只 ×4 级：秒数/次数/**消耗点数**）
    + `String.txt` **2201..2210 技能名** + `Info.txt` 202（上限 5 位）；**9 种特技全实现**
    （`Sim._tick_pets()`：**抵达格子后**发动，扣点券 + 进冷却）。**卡片商店**卡价 = **徽章 × 10**。
    **两店界面全是原版底图**（`uitex/pethouse/*`、`uitex/other/cardshop*`），
    **槽位坐标在 `assets/pets/index.json` 的 `slot` 表**（别硬编码进 gdscript）。
    ⚠️ 曾发现磁盘上 `card/index.json` **没有 `badge` 字段**（旧产物）→ 已重跑生成器。
47. **⭐ `config/Info.txt`（1236 条）= 原版**过程消息**总表**（2026-09-26 才进管线）。
    ⚠️ **它的 id 空间与 `String.txt` 完全独立**（String 63 ≠ Info 63）→ `Rules.info_string()` /
    `ui_string()` 是**两个**函数。占位符用 `Rules.info_fill(id, {...})` 替换。

## 关键路径

| 用途 | 路径 |
|------|------|
| 原版本体 / pck / 音频原件 | `F:\游戏\Rich6` / `gamedata.pck`（371 MB）/ `sound\`（**不在 pck 里**） |
| **原版明文 / 反汇编 / 定点逆向** | `docs/original-readable/installation/config/*.txt`；`docs/original-readable/disassembly/rich6.asm.txt`；**`tools/r6_re.py`** |
| **四份「唯一清单」** | `docs/iron-rules.md`（铁律全文）· `docs/alignment-gap.md`（未对齐）· `docs/ui-audit.md`（界面）· `docs/decision-log.md`（决策） |
| 解包 / 产物 | `tools/r6pck.py` → `samples/`（203 MB，gitignore）；`docs/orig-logic/`、`docs/orig-scene/` |
| Godot / 可写副本 / 实机截图 | `D:\Godot\..._console.exe` / `F:\游戏\Rich6run\` / `docs/screenshots/orig/` |
| 素材 / 规则表 | `game/assets/**`（`index.json`；`uitex/**` 458 张）/ `rules/{realtime,houses,sfx,ui_strings,info_strings,pets}.json` |
| 场景 / 地图原件 | `samples/scene/<map>/*.r6s`/`*.pol`/`*.r6m`；`samples/{roadobj,news,gamespot,effect1,effects,event,particle}/` |

## 命令 / 进度

**完整命令清单与进度在 `README.md`。** 只记易忘的：

- `GODOT="D:\Godot\Godot_v4.7.2-stable_win64_console.exe"`；Python 用 **`.workbuddy/venv/Scripts/python.exe`**
  （有 numpy/pillow/scipy/capstone/pefile）。⚠️ `godot` 命令别名是坏的（0 字节文件）→ 用完整路径。
- 改 `game/assets/**` 或新增 `class_name` 后**必须** `--headless --path game --import` **跑两次**。
- **验 UI**：`"$GODOT" --path game --resolution 1280x720 -- --uishot`（10 张）。`--demo` 6 张。
- ⚠️ **`_capture()` 是协程** → **必须 `await` 之后才改游戏状态**（否则抓帧时控件已消失）。
- ⚠️ **`_process` 也是协程** → `await` 期间会**再起一次 `_process`**，两个实例并发 → 用活动锁挡住。
- GDScript **Variant 类型推断视为错误**；`_sfx()` 形参用 **`BaseButton`**；`board_view.gd` 是 **CRLF**。
- ⚠️ **别用 bash heredoc + Python replace 往 `.gd` 里写含 `\n` 的字符串**（meta 层的转义会变成真换行）→ 用 Write/Edit。

**老板定的三项优先级（2026-09-25）**：① 对齐 UI（**已完成**）→ ② 放真实角色模型（`actor/roleN/`，
另有高清 `actor_h/`）→ ③ 接卡牌系统（**已落地成可玩版**，39/42 生效）。

48. **⭐ 路边物体（roadobj）**：权重表 = `config/scene/<map>/<map>.txt` 的「路面物体出现几率」段
    （13 种，`-1` = 不随机生成；**埃及 mine/block = -1，只有太空 mine = 3**），早已进
    `game/data/maps/*.json` 的 `road_items`（此前**零引用**）。素材 `samples/roadobj/<id>/`；
    ⚠️ **`*.tga` 是模型 UV 图集、不是道具图标**；9 个有 `model.pol` → R6BM，11 个只有 `.cvd`（**未逆**）。
    **事件格图标 = `samples/event/*.tga`（19 个 64×64）** → `assets/roadobj/event/`；
    地图 key 是 `coupon<N>` 而图标名是 `credit<N>`；`platform` 原版无图标。
    ⚠️ 事件格**别**再放黄圆盘（会盖住图标）；`tools/build_road_assets.py` 出素材。
49. **⭐ 路面物体数值已反汇编**（`tools/r6_re.py`，`decision-log.md §17`）：注册表在 **`0x431690`**
    （13 个名字压栈，**顺序 = Aiji.txt 注释顺序**），紧跟 **13 个效果回调**（`0x431120` 起）。
    **小偷 = 现金 rand(1..10)%**（`0x4313d0`）· **宝箱 = rand(10..20)% × 全体平均现金、下限 1000**
    （`0x431220`）· **戒指只在小神仙 < 4 级时升级**（`0x431170` 的 `cmp [esi+0x30],4` = 等级上限）。
    回调 push 的消息号 71/76/77/78 与 `config/Info.txt` **逐条对应**（交叉验证）。
    → 数值进 `rules/realtime.json` 的 `road` 段（`_disasm_notes` 记地址、`_inferred` 记推断项）。

50. **⭐ 传送平台（`platform`）**：埃及 2 格 = **索引 24/25（路径上相邻）**但**世界相隔 13.9**
    （≈3 格）→ **同一座传送门的两格**（「传送」已体现在路径本身）。✅ `_other_platform()` 必须
    **跳过相邻格**（`_tile_distance <= 1`），否则两端互传 = 「站在平台上掷 1 点留在原地」；
    传送检测要放 `_advance` 的**逐格循环**（**经过就传**，原来只在 `_arrive` 判 → 能停在平台上），
    并用 `p["_teleported"]` 防同段打转。⚠️ 原版完整语义仍不明（`Info.txt` 无「传送」文案、
    `aiji.r6s` **无 platform 节点**）。
51. **商店购买确认复用落点气泡 `_pop`** → 必须 `z_index = 60` + `_pop_mode == "shop"` 时
    **屏幕居中**（原贴角色头顶 → 落到商店面板边缘点不到）。
    ⚠️ **别**加「商店开着隐藏手牌条」：`_sync_card_hand` 会清空 `_card_slots`，
    连累 `--uishot` 的卡片菜单/选目标两张拍不到。
52. **精灵屋界面**（✅ 已按原版实机截图定稿）：`uitex/pethouse/` 是**一对** 256² 图
    （`精灵屋.tga` 标题「小神仙」、`商店.tga` = 货架），但**一次只显示 `商店.tga` 一张** ——
    原版**没有**「持有栏」。持有的小神仙显示在**左下角角色面板右侧**（`_pet_strip`，
    素材 `assets/pets/<id>/01..04.png`，上限 5 位）。

53. **⭐ 原版商店/卡片 UI 的几条硬规矩**（2026-09-26 老板 10 张原版实机截图定稿，
    截图在 `docs/screenshots/orig/records/`，对照清单 `docs/orig-records-audit.md`）：
    - **卡片商店槽位没有卡面**，只有一行文字「**卡名-价格**」；商店顶部深色条**只显示点券数字**
    - **小神仙价格写「雪精灵 40」**（没有「点券」二字）
    - **卡片菜单 = 锁定 / 使用 / 喂食**（**没有「丢弃」**）；「喂食」= 消耗卡让等级最低的小神仙 +1 级（**推断**）
    - **购买确认框底图 = `uitex/other/infobk.tga`**（灰白圆角 + 蓝底）；台词气泡 = `saybk.tga`
    - ⚠️ 槽位结构两套：`cardshop` 是 `{x,y,w,h}` **整块**，`pethouse` 是 `{img,bar}` **图+标签条** ——
      别混用（我混用过，导致文字被卡面压住）
54. **原版还有、我们没做的**（都出自那 10 张截图）：**右下角常驻股票行情面板**
    （连工业关也有）、**拉霸界面**（左侧滑出 + 三档下注 `+1000/+5000/+10000`）、
    **全局事件全屏插画**（`samples/news/` 38 文件）、台词气泡、其他玩家世界名牌。

55. **⭐ 掷骰节奏：先抛骰、定格，角色才走**（`Sim.ROLL_ANIM_SECONDS = 1.15`，与表现层
    `DIE_FLY_TIME` 对齐）：`act_roll` 设 `p["move_after"] = time + 时长`，`step()` 里
    **只走「本帧区间 ∩ 动画终点之后」那一段**（`seg = time - maxf(t_before, move_after)`）。
    ❌ 别写成「`wait <= 0` 就走整个 dt」—— 跨过终点那一帧会把等待时间算进移动距离。
    闸门放在权威 `Sim` 里（不在 UI），所以远端玩家看到的节奏也一致。
56. **角色面板那块是「精灵栏位」**（不是地块信息！）：显示**出战**的小神仙
    （`p["pet_active"]`，UI 标 `▶`），**点开 = 精灵仓库**（用 `uitex/pethouse/精灵屋.tga`）。
    ⚠️ 两张 pethouse 图的归属：**精灵屋事件点 → `商店.tga`（货架）/ 精灵栏位 → `精灵屋.tga`（仓库）**。
    「出战」的玩法含义无依据 → 只影响显示、特技仍全部生效。
57. **确认框尺寸**：`UI_POP_W/H = 330×160`（原版 `infobk` 对话框约占 1024 宽屏 1/3）。
    ⚠️ `--uishot` 的兜底分支**必须真的 `await _capture`** —— 原来只 push_warning，
    条件触发时那张图会**整张丢掉**（掷骰节奏变长后暴露：13 张 → 12/6 张）。

58. **⭐ 卡片栏规则**（老板 2026-09-26 实机观察；`Initvar_r.txt` **没有**这一项，
    只有 `Card_FuShen_NumCard = 5` 间接印证）：**上限 5 张**（`Sim.HAND_MAX`）·
    **同种叠加只占一个栏位** · 满栏时新卡**顶掉最前方（最早获得）那张** · **锁定的不被顶**
    （全锁着则收不进来、买卡退点券）。加卡一律走 **`Sim._push_card()`**（4 个加卡点）。
    ⚠️ **锁定状态必须在权威 `Sim`**（`p["card_locks"]` + `net` 动作 `lock_card`）——
    原来放客户端本地字典，服务端根本看不到、顶卡时会顶掉锁定的卡。
    ⚠️ 手牌**不能 `sort()`**（会打乱「最前方」的定义）；同种合并要按**首次出现顺序**去重。

59. **⭐ 股票 / 公司（2026-09-26 起）**：**公司名 = `config/Role.txt` 第 6 列「缺省公司」**
    （孙小美=中华美食、阿土伯=新土地、宫本宝藏=第一宝藏、乌咪=玛雅…；老板原版股票截图逐字对上）。
    每个玩家以自己的缺省公司上市，初始价 = `Player_Com_Capital/AllShares` = 500000/10000 = 50，
    自持 2000 股（`Player_Com_SelfShares`，截图里玩家的「持股」就是 2000）；
    每图另有 6 家**虚拟公司**（`scene/<map>/<map>.txt`）。参数全在 `realtime.json` 的
    `economy.stock`（25 项）；每日波动 `Stock_OpenPrice` ±10%；买卖手续费 `Stock_Handle_Charge = 0.01`；
    **持股 ≥60% = 董事长**（Info 131..135）。`tools/build_role_data.py` → `rules/roles.json`
    （12 角色 × 三项 AI 性格权重 + 缺省公司 + 标示物 + 标志色）。
    UI = `game/scripts/ui/stock_panel.gd`（右下角常驻表 + 点行弹「买进/卖出/股东/走势」+ 买卖对话框，
    素材 `uitex/buystock/`）。⚠️ 原版右下角**只有**行情面板，小地图是按 `MAP` 开的。
60. **`Role.txt` 是三个东西的权威**：① 角色名/模型目录（**只有 role1..9 + rolea/b/c**）
    ② **AI 三项性格权重**（害人 / 买卖股票 / 买地）③ **缺省公司**（股票系统的公司名）。

61. **红卡/黑卡（2026-09-26 解开）**：`CARD_TARGET` 里目标类型早就是 `"stock"`（选一种股票）；
    幅度 = `card.hongka_price` / `card.heika_price` = **0.20**（`Initvar_r.txt` 的
    `Card_HongKa_Price`/`HeiKa_Price`）。`act_use_card(id, card, target, target_name)` ——
    **第 4 个参数是公司名**（`net` 的 `card` 动作带 args[2]）。实现 = `Sim._shift_stock()`
    （同时把 `prev` 设成旧价，面板的 % 立刻反映）。
    UI：用卡时若 `card_target == "stock"` → 行情面板进 `begin_pick()`，点一行 = 选中公司。
    ⚠️ **`realtime.json` 的 `card` 段原来整个是空的**（25 个 `Card_*` 参数从未进管线）→ 已补 23 项。
    ✅ 现在只剩「复制卡」在 `CARD_UNSUPPORTED`。
62. **买股票对话框：滑动条是唯一输入点**（`HSlider`，**step = 100**），**没有手动输入框**；
    范围 = 买进「现金/股价」、卖出「手里的股数」（都按 100 取整）。原版截图里那个 1900 就是拖出来的。
63. **股票面板的公司名单**：**玩家公司在前、虚拟公司在后**（老板新截图证实：四位玩家的缺省公司
    之后跟着地图虚拟公司「阿里巴巴」）。

64. **⭐ 原版不允许多人同格 → 「挤人」**（老板 2026-09-26）：后到的人把**站着不动**的同格玩家
    **往前挤一格**（`Sim._push_away_occupants()`，在 `_arrive()` **最开头**调）。被挤的人
    **要付房租**（复用 `_resolve_plot`）但**不给**买地/升级机会（紧接着 `_clear_chance()`）。
    正在走的人不挤。⚠️ 表现层 `_stack_index`（同格错开）留作兜底。
65. **右下角功能区 = 6 个按钮 × 4 页**（老板给的原版说明，**以此为准**）：
    ①新闻→**日志页** ②**股票**→股票页 ③地图→小地图（**默认页**） ④聊天区→聊天记录页
    ⑤聊天→**额外**弹聊天栏（不占小面板） ⑥最右下→**收起/展开**功能区。
    ⚠️ **股票页要占「小地图那一块地方」**（互斥显示），不是浮在小地图上方 ——
    由 `StockPanel.set_embed_rect(rect, on)` 接 app 每帧传的 rect。
66. **聊天**：`Sim.act_chat(id, text, to, channel)` —— 公共=广播、私聊=只发双方、限长 60 字；
    `net` 动作 `chat`（args = 文本/目标id/频道名）。

67. **⭐ 拉霸（老虎机）素材在 `uitex/casino/`，不在 `labar/`**（我曾把 `labar` 误当拉霸，已纠）：
    `labar/` = **掷骰**素材（`go`/`go_dn` GO 钮、`anim` 16 帧骰子、`骰子` 6 面、`背景` 蓝球）；
    拉霸 = `casino/背景.tga`(粉色拱形面板) + `姑娘1..3`(兔子女郎) + `pull_1/2`(拉杆) +
    `add1..3`(`+1000/+5000/+10000`) + `7/苹果/香蕉/财神`(滚轮符号) + `exit`。
    赔率只给了 `events.casino_top_rate`(1.0)/`casino_middle_rate`(0.3) → 三同/两同算法是**推断**。
68. **全局新闻**：文案 = `Info.txt` **甲1..甲14 = id 3001..3014**（标签 `NEWS`）；
    效果参数 = `realtime.json` 的 `news` 段 14 项（`Initvar_r.txt` 的 `XinWen1..14`）。
    插画 = `samples/news/01..38.tga`（256²）→ `assets/news/`（`tools/build_news_assets.py`）。
    ⚠️ 触发频率与「哪张插画配哪条新闻」**都无依据**（按序号取，已登记）。
69. **42 张卡全部可用**（2026-09-26）：红卡/黑卡（股票）+ 复制卡（`copy`，复制手里另一张卡）
    都已实现 → `CARD_UNSUPPORTED` **已清空**。

70. **⚠️ 右下角功能区别把「地图面板」整个 `visible = false`**（2026-09-26 的 bug）：
    它和按钮条同在一个 `VBoxContainer` 里，面板一隐藏，**按钮条会被 VBox 顶到地图那块地方**，
    正好钻到股票页底下被盖住 → 「切到股票后按钮全没了、切不回去」。
    正确做法：**面板始终占位**，只 `_minimap.visible = false` + 把底框换成 `StyleBoxEmpty`。
    另加保险：`_hud.move_child(_stock, 0)`（股票面板压到最底层）。
    ⚠️ `--uishot` 的张数**偶尔波动**（同一命令 11~16 张）是 `_process` 协程竞态，**重跑即可**。

71. **角色面板右上那块 = 精灵栏，要显示「出战小神仙的头像」**（`_pet_slot`，用
    `Rules.pet_art(id,"face",lv)` + 一行「名字 Lv」）；**不要再**在角色面板右侧贴那排小图标
    （`_pet_strip` 已删 —— 老板 2026-09-26：「把精灵头像放在了右侧缩到了很小，完全不对」）。
    点开仍是**精灵仓库**（单独界面）。手牌尺寸 `CARD_PX = 130`（原版 100 × 1.3，因为上限只有 5 张）。
72. **⭐ `docs/HANDBOOK.md` = 项目手册 & 手改指南**（老板 2026-09-26 要的）：里面有四张
    「我要改 X 去哪找」表（**音效 / 模型贴图 / 玩法数值 / 逻辑代码**）+ 数值链
    （原版配置 → `tools/build_*.py` → `game/data/**/*.json` → `rules.gd` → `sim.gd`）
    + 验收命令 + 7 条最易踩的坑。README 顶部有入口。

73. **⭐ 联机：`Sim._ev()` 只在本地发信号 → 客户端什么都收不到（2026-09-26 修）**：
    必须由**房主把事件 RPC 转发**出去，客户端收到后在本地重新 `emit` 到 `sim.game_event`
    （这样 UI 不用改）。见 `net.gd` 的 `_rpc_event`；⚠️ 单机时**别发**（`has_remote_peers()` 判断，
    否则报 "RPC on yourself"）。**拉霸状态 `casino` 也要进快照**（`to_dict`/`apply_dict`）。
74. **联机烟测 `test/net_smoke.gd` 已覆盖 6 个动作**（掷骰/买股票/锁卡/精灵出战/聊天/拉霸），
    房主要先 `_seed_resources()` 塞钱+卡+宠物否则跑不动。`--large`（满盘地产+AI）**两端都要加**。
    期望两端各一行 `NET_SMOKE_PASS`。
75. **GDScript 三个坑**：① `_fail` 类函数**先 `print` 再 `push_error`**（headless 下
    `push_error` 不进 stdout，失败时日志会一片空白）② `(x as Dictionary).get(k, {})` 后
    **不能直接点成员**，要先落到 `Dictionary` 变量 ③ 快照里 `casino` 的 key 是 **int pid**，
    别用 `str(id)` 查。

76. **⚠️ 事件点必须「踩到」才生效**（2026-09-27 老板）：路边物体（`roadobj`）原来写在
    `_advance()` 的**逐格循环**里 → **路过就捡**；已挪到 `_arrive()`。
    **例外**（保持原样）：地雷/路障（踩上即停）、**传送平台**（原版就是经过就传）。
77. **⭐ 小神仙：体力条 → 满才能发动 → 发动一次升一级**（老板 2026-09-27 的原版观察）：
    走 1 步 +1 体力（`Sim.PET_ENERGY_MAX = 60` 步攒满，**推断值**）；`_tick_pets()` 里
    **体力不满就不发动**；发动 → 清体力 + **等级 +1**；**喂食** = 升级 + 把体力充满；
    ⚠️ 原来的「走步自动升级」（`Pet_Upgrade_Steps = 300`）**已停用**。
    UI：角色面板精灵栏 = 头像 + 「名字 LvN」+ **体力条**（`_pet_bar`）。
78. **⭐ 要选目标的卡只有「选对手」这一类**（按 `String.txt` 权威说明）：
    地雷卡 9023 = **身后一格**、路障卡 9024 / 清除卡 9039 = 自动放，**都不用选**；
    **穷神卡 9003「指定对象」才要选对手**。修法 = 屏幕中间弹**目标选择器**
    （头像+名字+现金的大按钮 + 取消），不再只靠点右上角小头像。
79. **卡片锁定 = 卡面底边贴 `uitex/other/clamp.png`**（不再压暗）；压暗只留给「条件不满足」。
    左下角那个独立的「卡片夹子」按钮（同一张图）**已删**（老板「不知道是干啥的」）。
    ⚠️ `--uishot` 内部超时已提到 **230 秒**（功能变多、流程变长）。

80. **聊天发一句刷 N 遍**（2026-09-27 修）：`Sim.act_chat` 的公共频道原来对**每个玩家各 `_ev` 一次**
    → UI 收 N 次。改成**只发一次**（`_ev("chat", null, payload)`）。
81. **⭐ 选目标 = 原版做法**（2026-09-27，老板实机截图纠正）：
    **候选角色脚下圆盘亮绿** + **鼠标指到的变红** + **点下去选中** + **有距离限制**
    （`Sim.CARD_TARGET_MAX_TILES = 5` 格，**推断值**——原版没有「选对手距离」参数）。
    ❌ 我上一版做的「屏幕中间弹目标选择器」**不是原版**，已撤。
    实现：投影到屏幕比距离（`BoardView.player_screen_positions()` / `nearest_tile_to_screen()`）。
82. **⭐ 建造选房型 = 横排建筑卡片**（2026-09-27，老板实机截图）：不是下拉框。
    卡片 = `assets/uitex/house/<House.txt 一级文件>.png` 缩略图 + 类型名 + 一级造价
    （住宅 a0101/1000 · 商业 b0101/1500 · 工业 c0101/2000）；点完随 `upgrade` 的 args[0] 发出。
83. **乐透开奖**（待做）：依据在 `Info.txt` **54..68**（60 奖金累积 / 61 请选择号码 /
    63 今日乐透开奖 / 64 中奖播报 / 65 没人中 / 68 售完）；素材 **`uitex/casino2/`**
    （`背景` 粉色面板 + `姑娘1..3` 兔子女郎 + `mark`/`cursor`/`exit`）。
    ⚠️ `Initvar_r.txt` **没有** `Lotto_*` 参数（15 天周期是老板说的，属推断）。
    ⚠️ `uitex/casino/` 是老虎机（已做），**别和 `casino2/` 搞混**。
