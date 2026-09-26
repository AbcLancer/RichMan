"""
check_minimap_fill.py —— 判定「原版小地图底图该怎么铺」的四联对比图。

背景：`game/assets/uitex/subc/m_<map>.png` 是 256×128，但第 98 行往下是一条
**装饰蓝条、不是地形**。所以有三种铺法可选，必须挑出原版用的那种：

    A 整图铺满            → 底部会露出蓝条
    B 只取地形 99 行铺满   → ✅ 与原版实机逐特征吻合（这就是结论）
    C 等比居中（letterbox）→ 底部留黑边

产出 `.workbuddy/tmp/ui/mini_compare.png`（原版实机 + A/B/C 四联）。
结论已写进 `docs/ui-audit.md` §4 与 `game/scripts/ui/minimap.gd::TERRAIN_ROWS`。
"""
from PIL import Image, ImageDraw

orig = Image.open("docs/screenshots/orig/07_牌桌.png").convert("RGB")
omap = orig.crop((1099, 862, 1532, 1086))          # 原版小地图内区（截图px）

mm = Image.open("game/assets/uitex/subc/m_aiji.png").convert("RGB")
print("m_aiji", mm.size)

# 候选 A：整图铺满
A = mm.resize(omap.size, Image.BILINEAR)
# 候选 B：只取上面 96 行（地形区）铺满
B = mm.crop((0, 0, 256, 96)).resize(omap.size, Image.BILINEAR)
# 候选 C：整图按等比（letterbox，我们的现状）
C = Image.new("RGB", omap.size, (0, 0, 0))
s = min(omap.width / 256, omap.height / 128)
C.paste(mm.resize((int(256 * s), int(128 * s)), Image.BILINEAR), (0, 0))

tiles = [("原版实机", omap), ("A 整图铺满", A), ("B 只取地形96行铺满", B), ("C 等比居中(现状)", C)]
Z = 2
CW = omap.width * Z + 12
H = (omap.height * Z + 26) * len(tiles) + 10
sheet = Image.new("RGB", (CW, H), (26, 26, 30))
d = ImageDraw.Draw(sheet)
y = 6
for name, im in tiles:
    d.text((6, y), name, fill=(255, 240, 120))
    y += 20
    sheet.paste(im.resize((im.width * Z, im.height * Z), Image.NEAREST), (6, y))
    y += im.height * Z + 8
sheet.save(".workbuddy/tmp/ui/mini_compare.png")
print("saved", sheet.size)
