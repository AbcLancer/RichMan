# 占地标志与连地建造（2026-09-27）

## 怎么使用

购买空地后，地产框内会出现当前所有者角色的原版标志。首次建设后隐藏；拆回空地后恢复，过户后改为新主人的标志。

同一原版地块网格内，拥有连续两块或三块空地后，再抵达其中一块并选择建设类型：

- 一联地：1×1 建筑的第一级。
- 二联地：2×2 建筑的第一级，例如一级重工厂。
- 三联地：3×3 建筑的第一级，例如一级工业区（`c0301`，工业序列第 7 级，表内造价 6000）。

选择界面显示实际建筑名、联地数及造价。随后再次抵达可继续升级。
已有小建筑跨入更大占地档位，也必须拥有所需相邻空地。升级卡和免费升级不能绕过土地归属条件。

当前实现按原版街区网格寻找能够容纳目标模型的范围，优先选择可用的最大空地组合；不跨街区，不吞并他人的地或旁边已有的其他建筑。
这是根据截图需求、原版地块矩阵和 House.txt 尺寸表实现的规则；候选范围的选择顺序尚未与原版可执行程序逐项确认。

## 原版标志对应表

| 角色 | 原版模型 |
|---|---|
| 钱夫人 | diamond.pol |
| 阿土伯 | hat.pol |
| 宫本宝藏 | knife.pol |
| 乌咪 | plume.pol |
| 孙小美 | shoe.pol |
| 金贝贝 | nipple.pol |
| 巴克力 | key.pol |
| 沙隆巴斯 | can.pol |
| 舞美拉 | mike.pol |
| DDR | ufo.pol |
| 爱丽丝 | wing.pol |
| 奇奇 | gear.pol |

角色名以 `game/data/rules/roles.json` 为准；映射读取该文件的 `marker` 字段，不按玩家颜色猜测。
源资源位于 `samples/actor/rolemark/`。重新生成：

```powershell
.workbuddy/venv/Scripts/python.exe tools/build_role_markers.py
```

## 实现位置

- `game/scripts/core/plot_assembly.gd`：不改状态的建设预览；服务端和客户端使用同一个尺寸/归属判定。
- `game/scripts/core/sim.gd`：确认资金与抵达机会后原子提交合并；普通建设和强制升级共用校验。快照保留 anchor、members、footprint、build_cell。
- `game/scripts/core/map_data.gd`：按确定的网格起点定位建筑，避免靠近边缘时盲目移动大模型。
- `game/scripts/ui/board_view.gd`：只在 anchor 处显示一栋建筑和一个完整地产框；空地显示角色标志。
- `game/scripts/ui/app.gd`：建设提示和房型选择显示实际组合的建筑及价格。

合并后的各路格共享同一处地产状态。过户整体生效；范围降级和新闻倍率按地产去重。
降级后仍保留合并土地；完全拆成空地时拆回各自空地，恢复每格的标志。

## 验证

- 专项探针 `game/scenes/plot_assembly_probe.tscn`：三联地建造、6000 元造价、资金不足无半途改动、一次抵达不能重复建造、快照恢复、从成员路格升级、范围伤害只降一次、整体过户、邻地归属和已有建筑限制、实际模型及标志加载。
- 现有玩法自检：263 通过 / 0 失败。
- 自检中跨入 2×2 住宅的测试补上了相邻自有空地条件；没有取消抵达、费用或卡牌断言。
- 实机截图：`docs/screenshots/scene-recovery/merged-industry.png`。
