@tool
extends GraphNode
class_name BTGraphNode

signal collapse_toggled(node_id: int)

var node_resource: BTNodeResource

var input_row: HBoxContainer
var output_row: HBoxContainer
var input_square: ColorRect
var output_square: ColorRect
var header_bar: ColorRect
var order_label: Label
var collapse_button: Button
var title_label: Label
var type_badge: Label
var runtime_label: Label
var collapsed_summary_label: Label
var description_label: Label
var execution_order := -1
var child_count := 0
var collapsed_descendant_count := 0
var collapsed_preview_text := ""
var decorator_badges: VBoxContainer
var runtime_active := false
var runtime_leaf := false
var runtime_status := ""
var manual_dragging := false


func _ready() -> void:
	resizable = false
	selectable = true
	draggable = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(240.0, 140.0)

	input_row = HBoxContainer.new()
	input_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(input_row)

	input_square = ColorRect.new()
	input_square.custom_minimum_size = Vector2(14.0, 14.0)
	input_row.add_child(input_square)

	header_bar = ColorRect.new()
	header_bar.custom_minimum_size = Vector2(230.0, 6.0)
	add_child(header_bar)

	var title_row := HBoxContainer.new()
	title_row.custom_minimum_size = Vector2(230.0, 28.0)
	add_child(title_row)

	order_label = Label.new()
	order_label.custom_minimum_size = Vector2(32.0, 28.0)
	order_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	order_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(order_label)

	collapse_button = Button.new()
	collapse_button.custom_minimum_size = Vector2(32.0, 24.0)
	collapse_button.tooltip_text = "Collapse or expand this subtree."
	collapse_button.pressed.connect(_on_collapse_button_pressed)
	title_row.add_child(collapse_button)

	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.custom_minimum_size = Vector2(150.0, 28.0)
	title_row.add_child(title_label)

	type_badge = Label.new()
	type_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(type_badge)

	runtime_label = Label.new()
	runtime_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(runtime_label)

	collapsed_summary_label = Label.new()
	collapsed_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	collapsed_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	collapsed_summary_label.custom_minimum_size = Vector2(220.0, 0.0)
	add_child(collapsed_summary_label)

	decorator_badges = VBoxContainer.new()
	decorator_badges.custom_minimum_size = Vector2(220.0, 0.0)
	add_child(decorator_badges)

	description_label = Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.custom_minimum_size = Vector2(220.0, 48.0)
	add_child(description_label)

	output_row = HBoxContainer.new()
	output_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(output_row)

	output_square = ColorRect.new()
	output_square.custom_minimum_size = Vector2(14.0, 14.0)
	output_row.add_child(output_square)

	set_slot(0, true, 0, _type_color(BTNodeResource.TYPE_ACTION), false, 0, Color.TRANSPARENT)
	set_slot(5, false, 0, Color.TRANSPARENT, true, 0, _type_color(BTNodeResource.TYPE_ACTION))
	_make_children_ignore_mouse(self)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _is_near_connection_port(event.position):
			manual_dragging = false
			return
		manual_dragging = event.pressed
		if event.pressed:
			selected = true
		accept_event()
	if event is InputEventMouseMotion and manual_dragging:
		var zoom := 1.0
		var parent := get_parent()
		if parent is GraphEdit:
			zoom = max(0.01, parent.zoom)
		position_offset += event.relative / zoom
		if node_resource != null:
			node_resource.position = position_offset
		accept_event()


func _is_near_connection_port(local_position: Vector2) -> bool:
	var center_x := size.x * 0.5
	var top_port := Vector2(center_x, 14.0)
	var bottom_port := Vector2(center_x, max(14.0, size.y - 14.0))
	return local_position.distance_to(top_port) <= 26.0 or local_position.distance_to(bottom_port) <= 26.0


func setup(resource: BTNodeResource, order := -1, decorators: Array = [], visible_child_count := 0, hidden_descendant_count := 0, hidden_preview := "") -> void:
	node_resource = resource
	execution_order = order
	child_count = visible_child_count
	collapsed_descendant_count = hidden_descendant_count
	collapsed_preview_text = hidden_preview
	name = str(resource.id)
	position_offset = resource.position
	_update_view(decorators)


func _make_children_ignore_mouse(root: Control) -> void:
	for child in root.get_children():
		if child is Control:
			if child is BaseButton:
				continue
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_make_children_ignore_mouse(child)


func sync_to_resource() -> void:
	if node_resource == null:
		return
	node_resource.position = position_offset
	_update_view()


func _update_view(decorators: Array = []) -> void:
	if node_resource == null:
		return
	title = "%s #%d" % [node_resource.title, node_resource.id]
	title_label.text = node_resource.title
	type_badge.text = "Type: %s" % node_resource.node_type
	description_label.text = node_resource.description if not node_resource.description.is_empty() else "No description"
	var color := _type_color(node_resource.node_type)
	header_bar.color = color
	_refresh_decorator_badges(decorators)
	input_square.color = color.darkened(0.2)
	output_square.color = color
	order_label.text = "" if execution_order < 0 else "%02d" % execution_order
	order_label.modulate = color
	collapse_button.visible = child_count > 0
	collapse_button.text = "+" if node_resource.collapsed else "-"
	if node_resource.collapsed and collapsed_descendant_count > 0:
		var summary := "Collapsed: %d node%s" % [collapsed_descendant_count, "" if collapsed_descendant_count == 1 else "s"]
		if not collapsed_preview_text.is_empty():
			summary += "\n%s" % collapsed_preview_text
		collapsed_summary_label.text = summary
		collapsed_summary_label.modulate = Color(0.78, 0.86, 1.0, 1.0)
	else:
		collapsed_summary_label.text = ""
	if node_resource.collapsed:
		description_label.text = "Subtree hidden in editor view."
	set_slot(0, true, 0, color.darkened(0.2), false, 0, Color.TRANSPARENT)
	set_slot(5, false, 0, Color.TRANSPARENT, true, 0, color)
	_apply_runtime_style()


func _on_collapse_button_pressed() -> void:
	if node_resource == null:
		return
	collapse_toggled.emit(node_resource.id)


func set_runtime_state(is_active: bool, is_leaf: bool, status: String = "") -> void:
	runtime_active = is_active
	runtime_leaf = is_leaf
	runtime_status = status
	_apply_runtime_style()


func _apply_runtime_style() -> void:
	if node_resource == null or runtime_label == null:
		return
	var enabled_color := Color.WHITE if node_resource.enabled else Color(1.0, 1.0, 1.0, 0.45)
	if not runtime_active:
		var color := _type_color(node_resource.node_type)
		header_bar.color = color
		input_square.color = color.darkened(0.2)
		output_square.color = color
		order_label.modulate = color
		modulate = enabled_color
		runtime_label.text = ""
		return
	var highlight := Color("facc15")
	if runtime_leaf:
		match runtime_status:
			"SUCCESS":
				highlight = Color("34d399")
			"FAILURE":
				highlight = Color("f87171")
			"RUNNING":
				highlight = Color("22c55e")
			_:
				highlight = Color("facc15")
	modulate = Color(1.0, 0.96, 0.68, 1.0)
	header_bar.color = highlight
	input_square.color = highlight.darkened(0.2)
	output_square.color = highlight
	order_label.modulate = highlight
	runtime_label.text = "CURRENT: %s" % runtime_status if runtime_leaf else "ACTIVE PATH"
	runtime_label.modulate = highlight


func _refresh_decorator_badges(decorators: Array) -> void:
	for child in decorator_badges.get_children():
		child.queue_free()
	for decorator in decorators:
		if decorator == null:
			continue
		var badge := Label.new()
		badge.text = "Decorator: %s" % decorator.title
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.modulate = _type_color(BTNodeResource.TYPE_DECORATOR)
		decorator_badges.add_child(badge)


func _type_color(node_type: String) -> Color:
	match node_type:
		BTNodeResource.TYPE_ROOT:
			return Color("7dd3fc")
		BTNodeResource.TYPE_SEQUENCE:
			return Color("60a5fa")
		BTNodeResource.TYPE_SELECTOR:
			return Color("f59e0b")
		BTNodeResource.TYPE_ACTION:
			return Color("34d399")
		BTNodeResource.TYPE_CONDITION:
			return Color("f87171")
		BTNodeResource.TYPE_DECORATOR:
			return Color("a78bfa")
		_:
			return Color("d1d5db")
