@tool
extends GraphEdit
class_name BTGraphEdit

signal canvas_context_requested(local_position: Vector2)
signal node_type_dropped(node_type: String, local_position: Vector2)
signal viewport_wheel_scrolled(local_position: Vector2)
signal custom_edge_disconnect_requested(from_node: StringName, to_node: StringName)
signal manual_connection_requested(from_node: StringName, to_node: StringName)

const FISHEYE_RADIUS := 82.0
const ENHANCED_MINIMAP_SIZE := Vector2(230.0, 150.0)
const ENHANCED_MINIMAP_OPACITY := 0.72

var fisheye_focus_position := Vector2.ZERO
var orthogonal_edges_enabled := false
var edge_bundling_enabled := false
var always_curved_edges_enabled := false
var straight_connections_enabled := false
var active_path_ids: Array[int] = []
var selection_context_enabled := false
var selection_context_selected_id := -1
var selection_context_path_ids: Array[int] = []
var selection_context_child_ids: Array[int] = []
var selection_context_sibling_ids: Array[int] = []
var single_connection_rendering_enabled := true
var native_connection_layer: Control
var manual_connection_active := false
var manual_connection_from := StringName()
var manual_connection_pointer := Vector2.ZERO
var zoom_boundary_min: GraphNode
var zoom_boundary_max: GraphNode
var connection_route_cache: Dictionary = {}


func _ready() -> void:
	right_disconnects = true
	show_grid = false
	snapping_enabled = true
	zoom_min = 0.1
	minimap_enabled = true
	minimap_size = ENHANCED_MINIMAP_SIZE
	minimap_opacity = ENHANCED_MINIMAP_OPACITY
	# Native GraphNode slots are side-mounted. Keep their hit-testing but render the
	# visible behavior-tree edges ourselves from bottom-center to top-center.
	connection_lines_thickness = 0.0
	connection_lines_curvature = 0.45
	native_connection_layer = get_node_or_null("_connection_layer") as Control
	connection_drag_started.connect(_on_connection_drag_started)
	connection_drag_ended.connect(_on_connection_drag_ended)
	_ensure_zoom_boundary_nodes()
	_update_native_connection_layer()


func set_zoom_scroll_boundary(view_center: Vector2, viewport_tree_size: Vector2) -> void:
	_ensure_zoom_boundary_nodes()
	var margin := Vector2(240.0, 240.0)
	zoom_boundary_min.position_offset = view_center - viewport_tree_size * 0.5 - margin
	zoom_boundary_max.position_offset = view_center + viewport_tree_size * 0.5 + margin


func _ensure_zoom_boundary_nodes() -> void:
	if not is_instance_valid(zoom_boundary_min):
		zoom_boundary_min = _create_zoom_boundary("_zoom_boundary_min")
	if not is_instance_valid(zoom_boundary_max):
		zoom_boundary_max = _create_zoom_boundary("_zoom_boundary_max")


func _create_zoom_boundary(node_name: String) -> GraphNode:
	var boundary := GraphNode.new()
	boundary.name = node_name
	boundary.custom_minimum_size = Vector2.ONE
	boundary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boundary.focus_mode = Control.FOCUS_NONE
	boundary.selectable = false
	boundary.draggable = false
	boundary.resizable = false
	boundary.modulate = Color(1.0, 1.0, 1.0, 0.0)
	boundary.z_index = -4096
	add_child(boundary)
	return boundary


func _gui_input(event: InputEvent) -> void:
	# Node movement and fisheye updates already request redraws when their visuals
	# actually change. Redrawing every edge for unrelated pointer motion wastes most
	# of the frame budget on large trees.
	if event is InputEventMouseButton or (event is InputEventMouseMotion and manual_connection_active):
		queue_redraw()
	if event is InputEventMouseButton and event.pressed and _is_wheel_button(event.button_index):
		viewport_wheel_scrolled.emit(event.position)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var connection := find_connection_at(event.position)
		if single_connection_rendering_enabled and not connection.is_empty():
			custom_edge_disconnect_requested.emit(StringName(connection["from_node"]), StringName(connection["to_node"]))
			accept_event()
			return
		canvas_context_requested.emit(event.position)
		accept_event()


func _input(event: InputEvent) -> void:
	# A drag can leave its source GraphNode, so GraphEdit must own the pointer
	# until release. Otherwise the target node consumes the release event.
	if not manual_connection_active or not (event is InputEventMouse):
		return
	var local_event := make_input_local(event) as InputEventMouse
	var local_position: Vector2 = local_event.position
	if event is InputEventMouseMotion:
		update_manual_connection(local_position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		finish_manual_connection(local_position)
		get_viewport().set_input_as_handled()


func _is_wheel_button(button_index: int) -> bool:
	return button_index == MOUSE_BUTTON_WHEEL_UP \
		or button_index == MOUSE_BUTTON_WHEEL_DOWN \
		or button_index == MOUSE_BUTTON_WHEEL_LEFT \
		or button_index == MOUSE_BUTTON_WHEEL_RIGHT


func _draw() -> void:
	_draw_behavior_tree_connections()
	_draw_manual_connection_preview()
	if fisheye_focus_position == Vector2.ZERO:
		return
	draw_circle(fisheye_focus_position, FISHEYE_RADIUS, Color(0.45, 0.75, 1.0, 0.055))
	draw_arc(fisheye_focus_position, FISHEYE_RADIUS, 0.0, TAU, 96, Color(0.45, 0.75, 1.0, 0.18), 2.0)


func _draw_behavior_tree_connections() -> void:
	if not single_connection_rendering_enabled:
		return
	var viewport_rect := Rect2(Vector2.ZERO, size).grow(64.0)
	for connection in get_connection_list():
		var from_node := get_node_or_null(NodePath(str(connection.get("from_node", "")))) as BTGraphNode
		var to_node := get_node_or_null(NodePath(str(connection.get("to_node", "")))) as BTGraphNode
		if from_node == null or to_node == null:
			continue
		var from_position := _output_port_position(from_node)
		var to_position := _input_port_position(to_node)
		var rough_bounds := Rect2(from_position, Vector2.ZERO).expand(to_position).grow(32.0)
		if not viewport_rect.intersects(rough_bounds):
			continue
		var cache_key := "%s>%s" % [from_node.name, to_node.name]
		var points := _cached_connection_between(cache_key, from_node, to_node)
		var active := _is_active_connection(from_node.node_resource.id, to_node.node_resource.id)
		var selection_role := _selection_connection_role(from_node.node_resource.id, to_node.node_resource.id)
		var color := from_node.output_square.color.lerp(to_node.input_square.color, 0.35)
		var thickness := 2.5 if edge_bundling_enabled else 3.5
		if active:
			color = Color("f8fafc")
			thickness = 5.0
		elif selection_role == "path":
			color = Color("60a5fa")
			thickness = 4.6
		elif selection_role == "child":
			color = Color("34d399")
			thickness = 4.3
		elif selection_role == "sibling":
			color = Color("c4b5fd")
			thickness = 3.9
		elif selection_context_enabled and selection_context_selected_id != -1:
			color.a *= 0.34
			thickness = 2.5
		draw_polyline(points, color, thickness, true)


func _cached_connection_line(cache_key: String, from_position: Vector2, to_position: Vector2) -> PackedVector2Array:
	var cached: Dictionary = connection_route_cache.get(cache_key, {})
	if not cached.is_empty() \
			and Vector2(cached.get("from", Vector2.INF)).is_equal_approx(from_position) \
			and Vector2(cached.get("to", Vector2.INF)).is_equal_approx(to_position):
		return cached.get("points", PackedVector2Array()) as PackedVector2Array
	var points := _route_connection_line(from_position, to_position)
	connection_route_cache[cache_key] = {
		"from": from_position,
		"to": to_position,
		"points": points,
	}
	return points


func _cached_connection_between(cache_key: String, from_node: BTGraphNode, to_node: BTGraphNode) -> PackedVector2Array:
	var from_position := _output_port_position(from_node)
	var to_position := _input_port_position(to_node)
	return _cached_connection_line(cache_key, from_position, to_position)


func _draw_manual_connection_preview() -> void:
	if not manual_connection_active:
		return
	var from_node := get_node_or_null(NodePath(str(manual_connection_from))) as BTGraphNode
	if from_node == null:
		return
	var start := _output_port_position(from_node)
	var target := find_input_port_at(manual_connection_pointer, manual_connection_from)
	var end := manual_connection_pointer
	if target != StringName():
		var target_node := get_node_or_null(NodePath(str(target))) as BTGraphNode
		if target_node != null:
			end = _input_port_position(target_node)
	var color := from_node.output_square.color.lightened(0.2)
	draw_polyline(_route_connection_line(start, end), color, 4.0, true)
	draw_circle(end, 7.0, color)


func begin_manual_connection(from_node: StringName, local_position: Vector2) -> void:
	if get_node_or_null(NodePath(str(from_node))) == null:
		return
	manual_connection_active = true
	manual_connection_from = from_node
	manual_connection_pointer = local_position
	queue_redraw()


func update_manual_connection(local_position: Vector2) -> void:
	if not manual_connection_active:
		return
	manual_connection_pointer = local_position
	queue_redraw()


func finish_manual_connection(local_position: Vector2) -> void:
	if not manual_connection_active:
		return
	manual_connection_pointer = local_position
	var from_node := manual_connection_from
	var to_node := find_input_port_at(local_position, from_node)
	cancel_manual_connection()
	if to_node != StringName():
		manual_connection_requested.emit(from_node, to_node)


func cancel_manual_connection() -> void:
	var source_node := get_node_or_null(NodePath(str(manual_connection_from))) as BTGraphNode
	if source_node != null:
		source_node.manual_connection_dragging = false
	manual_connection_active = false
	manual_connection_from = StringName()
	manual_connection_pointer = Vector2.ZERO
	queue_redraw()


func find_input_port_at(local_position: Vector2, excluded_node := StringName(), tolerance := 34.0) -> StringName:
	var closest_node := StringName()
	var closest_distance := INF
	for child in get_children():
		var graph_node := child as BTGraphNode
		if graph_node == null or StringName(graph_node.name) == excluded_node or not graph_node.visible:
			continue
		var distance := local_position.distance_to(_input_port_position(graph_node))
		if distance <= tolerance and distance < closest_distance:
			closest_node = StringName(graph_node.name)
			closest_distance = distance
	return closest_node


func _input_port_position(graph_node: BTGraphNode) -> Vector2:
	var rendered_size := graph_node.size * graph_node.scale
	return graph_node.position + Vector2(rendered_size.x * 0.5, 7.0 * graph_node.scale.y)


func _output_port_position(graph_node: BTGraphNode) -> Vector2:
	var rendered_size := graph_node.size * graph_node.scale
	return graph_node.position + Vector2(rendered_size.x * 0.5, rendered_size.y - 7.0 * graph_node.scale.y)


func _is_active_connection(from_id: int, to_id: int) -> bool:
	for index in range(active_path_ids.size() - 1):
		if active_path_ids[index] == from_id and active_path_ids[index + 1] == to_id:
			return true
	return false


func _selection_connection_role(from_id: int, to_id: int) -> String:
	if not selection_context_enabled or selection_context_selected_id == -1:
		return ""
	for index in range(selection_context_path_ids.size() - 1):
		if selection_context_path_ids[index] == from_id and selection_context_path_ids[index + 1] == to_id:
			return "path"
	if from_id == selection_context_selected_id and selection_context_child_ids.has(to_id):
		return "child"
	if selection_context_path_ids.size() >= 2:
		var selected_parent_id := selection_context_path_ids[selection_context_path_ids.size() - 2]
		if from_id == selected_parent_id and selection_context_sibling_ids.has(to_id):
			return "sibling"
	return ""


func _get_connection_line(from_position: Vector2, to_position: Vector2) -> PackedVector2Array:
	return _route_connection_line(from_position, to_position)


func _route_connection_line(from_position: Vector2, to_position: Vector2) -> PackedVector2Array:
	if straight_connections_enabled:
		return PackedVector2Array([from_position, to_position])
	if always_curved_edges_enabled:
		return _build_bezier_line(from_position, to_position)
	if edge_bundling_enabled:
		var direction := 1.0 if to_position.y >= from_position.y else -1.0
		var trunk_y := from_position.y + direction * minf(72.0, absf(to_position.y - from_position.y) * 0.35)
		return PackedVector2Array([
			from_position,
			Vector2(from_position.x, trunk_y),
			Vector2(to_position.x, trunk_y),
			to_position,
		])
	if orthogonal_edges_enabled:
		var middle_y := (from_position.y + to_position.y) * 0.5
		return PackedVector2Array([
			from_position,
			Vector2(from_position.x, middle_y),
			Vector2(to_position.x, middle_y),
			to_position,
		])
	return _build_channel_line(from_position, to_position)


func _route_connection_between(from_node: BTGraphNode, to_node: BTGraphNode) -> PackedVector2Array:
	return _route_connection_line(_output_port_position(from_node), _input_port_position(to_node))


func _polyline_length(points: PackedVector2Array) -> float:
	var length := 0.0
	for index in range(points.size() - 1):
		length += points[index].distance_to(points[index + 1])
	return length


func _build_channel_line(from_position: Vector2, to_position: Vector2) -> PackedVector2Array:
	var vertical_distance := to_position.y - from_position.y
	if vertical_distance <= 8.0:
		return _build_bezier_line(from_position, to_position)
	var lane_y := from_position.y + vertical_distance * 0.5
	var horizontal_distance := to_position.x - from_position.x
	var direction_x := signf(horizontal_distance)
	if is_zero_approx(direction_x):
		return PackedVector2Array([from_position, to_position])
	var radius := minf(24.0, minf(vertical_distance * 0.22, absf(horizontal_distance) * 0.22))
	var points := PackedVector2Array([from_position, Vector2(from_position.x, lane_y - radius)])
	_append_quadratic_points(
		points,
		Vector2(from_position.x, lane_y - radius),
		Vector2(from_position.x, lane_y),
		Vector2(from_position.x + direction_x * radius, lane_y)
	)
	points.append(Vector2(to_position.x - direction_x * radius, lane_y))
	_append_quadratic_points(
		points,
		Vector2(to_position.x - direction_x * radius, lane_y),
		Vector2(to_position.x, lane_y),
		Vector2(to_position.x, lane_y + radius)
	)
	points.append(to_position)
	return points


func _append_quadratic_points(points: PackedVector2Array, start: Vector2, control: Vector2, finish: Vector2) -> void:
	for index in range(1, 5):
		var weight := float(index) / 4.0
		var inverse := 1.0 - weight
		points.append(inverse * inverse * start + 2.0 * inverse * weight * control + weight * weight * finish)


func _build_bezier_line(from_position: Vector2, to_position: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var vertical_distance := absf(to_position.y - from_position.y)
	var handle_offset := maxf(40.0, vertical_distance * 0.45)
	var control_a := from_position + Vector2(0.0, handle_offset)
	var control_b := to_position - Vector2(0.0, handle_offset)
	for index in range(13):
		var weight := float(index) / 12.0
		var inverse := 1.0 - weight
		points.append(
			inverse * inverse * inverse * from_position
			+ 3.0 * inverse * inverse * weight * control_a
			+ 3.0 * inverse * weight * weight * control_b
			+ weight * weight * weight * to_position
		)
	return points


func set_edge_display(orthogonal_enabled: bool, bundling_enabled: bool, always_curved_enabled := false, straight_enabled := false) -> void:
	orthogonal_edges_enabled = orthogonal_enabled
	edge_bundling_enabled = bundling_enabled
	always_curved_edges_enabled = always_curved_enabled
	straight_connections_enabled = straight_enabled
	if straight_enabled:
		connection_lines_curvature = 0.0
	elif always_curved_enabled:
		connection_lines_curvature = 1.0
	elif bundling_enabled:
		connection_lines_curvature = 0.82
	elif orthogonal_enabled:
		connection_lines_curvature = 0.0
	else:
		connection_lines_curvature = 0.45
	connection_route_cache.clear()
	connection_lines_thickness = 0.0 if single_connection_rendering_enabled else 3.5
	queue_redraw()


func set_single_connection_rendering(enabled: bool) -> void:
	single_connection_rendering_enabled = enabled
	connection_lines_thickness = 0.0 if enabled else 3.5
	_update_native_connection_layer()
	queue_redraw()


func _on_connection_drag_started(_from_node: StringName, _from_port: int, _is_output: bool) -> void:
	if single_connection_rendering_enabled and is_instance_valid(native_connection_layer):
		native_connection_layer.visible = true


func _on_connection_drag_ended() -> void:
	_update_native_connection_layer()


func _update_native_connection_layer() -> void:
	if not is_instance_valid(native_connection_layer):
		native_connection_layer = get_node_or_null("_connection_layer") as Control
	if is_instance_valid(native_connection_layer):
		native_connection_layer.visible = not single_connection_rendering_enabled


func find_connection_at(local_position: Vector2, tolerance := 10.0) -> Dictionary:
	for connection in get_connection_list():
		var from_node := get_node_or_null(NodePath(str(connection.get("from_node", "")))) as BTGraphNode
		var to_node := get_node_or_null(NodePath(str(connection.get("to_node", "")))) as BTGraphNode
		if from_node == null or to_node == null:
			continue
		var cache_key := "%s>%s" % [from_node.name, to_node.name]
		var points := _cached_connection_between(cache_key, from_node, to_node)
		for index in range(points.size() - 1):
			if Geometry2D.get_closest_point_to_segment(local_position, points[index], points[index + 1]).distance_to(local_position) <= tolerance:
				return connection
	return {}


func set_active_path(path_ids: Array) -> void:
	active_path_ids.clear()
	for value in path_ids:
		active_path_ids.append(int(value))
	queue_redraw()


func set_selection_context(enabled: bool, selected_id: int, path_ids: Array, child_ids: Array, sibling_ids: Array) -> void:
	selection_context_enabled = enabled and selected_id != -1
	selection_context_selected_id = selected_id if selection_context_enabled else -1
	selection_context_path_ids.clear()
	selection_context_child_ids.clear()
	selection_context_sibling_ids.clear()
	if selection_context_enabled:
		for value in path_ids:
			selection_context_path_ids.append(int(value))
		for value in child_ids:
			selection_context_child_ids.append(int(value))
		for value in sibling_ids:
			selection_context_sibling_ids.append(int(value))
	queue_redraw()


func set_enhanced_minimap(enabled: bool) -> void:
	minimap_enabled = enabled
	if enabled:
		minimap_size = ENHANCED_MINIMAP_SIZE
		minimap_opacity = ENHANCED_MINIMAP_OPACITY


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.get("kind", "") == "bt_node_type"


func _drop_data(at_position: Vector2, data: Variant) -> void:
	node_type_dropped.emit(str(data.get("node_type", "")), at_position)
