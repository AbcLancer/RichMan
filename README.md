# RichMan6 Replica —— 大富翁6 即时制复刻

复刻经典游戏《大富翁6》（软星 Softstar, 2002），**重点是即时制玩法**，并重做联机功能。

- **素材**：复用原版本体资源（`F:\游戏\Rich6\gamedata.pck`，已完整解包）
- **引擎**：Godot 4.x + GDScript
- **联机**：权威服务端架构（房主即服务端），后续扩展为独立大厅
- **美术**：P0 用程序化占位，P3 阶段做画面升级

---

## 快速开始

```bash
# 1. 解包原版资源（首次运行）
PY=C:/Users/12733/.workbuddy/binaries/python/versions/3.13.12/python.exe
$PY tools/r6pck.py extract "F:/游戏/Rich6/gamedata.pck" samples --filter scene/

# 2. 由原版数据生成地图（街道名/公司/坐标均为原版真实数据）
$PY tools/build_map.py

# 3. 用 Godot 打开工程
#    工程目录：D:\Projects\RichMan\game
```

**联机**：
- 一方点「创建房间（主机）」，记下显示的局域网 IP
- 另一方填入该 IP，点「加入房间」
- 房主点「开始游戏」

---

## 验证方式（两层，都可复现）

### 1. 无头逻辑自检 —— 45 项断言全通过

```bash
GODOT="C:/Users/12733/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path game -- --selftest
```

覆盖：原版数值表 / 地图数据 / **连续移动（格内进度 0.5 的精确验证）** / 买地与过路费收支平衡 /
两类计时器语义（无敌=绝对时刻 vs 免费卡=剩余步数） / 破产判定与地产释放 / 静止 25 秒睡眠。

完整输出留档：`docs/selftest-run.txt`

### 2. 演示模式离屏截图

```bash
"$GODOT" --path game --resolution 1280x720 -- --demo
```

自动开一局（人类 + 电脑对手），按脚本操作并把截图写到工程根目录。
证据：`docs/screenshots/`（开局 / 移动中 / 买地与升级 / 过路费与事件点）

---

## 目录结构

```
RichMan/
├─ docs/
│  ├─ recon-report.md      技术侦察报告（本体画像、网络栈、玩法数据）
│  ├─ pck-format.md        gamedata.pck 格式规范（已完全逆向）
│  └─ gameplay-realtime.md 即时制玩法设计说明（数值依据全溯源）
├─ tools/
│  ├─ r6pck.py             资源包解包器（info / list / extract）
│  ├─ r6map.py             地图文件结构分析器
│  └─ build_map.py         由原版数据生成工程地图
├─ game/                   Godot 工程
│  ├─ data/
│  │  ├─ rules/realtime.json   即时制数值（源自 Initvar_r.txt）
│  │  └─ maps/*.json           8 张官方地图（源自 scene/*/）
│  ├─ scripts/
│  │  ├─ core/
│  │  │  ├─ rules.gd       数值单例（autoload）
│  │  │  ├─ map_data.gd    地图加载
│  │  │  └─ sim.gd         权威模拟（即时制核心）
│  │  ├─ net/net.gd        联机层（autoload）
│  │  └─ ui/
│  │     ├─ app.gd         根控制器（菜单/大厅/对局）
│  │     └─ board_view.gd  3D 棋盘表现层
│  └─ scenes/main.tscn     入口场景
└─ samples/                解包出的原版素材（git 忽略）
```

---

## 架构

```
      客户端 A                房主（= 权威服务端）              客户端 B
   ┌──────────┐            ┌───────────────────┐            ┌──────────┐
   │ 输入采集 │            │   Sim.step(dt)    │            │ 输入采集 │
   │ 状态渲染 │  ──意图──▶ │  20 Hz 逻辑帧      │ ◀──意图── │ 状态渲染 │
   │ 插值显示 │  ◀─快照──  │  10 Hz 状态广播    │  ──快照──▶ │ 插值显示 │
   └──────────┘            └───────────────────┘            └──────────┘
```

**关键设计**：`Sim` 类**不含任何渲染与网络代码**，因此在服务端和客户端行为完全一致。
换传输层（P2 → 独立大厅/专用服务器）时只需替换 `net.gd`，玩法逻辑零改动。

---

## 复刻进度

- [x] **P0-1** 资源包逆向与解包工具
- [x] **P0-2** 原版玩法数值提取（`realtime.json`）
- [x] **P0-3** 8 张官方地图数据生成
- [x] **P0-4** 即时制权威模拟（连续移动 / 买地 / 过路费 / 破产）
- [x] **P0-5** 联机层（ENet，房主权威）
- [x] **P0-6** 3D 棋盘 + HUD
- [x] **P0-7** 逻辑自检（45 项断言）+ 离屏截图验收
- [ ] **P0-8** 双机联机实测（需老板在两台机器上跑）
- [ ] **P1** 42 张卡牌 / 16 事件点 / 9 精灵 / 股票 / 新闻
- [ ] **P1** `.r6m` 地图逐字节还原（当前为原版数据重构）
- [ ] **P2** 独立大厅服务器 / 断线重连 / 观战
- [ ] **P3** 画面升级（原版 TGA 贴图 + `.max` 源文件 3D 化）

### 已知问题

- `.r6m` 地图文件只解析了表头（相机参数）与街道名表，**棋盘网格拓扑仍是重构而非还原**。
  完整结构：`R6MP` 魔数 → 渲染参数 → 场景名 → 街道表 → 4×4 变换矩阵 → 16 字节网格记录数组。
- 棋子/建筑仍为几何体占位，尚未接入原版 TGA 贴图。
- 联机未做客户端预测，高延迟下操作手感会有延迟（P0 阶段可接受，状态量小）。

---

## 版权声明

原版素材版权归软星科技（Softstar Entertainment Inc.）所有。
本项目**仅供个人学习与研究**，不得用于商业用途或公开分发。
