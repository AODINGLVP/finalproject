extends SceneTree

const BTEditorView = preload("res://addons/behavior_tree_editor/bt_editor_view.gd")
const BTGraphNode = preload("res://addons/behavior_tree_editor/bt_graph_node.gd")
const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")
const TreeFactory = preload("res://tests/support/multiscale_tree_factory.gd")

const TREE_SIZES := [31, 61, 121, 241, 364]
const CONDITIONS := [
	"Baseline",
	"Compact Cards",
	"Optimized Overview",
	"Optimized Search",
	"Subtree Focus",
	"Context Collapse",
]
const SCREENSHOT_CONDITIONS := ["Baseline", "Optimized Overview", "Optimized Search"]
const VIEWPORT_SIZE := Vector2i(1600, 900)
const WARMUP_TRIALS := 3
const MEASURED_TRIALS := 30
const RAW_OUTPUT_PATH := "res://test_results/multiscale_display_raw.csv"
const SUMMARY_OUTPUT_PATH := "res://test_results/multiscale_display_summary.csv"
const TREND_OUTPUT_PATH := "res://test_results/multiscale_display_trends.csv"
const SCREENSHOT_DIR := "res://test_results/multiscale_display_visual"

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.gui_embed_subwindows = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var view := BTEditorView.new()
	view.size = Vector2(VIEWPORT_SIZE)
	viewport.add_child(view)
	await _settle_frames()

	var fixtures := await _build_fixtures(view)
	if failures > 0:
		view.free()
		viewport.free()
		quit(1)
		return
	if OS.get_cmdline_user_args().has("--screenshots-only"):
		await _capture_evidence(view, viewport, fixtures)
		print("BT_MULTISCALE_SCREENSHOT_SUMMARY sizes=%d conditions=%d failed=%d directory=%s" % [
			TREE_SIZES.size(), SCREENSHOT_CONDITIONS.size(), failures, SCREENSHOT_DIR,
		])
		view.free()
		viewport.free()
		quit(0 if failures == 0 else 1)
		return

	var raw_rows: Array[PackedStringArray] = []
	raw_rows.append(PackedStringArray([
		"trial", "size_sequence_position", "condition_sequence_position", "tree_size", "condition",
		"resource_nodes", "rendered_cards", "decorators", "cards_in_viewport", "card_visible_ratio",
		"bounds_area_px2", "card_area_px2", "overlap_pairs", "min_parent_child_gap_px",
		"information_fields", "dimmed_cards", "target_in_viewport", "fit_zoom", "interaction_ms",
		"engine_version", "renderer", "gpu", "viewport",
	]))
	var samples_by_key: Dictionary = {}
	var metrics_by_key: Dictionary = {}
	for size_variant in TREE_SIZES:
		var tree_size := int(size_variant)
		for condition_variant in CONDITIONS:
			var condition := str(condition_variant)
			var empty_samples: Array[float] = []
			samples_by_key[_key(tree_size, condition)] = empty_samples

	for size_variant in TREE_SIZES:
		var tree_size := int(size_variant)
		var fixture: Dictionary = fixtures[tree_size]
		await _activate_tree(view, fixture)
		for condition_variant in CONDITIONS:
			var condition := str(condition_variant)
			for warmup in range(WARMUP_TRIALS):
				await _restore_baseline(view, fixture["tree"])
				await _apply_condition(view, fixture, condition)

	# Thirty complete repetitions rotate both size and condition order. Each size
	# occupies each size position six times; each condition occupies every
	# condition position five times.
	for trial in range(1, MEASURED_TRIALS + 1):
		for size_position in range(TREE_SIZES.size()):
			var size_index := (trial - 1 + size_position) % TREE_SIZES.size()
			var tree_size := int(TREE_SIZES[size_index])
			var fixture: Dictionary = fixtures[tree_size]
			await _activate_tree(view, fixture)
			for condition_position in range(CONDITIONS.size()):
				var condition_index := (trial - 1 + size_position + condition_position) % CONDITIONS.size()
				var condition := str(CONDITIONS[condition_index])
				await _restore_baseline(view, fixture["tree"])
				var started_usec := Time.get_ticks_usec()
				await _apply_condition(view, fixture, condition)
				var interaction_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
				var metrics := _measure(view, fixture, _information_fields_for(condition))
				metrics["fit_zoom"] = await _measure_fit_zoom(view)
				metrics["cards_in_viewport"] = _count_cards_in_viewport(view)
				var key := _key(tree_size, condition)
				var samples: Array[float] = samples_by_key[key]
				samples.append(interaction_ms)
				samples_by_key[key] = samples
				metrics_by_key[key] = metrics
				raw_rows.append(_raw_row(
					trial, size_position + 1, condition_position + 1, tree_size,
					condition, metrics, interaction_ms
				))
		print("BT_MULTISCALE_DISPLAY_PROGRESS trial=%d/%d" % [trial, MEASURED_TRIALS])

	var summary_rows := _build_summary_rows(samples_by_key, metrics_by_key)
	var trend_rows := _build_trend_rows(metrics_by_key)
	_write_rows(RAW_OUTPUT_PATH, raw_rows)
	_write_rows(SUMMARY_OUTPUT_PATH, summary_rows)
	_write_rows(TREND_OUTPUT_PATH, trend_rows)
	await _capture_evidence(view, viewport, fixtures)
	failures += _validate_results(fixtures, metrics_by_key)

	for size_variant in TREE_SIZES:
		var tree_size := int(size_variant)
		var baseline: Dictionary = metrics_by_key[_key(tree_size, "Baseline")]
		var overview: Dictionary = metrics_by_key[_key(tree_size, "Optimized Overview")]
		print("BT_MULTISCALE_RESULT size=%d cards=%d overview_area_reduction=%.2f%% fit_zoom=%.3f->%.3f" % [
			tree_size,
			int(baseline["rendered_cards"]),
			_reduction(float(overview["card_area_px2"]), float(baseline["card_area_px2"])),
			float(baseline["fit_zoom"]),
			float(overview["fit_zoom"]),
		])
	print("BT_MULTISCALE_DISPLAY_SUMMARY sizes=%d conditions=%d observations=%d failed=%d raw=%s summary=%s trends=%s" % [
		TREE_SIZES.size(), CONDITIONS.size(), TREE_SIZES.size() * CONDITIONS.size() * MEASURED_TRIALS,
		failures, RAW_OUTPUT_PATH, SUMMARY_OUTPUT_PATH, TREND_OUTPUT_PATH,
	])
	view.free()
	viewport.free()
	quit(0 if failures == 0 else 1)


func _build_fixtures(view: BTEditorView) -> Dictionary:
	var fixtures := {}
	for size_variant in TREE_SIZES:
		var tree_size := int(size_variant)
		var tree := TreeFactory.generate(tree_size) as BTTreeResource
		failures += _expect(tree.nodes.size() == tree_size, "%d-node fixture has exact resource count" % tree_size)
		failures += _expect(tree.validate_tree().is_empty(), "%d-node fixture passes structural validation" % tree_size)
		var focus_id := TreeFactory.focus_target_id(tree)
		var target_id := TreeFactory.search_target_id(tree)
		failures += _expect(focus_id > 0, "%d-node fixture has a deterministic focus target" % tree_size)
		failures += _expect(target_id > 0, "%d-node fixture has a deterministic search target" % tree_size)
		view.current_tree = tree
		view.current_tree_path = "res://benchmarks/controlled_scale_%d.tres" % tree_size
		view.next_node_id = tree_size + 1
		_prepare_deterministic_features(view)
		view._refresh_entire_ui()
		view._auto_arrange_tree()
		await _settle_frames()
		fixtures[tree_size] = {
			"tree": tree,
			"focus_id": focus_id,
			"focus_path": TreeFactory.focus_path_ids(tree, focus_id),
			"target_id": target_id,
			"target_title": tree.find_node(target_id).title,
			"card_count": TreeFactory.card_count(tree),
			"decorator_count": TreeFactory.decorator_count(tree),
			"positions": _capture_positions(tree),
			"order_signature": _order_signature(tree),
		}
	return fixtures


func _activate_tree(view: BTEditorView, fixture: Dictionary) -> void:
	var tree: BTTreeResource = fixture["tree"]
	if view.current_tree != tree:
		view.current_tree = tree
		view.current_tree_path = "res://benchmarks/controlled_scale_%d.tres" % tree.nodes.size()
		view.next_node_id = tree.nodes.size() + 1
		view._refresh_entire_ui()
		await _settle_frames()
	_prepare_deterministic_features(view)


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
	view.graph_edit.scroll_offset = Vector2.ZERO
	view._reset_auto_spacing()
	view._rebuild_graph()
	await _settle_frames()


func _apply_condition(view: BTEditorView, fixture: Dictionary, condition: String) -> void:
	var tree: BTTreeResource = fixture["tree"]
	match condition:
		"Baseline":
			view._rebuild_graph()
		"Compact Cards":
			view._set_feature_enabled("compact", true, false)
		"Optimized Overview":
			_apply_overview(view)
		"Optimized Search":
			_apply_overview(view)
			view._on_search_changed(str(fixture["target_title"]))
			view._on_search_submitted(str(fixture["target_title"]))
		"Subtree Focus":
			view._set_feature_enabled("compact", true, false)
			view.focus_root_id = int(fixture["focus_id"])
			view._rebuild_graph()
		"Context Collapse":
			view._set_feature_enabled("compact", true, false)
			_apply_context_collapse(tree, fixture["focus_path"])
			view._rebuild_graph()
		_:
			failures += _expect(false, "supported condition %s" % condition)
	await _settle_frames()


func _apply_overview(view: BTEditorView) -> void:
	view._set_feature_enabled("compact", true, false)
	view._set_feature_enabled("semantic_zoom", true, false)
	view.graph_edit.zoom = 0.5
	view._update_semantic_zoom()
	view._update_auto_spacing(0.0, true)


func _apply_context_collapse(tree: BTTreeResource, focus_path_variant: Variant) -> void:
	var focus_path: Array = focus_path_variant
	for node in tree.nodes:
		if node == null or node.decorator_parent_id != -1 or focus_path.has(node.id):
			continue
		if not tree.get_children_of(node.id).is_empty():
			node.collapsed = true


func _settle_frames() -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw(false, 0.0)
	await process_frame


func _measure(view: BTEditorView, fixture: Dictionary, information_fields: int) -> Dictionary:
	var nodes: Array[BTGraphNode] = []
	var rects_by_id := {}
	var bounds := Rect2()
	var card_area := 0.0
	var dimmed := 0
	var viewport_cards := 0
	var graph_canvas := view.graph_edit.get_global_rect()
	var target_in_viewport := false
	for child in view.graph_edit.get_children():
		if not child is BTGraphNode:
			continue
		var graph_node: BTGraphNode = child
		nodes.append(graph_node)
		var rect := Rect2(graph_node.position_offset + graph_node.visual_offset, graph_node.size * graph_node.scale)
		rects_by_id[graph_node.node_resource.id] = rect
		bounds = rect if bounds.size == Vector2.ZERO else bounds.merge(rect)
		card_area += rect.size.x * rect.size.y
		if not view.search_query.is_empty() and not graph_node.search_matches:
			dimmed += 1
		var center_in_canvas := graph_canvas.has_point(graph_node.get_global_rect().get_center())
		if center_in_canvas:
			viewport_cards += 1
		if graph_node.node_resource.id == int(fixture["target_id"]):
			target_in_viewport = center_in_canvas
	var overlaps := 0
	for left in range(nodes.size()):
		var left_rect: Rect2 = rects_by_id[nodes[left].node_resource.id]
		for right in range(left + 1, nodes.size()):
			var right_rect: Rect2 = rects_by_id[nodes[right].node_resource.id]
			if left_rect.intersects(right_rect):
				overlaps += 1
	var min_parent_child_gap := INF
	var tree: BTTreeResource = fixture["tree"]
	for node in tree.nodes:
		if node == null or node.parent_id == -1 or not rects_by_id.has(node.id) or not rects_by_id.has(node.parent_id):
			continue
		var child_rect: Rect2 = rects_by_id[node.id]
		var parent_rect: Rect2 = rects_by_id[node.parent_id]
		min_parent_child_gap = minf(min_parent_child_gap, child_rect.position.y - parent_rect.end.y)
	if not is_finite(min_parent_child_gap):
		min_parent_child_gap = 0.0
	return {
		"resource_nodes": tree.nodes.size(),
		"rendered_cards": nodes.size(),
		"decorators": int(fixture["decorator_count"]),
		"cards_in_viewport": viewport_cards,
		"card_visible_ratio": float(nodes.size()) / float(fixture["card_count"]),
		"bounds_area_px2": bounds.size.x * bounds.size.y,
		"card_area_px2": card_area,
		"overlap_pairs": overlaps,
		"min_parent_child_gap_px": min_parent_child_gap,
		"information_fields": information_fields,
		"dimmed_cards": dimmed,
		"target_in_viewport": target_in_viewport,
		"fit_zoom": 0.0,
	}


func _measure_fit_zoom(view: BTEditorView) -> float:
	view._fit_visible_tree()
	await _settle_frames()
	return view.graph_edit.zoom


func _count_cards_in_viewport(view: BTEditorView) -> int:
	var graph_canvas := view.graph_edit.get_global_rect()
	var count := 0
	for child in view.graph_edit.get_children():
		if child is BTGraphNode and graph_canvas.has_point(child.get_global_rect().get_center()):
			count += 1
	return count


func _raw_row(trial: int, size_position: int, condition_position: int, tree_size: int, condition: String, metrics: Dictionary, interaction_ms: float) -> PackedStringArray:
	return PackedStringArray([
		str(trial), str(size_position), str(condition_position), str(tree_size), condition,
		str(metrics["resource_nodes"]), str(metrics["rendered_cards"]), str(metrics["decorators"]),
		str(metrics["cards_in_viewport"]), str(metrics["card_visible_ratio"]), str(metrics["bounds_area_px2"]),
		str(metrics["card_area_px2"]), str(metrics["overlap_pairs"]), str(metrics["min_parent_child_gap_px"]),
		str(metrics["information_fields"]), str(metrics["dimmed_cards"]), str(metrics["target_in_viewport"]),
		str(metrics["fit_zoom"]), str(interaction_ms), str(Engine.get_version_info().get("string", "unknown")),
		RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name(),
		"%dx%d" % [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
	])


func _build_summary_rows(samples_by_key: Dictionary, metrics_by_key: Dictionary) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	rows.append(PackedStringArray([
		"tree_size", "condition", "n", "median_ms", "q1_ms", "q3_ms", "p95_ms", "rendered_cards",
		"visible_reduction_percent", "cards_in_viewport", "card_area_px2", "card_area_reduction_percent",
		"bounds_area_px2", "bounds_reduction_percent", "dimmed_cards", "dimming_percent", "fit_zoom",
		"fit_zoom_gain_percent", "overlap_max", "min_parent_child_gap_px", "target_in_viewport",
	]))
	for size_variant in TREE_SIZES:
		var tree_size := int(size_variant)
		var baseline: Dictionary = metrics_by_key[_key(tree_size, "Baseline")]
		for condition_variant in CONDITIONS:
			var condition := str(condition_variant)
			var key := _key(tree_size, condition)
			var metrics: Dictionary = metrics_by_key[key]
			var samples: Array[float] = samples_by_key[key]
			var sorted_samples := samples.duplicate()
			sorted_samples.sort()
			var dimming_percent := float(metrics["dimmed_cards"]) / float(metrics["rendered_cards"]) * 100.0 if int(metrics["rendered_cards"]) > 0 else 0.0
			rows.append(PackedStringArray([
				str(tree_size), condition, str(samples.size()), str(_median(sorted_samples)),
				str(_nearest_rank(sorted_samples, 0.25)), str(_nearest_rank(sorted_samples, 0.75)),
				str(_nearest_rank(sorted_samples, 0.95)), str(metrics["rendered_cards"]),
				str(_reduction(float(metrics["rendered_cards"]), float(baseline["rendered_cards"]))),
				str(metrics["cards_in_viewport"]), str(metrics["card_area_px2"]),
				str(_reduction(float(metrics["card_area_px2"]), float(baseline["card_area_px2"]))),
				str(metrics["bounds_area_px2"]),
				str(_reduction(float(metrics["bounds_area_px2"]), float(baseline["bounds_area_px2"]))),
				str(metrics["dimmed_cards"]), str(dimming_percent), str(metrics["fit_zoom"]),
				str(_gain(float(metrics["fit_zoom"]), float(baseline["fit_zoom"]))),
				str(metrics["overlap_pairs"]), str(metrics["min_parent_child_gap_px"]),
				str(metrics["target_in_viewport"]),
			]))
	return rows


func _build_trend_rows(metrics_by_key: Dictionary) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	rows.append(PackedStringArray([
		"tree_size", "baseline_cards", "compact_area_reduction_percent", "overview_area_reduction_percent",
		"search_dimming_percent", "focus_card_reduction_percent", "collapse_card_reduction_percent",
		"baseline_fit_zoom", "overview_fit_zoom", "overview_fit_zoom_gain_percent", "overlap_max",
	]))
	for size_variant in TREE_SIZES:
		var tree_size := int(size_variant)
		var baseline: Dictionary = metrics_by_key[_key(tree_size, "Baseline")]
		var compact: Dictionary = metrics_by_key[_key(tree_size, "Compact Cards")]
		var overview: Dictionary = metrics_by_key[_key(tree_size, "Optimized Overview")]
		var search: Dictionary = metrics_by_key[_key(tree_size, "Optimized Search")]
		var focus: Dictionary = metrics_by_key[_key(tree_size, "Subtree Focus")]
		var collapse: Dictionary = metrics_by_key[_key(tree_size, "Context Collapse")]
		var overlap_max := 0
		for condition_variant in CONDITIONS:
			overlap_max = maxi(overlap_max, int(metrics_by_key[_key(tree_size, str(condition_variant))]["overlap_pairs"]))
		rows.append(PackedStringArray([
			str(tree_size), str(baseline["rendered_cards"]),
			str(_reduction(float(compact["card_area_px2"]), float(baseline["card_area_px2"]))),
			str(_reduction(float(overview["card_area_px2"]), float(baseline["card_area_px2"]))),
			str(float(search["dimmed_cards"]) / float(search["rendered_cards"]) * 100.0),
			str(_reduction(float(focus["rendered_cards"]), float(baseline["rendered_cards"]))),
			str(_reduction(float(collapse["rendered_cards"]), float(baseline["rendered_cards"]))),
			str(baseline["fit_zoom"]), str(overview["fit_zoom"]),
			str(_gain(float(overview["fit_zoom"]), float(baseline["fit_zoom"]))), str(overlap_max),
		]))
	return rows


func _capture_evidence(view: BTEditorView, viewport: SubViewport, fixtures: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCREENSHOT_DIR))
	for size_variant in TREE_SIZES:
		var tree_size := int(size_variant)
		var fixture: Dictionary = fixtures[tree_size]
		await _activate_tree(view, fixture)
		for condition_variant in SCREENSHOT_CONDITIONS:
			var condition := str(condition_variant)
			await _restore_baseline(view, fixture["tree"])
			await _apply_condition(view, fixture, condition)
			# Search deliberately frames the matching node. The other evidence
			# conditions need an explicit whole-tree frame before capture.
			if condition != "Optimized Search":
				view._fit_visible_tree()
				await _settle_frames()
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			RenderingServer.force_draw(false, 0.0)
			await process_frame
			var image := viewport.get_texture().get_image()
			var filename := "%03d_%s.png" % [tree_size, condition.to_lower().replace(" ", "_")]
			var save_error := image.save_png(SCREENSHOT_DIR.path_join(filename))
			failures += _expect(save_error == OK, "%d-node %s evidence screenshot saves" % [tree_size, condition])


func _validate_results(fixtures: Dictionary, metrics_by_key: Dictionary) -> int:
	var result := 0
	for size_variant in TREE_SIZES:
		var tree_size := int(size_variant)
		var fixture: Dictionary = fixtures[tree_size]
		var tree: BTTreeResource = fixture["tree"]
		var baseline: Dictionary = metrics_by_key[_key(tree_size, "Baseline")]
		var compact: Dictionary = metrics_by_key[_key(tree_size, "Compact Cards")]
		var overview: Dictionary = metrics_by_key[_key(tree_size, "Optimized Overview")]
		var search: Dictionary = metrics_by_key[_key(tree_size, "Optimized Search")]
		var focus: Dictionary = metrics_by_key[_key(tree_size, "Subtree Focus")]
		var collapse: Dictionary = metrics_by_key[_key(tree_size, "Context Collapse")]
		result += _expect(tree.nodes.size() == tree_size, "%d-node fixture remains exact" % tree_size)
		result += _expect(int(baseline["rendered_cards"]) == int(fixture["card_count"]), "%d-node Baseline renders every card" % tree_size)
		result += _expect(_reduction(float(compact["card_area_px2"]), float(baseline["card_area_px2"])) >= 40.0, "%d-node Compact reduces card area by at least 40 percent" % tree_size)
		result += _expect(_reduction(float(overview["card_area_px2"]), float(baseline["card_area_px2"])) >= 70.0, "%d-node Overview reduces card area by at least 70 percent" % tree_size)
		result += _expect(float(overview["fit_zoom"]) + 0.0001 >= float(baseline["fit_zoom"]), "%d-node Overview does not reduce fit-to-view zoom" % tree_size)
		if tree_size >= 61:
			var dimming_percent := float(search["dimmed_cards"]) / float(search["rendered_cards"]) * 100.0
			result += _expect(dimming_percent >= 95.0, "%d-node Search dims at least 95 percent of cards" % tree_size)
		result += _expect(bool(search["target_in_viewport"]), "%d-node Search centers its target inside the canvas" % tree_size)
		if tree_size >= 121:
			result += _expect(_reduction(float(focus["rendered_cards"]), float(baseline["rendered_cards"])) >= 70.0, "%d-node Focus reduces cards by at least 70 percent" % tree_size)
			result += _expect(_reduction(float(collapse["rendered_cards"]), float(baseline["rendered_cards"])) >= 70.0, "%d-node Collapse reduces cards by at least 70 percent" % tree_size)
		for condition_variant in CONDITIONS:
			var condition := str(condition_variant)
			var metrics: Dictionary = metrics_by_key[_key(tree_size, condition)]
			result += _expect(int(metrics["overlap_pairs"]) == 0, "%d-node %s has zero overlaps" % [tree_size, condition])
			result += _expect(float(metrics["min_parent_child_gap_px"]) >= -0.01, "%d-node %s preserves parent-child spacing" % [tree_size, condition])
		result += _expect(_positions_unchanged(tree, fixture["positions"]), "%d-node display conditions preserve saved positions" % tree_size)
		result += _expect(_order_signature(tree) == str(fixture["order_signature"]), "%d-node display conditions preserve execution order" % tree_size)
	return result


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


func _order_signature(tree: BTTreeResource) -> String:
	var parts: Array[String] = []
	for node in tree.nodes:
		if node == null or node.decorator_parent_id != -1:
			continue
		var child_ids: Array[String] = []
		for child in tree.get_children_of(node.id):
			child_ids.append(str(child.id))
		parts.append("%d:%s" % [node.id, ",".join(child_ids)])
	return "|".join(parts)


func _information_fields_for(condition: String) -> int:
	match condition:
		"Compact Cards", "Subtree Focus", "Context Collapse":
			return 2
		"Optimized Overview", "Optimized Search":
			return 1
		_:
			return 6


func _key(tree_size: int, condition: String) -> String:
	return "%d|%s" % [tree_size, condition]


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


func _gain(value: float, baseline: float) -> float:
	return (value / baseline - 1.0) * 100.0 if baseline > 0.0 else 0.0


func _write_rows(path: String, rows: Array[PackedStringArray]) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
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
