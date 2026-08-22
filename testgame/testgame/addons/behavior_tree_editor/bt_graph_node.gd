@tool
extends GraphNode
class_name BTGraphNode

const BTTypeIcon = preload("res://addons/behavior_tree_editor/bt_type_icon.gd")

const INACTIVE_BRANCH_ALPHA := 0.24
const NORMAL_CARD_SIZE := Vector2(250.0, 150.0)
const COMPACT_CARD_SIZE := Vector2(188.0, 88.0)
const NORMAL_CONTENT_WIDTH := 230.0
const COMPACT_CONTENT_WIDTH := 172.0
const TRANSPARENT_EDGE_COLOR := Color(0.0, 0.0, 0.0, 0.0)

signal collapse_toggled(node_id: int)
signal drag_started(node_id: int)
signal drag_finished(node_id: int)

var node_resource: BTNodeResource

var input_row: HBoxContainer
var output_row: HBoxContainer
var input_square: ColorRect
var output_square: ColorRect
var header_bar: ColorRect
var title_row: HBoxContainer
var order_label: Label
var collapse_button: Button
var type_icon: BTTypeIcon
var title_label: Label
var type_badge: Label
var runtime_label: Label
var failure_badge: Label
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
var compact_mode := false
var semantic_detail_level := 2
var search_matches := true
var search_active := false
var search_current := false
var subtree_collapse_enabled := true
var decorator_badges_enabled := true
var type_encoding_enabled := false
var accessible_palette_enabled := false
var single_connection_rendering_enabled := true
var runtime_highlight_enabled := true
var runtime_dim_non_active := false
var runtime_reason_enabled := true
var runtime_reason := ""
var runtime_snapshot_active := false
var fisheye_magnification := 1.0
var manual_connection_dragging := false
var visual_offset := Vector2.ZERO
var fisheye_base_size := Vector2.ZERO


func _ready() -> void:
	resizable = false
	selectable = true
	# Node movement and bottom-to-top connection dragging are handled explicitly
	# so the native side-port drag cannot steal input from the visible squares.
	draggable = false
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

	title_row = HBoxContainer.new()
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

	type_icon = BTTypeIcon.new()
	type_icon.visible = false
	title_row.add_child(type_icon)

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

	failure_badge = Label.new()
	failure_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	failure_badge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	failure_badge.max_lines_visible = 2
	failure_badge.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	failure_badge.custom_minimum_size = Vector2(NORMAL_CONTENT_WIDTH, 0.0)
	failure_badge.modulate = Color("f87171")
	failure_badge.visible = false
	add_child(failure_badge)

	collapsed_summary_label = Label.new()
	collapsed_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	collapsed_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	collapsed_summary_label.max_lines_visible = 3
	collapsed_summary_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	collapsed_summary_label.custom_minimum_size = Vector2(NORMAL_CONTENT_WIDTH, 0.0)
	add_child(collapsed_summary_label)

	decorator_badges = VBoxContainer.new()
	decorator_badges.custom_minimum_size = Vector2(NORMAL_CONTENT_WIDTH, 0.0)
	add_child(decorator_badges)

	description_label = Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.max_lines_visible = 2
	description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description_label.custom_minimum_size = Vector2(NORMAL_CONTENT_WIDTH, 38.0)
	add_child(description_label)

	output_row = HBoxContainer.new()
	output_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(output_row)

	output_square = ColorRect.new()
	output_square.custom_minimum_size = Vector2(14.0, 14.0)
	output_row.add_child(output_square)

	_refresh_connection_slots(_type_color(BTNodeResource.TYPE_ACTION))
	_make_children_ignore_mouse(self)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _is_near_output_port(event.position):
			manual_dragging = false
			manual_connection_dragging = true
			selected = true
			var graph_edit := get_parent() as BTGraphEdit
			if graph_edit != null:
				graph_edit.begin_manual_connection(StringName(name), graph_edit._output_port_position(self))
			accept_event()
			return
		if not event.pressed and manual_connection_dragging:
			manual_connection_dragging = false
			var graph_edit := get_parent() as BTGraphEdit
			if graph_edit != null:
				graph_edit.finish_manual_connection(graph_edit.get_local_mouse_position())
			accept_event()
			return
		if event.pressed and _is_near_input_port(event.position):
			manual_dragging = false
			accept_event()
			return
		if event.pressed and not manual_dragging and node_resource != null:
			drag_started.emit(node_resource.id)
		if not event.pressed and manual_dragging and node_resource != null:
			drag_finished.emit(node_resource.id)
		manual_dragging = event.pressed
		if event.pressed:
			selected = true
		accept_event()
	if event is InputEventMouseMotion and manual_connection_dragging:
		var graph_edit := get_parent() as BTGraphEdit
		if graph_edit != null:
			graph_edit.update_manual_connection(graph_edit.get_local_mouse_position())
		accept_event()
		return
	if event is InputEventMouseMotion and manual_dragging:
		var zoom := 1.0
		var parent := get_parent()
		if parent is GraphEdit:
			zoom = max(0.01, parent.zoom)
		position_offset += event.relative / zoom
		accept_event()


func _is_near_connection_port(local_position: Vector2) -> bool:
	return _is_near_input_port(local_position) or _is_near_output_port(local_position)


func _is_near_input_port(local_position: Vector2) -> bool:
	var top_port := Vector2(size.x * 0.5, 7.0 * fisheye_magnification)
	return local_position.distance_to(top_port) <= 30.0


func _is_near_output_port(local_position: Vector2) -> bool:
	var bottom_port := Vector2(size.x * 0.5, size.y - 7.0 * fisheye_magnification)
	return local_position.distance_to(bottom_port) <= 30.0


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
	node_resource.position = get_logical_position()


func get_logical_position() -> Vector2:
	return position_offset - visual_offset + _fisheye_position_compensation()


func set_visual_offset(value: Vector2) -> void:
	visual_offset = value
	_apply_render_position()


func _apply_render_position() -> void:
	if node_resource != null:
		position_offset = node_resource.position + visual_offset - _fisheye_position_compensation()


func _update_view(decorators: Array = []) -> void:
	if node_resource == null:
		return
	title = "%s #%d" % [node_resource.title, node_resource.id]
	title_label.text = node_resource.title
	type_badge.text = "Type: %s" % node_resource.node_type
	description_label.text = node_resource.description if not node_resource.description.is_empty() else "No description"
	var color := _type_color(node_resource.node_type)
	type_icon.configure(node_resource.node_type, color)
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
	_apply_information_density()
	_refresh_connection_slots(color)
	_apply_runtime_style()
	_apply_search_style()


func set_compact_mode(enabled: bool) -> void:
	compact_mode = enabled
	_apply_information_density()


func set_semantic_detail_level(level: int) -> void:
	semantic_detail_level = clampi(level, 0, 2)
	_apply_information_density()


func set_subtree_collapse_enabled(enabled: bool) -> void:
	subtree_collapse_enabled = enabled
	if is_instance_valid(collapse_button):
		collapse_button.visible = enabled and child_count > 0
	if is_instance_valid(collapsed_summary_label):
		collapsed_summary_label.visible = enabled and semantic_detail_level >= 1 and node_resource != null and node_resource.collapsed
	if not enabled and node_resource != null and is_instance_valid(description_label):
		description_label.text = node_resource.description if not node_resource.description.is_empty() else "No description"
	_apply_information_density()


func set_decorator_badges_enabled(enabled: bool) -> void:
	decorator_badges_enabled = enabled
	_apply_information_density()


func set_type_encoding_enabled(enabled: bool) -> void:
	type_encoding_enabled = enabled
	if is_instance_valid(type_icon):
		type_icon.visible = enabled
	_apply_information_density()


func set_accessible_palette_enabled(enabled: bool) -> void:
	accessible_palette_enabled = enabled
	if node_resource == null:
		return
	var color := _type_color(node_resource.node_type)
	type_icon.configure(node_resource.node_type, color)
	_refresh_connection_slots(color)
	_apply_runtime_style()


func set_single_connection_rendering_enabled(enabled: bool) -> void:
	single_connection_rendering_enabled = enabled
	if node_resource != null:
		_refresh_connection_slots(_type_color(node_resource.node_type))


func set_search_state(has_query: bool, matches_query: bool, is_current_result := false) -> void:
	search_active = has_query
	search_matches = matches_query
	search_current = is_current_result
	_apply_search_style()


func _apply_information_density() -> void:
	if not is_instance_valid(description_label):
		return
	var effective_level := 0 if compact_mode else semantic_detail_level
	type_badge.visible = effective_level >= 1
	type_icon.visible = type_encoding_enabled
	description_label.visible = effective_level >= 2
	decorator_badges.visible = decorator_badges_enabled and effective_level >= 2
	collapsed_summary_label.visible = subtree_collapse_enabled and effective_level >= 1
	runtime_label.visible = effective_level >= 1 or runtime_active
	failure_badge.visible = runtime_reason_enabled and not runtime_reason.is_empty()
	if compact_mode:
		custom_minimum_size = COMPACT_CARD_SIZE * fisheye_magnification
		title_row.custom_minimum_size = Vector2(COMPACT_CONTENT_WIDTH, 26.0) * fisheye_magnification
		title_label.custom_minimum_size = Vector2(105.0, 24.0) * fisheye_magnification
		header_bar.custom_minimum_size = Vector2(COMPACT_CONTENT_WIDTH, 5.0) * fisheye_magnification
	else:
		# Semantic zoom changes information only, so wheel zoom never resizes nodes.
		custom_minimum_size = NORMAL_CARD_SIZE * fisheye_magnification
		title_row.custom_minimum_size = Vector2(NORMAL_CONTENT_WIDTH, 28.0) * fisheye_magnification
		title_label.custom_minimum_size = Vector2(150.0, 28.0) * fisheye_magnification
		header_bar.custom_minimum_size = Vector2(NORMAL_CONTENT_WIDTH, 6.0) * fisheye_magnification
	var content_width := (COMPACT_CONTENT_WIDTH if compact_mode else NORMAL_CONTENT_WIDTH) * fisheye_magnification
	description_label.custom_minimum_size.x = content_width
	decorator_badges.custom_minimum_size.x = content_width
	collapsed_summary_label.custom_minimum_size.x = content_width
	failure_badge.custom_minimum_size.x = content_width
	input_square.custom_minimum_size = Vector2.ONE * 14.0 * fisheye_magnification
	output_square.custom_minimum_size = Vector2.ONE * 14.0 * fisheye_magnification
	if not is_equal_approx(fisheye_magnification, 1.0):
		add_theme_font_size_override("font_size", maxi(11, roundi(16.0 * fisheye_magnification)))
	else:
		remove_theme_font_size_override("font_size")
	if node_resource != null:
		_apply_render_position()
		_refresh_connection_slots(_type_color(node_resource.node_type))
	# GraphNode keeps its previous expanded size unless explicitly reset after rows
	# are hidden. This is most visible when switching to Compact Mode.
	reset_size()
	_reset_size_after_layout.call_deferred()


func _reset_size_after_layout() -> void:
	if not is_inside_tree():
		return
	reset_size()
	if node_resource != null:
		_apply_render_position()
		_refresh_connection_slots(_type_color(node_resource.node_type))


func set_fisheye_magnification(value: float) -> void:
	var next_value := clampf(value, 0.7, 1.25)
	if is_equal_approx(fisheye_magnification, next_value):
		return
	if is_equal_approx(fisheye_magnification, 1.0) or fisheye_base_size.is_zero_approx():
		fisheye_base_size = size
	fisheye_magnification = next_value
	_apply_information_density()


func _fisheye_position_compensation() -> Vector2:
	if fisheye_base_size.is_zero_approx():
		return Vector2.ZERO
	return (size - fisheye_base_size) * 0.5


func _refresh_connection_slots(color: Color) -> void:
	clear_all_slots()
	var native_color := TRANSPARENT_EDGE_COLOR if single_connection_rendering_enabled else color
	var visible_row := 0
	for child in get_children():
		if not (child is Control) or not child.visible:
			continue
		if child == input_row:
			set_slot(visible_row, true, 0, native_color, false, 0, native_color)
		elif child == output_row:
			set_slot(visible_row, false, 0, native_color, true, 0, native_color)
		visible_row += 1


func _apply_search_style() -> void:
	if runtime_active and runtime_highlight_enabled:
		return
	if not search_active:
		self_modulate = Color.WHITE
		if node_resource != null and not runtime_active:
			header_bar.color = _type_color(node_resource.node_type)
		return
	self_modulate = Color.WHITE if search_matches else Color(0.45, 0.45, 0.45, 0.32)
	if search_current:
		header_bar.color = Color("22d3ee")
	elif search_matches:
		header_bar.color = Color("fbbf24")


func _on_collapse_button_pressed() -> void:
	if node_resource == null:
		return
	collapse_toggled.emit(node_resource.id)


func set_runtime_state(is_active: bool, is_leaf: bool, status: String = "", highlight_enabled := true, dim_non_active := false, failure_reason := "", reason_enabled := true, snapshot_active := true) -> void:
	if runtime_active == is_active \
		and runtime_leaf == is_leaf \
		and runtime_status == status \
		and runtime_highlight_enabled == highlight_enabled \
		and runtime_dim_non_active == dim_non_active \
		and runtime_reason == failure_reason \
		and runtime_reason_enabled == reason_enabled \
		and runtime_snapshot_active == snapshot_active:
		return
	var failure_visibility_changed := failure_badge.visible != (reason_enabled and not failure_reason.is_empty())
	runtime_active = is_active
	runtime_leaf = is_leaf
	runtime_status = status
	runtime_highlight_enabled = highlight_enabled
	runtime_dim_non_active = dim_non_active
	runtime_reason = failure_reason
	runtime_reason_enabled = reason_enabled
	runtime_snapshot_active = snapshot_active
	_apply_runtime_style()
	if failure_visibility_changed and node_resource != null:
		_refresh_connection_slots(_type_color(node_resource.node_type))


func _apply_runtime_style() -> void:
	if node_resource == null or runtime_label == null:
		return
	var enabled_color := Color.WHITE if node_resource.enabled else Color(1.0, 1.0, 1.0, 0.45)
	failure_badge.visible = runtime_reason_enabled and not runtime_reason.is_empty()
	failure_badge.text = "FAIL: %s" % runtime_reason if failure_badge.visible else ""
	failure_badge.tooltip_text = runtime_reason
	if not runtime_active or not runtime_highlight_enabled:
		var color := _type_color(node_resource.node_type)
		header_bar.color = color
		input_square.color = color.darkened(0.2)
		output_square.color = color
		order_label.modulate = color
		modulate = Color(enabled_color.r, enabled_color.g, enabled_color.b, INACTIVE_BRANCH_ALPHA) if runtime_snapshot_active and runtime_dim_non_active and not runtime_active else enabled_color
		runtime_label.text = ""
		_apply_search_style()
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
		badge.text = _decorator_badge_text(decorator)
		badge.tooltip_text = badge.text
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		badge.max_lines_visible = 2
		badge.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		badge.modulate = _type_color(BTNodeResource.TYPE_DECORATOR)
		decorator_badges.add_child(badge)


func _decorator_badge_text(decorator: BTNodeResource) -> String:
	var parameters := decorator.parameters
	var mode := str(parameters.get("mode", "blackboard")).to_lower()
	match mode:
		"blackboard":
			return "Decorator: %s [%s %s %s%s]" % [
				decorator.title,
				str(parameters.get("blackboard_key", "")),
				str(parameters.get("operator", "equals")),
				str(parameters.get("value", true)),
				", inverted" if bool(parameters.get("invert", false)) else ""
			]
		"cooldown":
			return "Decorator: %s [cooldown %ss]" % [decorator.title, str(parameters.get("duration", 1.0))]
		"time_limit":
			return "Decorator: %s [time limit %ss]" % [decorator.title, str(parameters.get("duration", 1.0))]
		"repeat_forever":
			return "Decorator: %s [repeat forever]" % decorator.title
		"invert":
			return "Decorator: %s [invert result]" % decorator.title
		"force_success", "always_success", "succeeder":
			return "Decorator: %s [force success]" % decorator.title
		"force_failure", "always_failure", "failer":
			return "Decorator: %s [force failure]" % decorator.title
		_:
			return "Decorator: %s [%s]" % [decorator.title, mode]


func _type_color(node_type: String) -> Color:
	if accessible_palette_enabled:
		match node_type:
			BTNodeResource.TYPE_ROOT: return Color("56b4e9")
			BTNodeResource.TYPE_SEQUENCE: return Color("0072b2")
			BTNodeResource.TYPE_SELECTOR: return Color("e69f00")
			BTNodeResource.TYPE_RANDOM_SELECTOR: return Color("d55e00")
			BTNodeResource.TYPE_PARALLEL: return Color("009e73")
			BTNodeResource.TYPE_REPEAT: return Color("cc79a7")
			BTNodeResource.TYPE_ACTION: return Color("56b4e9")
			BTNodeResource.TYPE_CONDITION: return Color("d55e00")
			BTNodeResource.TYPE_WAIT: return Color("f0e442")
			BTNodeResource.TYPE_DECORATOR: return Color("cc79a7")
	match node_type:
		BTNodeResource.TYPE_ROOT:
			return Color("7dd3fc")
		BTNodeResource.TYPE_SEQUENCE:
			return Color("60a5fa")
		BTNodeResource.TYPE_SELECTOR:
			return Color("f59e0b")
		BTNodeResource.TYPE_RANDOM_SELECTOR:
			return Color("fb923c")
		BTNodeResource.TYPE_PARALLEL:
			return Color("14b8a6")
		BTNodeResource.TYPE_REPEAT:
			return Color("a78bfa")
		BTNodeResource.TYPE_ACTION:
			return Color("34d399")
		BTNodeResource.TYPE_CONDITION:
			return Color("f87171")
		BTNodeResource.TYPE_WAIT:
			return Color("facc15")
		BTNodeResource.TYPE_DECORATOR:
			return Color("a78bfa")
		_:
			return Color("d1d5db")
