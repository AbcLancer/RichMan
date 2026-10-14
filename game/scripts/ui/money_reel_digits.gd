extends HBoxContainer
class_name MoneyReelDigits
## Six clipped red reels with yellow digits, based on the supplied original frame.
## Reel timing is a presentation approximation, not a recovered native constant.
var text := "000000"
var elapsed := 0.0
var scale_factor := 1.0
var reels: Array[Control] = []

func setup(ui_scale: float) -> void:
	scale_factor = ui_scale
	add_theme_constant_override("separation", maxi(1, int(3 * ui_scale)))
	for i in range(6):
		var cell := Panel.new()
		cell.name = "Reel%d" % i
		cell.clip_contents = true
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.custom_minimum_size = Vector2(33, 50) * ui_scale
		var style := StyleBoxFlat.new()
		style.bg_color = Color8(218, 37, 32)
		style.border_color = Color8(138, 76, 17)
		style.set_border_width_all(maxi(1, int(2 * ui_scale)))
		cell.add_theme_stylebox_override("panel", style)
		add_child(cell)
		reels.append(cell)
		for j in range(2):
			var digit := Label.new()
			digit.add_theme_font_size_override("font_size", maxi(26, int(round(43 * ui_scale))))
			digit.add_theme_color_override("font_color", Color8(255, 247, 31))
			digit.add_theme_color_override("font_outline_color", Color8(121, 29, 21))
			digit.add_theme_constant_override("outline_size", maxi(2, int(round(3 * ui_scale))))
			digit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			digit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			digit.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(digit)

func roll(amount: int) -> void:
	text = "%06d" % clampi(amount, 0, 999999)
	elapsed = 0.0

func _process(delta: float) -> void:
	elapsed += delta
	for i in range(reels.size()):
		var cell := reels[i]
		var turns := 18 + i * 3
		var fraction := clampf(elapsed / (.55 + i * .08), 0.0, 1.0)
		var progress := float(turns) * (1.0 - pow(1.0 - fraction, 3))
		var tick := int(floor(progress))
		var phase := progress - tick
		var number := posmod(int(text[i]) - turns + tick, 10)
		for j in range(2):
			var glyph := cell.get_child(j) as Label
			glyph.text = str((number + j) % 10)
			glyph.size = cell.size
			glyph.position = Vector2(0, (float(j) - phase) * cell.size.y)
