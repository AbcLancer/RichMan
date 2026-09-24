# gamedata.pck 格式规范（逆向确认）

> 对象：`F:\游戏\Rich6\gamedata.pck`，389,288,419 字节（371.3 MB）
> 状态：**已完全解开，解包/完整性校验 100% 通过**
> 工具：`tools/r6pck.py`

## 文件总体布局

```
┌─────────────────────────────────────────────┐
│ Header      9 字节                            │
│   +0  char[4] "PCK\0"                        │
│   +4  u32     unknown = 548609 (0x85F01)     │
│   +8  u8      0x00                            │
├─────────────────────────────────────────────┤
│ Directory   N × 264 字节，自 offset 8 起      │
│             N = 2143                          │
│             占 565,760 字节                   │
├─────────────────────────────────────────────┤
│ Data        自 offset 565,761 起，连续存放     │
│             388,722,658 字节（370.7 MB）      │
└─────────────────────────────────────────────┘
```

> 注：目录项步长固定 264 字节，但名字自 `entry_base + 1` 起。目录实际覆盖
> `[8, 8 + 2143×264) = [8, 565760)`，数据区自 565761 起，中间 1 字节对齐填充。

## 目录项结构（264 字节）

```
偏移      类型      说明
+0        u8        flag = 0
+1        char[]    GBK 文件名，NUL 结尾（最长 254 字节）
+...      bytes     零填充，直至尾部 8 字节
+256      u8        pad = 0
+257      u32 LE    data_offset   数据在包内的绝对偏移
+261      u24 LE    data_size     数据长度（3 字节，最大 16 MB）
```

## 校验方式（决定性证据）

数据区**未压缩、连续无缝隙**，满足：

```
entry[i].offset + entry[i].size == entry[i+1].offset
```

实测前 3 项：

| idx | name | offset | size | off+size |
|-----|------|--------|------|----------|
| 0 | actor/role1/qXX20.tga | 565761 | 196652 | **762413** |
| 1 | actor/role1/tris.a_q  | 762413 | 241080 | **1003493** |
| 2 | actor/role2/aaa.txt   | 1003493 | 133926 | 1137419 |

全表 2143 项连续性校验：**0 处断裂**。

## 资源构成

| 扩展名 | 数量 | 用途 |
|--------|------|------|
| `.tga` | 1323 | 贴图（未压缩真彩，含 RGBA 32bit） |
| `.cvd` / `.cvdf` | 154 | 顶点/模型数据 |
| `.pol` | 115 | 多边形数据 |
| `.psd` | 97 | **美术源文件**（Photoshop） |
| `.max` | 78 | **美术源文件**（3ds Max） |
| `.txt` | 60 | 角色模型/骨骼二进制（非文本） |
| `.gae` / `.gbf` | 100 | 特效脚本 |
| `.a_q` | 24 | 角色三角形数据 |
| `.r6m` / `.r6s` | 18 | **地图数据** |

顶层目录：`scene`(638) `uitex`(469) `building`(370) `effect1`(121) `effects`(106)
`gamespot`(94) `roadobj`(87) `actor_h`(63) `actor`(62) `card`(42) `news`(38) `gfxscript`(22) `event`(19)

## 八张官方地图

| 地图 | 文件 | 地图数据 | 场景数据 |
|------|------|----------|----------|
| 埃及 | scene/aiji/* | 33 KB | 650 KB |
| 中国 | scene/china/* | 26 KB | 771 KB |
| 岛屿 | scene/island/* | 23 KB | 372 KB |
| 日本 | scene/japan/* | 27 KB | 341 KB |
| 巴黎 | scene/paris/* | 27 KB | 558 KB |
| 太空 | scene/space/* | 23 KB | 511 KB |
| 火车 | scene/train/* | 24 KB | 578 KB |
| 测试 | scene/trybuild/* | 19 KB | 1.5 KB |

## 工具用法

```bash
PY=C:/Users/12733/.workbuddy/binaries/python/versions/3.13.12/python.exe
$PY tools/r6pck.py info    "F:/游戏/Rich6/gamedata.pck"
$PY tools/r6pck.py list    "F:/游戏/Rich6/gamedata.pck" -o docs/pck_filelist.txt
$PY tools/r6pck.py extract "F:/游戏/Rich6/gamedata.pck" out/ --filter scene/china
```

## 已知缺口（待后续逆向）

1. `.r6m` / `.r6s` 地图格式 —— **复刻玩法的关键**，尚未解析
2. `.cvd` / `.cvdf` / `.pol` 模型格式 —— 影响 3D 化重制路径
3. `.gae` / `.gbf` 特效脚本 —— 属视觉层，优先级低
