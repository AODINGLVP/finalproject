extends SceneTree

const BTEditorView = preload("res://addons/behavior_tree_editor/bt_editor_view.gd")
const BTGraphNode = preload("res://addons/behavior_tree_editor/bt_graph_node.gd")
const BTNodeResource = preload("res://addons/behavior_tree_editor/bt_node_resource.gd")
const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")
const BTBlackboardEntry = preload("res://addons/behavior_tree_editor/bt_blackboard_entry.gd")
const BTBlackboardSchema = preload("res://addons/behavior_tree_editor/bt_blackboard_schema.gd")

const VIEWPORT_SIZE := Vector2i(1600, 900)
const OUTPUT_DIR := "res://test_results/visual"

var passed := 0
var failed := 0
var viewport: SubViewport
var view: BTEditorView


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	viewport = SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.gui_embed_subwindows = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	view = BTEditorView.new()
	view.set_anchors_preset(Control.PRESET_TOP_LEFT)
	view.size = Vector2(VIEWPORT_SIZE)
	viewport.add_child(view)
	await process_frame
	await process_frame
	# Keep visual cases deterministic; feature updates are invoked explicitly below.
	view.set_process(false)
	view._on_live_debug_toggled(false)
	view.last_runtime_snapshot.clear()
	for definition in view.FEATURE_DEFINITIONS:
		view._set_feature_enabled(str(definition[0]), bool(definition[2]), false)

	view.current_tree = _make_visual_tree()
	view.current_tree_path = "res://behavior_trees/visual_regression_tree.tres"
	view.file_path_edit.text = view.current_tree_path
	view.selected_node_id = 4
	view.next_node_id = 9
	view._refresh_entire_ui()
	_restore_overview()
	await _settle()

	var baseline := await _capture_case("01_baseline")
	var diagnostic_child := _graph_node(view, 2)
	var expected_input_port := diagnostic_child.position + Vector2(diagnostic_child.size.x * diagnostic_child.scale.x * 0.5, 7.0 * diagnostic_child.scale.y)
	var expected_output_port := diagnostic_child.position + Vector2(diagnostic_child.size.x * diagnostic_child.scale.x * 0.5, diagnostic_child.size.y * diagnostic_child.scale.y - 7.0 * diagnostic_child.scale.y)
	_expect(view.graph_edit._input_port_position(diagnostic_child).is_equal_approx(expected_input_port) and view.graph_edit._output_port_position(diagnostic_child).is_equal_approx(expected_output_port), "connection hit testing uses rendered port positions at detail zoom")
	await _test_real_pointer_connection()
	_assert_image_valid(baseline, "baseline renders complete editor")
	_expect(_count_near_color(baseline, Color("34d399"), 0.12) > 1, "baseline contains Action type color")
	_expect(_count_near_color(baseline, Color("f59e0b"), 0.12) > 2, "baseline contains Selector type color")
	_expect(_count_near_color(baseline, Color("14b8a6"), 0.12) > 2, "baseline contains Parallel type color")
	_expect(_count_near_color(baseline, Color("fb923c"), 0.12) > 2, "baseline contains Random Selector type color")
	_expect(_count_near_color(baseline, Color("a78bfa"), 0.12) > 2, "baseline contains Repeat type color")
	_expect(_count_near_color(baseline, Color("facc15"), 0.12) > 2, "baseline contains Wait type color")
	_expect(_overlapping_node_pairs().is_empty(), "baseline node cards do not overlap")
	_expect(_all_parent_child_gaps_at_least(45.0), "baseline keeps a clear parent-child vertical gap")

	view.context_menu.position = Vector2i(260, 170)
	view.context_menu.popup()
	await _settle()
	var context_creation_menu := await _capture_case("01_context_creation_menu")
	_assert_image_valid(context_creation_menu, "canvas node creation menu renders")
	var context_has_all_types := true
	for creation_id in range(10):
		if view.context_menu.get_item_index(creation_id) < 0:
			context_has_all_types = false
			break
	_expect(view.context_menu.visible and context_has_all_types, "right-click menu visibly exposes all ten node types")
	view.context_menu.hide()
	await _settle()

	var display_popup := view.feature_menu_button.get_popup()
	display_popup.position = Vector2i(40, 135)
	display_popup.popup()
	await _settle()
	var display_menu := await _capture_case("01a_display_menu")
	_assert_image_valid(display_menu, "compact Display menu renders")
	_expect(display_popup.visible and display_popup.item_count == 10 and view.advanced_display_menu.item_count == 14, "Display popup keeps common options concise and exposes advanced options in a submenu")
	display_popup.hide()
	await _settle()
	var debug_popup := view.debug_menu_button.get_popup()
	debug_popup.position = Vector2i(40, 95)
	debug_popup.popup()
	await _settle()
	var debug_menu := await _capture_case("01aa_debug_menu")
	_assert_image_valid(debug_menu, "compact Debug menu renders")
	_expect(debug_popup.visible and debug_popup.item_count == 6 and not view.live_debug_toggle.visible and not view.blackboard_toggle.visible, "Debug popup exposes runtime options without expanding the toolbar")
	debug_popup.hide()
	await _settle()

	view._set_feature_enabled("type_encoding", true, false)
	view._set_feature_enabled("compact", true, false)
	view._set_feature_enabled("semantic_zoom", true, false)
	view.semantic_detail_level = 0
	view._apply_semantic_detail_level()
	await _settle()
	var type_encoding := await _capture_case("01b_type_encoding")
	_assert_image_valid(type_encoding, "shape and icon type encoding renders")
	_expect(_all_type_icons_visible(), "type encoding screenshot keeps every icon visible at minimum semantic detail")
	var grayscale := _to_grayscale(type_encoding)
	var grayscale_error := grayscale.save_png(OUTPUT_DIR.path_join("01c_type_encoding_grayscale.png"))
	_expect(grayscale_error == OK and _grayscale_contrast_count(grayscale) > 1000, "type encoding remains high-contrast in grayscale evidence")
	view._set_feature_enabled("type_encoding", false, false)
	view._set_feature_enabled("compact", false, false)
	view._set_feature_enabled("semantic_zoom", false, false)
	await _settle()
	_expect(not _any_type_icon_visible(), "disabling type encoding leaves no icon residue")

	view._set_feature_enabled("accessibility", true, false)
	view._set_feature_enabled("type_encoding", true, false)
	await _settle()
	var accessible := await _capture_case("01d_accessible_palette")
	_assert_image_valid(accessible, "accessible palette and redundant shapes render")
	var accessible_blue_count := _count_near_color(accessible, Color("56b4e9"), 0.16)
	var accessible_orange_count := _count_near_color(accessible, Color("e69f00"), 0.16)
	print("VISUAL_METRIC accessible_blue_pixels=%d accessible_orange_pixels=%d" % [accessible_blue_count, accessible_orange_count])
	_expect(accessible_blue_count > 0 and accessible_orange_count > 0, "accessible screenshot contains distinguishable blue and orange encodings")
	view._set_feature_enabled("accessibility", false, false)
	view._set_feature_enabled("type_encoding", false, false)
	await _settle()
	_expect(_graph_node(view, 2).header_bar.color == Color("f59e0b"), "accessible palette disable restores baseline colors")

	view._set_feature_enabled("single_connection", true, false)
	await _settle()
	var single_edges := await _capture_case("01e_single_connections")
	_assert_image_valid(single_edges, "single bottom-to-top connections render")
	_expect(view.graph_edit.connection_lines_thickness == 0.0 and view.graph_edit.single_connection_rendering_enabled and not view.graph_edit.native_connection_layer.visible, "single-connection screenshot has no native helper edge layer")
	var edge_midpoint := _first_connection_midpoint()
	_expect(not view.graph_edit.find_connection_at(edge_midpoint, 12.0).is_empty(), "single visible connection remains interactively hittable")
	view._set_feature_enabled("single_connection", false, false)
	await _settle()
	_expect(view.graph_edit.connection_lines_thickness == 3.5, "single-connection disable restores the native line layer")
	view._set_feature_enabled("single_connection", true, false)

	view._set_feature_enabled("compact", true, false)
	await _settle()
	var compact := await _capture_case("02_compact")
	_assert_image_valid(compact, "compact mode renders")
	_expect(_graph_node(view, 2).size.x < 230.0 and _graph_node(view, 2).size.y < 150.0 and not _graph_node(view, 2).description_label.visible, "compact screenshot uses genuinely reduced cards")
	_expect(_overlapping_node_pairs().is_empty(), "compact mode keeps cards separated")
	view._set_feature_enabled("compact", false, false)

	view.current_tree = _make_dense_zoom_tree()
	view.current_tree_path = "res://behavior_trees/dense_zoom_visual_tree.tres"
	view._rebuild_graph()
	view._set_feature_enabled("semantic_zoom", true, false)
	view._set_feature_enabled("auto_spacing", true, false)
	view.semantic_detail_level = 0
	view._apply_semantic_detail_level()
	view._update_auto_spacing(0.0, true)
	await _settle()
	var dense_overview := await _capture_case("02b_dense_overview")
	_assert_image_valid(dense_overview, "dense semantic overview renders")
	_expect(_all_visual_offsets_zero() and _overlapping_node_pairs().is_empty(), "dense overview retains readable compact logical positions")
	var dense_positions := _resource_positions(view.current_tree)
	view._set_feature_enabled("auto_spacing", false, false)
	view.semantic_detail_level = 2
	view._apply_semantic_detail_level()
	await _settle()
	var overlap_before := _overlapping_node_pairs().size()
	var dense_detail_overlap := await _capture_case("02c_dense_detail_overlap")
	_assert_image_valid(dense_detail_overlap, "dense detail overlap baseline renders")
	_expect(overlap_before > 0, "dense detail baseline reproduces expansion overlap")
	view._set_feature_enabled("auto_spacing", true, false)
	view._update_auto_spacing(0.0, true)
	await _settle()
	var dense_detail := await _capture_case("02d_dense_detail_auto_spacing")
	_assert_image_valid(dense_detail, "dense detail auto-spacing renders")
	var overlap_after := _overlapping_node_pairs().size()
	print("VISUAL_METRIC auto_spacing_overlap_before=%d auto_spacing_overlap_after=%d" % [overlap_before, overlap_after])
	_expect(overlap_after == 0, "dense detail auto-spacing removes visible overlap")
	_expect(_all_visual_offsets_nonnegative_y(), "dense detail auto-spacing never pulls lower nodes upward")
	_expect(_all_parent_child_gaps_at_least(view.AUTO_SPACING_CONNECTION_GAP), "dense detail auto-spacing preserves clear connection channels")
	_expect(_connection_node_intersections().is_empty(), "dense detail connections remain visible outside unrelated cards")
	_expect(_resource_positions_equal(view.current_tree, dense_positions), "dense detail auto-spacing preserves resource coordinates")
	view.semantic_detail_level = 0
	view._apply_semantic_detail_level()
	view._update_auto_spacing(0.0, true)
	await _settle()
	var dense_restored := await _capture_case("02e_dense_overview_restored")
	_assert_image_valid(dense_restored, "dense overview restoration renders")
	_expect(_overlapping_node_pairs().is_empty() and _resource_positions_equal(view.current_tree, dense_positions), "zooming out keeps the dense tree overlap-free without changing logical positions")
	view._set_feature_enabled("auto_spacing", false, false)
	view._set_feature_enabled("semantic_zoom", false, false)
	view.current_tree = _make_visual_tree()
	view.current_tree_path = "res://behavior_trees/visual_regression_tree.tres"
	view._rebuild_graph()
	_restore_overview()
	await _settle()

	view._set_feature_enabled("fisheye", true, false)
	var focused := _graph_node(view, 3)
	var fisheye_positions := _resource_positions(view.current_tree)
	var expected_focused_center := focused.position_offset + focused.size * 0.5
	var focused_local_point := (focused.position_offset + focused.size * 0.5) * view.graph_edit.zoom - view.graph_edit.scroll_offset
	var focused_pointer := view.graph_edit.get_global_transform_with_canvas() * focused_local_point
	_expect(view._fisheye_node_at(focused_pointer) == focused, "fisheye visual fixture resolves the node directly under the pointer")
	view._apply_fisheye_focus(focused, 1.0)
	view._update_auto_spacing(0.0, true)
	await _settle()
	var fisheye := await _capture_case("03_fisheye")
	_assert_image_valid(fisheye, "fisheye focus renders")
	_expect(_count_magnified_nodes() == 1 and _graph_node(view, 3).fisheye_magnification >= 1.24, "fisheye screenshot magnifies only the focused node")
	_expect((_graph_node(view, 3).position_offset + _graph_node(view, 3).size * 0.5).distance_to(expected_focused_center) < 6.0, "fisheye keeps the focused card centered while resizing")
	_expect(_all_unfocused_nodes_shrunk(3), "fisheye screenshot shrinks every surrounding node")
	_expect(_overlapping_node_pairs().is_empty(), "fisheye focus-and-context layout does not overlap cards")
	_expect(_rendered_tree_order_is_valid() and _resource_positions_equal(view.current_tree, fisheye_positions), "fisheye preserves topology and saved positions")
	view._set_feature_enabled("fisheye", false, false)
	await _settle()
	var recovered := await _capture_case("04_fisheye_disabled")
	_assert_image_valid(recovered, "fisheye disable recovery renders")
	_expect(_all_node_transforms_reset(), "fisheye disable leaves no transformed nodes")

	view._set_feature_enabled("subtree_collapse", true, false)
	view.current_tree.find_node(3).collapsed = true
	view._rebuild_graph()
	await _settle()
	var collapsed := await _capture_case("05_collapsed")
	_assert_image_valid(collapsed, "collapsed subtree renders")
	_expect(_graph_node(view, 4) == null and "Collapsed:" in _graph_node(view, 3).collapsed_summary_label.text, "collapsed screenshot summarizes hidden descendants")
	view.current_tree.find_node(3).collapsed = false
	view._rebuild_graph()

	view._set_feature_enabled("search", true, false)
	view._on_search_changed("attack")
	view._on_search_submitted("attack")
	await _settle()
	var search := await _capture_case("06_search")
	_assert_image_valid(search, "search highlight renders")
	_expect(_count_near_color(search, Color("22d3ee"), 0.13) > 4, "search screenshot contains current-result highlight")
	view._set_feature_enabled("search", false, false)
	_restore_overview()
	await _settle()

	var failure_snapshot := {
		"actor": "VisualTestNPC", "tree_path": view.current_tree_path,
		"path_ids": [1, 2, 3, 4], "path_titles": ["Root", "Decision", "Combat", "Attack Target"],
		"path_text": "Root > Decision > Combat > Attack Target",
		"leaf_status_text": "FAILURE", "failure_reasons": {4: "Actor method returned FAILURE"},
		"blackboard": {"health": "wrong", "target_in_range": true, "action_timer": 0.25},
		"blackboard_schema_types": {"health": "Int", "target_in_range": "Bool"},
		"blackboard_schema_errors": ["Blackboard key 'health' expected Int, got String."],
	}
	view._set_feature_enabled("active_path", true, false)
	view._set_feature_enabled("branch_dimming", true, false)
	view._set_feature_enabled("failure_reason", true, false)
	view._on_live_debug_toggled(true)
	view._apply_runtime_snapshot(failure_snapshot)
	await _settle()
	var runtime := await _capture_case("07_runtime_failure")
	_assert_image_valid(runtime, "runtime path and failure annotation render")
	_expect(_graph_node(view, 5).modulate.a < 0.3 and _graph_node(view, 4).failure_badge.visible, "runtime screenshot dims inactive branch and shows reason")

	view._on_blackboard_panel_toggled(true)
	await _settle()
	var live_blackboard := await _capture_case("07b_live_blackboard")
	_assert_image_valid(live_blackboard, "Live Blackboard panel renders")
	var blackboard_text := _collect_label_text(view.blackboard_grid)
	_expect(view.blackboard_panel.visible and view.blackboard_grid.get_child_count() == 16, "Live Blackboard screenshot shows all typed rows")
	_expect("ERROR" in blackboard_text and "Dynamic" in blackboard_text and "Bool" in blackboard_text, "Live Blackboard screenshot distinguishes schema states")
	_expect(_count_near_color(live_blackboard, Color("f87171"), 0.14) > 8 and _count_near_color(live_blackboard, Color("86efac"), 0.14) > 1, "Live Blackboard screenshot uses readable error and declared colors")
	view._on_blackboard_panel_toggled(false)

	var schema := BTBlackboardSchema.new()
	schema.allow_dynamic_keys = false
	schema.entries = [
		_schema_entry("health", BTBlackboardEntry.VALUE_TYPE_INT, 100, "Current actor health"),
		_schema_entry("target_visible", BTBlackboardEntry.VALUE_TYPE_BOOL, true, "Perception result"),
		_schema_entry("target_position", BTBlackboardEntry.VALUE_TYPE_VECTOR2, Vector2(10.0, 20.0), "Last known position"),
		_schema_entry("health", BTBlackboardEntry.VALUE_TYPE_FLOAT, 0.0, "Duplicate used to verify validation"),
	]
	view.current_tree.blackboard_schema = schema
	view._on_schema_panel_toggled(true)
	await _settle()
	var schema_editor := await _capture_case("07c_schema_editor")
	_assert_image_valid(schema_editor, "Blackboard Schema authoring panel renders")
	_expect(view.schema_panel.visible and view.schema_row_controls.size() == 4, "Schema screenshot shows every typed declaration")
	_expect("validation error" in view.schema_summary_label.text and "duplicate key" in view.schema_summary_label.tooltip_text, "Schema screenshot exposes concise and complete validation feedback")
	_expect(view.schema_panel.get_rect().end.y <= VIEWPORT_SIZE.y and view.schema_grid.size.x <= view.schema_panel.size.x + 1.0, "Schema authoring stays inside the 1600x900 editor viewport")
	view._on_schema_panel_toggled(false)

	var picker_schema := BTBlackboardSchema.new()
	picker_schema.allow_dynamic_keys = true
	picker_schema.entries = [
		_schema_entry("target_in_range", BTBlackboardEntry.VALUE_TYPE_BOOL, true, "Attack gate"),
		_schema_entry("health", BTBlackboardEntry.VALUE_TYPE_INT, 100, "Current actor health"),
	]
	view.current_tree.blackboard_schema = picker_schema
	view.selected_node_id = 9
	view._refresh_inspector()
	await _settle()
	var schema_picker := await _capture_case("07d_schema_key_picker")
	_assert_image_valid(schema_picker, "Blackboard Schema key picker renders in the Inspector")
	var picker := view.parameter_controls.get("__blackboard_key_picker") as OptionButton
	var key_edit := view.parameter_controls.get("blackboard_key") as LineEdit
	_expect(picker != null and picker.item_count == 3 and key_edit.text == "target_in_range", "Inspector picker lists typed Schema keys and preserves the selected key")
	_expect(view.inspector_panel.get_rect().end.x <= VIEWPORT_SIZE.x and picker.get_global_rect().end.x <= view.inspector_panel.get_global_rect().end.x + 1.0, "Schema key controls stay inside the 1600x900 Inspector")

	view._set_feature_enabled("orthogonal_edges", true, false)
	view._set_feature_enabled("edge_bundling", false, false)
	await _settle()
	var orthogonal := await _capture_case("08_orthogonal_edges")
	_assert_image_valid(orthogonal, "orthogonal edges render")
	_expect(view.graph_edit._get_connection_line(Vector2.ZERO, Vector2(100.0, 100.0)).size() == 4, "orthogonal screenshot uses routed edge geometry")

	view._set_feature_enabled("orthogonal_edges", false, false)
	view._set_feature_enabled("edge_bundling", true, false)
	await _settle()
	var bundled := await _capture_case("09_bundled_edges")
	_assert_image_valid(bundled, "edge bundling renders")
	var bundled_line := view.graph_edit._get_connection_line(Vector2.ZERO, Vector2(100.0, 100.0))
	_expect(bundled_line.size() == 4 and is_equal_approx(bundled_line[1].y, bundled_line[2].y), "bundled screenshot uses shared trunk geometry")

	view._clear_runtime_highlights()
	view._set_feature_enabled("branch_dimming", false, false)
	view._set_feature_enabled("failure_reason", false, false)
	view._set_feature_enabled("edge_bundling", false, false)
	view.current_tree = load("res://behavior_trees/complex_guard_validation_tree.tres") as BTTreeResource
	view.current_tree_path = "res://behavior_trees/complex_guard_validation_tree.tres"
	view.file_path_edit.text = view.current_tree_path
	view.selected_node_id = view.current_tree.root_node_id
	view._refresh_entire_ui()
	var complex_positions := _resource_positions(view.current_tree)
	view._set_feature_enabled("semantic_zoom", true, false)
	view._set_feature_enabled("auto_spacing", true, false)
	view.semantic_detail_level = 0
	view._apply_semantic_detail_level()
	view._update_auto_spacing(0.0, true)
	view._fit_visible_tree()
	await _settle()
	var complex_overview := await _capture_case("10_complex_overview_default")
	_assert_image_valid(complex_overview, "complex 36-node overview-default tree renders")
	_expect(view.current_tree.nodes.size() == 36 and _graph_node_count() == _non_decorator_node_count(), "complex tree renders every graph node")
	var complex_overview_overlap_count := _overlapping_node_pairs().size()
	_expect(complex_overview_overlap_count == 0 and _all_visual_offsets_zero(), "complex tree default coordinates are compact and overlap-free at overview detail")
	var complex_anchor := _graph_node(view, 24)
	var real_zoom_metrics := await _real_wheel_zoom_session(MOUSE_BUTTON_WHEEL_UP, 16, 0.95)
	print("VISUAL_METRIC real_wheel_final_zoom=%.3f detail_level=%d center_relation_drift=%.3f screen_formula_error=%.3f" % [float(real_zoom_metrics.get("final_zoom", 0.0)), view.semantic_detail_level, float(real_zoom_metrics.get("max_relation_drift", INF)), float(real_zoom_metrics.get("max_screen_formula_error", INF))])
	_expect(int(real_zoom_metrics.get("anchor_id", -1)) != -1, "real wheel zoom captures a valid viewport-center neighborhood")
	_expect(bool(real_zoom_metrics.get("sample_set_stable", false)), "real wheel zoom keeps one viewport-center neighborhood snapshot for the complete input burst")
	_expect(float(real_zoom_metrics.get("max_relation_drift", INF)) <= 1.0, "real wheel zoom preserves the viewport center's relative position within nearby nodes")
	_expect(float(real_zoom_metrics.get("max_screen_formula_error", INF)) <= 1.0, "zoom compensation matches GraphEdit's rendered node positions")
	_expect(float(real_zoom_metrics.get("final_zoom", 0.0)) >= 0.95 and view.semantic_detail_level == 2, "real wheel zoom crosses into full-detail semantic layout")
	var complex_detail_overlap_count := _overlapping_node_pairs().size()
	var complex_overlap := await _capture_case("10b_complex_detail_overlap")
	_assert_image_valid(complex_overlap, "complex detail overlap baseline renders")
	_expect(complex_detail_overlap_count == 0, "real wheel zoom applies collision-free detail layout")
	view._update_auto_spacing(0.0, true)
	view._restore_zoom_layout_anchor()
	await _settle()
	view._restore_zoom_layout_anchor()
	var complex_corrected_overlap_count := _overlapping_node_pairs().size()
	var complex_corrected := await _capture_case("10c_complex_detail_auto_spacing")
	_assert_image_valid(complex_corrected, "complex detail auto-spacing renders")
	print("VISUAL_METRIC complex_overview_overlaps=%d complex_detail_overlaps=%d complex_corrected_overlaps=%d" % [complex_overview_overlap_count, complex_detail_overlap_count, complex_corrected_overlap_count])
	_expect(complex_corrected_overlap_count == 0, "complex detail auto-spacing removes every visible overlap")
	print("VISUAL_METRIC complex_zoom_center_relation_drift=%.3f" % float(real_zoom_metrics.get("max_relation_drift", INF)))
	_expect(float(real_zoom_metrics.get("max_relation_drift", INF)) <= 1.0, "complex zoom-in reflow preserves the same center-relative node neighborhood")
	_expect(_all_visual_offsets_nonnegative_y(), "complex detail auto-spacing never lifts lower tree levels")
	var complex_gap_failures := _parent_child_gap_failures(view.AUTO_SPACING_CONNECTION_GAP)
	print("VISUAL_METRIC complex_connection_gap_failures=%s" % str(complex_gap_failures))
	_expect(complex_gap_failures.is_empty(), "complex detail auto-spacing reserves every parent-child connection channel")
	var complex_connection_intersections := _connection_node_intersections()
	print("VISUAL_METRIC complex_connection_intersections=%s" % str(complex_connection_intersections))
	_expect(complex_connection_intersections.is_empty(), "complex detail routes avoid every unrelated node card")
	_expect(_resource_positions_equal(view.current_tree, complex_positions), "complex auto-spacing preserves every saved overview coordinate")
	var real_zoom_out_metrics := await _real_wheel_zoom_session(MOUSE_BUTTON_WHEEL_DOWN, 16, 0.52)
	print("VISUAL_METRIC real_wheel_zoom_out_final=%.3f center_relation_drift=%.3f screen_formula_error=%.3f" % [float(real_zoom_out_metrics.get("final_zoom", 0.0)), float(real_zoom_out_metrics.get("max_relation_drift", INF)), float(real_zoom_out_metrics.get("max_screen_formula_error", INF))])
	_expect(bool(real_zoom_out_metrics.get("sample_set_stable", false)), "real wheel zoom-out keeps one viewport-center neighborhood snapshot")
	_expect(float(real_zoom_out_metrics.get("max_relation_drift", INF)) <= 1.0, "real wheel zoom-out preserves the viewport center's relative position within nearby nodes")
	_expect(float(real_zoom_out_metrics.get("max_screen_formula_error", INF)) <= 1.0 and float(real_zoom_out_metrics.get("final_zoom", INF)) <= 0.52, "real wheel zoom-out matches rendered positions and returns to overview")

	view._set_feature_enabled("auto_spacing", false, false)
	view._set_feature_enabled("compact", true, false)
	view._set_feature_enabled("semantic_zoom", true, false)
	view._set_feature_enabled("minimap", true, false)
	view.current_tree = load("res://behavior_trees/complex_display_tree_241.tres") as BTTreeResource
	view.current_tree_path = "res://behavior_trees/complex_display_tree_241.tres"
	view.file_path_edit.text = view.current_tree_path
	view.selected_node_id = view.current_tree.root_node_id
	view._refresh_entire_ui()
	var playable_positions := _resource_positions(view.current_tree)
	view.semantic_detail_level = 0
	view._apply_semantic_detail_level()
	view._fit_visible_tree()
	await _settle()
	var playable_overview := await _capture_case("11_playable_241_zoomed_out")
	_assert_image_valid(playable_overview, "playable 241-node zoomed-out overview renders")
	_expect(view.current_tree.nodes.size() == 241 and _graph_node_count() == _non_decorator_node_count(), "playable tree renders every one of its 241 runtime nodes")
	_expect(_overlapping_node_pairs().is_empty(), "saved 241-node overview remains overlap-free with Auto Spacing disabled")
	_expect(view.graph_edit.zoom <= 0.35 and view.graph_edit.minimap_enabled, "zoomed-out 241-node screenshot includes the complete minimap context")
	_expect(_resource_positions_equal(view.current_tree, playable_positions), "zooming the 241-node tree preserves every saved coordinate")

	print("BT_VISUAL_TEST_SUMMARY passed=%d failed=%d output=%s" % [passed, failed, OUTPUT_DIR])
	view.free()
	viewport.free()
	quit(0 if failed == 0 else 1)


func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func _capture_case(case_name: String) -> Image:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.force_draw(false, 0.0)
	await process_frame
	var image := viewport.get_texture().get_image()
	var error := image.save_png(OUTPUT_DIR.path_join("%s.png" % case_name))
	_expect(error == OK, "%s screenshot saves" % case_name)
	return image


func _assert_image_valid(image: Image, label: String) -> void:
	var valid_size := image.get_width() == VIEWPORT_SIZE.x and image.get_height() == VIEWPORT_SIZE.y
	var sample := image.duplicate()
	sample.resize(320, 180, Image.INTERPOLATE_NEAREST)
	var colors: Dictionary = {}
	for y in range(sample.get_height()):
		for x in range(sample.get_width()):
			colors[sample.get_pixel(x, y).to_html(false)] = true
	_expect(valid_size and colors.size() >= 20, label)


func _collect_label_text(parent: Node) -> String:
	var values: Array[String] = []
	for child in parent.get_children():
		if child is Label:
			values.append(child.text)
	return " | ".join(values)


func _count_near_color(image: Image, target: Color, tolerance: float) -> int:
	var sample := image.duplicate()
	sample.resize(800, 450, Image.INTERPOLATE_NEAREST)
	var count := 0
	for y in range(sample.get_height()):
		for x in range(sample.get_width()):
			var color: Color = sample.get_pixel(x, y)
			if absf(color.r - target.r) <= tolerance and absf(color.g - target.g) <= tolerance and absf(color.b - target.b) <= tolerance:
				count += 1
	return count


func _to_grayscale(source: Image) -> Image:
	var result := source.duplicate()
	for y in range(result.get_height()):
		for x in range(result.get_width()):
			var color: Color = result.get_pixel(x, y)
			var luminance: float = color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			result.set_pixel(x, y, Color(luminance, luminance, luminance, color.a))
	return result


func _grayscale_contrast_count(source: Image) -> int:
	var sample := source.duplicate()
	sample.resize(800, 450, Image.INTERPOLATE_NEAREST)
	var count := 0
	for y in range(1, sample.get_height()):
		for x in range(1, sample.get_width()):
			var value: float = sample.get_pixel(x, y).r
			if absf(value - sample.get_pixel(x - 1, y).r) > 0.22 or absf(value - sample.get_pixel(x, y - 1).r) > 0.22:
				count += 1
	return count


func _all_type_icons_visible() -> bool:
	for child in view.graph_edit.get_children():
		if child is BTGraphNode and not child.type_icon.visible:
			return false
	return true


func _any_type_icon_visible() -> bool:
	for child in view.graph_edit.get_children():
		if child is BTGraphNode and child.type_icon.visible:
			return true
	return false


func _first_connection_midpoint() -> Vector2:
	var connection: Dictionary = view.graph_edit.get_connection_list()[0]
	var from_node := view.graph_edit.get_node(NodePath(str(connection["from_node"]))) as BTGraphNode
	var to_node := view.graph_edit.get_node(NodePath(str(connection["to_node"]))) as BTGraphNode
	var points := view.graph_edit._route_connection_line(
		from_node.position + Vector2(from_node.size.x * from_node.scale.x * 0.5, from_node.size.y * from_node.scale.y),
		to_node.position + Vector2(to_node.size.x * to_node.scale.x * 0.5, 0.0)
	)
	return points[points.size() / 2]


func _all_node_transforms_reset() -> bool:
	var expected_graph_scale := Vector2.ONE * view.graph_edit.zoom
	for child in view.graph_edit.get_children():
		if child is BTGraphNode and (not is_equal_approx(child.fisheye_magnification, 1.0) or not child.scale.is_equal_approx(expected_graph_scale) or not child.pivot_offset.is_zero_approx() or child.z_index != 0):
			return false
	return true


func _count_magnified_nodes() -> int:
	var count := 0
	for child in view.graph_edit.get_children():
		if child is BTGraphNode and child.fisheye_magnification > 1.001:
			count += 1
	return count


func _all_unfocused_nodes_shrunk(focused_id: int) -> bool:
	for child in view.graph_edit.get_children():
		if child is BTGraphNode and child.node_resource.id != focused_id and child.fisheye_magnification > view.FISHEYE_CONTEXT_SCALE + 0.01:
			return false
	return true


func _rendered_tree_order_is_valid() -> bool:
	for node in view.current_tree.nodes:
		if node == null or node.decorator_parent_id != -1:
			continue
		var children := view.current_tree.get_children_of(node.id)
		var previous_x := -INF
		for child_node in children:
			var rendered := _graph_node(view, child_node.id)
			if rendered == null or rendered.position_offset.x < previous_x:
				return false
			if _graph_node(view, node.id).position_offset.y >= rendered.position_offset.y:
				return false
			previous_x = rendered.position_offset.x
	return true


func _restore_overview() -> void:
	view.graph_edit.zoom = 0.52
	view.graph_edit.scroll_offset = Vector2(-100.0, 35.0)


func _overlapping_node_pairs() -> Array[String]:
	var nodes: Array[BTGraphNode] = []
	for child in view.graph_edit.get_children():
		if child is BTGraphNode:
			nodes.append(child)
	var overlaps: Array[String] = []
	for left_index in range(nodes.size()):
		for right_index in range(left_index + 1, nodes.size()):
			var left_rect := Rect2(nodes[left_index].position_offset, nodes[left_index].size).grow(-2.0)
			var right_rect := Rect2(nodes[right_index].position_offset, nodes[right_index].size).grow(-2.0)
			if left_rect.intersects(right_rect):
				overlaps.append("%s:%s" % [nodes[left_index].name, nodes[right_index].name])
	return overlaps


func _graph_node_count() -> int:
	var count := 0
	for child in view.graph_edit.get_children():
		if child is BTGraphNode:
			count += 1
	return count


func _non_decorator_node_count() -> int:
	var count := 0
	for node in view.current_tree.nodes:
		if node != null and node.decorator_parent_id == -1:
			count += 1
	return count


func _all_parent_child_gaps_at_least(minimum_gap: float) -> bool:
	return _parent_child_gap_failures(minimum_gap).is_empty()


func _parent_child_gap_failures(minimum_gap: float) -> Array[String]:
	var failures: Array[String] = []
	for node in view.current_tree.nodes:
		if node == null or node.parent_id == -1 or node.decorator_parent_id != -1:
			continue
		var parent := _graph_node(view, node.parent_id)
		var child := _graph_node(view, node.id)
		if parent != null and child != null:
			var gap := child.position_offset.y - (parent.position_offset.y + parent.size.y)
			if gap < minimum_gap:
				failures.append("%d>%d:%.1f" % [node.parent_id, node.id, gap])
	return failures


func _make_visual_tree() -> BTTreeResource:
	var tree := BTTreeResource.new()
	tree.tree_name = "Visual Regression Tree"
	tree.root_node_id = 1
	var root_node := _node(1, BTNodeResource.TYPE_ROOT, -1, "Root", 620.0, 30.0)
	var selector := _node(2, BTNodeResource.TYPE_SELECTOR, 1, "Decision", 620.0, 330.0)
	var sequence := _node(3, BTNodeResource.TYPE_RANDOM_SELECTOR, 2, "Random Combat", 230.0, 640.0)
	sequence.parameters = {"seed": 42}
	var attack := _node(4, BTNodeResource.TYPE_ACTION, 3, "Attack Target", 40.0, 970.0)
	attack.parameters = {"action_name": "attack_target", "damage": 10}
	var chase := _node(5, BTNodeResource.TYPE_ACTION, 3, "Chase Target", 410.0, 970.0)
	chase.parameters = {"action_name": "chase_target", "speed": 120}
	var patrol := _node(6, BTNodeResource.TYPE_PARALLEL, 2, "Parallel Senses", 1010.0, 640.0)
	patrol.parameters = {"success_policy": "all", "failure_policy": "any"}
	var left := _node(7, BTNodeResource.TYPE_REPEAT, 6, "Repeat Scan", 840.0, 970.0)
	left.parameters = {"repeat_count": 3}
	var right := _node(8, BTNodeResource.TYPE_WAIT, 6, "Wait 1 Second", 1210.0, 970.0)
	right.parameters = {"duration": 1.0}
	var decorator := _node(9, BTNodeResource.TYPE_DECORATOR, -1, "Can Attack", 0.0, 0.0)
	decorator.decorator_parent_id = 4
	decorator.parameters = {"mode": "blackboard", "blackboard_key": "target_in_range", "operator": "equals", "value": true}
	tree.nodes = [root_node, selector, sequence, attack, chase, patrol, left, right, decorator]
	return tree


func _make_dense_zoom_tree() -> BTTreeResource:
	var tree := BTTreeResource.new()
	tree.tree_name = "Dense Zoom Visual Tree"
	tree.root_node_id = 1
	tree.nodes = [
		_node(1, BTNodeResource.TYPE_ROOT, -1, "Dense Root", 640.0, 190.0),
		_node(2, BTNodeResource.TYPE_ACTION, 1, "Dense Left", 500.0, 355.0),
		_node(3, BTNodeResource.TYPE_ACTION, 1, "Dense Right", 780.0, 355.0),
	]
	return tree


func _resource_positions(tree: BTTreeResource) -> Dictionary:
	var positions := {}
	for node in tree.nodes:
		if node != null:
			positions[node.id] = node.position
	return positions


func _resource_positions_equal(tree: BTTreeResource, expected: Dictionary) -> bool:
	for node in tree.nodes:
		if node != null and not node.position.is_equal_approx(expected.get(node.id, Vector2.INF)):
			return false
	return true


func _all_visual_offsets_zero() -> bool:
	for child in view.graph_edit.get_children():
		if child is BTGraphNode and not child.visual_offset.is_zero_approx():
			return false
	return true


func _all_visual_offsets_nonnegative_y() -> bool:
	for child in view.graph_edit.get_children():
		if child is BTGraphNode and child.visual_offset.y < -0.01:
			return false
	return true


func _connection_node_intersections() -> Array[String]:
	var failures: Array[String] = []
	for connection in view.graph_edit.get_connection_list():
		var from_id := int(str(connection.get("from_node", "-1")))
		var to_id := int(str(connection.get("to_node", "-1")))
		var from_node := _graph_node(view, from_id)
		var to_node := _graph_node(view, to_id)
		if from_node == null or to_node == null:
			continue
		var points := view.graph_edit._route_connection_line(
			view.graph_edit._output_port_position(from_node),
			view.graph_edit._input_port_position(to_node)
		)
		for graph_child in view.graph_edit.get_children():
			if not (graph_child is BTGraphNode) or graph_child == from_node or graph_child == to_node:
				continue
			var obstacle := Rect2(graph_child.position, graph_child.size * graph_child.scale).grow(-4.0)
			if _polyline_enters_rect(points, obstacle):
				failures.append("%d>%d through %s" % [from_id, to_id, graph_child.name])
	return failures


func _polyline_enters_rect(points: PackedVector2Array, rect: Rect2) -> bool:
	for index in range(points.size() - 1):
		var start := points[index]
		var finish := points[index + 1]
		var steps := maxi(1, ceili(start.distance_to(finish) / 4.0))
		for step in range(steps + 1):
			if rect.has_point(start.lerp(finish, float(step) / float(steps))):
				return true
	return false


func _render_positions_match_resources() -> bool:
	for child in view.graph_edit.get_children():
		if child is BTGraphNode and not child.position_offset.is_equal_approx(child.node_resource.position):
			return false
	return true


func _test_real_pointer_connection() -> void:
	var target := _node(10, BTNodeResource.TYPE_CONDITION, -1, "Pointer Connection Target", 1450.0, 640.0)
	view.current_tree.nodes.append(target)
	view._rebuild_graph()
	await _settle()
	var source_graph_node := _graph_node(view, 6)
	var target_graph_node := _graph_node(view, 10)
	var source_local := view.graph_edit._output_port_position(source_graph_node)
	var target_local := view.graph_edit._input_port_position(target_graph_node)
	var source_viewport := view.graph_edit.get_global_transform_with_canvas() * source_local
	var target_viewport := view.graph_edit.get_global_transform_with_canvas() * target_local

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	press.position = source_viewport
	viewport.push_input(press, false)
	await process_frame

	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = target_viewport
	motion.relative = target_viewport - source_viewport
	viewport.push_input(motion, false)
	await process_frame

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = target_viewport
	viewport.push_input(release, false)
	await process_frame
	_expect(target.parent_id == 6 and not view.graph_edit.manual_connection_active, "real pointer drag connects a bottom square to a top square")

	view.current_tree.nodes.erase(target)
	view._rebuild_graph()
	await _settle()


func _real_wheel_zoom_session(wheel_button: MouseButton, maximum_wheel_steps: int, target_zoom: float) -> Dictionary:
	var viewport_position := view.graph_edit.get_global_transform_with_canvas() * (view.graph_edit.size * 0.5)
	var max_relation_drift := 0.0
	var max_screen_formula_error := 0.0
	var session_anchor_id := -1
	var session_sample_ids: Array[int] = []
	var recorded_relation := Vector2.ZERO
	var sample_set_stable := true
	for _step in range(maximum_wheel_steps):
		var wheel := InputEventMouseButton.new()
		wheel.button_index = wheel_button
		wheel.pressed = true
		wheel.position = viewport_position
		viewport.push_input(wheel, false)
		await process_frame
		view._process(1.0 / 60.0)
		await process_frame
		if view.zoom_layout_anchor_id != -1:
			session_anchor_id = view.zoom_layout_anchor_id if session_anchor_id == -1 else session_anchor_id
			if view.zoom_layout_anchor_id != session_anchor_id:
				sample_set_stable = false
			if session_sample_ids.is_empty():
				session_sample_ids = _zoom_sample_ids(view.zoom_layout_anchor_samples)
				recorded_relation = _weighted_zoom_sample_relation(view.zoom_layout_anchor_samples, true)
			elif session_sample_ids != _zoom_sample_ids(view.zoom_layout_anchor_samples):
				sample_set_stable = false
			max_relation_drift = maxf(max_relation_drift, _weighted_zoom_sample_relation(view.zoom_layout_anchor_samples, false).distance_to(recorded_relation))
		max_screen_formula_error = maxf(max_screen_formula_error, _maximum_screen_formula_error())
		if (wheel_button == MOUSE_BUTTON_WHEEL_UP and view.graph_edit.zoom >= target_zoom) or (wheel_button == MOUSE_BUTTON_WHEEL_DOWN and view.graph_edit.zoom <= target_zoom):
			break
	# Continue through fisheye resume and auto-spacing animation settling.
	for _frame in range(50):
		view._process(1.0 / 60.0)
		await process_frame
		if view.zoom_layout_anchor_id != -1:
			if session_sample_ids != _zoom_sample_ids(view.zoom_layout_anchor_samples):
				sample_set_stable = false
			max_relation_drift = maxf(max_relation_drift, _weighted_zoom_sample_relation(view.zoom_layout_anchor_samples, false).distance_to(recorded_relation))
		max_screen_formula_error = maxf(max_screen_formula_error, _maximum_screen_formula_error())
	return {"anchor_id": session_anchor_id, "sample_set_stable": sample_set_stable, "max_relation_drift": max_relation_drift, "max_screen_formula_error": max_screen_formula_error, "final_zoom": view.graph_edit.zoom}


func _zoom_sample_ids(samples: Array) -> Array[int]:
	var ids: Array[int] = []
	for sample in samples:
		ids.append(int(sample.get("id", -1)))
	return ids


func _weighted_zoom_sample_relation(samples: Array, use_recorded_relative: bool) -> Vector2:
	var weighted_relation := Vector2.ZERO
	var total_weight := 0.0
	var view_center := view._graph_view_center_tree_position()
	for sample in samples:
		var weight := maxf(float(sample.get("weight", 1.0)), 0.001)
		var relative := Vector2(sample.get("relative", Vector2.ZERO))
		if not use_recorded_relative:
			var graph_node := _graph_node(view, int(sample.get("id", -1)))
			if graph_node == null:
				continue
			relative = graph_node.position_offset + graph_node.size * 0.5 - view_center
		weighted_relation += relative * weight
		total_weight += weight
	return weighted_relation / total_weight if total_weight > 0.0 else Vector2.INF


func _maximum_screen_formula_error() -> float:
	var maximum_error := 0.0
	for child in view.graph_edit.get_children():
		if child is BTGraphNode:
			var graph_node: BTGraphNode = child
			var rendered_center: Vector2 = graph_node.position + graph_node.size * graph_node.scale * 0.5
			maximum_error = maxf(maximum_error, rendered_center.distance_to(view._graph_node_screen_center(graph_node)))
	return maximum_error


func _node(id: int, type_name: String, parent_id: int, title: String, x: float, y: float) -> BTNodeResource:
	var node := BTNodeResource.new()
	node.id = id
	node.node_type = type_name
	node.parent_id = parent_id
	node.title = title
	node.description = "Visual description for %s" % title
	node.position = Vector2(x, y)
	return node


func _schema_entry(key: String, value_type: String, default_value: Variant, description: String) -> BTBlackboardEntry:
	var entry := BTBlackboardEntry.new()
	entry.key = key
	entry.value_type = value_type
	entry.default_value = default_value
	entry.description = description
	return entry


func _graph_node(editor: BTEditorView, id: int) -> BTGraphNode:
	return editor.graph_edit.get_node_or_null(NodePath(str(id))) as BTGraphNode


func _expect(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		printerr("FAIL: %s" % label)
