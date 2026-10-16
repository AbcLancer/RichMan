# 批 2 · C12 改建 / C13 土地公 / B01 建筑表示 —— 实现侧对比

> 承接 `batch1-卡片与状态.md`（原版证据）与 `card-crd-解析.md`（卡片表）。
> 本轮目标：把这三项的**我们的实现**读完，判定能否直接改。

---

## B01 · 建筑表示 —— **部分已对齐，但 `level` 在兼职**

原版：`FUN_0041ce10(&DAT_004ece18, 类别, 尺寸, 局部等级)` **三个参数独立**。

我们的 `plots[]` 现状（`sim.gd:250` 一带 + 注释）：
```gdscript
## 原版 0x41fa20 把普通建筑类别 0..2 改成特殊类别 3..5，保留
## 地块尺寸，特殊建筑内部等级固定为 1。House.txt 的 d1/d2/d3
## 用 1/2/3 表示占地尺寸，故这里的 level 必须等于 footprint。
```

**这段注释本身就是问题**：**「这里的 level 必须等于 footprint」= `level` 被用来装尺寸**。

实际字段：
| 我们 | 含义 | 评价 |
|---|---|---|
| `type` | 类别（`uptown/shop/industry/special1..3`） | ✅ 对应原版的「类别」 |
| `footprint` | 占地尺寸（1..3） | ✅ 对应原版的「尺寸」 |
| **`building_grade`** | **局部等级** | ✅ **已经独立了** |
| **`level`** | **= `footprint`（尺寸）** | ❌ **兼职，语义混淆** |

**→ 判定：`building_grade` 已经把「局部等级」独立出来了，方向是对的**；
剩下的是**把 `level` 这个旧字段的语义清理掉**（或明确它只是 `footprint` 的别名）。

⚠️ **但这是纯内部重构，玩法上看不出差别** —— **风险大于收益**，
而且**存档里存着 `level`**，改它要做迁移。
**建议：暂不改，只在文档里记清楚「`level` == `footprint`，不是等级」**，
等真正需要（比如出现「一级重工厂」这种跨尺寸显示）时再动。

---

## C12 · 改建 —— **大方向已对**

原版：`FUN_0041fa20` 用 `FUN_0041ce10(表, 类别=p%3+3, 尺寸=p/3+1, 局部等级=1)`，
前置「建筑对象 `+0x30 == 0` 则失败」。

我们的 `rebuild_plan()`（`sim.gd:250`）：
```gdscript
if not plots.has(index) or int(plots[index].get("level", 0)) <= 0: return {}
if int(plots[index].get("owner", -1)) < 0: return {}                 # ← 要有主
if not Rules.primary_types().has(str(plots[index].get("type", ""))): return {}
if not ["special1","special2","special3"].has(house_type): return {} # ← 只允许三种特殊类别
var old_space := Rules.house_footprint(Rules.house_file(old_type, old_level))
var space := clampi(int(plots[index].get("footprint", old_space)), 1, 3)
var grade := Rules.house_grade(house_type, space)                     # ← 按「类别+尺寸」查表
if grade.is_empty() or Rules.house_footprint(str(grade.get("file",""))) != space: return {}
return {"type": house_type, "level": space, "name": ..., "cost": 0,
        "building_grade": 1, "footprint": space, "members": ...}      # ← building_grade = 1 ✅
```

**逐条对照**：

| 原版 | 我们 | 判定 |
|---|---|---|
| 类别 = `p%3+3`（3..5） | 只接受 `special1/2/3` | ✅ 等价（三种特殊类别） |
| 尺寸 = `p/3+1` | `clampi(footprint, 1, 3)` + 校验 grade 的 footprint 一致 | ✅ **甚至更严**（多做了尺寸一致性校验） |
| **局部等级恒为 1** | **`building_grade: 1`** | ✅ **对齐** |
| 建筑 `+0x30 == 0` → 失败 | `level <= 0` / `owner < 0` 则返回 `{}` | ✅ 语义对应 |
| 保留原尺寸 | `clampi(footprint, 1, 3)` 继承 | ✅ 对齐 |

**→ 判定：`C12 大方向已对齐，没有发现确定差异`** ✅

（唯一遗留：`return` 里那个 `"level": space` 是 B01 说的兼职字段，不是 C12 的问题。）

---

## C13 · 土地公 —— **❌ 本项没做完**

我在 `sim.gd` 里搜 `tudigong`，**只找到一处**：`CARD_TARGET` 里的目标类型映射
（`"tudigong": "plot"`）。**效果实现不在这个标识符下** ——
可能写在 `_apply_card()` 的某个 `match` 分支里用了别的名字，或者走了通用的「换所有权」路径。

**所以我没能完成 C13 的对比**。**这是本轮欠的账**。

**已知的原版要求**（来自 `batch1`，可直接作为验收标准）：
1. 业主字段 = 地块对象 `+0x34`；**`业主 != 自己` 才执行**（含「无主」是否算可抢）
2. 换所有权走 **`FUN_0042b510(位置x, 位置y, 新业主)`**
3. **全程不扣钱**（土地公免费）—— 这条**报告早就说过**，也是我们目前的行为
4. 土地公按**「脚下地块」**，不是全图最佳敌产（报告 C13 标注「已有对应/边界待查」）

**下一步**：在 `_apply_card()` 里按「`plot` 类 + 不扣钱 + 换 owner」的特征反查那段代码。

---

## 本轮结论汇总

| 项 | 判定 |
|---|---|
| **B01 建筑表示** | `building_grade` 已独立 ✅；`level` 兼职尺寸 ⚠️ **但属内部重构、风险大于收益 → 暂不改** |
| **C12 改建** | **大方向已对齐，未发现确定差异** ✅（局部等级=1 已实现） |
| **C13 土地公** | ❌ **未完成**（在 `sim.gd` 里没找到实现位置）—— 欠账，下一轮补 |

**所以本轮改代码的部分：0 处** —— C12/B01 判定为「已对齐 / 不值得改」，C13 还没做完。
不是偷懒：**改一个判定为「已对齐」的东西只会引入风险**。
