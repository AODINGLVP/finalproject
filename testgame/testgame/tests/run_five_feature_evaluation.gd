extends SceneTree

## Paired evaluation of the five user-facing Display features in the current
## editor. The experiment uses the five behavior trees loaded by the playable
## arena and three physical-size profiles captured from real displays.

const BTEditorView = preload("res://addons/behavior_tree_editor/bt_editor_view.gd")
const BTGraphNode = preload("res://addons/behavior_tree_editor/bt_graph_node.gd")
const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")

const FEATURE_KEYS := [
	"auto_spacing",
	"semantic_zoom",
	"translucent_cards",
	"breadcrumb",
	"fisheye",
]
const FEATURE_NAMES := {
	"auto_spacing": "Smart Drag Reflow",
	"semantic_zoom": "Adaptive Zoom Detail",
	"translucent_cards": "Readable Edge Overlay",
	"breadcrumb": "Related Node Focus",
	"fisheye": "Fisheye Focus",
}
const TREE_PROFILES := [
	{"size": 31, "path": "res://behavior_trees/arena_scout_31.tres", "actor": "Scout"},
	{"size": 61, "path": "res://behavior_trees/arena_skirmisher_61.tres", "actor": "Skirmisher"},
	{"size": 121, "path": "res://behavior_trees/arena_hunter_121.tres", "actor": "Hunter"},
	{"size": 241, "path": "res://behavior_trees/arena_tactician_241.tres", "actor": "Tactician"},
	{"size": 364, "path": "res://behavior_trees/arena_commander_364.tres", "actor": "Commander"},
]
const SCREEN_PROFILES := [
	{
		"key": "laptop_15_94",
		"model": "BOE0CD1",
		"width_cm": 34.0,
		"height_cm": 22.0,
		"diagonal_in": 15.9437,
		"area_cm2": 748.0,
		"canvas": Vector2i(1190, 770),
	},
	{
		"key": "medium_26_96",
		"model": "H27T22S",
		"width_cm": 60.0,
		"height_cm": 33.0,
		"diagonal_in": 26.9574,
		"area_cm2": 1980.0,
		"canvas": Vector2i(2100, 1155),
	},
	{
		"key": "large_31_55",
		"model": "U32G3X",
		"width_cm": 70.0,
		"height_cm": 39.0,
		"diagonal_in": 31.5464,
		"area_cm2": 2730.0,
		"canvas": Vector2i(2450, 1365),
	},
]
const TASK_COUNT := 3
const LOGICAL_UNITS_PER_CM := 35.0
const DEFAULT_OUTPUT_DIR := "res://test_results/five_feature_evaluation"
const EVIDENCE_TREE_SIZE := 241
const EVIDENCE_SCREEN_KEY := "laptop_15_94"
const EVIDENCE_TASK_INDEX := 1
const SETTLE_FRAME_COUNT := 2

var failures := 0
var output_dir := ""
var viewport: SubViewport
var view: BTEditorView
var raw_rows: Array[PackedStringArray] = []
var pair_manifest: Array[Dictionary] = []
var quick_mode := false
var configured_task_count := TASK_COUNT


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	quick_mode = OS.get_environment("BT_FIVE_FEATURE_QUICK") == "1"
	var quick_task_count := int(OS.get_environment("BT_FIVE_FEATURE_QUICK_TASKS"))
	configured_task_count = clampi(quick_task_count, 1, TASK_COUNT) if quick_mode and quick_task_count > 0 else (1 if quick_mode else TASK_COUNT)
	output_dir = OS.get_environment("BT_FIVE_FEATURE_OUTPUT_DIR").replace("\\", "/")
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path(DEFAULT_OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(output_dir)
	DirAccess.make_dir_recursive_absolute(output_dir.path_join("evidence"))

	viewport = SubViewport.new()
	viewport.size = Vector2i(1190, 770)
	viewport.gui_embed_subwindows = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	view = BTEditorView.new()
	view.size = Vector2(viewport.size)
	viewport.add_child(view)
	await _settle()

	raw_rows.append(_raw_header())
	for screen_variant in _active_screen_profiles():
		var screen: Dictionary = screen_variant
		await _configure_screen(screen)
		for tree_variant in _active_tree_profiles():
			var tree_profile: Dictionary = tree_variant
			var canonical := ResourceLoader.load(
				str(tree_profile["path"]), "", ResourceLoader.CACHE_MODE_IGNORE
			) as BTTreeResource
			failures += _expect(canonical != null, "%s tree loads" % str(tree_profile["actor"]))
			if canonical == null:
				continue
			failures += _expect(canonical.nodes.size() == int(tree_profile["size"]), "%d-node real tree has its declared resource count" % int(tree_profile["size"]))
			failures += _expect(canonical.validate_tree().is_empty(), "%d-node real tree passes validation" % int(tree_profile["size"]))
			var target_sets := _build_task_targets(canonical)
			failures += _expect(target_sets.size() == TASK_COUNT, "%d-node tree supplies three deterministic task targets" % int(tree_profile["size"]))
			if target_sets.size() != TASK_COUNT:
				continue
			for task_index in range(configured_task_count):
				for feature_key_variant in FEATURE_KEYS:
					var feature_key := str(feature_key_variant)
					var pair_id := "%s|%03d|t%d|%s" % [
						str(screen["key"]), int(tree_profile["size"]), task_index + 1, feature_key,
					]
					var pair_states: Array[Dictionary] = []
					for enabled in [false, true]:
						var working_tree := canonical.duplicate_tree() as BTTreeResource
						await _prepare_baseline(working_tree, tree_profile)
						var state_metrics := await _run_feature_state(
							feature_key, enabled, screen, tree_profile, target_sets[task_index]
						)
						var common := _measure_common(working_tree, canonical)
						for metric_key in state_metrics:
							common[metric_key] = state_metrics[metric_key]
						common["pair_id"] = pair_id
						common["state"] = "on" if enabled else "off"
						common["feature_key"] = feature_key
						common["feature"] = str(FEATURE_NAMES[feature_key])
						common["screen_key"] = str(screen["key"])
						common["screen_model"] = str(screen["model"])
						common["width_cm"] = float(screen["width_cm"])
						common["height_cm"] = float(screen["height_cm"])
						common["diagonal_in"] = float(screen["diagonal_in"])
						common["screen_area_cm2"] = float(screen["area_cm2"])
						common["canvas_width"] = int((screen["canvas"] as Vector2i).x)
						common["canvas_height"] = int((screen["canvas"] as Vector2i).y)
						common["tree_size"] = int(tree_profile["size"])
						common["tree_path"] = str(tree_profile["path"])
						common["actor"] = str(tree_profile["actor"])
						common["task_index"] = task_index + 1
						common["target_id"] = int(target_sets[task_index]["target_id"])
						common["secondary_id"] = int(target_sets[task_index]["secondary_id"])
						common["drag_source_id"] = int(target_sets[task_index]["drag_source_id"])
						common["drag_target_id"] = int(target_sets[task_index]["drag_target_id"])
						common["engine"] = str(Engine.get_version_info().get("string", "unknown"))
						common["renderer"] = RenderingServer.get_current_rendering_method()
						common["gpu"] = RenderingServer.get_video_adapter_name()
						raw_rows.append(_raw_row(common))
						pair_states.append(common)
						if _is_evidence_case(screen, tree_profile, task_index):
							await _capture_evidence(feature_key, enabled)
						await _cleanup_interaction(feature_key)
					pair_manifest.append({
						"pair_id": pair_id,
						"feature": FEATURE_NAMES[feature_key],
						"off_safe": _state_is_safe(pair_states[0]),
						"on_safe": _state_is_safe(pair_states[1]),
						"effect_valid": _pair_meets_feature_contract(feature_key, pair_states[0], pair_states[1]),
					})
					failures += _expect(_state_is_safe(pair_states[0]) and _state_is_safe(pair_states[1]), "%s preserves structure and saved non-drag state" % pair_id)
					failures += _expect(_pair_meets_feature_contract(feature_key, pair_states[0], pair_states[1]), "%s produces the intended measurable feature effect" % pair_id)
			print("BT_FIVE_FEATURE_PROGRESS screen=%s tree=%d" % [str(screen["key"]), int(tree_profile["size"])])

	_write_csv(output_dir.path_join("raw_observations.csv"), raw_rows)
	_write_manifest()
	print("BT_FIVE_FEATURE_SUMMARY pairs=%d observations=%d failures=%d output=%s" % [
		pair_manifest.size(), raw_rows.size() - 1, failures, output_dir,
	])
	_shutdown()
	quit(0 if failures == 0 else 1)


func _configure_screen(screen: Dictionary) -> void:
	var canvas: Vector2i = screen["canvas"]
	viewport.size = canvas
	view.size = Vector2(canvas)
	await _settle()


func _active_screen_profiles() -> Array:
	return [SCREEN_PROFILES[0]] if quick_mode else SCREEN_PROFILES


func _active_tree_profiles() -> Array:
	return [TREE_PROFILES[0], TREE_PROFILES[3]] if quick_mode else TREE_PROFILES


func _prepare_baseline(tree: BTTreeResource, tree_profile: Dictionary) -> void:
	view.set_process(true)
	view.current_tree = tree
	view.current_tree_path = str(tree_profile["path"])
	view.next_node_id = tree.nodes.size() + 1
	for feature_key_variant in FEATURE_KEYS:
		view.feature_states[str(feature_key_variant)] = false
	view.fisheye_enabled = false
	view.semantic_zoom_enabled = false
	view.compact_mode_enabled = false
	view.semantic_detail_level = 2
	view.selected_node_id = -1
	view.selected_graph_node_ids.clear()
	view.search_query = ""
	view.search_result_ids.clear()
	view.search_result_index = -1
	view.focus_root_id = -1
	view.graph_edit.zoom = 1.0
	view.graph_edit.scroll_offset = Vector2.ZERO
	view._reset_fisheye()
	view._reset_auto_spacing()
	view._rebuild_graph()
	await _settle()


func _run_feature_state(feature_key: String, enabled: bool, screen: Dictionary, tree_profile: Dictionary, targets: Dictionary) -> Dictionary:
	match feature_key:
		"auto_spacing":
			return await _run_smart_drag_state(enabled, targets)
		"semantic_zoom":
			return await _run_adaptive_state(enabled, screen, int(tree_profile["size"]), int(targets["target_id"]))
		"translucent_cards":
			return await _run_overlay_state(enabled, int(targets["target_id"]), int(targets["task_index"]))
		"breadcrumb":
			return await _run_related_state(enabled, screen, int(tree_profile["size"]), targets)
		"fisheye":
			return await _run_fisheye_state(enabled, screen, int(tree_profile["size"]), int(targets["target_id"]))
		_:
			failures += _expect(false, "known feature state %s" % feature_key)
			return {}


func _run_smart_drag_state(enabled: bool, targets: Dictionary) -> Dictionary:
	view.feature_states["auto_spacing"] = enabled
	view.graph_edit.zoom = 0.75
	var source := _graph_node(int(targets["drag_source_id"]))
	var target := _graph_node(int(targets["drag_target_id"]))
	if source == null or target == null:
		failures += _expect(false, "Smart Drag source and target cards exist")
		return {}
	_center_node(target)
	await _settle()
	var initial_offsets := _capture_visual_offsets()
	var resource_positions := _capture_positions(view.current_tree)
	var source_start := source.position_offset
	view._on_graph_node_drag_started(source.node_resource.id)
	source.manual_dragging = true
	source.manual_drag_moved = true
	source.position_offset = target.position_offset + Vector2(12.0, 8.0)
	view._on_graph_node_position_changed(source)
	await _settle()
	if enabled:
		view._update_auto_spacing(0.0, true)
		await _settle()
	var overlap := _overlap_metrics()
	var moved_count := 0
	var max_move_px := 0.0
	var far_moved_count := 0
	for graph_node in _graph_nodes():
		if graph_node.node_resource.id == source.node_resource.id:
			continue
		var before := Vector2(initial_offsets.get(graph_node.node_resource.id, Vector2.ZERO))
		var displacement_px := (graph_node.visual_offset - before).length() * view.graph_edit.zoom
		if displacement_px > 0.5:
			moved_count += 1
			max_move_px = maxf(max_move_px, displacement_px)
			if graph_node.position_offset.distance_to(source.position_offset) * view.graph_edit.zoom > 900.0:
				far_moved_count += 1
	return {
		"operation_zoom": view.graph_edit.zoom,
		"smart_overlap_pairs": int(overlap["pairs"]),
		"smart_overlap_area_px2": float(overlap["area"]),
		"smart_other_cards_moved": moved_count,
		"smart_max_other_move_px": max_move_px,
		"smart_far_cards_moved": far_moved_count,
		"smart_solver_active": view.drag_auto_spacing_active,
		"smart_resource_positions_unchanged": _positions_equal(view.current_tree, resource_positions),
		"smart_source_start_x": source_start.x,
		"smart_source_start_y": source_start.y,
	}


func _run_adaptive_state(enabled: bool, screen: Dictionary, tree_size: int, target_id: int) -> Dictionary:
	view.feature_states["semantic_zoom"] = enabled
	view.semantic_zoom_enabled = enabled
	var zoom := _overview_zoom(screen, tree_size)
	view.graph_edit.zoom = zoom
	if enabled:
		view._update_semantic_zoom(true)
		view._update_auto_spacing(0.0, true)
	else:
		view.semantic_detail_level = 2
		view.compact_mode_enabled = false
		view._apply_semantic_detail_level()
	var target := _graph_node(target_id)
	if target != null:
		_center_node(target)
	await _settle()
	var common := _measure_view_metrics()
	return {
		"operation_zoom": zoom,
		"adaptive_detail_level": view.semantic_detail_level,
		"adaptive_compact": view.compact_mode_enabled,
		"adaptive_card_area_px2": float(common["card_area_px2"]),
		"adaptive_cards_in_viewport": int(common["cards_in_viewport"]),
		"adaptive_cards_fully_in_viewport": int(common["cards_fully_in_viewport"]),
		"adaptive_card_visible_area_px2": float(common["card_visible_area_px2"]),
		"adaptive_information_fields": int(common["information_fields"]),
		"adaptive_overlap_pairs": int(common["overlap_pairs"]),
		"adaptive_overlap_area_px2": float(common["overlap_area_px2"]),
		"adaptive_hierarchy_violations": int(common["hierarchy_violations"]),
	}


func _run_overlay_state(enabled: bool, target_id: int, task_index: int) -> Dictionary:
	# Hold the controlled visual-only blocker in place. The editor's normal idle
	# cleanup correctly removes temporary offsets, but that would also remove the
	# paired congestion fixture before it can be measured.
	view.set_process(false)
	view.feature_states["translucent_cards"] = enabled
	view.graph_edit.zoom = 0.75
	var fixture: Dictionary = await _prepare_edge_crossing_fixture(task_index)
	await _settle()
	var from_node := _graph_node(int(fixture.get("from_id", -1)))
	var to_node := _graph_node(int(fixture.get("to_id", -1)))
	var route_before := PackedVector2Array()
	if from_node != null and to_node != null:
		route_before = view.graph_edit._route_connection_between(from_node, to_node)
	view._apply_feature_states()
	var target := _graph_node(target_id)
	if fixture.has("blocker_id"):
		target = _graph_node(int(fixture["blocker_id"]))
	if target != null:
		_center_node(target)
	await _settle()
	var route_after := PackedVector2Array()
	if from_node != null and to_node != null:
		route_after = view.graph_edit._route_connection_between(from_node, to_node)
	var blocker := _graph_node(int(fixture.get("blocker_id", -1)))
	var crossing_length := 0.0
	if blocker != null:
		crossing_length = _polyline_length_inside_rect(
			route_after, Rect2(blocker.position, blocker.size * blocker.scale)
		)
	var alpha := BTGraphNode.TRANSLUCENT_CARD_ALPHA_FACTOR if enabled else 1.0
	return {
		"operation_zoom": view.graph_edit.zoom,
		"overlay_from_id": int(fixture.get("from_id", -1)),
		"overlay_to_id": int(fixture.get("to_id", -1)),
		"overlay_blocker_id": int(fixture.get("blocker_id", -1)),
		"overlay_crossing_length_px": crossing_length,
		"overlay_background_alpha": alpha,
		"overlay_revealed_edge_weighted_px": crossing_length * (1.0 - alpha),
		"overlay_text_mask_count": _count_translucent_text_masks(),
		"overlay_routes_unchanged": _polylines_equal(route_before, route_after),
	}


func _run_related_state(enabled: bool, screen: Dictionary, tree_size: int, targets: Dictionary) -> Dictionary:
	view.feature_states["breadcrumb"] = enabled
	view.graph_edit.zoom = _overview_zoom(screen, tree_size)
	var selected_ids: Array[int] = [int(targets["target_id"])]
	if int(targets["task_index"]) == 2:
		selected_ids.append(int(targets["secondary_id"]))
	view._on_canvas_selection_changed(selected_ids)
	var target := _graph_node(selected_ids[0])
	if target != null:
		_center_node(target)
	await _settle()
	var expected := _related_sets(view.current_tree, selected_ids)
	var related_count := 0
	var unrelated_count := 0
	var related_alpha_sum := 0.0
	var unrelated_alpha_sum := 0.0
	var correctly_dimmed := 0
	var correctly_classified := 0
	var full_bright_in_view := 0
	var canvas_rect := view.graph_edit.get_global_rect()
	for graph_node in _graph_nodes():
		var node_id := graph_node.node_resource.id
		var is_related := bool(expected["related"].has(node_id))
		if is_related:
			related_count += 1
			related_alpha_sum += graph_node.modulate.a
			if not enabled or graph_node.selection_context_role != BTGraphNode.SELECTION_ROLE_UNRELATED:
				correctly_classified += 1
		else:
			unrelated_count += 1
			unrelated_alpha_sum += graph_node.modulate.a
			if enabled and graph_node.modulate.a <= BTGraphNode.SELECTION_UNRELATED_ALPHA + 0.01:
				correctly_dimmed += 1
			if not enabled:
				correctly_classified += 1
		if canvas_rect.has_point(graph_node.get_global_rect().get_center()) and graph_node.modulate.a >= 0.95:
			full_bright_in_view += 1
	var related_mean := related_alpha_sum / float(related_count) if related_count > 0 else 0.0
	var unrelated_mean := unrelated_alpha_sum / float(unrelated_count) if unrelated_count > 0 else 0.0
	return {
		"operation_zoom": view.graph_edit.zoom,
		"related_selected_count": selected_ids.size(),
		"related_expected_count": related_count,
		"related_unrelated_count": unrelated_count,
		"related_correctly_classified": correctly_classified,
		"related_correctly_dimmed": correctly_dimmed,
		"related_mean_alpha": related_mean,
		"related_unrelated_mean_alpha": unrelated_mean,
		"related_salience_ratio": related_mean / unrelated_mean if unrelated_mean > 0.0 else 0.0,
		"related_full_bright_in_view": full_bright_in_view,
	}


func _run_fisheye_state(enabled: bool, screen: Dictionary, tree_size: int, target_id: int) -> Dictionary:
	# Adaptive is held constant in both states because the intended fisheye task is
	# to restore local detail while the rest of a zoomed-out tree stays compact.
	view.feature_states["semantic_zoom"] = true
	view.semantic_zoom_enabled = true
	var zoom := _overview_zoom(screen, tree_size)
	view.graph_edit.zoom = zoom
	view._update_semantic_zoom(true)
	view._update_auto_spacing(0.0, true)
	view.feature_states["fisheye"] = enabled
	view.fisheye_enabled = enabled
	var target := _graph_node(target_id)
	if target == null:
		failures += _expect(false, "Fisheye target card exists")
		return {}
	_center_node(target)
	await _settle()
	# Semantic detail changes card dimensions asynchronously. Recenter once more after
	# they settle, then invoke the same lens operation as a pointer exactly over the
	# target card. This avoids mixing viewport/global coordinate spaces in the test.
	_center_node(target)
	await _settle()
	var baseline_width := target.get_global_rect().size.x
	if enabled:
		view.set_process(false)
		view._apply_fisheye_focus(target, 1.0)
		view._update_auto_spacing(0.0, true)
		await _settle()
	var target_width := target.get_global_rect().size.x
	var magnified_count := 0
	var far_alpha_sum := 0.0
	var far_scale_sum := 0.0
	var far_count := 0
	var nonfocus_magnified := 0
	for graph_node in _graph_nodes():
		if graph_node.fisheye_magnification > 1.001:
			magnified_count += 1
			if graph_node.node_resource.id != target_id:
				nonfocus_magnified += 1
		var center: Vector2 = view._fisheye_reference_screen_center(graph_node)
		if center.distance_to(view.graph_edit.fisheye_focus_position) > view.FISHEYE_FADE_RADIUS_PX:
			far_alpha_sum += graph_node.fisheye_visibility_alpha
			far_scale_sum += graph_node.fisheye_magnification
			far_count += 1
	var protected_overlap := _overlap_metrics_for_ids(view.fisheye_layout_node_ids)
	return {
		"operation_zoom": zoom,
		"fisheye_controlled_prerequisite": "Adaptive Zoom Detail",
		"fisheye_target_width_px": target_width,
		"fisheye_baseline_width_px": baseline_width,
		"fisheye_target_fields": _node_information_fields(target),
		"fisheye_magnified_cards": magnified_count,
		"fisheye_nonfocus_magnified_cards": nonfocus_magnified,
		"fisheye_far_mean_alpha": far_alpha_sum / float(far_count) if far_count > 0 else 1.0,
		"fisheye_far_mean_scale": far_scale_sum / float(far_count) if far_count > 0 else 1.0,
		"fisheye_reflow_cards": view.fisheye_last_reflow_moved_ids.size(),
		"fisheye_layout_cards": view.fisheye_layout_node_ids.size(),
		"fisheye_protected_overlap_pairs": int(protected_overlap["pairs"]),
		"fisheye_protected_overlap_area_px2": float(protected_overlap["area"]),
		"fisheye_stationary_focus_id": view.fisheye_focus_node_id,
	}


func _cleanup_interaction(feature_key: String) -> void:
	if feature_key == "auto_spacing" and view.drag_history_node_id != -1:
		var source := _graph_node(view.drag_history_node_id)
		if source != null:
			source.position_offset = view.drag_auto_spacing_start_position
			source.manual_dragging = false
			view._on_graph_node_drag_finished(source.node_resource.id)
	if feature_key == "fisheye":
		view._reset_fisheye()
		view.set_process(true)
	elif feature_key == "translucent_cards":
		view.set_process(true)
	await _settle()


func _build_task_targets(tree: BTTreeResource) -> Array[Dictionary]:
	var cards: Array = []
	for node in tree.nodes:
		if node != null and node.decorator_parent_id == -1:
			cards.append(node)
	cards.sort_custom(func(left, right):
		if not is_equal_approx(left.position.x, right.position.x):
			return left.position.x < right.position.x
		if not is_equal_approx(left.position.y, right.position.y):
			return left.position.y < right.position.y
		return left.id < right.id
	)
	var focus_cards: Array = []
	for card in cards:
		if card.parent_id == -1:
			continue
		var single_selection: Array[int] = [card.id]
		if int((_related_sets(tree, single_selection)["related"] as Dictionary).size()) < cards.size():
			focus_cards.append(card)
	if focus_cards.is_empty():
		focus_cards = cards.duplicate()
	var drag_pairs := _drag_pairs(tree)
	var targets: Array[Dictionary] = []
	for task_index in range(TASK_COUNT):
		var fraction: float = float([0.22, 0.50, 0.78][task_index])
		var card_index := clampi(roundi(float(focus_cards.size() - 1) * fraction), 0, focus_cards.size() - 1)
		var primary = focus_cards[card_index]
		var secondary = _choose_related_secondary(tree, focus_cards, card_index, cards.size())
		var pair: Vector2i = drag_pairs[task_index % drag_pairs.size()]
		targets.append({
			"task_index": task_index,
			"target_id": primary.id,
			"secondary_id": secondary.id,
			"drag_source_id": pair.x,
			"drag_target_id": pair.y,
		})
	return targets


func _choose_related_secondary(tree: BTTreeResource, focus_cards: Array, primary_index: int, total_cards: int):
	var primary = focus_cards[primary_index]
	var preferred_offset := maxi(1, focus_cards.size() / 7)
	for step in range(focus_cards.size()):
		var candidate_index := (primary_index + preferred_offset + step) % focus_cards.size()
		var candidate = focus_cards[candidate_index]
		if candidate.id == primary.id:
			continue
		var selected_ids: Array[int] = [primary.id, candidate.id]
		if int((_related_sets(tree, selected_ids)["related"] as Dictionary).size()) < total_cards:
			return candidate
	return focus_cards[(primary_index + 1) % focus_cards.size()]


func _drag_pairs(tree: BTTreeResource) -> Array[Vector2i]:
	var pairs: Array[Vector2i] = []
	for parent in tree.nodes:
		if parent == null or parent.decorator_parent_id != -1:
			continue
		var children := tree.get_children_of(parent.id)
		var card_children: Array = []
		for child in children:
			if child.decorator_parent_id == -1:
				card_children.append(child)
		if card_children.size() < 2:
			continue
		card_children.sort_custom(func(left, right): return left.position.x < right.position.x)
		for index in range(card_children.size() - 1):
			if tree.get_children_of(card_children[index].id).is_empty():
				pairs.append(Vector2i(card_children[index].id, card_children[index + 1].id))
	if pairs.size() < TASK_COUNT:
		var cards: Array = []
		for node in tree.nodes:
			if node != null and node.decorator_parent_id == -1:
				cards.append(node)
		for index in range(cards.size() - 1):
			pairs.append(Vector2i(cards[index].id, cards[index + 1].id))
			if pairs.size() >= TASK_COUNT:
				break
	return pairs


func _prepare_edge_crossing_fixture(task_index: int) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for node in view.current_tree.nodes:
		if node == null or node.parent_id == -1 or node.decorator_parent_id != -1:
			continue
		var from_node := _graph_node(node.parent_id)
		var to_node := _graph_node(node.id)
		if from_node == null or to_node == null:
			continue
		var route := view.graph_edit._route_connection_between(from_node, to_node)
		var best_blocker_id := -1
		var best_length := 0.0
		for blocker in _graph_nodes():
			if blocker.node_resource.id == from_node.node_resource.id or blocker.node_resource.id == to_node.node_resource.id:
				continue
			var length := _polyline_length_inside_rect(route, Rect2(blocker.position, blocker.size * blocker.scale))
			if length > best_length:
				best_length = length
				best_blocker_id = blocker.node_resource.id
		candidates.append({
			"from_id": from_node.node_resource.id,
			"to_id": to_node.node_resource.id,
			"blocker_id": best_blocker_id,
			"crossing_length_px": best_length,
		})
	candidates.sort_custom(func(left: Dictionary, right: Dictionary): return float(left["crossing_length_px"]) > float(right["crossing_length_px"]))
	var chosen: Dictionary = candidates[mini(task_index, candidates.size() - 1)]
	if float(chosen["crossing_length_px"]) > 1.0 and int(chosen["blocker_id"]) != -1:
		return chosen
	# The real tree is still used, but a non-endpoint card receives a temporary
	# visual-only offset to produce one controlled congestion case. Resource data
	# and the route remain unchanged in both paired states.
	var from_node := _graph_node(int(chosen["from_id"]))
	var to_node := _graph_node(int(chosen["to_id"]))
	var route := view.graph_edit._route_connection_between(from_node, to_node)
	var midpoint := _polyline_midpoint(route)
	var blocker: BTGraphNode = null
	var best_distance := INF
	for candidate in _graph_nodes():
		if candidate.node_resource.id == from_node.node_resource.id or candidate.node_resource.id == to_node.node_resource.id:
			continue
		var candidate_center := candidate.position + candidate.size * candidate.scale * 0.5
		var distance := candidate_center.distance_to(midpoint)
		if distance < best_distance:
			best_distance = distance
			blocker = candidate
	if blocker != null:
		var current_screen_center := blocker.position + blocker.size * blocker.scale * 0.5
		var tree_delta := (midpoint - current_screen_center) / maxf(view.graph_edit.zoom, 0.01)
		blocker.set_visual_offset(blocker.visual_offset + tree_delta)
		await process_frame
		route = view.graph_edit._route_connection_between(from_node, to_node)
		chosen["blocker_id"] = blocker.node_resource.id
		chosen["crossing_length_px"] = _polyline_length_inside_rect(route, Rect2(blocker.position, blocker.size * blocker.scale))
	return chosen


func _measure_common(tree: BTTreeResource, canonical: BTTreeResource) -> Dictionary:
	var metrics := _measure_view_metrics()
	return {
		"resource_nodes": tree.nodes.size(),
		"canvas_cards": _graph_nodes().size(),
		"decorators": tree.nodes.size() - _graph_nodes().size(),
		"graph_canvas_width": view.graph_edit.size.x,
		"graph_canvas_height": view.graph_edit.size.y,
		"cards_in_viewport": int(metrics["cards_in_viewport"]),
		"cards_fully_in_viewport": int(metrics["cards_fully_in_viewport"]),
		"card_visible_area_px2": float(metrics["card_visible_area_px2"]),
		"card_area_px2": float(metrics["card_area_px2"]),
		"overlap_pairs": int(metrics["overlap_pairs"]),
		"overlap_area_px2": float(metrics["overlap_area_px2"]),
		"information_fields": int(metrics["information_fields"]),
		"hierarchy_violations": int(metrics["hierarchy_violations"]),
		"resource_positions_unchanged": _positions_equal(tree, _capture_positions(canonical)),
		"topology_unchanged": _topology_signature(tree) == _topology_signature(canonical),
		"execution_order_unchanged": _order_signature(tree) == _order_signature(canonical),
	}


func _measure_view_metrics() -> Dictionary:
	var nodes := _graph_nodes()
	var canvas_rect := view.graph_edit.get_global_rect()
	var card_area := 0.0
	var card_visible_area := 0.0
	var cards_in_viewport := 0
	var cards_fully_in_viewport := 0
	var information_fields := 0
	var hierarchy_violations := 0
	for graph_node in nodes:
		var rect := graph_node.get_global_rect()
		card_area += rect.size.x * rect.size.y
		var visible_rect := canvas_rect.intersection(rect)
		card_visible_area += visible_rect.get_area()
		if canvas_rect.has_point(rect.get_center()):
			cards_in_viewport += 1
		if visible_rect.get_area() >= rect.get_area() - 0.5:
			cards_fully_in_viewport += 1
		information_fields += _node_information_fields(graph_node)
	for resource in view.current_tree.nodes:
		if resource == null or resource.parent_id == -1 or resource.decorator_parent_id != -1:
			continue
		var parent := _graph_node(resource.parent_id)
		var child := _graph_node(resource.id)
		if parent != null and child != null and parent.node_resource.position.y < child.node_resource.position.y:
			if parent.get_global_rect().end.y > child.get_global_rect().position.y + 0.5:
				hierarchy_violations += 1
	var overlap := _overlap_metrics()
	return {
		"cards_in_viewport": cards_in_viewport,
		"cards_fully_in_viewport": cards_fully_in_viewport,
		"card_visible_area_px2": card_visible_area,
		"card_area_px2": card_area,
		"information_fields": information_fields,
		"hierarchy_violations": hierarchy_violations,
		"overlap_pairs": int(overlap["pairs"]),
		"overlap_area_px2": float(overlap["area"]),
	}


func _node_information_fields(graph_node: BTGraphNode) -> int:
	var count := 0
	for label in [graph_node.title_label, graph_node.order_label, graph_node.type_badge, graph_node.description_label, graph_node.runtime_label, graph_node.failure_badge, graph_node.collapsed_summary_label]:
		if label != null and label.visible and not label.text.strip_edges().is_empty():
			count += 1
	if graph_node.decorator_badges != null and graph_node.decorator_badges.visible:
		for child in graph_node.decorator_badges.get_children():
			if child is Label and child.visible and not child.text.strip_edges().is_empty():
				count += 1
	return count


func _overlap_metrics() -> Dictionary:
	var ids: Array[int] = []
	for graph_node in _graph_nodes():
		ids.append(graph_node.node_resource.id)
	return _overlap_metrics_for_ids(ids)


func _overlap_metrics_for_ids(ids: Array[int]) -> Dictionary:
	var pairs := 0
	var area := 0.0
	for left_index in range(ids.size()):
		var left := _graph_node(ids[left_index])
		if left == null:
			continue
		var left_rect := left.get_global_rect()
		for right_index in range(left_index + 1, ids.size()):
			var right := _graph_node(ids[right_index])
			if right == null:
				continue
			var right_rect := right.get_global_rect()
			if left_rect.intersects(right_rect):
				pairs += 1
				area += left_rect.intersection(right_rect).get_area()
	return {"pairs": pairs, "area": area}


func _related_sets(tree: BTTreeResource, selected_ids: Array[int]) -> Dictionary:
	var selected := {}
	var ancestors := {}
	var descendants := {}
	var siblings := {}
	for selected_id in selected_ids:
		selected[selected_id] = true
		var current := tree.find_node(selected_id)
		while current != null and current.parent_id != -1:
			ancestors[current.parent_id] = true
			current = tree.find_node(current.parent_id)
		var queue: Array[int] = [selected_id]
		while not queue.is_empty():
			var parent_id: int = queue.pop_front()
			for child in tree.get_children_of(parent_id):
				if child.decorator_parent_id == -1:
					descendants[child.id] = true
					queue.append(child.id)
		var selected_node := tree.find_node(selected_id)
		if selected_node != null and selected_node.parent_id != -1:
			for sibling in tree.get_children_of(selected_node.parent_id):
				if sibling.decorator_parent_id == -1 and sibling.id != selected_id:
					siblings[sibling.id] = true
	var related := {}
	for source in [selected, ancestors, descendants, siblings]:
		for node_id in source:
			related[int(node_id)] = true
	return {
		"selected": selected,
		"ancestors": ancestors,
		"descendants": descendants,
		"siblings": siblings,
		"related": related,
	}


func _count_translucent_text_masks() -> int:
	var count := 0
	for graph_node in _graph_nodes():
		for label in [graph_node.title_label, graph_node.order_label, graph_node.type_badge, graph_node.description_label, graph_node.runtime_label, graph_node.failure_badge, graph_node.collapsed_summary_label]:
			if label != null and label.has_meta(BTGraphNode.TRANSLUCENT_TEXT_BASELINE_META):
				count += 1
	return count


func _overview_zoom(screen: Dictionary, tree_size: int) -> float:
	var laptop_zoom: float = float({
		31: 0.60,
		61: 0.45,
		121: 0.32,
		241: 0.22,
		364: 0.16,
	}.get(tree_size, 0.22))
	var width_factor := float((screen["canvas"] as Vector2i).x) / 1190.0
	return clampf(float(laptop_zoom) * width_factor, 0.10, 0.75)


func _center_node(graph_node: BTGraphNode) -> void:
	view.graph_edit.scroll_offset = (graph_node.position_offset + graph_node.size * 0.5) * view.graph_edit.zoom - view.graph_edit.size * 0.5


func _graph_node(node_id: int) -> BTGraphNode:
	return view.graph_edit.get_node_or_null(NodePath(str(node_id))) as BTGraphNode


func _graph_nodes() -> Array[BTGraphNode]:
	var nodes: Array[BTGraphNode] = []
	for child in view.graph_edit.get_children():
		if child is BTGraphNode and child.node_resource != null:
			nodes.append(child)
	return nodes


func _capture_positions(tree: BTTreeResource) -> Dictionary:
	var positions := {}
	for node in tree.nodes:
		if node != null:
			positions[node.id] = node.position
	return positions


func _capture_visual_offsets() -> Dictionary:
	var offsets := {}
	for graph_node in _graph_nodes():
		offsets[graph_node.node_resource.id] = graph_node.visual_offset
	return offsets


func _positions_equal(tree: BTTreeResource, expected: Dictionary) -> bool:
	for node in tree.nodes:
		if node != null and (not expected.has(node.id) or not node.position.is_equal_approx(Vector2(expected[node.id]))):
			return false
	return true


func _topology_signature(tree: BTTreeResource) -> String:
	var parts: Array[String] = []
	for node in tree.nodes:
		if node != null:
			parts.append("%d:%d:%d:%s" % [node.id, node.parent_id, node.decorator_parent_id, node.node_type])
	parts.sort()
	return "|".join(parts)


func _order_signature(tree: BTTreeResource) -> String:
	var parts: Array[String] = []
	for parent in tree.nodes:
		if parent == null or parent.decorator_parent_id != -1:
			continue
		var child_parts: Array[String] = []
		for child in tree.get_children_of(parent.id):
			if child.decorator_parent_id == -1:
				child_parts.append(str(child.id))
		parts.append("%d:%s" % [parent.id, ",".join(child_parts)])
	return "|".join(parts)


func _polyline_length_inside_rect(points: PackedVector2Array, rect: Rect2) -> float:
	var length := 0.0
	for index in range(points.size() - 1):
		length += _segment_length_inside_rect(points[index], points[index + 1], rect)
	return length


func _polyline_midpoint(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	if points.size() == 1:
		return points[0]
	var total_length := 0.0
	for index in range(points.size() - 1):
		total_length += points[index].distance_to(points[index + 1])
	if is_zero_approx(total_length):
		return points[0]
	var remaining := total_length * 0.5
	for index in range(points.size() - 1):
		var segment_length := points[index].distance_to(points[index + 1])
		if remaining <= segment_length:
			return points[index].lerp(points[index + 1], remaining / maxf(segment_length, 0.001))
		remaining -= segment_length
	return points[points.size() - 1]


func _polylines_equal(left: PackedVector2Array, right: PackedVector2Array) -> bool:
	if left.size() != right.size():
		return false
	if left.is_empty():
		return true
	# Centering the evidence card pans the viewport and translates every route by
	# the same amount. Compare the routed shape, not its temporary screen origin;
	# GraphEdit rounds scrolled control positions to sub-pixel boundaries.
	for index in range(1, left.size()):
		var left_segment := left[index] - left[index - 1]
		var right_segment := right[index] - right[index - 1]
		if left_segment.distance_to(right_segment) > 0.75:
			return false
	return true


func _segment_length_inside_rect(start: Vector2, finish: Vector2, rect: Rect2) -> float:
	var delta := finish - start
	var t_min := 0.0
	var t_max := 1.0
	var checks: Array[Vector2] = [
		Vector2(-delta.x, start.x - rect.position.x),
		Vector2(delta.x, rect.end.x - start.x),
		Vector2(-delta.y, start.y - rect.position.y),
		Vector2(delta.y, rect.end.y - start.y),
	]
	for check: Vector2 in checks:
		var p: float = check.x
		var q: float = check.y
		if is_zero_approx(p):
			if q < 0.0:
				return 0.0
			continue
		var ratio: float = q / p
		if p < 0.0:
			t_min = maxf(t_min, ratio)
		else:
			t_max = minf(t_max, ratio)
		if t_min > t_max:
			return 0.0
	return delta.length() * maxf(0.0, t_max - t_min)


func _is_evidence_case(screen: Dictionary, tree_profile: Dictionary, task_index: int) -> bool:
	var requested_task := OS.get_environment("BT_FIVE_FEATURE_EVIDENCE_TASK").strip_edges()
	var evidence_task_index := EVIDENCE_TASK_INDEX
	if not requested_task.is_empty():
		evidence_task_index = clampi(int(requested_task) - 1, 0, TASK_COUNT - 1)
	return str(screen["key"]) == EVIDENCE_SCREEN_KEY and int(tree_profile["size"]) == EVIDENCE_TREE_SIZE and task_index == evidence_task_index


func _capture_evidence(feature_key: String, enabled: bool) -> void:
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() == "dummy":
		return
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.force_draw(false, 0.0)
	await process_frame
	var image := viewport.get_texture().get_image()
	var state := "on" if enabled else "off"
	var filename := "%s_%s.png" % [feature_key, state]
	var error := image.save_png(output_dir.path_join("evidence").path_join(filename))
	failures += _expect(error == OK, "%s %s evidence screenshot saves" % [FEATURE_NAMES[feature_key], state])
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _state_is_safe(state: Dictionary) -> bool:
	return bool(state.get("topology_unchanged", false)) \
		and bool(state.get("execution_order_unchanged", false)) \
		and (bool(state.get("resource_positions_unchanged", false)) or bool(state.get("smart_resource_positions_unchanged", false)))


func _pair_meets_feature_contract(feature_key: String, off_state: Dictionary, on_state: Dictionary) -> bool:
	match feature_key:
		"auto_spacing":
			var off_area := float(off_state.get("smart_overlap_area_px2", 0.0))
			var on_area := float(on_state.get("smart_overlap_area_px2", INF))
			return off_area > 1.0 and on_area < off_area * 0.05 \
				and int(on_state.get("smart_other_cards_moved", 99)) <= view.DRAG_REFLOW_MAX_AFFECTED_CARDS \
				and bool(on_state.get("smart_resource_positions_unchanged", false))
		"semantic_zoom":
			var area_reduced := float(on_state.get("adaptive_card_area_px2", INF)) < float(off_state.get("adaptive_card_area_px2", 0.0)) - 1.0
			var fields_reduced := int(on_state.get("adaptive_information_fields", 0)) < int(off_state.get("adaptive_information_fields", 0))
			return int(on_state.get("adaptive_detail_level", 2)) < int(off_state.get("adaptive_detail_level", 2)) \
				and (area_reduced or fields_reduced) \
				and int(on_state.get("adaptive_hierarchy_violations", 0)) <= int(off_state.get("adaptive_hierarchy_violations", 0))
		"translucent_cards":
			return float(on_state.get("overlay_crossing_length_px", 0.0)) > 1.0 \
				and float(on_state.get("overlay_background_alpha", 1.0)) < float(off_state.get("overlay_background_alpha", 1.0)) \
				and float(on_state.get("overlay_revealed_edge_weighted_px", 0.0)) > 0.0 \
				and int(on_state.get("overlay_text_mask_count", 0)) > 0 \
				and bool(on_state.get("overlay_routes_unchanged", false))
		"breadcrumb":
			var unrelated := int(on_state.get("related_unrelated_count", 0))
			return unrelated > 0 \
				and int(on_state.get("related_correctly_dimmed", -1)) == unrelated \
				and float(on_state.get("related_mean_alpha", 0.0)) >= 0.95 \
				and float(on_state.get("related_unrelated_mean_alpha", 1.0)) <= BTGraphNode.SELECTION_UNRELATED_ALPHA + 0.01
		"fisheye":
			return int(on_state.get("fisheye_stationary_focus_id", -1)) == int(on_state.get("target_id", -2)) \
				and float(on_state.get("fisheye_target_width_px", 0.0)) > float(off_state.get("fisheye_target_width_px", 0.0)) * 1.05 \
				and int(on_state.get("fisheye_target_fields", 0)) > int(off_state.get("fisheye_target_fields", 0)) \
				and int(on_state.get("fisheye_magnified_cards", 0)) >= 1 \
				and int(on_state.get("fisheye_layout_cards", 99)) <= view.FISHEYE_REFLOW_MAX_AFFECTED_CARDS
	return false


func _raw_header() -> PackedStringArray:
	return PackedStringArray([
		"pair_id", "state", "feature_key", "feature", "screen_key", "screen_model",
		"width_cm", "height_cm", "diagonal_in", "screen_area_cm2", "logical_units_per_cm",
		"canvas_width", "canvas_height", "tree_size", "tree_path", "actor", "task_index",
		"target_id", "secondary_id", "drag_source_id", "drag_target_id", "resource_nodes",
		"canvas_cards", "decorators", "graph_canvas_width", "graph_canvas_height", "operation_zoom",
		"cards_in_viewport", "cards_fully_in_viewport", "card_visible_area_px2", "card_area_px2", "overlap_pairs", "overlap_area_px2", "information_fields",
		"hierarchy_violations", "resource_positions_unchanged", "topology_unchanged", "execution_order_unchanged",
		"smart_overlap_pairs", "smart_overlap_area_px2", "smart_other_cards_moved", "smart_max_other_move_px",
		"smart_far_cards_moved", "smart_solver_active", "smart_resource_positions_unchanged",
		"adaptive_detail_level", "adaptive_compact", "adaptive_card_area_px2", "adaptive_cards_in_viewport",
		"adaptive_cards_fully_in_viewport", "adaptive_card_visible_area_px2",
		"adaptive_information_fields", "adaptive_overlap_pairs", "adaptive_overlap_area_px2", "adaptive_hierarchy_violations",
		"overlay_from_id", "overlay_to_id", "overlay_blocker_id", "overlay_crossing_length_px",
		"overlay_background_alpha", "overlay_revealed_edge_weighted_px", "overlay_text_mask_count", "overlay_routes_unchanged",
		"related_selected_count", "related_expected_count", "related_unrelated_count", "related_correctly_classified",
		"related_correctly_dimmed", "related_mean_alpha", "related_unrelated_mean_alpha", "related_salience_ratio",
		"related_full_bright_in_view", "fisheye_controlled_prerequisite", "fisheye_target_width_px",
		"fisheye_baseline_width_px", "fisheye_target_fields", "fisheye_magnified_cards",
		"fisheye_nonfocus_magnified_cards", "fisheye_far_mean_alpha", "fisheye_far_mean_scale",
		"fisheye_reflow_cards", "fisheye_layout_cards", "fisheye_protected_overlap_pairs",
		"fisheye_protected_overlap_area_px2", "fisheye_stationary_focus_id", "engine", "renderer", "gpu",
	])


func _raw_row(metrics: Dictionary) -> PackedStringArray:
	var row := PackedStringArray()
	for column in _raw_header():
		if column == "logical_units_per_cm":
			row.append(str(LOGICAL_UNITS_PER_CM))
		else:
			row.append(str(metrics.get(column, "")))
	return row


func _write_csv(path: String, rows: Array[PackedStringArray]) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	failures += _expect(file != null, "raw observation CSV opens")
	if file == null:
		return
	for row in rows:
		file.store_csv_line(row)
	file.close()


func _write_manifest() -> void:
	var source_hashes := {}
	for tree_variant in TREE_PROFILES:
		var profile: Dictionary = tree_variant
		source_hashes[str(profile["path"])] = FileAccess.get_sha256(ProjectSettings.globalize_path(str(profile["path"])))
	var manifest := {
		"schema_version": 1,
		"created_at_utc": Time.get_datetime_string_from_system(true),
		"execution_mode": "physical_size_profile_replay_on_one_gpu",
		"physical_size_source": "2026-08-23 EDID inventory of three real displays",
		"git_commit": OS.get_environment("BT_FIVE_FEATURE_GIT_COMMIT"),
		"features": FEATURE_NAMES,
		"tree_profiles": TREE_PROFILES,
		"screen_profiles": SCREEN_PROFILES,
		"task_count_per_tree": configured_task_count,
		"quick_mode": quick_mode,
		"pair_count": pair_manifest.size(),
		"observation_count": raw_rows.size() - 1,
		"failures": failures,
		"engine": str(Engine.get_version_info().get("string", "unknown")),
		"renderer": RenderingServer.get_current_rendering_method(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"source_sha256": source_hashes,
		"pairs": pair_manifest,
	}
	var file := FileAccess.open(output_dir.path_join("manifest.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(manifest, "  "))
		file.close()


func _settle() -> void:
	for _index in range(SETTLE_FRAME_COUNT):
		await process_frame
	RenderingServer.force_draw(false, 0.0)
	await process_frame


func _shutdown() -> void:
	if is_instance_valid(viewport):
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if is_instance_valid(view):
		view._reset_fisheye()
		view.free()
		view = null
	if is_instance_valid(viewport):
		viewport.free()
		viewport = null


func _expect(condition: bool, label: String) -> int:
	if condition:
		print("PASS: %s" % label)
		return 0
	printerr("FAIL: %s" % label)
	return 1
