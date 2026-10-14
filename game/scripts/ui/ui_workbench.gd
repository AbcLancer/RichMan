extends CanvasLayer
class_name UiWorkbench
## F10 opens a live inspector. Overrides use structural paths, never object IDs.
const SAVE_PATH := "res://data/ui/layout-overrides.json"
var save_path := SAVE_PATH
var root: Node
var overrides: Dictionary = {}
var panel: PanelContainer
var list: ItemList
var search: LineEdit
var detail: Label
var fields: Array[SpinBox] = []
var targets: Array[Control] = []
var selected: Control
var _timer := 0.0
var _updating := false
var _patched: Array[Control] = []
var highlight: Panel
var drag_handle: Label
var _dragging := false
var _drag_offset := Vector2.ZERO

func setup(ui_root: Node) -> void:
	root = ui_root
	layer = 130
	if FileAccess.file_exists(SAVE_PATH):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if saved is Dictionary: overrides = saved
	build()
	scan()

func build() -> void:
	highlight = Panel.new()
	highlight.name = "SelectionHighlight"
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark := StyleBoxFlat.new()
	mark.bg_color = Color(1, .05, .05, .22)
	mark.border_color = Color(1, .12, .12, 1)
	mark.set_border_width_all(3)
	highlight.add_theme_stylebox_override("panel", mark)
	add_child(highlight)
	highlight.hide()
	panel = PanelContainer.new()
	panel.z_index = 10
	panel.position = Vector2(12, 42)
	panel.size = Vector2(360, 625)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.10, 0.98)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	drag_handle = Label.new()
	drag_handle.text = "界面校准 · 拖动此处移动 · F10 开关"
	drag_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	drag_handle.mouse_default_cursor_shape = Control.CURSOR_MOVE
	drag_handle.gui_input.connect(_header_input)
	box.add_child(drag_handle)
	var search_row := HBoxContainer.new()
	box.add_child(search_row)
	search = LineEdit.new()
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.placeholder_text = "筛选名称 / 文字 / 节点路径"
	search.text_changed.connect(func(_text): refresh())
	search_row.add_child(search)
	var refresh_button := Button.new()
	refresh_button.text = "刷新"
	refresh_button.pressed.connect(refresh)
	search_row.add_child(refresh_button)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(330, 210)
	list.item_selected.connect(select)
	box.add_child(list)
	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(330, 60)
	box.add_child(detail)
	for caption in ["横坐标", "纵坐标", "宽度", "高度", "字号"]:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = caption
		label.custom_minimum_size.x = 85
		row.add_child(label)
		var input := SpinBox.new()
		input.min_value = -4096
		input.max_value = 8192
		input.step = 1
		input.custom_minimum_size.x = 210
		input.value_changed.connect(func(_value): edit())
		row.add_child(input)
		box.add_child(row)
		fields.append(input)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	for caption in ["保存全部", "重置选中", "导出检查"]:
		var button := Button.new()
		button.text = caption
		button.pressed.connect(save if caption == "保存全部" else (reset if caption == "重置选中" else export_audit))
		buttons.add_child(button)
	var help := Label.new()
	help.text = "打开弹窗后自动加入列表；选中控件标红。\n拖动标题移开工具；保存后下次启动生效。\n容器子项请调整其父节点。F10 关闭工具。"
	help.add_theme_font_size_override("font_size", 13)
	box.add_child(help)
	panel.hide()

func scan() -> void:
	for surface in surfaces():
		assign(surface, "UI" if surface == root else "UI/" + str(surface.name))

func surfaces() -> Array[Node]:
	# Preserve existing main UI keys while including sibling modal/menu layers.
	var result: Array[Node] = [root]
	for child in root.get_parent().get_children():
		if child is CanvasLayer and child != root and child != self:
			result.append(child)
	result.sort_custom(func(a, b): return (a.layer if a is CanvasLayer else 0) > (b.layer if b is CanvasLayer else 0))
	return result

func assign(node: Node, key: String) -> void:
	if node == self or node.get_meta("ui_inspector_skip", false): return
	if node is Control:
		var control := node as Control
		if not control.has_meta("ui_id"):
			control.set_meta("ui_id", key)
			control.set_meta("ui_original", properties(control))
			if overrides.has(key):
				apply(control, overrides[key])
				_patched.append(control)
		if control is Label: fit_text(control)
	var counts := {}
	for child in node.get_children():
		var kind: String = child.get_class()
		counts[kind] = int(counts.get(kind, 0)) + 1
		var part := str(child.name)
		if part.begins_with("@") or part == kind:
			part = kind + str(counts[kind])
		assign(child, key + "/" + part)

func properties(control: Control) -> Dictionary:
	var parent := control.get_parent() as Control
	var relative := parent.size if parent != null and parent.size.x > 0 and parent.size.y > 0 else get_viewport().get_visible_rect().size
	return {"rect": [control.position.x, control.position.y, control.size.x, control.size.y], "reference": [relative.x, relative.y], "font": control.get_theme_font_size("font_size")}

func apply(control: Control, value: Dictionary) -> void:
	var rect: Array = value.get("rect", [0, 0, 0, 0])
	var reference: Array = value.get("reference", [1280, 720])
	var parent := control.get_parent() as Control
	var area := parent.size if parent != null and parent.size.x > 0 and parent.size.y > 0 else get_viewport().get_visible_rect().size
	var factor := area / Vector2(maxf(float(reference[0]), 1), maxf(float(reference[1]), 1))
	if not control.get_parent() is Container:
		control.position = Vector2(float(rect[0]), float(rect[1])) * factor
		control.size = Vector2(float(rect[2]), float(rect[3])) * factor
	if control is Label or control is Button or control is LineEdit:
		control.add_theme_font_size_override("font_size", int(value.get("font", 16)))
		control.set_meta("ui_font", int(value.get("font", 16)))

func fit_text(label: Label) -> void:
	if label.get_meta("ui_keep_font", false): return
	# Containers calculate paragraph height from their text. Clipping that text
	# before layout would collapse the label and hide confirmation/news content.
	if label.get_parent() is Container and label.autowrap_mode != TextServer.AUTOWRAP_OFF:
		return
	if label.size.x < 12 or label.size.y < 8: return
	var current := label.get_theme_font_size("font_size")
	var requested := int(label.get_meta("ui_font", current))
	if current != int(label.get_meta("ui_last_font", current)):
		requested = current
	label.set_meta("ui_font", requested)
	var font := label.get_theme_font("font")
	var chosen := requested
	while chosen > mini(requested, 10):
		var measured: Vector2
		if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
			measured = font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, label.size.x, chosen)
		else:
			measured = font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, chosen)
		if measured.x <= label.size.x + 1 and measured.y <= label.size.y + 1: break
		chosen -= 1
	label.add_theme_font_size_override("font_size", chosen)
	label.set_meta("ui_last_font", chosen)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
		label.max_lines_visible = maxi(1, int(label.size.y / font.get_height(chosen)))
	if chosen < requested:
		label.tooltip_text = label.text
		label.mouse_filter = Control.MOUSE_FILTER_PASS

func collect(node: Node) -> void:
	if node == self or node.get_meta("ui_inspector_skip", false): return
	if node is Control and node.is_visible_in_tree() and node.has_meta("ui_id"):
		var control := node as Control
		var text := str(control.get("text")) if control is Label or control is Button or control is LineEdit else ""
		var title := str(control.get_meta("ui_title", ""))
		var description := str(control.get_meta("ui_id")) + " " + title + " " + text
		if search.text.is_empty() or description.to_lower().contains(search.text.to_lower()):
			targets.append(control)
			var key := str(control.get_meta("ui_id"))
			var label := text.replace("\n", " ").left(20)
			if label.is_empty() and control is TextureRect and control.texture != null:
				label = control.texture.resource_path.get_file()
			var context := key.get_base_dir().get_file() + "/" + key.get_file()
			if not title.is_empty(): label = title + ("：" + label if not label.is_empty() else "")
			list.add_item((label + " · " if not label.is_empty() else "") + context)
			list.set_item_tooltip(list.item_count - 1, description)
	for child in node.get_children(): collect(child)

func refresh() -> void:
	var scroll := list.get_v_scroll_bar().value
	scan()
	targets.clear()
	list.clear()
	for surface in surfaces(): collect(surface)
	if is_instance_valid(selected) and targets.has(selected): list.select(targets.find(selected))
	list.get_v_scroll_bar().set_deferred("value", scroll)

func select(index: int) -> void:
	if index < 0 or index >= targets.size(): return
	selected = targets[index]
	_updating = true
	var value := properties(selected)
	for i in range(4): fields[i].value = value.rect[i]
	fields[4].value = int(selected.get_meta("ui_font", value.font))
	detail.text = str(selected.get_meta("ui_id")) + ("\n位置和尺寸由父容器管理；可调整字号或父节点" if selected.get_parent() is Container else "\n坐标相对于父节点")
	for i in range(4): fields[i].editable = not selected.get_parent() is Container
	_updating = false
	queue_highlight()

func edit() -> void:
	if _updating or not is_instance_valid(selected): return
	var value := properties(selected)
	value.rect = [fields[0].value, fields[1].value, maxf(1, fields[2].value), maxf(1, fields[3].value)]
	value.font = maxi(8, int(fields[4].value))
	apply(selected, value)
	overrides[str(selected.get_meta("ui_id"))] = value
	if not _patched.has(selected): _patched.append(selected)

func save() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/ui"))
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		detail.text = "保存失败：" + error_string(FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(overrides, "\t"))
	detail.text = "已保存：game/data/ui/layout-overrides.json"

func reset() -> void:
	if not is_instance_valid(selected): return
	overrides.erase(str(selected.get_meta("ui_id")))
	apply(selected, selected.get_meta("ui_original"))
	select(targets.find(selected))

func export_audit() -> void:
	var rows: Array = []
	for surface in surfaces(): audit(surface, rows)
	var path := ProjectSettings.globalize_path("res://../docs/ui-layout-audit.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(rows, "\t"))
	detail.text = "已导出 docs/ui-layout-audit.json"

func audit(node: Node, rows: Array) -> void:
	if node == self or node.get_meta("ui_inspector_skip", false): return
	if node is Control and node.has_meta("ui_id"):
		var control := node as Control
		var row := properties(control)
		row.id = control.get_meta("ui_id")
		row.visible = control.is_visible_in_tree()
		row.type = control.get_class()
		row.outside_viewport = not get_viewport().get_visible_rect().encloses(control.get_global_rect()) if control.size.x > 0 and control.size.y > 0 else false
		if control is TextureRect and control.texture != null:
			row.image_size = [control.texture.get_width(), control.texture.get_height()]
			row.stretch_mode = control.stretch_mode
			row.texture = control.texture.resource_path
		if control is Label:
			row.text = control.text
			row.font_reduced = control.get_theme_font_size("font_size") < int(control.get_meta("ui_font", 16))
		rows.append(row)
	for child in node.get_children(): audit(child, rows)

func _process(delta: float) -> void:
	for i in range(_patched.size() - 1, -1, -1):
		var target := _patched[i]
		if not is_instance_valid(target):
			_patched.remove_at(i)
			continue
		var key := str(target.get_meta("ui_id"))
		if overrides.has(key):
			apply(target, overrides[key])
			if target is Label: fit_text(target)
	_timer += delta
	if _timer > 0.4:
		_timer = 0
		if panel.visible: refresh()
		else: scan()
	if is_instance_valid(selected) and panel.visible and selected.is_visible_in_tree(): queue_highlight()
	else: highlight.hide()

func queue_highlight() -> void:
	# A sibling overlay is never resized by the inspector's PanelContainer.
	if not is_instance_valid(selected): highlight.hide(); return
	var rect := selected.get_global_rect()
	highlight.position = rect.position
	highlight.size = rect.size
	highlight.visible = panel.visible and selected.is_visible_in_tree()

func _header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_dragging = true
		# gui_input coordinates are local to the title, independent of OS cursor state.
		_drag_offset = drag_handle.get_global_rect().position - panel.position + event.position
		drag_handle.accept_event()

func _move_panel(point: Vector2) -> void:
	var bounds := get_viewport().get_visible_rect().size
	panel.position = Vector2(clampf(point.x, 0, maxf(0, bounds.x - panel.size.x)),
		clampf(point.y, 0, maxf(0, bounds.y - panel.size.y)))

func _input(event: InputEvent) -> void:
	if _dragging:
		if event is InputEventMouseMotion:
			_move_panel(event.position - _drag_offset)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed: _dragging = false
			get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		_dragging = false
		panel.visible = not panel.visible
		if not panel.visible: highlight.hide()
		if panel.visible: refresh()
		get_viewport().set_input_as_handled()
