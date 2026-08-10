extends SceneTree

const BTEditorView = preload("res://addons/behavior_tree_editor/bt_editor_view.gd")
const BTGraphNode = preload("res://addons/behavior_tree_editor/bt_graph_node.gd")
const BTNodeResource = preload("res://addons/behavior_tree_editor/bt_node_resource.gd")
const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")

const OUTPUT_PATH := "res://test_results/enhanced_minimap_results.csv"
const TREE_SIZES := [31, 121, 364]
const SAMPLE_COUNT := 50


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var rows: Array[PackedStringArray] = []
	rows.append(PackedStringArray([
		"tree_size", "overview_nodes", "coverage_ratio", "minimap_width_px", "minimap_height_px",
		"minimap_area_px2", "nodes_per_1000_px2", "toggle_cycle_ms", "steady_status_update_ms"
	]))
	for tree_size_value in TREE_SIZES:
		var tree_size: int = int(tree_size_value)
		var view := BTEditorView.new()
		root.add_child(view)
		await process_frame
		view.current_tree = _generate_tree(tree_size)
		view.current_tree_path = "res://benchmarks/minimap_%d.tres" % tree_size
		view.next_node_id = tree_size + 1
		view._rebuild_graph()
		await process_frame
		var start: int = Time.get_ticks_usec()
		for sample in range(SAMPLE_COUNT):
			view._set_feature_enabled("enhanced_minimap", false, false)
			view._set_feature_enabled("enhanced_minimap", true, false)
		var toggle_cycle_ms: float = float(Time.get_ticks_usec() - start) / 1000.0 / float(SAMPLE_COUNT)
		view._refresh_minimap_node_counts()
		view.graph_edit.zoom = 0.55
		view._update_minimap_status(true)
		var status_start: int = Time.get_ticks_usec()
		for sample in range(SAMPLE_COUNT):
			view._update_minimap_status()
		var steady_status_ms: float = float(Time.get_ticks_usec() - status_start) / 1000.0 / float(SAMPLE_COUNT)
		var size: Vector2 = view.graph_edit.minimap_size
		var area: float = size.x * size.y
		rows.append(PackedStringArray([
			str(tree_size), str(view.minimap_visible_node_count), str(float(view.minimap_visible_node_count) / float(tree_size)),
			str(size.x), str(size.y), str(area), str(float(tree_size) / area * 1000.0),
			str(toggle_cycle_ms), str(steady_status_ms)
		]))
		if not view.graph_edit.minimap_enabled or view.minimap_visible_node_count != tree_size:
			printerr("FAIL: enhanced minimap coverage for tree size %d" % tree_size)
			quit(1)
			return
		view.free()
	var directory := ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir())
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	for row in rows:
		file.store_csv_line(row)
	file.close()
	print("BT_ENHANCED_MINIMAP_BENCHMARK rows=%d samples=%d output=%s" % [rows.size() - 1, SAMPLE_COUNT, OUTPUT_PATH])
	quit(0)


func _generate_tree(node_count: int) -> BTTreeResource:
	var tree := BTTreeResource.new()
	tree.tree_name = "Enhanced Minimap Benchmark %d" % node_count
	tree.root_node_id = 1
	tree.nodes.append(_node(1, BTNodeResource.TYPE_ROOT, -1, Vector2(0.0, 0.0)))
	if node_count == 1:
		return tree
	tree.nodes.append(_node(2, BTNodeResource.TYPE_SELECTOR, 1, Vector2(0.0, 220.0)))
	for id in range(3, node_count + 1):
		var column := (id - 3) % 20
		var row := (id - 3) / 20
		tree.nodes.append(_node(id, BTNodeResource.TYPE_ACTION, 2, Vector2(float(column) * 280.0, 460.0 + float(row) * 220.0)))
	return tree


func _node(id: int, type_name: String, parent_id: int, position: Vector2) -> BTNodeResource:
	var node := BTNodeResource.new()
	node.id = id
	node.node_type = type_name
	node.parent_id = parent_id
	node.title = "Node %d" % id
	node.position = position
	return node
