# 原版场景、建筑贴图和角色恢复（2026-09-26）

> 2026-09-27 更新：独立变换轨迹遗漏、逐帧跳变已修复，新增可手动编辑的七图场景。
> 当前编辑方法与动画机制以 [地图编辑说明](manual-map-editing.md) 为准；下文保留首轮记录。

## 本轮结果

保留接手时已有的股票、卡牌、新闻、拉霸、功能区与世界名牌改动。

| 地图 | 原版静态网格 | 导入的动画网格节点 | 原版道路格数 |
|---|---:|---:|---:|
| 埃及 aiji | 163 | 11 | 144 |
| 中国 china | 229 | 28 | 98 |
| 岛屿 island | 119 | 46 | 96 |
| 日本 japan | 171 | 17 | 124 |
| 巴黎 paris | 184 | 34 | 102 |
| 太空 space | 350 | 29 | 64 |
| 火车 train | 136 | 15 | 84 |

- 原版 R6SM 场景包含地形、环境建筑、树木及其他布景，不需要用一张平面地形图代替整个场景。
- 解析并导入 CVD 顶点动画和变换轨迹。埃及木乃伊包含 81 帧，周期约 13.333 秒；已验证动作和世界位置均随时间变化。
- 十二名角色的 `tris.a_q` 是 MD2 格式的变体，已导出原版模型、皮肤和动画序列。生产棋盘根据移动/停止/睡眠切换 `run/stan/slee`。
- 48 个可建造建筑重新导出，修复顶点起始偏移导致的 UV 错位。保留原版图集，不执行旧的 UV 拉伸和图集补边。
- 所有七图使用原版道路、Bezier 曲线、地块矩阵及小地图坐标。道路、建筑和环境应用同一世界变换，保留高度。
- 修复 `BoardView.sync` 中只有多人叠格分支才更新玩家目标位置的缩进错误。
- 地毯大小随地图的原始单位比例换算；雾色按地图读取，太空取消沙色雾。

## 关键逆向证据（修正旧结论）

### R6HS / R6SM

对应原版程序函数 `0x40a050`（网格）和 `0x409d60`（材质索引四叉树）。

R6HS v100 的顶点块从文件偏移 **128** 开始，每条 32 字节：

```
+0   float2 UV
+8   float3 normal
+20  float3 position
```

旧解析器从 144 开始，取 +4 的位置，恰好仍能读到正确位置；但 +16 的 UV 已读到下一条顶点。
因此“模型位置正确”不足以验证顶点块起点；旧文档关于“盒投影本身缺陷、每个面另有映射表”的判断应作废。

网格材料后接递归四叉树：三角数、16 位索引、3 个整数、6 个浮点数、4 个子树标志，随后递归子树。
新解析器读取整棵树并验证索引范围。七张 R6SM 的网格段均完整读取。

### CVD

对应函数 `0x4074d0` / `0x407550`（关键帧）、`0x407ba0`（节点树）、
`0x408660`（逐帧网格）、`0x408a70`（材质）。

```
cvdf + root_count
node:
  has_mesh: byte
  if has_mesh:
    translation keys: count + type byte + count * 44 bytes
    rotation keys:    count + type byte + count * 44 bytes
    scale keys:       count + type byte + count * 60 bytes
    uniform_scale: float
    frame_count, vertex_count
    frame_count * vertex_count * (UV2, normal3, position3)
    frame_times[frame_count]
    materials (flag byte, 20-byte parameters, texture64, triangle list)
    matrix16
  child_count + recursive children
```

原版加载器在根节点进行 X=-90 度变换；解析后的角色/环境坐标再统一进入地图变换。
导出器验证 CVD 完整消费到文件末尾，不能靠碰巧找到一个纹理字符串就宣布解析成功。

### 角色

MD2 表包含每帧 scale/translate、名称和压缩顶点，三角形分别索引位置和 UV。
导出时按位置索引/UV 索引组合拆分接缝；动画帧沿用同一组合。原版皮肤 V 方向需翻转。
角色文件夹 10–12 使用十六进制后缀 `rolea/roleb/rolec`。

## 可复现入口

需要本机 Python 环境内的 numpy、Pillow、scipy，以及已解包的 `samples/`。

```powershell
.workbuddy/venv/Scripts/python.exe tools/pol2obj.py pack samples/building game/assets/buildings
.workbuddy/venv/Scripts/python.exe tools/build_original_scenes.py
& D:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path game --editor --import --quit
& D:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path game -- --selftest
& D:\Godot\Godot_v4.7.2-stable_win64_console.exe --path game res://scenes/original_scene_probe.tscn
```

- 解析器：`tools/r6_scene_assets.py`。
- 场景、CVD、MD2 导出及七图数据生成：`tools/build_original_scenes.py`。
- 播放器：`game/scripts/ui/original_mesh.gd`。
- 统计清单：`docs/original-readable/scene-recovery/manifest.json`。
- 实机截图：`docs/screenshots/scene-recovery/`（七图、角色、木乃伊两帧、48 建筑）。
- 生成素材：`game/assets/original/`，遵循工程现有忽略规则，不提交原版素材；可由上述脚本重建。
- 旧 `build_map.py` 已保护七图的已验证道路，避免重新生成虚构路线覆盖它们。

## 验证与边界

- 玩法自检：263 通过，0 失败。修正中国地图的旧 96 格假数据断言为原版 98 格。
- 原测试一边要求埃及平台事件额外传送，一边又要求相邻入口/出口不互传，且事件测试实际使用中国地图；本轮修正测试夹具和矛盾断言，保留现有防重复传送实现。
- 七图道路接点最大误差均小于 0.000018 个棋盘单位；实机探针同时检查单人目标位置更新。
- 七图逐张截图检查，十二角色贴图检查，建筑完整加载检查。自检退出仍有既有 ObjectDB 资源释放告警，不能把它称为完全无告警。

以下尚不能宣称与原版逐帧一致，留待下一轮对照：

1. GAE 包含音效、触发和编排。本轮使用其同名 CVD 恢复视觉动画，未恢复 GAE 的完整触发时序和空间音效；只有声音的 GAE 不生成网格。
2. CVD 关键帧在离线采样时对轨迹数值作线性插值，未完整复现原引擎各种插值类型；运行时按源时间播放，角色固定 12 帧/秒。
3. 水面、喷泉及发光表面的专用混合/UV 动画着色尚未逐项恢复，目前使用原版纹理和网格，统一透明裁切材质。水色、透明度仍可能与原版不同。
4. 角色基础模型已替换；车辆切换、特殊卡牌动作、完整表情状态机没有在本轮新增。
5. 雾密度与角色显示比例是当前可见性调校值，不是已验证的原版精确参数。多格建筑的整合占地规则仍沿用当前工程实现。

这里提供的是根据二进制和反汇编恢复的格式说明与转换代码，不是声称找回原版完整源代码。
