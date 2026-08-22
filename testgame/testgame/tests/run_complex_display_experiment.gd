extends SceneTree

const BTEditorView = preload("res://addons/behavior_tree_editor/bt_editor_view.gd")
const BTGraphNode = preload("res://addons/behavior_tree_editor/bt_graph_node.gd")
const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")

const TREE_PATH := "res://behavior_trees/complex_display_tree_241.tres"
const RAW_OUTPUT_PATH := "res://test_results/complex_display_experiment_raw.csv"
const SUMMARY_OUTPUT_PATH := "res://test_results/complex_display_experiment_summary.csv"
const VIEWPORT_SIZE := Vector2i(1600, 900)
const WARMUP_TRIALS := 3
const MEASURED_TRIALS := 30
const SEARCH_TARGET := "Patrol Route Choice"
const FOCUS_TARGET := "11 Layered Patrol"
const CONDITIONS := [
	"Baseline",
	"Compact Cards",
	"Optimized Overview",
	"Optimized Search",
	"Subtree Focus",
	"Context Collapse",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var tree := ResourceLoader.load(TREE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as BTTreeResource
	if tree == null:
		printerr("FAIL: cannot load %s" % TREE_PATH)
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.gui_embed_subwindows = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := BTEditorView.new()
	view.size = Vector2(VIEWPORT_SIZE)
	viewport.add_child(view)
	await _settle_frames()
	view.current_tree = tree
	view.current_tree_path = TREE_PATH
	view.next_node_id = 242
	_prepare_deterministic_features(view)
	view._auto_arrange_tree()
	await _settle_frames()

	var focus_id := _find_node_id(tree, FOCUS_TARGET)
	var priority_node := tree.find_node(3)
	if focus_id < 0 or priority_node == null:
		printerr("FAIL: cannot find fixed focus/collapse targets")
		quit(1)
		return
	var initial_positions := _capture_positions(tree)
	var raw_rows: Array[PackedStringArray] = []
	raw_rows.append(PackedStringArray([
		"trial", "sequence_position", "condition", "resource_nodes", "rendered_cards", "visible_ratio",
		"bounds_area_px2", "card_area_px2", "overlap_pairs", "information_fields",
		"dimmed_cards", "interaction_ms", "engine_version", "renderer", "viewport",
	]))
	var samples_by_condition: Dictionary = {}
	var metrics_by_condition: Dictionary = {}

	for condition_variant in CONDITIONS:
		var condition := str(condition_variant)
		var empty_samples: Array[float] = []
		samples_by_condition[condition] = empty_samples
		for warmup in range(WARMUP_TRIALS):
			await _restore_baseline(view, tree)
			await _apply_condition(view, tree, condition, focus_id, priority_node.id)
	# Rotate the six-condition order once per repetition. Because 30 is exactly
	# divisible by six, every condition occupies every sequence position five
	# times, reducing time/temperature drift without introducing randomness.
	for trial in range(1, MEASURED_TRIALS + 1):
		for sequence_position in range(CONDITIONS.size()):
			var condition_index := (trial - 1 + sequence_position) % CONDITIONS.size()
			var condition := str(CONDITIONS[condition_index])
			await _restore_baseline(view, tree)
			var started_usec := Time.get_ticks_usec()
			await _apply_condition(view, tree, condition, focus_id, priority_node.id)
			var interaction_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
			var metrics := _measure(view, _information_fields_for(condition))
			var samples: Array[float] = samples_by_condition[condition]
			samples.append(interaction_ms)
			samples_by_condition[condition] = samples
			raw_rows.append(_raw_row(trial, sequence_position + 1, condition, metrics, interaction_ms))
			metrics_by_condition[condition] = metrics
	for condition_variant in CONDITIONS:
		var condition := str(condition_variant)
		var samples: Array[float] = samples_by_condition[condition]
		print("BT_COMPLEX_EXPERIMENT condition=%s trials=%d median_ms=%.3f" % [
			condition, samples.size(), _median(samples),
		])

	var summary_rows := _build_summary_rows(samples_by_condition, metrics_by_condition)
	_write_rows(RAW_OUTPUT_PATH, raw_rows)
	_write_rows(SUMMARY_OUTPUT_PATH, summary_rows)
	var failures := _validate_results(tree, initial_positions, metrics_by_condition)
	print("BT_COMPLEX_DISPLAY_EXPERIMENT conditions=%d observations=%d failed=%d raw=%s summary=%s" % [
		CONDITIONS.size(), CONDITIONS.size() * MEASURED_TRIALS, failures, RAW_OUTPUT_PATH, SUMMARY_OUTPUT_PATH,
	])
	view.free()
	viewport.free()
	quit(0 if failures == 0 else 1)


func _prepare_deterministic_features(view: BTEditorView) -> void:
	view.feature_states["compact"] = false
	view.feature_states["semantic_zoom"] = false
	view.feature_states["search"] = true
	view.feature_states["subtree_collapse"] = true
	view.feature_states["auto_spacing"] = true
	view.compact_mode_enabled = false
	view.semantic_zoom_enabled = false
	view.semantic_detail_level = 2


func _restore_baseline(view: BTEditorView, tree: BTTreeResource) -> void:
	for node in tree.nodes:
		if node != null:
			node.collapsed = false
	view.focus_root_id = -1
	view.feature_states["compact"] = false
	view.feature_states["semantic_zoom"] = false
	view.compact_mode_enabled = false
	view.semantic_zoom_enabled = false
	view.semantic_detail_level = 2
	view.search_query = ""
	view.search_result_ids.clear()
	view.search_result_index = -1
	view.graph_edit.zoom = 1.0
	view._reset_auto_spacing()
	view._rebuild_graph()
	await _settle_frames()


func _apply_condition(view: BTEditorView, tree: BTTreeResource, condition: String, focus_id: int, priority_id: int) -> void:
	match condition:
		"Baseline":
			view._rebuild_graph()
		"Compact Cards":
			view._set_feature_enabled("compact", true, false)
		"Optimized Overview":
			_apply_overview(view)
		"Optimized Search":
			_apply_overview(view)
			view._on_search_changed(SEARCH_TARGET)
		"Subtree Focus":
			view._set_feature_enabled("compact", true, false)
			view.focus_root_id = focus_id
			view._rebuild_graph()
		"Context Collapse":
			view._set_feature_enabled("compact", true, false)
			for child in tree.get_children_of(priority_id):
				if child.id != focus_id:
					child.collapsed = true
			view._rebuild_graph()
		_:
			printerr("FAIL: unsupported experiment condition %s" % condition)
	await _settle_frames()


func _apply_overview(view: BTEditorView) -> void:
	view._set_feature_enabled("compact", true, false)
	view._set_feature_enabled("semantic_zoom", true, false)
	view.graph_edit.zoom = 0.5
	view._update_semantic_zoom()
	view._update_auto_spacing(0.0, true)


func _settle_frames() -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw(false, 0.0)
	await process_frame


func _measure(view: BTEditorView, information_fields: int) -> Dictionary:
	var nodes: Array[BTGraphNode] = []
	for child in view.graph_edit.get_children():
		if child is BTGraphNode:
			nodes.append(child)
	var bounds := Rect2()
	var card_area := 0.0
	var dimmed := 0
	for index in range(nodes.size()):
		var graph_node := nodes[index]
		var rect := Rect2(graph_node.position_offset + graph_node.visual_offset, graph_node.size * graph_node.scale)
		bounds = rect if index == 0 else bounds.merge(rect)
		card_area += rect.size.x * rect.size.y
		if not view.search_query.is_empty() and not graph_node.search_matches:
			dimmed += 1
	var overlaps := 0
	for left in range(nodes.size()):
		var left_rect := Rect2(nodes[left].position_offset + nodes[left].visual_offset, nodes[left].size * nodes[left].scale)
		for right in range(left + 1, nodes.size()):
			var right_rect := Rect2(nodes[right].position_offset + nodes[right].visual_offset, nodes[right].size * nodes[right].scale)
			if left_rect.intersects(right_rect):
				overlaps += 1
	return {
		"resource_nodes": view.current_tree.nodes.size(),
		"rendered_cards": nodes.size(),
		"visible_ratio": float(nodes.size()) / float(view.current_tree.nodes.size()),
		"bounds_area_px2": bounds.size.x * bounds.size.y,
		"card_area_px2": card_area,
		"overlap_pairs": overlaps,
		"information_fields": information_fields,
		"dimmed_cards": dimmed,
	}


func _raw_row(trial: int, sequence_position: int, condition: String, metrics: Dictionary, interaction_ms: float) -> PackedStringArray:
	return PackedStringArray([
		str(trial), str(sequence_position), condition, str(metrics["resource_nodes"]), str(metrics["rendered_cards"]),
		str(metrics["visible_ratio"]), str(metrics["bounds_area_px2"]), str(metrics["card_area_px2"]),
		str(metrics["overlap_pairs"]), str(metrics["information_fields"]), str(metrics["dimmed_cards"]),
		str(interaction_ms), str(Engine.get_version_info().get("string", "unknown")),
		RenderingServer.get_current_rendering_method(), "%dx%d" % [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
	])


func _build_summary_rows(samples_by_condition: Dictionary, metrics_by_condition: Dictionary) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	rows.append(PackedStringArray([
		"condition", "n", "median_ms", "q1_ms", "q3_ms", "p95_ms", "rendered_cards",
		"visible_reduction_percent", "card_area_px2", "card_area_reduction_percent",
		"bounds_area_px2", "bounds_reduction_percent", "dimmed_cards", "overlap_max",
	]))
	var baseline: Dictionary = metrics_by_condition["Baseline"]
	for condition_variant in CONDITIONS:
		var condition := str(condition_variant)
		var samples: Array[float] = samples_by_condition[condition]
		var sorted_samples := samples.duplicate()
		sorted_samples.sort()
		var metrics: Dictionary = metrics_by_condition[condition]
		rows.append(PackedStringArray([
			condition, str(samples.size()), str(_median(sorted_samples)), str(_nearest_rank(sorted_samples, 0.25)),
			str(_nearest_rank(sorted_samples, 0.75)), str(_nearest_rank(sorted_samples, 0.95)),
			str(metrics["rendered_cards"]), str(_reduction(float(metrics["rendered_cards"]), float(baseline["rendered_cards"]))),
			str(metrics["card_area_px2"]), str(_reduction(float(metrics["card_area_px2"]), float(baseline["card_area_px2"]))),
			str(metrics["bounds_area_px2"]), str(_reduction(float(metrics["bounds_area_px2"]), float(baseline["bounds_area_px2"]))),
			str(metrics["dimmed_cards"]), str(metrics["overlap_pairs"]),
		]))
	return rows


func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values := values.duplicate()
	sorted_values.sort()
	var middle := sorted_values.size() / 2
	if sorted_values.size() % 2 == 1:
		return sorted_values[middle]
	return (sorted_values[middle - 1] + sorted_values[middle]) * 0.5


func _nearest_rank(sorted_values: Array[float], percentile: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var index := clampi(ceili(percentile * float(sorted_values.size())) - 1, 0, sorted_values.size() - 1)
	return sorted_values[index]


func _reduction(value: float, baseline: float) -> float:
	return (1.0 - value / baseline) * 100.0 if baseline > 0.0 else 0.0


func _capture_positions(tree: BTTreeResource) -> Dictionary:
	var positions := {}
	for node in tree.nodes:
		if node != null:
			positions[node.id] = node.position
	return positions


func _positions_unchanged(tree: BTTreeResource, initial_positions: Dictionary) -> bool:
	for node in tree.nodes:
		if node != null and (not initial_positions.has(node.id) or node.position != initial_positions[node.id]):
			return false
	return true


func _find_node_id(tree: BTTreeResource, title: String) -> int:
	for node in tree.nodes:
		if node != null and node.title == title:
			return node.id
	return -1


func _information_fields_for(condition: String) -> int:
	match condition:
		"Compact Cards", "Subtree Focus", "Context Collapse":
			return 2
		"Optimized Overview", "Optimized Search":
			return 1
		_:
			return 6


func _validate_results(tree: BTTreeResource, initial_positions: Dictionary, metrics_by_condition: Dictionary) -> int:
	var failures := 0
	var baseline: Dictionary = metrics_by_condition["Baseline"]
	var compact: Dictionary = metrics_by_condition["Compact Cards"]
	var overview: Dictionary = metrics_by_condition["Optimized Overview"]
	var search: Dictionary = metrics_by_condition["Optimized Search"]
	var focus: Dictionary = metrics_by_condition["Subtree Focus"]
	var collapse: Dictionary = metrics_by_condition["Context Collapse"]
	failures += _expect(tree.nodes.size() == 241, "The playable resource has exactly 241 nodes")
	failures += _expect(int(baseline["rendered_cards"]) == 202, "Baseline renders exactly 202 node cards")
	failures += _expect(_reduction(float(compact["card_area_px2"]), float(baseline["card_area_px2"])) >= 40.0, "Compact Cards reduce card area by at least 40 percent")
	failures += _expect(_reduction(float(overview["card_area_px2"]), float(baseline["card_area_px2"])) >= 70.0, "Optimized Overview reduces card area by at least 70 percent")
	failures += _expect(int(search["dimmed_cards"]) >= 191, "Search dims at least 95 percent of non-target cards")
	failures += _expect(_reduction(float(focus["rendered_cards"]), float(baseline["rendered_cards"])) >= 70.0, "Subtree Focus reduces rendered cards by at least 70 percent")
	failures += _expect(_reduction(float(collapse["rendered_cards"]), float(baseline["rendered_cards"])) >= 70.0, "Context Collapse reduces rendered cards by at least 70 percent")
	for condition_variant in CONDITIONS:
		var condition := str(condition_variant)
		var metrics: Dictionary = metrics_by_condition[condition]
		failures += _expect(int(metrics["overlap_pairs"]) == 0, "%s has zero card overlaps" % condition)
	failures += _expect(_positions_unchanged(tree, initial_positions), "Display conditions do not change saved resource positions")
	return failures


func _write_rows(path: String, rows: Array[PackedStringArray]) -> void:
	var directory := ProjectSettings.globalize_path(path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(path, FileAccess.WRITE)
	for row in rows:
		file.store_csv_line(row)
	file.close()


func _expect(condition: bool, label: String) -> int:
	if condition:
		print("PASS: %s" % label)
		return 0
	printerr("FAIL: %s" % label)
	return 1
