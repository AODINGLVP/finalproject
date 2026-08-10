@tool
extends GraphEdit
class_name BTGraphEdit

signal canvas_context_requested(local_position: Vector2)
signal node_type_dropped(node_type: String, local_position: Vector2)
signal viewport_wheel_scrolled
signal custom_edge_disconnect_requested(from_node: StringName, to_node: StringName)
signal manual_connection_requested(from_node: StringName, to_node: StringName)

const FISHEYE_RADIUS := 430.0
const ENHANCED_MINIMAP_SIZE := Vector2(230.0, 150.0)
const ENHANCED_MINIMAP_OPACITY := 0.72

var fisheye_focus_position := Vector2.ZERO
var orthogonal_edges_enabled := false
var edge_bundling_enabled := false
var active_path_ids: Array[int] = []
var single_connection_rendering_enabled := true
var native_connection_layer: Control
var manual_connection_active := false
var manual_connection_from := StringName()
var manual_connection_pointer := Vector2.ZERO


func _ready() -> void:
	right_disconnects = true
	show_grid = true
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
	_update_native_connection_layer()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		queue_redraw()
	if event is InputEventMouseButton and event.pressed and _is_wheel_button(event.button_index):
		viewport_wheel_scrolled.emit()
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
	for connection in get_connection_list():
		var from_node := get_node_or_null(NodePath(str(connection.get("from_node", "")))) as BTGraphNode
		var to_node := get_node_or_null(NodePath(str(connection.get("to_node", "")))) as BTGraphNode
		if from_node == null or to_node == null:
			continue
		var from_position := _output_port_position(from_node)
		var to_position := _input_port_position(to_node)
		var points := _route_connection_line(from_position, to_position)
		var active := _is_active_connection(from_node.node_resource.id, to_node.node_resource.id)
		var color := Color("f8fafc") if active else from_node.output_square.color.lerp(to_node.input_square.color, 0.35)
		var thickness := 5.0 if active else (2.5 if edge_bundling_enabled else 3.5)
		draw_polyline(points, color, thickness, true)


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


func _get_connection_line(from_position: Vector2, to_position: Vector2) -> PackedVector2Array:
	return _route_connection_line(from_position, to_position)


func _route_connection_line(from_position: Vector2, to_position: Vector2) -> PackedVector2Array:
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
	return _build_bezier_line(from_position, to_position)


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


func set_edge_display(orthogonal_enabled: bool, bundling_enabled: bool) -> void:
	orthogonal_edges_enabled = orthogonal_enabled
	edge_bundling_enabled = bundling_enabled
	if orthogonal_enabled:
		connection_lines_curvature = 0.0
	elif bundling_enabled:
		connection_lines_curvature = 0.82
	else:
		connection_lines_curvature = 0.45
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
		var from_position := _output_port_position(from_node)
		var to_position := _input_port_position(to_node)
		var points := _route_connection_line(from_position, to_position)
		for index in range(points.size() - 1):
			if Geometry2D.get_closest_point_to_segment(local_position, points[index], points[index + 1]).distance_to(local_position) <= tolerance:
				return connection
	return {}


func set_active_path(path_ids: Array) -> void:
	active_path_ids.clear()
	for value in path_ids:
		active_path_ids.append(int(value))
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
