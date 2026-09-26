extends Control
class_name StockChart
## 股价**走势折线图**（原版股票面板里「走势」按钮打开的那个）。
##
## 数据 = `Sim.stock_history(公司名)`（每天开盘时追加一天，最多 60 天）。
## 自己 `_draw()` 画折线 —— 原版这张图没有底图素材，是程序绘制的。

var series: Array = []          # [float, ...]
var line_color := Color8(36, 88, 196)
var fill_color := Color8(150, 200, 250, 90)


func set_series(v: Array) -> void:
	series = v
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	# 背景网格（4 条横线）
	var g := Color8(150, 180, 220, 110)
	for i in range(5):
		var y := h * float(i) / 4.0
		draw_line(Vector2(0, y), Vector2(w, y), g, 1.0)
	if series.size() < 2:
		# 数据太少就只写一行提示
		draw_string(ThemeDB.fallback_font, Vector2(4, h * 0.55), "（数据不足）",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color8(90, 110, 150))
		return
	var lo := INF
	var hi := -INF
	for v in series:
		lo = minf(lo, float(v))
		hi = maxf(hi, float(v))
	if hi - lo < 0.001:
		hi = lo + 1.0
	var pts := PackedVector2Array()
	for i in range(series.size()):
		var x := w * float(i) / float(series.size() - 1)
		var y := h - h * 0.88 * (float(series[i]) - lo) / (hi - lo) - h * 0.06
		pts.append(Vector2(x, y))
	# 折线下方淡淡填一层，看起来更像行情图
	var poly := PackedVector2Array(pts)
	poly.append(Vector2(w, h))
	poly.append(Vector2(0, h))
	draw_colored_polygon(poly, fill_color)
	draw_polyline(pts, line_color, 2.0)
	# 最高 / 最低价标注
	draw_string(ThemeDB.fallback_font, Vector2(2, 11), "%.1f" % hi,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color8(190, 40, 40))
	draw_string(ThemeDB.fallback_font, Vector2(2, h - 3), "%.1f" % lo,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color8(20, 130, 60))
