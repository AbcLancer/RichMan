# MEMORY.md —— RichMan（大富翁6 即时制复刻）长期项目笔记

## 一句话

复刻《大富翁6》（软星 2002）的**即时制玩法**并重做联机；素材复用原版本体
`F:\游戏\Rich6`。引擎 **Godot 4.x + GDScript**。

## 铁律

1. **所有玩法数值必须溯源到原版配置**，不许凭感觉写。
   原版参数表在 `F:\游戏\Rich6\config\`，即时制用 `Initvar_r.txt`、回合制用 `Initvar_t.txt`。
   工程内对应 `game/data/rules/realtime.json`，每条都带 `_source` 与 `_comment`。
2. **即时制 ≠ 回合制换算**。原版注释给的基准是 `1 天 = 24 秒`，但很多参数两套不等比
   （无敌卡即时制 72 秒 / 回合制 1 天）。**整表只取 `_r` 分支。**
3. **区分两类计时器**：绝对时刻（`_until = time + N` 秒）vs 剩余步数（`_steps = N`）。
   混用会让手感完全错乱。
4. **`Sim` 类不得引入渲染或网络代码** —— 服务端与客户端共用同一份玩法逻辑，
   这是换传输层零成本的前提。
5. 素材版权属软星，**仅限个人学习研究，不得商用分发**。

## 关键资产路径

| 用途 | 路径 |
|------|------|
| 原版本体 | `F:\游戏\Rich6` |
| 资源包 | `F:\游戏\Rich6\gamedata.pck`（371 MB / 2143 文件） |
| 解包工具 | `tools/r6pck.py`（`info` / `list` / `extract`） |
| 地图生成 | `tools/build_map.py` → `game/data/maps/*.json` |
| 解包产物 | `samples/`（203 MB，**已 gitignore**） |
| Godot 可执行 | `D:\Godot\Godot_v4.7.2-stable_win64_console.exe`（老板自备，本项目统一用这份） |

> **Godot 环境（2026-09-25 实测）**
> 工程统一用 `D:\Godot\` 下老板自己下载的那份：
> - `Godot_v4.7.2-stable_win64.exe`（180 MB）—— GUI 版，`PLAY.bat` 用它
> - `Godot_v4.7.2-stable_win64_console.exe`（198 KB）—— **跑脚本/无头验收一律用这个**，stdout 才拿得到
>
> 与 winget 装的那份 **MD5 完全一致**（`2afa3142b68f7758755dc6015c54cbd8`），可互换。
> winget 路径（备用）：`%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\`
>
> ⚠️ **`godot` / `godot_console` 命令别名是坏的**：winget 非管理员安装建不出符号链接，
> `…\WinGet\Links\godot.exe` 是 **0 字节空文件**，敲下去不报错也不启动（PATH 里确实加了
> Links 目录，所以更容易误判）。**用完整路径，或直接双击 `PLAY.bat`。**
>
> ⚠️ **`PLAY.bat` 必须存成 GBK + CRLF**，不能是 UTF-8。UTF-8 的中文会被 cmd 按 GBK
> 解析错位，把命令行从中间切断（症状：`'7.2' 不是内部或外部命令`），启动器直接失效。
> 另外**不要用 bash heredoc 写含 `D:\...` 内容的 bat** —— MSYS2 会把 `\` 改写成 `/`。
> 正确做法：Write 工具写 UTF-8 临时文件 → Python 读 UTF-8 转码写 GBK → 删临时文件。

## 常用命令

```bash
PY=C:/Users/12733/.workbuddy/binaries/python/versions/3.13.12/python.exe
GODOT="$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe"

$PY tools/r6pck.py extract "F:/游戏/Rich6/gamedata.pck" samples --filter scene/
$PY tools/build_map.py
"$GODOT" --headless --path game --import          # 新增 class_name 后必须跑
"$GODOT" --headless --path game -- --selftest      # 45 项逻辑断言
"$GODOT" --path game --resolution 1280x720 -- --demo   # 离屏截图
```

## Godot 踩坑（本机实测）

- GDScript 把 **「Variant 类型推断」视为错误**：`var x := dict.get(k)` 编译不过，
  必须 `var x: T = ...` 或 `str()/int()` 包一层。
- 新增带 `class_name` 的文件后**必须重跑 `--import`**，否则报 `Identifier not declared`。
- 渲染后端用 `gl_compatibility`（棋盘游戏够用且离屏验收稳）。
- 自检夹具**不要替被测代码补状态**（曾因夹具设了 `running` 而漏掉一个致命 bug）。

## 进度

P0 垂直切片已完成并通过验证（自检 45/45 + 4 张截图）。
详见 `README.md` 的复刻进度清单与 `docs/` 下四份文档。
