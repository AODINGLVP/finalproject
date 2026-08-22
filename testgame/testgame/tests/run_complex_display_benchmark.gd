extends SceneTree

const BTEditorView = preload("res://addons/behavior_tree_editor/bt_editor_view.gd")
const BTGraphNode = preload("res://addons/behavior_tree_editor/bt_graph_node.gd")
const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")

const TREE_PATH := "res://behavior_trees/complex_display_tree_241.tres"
const OUTPUT_PATH := "res://test_results/complex_display_optimization.csv"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var tree := ResourceLoader.load(TREE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as BTTreeResource
	if tree == null:
		printerr("FAIL: cannot load %s" % TREE_PATH)
		quit(1)
		return
	var view := BTEditorView.new()
	root.add_child(view)
	await process_frame
	view.current_tree = tree
	view.current_tree_path = TREE_PATH
	view.next_node_id = 242
	view._auto_arrange_tree()
	await process_frame
	view._on_search_changed("")

	var rows: Array[PackedStringArray] = []
	rows.append(PackedStringArray(["mode", "resource_nodes", "rendered_cards", "rendered_ratio", "bounds_area_px2", "card_area_px2", "overlap_pairs", "information_fields", "dimmed_cards", "rebuild_ms"]))
	var baseline := _measure(view, "Baseline", 6, 0.0)
	rows.append(baseline)

	var start := Time.get_ticks_usec()
	view._set_feature_enabled("compact", true, false)
	view._rebuild_graph()
	await process_frame
	var compact := _measure(view, "Compact Cards", 2, _elapsed_ms(start))
	rows.append(compact)

	start = Time.get_ticks_usec()
	view._set_feature_enabled("semantic_zoom", true, false)
	view.semantic_zoom_enabled = true
	view.graph_edit.zoom = 0.5
	view._update_semantic_zoom()
	view._update_auto_spacing(0.0, true)
	await process_frame
	var overview := _measure(view, "Optimized Overview", 1, _elapsed_ms(start))
	rows.append(overview)

	start = Time.get_ticks_usec()
	view._on_search_changed("Patrol Route Choice")
	await process_frame
	var search := _measure(view, "Optimized Search", 1, _elapsed_ms(start))
	rows.append(search)
	view._on_search_changed("")

	var patrol_branch := _find_node_id(tree, "11 Layered Patrol")
	start = Time.get_ticks_usec()
	view.focus_root_id = patrol_branch
	view._rebuild_graph()
	await process_frame
	var focus := _measure(view, "Subtree Focus", 2, _elapsed_ms(start))
	rows.append(focus)

	view.focus_root_id = -1
	view._rebuild_graph()
	await process_frame
	var priority := tree.find_node(3)
	start = Time.get_ticks_usec()
	for child in tree.get_children_of(priority.id):
		if child.id != patrol_branch:
			child.collapsed = true
	view._rebuild_graph()
	await process_frame
	var collapse := _measure(view, "Context Collapse", 2, _elapsed_ms(start))
	rows.append(collapse)

	var directory := ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir())
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	for row in rows:
		file.store_csv_line(row)
	file.close()
	var failures := 0
	failures += _expect(float(compact[5]) < float(baseline[5]), "Compact Cards reduce total card area")
	failures += _expect(float(overview[4]) < float(baseline[4]), "Optimized Overview reduces graph bounds area")
	failures += _expect(int(search[8]) >= 199, "Search dims at least 95 percent of rendered cards")
	failures += _expect(int(focus[2]) < int(baseline[2]), "Subtree Focus reduces rendered cards")
	failures += _expect(int(collapse[2]) < int(baseline[2]), "Context Collapse reduces rendered cards")
	for row in rows.slice(1):
		failures += _expect(int(row[6]) == 0, "%s has zero card overlaps" % row[0])
	print("BT_COMPLEX_DISPLAY_BENCHMARK rows=%d failed=%d output=%s" % [rows.size() - 1, failures, OUTPUT_PATH])
	quit(0 if failures == 0 else 1)


func _measure(view: BTEditorView, mode: String, information_fields: int, rebuild_ms: float) -> PackedStringArray:
	var nodes: Array[BTGraphNode] = []
	for child in view.graph_edit.get_children():
		if child is BTGraphNode:
			nodes.append(child)
	var bounds := Rect2()
	var card_area := 0.0
	var dimmed := 0
	for index in range(nodes.size()):
		var node := nodes[index]
		var rect := Rect2(node.position_offset, node.size * node.scale)
		bounds = rect if index == 0 else bounds.merge(rect)
		card_area += rect.size.x * rect.size.y
		if mode == "Optimized Search" and not node.search_matches:
			dimmed += 1
	var overlaps := 0
	for left in range(nodes.size()):
		for right in range(left + 1, nodes.size()):
			var left_rect := Rect2(nodes[left].position_offset, nodes[left].size * nodes[left].scale)
			var right_rect := Rect2(nodes[right].position_offset, nodes[right].size * nodes[right].scale)
			if left_rect.intersects(right_rect):
				overlaps += 1
	return PackedStringArray([
		mode, str(view.current_tree.nodes.size()), str(nodes.size()), str(float(nodes.size()) / float(view.current_tree.nodes.size())),
		str(bounds.size.x * bounds.size.y), str(card_area), str(overlaps), str(information_fields), str(dimmed), str(rebuild_ms)
	])


func _elapsed_ms(start_usec: int) -> float:
	return float(Time.get_ticks_usec() - start_usec) / 1000.0


func _find_node_id(tree: BTTreeResource, title: String) -> int:
	for node in tree.nodes:
		if node.title == title:
			return node.id
	return -1


func _expect(condition: bool, label: String) -> int:
	if condition:
		print("PASS: %s" % label)
		return 0
	printerr("FAIL: %s" % label)
	return 1
