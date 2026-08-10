extends SceneTree

const BTEditorView = preload("res://addons/behavior_tree_editor/bt_editor_view.gd")
const BTGraphNode = preload("res://addons/behavior_tree_editor/bt_graph_node.gd")
const BTNodeResource = preload("res://addons/behavior_tree_editor/bt_node_resource.gd")
const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")

const OUTPUT_PATH := "res://test_results/display_optimization_raw.csv"
const TREE_SIZES := [31, 121, 364]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var rows: Array[PackedStringArray] = []
	rows.append(PackedStringArray([
		"tree_size", "method", "visible_nodes", "visible_ratio", "card_area_px2",
		"information_fields", "dimmed_nodes", "focus_scale_gain", "rebuild_ms"
	]))
	for tree_size in TREE_SIZES:
		var view := BTEditorView.new()
		root.add_child(view)
		await process_frame
		view.current_tree = _generate_tree(tree_size)
		view.current_tree_path = "res://benchmarks/tree_%d.tres" % tree_size
		view.next_node_id = tree_size + 1
		view.selected_node_id = max(2, tree_size / 3)
		view._auto_arrange_tree()
		await process_frame

		rows.append(_measure(view, tree_size, "Baseline", 6, 0, 1.0))

		view._on_compact_toggled(true)
		await process_frame
		rows.append(_measure(view, tree_size, "Compact Cards", 2, 0, 1.0))
		view._on_compact_toggled(false)
		await process_frame

		view.semantic_zoom_enabled = true
		view.graph_edit.zoom = 0.5
		view._update_semantic_zoom()
		await process_frame
		rows.append(_measure(view, tree_size, "Semantic Zoom", 1, 0, 1.0))
		view.semantic_zoom_enabled = false
		view.semantic_detail_level = 2
		view._apply_semantic_detail_level()
		await process_frame

		view._on_search_changed("target_%d" % tree_size)
		var dimmed := _count_dimmed(view)
		rows.append(_measure(view, tree_size, "Search Highlight", 6, dimmed, 1.0))
		view._on_search_changed("")
		await process_frame

		view.focus_root_id = max(2, tree_size / 3)
		var focus_start := Time.get_ticks_usec()
		view._rebuild_graph()
		await process_frame
		var focus_ms := float(Time.get_ticks_usec() - focus_start) / 1000.0
		rows.append(_measure(view, tree_size, "Subtree Focus", 6, 0, 1.0, focus_ms))
		view.focus_root_id = -1
		view._rebuild_graph()
		await process_frame

		var collapse_start := Time.get_ticks_usec()
		for node in view.current_tree.nodes:
			if node != null and node.id != view.current_tree.root_node_id and not view.current_tree.get_children_of(node.id).is_empty():
				node.collapsed = true
		view._rebuild_graph()
		await process_frame
		var collapse_ms := float(Time.get_ticks_usec() - collapse_start) / 1000.0
		rows.append(_measure(view, tree_size, "Subtree Collapse", 4, 0, 1.0, collapse_ms))
		for node in view.current_tree.nodes:
			if node != null:
				node.collapsed = false
		view._rebuild_graph()
		await process_frame

		var fisheye_node := _first_graph_node(view)
		view._apply_node_fisheye_scale(fisheye_node, view.FISHEYE_MAX_SCALE, 1.0, 1.0)
		rows.append(_measure(view, tree_size, "Fisheye", 6, 0, fisheye_node.fisheye_magnification))
		view._reset_fisheye()

		rows.append(_measure(view, tree_size, "Minimap", 6, 0, 1.0))
		rows.append(_measure(view, tree_size, "Fit to View", 6, 0, 1.0))

		for definition in view.FEATURE_DEFINITIONS:
			var key := str(definition[0])
			var label := str(definition[1])
			var feature_start := Time.get_ticks_usec()
			view._set_feature_enabled(key, true, false)
			view._rebuild_graph()
			await process_frame
			view._set_feature_enabled(key, false, false)
			view._rebuild_graph()
			await process_frame
			var feature_ms := float(Time.get_ticks_usec() - feature_start) / 1000.0
			rows.append(_measure(view, tree_size, "Switch Cycle: %s" % label, 6, 0, 1.0, feature_ms))
		view.free()

	var directory := ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir())
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	for row in rows:
		file.store_csv_line(row)
	file.close()
	print("BT_DISPLAY_BENCHMARK rows=%d output=%s" % [rows.size() - 1, OUTPUT_PATH])
	quit(0)


func _generate_tree(node_count: int) -> BTTreeResource:
	var tree := BTTreeResource.new()
	tree.tree_name = "Display Benchmark %d" % node_count
	tree.root_node_id = 1
	var root_node := _node(1, BTNodeResource.TYPE_ROOT, -1, "Root")
	tree.nodes.append(root_node)
	if node_count == 1:
		return tree
	var entry := _node(2, BTNodeResource.TYPE_SELECTOR, 1, "Decision Hub")
	tree.nodes.append(entry)
	var queue: Array[BTNodeResource] = [entry]
	var next_id := 3
	while next_id <= node_count and not queue.is_empty():
		var parent: BTNodeResource = queue.pop_front()
		for branch in range(3):
			if next_id > node_count:
				break
			var remaining := node_count - next_id
			var type_name := BTNodeResource.TYPE_SELECTOR if remaining > 9 else BTNodeResource.TYPE_ACTION
			var title := "Branch_%d" % next_id
			if next_id == node_count:
				title = "Target_%d" % node_count
			var child := _node(next_id, type_name, parent.id, title)
			if type_name == BTNodeResource.TYPE_ACTION:
				child.parameters = {"action_name": "benchmark_action_%d" % next_id}
			tree.nodes.append(child)
			if type_name == BTNodeResource.TYPE_SELECTOR:
				queue.append(child)
			next_id += 1
	# Fill any remainder under composites created near the frontier.
	while next_id <= node_count:
		var parent := tree.nodes[1 + ((next_id - 3) % max(1, tree.nodes.size() - 1))]
		if parent.node_type == BTNodeResource.TYPE_ACTION:
			parent = entry
		var child := _node(next_id, BTNodeResource.TYPE_ACTION, parent.id, "Target_%d" % node_count if next_id == node_count else "Task_%d" % next_id)
		tree.nodes.append(child)
		next_id += 1
	return tree


func _node(id: int, type_name: String, parent_id: int, title: String) -> BTNodeResource:
	var node := BTNodeResource.new()
	node.id = id
	node.node_type = type_name
	node.parent_id = parent_id
	node.title = title
	node.description = "Benchmark node %d for display readability measurement." % id
	return node


func _measure(view: BTEditorView, tree_size: int, method: String, information_fields: int, dimmed_nodes: int, focus_gain: float, measured_ms := -1.0) -> PackedStringArray:
	var start := Time.get_ticks_usec()
	var visible_nodes := _graph_node_count(view)
	var area := 0.0
	for child in view.graph_edit.get_children():
		if child is BTGraphNode:
			area += child.custom_minimum_size.x * child.custom_minimum_size.y
	var elapsed_ms := measured_ms if measured_ms >= 0.0 else float(Time.get_ticks_usec() - start) / 1000.0
	return PackedStringArray([
		str(tree_size), method, str(visible_nodes), str(float(visible_nodes) / float(tree_size)),
		str(area), str(information_fields), str(dimmed_nodes), str(focus_gain), str(elapsed_ms)
	])


func _graph_node_count(view: BTEditorView) -> int:
	var count := 0
	for child in view.graph_edit.get_children():
		if child is BTGraphNode:
			count += 1
	return count


func _count_dimmed(view: BTEditorView) -> int:
	var count := 0
	for child in view.graph_edit.get_children():
		if child is BTGraphNode and not child.search_matches:
			count += 1
	return count


func _first_graph_node(view: BTEditorView) -> BTGraphNode:
	for child in view.graph_edit.get_children():
		if child is BTGraphNode:
			return child
	return null
