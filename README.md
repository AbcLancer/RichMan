# RichMan6 Replica —— 大富翁6 即时制复刻

复刻经典游戏《大富翁6》（软星 Softstar, 2002），**重点是即时制玩法**，并重做联机功能。

- **素材**：复用原版本体资源（`F:\游戏\Rich6\gamedata.pck`，已完整解包）
- **引擎**：Godot 4.x + GDScript
- **联机**：权威服务端架构（房主即服务端），后续扩展为独立大厅
- **美术**：P0 用程序化占位，P3 阶段做画面升级

---

## 怎么打开

### 方式一：双击 `PLAY.bat`（推荐）

在工程根目录双击 **`PLAY.bat`** 即可。它会自动按以下顺序找 Godot，找到哪个用哪个：

1. `D:\Godot\Godot_v4.7.2-stable_win64.exe` ← 当前用的
2. `.\Godot\`（放在工程里也行）
3. `.\.tools\`
4. `%LOCALAPPDATA%\Microsoft\WinGet\Packages\...`

窗口分辨率 1440×810。四个位置都没有时会提示，并告诉你放哪里。

> ⚠️ **别敲 `godot` 命令** —— winget 非管理员安装建不出符号链接，
> `%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe` 是个 0 字节空文件，
> 敲下去**不报错也不启动**，很容易误判成 Godot 坏了。

### 方式二：Godot 编辑器

打开 Godot 4.7.2 → 「导入」→ 选择 `D:\Projects\RichMan\game\project.godot` → 打开后按 **F5**。
（推荐后续做画面调试时用这个。）

### 进去之后怎么玩

1. 主菜单填昵称 → 选地图 → 点 **▶ 单人练习（对阵 3 名电脑）** —— 立刻开局，无需配置
2. 想联机：一方点 **创建房间（主机）**，记下显示的局域网 IP；
   另一方填该 IP 点 **加入房间**；房主点 **开始游戏**
3. 对局中：**空格**或点「掷骰子」前进；走到空地会亮起「购买地产」；站在自己地上可「升级地产」
4. 左下角是实时事件日志，右上角是四家资产对比

### 命令行（等价）

```bash
GODOT="D:/Godot/Godot_v4.7.2-stable_win64_console.exe"   # 本项目统一用这一份
"$GODOT" --path game --resolution 1440x810
```

---

## 首次使用：准备数据

若 `game/data/maps/` 为空，或想重新解包原版素材：

```bash
PY=C:/Users/12733/.workbuddy/binaries/python/versions/3.13.12/python.exe

# 1. 解包原版资源
$PY tools/r6pck.py extract "F:/游戏/Rich6/gamedata.pck" samples --filter scene/

# 2. 由原版数据生成地图（街道名 / 公司 / 坐标均为原版真实数据）
$PY tools/build_map.py
```

---

## 验证方式（两层，都可复现）

### 1. 无头逻辑自检 —— 45 项断言全通过

```bash
GODOT="D:/Godot/Godot_v4.7.2-stable_win64_console.exe"   # 本项目统一用这一份
"$GODOT" --headless --path game -- --selftest
```

覆盖：原版数值表 / 地图数据 / **连续移动（格内进度 0.5 的精确验证）** / 买地与过路费收支平衡 /
两类计时器语义（无敌=绝对时刻 vs 免费卡=剩余步数） / 破产判定与地产释放 / 静止 25 秒睡眠。

完整输出留档：`docs/selftest-run.txt`

### 2. 演示模式离屏截图

```bash
"$GODOT" --path game --resolution 1280x720 -- --demo
```

自动开一局（1 人 + 3 电脑），按脚本操作并把截图写到工程根目录。
证据：`docs/screenshots/`（开局 / 移动中 / 买地与升级 / 过路费与事件点 / 四人对局）

### 3. 单人练习冒烟测试（走生产入口）

```bash
"$GODOT" --path game --resolution 1280x720 -- --solotest
```

**直接调用主菜单上那个「单人练习」按钮的同一个函数 `_on_solo()`**，
断言开局后是 4 名玩家 / 3 个本地 AI / 逻辑处于运行态 / 地图为 china。

> 之所以单独做这一步：demo 模式走的是另一条代码路径，
> 用它来自证「按钮能开起局」是不成立的。验收必须打在真实入口上。
> 输出留档：`docs/solotest-run.txt`

### 4. 主菜单截图

```bash
"$GODOT" --path game --resolution 1280x720 -- --menushot
```

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
