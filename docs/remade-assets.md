# 新版素材与对照启动器

## 使用方式

双击项目根目录的 `COMPARE_ASSETS.bat`，选择同屏对照或单独启动游戏。

| 入口 | 使用的素材 |
| --- | --- |
| 原素材 | 原版解包转换的模型和贴图 |
| 上一轮高清修复 | 本地超分辨率贴图、PN 网格细分 |
| 新版重绘 | 新角色图集、独立细分网格、环境细节材质 |

`PLAY_REMADE.bat` 直接启动新版。已有 `PLAY.bat` 和 `PLAY_ORIGINAL_GRAPHICS.bat` 继续可用。游戏窗口标题标明素材版本，三个入口共享当前玩法代码。

同屏窗口可以选择 12 个角色、12 种占地标志物、7 张地图，播放动作、转动、缩放。三列使用相同相机。地图的“转动”调整相机绕场景的角度；标志物背后的双色格用于观察半透明。ESC 退出。

## 本轮新增内容与范围

- 12 张角色图集重新绘制为 1024×1024：参照原版服装、配色和图集，增加头发、衣料、车辆面板的清晰细节。
- 12 个角色独立模型：两轮考虑硬边的 Loop 细分，三角形数为原来的 16 倍。这次也改变原顶点位置，圆润轮廓。UV 接缝按全部动画帧的相同顶点轨迹共享几何处理；继续使用原版动作及 GPU 帧间插值。
- 12 个标志物增加法线和材质。钻石保留切面法线，使用半透明和反光。
- 草、沙、石、木四种新绘制材质，镜像拼接保证循环边缘连续，在七张地图静态环境表面补充近距离细节。
- 修复连续半透明：原来统一镂空模式丢弃了中间透明度；现在区分不透明、镂空、半透明。钻石源图 alpha 为 38～209，按原透明度绘制。动画半透明使用独立着色器。

半透明修复应用到三个入口，所以“原素材”使用原资产加正确的透明渲染。新版角色会有重绘风格变化，不能视为逐像素复原。

**本轮没有逐一重新建模环境建筑。** 环境曲面继续复用上一轮增强网格；建筑主体和 UI 继续使用上一轮高清资产。新增环境内容为细节材质层。原道路、布局、手动建筑位置和烘焙明暗继续保留。

## 素材与对应关系

| 路径 | 用途 |
| --- | --- |
| `game/assets/remade/manifest.json` | 原资产路径到新版模型/贴图的映射 |
| `game/assets/remade/actors/` | 12 个独立角色网格，保留全部原动画帧 |
| `game/assets/remade/textures/role*.png` | 运行时角色图集，alpha 从原图重建 |
| `game/assets/remade/markers/` | 占地标志物，独立切面法线 |
| `game/assets/remade/materials/` | 草、沙、石、木细节材质 |
| `game/assets/remade/art/` | 本轮实际生成的原始绘图结果 |
| `game/data/render/materials.json` | 源图透明模式分析结果 |
| `game/scripts/ui/visual_quality.gd` | 版本选择、缓存和缺失/过期回退 |
| `game/scripts/ui/original_mesh.gd` | 模型与材质加载 |
| `game/scripts/ui/remade_actor.gdshader` | 新版角色动画和材质 |
| `game/scripts/ui/remade_environment.gdshader` | 环境细节层 |

手动场景仍在 `game/scenes/maps/*.tscn` 修改，见 `manual-map-editing.md`。生成新版素材不会重写这些场景；原版安装目录没有被修改。

## 本地重建

```powershell
.workbuddy/venv/Scripts/python.exe tools/build_material_rules.py
.workbuddy/venv/Scripts/python.exe tools/build_remade_models.py
.workbuddy/venv/Scripts/python.exe tools/install_remade_assets.py
```

模型步骤需要 NumPy，安装步骤需要 Pillow。安装脚本读取已保存的绘图，恢复原 alpha，生成运行图集、循环环境贴图和清单，不调用在线服务。清单检查原素材摘要，手动改过的源素材不会被过期替代图覆盖。

绘图参考、实际提示词和保存位置记录在 `remade-art-prompts.json`。提示词要求保留原人物设计及图集位置；实际验收以模型渲染为准，不能仅凭提示词认定 UV 绝对不变。

素材被原有仓库忽略规则排除，但已保存在本地工作区。重新克隆时须复制 `game/assets/remade/art/`，准备原版转换素材及上一轮增强素材，再执行以上步骤；也可以直接备份整个 `game/assets/remade/`。

## 验证

- 当前游戏自检：280 通过、0 失败；退出时仍有既有 ObjectDB/资源清理提示。
- 三版本同屏实机渲染：12 个角色、钻石连续 alpha、七张地图通过。
- 清单 184 项模型映射、1157 项贴图映射，目标路径全部存在；本轮独立网格为角色与标志物，其余为已有环境增强网格。
- 启动器 PowerShell 语法检查通过，新版主游戏自动演示正常开局并完成截图。
- 截图：`docs/screenshots/remade-assets/`，包括角色、钻石、七地图及 `gameplay-aiji.png`。

可重跑实机验收：

```powershell
& D:\Godot\Godot_v4.7.2-stable_win64_console.exe --path game res://scenes/asset_comparison.tscn -- --comparison-check
```
