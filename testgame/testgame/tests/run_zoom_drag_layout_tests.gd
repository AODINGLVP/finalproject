extends SceneTree

const BTEditorView = preload("res://addons/behavior_tree_editor/bt_editor_view.gd")
const BTGraphNode = preload("res://addons/behavior_tree_editor/bt_graph_node.gd")
const BTNodeResource = preload("res://addons/behavior_tree_editor/bt_node_resource.gd")
const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")
const TreeFactory = preload("res://tests/support/multiscale_tree_factory.gd")

const SCALE_COUNTS := [31, 61, 121, 241, 364]
const SETTLE_FRAMES := 4
const POSITION_EPSILON := 0.05

var passed := 0
var failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var view := await _make_view()
	await _test_complete_zoom_range(view)
	await _test_complex_tree_scales(view)
	await _test_drag_undo_redo(view)
	await _test_save_reload_reflow(view)
	await _test_topology_cache_invalidation(view)
	_test_saved_large_tree_layouts()
	print("BT_ZOOM_DRAG_LAYOUT_TEST_SUMMARY passed=%d failed=%d" % [passed, failed])
	view.free()
	quit(0 if failed == 0 else 1)


func _make_view() -> BTEditorView:
	var view := BTEditorView.new()
	view.set_anchors_preset(Control.PRESET_TOP_LEFT)
	view.size = Vector2(1600.0, 900.0)
	root.add_child(view)
	await process_frame
	await process_frame
	view._set_feature_enabled("fisheye", false, false)
	view._set_feature_enabled("subtree_collapse", false, false)
	view._set_feature_enabled("auto_spacing", true, false)
	return view


func _test_complete_zoom_range(view: BTEditorView) -> void:
	var zoom_values: Array[float] = [
		view.graph_edit.zoom_min,
		0.25,
		0.50,
		0.619,
		0.620,
		0.621,
		0.75,
		0.879,
		0.880,
		0.881,
		1.0,
		(view.graph_edit.zoom_min + view.graph_edit.zoom_max) * 0.5,
		view.graph_edit.zoom_max,
	]
	for semantic_zoom in [false, true]:
		for compact_cards in [false, true]:
			for requested_zoom in zoom_values:
				var zoom_value := clampf(requested_zoom, view.graph_edit.zoom_min, view.graph_edit.zoom_max)
				var label := "zoom %.3f semantic=%s compact=%s" % [zoom_value, semantic_zoom, compact_cards]
				await _prepare_view(view, _make_drag_tree(), zoom_value, semantic_zoom, compact_cards)
				var structure_before := _structure_signature(view.current_tree)
				var other_positions := _resource_positions_except(view.current_tree, 3)
				var drag_result := _drag_graph_node_onto(view, 3, 4)
				_expect(bool(drag_result.get("started", false)), "%s starts a real card drag" % label)
				_expect(bool(drag_result.get("resource_unchanged_during_drag", false)), "%s defers resource writes until release" % label)
				var order_after_release := _execution_order_signature(view.current_tree)
				await _wait_frames(SETTLE_FRAMES)
				_expect(_rendered_overlaps(view).is_empty(), "%s automatically removes graph-space overlaps" % label)
				_expect(_screen_overlaps(view).is_empty(), "%s has no screen-space card overlaps" % label)
				_expect(_structure_signature(view.current_tree) == structure_before, "%s preserves tree structure and parameters" % label)
				_expect(_resource_positions_except_equal(view.current_tree, 3, other_positions), "%s does not move other saved nodes" % label)
				_expect(_execution_order_signature(view.current_tree) == order_after_release, "%s reflow preserves post-drag execution order" % label)
				var stable_positions := _render_positions(view)
				await _wait_frames(3)
				_expect(_render_positions_equal(view, stable_positions), "%s remains stable without layout jitter" % label)


func _test_complex_tree_scales(view: BTEditorView) -> void:
	for node_count in SCALE_COUNTS:
		for zoom_value in [view.graph_edit.zoom_min, 1.0, view.graph_edit.zoom_max]:
			var tree := TreeFactory.generate(node_count) as BTTreeResource
			_assign_layered_positions(tree)
			await _prepare_view(view, tree, zoom_value, true, false)
			var leaf_ids := _last_leaf_ids(tree, 2)
			var label := "%d nodes at zoom %.3f" % [node_count, zoom_value]
			_expect(leaf_ids.size() == 2, "%s provides two independent drag targets" % label)
			if leaf_ids.size() != 2:
				continue
			var structure_before := _structure_signature(tree)
			_drag_graph_node_onto(view, leaf_ids[0], leaf_ids[1])
			var order_after_release := _execution_order_signature(tree)
			await _wait_frames(SETTLE_FRAMES)
			_expect(_rendered_overlaps(view).is_empty(), "%s reflows a collision without overlap" % label)
			_expect(_structure_signature(tree) == structure_before and tree.validate_tree().is_empty(), "%s keeps the generated behavior tree valid" % label)
			_expect(_execution_order_signature(tree) == order_after_release, "%s keeps execution order after automatic reflow" % label)


func _test_drag_undo_redo(view: BTEditorView) -> void:
	await _prepare_view(view, _make_drag_tree(), view.graph_edit.zoom_min, false, false)
	var original_position := view.current_tree.find_node(3).position
	_drag_graph_node_onto(view, 3, 4)
	await _wait_frames(SETTLE_FRAMES)
	var dragged_position := view.current_tree.find_node(3).position
	_expect(not dragged_position.is_equal_approx(original_position), "minimum-zoom drag stores the released logical position")
	view._undo()
	await _wait_frames(SETTLE_FRAMES)
	_expect(view.current_tree.find_node(3).position.is_equal_approx(original_position), "minimum-zoom drag can be undone")
	_expect(_rendered_overlaps(view).is_empty(), "undo remains overlap-free")
	view._redo()
	await _wait_frames(SETTLE_FRAMES)
	_expect(view.current_tree.find_node(3).position.is_equal_approx(dragged_position), "minimum-zoom drag can be redone")
	_expect(_rendered_overlaps(view).is_empty(), "redo automatically restores an overlap-free view")


func _test_save_reload_reflow(view: BTEditorView) -> void:
	await _prepare_view(view, _make_drag_tree(), view.graph_edit.zoom_min, false, true)
	_drag_graph_node_onto(view, 3, 4)
	await _wait_frames(SETTLE_FRAMES)
	var saved_structure := _structure_signature(view.current_tree)
	var saved_order := _execution_order_signature(view.current_tree)
	var saved_positions := _resource_positions(view.current_tree)
	var save_path := "user://zoom_drag_layout_roundtrip.tres"
	var save_error := ResourceSaver.save(view.current_tree, save_path)
	_expect(save_error == OK, "collision-edited tree saves successfully")
	var loaded := ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as BTTreeResource
	_expect(loaded != null, "collision-edited tree reloads successfully")
	if loaded == null:
		return
	var fresh_view := await _make_view()
	await _prepare_view(fresh_view, loaded, fresh_view.graph_edit.zoom_min, false, true)
	_expect(_rendered_overlaps(fresh_view).is_empty(), "freshly loaded tree automatically reflows at minimum zoom")
	_expect(_structure_signature(loaded) == saved_structure, "save/reload preserves structure and parameters")
	_expect(_execution_order_signature(loaded) == saved_order, "save/reload preserves execution order")
	_expect(_resource_positions_equal(loaded, saved_positions), "save/reload preserves logical node positions")
	fresh_view.free()


func _test_topology_cache_invalidation(view: BTEditorView) -> void:
	var tree_a := _make_topology_tree(false)
	await _prepare_view(view, tree_a, 1.0, true, false)
	var signature_a := view._auto_spacing_layout_signature()
	var tree_b := _make_topology_tree(true)
	await _prepare_view(view, tree_b, 1.0, true, false)
	var signature_b := view._auto_spacing_layout_signature()
	_expect(signature_a != signature_b, "auto-spacing cache key includes parent topology")
	_expect(_rendered_overlaps(view).is_empty(), "switching to same-size nodes with different topology recomputes a valid layout")


func _test_saved_large_tree_layouts() -> void:
	for node_count in [121, 364]:
		var path := "res://behavior_trees/human_study_tree_%d.tres" % node_count
		var tree := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as BTTreeResource
		_expect(tree != null, "%d-node saved study tree loads" % node_count)
		if tree == null:
			continue
		_expect(tree.validate_tree().is_empty(), "%d-node saved study tree remains structurally valid" % node_count)
		_expect(_saved_card_overlaps(tree) == 0, "%d-node saved study tree opens without stacked cards" % node_count)
		_expect(_saved_card_positions_unique(tree), "%d-node saved study tree has distinct card coordinates" % node_count)


func _prepare_view(view: BTEditorView, tree: BTTreeResource, zoom_value: float, semantic_zoom: bool, compact_cards: bool) -> void:
	view._set_feature_enabled("auto_spacing", true, false)
	view._set_feature_enabled("semantic_zoom", semantic_zoom, false)
	view._set_feature_enabled("compact", compact_cards, false)
	view.graph_edit.zoom = clampf(zoom_value, view.graph_edit.zoom_min, view.graph_edit.zoom_max)
	view.current_tree = tree
	view.current_tree_path = ""
	view.selected_node_id = -1
	view.next_node_id = _next_node_id(tree)
	view.undo_stack.clear()
	view.redo_stack.clear()
	view._update_semantic_zoom()
	view._rebuild_graph()
	await _wait_frames(3)
	view._update_semantic_zoom()
	await _wait_frames(2)


func _drag_graph_node_onto(view: BTEditorView, source_id: int, target_id: int) -> Dictionary:
	var source := _graph_node(view, source_id)
	var target := _graph_node(view, target_id)
	if source == null or target == null:
		return {}
	var resource_before := source.node_resource.position
	var local_pointer := Vector2(38.0, source.size.y * 0.5)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = local_pointer
	source._gui_input(press)
	var destination := target.position_offset + Vector2(1.0, 1.0)
	var graph_delta := destination - source.position_offset
	var motion := InputEventMouseMotion.new()
	motion.position = local_pointer + graph_delta * view.graph_edit.zoom
	motion.relative = graph_delta * view.graph_edit.zoom
	source._gui_input(motion)
	var unchanged_during_drag := source.node_resource.position.is_equal_approx(resource_before)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = local_pointer
	source._gui_input(release)
	return {
		"started": not graph_delta.is_zero_approx(),
		"resource_unchanged_during_drag": unchanged_during_drag,
	}


func _make_drag_tree() -> BTTreeResource:
	var tree := BTTreeResource.new()
	tree.tree_name = "Zoom Drag Layout Fixture"
	tree.root_node_id = 1
	tree.nodes = [
		_make_node(1, BTNodeResource.TYPE_ROOT, -1, Vector2(360.0, 0.0)),
		_make_node(2, BTNodeResource.TYPE_SEQUENCE, 1, Vector2(360.0, 260.0)),
		_make_node(3, BTNodeResource.TYPE_ACTION, 2, Vector2(0.0, 520.0)),
		_make_node(4, BTNodeResource.TYPE_ACTION, 2, Vector2(360.0, 520.0)),
		_make_node(5, BTNodeResource.TYPE_ACTION, 2, Vector2(720.0, 520.0)),
	]
	return tree


func _make_topology_tree(alternate: bool) -> BTTreeResource:
	var tree := BTTreeResource.new()
	tree.tree_name = "Topology Cache B" if alternate else "Topology Cache A"
	tree.root_node_id = 1
	var parent_4 := 3 if alternate else 2
	var parent_5 := 2 if alternate else 3
	tree.nodes = [
		_make_node(1, BTNodeResource.TYPE_ROOT, -1, Vector2(0.0, 0.0)),
		_make_node(2, BTNodeResource.TYPE_PARALLEL, 1, Vector2(0.0, 80.0)),
		_make_node(3, BTNodeResource.TYPE_SEQUENCE, 2, Vector2(0.0, 160.0)),
		_make_node(4, BTNodeResource.TYPE_ACTION, parent_4, Vector2(0.0, 240.0)),
		_make_node(5, BTNodeResource.TYPE_ACTION, parent_5, Vector2(0.0, 320.0)),
	]
	return tree


func _make_node(id: int, node_type: String, parent_id: int, position: Vector2) -> BTNodeResource:
	var node := BTNodeResource.new()
	node.id = id
	node.node_type = node_type
	node.parent_id = parent_id
	node.position = position
	node.title = "%s %d" % [node_type, id]
	node.description = "Zoom and drag layout regression fixture."
	if node_type == BTNodeResource.TYPE_ACTION:
		node.parameters = {"action_name": "layout_action_%d" % id}
	elif node_type == BTNodeResource.TYPE_PARALLEL:
		node.parameters = {"success_policy": "all", "failure_policy": "any"}
	return node


func _assign_layered_positions(tree: BTTreeResource) -> void:
	var rows: Dictionary = {}
	for node in tree.nodes:
		if node == null or node.decorator_parent_id != -1:
			continue
		var depth := _node_depth(tree, node)
		if not rows.has(depth):
			rows[depth] = []
		var row: Array = rows[depth]
		row.append(node)
		rows[depth] = row
	var depths: Array = rows.keys()
	depths.sort()
	for depth_variant in depths:
		var depth := int(depth_variant)
		var row: Array = rows[depth]
		row.sort_custom(func(left: BTNodeResource, right: BTNodeResource) -> bool: return left.id < right.id)
		for index in range(row.size()):
			var node := row[index] as BTNodeResource
			node.position = Vector2(float(index) * 300.0, float(depth) * 260.0)


func _node_depth(tree: BTTreeResource, node: BTNodeResource) -> int:
	var depth := 0
	var cursor := node
	var visited: Dictionary = {}
	while cursor != null and cursor.parent_id != -1 and not visited.has(cursor.id):
		visited[cursor.id] = true
		depth += 1
		cursor = tree.find_node(cursor.parent_id)
	return depth


func _last_leaf_ids(tree: BTTreeResource, count: int) -> Array[int]:
	var result: Array[int] = []
	for index in range(tree.nodes.size() - 1, -1, -1):
		var node := tree.nodes[index]
		if node == null or node.decorator_parent_id != -1 or not tree.get_children_of(node.id).is_empty():
			continue
		result.append(node.id)
		if result.size() == count:
			break
	return result


func _graph_node(view: BTEditorView, node_id: int) -> BTGraphNode:
	return view.graph_edit.get_node_or_null(NodePath(str(node_id))) as BTGraphNode


func _graph_nodes(view: BTEditorView) -> Array[BTGraphNode]:
	var result: Array[BTGraphNode] = []
	for child in view.graph_edit.get_children():
		if child is BTGraphNode:
			result.append(child)
	return result


func _rendered_overlaps(view: BTEditorView) -> Array[String]:
	var nodes := _graph_nodes(view)
	var overlaps: Array[String] = []
	for left_index in range(nodes.size()):
		for right_index in range(left_index + 1, nodes.size()):
			var left := nodes[left_index]
			var right := nodes[right_index]
			if Rect2(left.position_offset, left.size).intersects(Rect2(right.position_offset, right.size)):
				overlaps.append("%d-%d" % [left.node_resource.id, right.node_resource.id])
	return overlaps


func _screen_overlaps(view: BTEditorView) -> Array[String]:
	var nodes := _graph_nodes(view)
	var overlaps: Array[String] = []
	var zoom := view.graph_edit.zoom
	for left_index in range(nodes.size()):
		for right_index in range(left_index + 1, nodes.size()):
			var left := nodes[left_index]
			var right := nodes[right_index]
			var left_rect := Rect2(left.position_offset * zoom, left.size * zoom)
			var right_rect := Rect2(right.position_offset * zoom, right.size * zoom)
			if left_rect.intersects(right_rect):
				overlaps.append("%d-%d" % [left.node_resource.id, right.node_resource.id])
	return overlaps


func _render_positions(view: BTEditorView) -> Dictionary:
	var result := {}
	for graph_node in _graph_nodes(view):
		result[graph_node.node_resource.id] = graph_node.position_offset
	return result


func _render_positions_equal(view: BTEditorView, expected: Dictionary) -> bool:
	for graph_node in _graph_nodes(view):
		if not expected.has(graph_node.node_resource.id):
			return false
		if graph_node.position_offset.distance_to(Vector2(expected[graph_node.node_resource.id])) > POSITION_EPSILON:
			return false
	return expected.size() == _graph_nodes(view).size()


func _resource_positions(tree: BTTreeResource) -> Dictionary:
	var result := {}
	for node in tree.nodes:
		if node != null:
			result[node.id] = node.position
	return result


func _resource_positions_except(tree: BTTreeResource, excluded_id: int) -> Dictionary:
	var result := {}
	for node in tree.nodes:
		if node != null and node.id != excluded_id:
			result[node.id] = node.position
	return result


func _resource_positions_except_equal(tree: BTTreeResource, excluded_id: int, expected: Dictionary) -> bool:
	for node in tree.nodes:
		if node == null or node.id == excluded_id:
			continue
		if not expected.has(node.id) or not node.position.is_equal_approx(Vector2(expected[node.id])):
			return false
	return true


func _resource_positions_equal(tree: BTTreeResource, expected: Dictionary) -> bool:
	for node in tree.nodes:
		if node == null or not expected.has(node.id) or not node.position.is_equal_approx(Vector2(expected[node.id])):
			return false
	return expected.size() == tree.nodes.size()


func _structure_signature(tree: BTTreeResource) -> String:
	var entries: Array[String] = []
	for node in tree.nodes:
		if node == null:
			entries.append("null")
			continue
		entries.append("%d:%s:%d:%d:%s" % [
			node.id,
			node.node_type,
			node.parent_id,
			node.decorator_parent_id,
			JSON.stringify(node.parameters),
		])
	entries.sort()
	return "%d|%s" % [tree.root_node_id, "|".join(entries)]


func _execution_order_signature(tree: BTTreeResource) -> String:
	var entries: Array[String] = []
	for node in tree.nodes:
		if node == null or node.decorator_parent_id != -1:
			continue
		var child_ids: Array[String] = []
		for child in tree.get_children_of(node.id):
			child_ids.append(str(child.id))
		entries.append("%d:%s" % [node.id, ",".join(child_ids)])
	entries.sort()
	return "|".join(entries)


func _saved_card_overlaps(tree: BTTreeResource) -> int:
	var cards: Array[BTNodeResource] = []
	for node in tree.nodes:
		if node != null and node.decorator_parent_id == -1:
			cards.append(node)
	var overlaps := 0
	for left_index in range(cards.size()):
		for right_index in range(left_index + 1, cards.size()):
			if Rect2(cards[left_index].position, BTGraphNode.NORMAL_CARD_SIZE).intersects(Rect2(cards[right_index].position, BTGraphNode.NORMAL_CARD_SIZE)):
				overlaps += 1
	return overlaps


func _saved_card_positions_unique(tree: BTTreeResource) -> bool:
	var positions := {}
	for node in tree.nodes:
		if node == null or node.decorator_parent_id != -1:
			continue
		var key := "%.3f,%.3f" % [node.position.x, node.position.y]
		if positions.has(key):
			return false
		positions[key] = true
	return true


func _next_node_id(tree: BTTreeResource) -> int:
	var result := 1
	for node in tree.nodes:
		if node != null:
			result = maxi(result, node.id + 1)
	return result


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		printerr("FAIL: %s" % label)
