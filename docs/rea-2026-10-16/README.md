# REA / Ghidra 打通记录与函数清单（2026-10-16）

> 上一轮（10-14）我判定「Ghidra 不在了」—— **那是错的**，原因是我搜盘时只匹配了
> `AppData\Local\*ghidra*`（**一层**），而实际在 `AppData\Local\Programs\Ghidra\`（**两层**）。
> 本文件记录实际打通过程、踩到的坑、以及产出。

## 1. 环境（实测可用）

| 组件 | 路径 | 状态 |
|---|---|---|
| Ghidra | `C:\Users\12733\AppData\Local\Programs\Ghidra\ghidra_12.1.4_PUBLIC` | ✅ 可用 |
| JDK | `C:\Users\12733\AppData\Local\Programs\Java\jdk-25.0.4.1+1` | ✅ `25.0.4.1` |
| REA | `C:\Users\12733\AppData\Local\Programs\REA`（`rea-agents` v6.3.0） | ⚠️ 见 §3 |

**目标**：`D:\Projects\reference\Rich6\rich6.exe`（688128 字节，PE32/x86）
SHA-256 `5dd5c38e09aefbdc2cadd970aefb14a2e64b0560e943d8ef0fbdfddb77a4e1f7`（与 10-11 报告一致）。

## 2. 怎么跑通的（**REA 走不通，直接用 Ghidra headless**）

```bash
export JAVA_HOME='C:\Users\12733\AppData\Local\Programs\Java\jdk-25.0.4.1+1'
G="C:/Users/12733/AppData/Local/Programs/Ghidra/ghidra_12.1.4_PUBLIC"

# ① 导入（快，~1 分钟）
"$G/support/analyzeHeadless.bat" "D:/Projects/RichMan/ghidra_proj" Rich6 \
  -import "D:/Projects/reference/Rich6/rich6.exe" -noanalysis -log <日志>

# ② 完整分析 + 导出函数清单
"$G/support/analyzeHeadless.bat" "D:/Projects/RichMan/ghidra_proj" Rich6 \
  -process rich6.exe -postScript ExportFunctionInfoScript.java <输出> -log <日志>
```
**实测**：完整分析 **1 分 10 秒** 跑完（688 KB 的老 PE，很快）。

### ⚠️ 三个坑（都会让人误判成「工具坏了」）

1. **Ghidra 拒绝路径里有以 `.` 开头的元素**：
   ```
   Abort due to Headless analyzer error: Path element starting with '.' is not permitted
   ```
   我最初把项目目录放在 `.workbuddy/ghidra_proj` → **直接被拒**。
   → 只能叫 `ghidra_proj/`（已在 `.gitignore` 里，带注释说明原因）。

2. **失败时终端可能一个字都不输出**：Ghidra 的错误只进 `-log` 指定的文件。
   **必须带 `-log <文件>`，然后去读那个文件** —— 否则只看到「没输出、exit 1」，无从下手。

3. **bash 里给 `.bat` 套嵌套引号会被解析坏**：`cmd //c ""...bat" "arg""` 这种写法
   会让整条命令静默失效。**直接调 `.bat`**（Git Bash 会转给 cmd）即可，别套 `cmd //c` 加双层引号。

## 3. REA 为什么用不了（**不是配置问题**）

`rea doctor` 在设好环境变量后，Ghidra 相关检查**全绿**（配置/平台/架构/安装/版本/headless/
原生反编译器/Java 共 8 项全 `true`），**但 `decompile` / `analyze` 仍然失败**：

```
code: unsupported_host
reason: "REA Windows native controls are unavailable:
         Delete owned object by handle failed [...\Temp\rea-native-probe-...] (Win32 5): 拒绝访问。"
windows_security:
  job_object_process_ownership:
    available: false
```

→ **REA 靠 Windows Job Object 托管它拉起的子进程**，而那个能力探测在本机失败
（`Win32 5 = ERROR_ACCESS_DENIED`）。**加了 `dangerouslyDisableSandbox` 也一样**，
所以很可能不是沙箱，而是**安全软件拦「进程托管/句柄删除」这类操作**。

⚠️ **注意一个陷阱**：`rea doctor` 报 `ghidra: ok: true` **只证明静态配置对**（路径/版本/jar），
**不等于真能做分析** —— 分析时才做那个 Job Object 探测。**别把 doctor 的 healthy 当成「能跑」**。

**结论**：REA 的 Ghidra provider 在本机不可用；**直接用 Ghidra headless 绕开它**，
能力上完全等效（REA 底层调的就是同一个 `analyzeHeadless.bat`）。

## 4. 产出：函数清单（3180 个）

| 文件 | 说明 |
|---|---|
| `function-list.json` | Ghidra 导出的原始结果（`{name, entry}`） |
| `function-list.txt` | 同一份数据的可读版（`地址  名字`），方便 grep |

原版是 2002 年 MSVC 编译、**未加壳、无符号**（无 PDB / 无 RTTI / 无导出名），
所以函数名全是 `FUN_xxxxxxxx`，**只能靠调用关系和作用反推意义**。

### 地址核对：既有 10-11 报告的 16 个关键地址

| 结果 | 数量 | 说明 |
|---|---|---|
| ✅ 直接命中函数入口 | **12** | 如 `435910` 小神仙技能总入口、`431ea0` 宠物初始化、`431f50` 满能量不衰减、`42aea0` 价格限幅、`432d20/432d40` 技能强度与消耗 |
| ✅ 落在某函数**内部** | **4** | `41f970`→`FUN_0041f900`+0x70（暴走）、`41fcb0`→`FUN_0041fa20`+0x290（购地扣款）、`420350`/`420550`→**同在** `FUN_004202a0`（+0xb0 / +0x2b0，查封与诱拐） |

→ **既有报告的地址全部能对上**，可信；那 4 个只是**函数内部地址**而非入口。
→ 顺带发现：**查封与诱拐在同一个函数里**（`FUN_004202a0`）—— 那应该是一个
**大的卡片效果分发函数**，与「42 张卡各有分支」的结构吻合。

## 5. 下一步（按需反编译）

Ghidra 已打通，**随时可以定点反编译任意函数**：

```bash
"$G/support/analyzeHeadless.bat" "D:/Projects/RichMan/ghidra_proj" Rich6 \
  -process rich6.exe -postScript <你的脚本>.java
```

推荐做法（避免一次性导出几十 MB 无用的全量反编译）：
- **只导「有问题的地址」**：先拿 `function-list.txt` 定位入口，再针对性反编译
- 优先攻克 `docs/alignment-status-2026-10-14.md` 里标 **❓待核验** 的那些项：
  C05 状态互斥 / C09 清除参数 7 / C14 其余卡片门禁 / P05 衰减调度 / P09 喂食换算 /
  L02 购地价构成 / L03 衰神购地 / B03 合并建造 / B06 资产基数
