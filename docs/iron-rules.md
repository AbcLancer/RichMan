# 铁律全文（RichMan 复刻）

> 这份是 `.workbuddy/memory/MEMORY.md` 的**全文版**。MEMORY.md 只保留「编号 + 一句话 + 指针」
> （注入有长度上限，太长会被截断）。**编号两边一致**，代码注释里的「铁律 #12」直接查这里。
>
> 只放**铁律 + 路径 + 命令**。完整证据 / 字段表 / 指标表 →
> `docs/ui-audit.md`（界面）、`docs/alignment-gap.md`（未对齐清单）、
> `docs/original-visual-reference.md`（画面）、`docs/decision-log.md`（逐轮决策）、
> `docs/orig-logic/`、`docs/orig-scene/`、`docs/sfx-map.md`。

---

复刻《大富翁6》（软星 2002）**即时制玩法** + 重做联机；素材复用 `F:\游戏\Rich6`。
引擎 **Godot 4.x + GDScript**。进度 → `README.md`；决策 → `docs/decision-log.md`。

> **本文件只放铁律 + 指针**。证据 / 字段表 / 指标表 / 度量全部在：
> `docs/ui-audit.md`（界面）、`docs/original-visual-reference.md`（画面）、
> `docs/decision-log.md`（逐轮决策）、`docs/orig-logic/`、`docs/orig-scene/`、`docs/sfx-map.md`。
> ⚠️ **编号是稳定引用**（代码注释会写「铁律 #12」「见 #28」）→ 增删条目**不要重排号**。

## 铁律（冲突时以本文件为准）

### A. 方法论

1. **玩法数值必须溯源原版配置**（`F:\游戏\Rich6\config\`）：即时制取 `Initvar_r.txt`
   → `game/data/rules/realtime.json`，每条带 `_source`/`_comment`。
2. **即时制 ≠ 回合制换算**（1 天 = 24 秒，但两套不等比）→ **只取 `_r` 分支**。
3. **两类计时器分清**：绝对时刻 `_until = time + N` 秒 vs 剩余步数 `_steps = N`。
4. **`Sim` 不得引入渲染/网络代码**（服务端与客户端共用玩法逻辑的前提）。
5. 素材版权属软星，**仅限个人学习研究，不得商用分发**。
6. **画面必须对齐原版实机截图**（`docs/screenshots/orig/`）：牌桌 = 连续 3D 地形 + 地块地面贴花
   + 低机位斜视，**不是矩形跑道**。
7. **跑原版做参考时游戏要常开、一步步走，别每次会话结束就 taskkill**（老板要求）。沙箱改不了
   工作区外文件 → `tools/make_r6_runtime_copy.py` 造副本 `F:\游戏\Rich6run\` + `r6_drive.py` 保活。

### B. 原版数据（已逆完，别再重啃）

8. **`.r6m`(R6MP)**：街道名表 + 20 个**街区矩形**（`48×A + 76`，埃及 ΣA = 94），**不是逐格坐标**。
   `tools/r6m_blocks.py`。
9. **`.r6s`(R6SM)** = 场景节点树：路线 = 一条 Bezier（节点数 = 格数）；地产块 A×100 / B×100
   → **1 格 = 100 世界单位**。`tools/r6s_nodes.py` → `docs/orig-scene/`。❌ 未做：街区坐标 ↔
   `aiji_tilepos.json` 的相似变换拟合。
10. **`.pol` 字段**：位置 `(f1,f2,f3)`、法线 `(f0,f6,f7)`、UV `(f4,f5)`；`f4` 只随 (x,z)、`f5` 只随 y
    → **UVW「盒投影」** → 必然「大体对、局部错」。❌ 旧记忆「f4/f5 不是 UV」错的。
11. **房屋数值唯一权威 = `config/House.txt`** → `rules/houses.json`（45 级）。「升级费」= **建成该等级
    的造价**；上限 `nGrade` **住宅 12 / 商业 15 / 工业 9**（别写死 4）；模型 id = 「文件」列
    （a/b/c = 住宅/商业/工业）；房型选项来自 `scene/<map>/<map>.txt` 的 `buildinfo`。
    ❌ `STYLE_BY_MAP` 把埃及映射到 `d` 组是错的，已改 `id_for()`。另有 3 组 `special1/2/3`
    （d1xx–d3xx 特殊建筑，9 级）—— **数据有、但不可建、无效果**（见 #45）。
12. **升级 = 抵达自己地产时的「一次性」选择**（同买地语义，`Info.txt` 91/93/88/1050/1053）。靠
    `last_plot` + `last_plot_kind`，**用完即清**；连续升级只有三路：走开再回来 / 停留卡 / 升级卡。
    ❌ **绝不按 `tile` 判权限**（会变成站地上连点到满级）。

### C. 音频

13. **音频 4 层**：音效 152（id = 文件名，2D/3D 看 `sndeffect.txt`）/ BGM 18 / 配音 12×27
    + 卡名 42 / 宠物 9×9。台词文件名 = `Info.txt` 消息 id（role k 段号 9+k → role1 = `1001.wav`）；
    卡名/回话 = **卡号**。总映射 `voice_map.json`。
14. **音效「何时播哪个」分两半**：场景物体 **有表**（`anim/*.gae` 内嵌 `.cvd`，已提 33 条）；
    UI/玩法调用点 **没有表** → 只能标记音替换实测。已实测 **1=按钮、2=确认、95=底噪**。
15. **音效语义唯一权威 = `rules/sfx.json`**（`conf` + `wired`）。❗两条「数量吻合」推断已被老板试听
    **否证，永不再捡**：① 016–054=新闻 ② 055–067=路面物体。**教训**：`sndeffect.txt` 的 `//`
    只是排版分段，**组条目数 ≠ 语义**。
16. **BGM 一曲接一曲不是循环**。菜单/大厅 = **m01001**；**7 张地图对局曲全是 m01009**。
    对局用 `Audio.play_bgm_playlist()`，**别用 `play_bgm()`**。

### D. 画面（血泪）

17. **棋盘贴图三张**：`ditu.tga` = **游戏真身**（与 `assets/terrain/aiji_ground.png` 逐像素相同）
    → **看对齐只看它**；`ditu_noshadow` = 去阴影；`ditu2_1024` = 编辑器版（量红框用）。
18. **UV 约定**：Godot `uv.y=0` 在贴图**上方** → **必须 `v = z/S + 0.5`**；❌ `0.5 - z/S` 会让整张贴图
    **沿 Z 镜像**（症状「形状像但整体错开 ≈2 格」＝**「地毯没对齐石子路」的真因**）。顶点-UV 必须
    **双边同口径**（`_build_ground()` 与 `minimap.gd::_uv()`）。判向法见
    `docs/original-visual-reference.md`（❌「点→线距离」是循环论证）。
19. **量对齐必须 `--tex ditu`**（`tools/walkway_mask.py` 默认已改回）；另两张得**假数字**。
20. **相机 = 跟随角色的近距低机位**（约 3~4 格远），**不是俯视全盘**。
21. **只有埃及有 `ditu*` 棋盘美术**，其余 7 图全包内确认没有 → 走兜底布局。
22. **小地图路线只能当拓扑参考**（`m_aiji.tga` 是 256×128 的 2:1 压扁示意图）→ 不能产坐标。

### E. 棋盘格数

23. **棋盘 = 94 格（2026-09-25 老板拍板，✅ 不再压缩）**。**111** = 早期拟合（偏密）；**94** =
    `aiji.r6m` 20 街区 ΣA，且 `1 + 22×4 + 5 = 94` 自洽。产 `aiji_tilepos.json` ←
    `tools/route_from_walkway.py`（`alpha=0.70`、`mode=quantile`）+ `build_map.py::EVENTS_OVERRIDE`。
    指标：→掩码中位 **0.4 px**、→中心线中位 **5.0 px**、离中线 >25 px **1/94**（旧 111 是 45/111）。
24. **坐标口径**：`x=(px/1024-0.5)*200`、`z=(py/1024-0.5)*200`；文件 `"u"/"v"` = `x/S+0.5`/`z/S+0.5`。

### F. 界面（UI）

> **完整内容（度量 / 槽位表 / 素材映射 / 刻意偏差 / 还缺什么）在 `docs/ui-audit.md`。改版式前先看它。**

25. **口径**：原版设计 **1024×768**；`07_牌桌.png` = **×1.5**；`UI_SCALE = 视口高 / 768`，截图 px
    **÷1.5 = native**。⚠️ 原版 4:3 / 我们 16:9 → 宽屏下 HUD **占屏比更小是正确行为**。
26. **原版 UI 其实有贴图**（旧记忆「都是程序绘制」**只对顶栏底条成立**）：面板底框 `other/atb.png`；
    右下 6 图标 `subc/*.png`；是/否 `other/{yes,no}_{up,dn}.png`。
27. **动作入口分两种，定位规则不同**（旧记忆「都在角色头顶」**错了**）：掷骰子 = **GO 钮 =
    固定屏幕位**（见 #40）；买地/升级 = **落点气泡 = 贴角色头顶**（`player_pos` →
    `unproject_position(pos + UP*2.0)`，⚠️ 必须锚世界点再投影）。铁律 #12 照旧。
28. **小地图底图 `m_<map>.png` 第 98 行往下是装饰蓝条** → 原版**裁蓝条、地形铺满整框**
    （`minimap.gd::TERRAIN_ROWS`）；标记仍按**全图 v(0..1) 映射整框**。
29. **角色头像三套** `uitex/player/roleN_*`：`_01.._04`（左下大头像）/`_21`（右侧列）/`_31`（随身物）。
    序号 **1..12 → role1..role9 / a / b / c**（**没有 role10/11/12**）。
30. **真字体 = `gbdata/unicode16/24.tft`（TNFT 点阵，已破 → `tools/r6_tft.py`）**，已设为
    `Window.theme.default_font`。顶栏数字**另用** `number1.tga`（❌ 别用细笔画的 `number.tga`）。
31. **没用上的 UI 素材**（后续直接拿）：`other/saybk.png`、`{buystock,auction,pet,pethouse,house,
    up_info,casino,form,option,gold}/`、`card/1..42_<名>.tga`、`roadobj/`、`event/`。
32. **GO 钮 = 两张残图叠出来的**（`labar/背景.png` 深蓝球 + `labar/go.png` 青球；**都贴边裁切**）
    → **只能按「可见区中心」对齐**；❌ 单用 `go.png` 会缺「G」的一竖 → `go_btn.png`(78×78)。
33. **是/否 = 两块半胶囊拼一整颗**（`yes` 只有左圆头、`no` 只有右圆头）→ `AtlasTexture` 裁透明边 +
    `separation=0` + `STRETCH_SCALE`(56×32)。❌ `KEEP_ASPECT_*` + 窄容器会把胶囊**裁掉一半**。

### G. 骰子 / 卡片 / 音效（2026-09-26）

34. **骰子颗数选择器上限 = 2**（`Sim.DICE_PER_ROLL_MAX`）：原版实机 **5 张截图**一致，GO 钮左侧
    固定 2 颗（上白选中 / 下灰未选），**从未出现第 3 颗**。默认 1 颗。
35. **骰子素材口径（旧记录错了）**：`labar/anim.tga` = **4×4 = 16 帧**（不是 8×2）；`labar/骰子.tga`
    = **6 个骰子面**（不是「两颗骰子」）。切分必须**零列分列 + 行均分 + 行优先**（上下 alpha 相连，
    `ndimage.label` 只得 3 块；按列遍历得 1,4,2,5,3,6）。
36. **`config/String.txt` = 原版 UI 文案唯一权威**（**UTF-8**）：卡片菜单 1/2/3、目标提示 1101..1106、
    卡说明 9001..9042、卡片夹 2010、**不可用原因码 60..70**。⚠️ **第 104 行编号写成 `02`** 与
    第 4 行 `2 = 锁定` **撞号** → 生成器**同 id 保留首次**（`_duplicate_ids`）→ `ui_strings.json`。
37. **卡片 42 张，39 张真生效**。`CARD_TARGET`（哪张卡点谁）是**推导表**，改效果必须同步改它。红卡/
    黑卡/复制卡在 `CARD_UNSUPPORTED`（**用了不消耗**）；`act_use_card` false **一律不消耗**。卡面
    `samples/card/<n>_<名>.tga` → `assets/card/<id>.png` + `index.json`（`badge` 语义未考证）。
38. **原版卡片界面版式没有证据** → 我们的是**重建版式**（底部手牌条 + 弹菜单 + 选目标 + 步数选择器），
    **属刻意偏差**，文案 100% 用原版。素材 128×128，**显示 100 native**；手牌条在「角色面板 → 小地图」
    间**自适应居中**，放不下等比缩（下限 62）。
39. **多格建筑占地仍不合并**：相邻两格盖满级房会穿插（议题 4 未做「占地预订」）。
40. **⭐ GO 钮不在角色头上**（推翻旧 #27 说法，2026-09-26）。原版实机 **4 张**截图量：角色站位不同，
    GO 球圆心**固定在归一化 (0.691, 0.599)** → **固定屏幕位**。**角色头顶那个蓝色圆盘是三岔路方向
    选择盘**（黄直行/蓝S/红Z），与掷骰无关。⚠️ 4:3 与 16:9 的归一化**不可换算** → 取老板实机标注
    `GO_ANCHOR_NORM = (0.782, 0.508)`；骰子选择器随之平移（挂球左缘）。
41. **⭐ 卡片可用性门禁**：原版确实有，原因码在 `String.txt` **60..70**（60 现金不足 / 61 不能使用 /
    62 当前位置没有地产 / **63 只能用于对手的地产**「（土神卡， 购地卡等）」/ 64 只能用于自己的 /
    65 没有建筑 / 66 不能放置道具 / 67 没有可组合的卡片 / 68 占地一格 / 69 体力不够 / 70 此时不能免费）。
    `Sim.card_usable(id, card_id) -> int`（0 = 能用）= ① 批注 + ② `_apply_card` 前置条件。
    UI：用不了 → **压暗** + 菜单「使用」**置灰**（必须给 `font_disabled_color`，Godot 默认字色近乎
    透明会让整条看不见）+ toast 原因。⚠️ **原版没有「卡→码」映射表 → 这是推导**。
    ⚠️ **走着时允许用卡**（停留卡 9040 就是边走边用），只有骰子卡 `pending_steps` 拒绝。
    ⚠️ 修掉静默 bug：以前 `_apply_card` 失败**不发事件** → UI 死寂（＝「点了没反应」）。
42. **⭐ 购地卡/土神卡语义**（2026-09-26 修正，旧实现写反了）：目标是**脚下的「对手的地产」**，
    不是「无主空地」（空地本来就能直接买 → 旧实现永远失败）。购地卡按**现值**
    （`Sim.plot_value()` = 地价 2000 + 已投入建造费）付给原主；土神卡不付钱。两张都先弹
    **原版「是│否」二次确认**（`_pop_mode = "card"`；「否」**只关框、不发 `pass`**，否则会把落地机会
    一起丢掉）。
43. **⭐ 音效 2D/3D 的含义**：`sndeffect.txt` 的分类 → **2D = 界面音 = 本机操作的听觉反馈，只给
    「当事人」听**；**3D = 场景空间音，人人可听**。023 骰子滚动声是 2D，所以不该听到电脑玩家掷骰。
    例外：006/007 结算画面全桌共见，保留全员播放。
    ❌ **3D 空间音仍未做**：`play_sfx_at` 的 `unit_size=12 / max_distance=120` 是旧值，对 200 世界
    单位的棋盘 + 300~400 单位外的相机会**直接静音** → 要用得先调到 ≈200 / ≈2000。
44. **⭐ 原版「逻辑全貌」不存在**（2026-09-26 定论）：包内**没有脚本**（`gfxscript/*.gbf` 是
    渲染着色器）；`rich6.exe`（688 KB 未加壳）**C++ 名 0 / RTTI 0 / 无 PDB**；`rich6.asm.txt` 是
    **线性扫描**（无函数边界、无交叉引用）。→ 核对算法只能**定点逆向**：**`tools/r6_re.py`**
    （capstone+pefile；`info`/`strs`/`xref <VA|off:偏移>`/`dis`/`calls`）。
    ⚠️ `executable-references.txt` 的 `0x0009DF4C` 是**文件偏移**，+0x400000 才是 VA。
    规模 **76 098 指令 / 1 020 个 call 目标**；另一个 AI 的 8 个地图函数地址 **7/8 命中**。
    已恢复：`config/card.txt` 加载函数 `0x41e78f`，**卡片记录结构体 0x230 = 560 字节**。
45. **⭐ 未对齐总表 = `docs/alignment-gap.md`**（问「还有哪里不对」先看它）。零实现的大块：
    股票/公司（**董事长 ≥60% 持股**、5 家虚拟公司、`Role.txt` 缺省公司）、小神仙（9 只 ×4 级 +
    6 特技 + **点券购买**）、**点券出口**、拍卖、新闻真身（甲 19 + 命运 19 + 丙 10 + 小画面）、
    乐透选号开奖、特殊建筑 9 种、路面物体 NPC（`roadobj/` 87 + `Info.txt` 71–78 + 乞丐）、
    小游戏（`gamespot/` 94）、存款利息、冠军结算、时间限制/难度、存读档等 9 族界面。
    ✅ **2026-09-26 下午已补掉「点券出口 + 小神仙」这两块 P0**（见 #46）；瓶颈转到
    **路面物体/神仙蛋**（小神仙已能升级，缺「魔戒」这类升级来源）。
    ⚠️ **`Info.txt`（1490 行）= 原版功能全图**（分区注释＝功能清单）——查「原版有什么」的首选。

## 关键路径

| 用途 | 路径 |
|------|------|
| 原版本体 / pck / 音频原件 | `F:\游戏\Rich6` / `gamedata.pck`（371 MB）/ `sound\`（**不在 pck 里**） |
| **原版明文 / 反汇编 / 定点逆向** | `docs/original-readable/installation/config/*.txt`（String/Card/House/Initvar_r/Roadevent/Role/Pet/Info…）；`docs/original-readable/disassembly/rich6.asm.txt`（线性扫描）；**`tools/r6_re.py`** |
| **两份「唯一清单」** | `docs/alignment-gap.md`（对齐度体检）· `docs/ui-audit.md`（界面度量/槽位/素材） |
| 解包 / 产物 | `tools/r6pck.py`（`info`/`list`/`extract`）→ `samples/`（203 MB，gitignore）；`docs/orig-logic/`、`docs/orig-scene/` |
| Godot / 可写副本 / 实机截图 | `D:\Godot\..._console.exe` / `F:\游戏\Rich6run\` / `docs/screenshots/orig/` |
| 游戏素材 / UI 贴图 / 字体 | `game/assets/**`（清单 `index.json`，`uitex/**` 458 张）/ `assets/ui/{hud,panel}/` / `fonts/` |
| 音频 / 中控 | `game/assets/audio/**`（`voice_map.json` 含 2D/3D 分类）；`core/audio.gd` |
| 场景 / 网格 / 地图原件 | `samples/scene/<map>/*.r6s`/`*.pol`/`*.r6m`；棋盘贴图 `ditu*.tga`+`ditan.tga`；`samples/{roadobj,news,gamespot,effect1,effects,event,particle}/` |
| 规则表 / 建筑 / 地图数据 | `rules/{realtime,houses,sfx,ui_strings}.json`；`assets/buildings/<id>.r6m`（48）；`game/data/maps/*.json`（`<map>_tilepos.json` **只有 aiji**） |

> **Godot 环境**：统一用 `D:\Godot\` 那份。⚠️ `godot`/`godot_console` 命令别名是坏的（0 字节文件）
> → 用完整路径。⚠️ **`PLAY.bat` 必须 GBK + CRLF**；别用 bash heredoc 写含 `D:\...` 的 bat。

## 命令 / 进度

**完整命令清单与进度在 `README.md`（不重复抄）。** 只记易忘的：

- `GODOT="D:\Godot\Godot_v4.7.2-stable_win64_console.exe"`；Python 用 **`.workbuddy/venv/Scripts/python.exe`**
  （有 numpy/pillow/scipy/capstone/pefile；binaries 下那个什么都没有）。
- 改 `game/assets/**` 或新增 `class_name` 后**必须** `--headless --path game --import` **跑两次**，
  否则报 "No loader found for resource"。
- **验 UI**：`"$GODOT" --path game --resolution 1280x720 -- --uishot`（8 张）。`--demo` 动作太密抓不到静止帧。
- ⚠️ **`_capture()` 是协程** → **必须 `await` 之后才改游戏状态**（否则抓帧时按钮已消失，rect 却正确）。
- ⚠️ **`_process` 也是协程** → `await` 期间 Godot 会**再起一次 `_process`**，两个实例并发。`--uishot`
  拍卡片确认框时并发实例抢先掷骰 → 角色进运动态 → 确认框被判过期收掉。→ 用活动锁挡住。
- GDScript **Variant 类型推断视为错误**（`var x := dict.get(k)` 不过）→ 写显式类型；`_sfx()` 形参用
  **`BaseButton`**。`board_view.gd` 是 **CRLF** → 用 Python 二进制读写。

**待做**（完整清单见 `docs/alignment-gap.md §5`）：议题4 占地预订；议题34-C/D（朝向 / 148 vs 100）；
`.pol` 网格未解出（地形无起伏）；`play_sfx_at` 参数未调 → 3D 空间音未做；三岔路方向盘；
破坏类卡棋盘点选 UI。P3 待逆：`.cvd`/`.cvdf`、`.a_q`。

**老板定的三项优先级（2026-09-25）**：① 对齐 UI（**已完成**）→ ② 放真实角色模型（`actor/roleN/`，
另有高清 `actor_h/`）→ ③ 接卡牌系统（**本轮已提前落地成可玩版**，39/42 生效）。

46. **⭐ 小神仙 + 点券出口（2026-09-26 下午已完成）**：
    - **数据**：`config/Pet.txt` = 9 只 × **4 级** × 三行（① 即时制**秒数** ② 回合制次数
      ③ **消耗点数**）；`String.txt` **2201..2210 = 技能名**（穷神技/梦游技/拆除技/免费技/
      土神技/加盖技/无敌技/骰子技/PK技）；`Info.txt` **202 = 上限 5 位**。
      → `tools/build_pet_data.py` → `game/data/rules/pets.json`。
    - **语义**（推断，已登记）：`秒数` = 发动后的**冷却**；`消耗点数` = **每次发动花的点券**；
      **购买价**取消耗点数第 1 级值（Info 203 的 `<NUMBER>` 原版没给）。
    - **9 种特技全实现**（`Sim._tick_pets()`：**抵达格子后**每只发动一次，扣点券 + 进冷却）。
      新增 effect 字段：`no_rent_until`（按秒的免租，与免费卡的按步数版**分开**）、
      `rent_pay_double_until`、`pet_max_dice`。
    - **卡片商店**：卡价 = **`Rules.card_badge` × 10**（10~50 点券，推断）；
      ⚠️ 曾发现磁盘上 `card/index.json` **根本没有 `badge` 字段**（旧产物没重跑）→ 已修。
    - **两店界面全是原版底图**（不用自己画）：`uitex/pethouse/{精灵屋=持有面板2×2,
      商店=货架2×2,浮动条}` + `uitex/other/cardshop(=8格2×4) `；`uitex/pet/<只>/{01-04=4级小头像,
      70-73=4级大图,30-33=施法特效,90/91=小图标}` + `星01-04=等级星`。
      `tools/build_pet_assets.py` 转素材 + 把**槽位坐标**写进 `assets/pets/index.json` 的 `slot` 表
      （**别把坐标硬编码进 gdscript**）。关闭用**右键 / ESC**（Info.txt 62 批注）。
47. **⭐ `config/Info.txt`（1490 行 / 1236 条）= 原版**过程消息**总表**，2026-09-26 才进管线
    （`tools/build_info_strings.py` → `game/data/rules/info_strings.json`）。
    ⚠️ **它的 id 空间与 `config/String.txt` 完全独立**（String 63 = 卡片原因码；
    Info 63 = 「今日乐透开奖」）→ `Rules.info_string()` / `ui_string()` 是**两个**函数。
    占位符 `<SOMEONE> <SOMEONE1/2> <NUMBER> <FLTNUM> <CARDNAME> <ROAD> <STOCKNAME/1/2> <BABYNAME>`
    → 用 `Rules.info_fill(id, {...})` 替换。
    ⚠️ 原版文本里的「反斜杠+n」是**两个字符**，生成器要转成真换行，否则 UI 上会显示字面 `
`。
