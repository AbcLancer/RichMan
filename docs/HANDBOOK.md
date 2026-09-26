# RichMan6 Replica · 项目手册 & 手改指南

> 这份文档回答两件事：
> **① 这个项目现在是什么样** ② **我想改某个东西，该去哪个文件**。
>
> 相关文档（都在 `docs/`）：`iron-rules.md`（踩过的坑 / 铁律全文）·
> `alignment-gap.md`（**还没对齐的地方**）· `ui-audit.md`（界面逐项）·
> `decision-log.md`（每轮决策与依据）· `original-visual-reference.md`（画面参考）。
> 项目进度总表在仓库根目录的 `README.md`。

---

## 一、这是什么

复刻《大富翁6》（软星 2002）的**即时制玩法**，并重做联机部分。引擎 **Godot 4.x + GDScript**，
素材**复用原版安装目录**（`F:\游戏\Rich6`），运行时不依赖原版。

**设计上的一条硬规矩**：所有玩法数值都必须**溯源到原版配置**（`config/*.txt`），
不能凭感觉填。每个数值在 `game/data/**/*.json` 里都带 `_source` 字段写明出处。

---

## 二、跑起来 / 验收

```bash
# 玩（窗口 1600x900）
"D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path game --resolution 1600x900

# 逻辑自检（无窗口，263 条断言）
"…" --headless --path game -- --selftest

# 界面截图（16 张，出在仓库根目录 ui_shot_*.png）
"…" --path game --resolution 1280x720 -- --uishot

# 玩法演示截图（6 张 demo_shot_*.png）
"…" --path game --resolution 1280x720 -- --demo

# 棋盘对齐校验
"…" --headless --path game --script res://scripts/test/map_alignment.gd
```

或者直接双击根目录的 **`PLAY.bat`**。

⚠️ **改完 `game/assets/**` 或新增 `class_name` 之后，必须跑两次**
`"…" --headless --path game --import`（第一次生成 `.uid` / 导入资源，第二次才稳）。

---

## 三、目录地图

```
game/                      ← 真正跑的游戏（Godot 工程根）
  assets/                  ← 素材（从原版转出来的 png / ogg + index.json 索引）
  data/                    ← 规则与数据（全是 json，带 _source）
    maps/                  ← 每张地图一份：几何、格子、地价、街区…
    rules/                 ← 规则表：realtime / houses / pets / sfx / roles / 文案
  scripts/
    core/                  ← **玩法逻辑**（sim.gd 是心脏）+ 数据读取（rules.gd / map_data.gd）
    net/                   ← 联机（net.gd：动作 RPC + 快照同步）
    ui/                    ← 界面（app.gd 是总装 + 各个面板）
    test/                  ← 自检与校验脚本
tools/                     ← Python 数据管线（原版 → game/data、game/assets）
docs/                      ← 文档；screenshots/orig/ 是老板跑原版截的实机图
samples/                   ← 原版解包产物（远景素材、中间产物，不进 git）
```

---

## 四、⭐「我要手改 X，去哪个文件」

### 1. 音效 / 配音 / BGM

| 我想… | 去这里 |
|---|---|
| **换某个音效播的是哪个文件** | `game/data/rules/sfx.json` —— 这是**唯一权威**，每条都写了它是 2D（界面音）还是 3D（场景音）。改它的 `id` 就换文件 |
| **调音量 / 频道** | `game/scripts/core/audio.gd` |
| **换 BGM** | `sfx.json` 的 `bgm` 段；原版一曲接一曲**不是循环**，用 `Audio.play_bgm_playlist()`，别用 `play_bgm()` |
| **加新音频文件** | 原版音频在 **`F:\游戏\Rich6\sound\`**（⚠️ **不在 `gamedata.pck` 里**，是明文目录）→ 跑 `tools/build_audio_assets.py` → 出到 `game/assets/audio/` |
| **看语音（角色 / 小神仙说什么）** | `game/assets/audio/voice_map.json`（`roles` / `pets` / `cards` 三段，含每条的**场景名**：发特技 / 平时 / 悲伤…） |
| **试听全部音效** | 双击根目录 `OPEN_SFX_AUDITION.bat` |
| **某处代码播什么音** | 搜 `Audio.play_sfx` / `_ev_sfx(` （后者按事件类型统一派发，规则写在注释里） |

> ⚠️ 原版**没有**「UI 什么时候播哪个音」的配置表（物体级的有，在 `anim/*.gae` 内嵌）。
> 已实测：`1=按钮`、`2=确认`、`95=底噪`。其余是推断，见 `alignment-gap.md`。

### 2. 模型 / 贴图 / 立绘

| 我想… | 去这里 |
|---|---|
| **换角色立绘** | `game/assets/roles/role1.png … role9.png / rolea/b/c.png`（12 个角色，**没有 role10/11/12**）。⚠️ 原版还有一套**高清立绘**在安装目录的 `actor_h/`，**目前没入库** —— 想用高清版要先加进 `tools/build_*_assets.py` |
| **换骰子贴图** | `game/assets/dice/`（`anim` = 4×4 十六帧旋转 / `face` = 6 个面） |
| **换棋盘地面贴图** | `game/assets/terrain/`；原版三张的差别见铁律 #17（**对齐只看 `ditu`**） |
| **换房屋模型** | `game/assets/buildings/`（按 `House.txt` 的主题 × 等级） |
| **换路边物体 / 事件格图标** | `game/assets/roadobj/`（含 `event/` 19 个 64×64 图标） |
| **换 UI 贴图** | `game/assets/ui/**`（`panel/` 顶栏与按钮、`shop/` 各面板底图）+ `game/assets/uitex/**`（原版 UI 大图，458 张） |
| **换小神仙图** | `game/assets/pets/<id>/01..04.png`（4 级） |
| **换卡面** | `game/assets/card/`（`index.json` 里有每张卡的文件名、大小、文案 id、徽章数） |
| **加新素材** | 原版图放 `samples/uitex/...` → 跑对应的 `tools/build_*_assets.py` |

> 素材索引（哪个文件叫什么、多大、对应哪个 id）都在**同目录的 `index.json`** 里，
> 代码是读索引而不是写死路径 —— 所以**换图只要换文件 + 重跑 import**。

### 3. 玩法数值（最常改的一类）

**全部在 `game/data/rules/` 和 `game/data/maps/`，改 json 即可，不用动代码。**

| 我想改… | 文件 | 关键字段 |
|---|---|---|
| **时间尺度 / 天数 / 体力** | `rules/realtime.json` | `time.*`（一天几秒）、`stamina.*` |
| **起始现金 / 目标额** | `rules/realtime.json` | `player.*` |
| **房租 / 地价 / 过路费** | `rules/houses.json`（按主题×等级）+ `maps/*.json` 的地价系数 | `rent*` |
| **房屋升级上限** | `rules/houses.json` | 住宅 12 / 商业 15 / 工业 9 级（**别写死 4**） |
| **卡片效果** | `rules/realtime.json` 的 `card` 段（23 项，来自 `Initvar_r.txt` 的 `Card_*`） | 例：`hongka_price = 0.2` |
| **股票** | `rules/realtime.json` 的 `economy.stock` / `player_company` | 手续费、每日波动、分红率 |
| **拉霸赔率** | 同上 `events.casino_*` | `top_rate` / `middle_rate` |
| **全局新闻效果** | 同上 `news` 段（14 种） | `stock_down` / `all_price_up` … |
| **小神仙数值** | `rules/pets.json`（9 只 × 4 级：秒数 / 次数 / 消耗点数） | — |
| **角色与公司名** | `rules/roles.json`（`Role.txt` 的 12 角色 × 缺省公司 × AI 性格权重） | `company` 就是股票里的公司名 |
| **某张地图的格子 / 街道 / 地价 / 路边物体几率** | `game/data/maps/<map>.json` | `tiles` / `streets` / `road_items` |
| **文案**（界面标签 / 过程消息） | `rules/ui_strings.json`（`String.txt` 216 条）· `rules/info_strings.json`（`Info.txt` 1236 条） | ⚠️ **两套 id 空间完全独立**，别混 |

> 这些 json 都是 **`tools/build_*.py` 从原版配置生成**的。想**追根溯源**就看每个文件的
> `_source` 字段；想**批量重生成**就跑对应的工具（见下节）。

### 4. 逻辑代码

| 我想改… | 去这里 | 说明 |
|---|---|---|
| **一条玩法规则** | `game/scripts/core/sim.gd` | **权威逻辑全在这一个文件**（服务端 / 单机共用）。掷骰、走路、买地、收租、卡片、小神仙、股票、拉霸…都在这 |
| 加一个新的**动作**（玩家能做的事） | ① `sim.gd` 写 `act_xxx()` ② `scripts/net/net.gd` 的 `_apply_action` 里加一个 `match` 分支 | 联机时**必须两步都做**，否则只有单机能用 |
| 加一个**新事件**（广播给 UI） | `sim.gd` 里 `_ev("事件名", 玩家, {数据})` → `ui/app.gd` 的 `_on_game_event` 里加分支 | 事件是 sim 与 ui 之间**唯一的通信方式** |
| **界面布局 / 新面板** | `game/scripts/ui/app.gd`（总装）+ `stock_panel.gd` / `casino_panel.gd` / `stock_chart.gd` / `board_view.gd`（各面板） | ⚠️ `board_view.gd` 是 **CRLF**，编辑时别把行尾改了 |
| **棋盘怎么画** | `game/scripts/ui/board_view.gd` | 相机、地形、贴花、房屋、路边物体、角色移动都在这里 |
| **网络同步** | `game/scripts/net/net.gd` | 动作走 RPC、状态走快照；**快照里没带的字段，联机时就不会同步** |
| **AI 电脑玩家** | `sim.gd` 里搜 `_ai_` / `_bot` | 目前是极简版；`rules/roles.json` 的 `ai_aggr`（害人 / 买股票 / 买地）数据已就位但**还没接** |

> ⚠️ **铁律 #4**：`sim.gd`（`Sim`）里**不许出现渲染 / 网络代码** —— 它是服务端与客户端共用的。
> 想加表现层的东西，用 `_ev(...)` 发出去，在 `app.gd` 里画。

### 5. 想换「数值从哪来」

数值链是：**原版配置 → `tools/build_*.py` → `game/data/**/*.json` → `rules.gd` → `sim.gd`**。

```bash
# 重新生成全部规则表（改了原版配置或解析逻辑之后）
.workbuddy/venv/Scripts/python.exe tools/build_game_assets.py     # 总入口（会串起各分项）

# 只重生成某一块
.workbuddy/venv/Scripts/python.exe tools/build_role_data.py       # 角色表（Role.txt）
.workbuddy/venv/Scripts/python.exe tools/build_pet_data.py        # 小神仙（Pet.txt）
.workbuddy/venv/Scripts/python.exe tools/build_house_rules.py     # 房屋（House.txt）
.workbuddy/venv/Scripts/python.exe tools/build_info_strings.py    # 文案（Info.txt）
.workbuddy/venv/Scripts/python.exe tools/build_news_assets.py     # 全局新闻插画
```

**Python 一律用 `.workbuddy/venv/Scripts/python.exe`**（里面有 numpy / pillow / scipy / capstone / pefile）。

---

## 五、原版资料在哪（想查「原版是怎么做的」）

| 内容 | 路径 |
|---|---|
| **原版明文配置**（所有 `.txt`，UTF-8） | `docs/original-readable/installation/config/` ← **查数值先来这** |
| **原版功能全图**（1490 行的 `Info.txt` 已解析版） | `game/data/rules/info_strings.json`（1236 条，带 `kind` = NEWS / MANSAY / PETSAY / MINE…） |
| **反汇编 / 定点逆向** | `docs/original-readable/disassembly/rich6.asm.txt` + 工具 **`tools/r6_re.py`**（`info` / `strs` / `xref <地址>` / `dis`） |
| **老板跑原版截的实机图** | `docs/screenshots/orig/records/`（对照清单 `docs/orig-records-audit.md`） |
| **原版解包的素材 / 场景** | `samples/**`（203 MB，不进 git；用 `tools/r6pck.py` 重新解） |

> ⚠️ **原版没有脚本**（`*.gbf` 是着色器），`rich6.exe` 零符号，所以复杂逻辑只能
> 「定点逆向 + 老板实机观察」两条腿走。**老板的实机截图是最高权威**。

---

## 六、改完怎么验

```bash
GODOT="D:/Godot/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path game --import                      # 必须跑（改资源后跑两次）
"$GODOT" --headless --path game -- --selftest                 # 期望：通过 263 / 失败 0
"$GODOT" --path game --resolution 1280x720 -- --uishot        # 出 16 张 ui_shot_*.png
```

⚠️ `--uishot` 的张数**偶尔会波动**（同一命令 11~16 张）—— 是 `_process` 协程竞态（老问题），
**重跑即可**，不是代码坏了。

---

## 七、几条最容易踩的坑（全文见 `iron-rules.md`）

1. **数值必须溯源**：先在 `docs/original-readable/installation/config/*.txt` 里找到，再进 json。
2. **即时制只取 `_r` 分支**（`Initvar_r.txt`），别用回合制的 `Initvar_t.txt`。
3. **`sim.gd` 里不许有渲染 / 网络代码**。
4. **UI 口径**：原版 **1024×768**；原版截图的像素 **÷1.5** 才是 native；代码里一律乘 `_ui_scale`。
5. **两个 id 空间别混**：`String.txt`（界面标签，id 60~1106）≠ `Info.txt`（过程消息，id 3001+）。
6. **改 `.gd` 别用 bash heredoc + Python replace 写含 `\n` 的字符串**会变成真换行 → 用编辑器。
7. **`--uishot` 抓帧是协程**：必须 `await _capture(...)` 之后才改游戏状态，否则抓到的是空帧。
