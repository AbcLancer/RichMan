# 地图模型对应关系、手动摆放与动画（2026-09-27）

## 手动摆放：直接打开这七个场景

在 Godot 中打开 `game/project.godot`，然后双击对应文件：

| 地图 | 可编辑场景 |
|---|---|
| 中国 | `game/scenes/maps/china.tscn` |
| 埃及 | `game/scenes/maps/aiji.tscn` |
| 日本 | `game/scenes/maps/japan.tscn` |
| 巴黎 | `game/scenes/maps/paris.tscn` |
| 岛屿 | `game/scenes/maps/island.tscn` |
| 太空 | `game/scenes/maps/space.tscn` |
| 火车 | `game/scenes/maps/train.tscn` |

1. 场景树中的 **Environment** 是地形、建筑、树木等静态物体；**Animations** 是场景动画，按原版文件名分组。
2. 在三维视图选中建筑，按 **F** 聚焦；使用移动、旋转、缩放工具，或右侧 Inspector → Transform 精确输入。
3. **Y 是高度，X/Z 是地面方向。** 数字采用当前游戏棋盘单位。模型中心已移到自身附近，操作轴不再全部挤在世界原点。
4. 暂时不想显示的物体，在 Inspector → Visibility 关闭 Visible；重复物体可以删除。复制已有物体可用 Ctrl+D。
5. Ctrl+S 保存，重新进入该地图查看结果。游戏优先加载这些场景。正在运行的对局不会自动热更新。
6. 灯笼龙在中国场景的 **Animations/longdeng**，它包含十个模型部分。移动父节点会整体移动龙及其飞行路线；避免只移动其中一盏灯笼。

`Environment/Box01__0` 等名称来自原版模型名加源序号。原版很多物体确实都叫 Box01，这不是导出器识别出的中文建筑名称；选中画面里的物体比猜名字更可靠。

**只移动装饰物，不会改变道路、地块或玩法坐标。** 地产建筑由玩家状态动态生成，不能在静态地图场景里修改后就改变其购买位置。也不要为了调整一栋建筑而移动整个地图根节点。

## 对应关系在哪里

| 用途 | 文件/入口 |
|---|---|
| 手动环境布局，游戏优先读取 | `game/scenes/maps/<地图>.tscn` |
| 场景加载及原版模型播放器 | `game/scripts/ui/original_mesh.gd` → `load_scene`、`setup` |
| 棋盘调用、主角选模型、动作切换 | `game/scripts/ui/board_view.gd` → `_build_ground`、`_create_player`、`sync` |
| 原版静态模型清单 | `game/assets/original/scenes/<地图>/scene.json` 的 `meshes` |
| 原版场景动画清单 | 同一个 JSON 的 `animations` |
| 每个模型的定义 | 场景节点 Inspector 的 **Definition Path** 指向的 JSON |
| 模型二进制、纹理和动画时间 | 上述定义的 `mesh`、`surfaces[].texture`、`times`、`speed` |
| 主角 | `game/assets/original/actors/role1.json` 至 `role12.json`；玩家的 `role` 决定选哪个 |
| 可购买建筑 | `game/scripts/ui/building_lib.gd` + `game/data/rules/houses.json` + `game/assets/buildings/index.json` |
| 地产建筑实际摆放 | `board_view.gd` 的 `_apply_building_model` → `MapData.plot_transform` |
| 道路/地块/小地图坐标 | `game/data/maps/<地图>_tilepos.json` + `game/scripts/core/map_data.gd` |
| 场景节点与原版文件的对照表 | `docs/original-readable/scene-recovery/object-catalog.json` |

例如灯笼龙来源为 `samples/scene/china/anim/longdeng.cvd`，导出成
`longdeng_0.r6v` 至 `longdeng_9.r6v`；十个节点归在同一个 `longdeng` 父节点下。
静态物体定义带 `source` 和 `source_index`，可从场景节点反查原版 `.r6s` 的第几个网格。

不要直接改 `game/assets/original/.../scene.json` 来摆放：它是生成清单，下次导出会覆盖。
`game/scenes/maps/*.tscn` 是手动编辑层；生成器发现文件已存在就保留它，模型再导出也不覆盖你的布局。
材质和网格由定义加载，编辑器保存时只保存节点布局/定义，不把临时 GPU 资源塞入场景文件。

## 灯笼龙为什么不动，动画为什么卡

上一轮导出存在两个独立问题，已修复：

1. **灯笼龙只有一帧网格，但有独立变换动画。** 十个部分的平移、旋转、缩放轨迹有约 101 个关键帧，周期约 16.667 秒。旧代码只在网格帧的时间采样，漏掉了这些轨迹。现在采样时间取网格、当前节点和祖先变换轨迹的并集；这一修复应用于所有地图。
2. **播放器逐帧跳变，没有补间。** 原来主角每秒取 12 帧，环境模型按原始稀疏关键帧跳变，还限制了更新频率。现在保留动作时长，在每个渲染帧内平滑插值相邻姿态。

补间在 `original_animation.gdshader` 中执行，GPU 从浮点纹理读取两帧顶点。
每帧只更新帧号和插值权重，不再重建 ArrayMesh。主角的动作节奏仍按 12 个源帧/秒解释，这不再意味着画面只更新 12 次/秒。
灯笼龙原版 `longdeng.ani` 还有 `set_speed(0.3)`，目前也读入了这一速度参数；单轮播放约 55.56 秒，不应人为加速成 16.7 秒。

### 验证

- 七张地图实机加载和道路检查通过；48 个建筑加载通过。
- 专项检查十个灯笼龙节点都有多帧轨迹和实际位移。
- 主角在 1/60 秒处的帧内插值权重为 0.2，不再停在源帧上。
- 验证动画过程中 Mesh 资源保持不变。
- 手动移动灯笼龙后保存临时场景、重新加载，Transform 保持一致；没有序列化生成网格和 GPU 纹理。
- 检查入口：`game/scenes/animation_probe.tscn`。

这解决了稀疏关键帧导致的顿挫，并不保证任何硬件/负载下都达到 60 FPS。原版 GAE 的完整编排、水面特殊混合及插值曲线种类仍未全部复原。

## 重新生成

```powershell
.workbuddy/venv/Scripts/python.exe tools/build_original_scenes.py
.workbuddy/venv/Scripts/python.exe tools/create_editable_scenes.py
```

第二条只创建尚不存在的地图场景，同时更新对照表，不会覆盖已有手动布局。
如确实想恢复某张图的原始布局，先把自己修改过的 `.tscn` 另存备份，再移走该文件后运行第二条。
