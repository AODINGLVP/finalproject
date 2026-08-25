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
	if OS.get_cmdline_user_args().has("density-transition-quick"):
		await _test_drag_across_display_density_change(view)
		print("BT_ZOOM_DENSITY_QUICK_SUMMARY passed=%d failed=%d" % [passed, failed])
		view.free()
		quit(0 if failed == 0 else 1)
		return
	if OS.get_cmdline_user_args().has("drag-rules-quick"):
		await _test_drag_reflow_deadzone(view)
		await _test_conditional_parent_child_clearance(view)
		await _test_playable_tree_max_zoom_quick(view)
		print("BT_ZOOM_DRAG_LAYOUT_QUICK_SUMMARY passed=%d failed=%d" % [passed, failed])
		view.free()
		quit(0 if failed == 0 else 1)
		return
	await _test_freeform_layout_is_untouched(view)
	await _test_drag_reflow_deadzone(view)
	await _test_conditional_parent_child_clearance(view)
	await _test_local_drag_avoidance(view)
	await _test_parent_child_drag_hierarchy(view)
	await _test_complete_zoom_range(view)
	await _test_playable_tree_zoom_sweep(view)
	await _test_saved_arena_hierarchy_zoom_sweep(view)
	await _test_live_drag_avoidance(view)
	await _test_drag_across_display_density_change(view)
	await _test_wheel_anchor_disabled_during_drag(view)
	await _test_drag_previously_displaced_card(view)
	await _test_large_live_drag_latency(view)
	await _test_complex_tree_scales(view)
	await _test_complex_tree_drag_locality(view)
	await _test_large_local_solver_latency(view)
	await _test_zero_coordinate_recovery(view)
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


func _test_freeform_layout_is_untouched(view: BTEditorView) -> void:
	var zoom_values: Array[float] = [
		view.graph_edit.zoom_min,
		0.50,
		0.619,
		0.620,
		0.621,
		0.879,
		0.880,
		0.881,
		1.0,
		view.graph_edit.zoom_max,
	]
	for semantic_zoom in [false, true]:
		for compact_cards in [false, true]:
			for requested_zoom in zoom_values:
				var zoom_value := clampf(requested_zoom, view.graph_edit.zoom_min, view.graph_edit.zoom_max)
				var tree := _make_freeform_tree()
				var resource_positions := _resource_positions(tree)
				var order_before := _execution_order_signature(tree)
				var label := "freeform zoom %.3f semantic=%s compact=%s" % [zoom_value, semantic_zoom, compact_cards]
				await _prepare_view(view, tree, zoom_value, semantic_zoom, compact_cards)
				_expect(_render_positions_match_expected(view, resource_positions), "%s leaves every non-overlapping card exactly where the user placed it" % label)
				_expect(_all_visual_offsets_zero(view), "%s does not apply hidden layout offsets to a freeform arrangement" % label)
				_expect(_rendered_overlaps(view).is_empty() and _screen_overlaps(view).is_empty(), "%s remains overlap-free without forced topology formatting" % label)
				_expect(_execution_order_signature(tree) == order_before, "%s preserves freeform left-to-right execution order" % label)


func _test_drag_reflow_deadzone(view: BTEditorView) -> void:
	# Fisheye used to reset on pointer-down, which made a selection click resize
	# every card and repeatedly invalidate layout. A click must now be inert.
	var fisheye_tree := await _prepare_deadzone_fixture(view, 1.0)
	view._set_feature_enabled("fisheye", true, false)
	var fisheye_source := _graph_node(view, 4)
	var fisheye_context := _graph_node(view, 5)
	view._apply_fisheye_focus(fisheye_source, 1.0)
	var focused_scale := fisheye_source.fisheye_magnification
	var context_scale := fisheye_context.fisheye_magnification
	var fisheye_positions := _render_positions(view)
	var fisheye_resources := _resource_positions(fisheye_tree)
	var fisheye_undo_count := view.undo_stack.size()
	var fisheye_click := _begin_graph_node_drag(view, 4)
	_expect(not fisheye_click.is_empty() and not view.drag_auto_spacing_active, "selection click arms dragging without activating reflow")
	_expect(is_equal_approx(fisheye_source.fisheye_magnification, focused_scale) and is_equal_approx(fisheye_context.fisheye_magnification, context_scale), "selection click leaves Fisheye card sizes unchanged")
	_end_graph_node_drag(fisheye_click)
	_expect(_render_positions_equal(view, fisheye_positions) and _resource_positions_equal(fisheye_tree, fisheye_resources) and view.undo_stack.size() == fisheye_undo_count, "selection click changes no layout, resource position, or history")
	view._set_feature_enabled("fisheye", false, false)
	view._reset_fisheye()

	for requested_zoom in [view.graph_edit.zoom_min, 1.0, view.graph_edit.zoom_max]:
		var zoom_value := clampf(float(requested_zoom), view.graph_edit.zoom_min, view.graph_edit.zoom_max)
		var tree := await _prepare_deadzone_fixture(view, zoom_value)
		var source := _graph_node(view, 4)
		var start_position := source.position_offset
		if is_equal_approx(zoom_value, 1.0):
			# A click must preserve a card that is already temporarily displaced by
			# Auto Spacing; this catches layout notifications while the button is held.
			source.set_visual_offset(Vector2(18.0, -7.0))
			view.auto_spacing_targets[4] = source.visual_offset
			view.auto_spacing_signature = view._auto_spacing_layout_signature()
			start_position = source.position_offset
		var positions_before := _render_positions(view)
		var resources_before := _resource_positions(tree)
		var targets_before := view.auto_spacing_targets.duplicate(true)
		var undo_count_before := view.undo_stack.size()
		var click_state := _begin_graph_node_drag(view, 4)
		await _wait_frames(2)
		_expect(not view.drag_auto_spacing_active and _render_positions_equal(view, positions_before) and _vector_dictionaries_equal(view.auto_spacing_targets, targets_before), "click at zoom %.3f performs no layout solve while held" % zoom_value)
		_end_graph_node_drag(click_state)
		await _wait_frames(2)
		_expect(_render_positions_equal(view, positions_before) and _resource_positions_equal(tree, resources_before) and view.undo_stack.size() == undo_count_before, "click at zoom %.3f performs no delayed release-time reflow" % zoom_value)

		var other_resource_positions := _resource_positions_except(tree, 4)
		var small_drag_positions := _render_positions(view)
		var small_drag := _begin_graph_node_drag(view, 4)
		var small_screen_distance := view.DRAG_REFLOW_ACTIVATION_SCREEN_DISTANCE - 1.0
		var small_target := start_position + Vector2.RIGHT * (small_screen_distance / zoom_value)
		_move_graph_node_drag(view, small_drag, start_position.lerp(small_target, 0.5))
		await process_frame
		_move_graph_node_drag(view, small_drag, small_target)
		await process_frame
		_expect(not view.drag_auto_spacing_active, "%.1f-screen-pixel drag stays inside the reflow deadzone at zoom %.3f" % [small_screen_distance, zoom_value])
		_expect(_render_positions_for_ids_equal(view, small_drag_positions, [1, 2, 3, 5, 6]), "sub-threshold drag at zoom %.3f moves no neighbouring card" % zoom_value)
		_expect(_resource_positions_equal(tree, resources_before), "sub-threshold drag at zoom %.3f defers its only resource write until release" % zoom_value)
		_end_graph_node_drag(small_drag)
		await _wait_frames(3)
		_expect(tree.find_node(4).position.distance_to(small_target) <= POSITION_EPSILON, "sub-threshold drag at zoom %.3f stores the user's exact small correction" % zoom_value)
		_expect(_resource_positions_except_equal(tree, 4, other_resource_positions) and _render_positions_for_ids_equal(view, small_drag_positions, [1, 2, 3, 5, 6]), "sub-threshold release at zoom %.3f still moves no neighbour" % zoom_value)
		if is_equal_approx(zoom_value, view.graph_edit.zoom_min):
			_expect(_rendered_overlaps(view).has("4-5"), "small drag may retain a minor visible overlap instead of forcing reflow")

		tree = await _prepare_deadzone_fixture(view, zoom_value)
		source = _graph_node(view, 4)
		start_position = source.position_offset
		var structure_before := _structure_signature(tree)
		var order_before := _execution_order_signature(tree)
		var active_drag := _begin_graph_node_drag(view, 4)
		var activation_target := start_position + Vector2.RIGHT * ((view.DRAG_REFLOW_ACTIVATION_SCREEN_DISTANCE + 1.0) / zoom_value)
		_move_graph_node_drag(view, active_drag, activation_target)
		await process_frame
		_expect(view.drag_auto_spacing_active, "drag beyond the screen-space deadzone activates live avoidance at zoom %.3f" % zoom_value)
		var first_refresh_position := view.drag_auto_spacing_last_refresh_position
		var substep_target := activation_target + Vector2.RIGHT * ((view.DRAG_REFLOW_REFRESH_SCREEN_DISTANCE * 0.5) / zoom_value)
		_move_graph_node_drag(view, active_drag, substep_target)
		await process_frame
		_expect(view.drag_auto_spacing_last_refresh_position.is_equal_approx(first_refresh_position), "active drag coalesces movement smaller than the refresh step at zoom %.3f" % zoom_value)
		var refresh_target := activation_target + Vector2.RIGHT * ((view.DRAG_REFLOW_REFRESH_SCREEN_DISTANCE + 1.0) / zoom_value)
		_move_graph_node_drag(view, active_drag, refresh_target)
		await process_frame
		_expect(view.drag_auto_spacing_last_refresh_position.is_equal_approx(refresh_target), "active drag refreshes after the next screen-space movement step at zoom %.3f" % zoom_value)
		var returned_target := start_position + Vector2.RIGHT * ((view.DRAG_REFLOW_ACTIVATION_SCREEN_DISTANCE * 0.5) / zoom_value)
		_move_graph_node_drag(view, active_drag, returned_target)
		await process_frame
		_expect(view.drag_auto_spacing_active, "reflow activation remains latched when the pointer returns inside the deadzone")
		_end_graph_node_drag(active_drag)
		await _wait_frames(3)
		_expect(_structure_signature(tree) == structure_before and _execution_order_signature(tree) == order_before, "deadzone and stepped reflow preserve tree semantics at zoom %.3f" % zoom_value)

	# Real mice can emit several motion events before the deferred solve runs. A
	# small second event must not acknowledge and cancel the first queued reflow.
	var burst_tree := await _prepare_deadzone_fixture(view, 1.0)
	var burst_source := _graph_node(view, 4)
	var burst_context := _graph_node(view, 5)
	var burst_start := burst_source.position_offset
	var burst_context_start := burst_context.position_offset
	var burst_drag := _begin_graph_node_drag(view, 4)
	_move_graph_node_drag(view, burst_drag, burst_start + Vector2.RIGHT * 11.0)
	_move_graph_node_drag(view, burst_drag, burst_start + Vector2.RIGHT * 15.0)
	_expect(view.live_auto_spacing_refresh_pending and view.auto_spacing_signature.is_empty(), "same-frame sub-step keeps the earlier live reflow queued")
	await process_frame
	_expect(not view.live_auto_spacing_refresh_pending and not view.auto_spacing_signature.is_empty(), "same-frame motion burst completes its queued reflow")
	_expect(burst_context.position_offset.distance_to(burst_context_start) > POSITION_EPSILON, "same-frame motion burst moves the newly colliding neighbour")
	_end_graph_node_drag(burst_drag)
	await _wait_frames(2)
	_expect(burst_tree.validate_tree().is_empty(), "same-frame motion burst preserves the behavior tree")

	# Count each movement segment at the zoom where it occurred. Merely changing
	# zoom while holding a card must not reinterpret earlier movement.
	await _prepare_deadzone_fixture(view, 1.0)
	var zoom_source := _graph_node(view, 4)
	var zoom_start := zoom_source.position_offset
	var zoom_drag := _begin_graph_node_drag(view, 4)
	_move_graph_node_drag(view, zoom_drag, zoom_start + Vector2.RIGHT * 6.0)
	await process_frame
	view.graph_edit.zoom = 2.0
	_move_graph_node_drag(view, zoom_drag, zoom_start + Vector2.RIGHT * 7.5)
	await process_frame
	_expect(not view.drag_auto_spacing_active, "dragging through a zoom change remains below the accumulated 10-screen-pixel threshold")
	_move_graph_node_drag(view, zoom_drag, zoom_start + Vector2.RIGHT * 8.1)
	await process_frame
	_expect(view.drag_auto_spacing_active, "post-zoom movement activates reflow only after the accumulated screen distance crosses the threshold")
	_end_graph_node_drag(zoom_drag)
	await _wait_frames(2)


func _test_conditional_parent_child_clearance(view: BTEditorView) -> void:
	for originally_layered in [true, false]:
		var tree := _make_conditional_hierarchy_tree()
		await _prepare_view(view, tree, 1.0, false, false)
		var parent := _graph_node(view, 2)
		var authored_gap := 4.0 if originally_layered else -4.0
		if originally_layered:
			tree.find_node(3).position = Vector2(
				parent.node_resource.position.x + 900.0,
				parent.node_resource.position.y + BTGraphNode.NORMAL_CARD_SIZE.y + authored_gap
			)
		else:
			# This pair really overlaps in both axes, but its shortest escape route is
			# horizontal. Avoidance must not turn it into a vertical tree rank.
			tree.find_node(3).position = Vector2(
				parent.node_resource.position.x + BTGraphNode.NORMAL_CARD_SIZE.x - 30.0,
				parent.node_resource.position.y + 20.0
			)
		var resource_positions := _resource_positions(tree)
		view._rebuild_graph()
		await _wait_frames(3)
		parent = _graph_node(view, 2)
		var child := _graph_node(view, 3)
		var child_position_before_expansion := child.position_offset
		var saved_gap := view._saved_parent_child_vertical_gap(parent, child)
		parent.set_fisheye_magnification(1.25)
		await _wait_frames(2)
		view.auto_spacing_signature = ""
		view._update_auto_spacing(0.0, true)
		await _wait_frames(2)
		var rendered_gap := child.position_offset.y - (parent.position_offset.y + parent.size.y)
		if originally_layered:
			_expect(saved_gap >= 0.0 and rendered_gap + POSITION_EPSILON >= 0.0, "card expansion preserves an authored parent-bottom-above-child-top relationship")
		else:
			_expect(saved_gap < 0.0 and absf(child.position_offset.y - child_position_before_expansion.y) <= POSITION_EPSILON, "freeform parent-child collision resolves without imposing a vertical hierarchy")
			_expect(rendered_gap < 0.0 and not _rendered_overlaps(view).has("2-3"), "originally overlapping parent-child cards separate horizontally and keep their freeform vertical relationship")
		_expect(_resource_positions_equal(tree, resource_positions), "conditional hierarchy protection changes no saved node position")


func _test_local_drag_avoidance(view: BTEditorView) -> void:
	var cases: Array[Array] = [
		[view.graph_edit.zoom_min, false, false],
		[0.50, true, false],
		[0.619, true, false],
		[0.620, true, false],
		[0.621, true, false],
		[0.879, true, false],
		[0.880, true, false],
		[0.881, true, false],
		[1.0, true, false],
		[view.graph_edit.zoom_max, false, true],
	]
	for case in cases:
		var zoom_value := clampf(float(case[0]), view.graph_edit.zoom_min, view.graph_edit.zoom_max)
		var semantic_zoom := bool(case[1])
		var compact_cards := bool(case[2])
		var tree := _make_local_avoidance_tree()
		var structure_before := _structure_signature(tree)
		var order_before := _execution_order_signature(tree)
		var other_resource_positions := _resource_positions_except(tree, 4)
		var label := "local avoidance zoom %.3f semantic=%s compact=%s" % [zoom_value, semantic_zoom, compact_cards]
		await _prepare_view(view, tree, zoom_value, semantic_zoom, compact_cards)
		var initial_render_positions := _render_positions(view)

		var free_target := Vector2(200.0, 550.0)
		var free_drag := _drag_graph_node_to(view, 4, free_target)
		await _wait_frames(SETTLE_FRAMES)
		_expect(bool(free_drag.get("started", false)), "%s starts a free-position drag" % label)
		_expect(_graph_node(view, 4).position_offset.distance_to(free_target) <= POSITION_EPSILON, "%s keeps an unobstructed node at the exact release point" % label)
		_expect(_render_positions_for_ids_equal(view, initial_render_positions, [1, 2, 3, 5, 6, 7]), "%s does not move any other rendered card for an unobstructed drag" % label)

		var before_collision_positions := _render_positions(view)
		var collision_target := Vector2(330.0, 550.0)
		var collision_drag := _drag_graph_node_to(view, 4, collision_target)
		await _wait_frames(SETTLE_FRAMES)
		var after_collision_positions := _render_positions(view)
		var moved_ids := _moved_render_ids(before_collision_positions, after_collision_positions)
		_expect(bool(collision_drag.get("started", false)), "%s starts a collision-producing drag" % label)
		_expect(tree.find_node(4).position.distance_to(collision_target) <= POSITION_EPSILON, "%s stores the exact logical release point" % label)
		_expect(_graph_node(view, 4).position_offset.distance_to(collision_target) <= POSITION_EPSILON, "%s keeps the user-dragged card fixed while neighbours avoid it" % label)
		_expect(_render_positions_for_ids_equal(view, before_collision_positions, [1, 2, 3, 7]), "%s gives every remote card zero rendered drift" % label)
		_expect(moved_ids.has(4) and moved_ids.has(5) and _ids_are_subset(moved_ids, [4, 5, 6]), "%s moves only the dragged card and its local collision closure" % label)
		_expect(_rendered_ids_left_to_right(view, [3, 4, 5, 6, 7]), "%s preserves the established relative left-to-right order" % label)
		_expect(_rendered_overlaps(view).is_empty() and _screen_overlaps(view).is_empty(), "%s removes the local collision without hiding cards at the active zoom" % label)
		_expect(_resource_positions_except_equal(tree, 4, other_resource_positions), "%s keeps all non-dragged resource coordinates unchanged" % label)
		_expect(_structure_signature(tree) == structure_before and _execution_order_signature(tree) == order_before, "%s preserves structure and execution order" % label)
		var stable_positions := _render_positions(view)
		await _wait_frames(3)
		_expect(_render_positions_equal(view, stable_positions), "%s reaches a stable local solution without jitter" % label)

		var release_target := Vector2(200.0, 550.0)
		_drag_graph_node_to(view, 4, release_target)
		await _wait_frames(SETTLE_FRAMES)
		_expect(_render_positions_match_resources(view), "%s clears temporary avoidance offsets when the collision is removed" % label)
		_expect(_rendered_overlaps(view).is_empty(), "%s remains overlap-free after moving back into free space" % label)


func _test_parent_child_drag_hierarchy(view: BTEditorView) -> void:
	var cases: Array[Array] = [
		[view.graph_edit.zoom_min, false, false],
		[1.0, true, false],
		[view.graph_edit.zoom_max, false, true],
	]
	for case in cases:
		var zoom_value := float(case[0])
		var semantic_zoom := bool(case[1])
		var compact_cards := bool(case[2])
		var tree := _make_parent_child_drag_tree()
		var structure_before := _structure_signature(tree)
		var order_before := _execution_order_signature(tree)
		var other_positions := _resource_positions_except(tree, 3)
		var label := "parent-child drag zoom %.3f semantic=%s compact=%s" % [zoom_value, semantic_zoom, compact_cards]
		await _prepare_view(view, tree, zoom_value, semantic_zoom, compact_cards)
		var parent_target := _graph_node(view, 2).position_offset
		var drag_result := _drag_graph_node_to(view, 3, parent_target)
		await _wait_frames(SETTLE_FRAMES)
		_expect(bool(drag_result.get("started", false)), "%s starts a direct-edge collision drag" % label)
		_expect(_graph_node(view, 3).position_offset.distance_to(parent_target) <= POSITION_EPSILON, "%s keeps the dragged child at the requested position" % label)
		_expect(_rendered_overlaps(view).is_empty(), "%s resolves the complete parent collision chain" % label)
		_expect(_parent_child_clearance_failures(view, 0.0).is_empty(), "%s preserves the fixture's original parent-above-child relationships" % label)
		_expect(_resource_positions_except_equal(tree, 3, other_positions), "%s leaves every non-dragged resource coordinate unchanged" % label)
		_expect(_structure_signature(tree) == structure_before and _execution_order_signature(tree) == order_before, "%s preserves tree structure and execution order" % label)


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


func _test_playable_tree_zoom_sweep(view: BTEditorView) -> void:
	var tree := ResourceLoader.load("res://behavior_trees/complex_display_tree_241.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as BTTreeResource
	_expect(tree != null, "playable 241-node tree loads for the complete zoom sweep")
	if tree == null:
		return
	var structure_before := _structure_signature(tree)
	var order_before := _execution_order_signature(tree)
	var positions_before := _resource_positions(tree)
	await _prepare_view(view, tree, view.graph_edit.zoom_min, true, false)
	for requested_zoom in [view.graph_edit.zoom_min, 0.25, 0.50, 0.619, 0.620, 0.621, 0.879, 0.880, 0.881, 1.0, 1.5, view.graph_edit.zoom_max]:
		var zoom_value := clampf(float(requested_zoom), view.graph_edit.zoom_min, view.graph_edit.zoom_max)
		view.graph_edit.zoom = zoom_value
		view._update_semantic_zoom()
		await process_frame
		var label := "playable 241-node tree at zoom %.3f" % zoom_value
		_expect(_rendered_overlaps(view).is_empty(), "%s has no graph-space overlap on the first rendered frame" % label)
		_expect(_screen_overlaps(view).is_empty(), "%s has no screen-space overlap on the first rendered frame" % label)
		await _wait_frames(SETTLE_FRAMES)
		_expect(_rendered_overlaps(view).is_empty() and _screen_overlaps(view).is_empty(), "%s remains overlap-free after layout settles" % label)
		_expect(_saved_layered_relationship_failures(view).is_empty(), "%s preserves every parent-above-child relationship present in the saved layout" % label)
		_expect(_rendered_sibling_order_matches_resources(view, tree), "%s preserves the saved sibling order" % label)
	_expect(_structure_signature(tree) == structure_before and _execution_order_signature(tree) == order_before, "complete playable-tree zoom sweep preserves structure and execution order")
	_expect(_resource_positions_equal(tree, positions_before), "complete playable-tree zoom sweep preserves every saved node position")


func _test_playable_tree_max_zoom_quick(view: BTEditorView) -> void:
	var tree := ResourceLoader.load("res://behavior_trees/complex_display_tree_241.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as BTTreeResource
	_expect(tree != null, "quick check loads the playable 241-node tree")
	if tree == null:
		return
	var structure_before := _structure_signature(tree)
	var order_before := _execution_order_signature(tree)
	var positions_before := _resource_positions(tree)
	await _prepare_view(view, tree, view.graph_edit.zoom_max, true, false)
	_expect(_rendered_overlaps(view).is_empty() and _screen_overlaps(view).is_empty(), "playable 241-node tree is overlap-free at maximum zoom")
	_expect(_saved_layered_relationship_failures(view).is_empty(), "playable 241-node tree preserves every authored parent-above-child relationship at maximum zoom")
	_expect(_rendered_sibling_order_matches_resources(view, tree), "playable 241-node maximum-zoom layout preserves sibling order")
	_expect(_structure_signature(tree) == structure_before and _execution_order_signature(tree) == order_before and _resource_positions_equal(tree, positions_before), "playable 241-node maximum-zoom layout changes no saved tree semantics or positions")


func _test_saved_arena_hierarchy_zoom_sweep(view: BTEditorView) -> void:
	var tree := ResourceLoader.load("res://behavior_trees/arena_hunter_121.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as BTTreeResource
	_expect(tree != null, "saved 121-node arena tree loads for hierarchy-preserving zoom tests")
	if tree == null:
		return
	var structure_before := _structure_signature(tree)
	var order_before := _execution_order_signature(tree)
	var positions_before := _resource_positions(tree)
	await _prepare_view(view, tree, view.graph_edit.zoom_min, true, false)
	for requested_zoom in [view.graph_edit.zoom_min, 0.25, 0.50, 0.619, 0.620, 0.621, 0.879, 0.880, 0.881, 1.0, 1.5, view.graph_edit.zoom_max]:
		var zoom_value := clampf(float(requested_zoom), view.graph_edit.zoom_min, view.graph_edit.zoom_max)
		view.graph_edit.zoom = zoom_value
		view._update_semantic_zoom()
		await _wait_frames(SETTLE_FRAMES)
		var failures := _saved_layered_relationship_failures(view)
		if not failures.is_empty():
			print("BT_HIERARCHY_FAILURE zoom=%.3f failures=%s" % [zoom_value, failures])
		_expect(failures.is_empty(), "saved 121-node arena tree preserves its authored parent-above-child relationships at zoom %.3f" % zoom_value)
		_expect(_rendered_overlaps(view).is_empty() and _screen_overlaps(view).is_empty(), "saved 121-node arena tree stays overlap-free at zoom %.3f" % zoom_value)
		_expect(_rendered_sibling_order_matches_resources(view, tree), "saved 121-node arena tree preserves sibling order at zoom %.3f" % zoom_value)
	_expect(_structure_signature(tree) == structure_before and _execution_order_signature(tree) == order_before, "arena hierarchy zoom sweep preserves structure and execution order")
	_expect(_resource_positions_equal(tree, positions_before), "arena hierarchy zoom sweep preserves every saved node position")


func _test_live_drag_avoidance(view: BTEditorView) -> void:
	var cases: Array[Array] = [
		[view.graph_edit.zoom_min, false],
		[0.619, false],
		[0.620, false],
		[0.879, false],
		[0.880, false],
		[view.graph_edit.zoom_max, false],
		[view.graph_edit.zoom_max, true],
	]
	for case in cases:
		var zoom_value := clampf(float(case[0]), view.graph_edit.zoom_min, view.graph_edit.zoom_max)
		var compact_cards := bool(case[1])
		var tree := _make_local_avoidance_tree()
		var structure_before := _structure_signature(tree)
		var order_before := _execution_order_signature(tree)
		var resource_before := _resource_positions(tree)
		var other_resource_before := _resource_positions_except(tree, 4)
		await _prepare_view(view, tree, zoom_value, true, compact_cards)
		var drag_state := _begin_graph_node_drag(view, 4)
		_expect(not drag_state.is_empty(), "live drag begins at zoom %.3f compact=%s" % [zoom_value, compact_cards])
		if drag_state.is_empty():
			continue
		var final_target := Vector2(200.0, 550.0)
		for target in [Vector2(100.0, 550.0), Vector2(220.0, 550.0), Vector2(280.0, 550.0), Vector2(330.0, 550.0), Vector2(420.0, 550.0), Vector2(200.0, 550.0)]:
			var render_positions_before_step := _render_positions(view)
			var refresh_position_before: Vector2 = view.drag_auto_spacing_last_refresh_position
			var refresh_distance_on_screen: float = Vector2(target).distance_to(refresh_position_before) * zoom_value
			_move_graph_node_drag(view, drag_state, target)
			await process_frame
			var label := "live drag zoom %.3f compact=%s at %s" % [zoom_value, compact_cards, target]
			_expect(_graph_node(view, 4).manual_dragging, "%s remains in the active pointer drag" % label)
			_expect(_graph_node(view, 4).position_offset.distance_to(target) <= POSITION_EPSILON, "%s keeps the dragged card under the pointer" % label)
			if view.drag_auto_spacing_active and refresh_distance_on_screen + POSITION_EPSILON < view.DRAG_REFLOW_REFRESH_SCREEN_DISTANCE:
				_expect(_render_positions_for_ids_equal(view, render_positions_before_step, [1, 2, 3, 5, 6, 7]), "%s coalesces a sub-step without moving neighbouring cards" % label)
			else:
				_expect(_rendered_overlaps(view).is_empty() and _screen_overlaps(view).is_empty(), "%s moves colliding neighbours at the next reflow step" % label)
			_expect(_resource_positions_equal(tree, resource_before), "%s defers every resource write until pointer release" % label)
		_end_graph_node_drag(drag_state)
		await _wait_frames(SETTLE_FRAMES)
		var release_label := "live drag release at zoom %.3f compact=%s" % [zoom_value, compact_cards]
		_expect(tree.find_node(4).position.distance_to(final_target) <= POSITION_EPSILON, "%s stores the visible release point" % release_label)
		_expect(_resource_positions_except_equal(tree, 4, other_resource_before), "%s leaves every other saved position unchanged" % release_label)
		_expect(_rendered_overlaps(view).is_empty() and _screen_overlaps(view).is_empty(), "%s remains overlap-free" % release_label)
		_expect(tree.validate_tree().is_empty() and _structure_signature(tree) == structure_before and _execution_order_signature(tree) == order_before, "%s preserves structure and execution order" % release_label)
		var stable_positions := _render_positions(view)
		await _wait_frames(3)
		_expect(_render_positions_equal(view, stable_positions), "%s reaches a stable layout without jitter" % release_label)


func _test_drag_across_display_density_change(view: BTEditorView) -> void:
	var tree := _make_density_transition_tree()
	var resources_before := _resource_positions(tree)
	var structure_before := _structure_signature(tree)
	var order_before := _execution_order_signature(tree)
	await _prepare_view(view, tree, view.graph_edit.zoom_min, true, false)
	_expect(_rendered_overlaps(view).is_empty(), "density-transition fixture starts overlap-free at overview zoom")
	var drag_state := _begin_graph_node_drag(view, 2)
	_expect(not drag_state.is_empty(), "click-hold starts before a semantic detail transition")
	if drag_state.is_empty():
		return
	view.graph_edit.zoom = view.graph_edit.zoom_max
	view._update_semantic_zoom()
	await _wait_frames(SETTLE_FRAMES)
	_expect(_graph_node(view, 2).manual_dragging, "semantic detail transition keeps the pointer drag active")
	_expect(_rendered_overlaps(view).is_empty() and _screen_overlaps(view).is_empty(), "semantic detail transition reflows expanded cards before release")
	_expect(_resource_positions_equal(tree, resources_before), "semantic detail transition performs no resource writes while held")
	_end_graph_node_drag(drag_state)
	await _wait_frames(SETTLE_FRAMES)
	_expect(_rendered_overlaps(view).is_empty() and _screen_overlaps(view).is_empty(), "click release retains collision-free spacing for the new detail level")
	_expect(_resource_positions_equal(tree, resources_before), "click without movement changes no saved position across a detail transition")
	_expect(tree.validate_tree().is_empty() and _structure_signature(tree) == structure_before and _execution_order_signature(tree) == order_before, "detail transition during a click-hold preserves tree semantics")


func _test_wheel_anchor_disabled_during_drag(view: BTEditorView) -> void:
	var tree := _make_local_avoidance_tree()
	var resources_before := _resource_positions(tree)
	await _prepare_view(view, tree, 0.50, true, false)
	view._set_feature_enabled("zoom_anchor", true, false)
	var drag_state := _begin_graph_node_drag(view, 4)
	_expect(not drag_state.is_empty(), "wheel-during-drag fixture starts a real pointer drag")
	if drag_state.is_empty():
		return
	view._clear_zoom_layout_anchor()
	view._on_graph_view_wheel_scrolled(view.graph_edit.size * 0.5)
	_expect(view.zoom_anchor_candidate_id == -1 and view.zoom_layout_anchor_id == -1, "wheel input does not create a competing viewport anchor during node drag")
	view.graph_edit.zoom = 1.0
	var scroll_after_zoom := view.graph_edit.scroll_offset
	view._prepare_zoom_layout_anchor()
	view._restore_zoom_layout_anchor()
	_expect(view.graph_edit.scroll_offset.distance_to(scroll_after_zoom) <= POSITION_EPSILON, "drag-time wheel input does not move the canvas after zoom is applied")
	_end_graph_node_drag(drag_state)
	await _wait_frames(SETTLE_FRAMES)
	_expect(_resource_positions_equal(tree, resources_before), "wheel zoom during click-hold changes no saved position")
	_expect(_rendered_overlaps(view).is_empty() and _screen_overlaps(view).is_empty(), "wheel zoom during click-hold leaves an overlap-free layout")


func _test_drag_previously_displaced_card(view: BTEditorView) -> void:
	for zoom_value in [view.graph_edit.zoom_min, view.graph_edit.zoom_max]:
		var tree := _make_local_avoidance_tree()
		await _prepare_view(view, tree, zoom_value, true, false)
		_drag_graph_node_to(view, 4, Vector2(330.0, 550.0))
		await _wait_frames(SETTLE_FRAMES)
		var displaced := _graph_node(view, 5)
		_expect(displaced != null and not displaced.visual_offset.is_zero_approx(), "zoom %.3f creates a temporarily displaced neighbour" % zoom_value)
		if displaced == null:
			continue
		var rendered_start := displaced.position_offset
		var resources_before := _resource_positions(tree)
		var structure_before := _structure_signature(tree)
		var order_before := _execution_order_signature(tree)
		var drag_state := _begin_graph_node_drag(view, 5)
		_expect(displaced.position_offset.distance_to(rendered_start) <= POSITION_EPSILON, "zoom %.3f grabs a displaced card without snapping it back" % zoom_value)
		var free_target := Vector2(500.0, 900.0)
		_move_graph_node_drag(view, drag_state, free_target)
		await process_frame
		_expect(displaced.position_offset.distance_to(free_target) <= POSITION_EPSILON, "zoom %.3f keeps the previously displaced card under the pointer" % zoom_value)
		_expect(_rendered_overlaps(view).is_empty() and _screen_overlaps(view).is_empty(), "zoom %.3f keeps a previously displaced card overlap-free during its drag" % zoom_value)
		_expect(_resource_positions_equal(tree, resources_before), "zoom %.3f does not write the displaced card or neighbours before release" % zoom_value)
		_end_graph_node_drag(drag_state)
		await _wait_frames(SETTLE_FRAMES)
		_expect(tree.find_node(5).position.distance_to(free_target) <= POSITION_EPSILON, "zoom %.3f stores the visible release point of a previously displaced card" % zoom_value)
		_expect(_rendered_overlaps(view).is_empty() and _screen_overlaps(view).is_empty(), "zoom %.3f remains overlap-free after releasing a previously displaced card" % zoom_value)
		_expect(_structure_signature(tree) == structure_before and _execution_order_signature(tree) == order_before, "zoom %.3f preserves semantics when dragging a previously displaced card" % zoom_value)


func _test_large_live_drag_latency(view: BTEditorView) -> void:
	var tree := TreeFactory.generate(364) as BTTreeResource
	_assign_layered_positions(tree)
	var leaf_ids := _last_leaf_ids(tree, 2)
	_expect(leaf_ids.size() == 2, "364-node live-drag timing has an isolated collision pair")
	if leaf_ids.size() != 2:
		return
	var source_id := leaf_ids[0]
	var target_id := leaf_ids[1]
	var bounds := _resource_card_bounds(tree)
	var target_position := bounds.end + Vector2(1000.0, 500.0)
	tree.find_node(target_id).position = target_position
	tree.find_node(source_id).position = target_position + Vector2(-500.0, 0.0)
	var resource_before := _resource_positions(tree)
	var structure_before := _structure_signature(tree)
	var order_before := _execution_order_signature(tree)
	await _prepare_view(view, tree, view.graph_edit.zoom_max, true, false)
	var drag_begin_usec := Time.get_ticks_usec()
	var drag_state := _begin_graph_node_drag(view, source_id)
	var drag_begin_ms := float(Time.get_ticks_usec() - drag_begin_usec) / 1000.0
	_expect(not drag_state.is_empty(), "364-node live-drag timing starts a real drag")
	if drag_state.is_empty():
		return
	var samples_ms: Array[float] = []
	for offset_x in [-210.0, -180.0, -150.0, -120.0, -90.0, -60.0, -30.0, 0.0, 30.0, 60.0, 90.0, 120.0]:
		_move_graph_node_drag(view, drag_state, target_position + Vector2(offset_x, 0.0))
		var started_usec := Time.get_ticks_usec()
		view._update_auto_spacing(0.0, true)
		samples_ms.append(float(Time.get_ticks_usec() - started_usec) / 1000.0)
		_expect(_rendered_overlaps(view).is_empty(), "364-node live drag resolves sample %.0f before release" % offset_x)
	samples_ms.sort()
	var p95_index := clampi(ceili(float(samples_ms.size()) * 0.95) - 1, 0, samples_ms.size() - 1)
	var p95_ms := samples_ms[p95_index]
	print("BT_LIVE_DRAG_METRIC cards=%d samples=%d begin_ms=%.3f p95_ms=%.3f max_ms=%.3f" % [_graph_nodes(view).size(), samples_ms.size(), drag_begin_ms, p95_ms, samples_ms[-1]])
	_expect(drag_begin_ms <= 50.0, "364-node drag-start baseline pruning stays below the 50 ms interaction safety limit at maximum zoom")
	_expect(p95_ms <= 50.0, "364-node live collision avoidance stays below the 50 ms interaction safety limit at maximum zoom")
	_expect(_resource_positions_equal(tree, resource_before), "364-node live drag performs no resource writes before release")
	_expect(_structure_signature(tree) == structure_before and _execution_order_signature(tree) == order_before, "364-node live drag preserves structure and execution order")
	_end_graph_node_drag(drag_state)
	await _wait_frames(SETTLE_FRAMES)


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


func _test_complex_tree_drag_locality(view: BTEditorView) -> void:
	for node_count in SCALE_COUNTS:
		var tree := TreeFactory.generate(node_count) as BTTreeResource
		_assign_layered_positions(tree)
		var leaf_ids := _last_leaf_ids(tree, 2)
		var label := "%d-node isolated local collision" % node_count
		_expect(leaf_ids.size() == 2, "%s provides two leaf drag targets" % label)
		if leaf_ids.size() != 2:
			continue
		var source_id := leaf_ids[0]
		var target_id := leaf_ids[1]
		var bounds := _resource_card_bounds(tree)
		var isolated_target := bounds.end + Vector2(1000.0, 500.0)
		tree.find_node(target_id).position = isolated_target
		tree.find_node(source_id).position = isolated_target + Vector2(-500.0, 0.0)
		var structure_before := _structure_signature(tree)
		var order_before := _execution_order_signature(tree)
		var other_resource_positions := _resource_positions_except(tree, source_id)
		await _prepare_view(view, tree, 1.0, false, false)
		var rendered_before := _render_positions(view)
		var source_graph_node := _graph_node(view, source_id)
		var collision_target := isolated_target + Vector2(-source_graph_node.size.x + 100.0, 0.0)
		_drag_graph_node_to(view, source_id, collision_target)
		await _wait_frames(SETTLE_FRAMES)
		var rendered_after := _render_positions(view)
		var remote_ids: Array[int] = []
		for id_variant in rendered_before.keys():
			var node_id := int(id_variant)
			if node_id != source_id and node_id != target_id:
				remote_ids.append(node_id)
		var moved_ids := _moved_render_ids(rendered_before, rendered_after)
		_expect(_graph_node(view, source_id).position_offset.distance_to(collision_target) <= POSITION_EPSILON, "%s keeps the dragged leaf at its requested position" % label)
		_expect(_render_positions_for_ids_equal(view, rendered_before, remote_ids), "%s leaves every non-colliding card at its previous rendered position" % label)
		_expect(moved_ids.has(source_id) and moved_ids.has(target_id) and _ids_are_subset(moved_ids, [source_id, target_id]), "%s confines automatic movement to the isolated collision pair" % label)
		_expect(_rendered_overlaps(view).is_empty() and _screen_overlaps(view).is_empty(), "%s resolves the isolated collision without overlap" % label)
		_expect(_resource_positions_except_equal(tree, source_id, other_resource_positions), "%s does not write avoidance movement into other resources" % label)
		_expect(_structure_signature(tree) == structure_before and _execution_order_signature(tree) == order_before, "%s preserves tree semantics and execution order" % label)


func _test_large_local_solver_latency(view: BTEditorView) -> void:
	var tree := TreeFactory.generate(364) as BTTreeResource
	_assign_layered_positions(tree)
	await _prepare_view(view, tree, 1.0, true, false)
	var leaf_ids := _last_leaf_ids(tree, 2)
	_expect(leaf_ids.size() == 2, "364-node solver timing has an isolated collision target")
	if leaf_ids.size() != 2:
		return
	_drag_graph_node_onto(view, leaf_ids[0], leaf_ids[1])
	await _wait_frames(SETTLE_FRAMES)
	var started_usec := Time.get_ticks_usec()
	var solved_offsets := view._solve_auto_spacing_offsets(leaf_ids[0])
	var elapsed_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
	print("BT_LOCAL_AVOIDANCE_METRIC cards=%d solve_ms=%.3f" % [_graph_nodes(view).size(), elapsed_ms])
	_expect(solved_offsets.size() == _graph_nodes(view).size(), "364-node local solver returns one deterministic offset per visible card")
	# Keep this as a diagnostic metric rather than a machine-dependent pass gate.
	# Functional correctness is covered above; layout timing is outside this task.


func _test_zero_coordinate_recovery(view: BTEditorView) -> void:
	var cases: Array[Array] = []
	for node_count in SCALE_COUNTS:
		cases.append([node_count, view.graph_edit.zoom_min, true, false, "semantic overview"])
		cases.append([node_count, 1.0, false, false, "normal cards"])
		cases.append([node_count, view.graph_edit.zoom_max, false, true, "compact cards"])
	for zoom_value in [0.619, 0.620, 0.621, view.graph_edit.zoom_max]:
		cases.append([364, zoom_value, true, false, "semantic boundary"])
	for case in cases:
		var node_count := int(case[0])
		var zoom_value := float(case[1])
		var semantic_zoom := bool(case[2])
		var compact_cards := bool(case[3])
		var display_mode := str(case[4])
		var tree := TreeFactory.generate(node_count) as BTTreeResource
		var positions_before := _resource_positions(tree)
		var structure_before := _structure_signature(tree)
		var order_before := _execution_order_signature(tree)
		var label := "%d-node all-zero %s layout at zoom %.3f" % [node_count, display_mode, zoom_value]
		await _prepare_view(view, tree, zoom_value, semantic_zoom, compact_cards)
		await _wait_frames(SETTLE_FRAMES)
		_expect(_rendered_overlaps(view).is_empty(), "%s automatically recovers without overlap" % label)
		_expect(_screen_overlaps(view).is_empty(), "%s is readable in screen space" % label)
		# Every resource position is intentionally identical in this recovery case,
		# so it has no authored parent-above-child relationship to enforce.
		_expect(_rendered_sibling_order_matches_resources(view, tree), "%s renders siblings in their saved execution order" % label)
		_expect(_resource_positions_equal(tree, positions_before), "%s uses temporary offsets only" % label)
		_expect(_structure_signature(tree) == structure_before and tree.validate_tree().is_empty(), "%s preserves a valid tree" % label)
		_expect(_execution_order_signature(tree) == order_before, "%s preserves execution order" % label)


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


func _prepare_deadzone_fixture(view: BTEditorView, zoom_value: float) -> BTTreeResource:
	var tree := _make_deadzone_tree()
	await _prepare_view(view, tree, zoom_value, false, false)
	var source := _graph_node(view, 4)
	if source != null:
		tree.find_node(5).position = source.node_resource.position + Vector2(source.size.x + view.AUTO_SPACING_GAP, 0.0)
		view._rebuild_graph()
		await _wait_frames(3)
	return tree


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


func _drag_graph_node_to(view: BTEditorView, source_id: int, logical_target: Vector2) -> Dictionary:
	var source := _graph_node(view, source_id)
	if source == null:
		return {}
	var resource_before := source.node_resource.position
	var local_pointer := Vector2(38.0, source.size.y * 0.5)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = local_pointer
	source._gui_input(press)
	var graph_delta := logical_target - source.position_offset
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


func _begin_graph_node_drag(view: BTEditorView, source_id: int) -> Dictionary:
	var source := _graph_node(view, source_id)
	if source == null:
		return {}
	var local_pointer := Vector2(38.0, source.size.y * 0.5)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = local_pointer
	source._gui_input(press)
	return {
		"view": view,
		"source": source,
		"local_pointer": local_pointer,
	}


func _move_graph_node_drag(view: BTEditorView, drag_state: Dictionary, logical_target: Vector2) -> void:
	var source := drag_state.get("source") as BTGraphNode
	if source == null:
		return
	var local_pointer := Vector2(drag_state.get("local_pointer", Vector2.ZERO))
	# Real pointer motion starts from the rendered card. This also covers cards
	# that currently have a temporary auto-spacing offset.
	var graph_delta := logical_target - source.position_offset
	var motion := InputEventMouseMotion.new()
	motion.position = local_pointer + graph_delta * view.graph_edit.zoom
	motion.relative = graph_delta * view.graph_edit.zoom
	source._gui_input(motion)


func _end_graph_node_drag(drag_state: Dictionary) -> void:
	var source := drag_state.get("source") as BTGraphNode
	if source == null:
		return
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(drag_state.get("local_pointer", Vector2.ZERO))
	source._gui_input(release)


func _make_freeform_tree() -> BTTreeResource:
	var tree := BTTreeResource.new()
	tree.tree_name = "Freeform Auto Spacing Fixture"
	tree.root_node_id = 1
	tree.nodes = [
		_make_node(1, BTNodeResource.TYPE_ROOT, -1, Vector2(650.0, 420.0)),
		_make_node(2, BTNodeResource.TYPE_SELECTOR, 1, Vector2(80.0, 80.0)),
		_make_node(3, BTNodeResource.TYPE_ACTION, 2, Vector2(1200.0, 100.0)),
		_make_node(4, BTNodeResource.TYPE_ACTION, 2, Vector2(300.0, 760.0)),
		_make_node(5, BTNodeResource.TYPE_ACTION, 2, Vector2(1050.0, 740.0)),
	]
	return tree


func _make_deadzone_tree() -> BTTreeResource:
	var tree := BTTreeResource.new()
	tree.tree_name = "Drag Reflow Deadzone Fixture"
	tree.root_node_id = 1
	tree.nodes = [
		_make_node(1, BTNodeResource.TYPE_ROOT, -1, Vector2(600.0, 0.0)),
		_make_node(2, BTNodeResource.TYPE_SEQUENCE, 1, Vector2(600.0, 260.0)),
		_make_node(3, BTNodeResource.TYPE_ACTION, 2, Vector2(-600.0, 560.0)),
		_make_node(4, BTNodeResource.TYPE_ACTION, 2, Vector2(0.0, 560.0)),
		_make_node(5, BTNodeResource.TYPE_ACTION, 2, Vector2(500.0, 560.0)),
		_make_node(6, BTNodeResource.TYPE_ACTION, 2, Vector2(1200.0, 560.0)),
	]
	return tree


func _make_conditional_hierarchy_tree() -> BTTreeResource:
	var tree := BTTreeResource.new()
	tree.tree_name = "Conditional Parent Child Clearance Fixture"
	tree.root_node_id = 1
	tree.nodes = [
		_make_node(1, BTNodeResource.TYPE_ROOT, -1, Vector2(-900.0, -400.0)),
		_make_node(2, BTNodeResource.TYPE_SEQUENCE, 1, Vector2(100.0, 300.0)),
		_make_node(3, BTNodeResource.TYPE_ACTION, 2, Vector2(1000.0, 700.0)),
	]
	return tree


func _make_local_avoidance_tree() -> BTTreeResource:
	var tree := BTTreeResource.new()
	tree.tree_name = "Local Collision Avoidance Fixture"
	tree.root_node_id = 1
	tree.nodes = [
		_make_node(1, BTNodeResource.TYPE_ROOT, -1, Vector2(650.0, 0.0)),
		_make_node(2, BTNodeResource.TYPE_SEQUENCE, 1, Vector2(650.0, 250.0)),
		_make_node(3, BTNodeResource.TYPE_ACTION, 2, Vector2(-300.0, 550.0)),
		_make_node(4, BTNodeResource.TYPE_ACTION, 2, Vector2(0.0, 550.0)),
		_make_node(5, BTNodeResource.TYPE_ACTION, 2, Vector2(500.0, 550.0)),
		_make_node(6, BTNodeResource.TYPE_ACTION, 2, Vector2(800.0, 550.0)),
		_make_node(7, BTNodeResource.TYPE_ACTION, 2, Vector2(1300.0, 550.0)),
	]
	return tree


func _make_parent_child_drag_tree() -> BTTreeResource:
	var tree := BTTreeResource.new()
	tree.tree_name = "Parent Child Drag Hierarchy"
	tree.root_node_id = 1
	tree.nodes = [
		_make_node(1, BTNodeResource.TYPE_ROOT, -1, Vector2(100.0, 100.0)),
		_make_node(2, BTNodeResource.TYPE_SEQUENCE, 1, Vector2(100.0, 400.0)),
		_make_node(3, BTNodeResource.TYPE_ACTION, 2, Vector2(100.0, 700.0)),
		_make_node(4, BTNodeResource.TYPE_ACTION, 2, Vector2(500.0, 700.0)),
	]
	return tree


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


func _make_density_transition_tree() -> BTTreeResource:
	var tree := BTTreeResource.new()
	tree.tree_name = "Held Drag Density Transition Fixture"
	tree.root_node_id = 1
	tree.nodes = [
		_make_node(1, BTNodeResource.TYPE_ROOT, -1, Vector2(0.0, 0.0)),
		_make_node(2, BTNodeResource.TYPE_SEQUENCE, 1, Vector2(0.0, 180.0)),
		_make_node(3, BTNodeResource.TYPE_ACTION, 2, Vector2(0.0, 360.0)),
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


func _render_positions_match_expected(view: BTEditorView, expected: Dictionary) -> bool:
	if expected.size() != _graph_nodes(view).size():
		return false
	for graph_node in _graph_nodes(view):
		if not expected.has(graph_node.node_resource.id):
			return false
		if graph_node.position_offset.distance_to(Vector2(expected[graph_node.node_resource.id])) > POSITION_EPSILON:
			return false
	return true


func _render_positions_match_resources(view: BTEditorView) -> bool:
	for graph_node in _graph_nodes(view):
		if graph_node.position_offset.distance_to(graph_node.node_resource.position) > POSITION_EPSILON:
			return false
	return true


func _render_positions_for_ids_equal(view: BTEditorView, expected: Dictionary, node_ids: Array) -> bool:
	for id_variant in node_ids:
		var node_id := int(id_variant)
		var graph_node := _graph_node(view, node_id)
		if graph_node == null or not expected.has(node_id):
			return false
		if graph_node.position_offset.distance_to(Vector2(expected[node_id])) > POSITION_EPSILON:
			return false
	return true


func _moved_render_ids(before: Dictionary, after: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for id_variant in before.keys():
		var node_id := int(id_variant)
		if not after.has(node_id) or Vector2(before[node_id]).distance_to(Vector2(after[node_id])) > POSITION_EPSILON:
			result.append(node_id)
	result.sort()
	return result


func _ids_are_subset(candidate_ids: Array[int], allowed_ids: Array) -> bool:
	for node_id in candidate_ids:
		if not allowed_ids.has(node_id):
			return false
	return true


func _rendered_ids_left_to_right(view: BTEditorView, node_ids: Array) -> bool:
	var previous_x := -INF
	for id_variant in node_ids:
		var graph_node := _graph_node(view, int(id_variant))
		if graph_node == null or graph_node.position_offset.x <= previous_x:
			return false
		previous_x = graph_node.position_offset.x
	return true


func _parent_child_clearance_failures(view: BTEditorView, minimum_gap: float) -> Array[String]:
	var failures: Array[String] = []
	for child in _graph_nodes(view):
		var parent_id: int = child.node_resource.parent_id
		if parent_id == -1:
			continue
		var parent := _graph_node(view, parent_id)
		if parent == null:
			continue
		var gap := child.position_offset.y - (parent.position_offset.y + parent.size.y)
		if gap + POSITION_EPSILON < minimum_gap:
			failures.append("%d>%d gap=%.3f" % [parent_id, child.node_resource.id, gap])
	return failures


func _saved_layered_relationship_failures(view: BTEditorView) -> Array[String]:
	var failures: Array[String] = []
	for child in _graph_nodes(view):
		var parent_id: int = child.node_resource.parent_id
		if parent_id == -1:
			continue
		var parent := _graph_node(view, parent_id)
		if parent == null:
			continue
		var saved_gap := view._saved_parent_child_vertical_gap(parent, child)
		if saved_gap < -POSITION_EPSILON:
			continue
		var rendered_gap := child.position_offset.y - (parent.position_offset.y + parent.size.y)
		if rendered_gap + POSITION_EPSILON < 0.0:
			failures.append("%d>%d saved=%.3f rendered=%.3f" % [parent_id, child.node_resource.id, saved_gap, rendered_gap])
	return failures


func _depth_layer_clearance_failures(view: BTEditorView, tree: BTTreeResource, minimum_gap: float) -> Array[String]:
	var rows: Dictionary = {}
	var maximum_depth := 0
	for graph_node in _graph_nodes(view):
		var depth := _node_depth(tree, graph_node.node_resource)
		maximum_depth = maxi(maximum_depth, depth)
		var row: Dictionary = rows.get(depth, {"min_top": INF, "max_bottom": -INF})
		row["min_top"] = minf(float(row["min_top"]), graph_node.position_offset.y)
		row["max_bottom"] = maxf(float(row["max_bottom"]), graph_node.position_offset.y + graph_node.size.y)
		rows[depth] = row
	var failures: Array[String] = []
	for depth in range(maximum_depth):
		if not rows.has(depth) or not rows.has(depth + 1):
			continue
		var upper: Dictionary = rows[depth]
		var lower: Dictionary = rows[depth + 1]
		var gap := float(lower["min_top"]) - float(upper["max_bottom"])
		if gap + POSITION_EPSILON < minimum_gap:
			failures.append("%d>%d gap=%.3f" % [depth, depth + 1, gap])
	return failures


func _rendered_sibling_order_matches_resources(view: BTEditorView, tree: BTTreeResource) -> bool:
	for parent in tree.nodes:
		if parent == null or parent.decorator_parent_id != -1:
			continue
		var resource_children := tree.get_children_of(parent.id)
		if resource_children.size() < 2:
			continue
		var rendered_children: Array[BTGraphNode] = []
		for child in resource_children:
			var rendered := _graph_node(view, child.id)
			if rendered == null:
				return false
			rendered_children.append(rendered)
		rendered_children.sort_custom(func(left: BTGraphNode, right: BTGraphNode) -> bool:
			if not is_equal_approx(left.position_offset.x, right.position_offset.x):
				return left.position_offset.x < right.position_offset.x
			return left.position_offset.y < right.position_offset.y
		)
		for index in range(resource_children.size()):
			if resource_children[index].id != rendered_children[index].node_resource.id:
				return false
	return true


func _all_visual_offsets_zero(view: BTEditorView) -> bool:
	for graph_node in _graph_nodes(view):
		if graph_node.visual_offset.length() > POSITION_EPSILON:
			return false
	return true


func _render_positions_equal(view: BTEditorView, expected: Dictionary) -> bool:
	for graph_node in _graph_nodes(view):
		if not expected.has(graph_node.node_resource.id):
			return false
		if graph_node.position_offset.distance_to(Vector2(expected[graph_node.node_resource.id])) > POSITION_EPSILON:
			return false
	return expected.size() == _graph_nodes(view).size()


func _vector_dictionaries_equal(first: Dictionary, second: Dictionary) -> bool:
	if first.size() != second.size():
		return false
	for key in first:
		if not second.has(key) or not Vector2(first[key]).is_equal_approx(Vector2(second[key])):
			return false
	return true


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


func _resource_card_bounds(tree: BTTreeResource) -> Rect2:
	var initialized := false
	var bounds := Rect2()
	for node in tree.nodes:
		if node == null or node.decorator_parent_id != -1:
			continue
		var card_rect := Rect2(node.position, BTGraphNode.NORMAL_CARD_SIZE)
		bounds = bounds.merge(card_rect) if initialized else card_rect
		initialized = true
	return bounds


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
