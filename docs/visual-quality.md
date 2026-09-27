# 素材高清化：第一轮

默认运行 `PLAY.bat` 使用增强素材。`PLAY_ORIGINAL_GRAPHICS.bat` 可切回原素材和原版点阵字体，方便对照。两种模式共用游戏规则、地图布局和动画时间。

## 已完成

| 范围 | 处理 |
| --- | --- |
| 12 个主角 | PN 曲面细分，三角面数量为原来的 16 倍；每个动作帧对应同一套顶点；补充每帧平滑法线和柔和明暗 |
| 78 个环境动画部件 | 木乃伊、狗头兵、考古人物、鸟、海豚、鲸鱼、牛、树、灯笼龙、鲤鱼旗等，面数为原来的 4 倍 |
| 82 个静态圆形部件 | 原版 Sphere / Cylinder / Tube / Cone 物体做曲面细分；建筑的直边、道路和地形高度保留 |
| 角色贴图 | 256×256 → 1024×1024，保留 UV 图集布局 |
| 七张地图、环境、玩家建筑 | 原贴图超分辨率；小图通常放大 4 倍，1024 原图放大至 2048，避免每张地面都使用 4096 贴图 |
| UI | 头像、按钮、卡牌、骰子图集、小地图、数字等高清化；普通文字使用可缩放字体，顶栏继续用原版数字造型 |
| 渲染 | 4× MSAA，16× 各向异性过滤，3D 贴图生成 mipmap；建筑补充面法线 |

当前清单覆盖 **1157 个 PNG 来源路径**，相同内容共用 **872 张高清图**。12 个角色网格约 182 MiB，160 个环境部件约 48 MiB，高清 PNG 约 486 MiB；引擎导入缓存另计。纹理复用缓存限制为约 256 MiB，当前场景仍在使用的纹理会由材质继续持有。

这轮增加的是曲面采样和细节重建，没有新增手工雕刻的配件、头发束或完整重制模型。低分辨率原图中已经丢失的小字和纹理，不能保证还原成准确的新细节。

## 原素材与增强素材在哪里

- 原素材：`game/assets/original/`、`game/assets/buildings/`、`game/assets/ui/` 等原目录，均未被高清图覆盖。
- 增强素材：`game/assets/enhanced/actors/`、`scenery/`、`textures/`。
- 对应关系：`game/assets/enhanced/manifest.json`。`meshes` 和 `textures` 是原路径到增强路径的映射；`texture_sizes` 存原 UI 图的逻辑尺寸；`source_hashes` / `mesh_hashes` 用于避免使用过期增强素材。
- 渲染入口：`game/scripts/ui/visual_quality.gd`；角色及环境网格由 `original_mesh.gd` 加载，玩家建筑由 `building_lib.gd` 加载。
- 手动地图场景：`game/scenes/maps/*.tscn`。高清化不改这些场景的节点位置、旋转或缩放；手动摆放方式继续参考 `docs/manual-map-editing.md`。

源文件改变后，重启游戏会检测增强结果是否过期，过期则退回源素材。重新跑下面的处理步骤即可更新增强结果。增强素材缺失时也会自动使用源素材。

UI 高清图的像素尺寸增加，但 `ImageTexture.set_size_override()` 保留原逻辑尺寸，因此骰子帧的裁切位置、小地图裁切高度、按钮大小和九宫格边距无需乘以 4。一般中文字体使用系统中的 Microsoft YaHei / Noto Sans CJK SC / sans-serif，保持现有字号和布局。

## 重新生成

在项目根目录运行，先完成原素材转换，再进行增强：

```powershell
.workbuddy/venv/Scripts/python.exe tools/build_enhanced_models.py
.workbuddy/venv/Scripts/python.exe tools/build_enhanced_models.py --environment
.workbuddy/venv/Scripts/python.exe tools/enhance_textures.py
& D:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless --path game --editor --import
```

模型处理仅依赖 numpy。贴图处理依赖 Pillow、numpy、scipy，以及 `.tools/quality/realesrgan/realesrgan-ncnn-vulkan.exe`。本机已安装官方便携版；其他机器可从 [Real-ESRGAN 官方说明](https://github.com/xinntao/Real-ESRGAN/blob/master/README.md#portable-executable-files-ncnn) 下载 Windows 包，解压到同一目录。也可以用 `--tool` 指定程序路径、`--gpu` 指定显卡。

贴图按角色 → 地图与环境 → UI 的顺序处理。角色使用 `realesrgan-x4plus-anime`，环境使用 `realesrgan-x4plus`，UI 使用 `realesr-animevideov3`。修复结果与 Lanczos 图混合，并去除低频颜色偏移；透明度始终来自原图。中间结果可缓存，重复执行会跳过已处理图。

增强资源和原版解包资源一样，被仓库忽略规则排除；脚本和加载代码在仓库内，实际素材保存在本地工作区。重新克隆项目时需要重新生成。

## 网格格式

原版转换文件仍为 R6V1。增强网格使用 R6V2：魔数、帧数、顶点数、材质数、UV、各帧坐标、各帧法线、各材质索引。法线和坐标均通过 GPU 在相邻动作帧间插值，不在每帧重建网格。UV 接缝按完整动作轨迹判断共享几何位置，硬边和开放边不做曲率拉弯；原顶点在全部动作帧中的位置保持不变。

## 验证与对照

- 现有游戏自检：269 通过、0 失败。
- `res://scenes/visual_quality_probe.tscn`：12 角色、动画网格复用、UI 逻辑尺寸、七张地图实机渲染。
- `res://scenes/animation_probe.tscn`：灯笼龙、角色帧间插值，以及手动场景保存。
- 贴图检查：原透明度重建一致，输出边长增加 2～4 倍。
- 对照截图：`docs/screenshots/visual-quality/role1-comparison.png`、`characters_original.png`、`characters_enhanced.png`；七张地图截图、UI 和卡牌截图也在该目录。

曾用生成式图像编辑试做钱夫人图集，但输出改变了五官与透明区域，已弃用。当前实际接入的贴图全部使用用户确认的本地超分辨率处理。
