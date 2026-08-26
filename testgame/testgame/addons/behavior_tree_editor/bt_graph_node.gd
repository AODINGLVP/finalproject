@tool
extends GraphNode
class_name BTGraphNode

const BTTypeIcon = preload("res://addons/behavior_tree_editor/bt_type_icon.gd")

const INACTIVE_BRANCH_ALPHA := 0.24
const NORMAL_CARD_SIZE := Vector2(250.0, 150.0)
const COMPACT_CARD_SIZE := Vector2(188.0, 88.0)
const SELECTION_ROLE_NONE := 0
const SELECTION_ROLE_UNRELATED := 1
const SELECTION_ROLE_SIBLING := 2
const SELECTION_ROLE_DIRECT_CHILD := 3
const SELECTION_ROLE_ANCESTOR := 4
const SELECTION_ROLE_SELECTED := 5
const SELECTION_SELECTED_COLOR := Color("ffffff")
const SELECTION_RELATED_COLOR := Color("facc15")
const SELECTION_SIBLING_COLOR := Color("4ade80")
const SELECTION_UNRELATED_ALPHA := 0.18
const SELECTION_OUTLINE_WIDTH := 4.0
const SELECTION_SELECTED_OUTLINE_WIDTH := 5.0
const NORMAL_CONTENT_WIDTH := 230.0
const COMPACT_CONTENT_WIDTH := 172.0
const TRANSPARENT_EDGE_COLOR := Color(0.0, 0.0, 0.0, 0.0)
const TRANSLUCENT_CARD_ALPHA_FACTOR := 0.72
const TRANSLUCENT_TEXT_OUTLINE_SIZE := 2
const TRANSLUCENT_TEXT_PRIMARY_COLOR := Color("f8fafc")
const TRANSLUCENT_TEXT_SECONDARY_COLOR := Color("dbeafe")
const TRANSLUCENT_TEXT_ACCENT_COLOR := Color("fef3c7")
const TRANSLUCENT_TEXT_RUNTIME_COLOR := Color("dcfce7")
const TRANSLUCENT_TEXT_FAILURE_COLOR := Color("fecaca")
const TRANSLUCENT_TEXT_DECORATOR_COLOR := Color("f3e8ff")
const TRANSLUCENT_TEXT_OUTLINE_COLOR := Color("020617")
const TRANSLUCENT_TEXT_BASELINE_META := &"_bt_translucent_text_baseline"
const FISHEYE_MIN_MAGNIFICATION := 0.62
const FISHEYE_MAX_MAGNIFICATION := 6.0
const TRANSLUCENT_CARD_STYLE_NAMES := [
	&"panel",
	&"panel_focus",
	&"panel_selected",
	&"slot",
	&"slot_selected",
	&"titlebar",
	&"titlebar_selected",
]

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
var manual_group_dragging := false
var manual_drag_moved := false
var compact_mode := false
var semantic_detail_level := 2
var search_matches := true
var search_active := false
var search_current := false
var selection_context_enabled := false
var selection_context_role := SELECTION_ROLE_NONE
var selection_outline_color := Color.TRANSPARENT
var selection_outline_width := 0.0
var runtime_card_modulate := Color.WHITE
var subtree_collapse_enabled := true
var decorator_badges_enabled := true
var type_encoding_enabled := false
var accessible_palette_enabled := false
var single_connection_rendering_enabled := true
var translucent_cards_enabled := false
var translucent_style_override_names: Array[StringName] = []
var translucent_saved_style_overrides: Dictionary = {}
var runtime_highlight_enabled := true
var runtime_dim_non_active := false
var runtime_reason_enabled := true
var runtime_reason := ""
var runtime_snapshot_active := false
var fisheye_magnification := 1.0
var fisheye_detail_focus := false
var fisheye_visibility_alpha := 1.0
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


func _draw() -> void:
	if selection_outline_color.a <= 0.0 or selection_outline_width <= 0.0:
		return
	# Draw inside the card bounds so the complete frame remains visible even when
	# GraphEdit clips cards at the edge of its viewport.
	var inset := selection_outline_width * 0.5 + 1.0
	var outline_size := Vector2(maxf(0.0, size.x - inset * 2.0), maxf(0.0, size.y - inset * 2.0))
	if outline_size.x <= 0.0 or outline_size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ONE * inset, outline_size), selection_outline_color, false, selection_outline_width, true)


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
			manual_drag_moved = false
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
		if not event.relative.is_zero_approx():
			manual_drag_moved = true
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


func sync_rendered_position_to_resource() -> void:
	if node_resource == null:
		return
	# A manual drop owns the visible position. Temporary spacing must not be
	# subtracted here, otherwise a previously displaced card jumps on release.
	node_resource.position = get_rendered_drop_position()
	visual_offset = Vector2.ZERO
	_apply_render_position()


func capture_rendered_position_for_manual_drag() -> void:
	# Auto Spacing is a visual-only offset. Once the user picks this card up, its
	# rendered location becomes the live drag origin while the resource remains
	# unchanged until mouse release.
	visual_offset = Vector2.ZERO


func set_manual_group_dragging(enabled: bool) -> void:
	manual_group_dragging = enabled


func get_logical_position() -> Vector2:
	return position_offset - visual_offset + _fisheye_position_compensation()


func get_rendered_drop_position() -> Vector2:
	return position_offset + _fisheye_position_compensation()


func set_visual_offset(value: Vector2) -> void:
	visual_offset = value
	_apply_render_position()


func _apply_render_position() -> void:
	# Card contents may resize while the pointer is held (Semantic Zoom, Compact,
	# or a deferred GraphNode reset). The live pointer position must win over the
	# deliberately stale resource coordinate until release.
	if node_resource != null and not manual_dragging and not manual_group_dragging:
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


func set_translucent_cards_enabled(enabled: bool) -> void:
	if translucent_cards_enabled == enabled:
		return
	translucent_cards_enabled = enabled
	if enabled:
		_capture_translucent_style_baseline()
		_apply_translucent_card_styles()
		_apply_translucent_text_masks()
	else:
		_restore_translucent_style_baseline()
		_restore_translucent_text_masks()


func _capture_translucent_style_baseline() -> void:
	translucent_saved_style_overrides.clear()
	for style_name in TRANSLUCENT_CARD_STYLE_NAMES:
		if has_theme_stylebox_override(style_name):
			translucent_saved_style_overrides[style_name] = get_theme_stylebox(style_name).duplicate(true)


func _apply_translucent_card_styles() -> void:
	translucent_style_override_names.clear()
	for style_name in TRANSLUCENT_CARD_STYLE_NAMES:
		var base_style := get_theme_stylebox(style_name)
		if not (base_style is StyleBoxFlat):
			continue
		var translucent_style := base_style.duplicate(true) as StyleBoxFlat
		translucent_style.bg_color.a *= TRANSLUCENT_CARD_ALPHA_FACTOR
		add_theme_stylebox_override(style_name, translucent_style)
		translucent_style_override_names.append(style_name)


func _restore_translucent_style_baseline() -> void:
	for style_name in TRANSLUCENT_CARD_STYLE_NAMES:
		remove_theme_stylebox_override(style_name)
	for style_name in translucent_saved_style_overrides:
		add_theme_stylebox_override(style_name, translucent_saved_style_overrides[style_name])
	translucent_style_override_names.clear()
	translucent_saved_style_overrides.clear()


func _apply_translucent_text_masks() -> void:
	if not translucent_cards_enabled:
		return
	var titlebar := get_titlebar_hbox()
	if is_instance_valid(titlebar):
		_apply_translucent_text_masks_in(titlebar, TRANSLUCENT_TEXT_PRIMARY_COLOR)
	_apply_translucent_text_mask(title_label, TRANSLUCENT_TEXT_PRIMARY_COLOR)
	_apply_translucent_text_mask(order_label, TRANSLUCENT_TEXT_ACCENT_COLOR)
	_apply_translucent_text_mask(type_badge, TRANSLUCENT_TEXT_SECONDARY_COLOR)
	_apply_translucent_text_mask(runtime_label, TRANSLUCENT_TEXT_RUNTIME_COLOR)
	_apply_translucent_text_mask(failure_badge, TRANSLUCENT_TEXT_FAILURE_COLOR)
	_apply_translucent_text_mask(collapsed_summary_label, TRANSLUCENT_TEXT_SECONDARY_COLOR)
	_apply_translucent_text_mask(description_label, TRANSLUCENT_TEXT_SECONDARY_COLOR)
	for child in decorator_badges.get_children():
		if child is Label:
			_apply_translucent_text_mask(child, TRANSLUCENT_TEXT_DECORATOR_COLOR)


func _apply_translucent_text_masks_in(parent: Node, text_color: Color) -> void:
	for child in parent.get_children(true):
		if child is Label:
			_apply_translucent_text_mask(child, text_color)
		_apply_translucent_text_masks_in(child, text_color)


func _apply_translucent_text_mask(label: Label, text_color: Color) -> void:
	if not is_instance_valid(label):
		return
	if not label.has_meta(TRANSLUCENT_TEXT_BASELINE_META):
		var saved := {
			"font_color_overridden": label.has_theme_color_override(&"font_color"),
			"font_outline_color_overridden": label.has_theme_color_override(&"font_outline_color"),
			"outline_size_overridden": label.has_theme_constant_override(&"outline_size"),
			"modulate": label.modulate,
		}
		if bool(saved["font_color_overridden"]):
			saved["font_color"] = label.get_theme_color(&"font_color")
		if bool(saved["font_outline_color_overridden"]):
			saved["font_outline_color"] = label.get_theme_color(&"font_outline_color")
		if bool(saved["outline_size_overridden"]):
			saved["outline_size"] = label.get_theme_constant(&"outline_size")
		label.set_meta(TRANSLUCENT_TEXT_BASELINE_META, saved)
	elif label.modulate != Color.WHITE:
		# Runtime state can update semantic text colors while the mask is active.
		# Preserve that latest value so disabling the experiment is exact.
		var saved: Dictionary = label.get_meta(TRANSLUCENT_TEXT_BASELINE_META)
		saved["modulate"] = label.modulate
		label.set_meta(TRANSLUCENT_TEXT_BASELINE_META, saved)
	label.modulate = Color.WHITE
	var outline_color := _translucent_text_outline_color()
	if not label.has_theme_color_override(&"font_color") or label.get_theme_color(&"font_color") != text_color:
		label.add_theme_color_override(&"font_color", text_color)
	if not label.has_theme_color_override(&"font_outline_color") or label.get_theme_color(&"font_outline_color") != outline_color:
		label.add_theme_color_override(&"font_outline_color", outline_color)
	if not label.has_theme_constant_override(&"outline_size") or label.get_theme_constant(&"outline_size") != TRANSLUCENT_TEXT_OUTLINE_SIZE:
		label.add_theme_constant_override(&"outline_size", TRANSLUCENT_TEXT_OUTLINE_SIZE)


func _translucent_text_outline_color() -> Color:
	var outline_color := TRANSLUCENT_TEXT_OUTLINE_COLOR
	# Branch dimming intentionally fades the text fill. Compensate only the dark
	# glyph silhouette so the independently rendered connection cannot bleed
	# through it, even when the owning card is dimmed.
	var intentionally_faded := (selection_context_enabled and selection_context_role == SELECTION_ROLE_UNRELATED) \
		or fisheye_visibility_alpha < 0.999
	if intentionally_faded:
		# Related Focus and Fisheye deliberately fade the complete card, including
		# its text mask. Their connections are faded as well, so full compensation
		# is neither necessary nor visually desirable here.
		outline_color.a = 1.0
	else:
		outline_color.a = 1.0 / maxf(modulate.a, 0.05)
	return outline_color


func _restore_translucent_text_masks() -> void:
	var titlebar := get_titlebar_hbox()
	if is_instance_valid(titlebar):
		_restore_translucent_text_masks_in(titlebar)
	_restore_translucent_text_mask(title_label)
	_restore_translucent_text_mask(order_label)
	_restore_translucent_text_mask(type_badge)
	_restore_translucent_text_mask(runtime_label)
	_restore_translucent_text_mask(failure_badge)
	_restore_translucent_text_mask(collapsed_summary_label)
	_restore_translucent_text_mask(description_label)
	for child in decorator_badges.get_children():
		if child is Label:
			_restore_translucent_text_mask(child)


func _restore_translucent_text_masks_in(parent: Node) -> void:
	for child in parent.get_children(true):
		if child is Label:
			_restore_translucent_text_mask(child)
		_restore_translucent_text_masks_in(child)


func _restore_translucent_text_mask(label: Label) -> void:
	if not is_instance_valid(label) or not label.has_meta(TRANSLUCENT_TEXT_BASELINE_META):
		return
	var saved: Dictionary = label.get_meta(TRANSLUCENT_TEXT_BASELINE_META)
	var saved_modulate: Color = saved["modulate"]
	label.modulate = saved_modulate
	label.remove_theme_color_override(&"font_color")
	label.remove_theme_color_override(&"font_outline_color")
	label.remove_theme_constant_override(&"outline_size")
	if bool(saved.get("font_color_overridden", false)):
		var saved_font_color: Color = saved["font_color"]
		label.add_theme_color_override(&"font_color", saved_font_color)
	if bool(saved.get("font_outline_color_overridden", false)):
		var saved_outline_color: Color = saved["font_outline_color"]
		label.add_theme_color_override(&"font_outline_color", saved_outline_color)
	if bool(saved.get("outline_size_overridden", false)):
		label.add_theme_constant_override(&"outline_size", int(saved["outline_size"]))
	label.remove_meta(TRANSLUCENT_TEXT_BASELINE_META)

func set_search_state(has_query: bool, matches_query: bool, is_current_result := false) -> void:
	search_active = has_query
	search_matches = matches_query
	search_current = is_current_result
	_apply_search_style()


func set_selection_context(enabled: bool, role: int = SELECTION_ROLE_NONE) -> void:
	selection_context_enabled = enabled
	selection_context_role = role if enabled else SELECTION_ROLE_NONE
	# Selection focus is an independent visual layer. Apply it even when Search or
	# Live Debug currently owns the header and card colors.
	_apply_selection_style()
	_apply_search_style()


func _apply_information_density() -> void:
	if not is_instance_valid(description_label):
		return
	var density_compact := compact_mode and not fisheye_detail_focus
	var effective_level := 2 if fisheye_detail_focus else (0 if density_compact else semantic_detail_level)
	type_badge.visible = effective_level >= 1
	type_icon.visible = type_encoding_enabled
	description_label.visible = effective_level >= 2
	decorator_badges.visible = decorator_badges_enabled and effective_level >= 2
	collapsed_summary_label.visible = subtree_collapse_enabled and effective_level >= 1
	runtime_label.visible = effective_level >= 1 or runtime_active
	failure_badge.visible = runtime_reason_enabled and not runtime_reason.is_empty()
	if density_compact:
		custom_minimum_size = COMPACT_CARD_SIZE * fisheye_magnification
		title_row.custom_minimum_size = Vector2(COMPACT_CONTENT_WIDTH, 26.0) * fisheye_magnification
		title_label.custom_minimum_size = Vector2(105.0, 24.0) * fisheye_magnification
		header_bar.custom_minimum_size = Vector2(COMPACT_CONTENT_WIDTH, 5.0) * fisheye_magnification
	else:
		custom_minimum_size = NORMAL_CARD_SIZE * fisheye_magnification
		title_row.custom_minimum_size = Vector2(NORMAL_CONTENT_WIDTH, 28.0) * fisheye_magnification
		title_label.custom_minimum_size = Vector2(150.0, 28.0) * fisheye_magnification
		header_bar.custom_minimum_size = Vector2(NORMAL_CONTENT_WIDTH, 6.0) * fisheye_magnification
	var content_width := (COMPACT_CONTENT_WIDTH if density_compact else NORMAL_CONTENT_WIDTH) * fisheye_magnification
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
	var next_value := clampf(value, FISHEYE_MIN_MAGNIFICATION, FISHEYE_MAX_MAGNIFICATION)
	if is_equal_approx(fisheye_magnification, next_value):
		return
	if fisheye_base_size.is_zero_approx():
		fisheye_base_size = size
	fisheye_magnification = next_value
	_apply_information_density()


func set_fisheye_detail_focus(enabled: bool) -> void:
	if fisheye_detail_focus == enabled:
		return
	fisheye_detail_focus = enabled
	# Density changes alter the unscaled card geometry. Keep the compensation base
	# aligned with that geometry so the magnified card remains centered.
	fisheye_base_size = NORMAL_CARD_SIZE if enabled or not compact_mode else COMPACT_CARD_SIZE
	_apply_information_density()


func set_fisheye_visibility_alpha(value: float) -> void:
	var next_value := clampf(value, 0.0, 1.0)
	if is_equal_approx(fisheye_visibility_alpha, next_value):
		return
	fisheye_visibility_alpha = next_value
	_apply_search_style()


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
		self_modulate = Color.WHITE
		_apply_fisheye_visibility()
		return
	if search_active:
		self_modulate = Color.WHITE if search_matches else Color(0.45, 0.45, 0.45, 0.32)
		if search_current:
			header_bar.color = Color("22d3ee")
		elif search_matches:
			header_bar.color = Color("fbbf24")
		elif node_resource != null:
			header_bar.color = _type_color(node_resource.node_type)
		_apply_fisheye_visibility()
		return
	self_modulate = Color.WHITE
	if node_resource != null:
		header_bar.color = _type_color(node_resource.node_type)
	_apply_selection_style()


func _apply_selection_style() -> void:
	selection_outline_color = Color.TRANSPARENT
	selection_outline_width = 0.0
	if not selection_context_enabled:
		_apply_composed_card_modulate()
		if translucent_cards_enabled:
			_apply_translucent_text_masks()
		queue_redraw()
		return
	match selection_context_role:
		SELECTION_ROLE_SELECTED:
			selection_outline_color = SELECTION_SELECTED_COLOR
			selection_outline_width = SELECTION_SELECTED_OUTLINE_WIDTH
		SELECTION_ROLE_ANCESTOR:
			selection_outline_color = SELECTION_RELATED_COLOR
			selection_outline_width = SELECTION_OUTLINE_WIDTH
		SELECTION_ROLE_DIRECT_CHILD:
			selection_outline_color = SELECTION_RELATED_COLOR
			selection_outline_width = SELECTION_OUTLINE_WIDTH
		SELECTION_ROLE_SIBLING:
			selection_outline_color = SELECTION_SIBLING_COLOR
			selection_outline_width = SELECTION_OUTLINE_WIDTH
	_apply_composed_card_modulate()
	if translucent_cards_enabled:
		_apply_translucent_text_masks()
	queue_redraw()


func _apply_composed_card_modulate() -> void:
	var composed := runtime_card_modulate
	if selection_context_enabled:
		if selection_context_role == SELECTION_ROLE_UNRELATED:
			composed.a *= SELECTION_UNRELATED_ALPHA
		else:
			# Related Focus is the user's current navigation task. Keep every selected
			# family fully visible even if Live Debug would normally dim inactive paths.
			composed.a = 1.0
	# Fisheye fading is a final whole-card factor. Applying it here keeps text,
	# ports, selection frames, Search and Live Debug visually synchronized.
	composed.a *= fisheye_visibility_alpha
	modulate = composed


func _apply_fisheye_visibility() -> void:
	# Recompute from stable feature factors instead of multiplying the previous
	# frame. This prevents stationary-pointer fading from accumulating over time.
	_apply_composed_card_modulate()


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
		runtime_card_modulate = Color(enabled_color.r, enabled_color.g, enabled_color.b, INACTIVE_BRANCH_ALPHA) if runtime_snapshot_active and runtime_dim_non_active and not runtime_active else enabled_color
		_apply_composed_card_modulate()
		runtime_label.text = ""
		_apply_search_style()
		_apply_translucent_text_masks()
		return
	var highlight := _runtime_highlight_color()
	runtime_card_modulate = Color(1.0, 0.96, 0.68, 1.0)
	_apply_composed_card_modulate()
	self_modulate = Color.WHITE
	_apply_fisheye_visibility()
	header_bar.color = highlight
	input_square.color = highlight.darkened(0.2)
	output_square.color = highlight
	order_label.modulate = highlight
	runtime_label.text = "CURRENT: %s" % runtime_status if runtime_leaf else "ACTIVE PATH"
	runtime_label.modulate = highlight
	_apply_translucent_text_masks()


func _runtime_highlight_color() -> Color:
	if not runtime_leaf:
		return Color("facc15")
	match runtime_status:
		"SUCCESS":
			return Color("34d399")
		"FAILURE":
			return Color("f87171")
		"RUNNING":
			return Color("22c55e")
		_:
			return Color("facc15")


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
		if translucent_cards_enabled:
			_apply_translucent_text_mask(badge, TRANSLUCENT_TEXT_DECORATOR_COLOR)


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
