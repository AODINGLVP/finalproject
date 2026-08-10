extends SceneTree

const BTEditorView = preload("res://addons/behavior_tree_editor/bt_editor_view.gd")
const BTGraphNode = preload("res://addons/behavior_tree_editor/bt_graph_node.gd")
const BTNodeResource = preload("res://addons/behavior_tree_editor/bt_node_resource.gd")
const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")

const OUTPUT_PATH := "res://test_results/branch_dimming_results.csv"
const TREE_SIZES := [31, 121, 364]
const SAMPLE_COUNT := 50


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var rows: Array[PackedStringArray] = []
	rows.append(PackedStringArray([
		"tree_size", "active_nodes", "dimmed_nodes", "dimmed_ratio",
		"active_alpha", "inactive_alpha", "alpha_contrast", "first_update_ms", "steady_update_ms"
	]))
	for tree_size_value in TREE_SIZES:
		var tree_size: int = int(tree_size_value)
		var view := BTEditorView.new()
		root.add_child(view)
		await process_frame
		view.current_tree = _generate_tree(tree_size)
		view.current_tree_path = "res://benchmarks/dimming_%d.tres" % tree_size
		view.next_node_id = tree_size + 1
		view._rebuild_graph()
		await process_frame
		view._set_feature_enabled("branch_dimming", true, false)
		var path_ids: Array[int] = _first_leaf_path(view.current_tree)
		var snapshot: Dictionary = {"actor": "Benchmark", "path_ids": path_ids, "leaf_status_text": "RUNNING"}
		var first_start: int = Time.get_ticks_usec()
		view._apply_runtime_snapshot(snapshot)
		var first_update_ms: float = float(Time.get_ticks_usec() - first_start) / 1000.0
		var start: int = Time.get_ticks_usec()
		for sample in range(SAMPLE_COUNT):
			view._apply_runtime_snapshot(snapshot)
		var steady_update_ms: float = float(Time.get_ticks_usec() - start) / 1000.0 / float(SAMPLE_COUNT)
		var dimmed_nodes: int = _count_dimmed(view)
		var active_nodes: int = tree_size - dimmed_nodes
		rows.append(PackedStringArray([
			str(tree_size), str(active_nodes), str(dimmed_nodes), str(float(dimmed_nodes) / float(tree_size)),
			"1.0", str(BTGraphNode.INACTIVE_BRANCH_ALPHA), str(1.0 / BTGraphNode.INACTIVE_BRANCH_ALPHA),
			str(first_update_ms), str(steady_update_ms)
		]))
		view._set_feature_enabled("branch_dimming", false, false)
		if _count_dimmed(view) != 0:
			printerr("FAIL: branch dimming reset for tree size %d" % tree_size)
			quit(1)
			return
		view.free()
	var directory := ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir())
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	for row in rows:
		file.store_csv_line(row)
	file.close()
	print("BT_BRANCH_DIMMING_BENCHMARK rows=%d samples=%d output=%s" % [rows.size() - 1, SAMPLE_COUNT, OUTPUT_PATH])
	quit(0)


func _generate_tree(node_count: int) -> BTTreeResource:
	var tree := BTTreeResource.new()
	tree.tree_name = "Branch Dimming Benchmark %d" % node_count
	tree.root_node_id = 1
	tree.nodes.append(_node(1, BTNodeResource.TYPE_ROOT, -1))
	if node_count == 1:
		return tree
	tree.nodes.append(_node(2, BTNodeResource.TYPE_SELECTOR, 1))
	var queue: Array[int] = [2]
	var next_id := 3
	while next_id <= node_count and not queue.is_empty():
		var parent_id: int = queue.pop_front()
		for branch in range(3):
			if next_id > node_count:
				break
			var type_name := BTNodeResource.TYPE_SELECTOR if next_id < node_count / 3 else BTNodeResource.TYPE_ACTION
			tree.nodes.append(_node(next_id, type_name, parent_id))
			if type_name == BTNodeResource.TYPE_SELECTOR:
				queue.append(next_id)
			next_id += 1
	while next_id <= node_count:
		tree.nodes.append(_node(next_id, BTNodeResource.TYPE_ACTION, 2))
		next_id += 1
	return tree


func _node(id: int, type_name: String, parent_id: int) -> BTNodeResource:
	var node := BTNodeResource.new()
	node.id = id
	node.node_type = type_name
	node.parent_id = parent_id
	node.title = "Node %d" % id
	node.position = Vector2(float(id % 12) * 280.0, float(id / 12) * 220.0)
	return node


func _first_leaf_path(tree: BTTreeResource) -> Array[int]:
	var path: Array[int] = []
	var node := tree.find_node(tree.root_node_id)
	while node != null:
		path.append(node.id)
		var children := tree.get_children_of(node.id)
		node = children[0] if not children.is_empty() else null
	return path


func _count_dimmed(view: BTEditorView) -> int:
	var count := 0
	for child in view.graph_edit.get_children():
		if child is BTGraphNode and child.modulate.a < 0.99:
			count += 1
	return count
