extends SceneTree

const BTEditorView = preload("res://addons/behavior_tree_editor/bt_editor_view.gd")
const BTGraphNode = preload("res://addons/behavior_tree_editor/bt_graph_node.gd")
const BTNodeResource = preload("res://addons/behavior_tree_editor/bt_node_resource.gd")
const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")
const BTBlackboardEntry = preload("res://addons/behavior_tree_editor/bt_blackboard_entry.gd")
const BTBlackboardSchema = preload("res://addons/behavior_tree_editor/bt_blackboard_schema.gd")

var passed := 0
var failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var view := BTEditorView.new()
	view.set_anchors_preset(Control.PRESET_TOP_LEFT)
	view.size = Vector2(1600.0, 900.0)
	root.add_child(view)
	await process_frame
	await process_frame
	_expect(view.graph_edit != null and view.search_edit != null and view.search_toggle != null and view.branch_dimming_toggle != null and view.failure_reason_toggle != null, "editor view builds controls")
	_test_compact_display_toolbar(view)
	var node_palette := view.find_child("NodePalette", true, false) as VBoxContainer
	_expect(node_palette != null and not node_palette.visible and node_palette.custom_minimum_size == Vector2.ZERO, "node creation palette is removed from the visible editor")
	var all_context_types_present := true
	for creation_id in range(10):
		if view.context_menu.get_item_index(creation_id) < 0:
			all_context_types_present = false
			break
	_expect(all_context_types_present, "right-click menu contains every supported node type")
	_expect(view.path_navigation_row is VBoxContainer and view.runtime_path_scroll != null and view.selection_path_scroll != null, "runtime and selection paths use independent overflow-safe rows")
	_expect(view.runtime_debug_label.clip_text and view.runtime_debug_label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "long Live Debug text is clipped with an ellipsis instead of expanding the editor")
	view.current_tree = _make_view_tree()
	view.current_tree_path = "res://behavior_trees/test_view_tree.tres"
	view.selected_node_id = 2
	view.next_node_id = 7
	view._refresh_entire_ui()
	await process_frame
	_expect(_graph_node_count(view) == 5, "attached decorator is shown on owner, not as graph node")
	_expect(_graph_node(view, 4).decorator_badges.get_child_count() == 1, "decorator badge is visible")
	_expect(view.NODE_TYPES.has(BTNodeResource.TYPE_PARALLEL), "Parallel is available in editor node types")
	_expect(view.NODE_TYPES.has(BTNodeResource.TYPE_RANDOM_SELECTOR), "Random Selector is available in editor node types")
	_expect(view.NODE_TYPES.has(BTNodeResource.TYPE_REPEAT) and view.NODE_TYPES.has(BTNodeResource.TYPE_WAIT), "Repeat and Wait are available in editor node types")

	view._on_compact_toggled(true)
	_expect(_graph_node(view, 2).compact_mode and not _graph_node(view, 2).description_label.visible, "compact mode hides detail")
	_expect(_graph_node(view, 2).custom_minimum_size.x == BTGraphNode.COMPACT_CARD_SIZE.x, "compact mode reduces card width")
	view._on_compact_toggled(false)

	view.semantic_zoom_enabled = true
	view.graph_edit.zoom = 0.5
	view._update_semantic_zoom()
	_expect(view.semantic_detail_level == 0, "semantic zoom chooses overview detail")
	_expect(not _graph_node(view, 2).type_badge.visible, "semantic overview hides secondary labels")
	view.graph_edit.zoom = 1.0
	view._update_semantic_zoom()
	_expect(view.semantic_detail_level == 2 and _graph_node(view, 2).description_label.visible, "semantic zoom restores full detail")

	view._on_search_changed("attack")
	_expect(_graph_node(view, 4).search_matches, "search finds node title and parameters")
	_expect(not _graph_node(view, 5).search_matches, "search dims non-matching node")
	view._on_search_changed("")
	_expect(_graph_node(view, 5).self_modulate == Color.WHITE, "clearing search restores node style")
	var focus_node := _graph_node(view, 5)
	var original_focus_position := focus_node.position_offset
	var original_focus_zoom := view.graph_edit.zoom
	focus_node.position_offset = Vector2(80000.0, 2000.0)
	view.graph_edit.zoom = 0.1
	view._focus_graph_node(5)
	await process_frame
	_expect(view.graph_edit.get_global_rect().has_point(focus_node.get_global_rect().get_center()), "node focus centers distant targets at minimum zoom")
	focus_node.position_offset = original_focus_position
	view.graph_edit.zoom = original_focus_zoom

	view.selected_node_id = 3
	view._focus_selected_subtree()
	await process_frame
	_expect(_graph_node_count(view) == 4, "subtree focus keeps ancestors and descendants")
	view._clear_subtree_focus()
	await process_frame
	_expect(_graph_node_count(view) == 5, "show all restores hidden branch")

	view._set_all_subtrees_collapsed(true)
	await process_frame
	_expect(_graph_node_count(view) == 1, "collapse all reduces tree to root")
	view._set_all_subtrees_collapsed(false)
	await process_frame
	_expect(_graph_node_count(view) == 5, "expand all restores tree")

	view.selected_node_id = 4
	view._refresh_inspector()
	_expect(view.decorator_picker.item_count == 1, "inspector lists attached decorators")
	view._edit_picked_decorator()
	_expect(view.current_tree.find_node(view.selected_node_id).decorator_parent_id == 4, "decorator can be selected for editing")
	view._return_to_decorator_owner()
	_expect(view.selected_node_id == 4, "decorator editor returns to owner")

	var node := _graph_node(view, 4)
	view._set_feature_enabled("fisheye", true, false)
	node.scale = Vector2(1.2, 1.2)
	node.pivot_offset = node.size * 0.5
	node.z_index = 500
	var zoom_before_fisheye_disable: float = view.graph_edit.zoom
	var scroll_before_fisheye_disable: Vector2 = view.graph_edit.scroll_offset
	view._on_fisheye_toggled(false)
	await process_frame
	var rebuilt_node := _graph_node(view, 4)
	_expect(rebuilt_node != node, "disabling fisheye recreates graph controls")
	_expect(rebuilt_node.scale.is_equal_approx(Vector2.ONE), "disabling fisheye restores node scale")
	_expect(rebuilt_node.pivot_offset.is_zero_approx() and rebuilt_node.z_index == 0, "disabling fisheye clears transform residue")
	_expect(view.graph_edit.get_connection_list().size() == 4, "disabling fisheye rebuilds every connection")
	_expect(is_equal_approx(view.graph_edit.zoom, zoom_before_fisheye_disable) and view.graph_edit.scroll_offset.is_equal_approx(scroll_before_fisheye_disable), "fisheye cleanup preserves viewport")

	await _test_display_feature_switches(view)
	_test_right_click_node_creation(view)
	await _test_editor_mutations(view)
	_test_typed_parameter_inspector(view)
	_test_blackboard_schema_editor(view)
	_test_live_blackboard_panel(view)
	_test_live_debug_bridge_resilience(view)

	print("BT_EDITOR_TEST_SUMMARY passed=%d failed=%d" % [passed, failed])
	view.free()
	quit(0 if failed == 0 else 1)


func _test_right_click_node_creation(view: BTEditorView) -> void:
	view.current_tree = BTTreeResource.new()
	view.current_tree.tree_name = "Context Creation Test"
	view.current_tree.root_node_id = -1
	view.current_tree.nodes = []
	view.selected_node_id = -1
	view.next_node_id = 1
	view.graph_edit.zoom = 1.0
	view.graph_edit.scroll_offset = Vector2.ZERO
	view._on_canvas_context_requested(Vector2(180.0, 120.0))
	view.context_menu.hide()
	view._on_context_menu_id_pressed(0)
	_expect(view.current_tree.root_node_id == 1 and view.current_tree.find_node(1).position == Vector2(180.0, 120.0), "right-click creates Root at the pointer position")
	var definitions := [
		[1, BTNodeResource.TYPE_SEQUENCE], [2, BTNodeResource.TYPE_SELECTOR],
		[7, BTNodeResource.TYPE_RANDOM_SELECTOR], [6, BTNodeResource.TYPE_PARALLEL],
		[8, BTNodeResource.TYPE_REPEAT], [3, BTNodeResource.TYPE_ACTION],
		[4, BTNodeResource.TYPE_CONDITION], [9, BTNodeResource.TYPE_WAIT],
		[5, BTNodeResource.TYPE_DECORATOR],
	]
	for index in range(definitions.size()):
		view.selected_node_id = 1
		view.pending_context_position = Vector2(240.0 + index * 35.0, 300.0)
		view._on_context_menu_id_pressed(int(definitions[index][0]))
		var created := view.current_tree.find_node(index + 2)
		_expect(created != null and created.node_type == str(definitions[index][1]) and created.position == view.pending_context_position, "right-click creates %s at the requested graph position" % definitions[index][1])
	_expect(view.current_tree.nodes.size() == 10, "right-click workflow creates all ten node types without palette buttons")


func _test_editor_mutations(view: BTEditorView) -> void:
	view.current_tree = BTTreeResource.new()
	view.current_tree.tree_name = "Mutation Test"
	view.current_tree_path = "res://behavior_trees/mutation_test.tres"
	view.selected_node_id = -1
	view.next_node_id = 1
	view.undo_stack.clear()
	view.redo_stack.clear()
	view._refresh_entire_ui()

	view._create_node_from_ui(BTNodeResource.TYPE_ROOT, Vector2(100.0, 80.0))
	_expect(view.current_tree.root_node_id == 1 and view.current_tree.nodes.size() == 1, "editor creates one root")
	view._create_node_from_ui(BTNodeResource.TYPE_ROOT, Vector2(300.0, 80.0))
	_expect(view.current_tree.nodes.size() == 1, "editor prevents duplicate root")

	view._create_node_from_ui(BTNodeResource.TYPE_SEQUENCE, Vector2(100.0, 280.0))
	var sequence_id := view.selected_node_id
	_expect(view.current_tree.find_node(sequence_id).parent_id == 1, "drop creation attaches to selected parent")
	view.selected_node_id = sequence_id
	view._create_node_from_ui(BTNodeResource.TYPE_PARALLEL, Vector2(500.0, 480.0))
	var parallel_id := view.selected_node_id
	_expect(view.current_tree.find_node(parallel_id).parent_id == sequence_id and view.current_tree.find_node(parallel_id).parameters.get("success_policy") == "all", "editor creates configured Parallel composite")
	view.selected_node_id = sequence_id
	view._create_node_from_ui(BTNodeResource.TYPE_RANDOM_SELECTOR, Vector2(800.0, 480.0))
	var random_selector_id := view.selected_node_id
	_expect(view.current_tree.find_node(random_selector_id).parent_id == sequence_id and view.current_tree.find_node(random_selector_id).parameters.get("seed") == -1, "editor creates configured Random Selector")
	view.selected_node_id = sequence_id
	view._create_node_from_ui(BTNodeResource.TYPE_REPEAT, Vector2(1100.0, 480.0))
	var repeat_id := view.selected_node_id
	_expect(view.current_tree.find_node(repeat_id).parent_id == sequence_id and view.current_tree.find_node(repeat_id).parameters.get("repeat_count") == -1, "editor creates configured Repeat")
	view._create_node_from_ui(BTNodeResource.TYPE_WAIT, Vector2(1100.0, 680.0))
	var wait_id := view.selected_node_id
	_expect(view.current_tree.find_node(wait_id).parent_id == repeat_id and view.current_tree.find_node(wait_id).parameters.get("duration") == 1.0, "editor creates Wait under Repeat")
	view.selected_node_id = wait_id
	view._create_node_from_ui(BTNodeResource.TYPE_ACTION, Vector2(1100.0, 880.0))
	_expect(view.current_tree.find_node(view.selected_node_id).parent_id == -1, "editor keeps children disconnected from Wait leaf")
	view.current_tree.nodes.erase(view.current_tree.find_node(view.selected_node_id))
	view.selected_node_id = sequence_id
	view._create_node_from_ui(BTNodeResource.TYPE_ACTION, Vector2(40.0, 480.0))
	var action_id := view.selected_node_id
	_expect(view.current_tree.find_node(action_id).parent_id == sequence_id, "editor creates Action child")
	view._create_node_from_ui(BTNodeResource.TYPE_CONDITION, Vector2(320.0, 480.0))
	var detached_id := view.selected_node_id
	_expect(view.current_tree.find_node(detached_id).parent_id == -1, "leaf selection creates disconnected node instead of invalid child")
	await process_frame
	await process_frame

	var sequence_graph_node := _graph_node(view, sequence_id)
	var detached_graph_node := _graph_node(view, detached_id)
	var sequence_position_before_port_drag := sequence_graph_node.position_offset
	var port_press := InputEventMouseButton.new()
	port_press.button_index = MOUSE_BUTTON_LEFT
	port_press.pressed = true
	port_press.position = Vector2(sequence_graph_node.size.x * 0.5, sequence_graph_node.size.y - 7.0 * sequence_graph_node.fisheye_magnification)
	sequence_graph_node._gui_input(port_press)
	_expect(not sequence_graph_node.draggable and sequence_graph_node.manual_connection_dragging and not sequence_graph_node.manual_dragging and sequence_graph_node.position_offset.is_equal_approx(sequence_position_before_port_drag), "bottom port starts connection drag without moving the node")
	var detached_input_position := view.graph_edit._input_port_position(detached_graph_node)
	_expect(view.graph_edit.find_input_port_at(detached_input_position, StringName(str(sequence_id))) == StringName(str(detached_id)), "manual connection targets the visible top port")
	view.graph_edit.finish_manual_connection(detached_input_position)
	sequence_graph_node.manual_connection_dragging = false
	_expect(view.current_tree.find_node(detached_id).parent_id == sequence_id, "bottom-to-top port drag connects an existing node")
	view._on_disconnection_request(str(sequence_id), 0, str(detached_id), 0)
	await process_frame
	sequence_graph_node = _graph_node(view, sequence_id)
	detached_graph_node = _graph_node(view, detached_id)
	view.graph_edit.begin_manual_connection(StringName(str(sequence_id)), view.graph_edit._output_port_position(sequence_graph_node))
	var target_global_position := view.graph_edit.get_global_transform_with_canvas() * view.graph_edit._input_port_position(detached_graph_node)
	var cross_node_release := InputEventMouseButton.new()
	cross_node_release.button_index = MOUSE_BUTTON_LEFT
	cross_node_release.pressed = false
	cross_node_release.position = target_global_position
	view.graph_edit._input(cross_node_release)
	_expect(view.current_tree.find_node(detached_id).parent_id == sequence_id and not view.graph_edit.manual_connection_active, "canvas-level release completes a drag after the pointer leaves its source node")
	view._on_disconnection_request(str(sequence_id), 0, str(detached_id), 0)
	await process_frame
	sequence_graph_node = _graph_node(view, sequence_id)
	detached_graph_node = _graph_node(view, detached_id)
	view.graph_edit.zoom = 0.65
	view.graph_edit.scroll_offset = Vector2(135.0, 75.0)
	await process_frame
	var transformed_input_position := view.graph_edit._input_port_position(detached_graph_node)
	_expect(view.graph_edit.find_input_port_at(transformed_input_position, StringName(str(sequence_id))) == StringName(str(detached_id)), "visible square centers remain hittable after zooming and scrolling")
	view.graph_edit.zoom = 1.0
	view.graph_edit.scroll_offset = Vector2.ZERO
	view.graph_edit.begin_manual_connection(StringName(str(sequence_id)), view.graph_edit._output_port_position(sequence_graph_node))
	view.graph_edit.finish_manual_connection(Vector2(-500.0, -500.0))
	_expect(view.current_tree.find_node(detached_id).parent_id == -1 and not view.graph_edit.manual_connection_active, "releasing a connection over empty canvas cancels safely")
	view._on_connection_request(str(sequence_id), 0, str(detached_id), 0)
	_expect(view.current_tree.find_node(detached_id).parent_id == sequence_id, "programmatic connection path remains available")
	view._on_connection_request(str(action_id), 0, str(sequence_id), 0)
	_expect(view.current_tree.find_node(sequence_id).parent_id == 1, "editor rejects leaf as parent")
	view._on_connection_request(str(detached_id), 0, str(sequence_id), 0)
	_expect(view.current_tree.find_node(sequence_id).parent_id == 1, "editor rejects cycle creation")

	view._on_disconnection_request(str(sequence_id), 0, str(detached_id), 0)
	_expect(view.current_tree.find_node(detached_id).parent_id == -1, "editor disconnects child")
	view._undo()
	_expect(view.current_tree.find_node(detached_id).parent_id == sequence_id, "undo restores disconnected edge")
	view._redo()
	_expect(view.current_tree.find_node(detached_id).parent_id == -1, "redo removes edge again")

	view.selected_node_id = action_id
	view._attach_decorator_to_selected("Can Run", {"mode": "blackboard", "blackboard_key": "ready", "operator": "equals", "value": true})
	var decorator_id := view.current_tree.get_decorators_of(action_id)[0].id
	_expect(view.current_tree.find_node(decorator_id).decorator_parent_id == action_id, "editor attaches Decorator")
	view.selected_node_id = sequence_id
	view._delete_selected_node()
	_expect(view.current_tree.find_node(sequence_id) == null and view.current_tree.find_node(action_id) == null and view.current_tree.find_node(decorator_id) == null, "deleting subtree also deletes attached Decorators")
	view._undo()
	_expect(view.current_tree.find_node(sequence_id) != null and view.current_tree.find_node(action_id) != null and view.current_tree.find_node(decorator_id) != null, "undo restores deleted subtree and Decorators")
	view._redo()
	_expect(view.current_tree.find_node(sequence_id) == null, "redo deletes restored subtree")
	view._undo()

	view.selected_node_id = action_id
	var graph_node := _graph_node(view, action_id)
	var old_position := view.current_tree.find_node(action_id).position
	view._on_graph_node_drag_started(action_id)
	graph_node.manual_dragging = true
	graph_node.position_offset = old_position + Vector2(137.0, 59.0)
	view._on_graph_node_position_changed(graph_node)
	_expect(view.current_tree.find_node(action_id).position.is_equal_approx(old_position), "large-tree drag defers resource writes until pointer release")
	view._on_graph_node_drag_finished(action_id)
	graph_node.manual_dragging = false
	_expect(view.current_tree.find_node(action_id).position.is_equal_approx(old_position + Vector2(137.0, 59.0)), "drag persists resource position")
	view._undo()
	_expect(view.current_tree.find_node(action_id).position.is_equal_approx(old_position), "drag movement is undoable")
	view._redo()
	_expect(view.current_tree.find_node(action_id).position.is_equal_approx(old_position + Vector2(137.0, 59.0)), "drag movement is redoable")

	view.selected_node_id = action_id
	view._refresh_inspector()
	var parameters_before: Dictionary = view.current_tree.find_node(action_id).parameters.duplicate(true)
	view.node_parameters_edit.text = "{ invalid json"
	view._on_node_fields_changed()
	_expect(view.current_tree.find_node(action_id).parameters == parameters_before, "invalid inspector JSON never destroys parameters")
	view.node_parameters_edit.text = "{\"action_name\": \"success_action\", \"speed\": 2}"
	view._on_node_fields_changed()
	_expect(view.current_tree.find_node(action_id).parameters.get("speed") == 2, "valid inspector JSON updates parameters")


func _test_typed_parameter_inspector(view: BTEditorView) -> void:
	var tree := BTTreeResource.new()
	tree.tree_name = "Typed Inspector Test"
	var schema := BTBlackboardSchema.new()
	schema.entries = [_blackboard_entry("ready", BTBlackboardEntry.VALUE_TYPE_BOOL, true), _blackboard_entry("health", BTBlackboardEntry.VALUE_TYPE_INT, 100)]
	tree.blackboard_schema = schema
	tree.root_node_id = 1
	var root_node := _node(1, BTNodeResource.TYPE_ROOT, -1, "Root", 100.0, 80.0)
	var action := _node(2, BTNodeResource.TYPE_ACTION, 1, "Action", 100.0, 360.0)
	action.parameters = {"action_name": "old_method", "custom_speed": 4}
	var condition := _node(3, BTNodeResource.TYPE_CONDITION, 1, "Condition", 430.0, 360.0)
	condition.parameters = {"condition_name": "can_see_player"}
	var selector := _node(4, BTNodeResource.TYPE_SELECTOR, 1, "Selector", 760.0, 360.0)
	selector.parameters = {"reactive": false}
	var parallel := _node(5, BTNodeResource.TYPE_PARALLEL, 1, "Parallel", 1090.0, 360.0)
	parallel.parameters = {"success_policy": "all", "failure_policy": "any"}
	var random_selector := _node(6, BTNodeResource.TYPE_RANDOM_SELECTOR, 1, "Random", 1420.0, 360.0)
	random_selector.parameters = {"seed": -1}
	var repeat := _node(7, BTNodeResource.TYPE_REPEAT, 1, "Repeat", 1750.0, 360.0)
	repeat.parameters = {"repeat_count": -1}
	var wait := _node(8, BTNodeResource.TYPE_WAIT, 1, "Wait", 2080.0, 360.0)
	wait.parameters = {"duration": 1.0}
	var decorator := _node(9, BTNodeResource.TYPE_DECORATOR, -1, "Decorator", 0.0, 0.0)
	decorator.decorator_parent_id = 2
	decorator.parameters = {"mode": "blackboard", "blackboard_key": "ready", "operator": "equals", "value": true, "invert": false}
	tree.nodes = [root_node, action, condition, selector, parallel, random_selector, repeat, wait, decorator]
	view.current_tree = tree
	view.current_tree_path = "res://behavior_trees/typed_inspector_test.tres"
	view.undo_stack.clear()
	view.redo_stack.clear()
	view._refresh_entire_ui()

	view.selected_node_id = 2
	view._refresh_inspector()
	_expect(view.parameter_controls.get("action_name") is LineEdit, "typed Inspector shows Action method field")
	var action_method := view.parameter_controls.get("action_name") as LineEdit
	action_method.text = "attack_target"
	view._on_typed_parameter_changed()
	_expect(action.parameters.get("action_name") == "attack_target" and action.parameters.get("custom_speed") == 4, "typed Action field updates method and preserves custom parameters")
	view._undo()
	_expect(view.current_tree.find_node(2).parameters.get("action_name") == "old_method", "typed parameter edit is undoable")
	view._redo()
	_expect(view.current_tree.find_node(2).parameters.get("action_name") == "attack_target", "typed parameter edit is redoable")
	action = view.current_tree.find_node(2)
	condition = view.current_tree.find_node(3)
	selector = view.current_tree.find_node(4)
	parallel = view.current_tree.find_node(5)
	random_selector = view.current_tree.find_node(6)
	repeat = view.current_tree.find_node(7)
	wait = view.current_tree.find_node(8)
	decorator = view.current_tree.find_node(9)

	view.selected_node_id = 3
	view._refresh_inspector()
	_expect(view.parameter_rows.get("condition_name").visible and not view.parameter_rows.get("blackboard_key").visible, "Condition actor mode shows only actor method fields")
	var condition_mode := view.parameter_controls.get("__condition_mode") as OptionButton
	condition_mode.select(1)
	view._on_typed_parameter_changed(true)
	var condition_key := view.parameter_controls.get("blackboard_key") as LineEdit
	var condition_key_picker := view.parameter_controls.get("__blackboard_key_picker") as OptionButton
	var condition_operator := view.parameter_controls.get("operator") as OptionButton
	var condition_value := view.parameter_controls.get("expected") as LineEdit
	_expect(condition_key_picker.item_count == 3 and _option_index_for_metadata(condition_key_picker, "health") > 0, "Blackboard Inspector lists every declared Schema key")
	condition_key_picker.select(_option_index_for_metadata(condition_key_picker, "health"))
	condition_key.text = str(condition_key_picker.get_item_metadata(condition_key_picker.selected))
	condition_operator.select(_option_index_for_metadata(condition_operator, ">"))
	condition_value.text = "25"
	view._on_typed_parameter_changed()
	_expect(condition.parameters.get("condition_name") == "" and condition.parameters.get("blackboard_key") == "health" and condition.parameters.get("operator") == ">" and condition.parameters.get("expected") == 25, "typed Condition configures blackboard operator and JSON value")
	condition_key.text = "dynamic_runtime_key"
	view._on_typed_parameter_changed()
	_expect(condition.parameters.get("blackboard_key") == "dynamic_runtime_key", "Blackboard Inspector preserves free typing for dynamic keys")
	_expect(view.parameter_rows.get("blackboard_key").visible and not view.parameter_rows.get("condition_name").visible, "Condition blackboard mode updates field visibility")

	view.selected_node_id = 4
	view._refresh_inspector()
	var reactive := view.parameter_controls.get("reactive") as CheckBox
	reactive.button_pressed = true
	view._on_typed_parameter_changed()
	_expect(selector.parameters.get("reactive") == true, "typed Selector toggles reactive execution")

	view.selected_node_id = 5
	view._refresh_inspector()
	var success_policy := view.parameter_controls.get("success_policy") as OptionButton
	var failure_policy := view.parameter_controls.get("failure_policy") as OptionButton
	success_policy.select(_option_index_for_metadata(success_policy, "any"))
	failure_policy.select(_option_index_for_metadata(failure_policy, "all"))
	view._on_typed_parameter_changed()
	_expect(parallel.parameters.get("success_policy") == "any" and parallel.parameters.get("failure_policy") == "all", "typed Parallel fields update both policies")

	view.selected_node_id = 6
	view._refresh_inspector()
	var seed := view.parameter_controls.get("seed") as SpinBox
	seed.value = 42
	view._on_typed_parameter_changed()
	_expect(random_selector.parameters.get("seed") == 42, "typed Random Selector updates deterministic seed")

	view.selected_node_id = 7
	view._refresh_inspector()
	var repeat_count := view.parameter_controls.get("repeat_count") as SpinBox
	repeat_count.value = 3
	view._on_typed_parameter_changed()
	_expect(repeat.parameters.get("repeat_count") == 3, "typed Repeat updates iteration count")

	view.selected_node_id = 8
	view._refresh_inspector()
	var duration := view.parameter_controls.get("duration") as SpinBox
	duration.value = 2.5
	view._on_typed_parameter_changed()
	_expect(is_equal_approx(float(wait.parameters.get("duration")), 2.5), "typed Wait updates duration")

	view.selected_node_id = 9
	view._refresh_inspector()
	_expect(view.parameter_controls.get("mode") is OptionButton and view.parameter_rows.get("blackboard_key").visible, "typed Decorator shows mode-specific blackboard fields")
	var decorator_mode := view.parameter_controls.get("mode") as OptionButton
	decorator_mode.select(_option_index_for_metadata(decorator_mode, "cooldown"))
	view._on_typed_parameter_changed(true)
	var decorator_duration := view.parameter_controls.get("duration") as SpinBox
	decorator_duration.value = 1.75
	view._on_typed_parameter_changed()
	_expect(decorator.parameters.get("mode") == "cooldown" and is_equal_approx(float(decorator.parameters.get("duration")), 1.75), "typed Decorator configures cooldown duration")
	_expect(view.parameter_rows.get("duration").visible and not view.parameter_rows.get("blackboard_key").visible, "Decorator mode hides irrelevant fields")

	view.advanced_parameters_toggle.button_pressed = true
	view._on_advanced_parameters_toggled(true)
	_expect(view.node_parameters_edit.visible and "cooldown" in view.node_parameters_edit.text, "Advanced JSON remains available and synchronized")


func _option_index_for_metadata(option: OptionButton, value: String) -> int:
	for index in range(option.item_count):
		if str(option.get_item_metadata(index)) == value:
			return index
	return 0


func _test_live_blackboard_panel(view: BTEditorView) -> void:
	view.current_tree = _make_view_tree()
	view.current_tree_path = "res://behavior_trees/live_blackboard_test.tres"
	view._refresh_entire_ui()
	_expect(view.blackboard_toggle != null and view.blackboard_panel != null and not view.blackboard_panel.visible, "Live Blackboard panel is available and collapsed by default")
	view.blackboard_toggle.button_pressed = true
	view._on_blackboard_panel_toggled(true)
	_expect(view.blackboard_panel.visible, "Live Blackboard has an independent visibility switch")
	var snapshot := {
		"actor": "SchemaNPC",
		"tree_path": view.current_tree_path,
		"path_ids": [1, 2, 3, 4],
		"path_titles": ["Root", "Decision", "Combat", "Attack Target"],
		"path_text": "Root > Decision > Combat > Attack Target",
		"leaf_status_text": "RUNNING",
		"failure_reasons": {},
		"blackboard": {"temporary_timer": 0.25, "health": "wrong", "player_detected": true},
		"blackboard_schema_types": {"health": "Int", "player_detected": "Bool"},
		"blackboard_schema_errors": ["Blackboard key 'health' expected Int, got String."],
	}
	view._apply_runtime_snapshot(snapshot)
	var table_text := _collect_label_text(view.blackboard_grid)
	_expect("SchemaNPC" in view.blackboard_summary_label.text and "3 keys" in view.blackboard_summary_label.text and "1 schema errors" in view.blackboard_summary_label.text, "Live Blackboard identifies actor, key count, and schema errors")
	_expect("health" in table_text and "ERROR" in table_text and "player_detected" in table_text and "Bool" in table_text, "Live Blackboard renders declared values and type errors")
	_expect("temporary_timer" in table_text and "Dynamic" in table_text, "Live Blackboard distinguishes dynamic runtime keys")
	_expect(view.blackboard_grid.get_child_count() == 16, "Live Blackboard creates a four-column row for every key")
	_expect(_grid_has_tooltip(view.blackboard_grid, "expected Int"), "Live Blackboard exposes complete schema error tooltip")

	var next_snapshot := snapshot.duplicate(true)
	next_snapshot["blackboard"] = {"health": 80}
	next_snapshot["blackboard_schema_errors"] = []
	view._apply_runtime_snapshot(next_snapshot)
	table_text = _collect_label_text(view.blackboard_grid)
	_expect("80" in table_text and not "temporary_timer" in table_text and "0 schema errors" in view.blackboard_summary_label.text, "Live Blackboard replaces stale values on every runtime frame")
	view._clear_runtime_highlights()
	_expect("0 keys" in view.blackboard_summary_label.text and "No blackboard values" in _collect_label_text(view.blackboard_grid), "stopping Live Debug clears Live Blackboard values")
	view._on_blackboard_panel_toggled(false)
	_expect(not view.blackboard_panel.visible, "Live Blackboard switch safely hides the panel")


func _test_blackboard_schema_editor(view: BTEditorView) -> void:
	view.current_tree = _make_view_tree()
	view.current_tree_path = "res://behavior_trees/schema_editor_test.tres"
	view.undo_stack.clear()
	view.redo_stack.clear()
	view._on_schema_panel_toggled(false)
	view._refresh_entire_ui()
	_expect(view.schema_toggle != null and view.schema_panel != null and not view.schema_panel.visible, "Schema authoring panel is available and independently collapsed")
	view._on_schema_panel_toggled(true)
	_expect(view.schema_panel.visible and not view.blackboard_panel.visible, "Schema authoring opens separately from Live Blackboard")
	_expect(view.current_tree.blackboard_schema == null and "0 keys" in view.schema_summary_label.text, "Tree without a schema renders an empty authoring state")

	for unused in range(5):
		view._add_schema_entry()
	_expect(view.current_tree.blackboard_schema != null and view.current_tree.blackboard_schema.entries.size() == 5 and view.schema_row_controls.size() == 5, "Schema editor creates typed declarations on an empty tree schema")

	var definitions := [
		["player_detected", BTBlackboardEntry.VALUE_TYPE_BOOL, true, "Whether perception has a target"],
		["health", BTBlackboardEntry.VALUE_TYPE_INT, 100, "Current actor health"],
		["distance", BTBlackboardEntry.VALUE_TYPE_FLOAT, 12.5, "Distance to target"],
		["state", BTBlackboardEntry.VALUE_TYPE_STRING, "patrol", "Current decision state"],
		["target_position", BTBlackboardEntry.VALUE_TYPE_VECTOR2, Vector2(10.0, 20.0), "Last known target position"],
	]
	for index in range(definitions.size()):
		view._set_schema_key(index, definitions[index][0])
		view._set_schema_type(index, BTBlackboardEntry.SUPPORTED_TYPES.find(definitions[index][1]))
		view._set_schema_default(index, definitions[index][2])
		view._set_schema_description(index, definitions[index][3])
	var schema = view.current_tree.blackboard_schema
	view.current_tree.find_node(6).parameters["blackboard_key"] = "player_detected"
	view._refresh_schema_editor()
	_expect(schema.entries[0].default_value == true and typeof(schema.entries[1].default_value) == TYPE_INT and typeof(schema.entries[2].default_value) == TYPE_FLOAT, "Schema editor stores Bool, Int, and Float defaults with exact types")
	_expect(schema.entries[3].default_value == "patrol" and schema.entries[4].default_value == Vector2(10.0, 20.0), "Schema editor stores String and Vector2 defaults")
	_expect(schema.entries[4].description == "Last known target position" and " - valid;" in view.schema_summary_label.text.to_lower(), "Schema descriptions update and the valid summary refreshes immediately")
	_expect("1 referenced, 4 unused" in view.schema_summary_label.text and "player_detected: #6 Can Attack" in view.schema_summary_label.tooltip_text, "Schema summary reports reference count, unused keys, and exact node location")

	view._set_schema_type(3, BTBlackboardEntry.SUPPORTED_TYPES.find(BTBlackboardEntry.VALUE_TYPE_INT))
	_expect(typeof(schema.entries[3].default_value) == TYPE_INT and schema.entries[3].default_value == 0, "Changing an incompatible schema type resets its default safely")
	view._set_schema_type(3, BTBlackboardEntry.SUPPORTED_TYPES.find(BTBlackboardEntry.VALUE_TYPE_STRING))
	view._set_schema_default(3, "patrol")

	view._on_schema_dynamic_keys_toggled(false)
	_expect(not schema.allow_dynamic_keys, "Schema editor persists the strict dynamic-key policy")
	view._set_schema_key(4, "health")
	_expect(not schema.validate_schema().is_empty() and "validation error" in view.schema_summary_label.text, "Duplicate schema keys show immediate validation feedback")
	view._undo()
	schema = view.current_tree.blackboard_schema
	_expect(schema.entries[4].key == "target_position" and schema.validate_schema().is_empty(), "Undo restores the schema before an invalid duplicate edit")
	view._redo()
	schema = view.current_tree.blackboard_schema
	_expect(schema.entries[4].key == "health" and not schema.validate_schema().is_empty(), "Redo reapplies the schema edit")
	view._undo()
	schema = view.current_tree.blackboard_schema
	view._set_schema_key(0, "")
	_expect("empty key" in view.schema_summary_label.tooltip_text, "Empty schema keys expose the complete validation reason")
	view._undo()
	schema = view.current_tree.blackboard_schema

	view._remove_schema_entry(4)
	_expect(view.current_tree.blackboard_schema.entries.size() == 4 and view.schema_row_controls.size() == 4, "Schema editor removes a declaration and refreshes its rows")
	view._undo()
	schema = view.current_tree.blackboard_schema
	_expect(schema.entries.size() == 5 and schema.find_entry("target_position") != null, "Undo restores a removed schema declaration")

	var path := "user://bt_schema_editor_round_trip.tres"
	var save_error := ResourceSaver.save(view.current_tree, path)
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as BTTreeResource
	_expect(save_error == OK and loaded != null and loaded.blackboard_schema != null, "Schema authored in the editor saves with the behavior tree")
	_expect(loaded.blackboard_schema.entries.size() == 5 and loaded.blackboard_schema.find_entry("target_position").default_value == Vector2(10.0, 20.0) and not loaded.blackboard_schema.allow_dynamic_keys, "Schema editor values and policy survive resource reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	var runtime_snapshot := {
		"actor": "SchemaEditorNPC", "tree_path": view.current_tree_path,
		"path_ids": [], "path_titles": [], "leaf_status_text": "IDLE", "failure_reasons": {},
		"blackboard": {"health": 80}, "blackboard_schema_types": {"health": "Int"}, "blackboard_schema_errors": [],
	}
	view._apply_runtime_snapshot(runtime_snapshot)
	view._on_blackboard_panel_toggled(true)
	_expect(view.schema_panel.visible and view.blackboard_panel.visible and "health" in _collect_label_text(view.blackboard_grid), "Live Blackboard remains functional and visually separate while schema authoring is open")
	view._on_blackboard_panel_toggled(false)
	view._on_schema_panel_toggled(false)
	_expect(not view.schema_panel.visible and not view.blackboard_panel.visible, "Both blackboard panels hide without leaving UI residue")


func _collect_label_text(parent: Node) -> String:
	var values: Array[String] = []
	for child in parent.get_children():
		if child is Label:
			values.append(child.text)
	return " | ".join(values)


func _grid_has_tooltip(parent: Node, expected: String) -> bool:
	for child in parent.get_children():
		if child is Control and expected in child.tooltip_text:
			return true
	return false


func _test_live_debug_bridge_resilience(view: BTEditorView) -> void:
	view.current_tree = _make_view_tree()
	view.current_tree_path = "res://behavior_trees/live_debug_resilience.tres"
	view.file_path_edit.text = view.current_tree_path
	view._refresh_entire_ui()
	view.runtime_debug_enabled = true
	var bridge_path := "res://.godot/behavior_tree_runtime_debug.json"
	var snapshot_before_corruption: Dictionary = view.last_runtime_snapshot.duplicate(true)
	var file := FileAccess.open(bridge_path, FileAccess.WRITE)
	file.store_string("{\"version\": 1, \"components\": [")
	file.close()
	view.runtime_debug_elapsed = 0.0
	view._poll_runtime_debug(1.0)
	_expect(view.last_runtime_snapshot == snapshot_before_corruption, "Live Debug ignores truncated JSON and preserves the previous frame")

	var payload := {
		"version": 1,
		"timestamp_unix": Time.get_unix_time_from_system(),
		"components": [{
			"actor": "BridgeActor", "tree_path": view.current_tree_path,
			"path_ids": [1, 2, 3, 4], "path_titles": ["Root", "Decision", "Combat", "Attack Target"],
			"leaf_status_text": "RUNNING", "failure_reasons": {},
		}],
	}
	file = FileAccess.open(bridge_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
	view.runtime_debug_elapsed = 0.0
	view._poll_runtime_debug(1.0)
	_expect(view.last_runtime_snapshot.get("actor", "") == "BridgeActor" and _graph_node(view, 4).runtime_active, "Live Debug recovers on next complete snapshot")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bridge_path))


func _test_display_feature_switches(view: BTEditorView) -> void:
	view._set_feature_enabled("fisheye", true, false)
	_expect(view.fisheye_enabled, "fisheye switch enables feature")
	view._set_feature_enabled("fisheye", false, false)
	_expect(_all_node_scales_reset(view), "fisheye switch restores all node scales")

	view.current_tree.find_node(2).collapsed = true
	view._set_feature_enabled("subtree_collapse", true, false)
	_expect(_graph_node_count(view) == 2, "subtree collapse switch hides descendants")
	view._set_feature_enabled("subtree_collapse", false, false)
	_expect(_graph_node_count(view) == 5, "disabling subtree collapse restores descendants")
	view.current_tree.find_node(2).collapsed = false

	view._set_feature_enabled("compact", true, false)
	_expect(_graph_node(view, 2).compact_mode and _graph_node(view, 2).custom_minimum_size.x == BTGraphNode.COMPACT_CARD_SIZE.x, "compact switch reduces cards")
	view._set_feature_enabled("compact", false, false)
	_expect(_graph_node(view, 2).custom_minimum_size.x == BTGraphNode.NORMAL_CARD_SIZE.x, "disabling compact restores cards")

	view._set_feature_enabled("type_encoding", true, false)
	_expect(_graph_node(view, 2).type_icon.visible and _graph_node(view, 2).type_icon.node_type == BTNodeResource.TYPE_SELECTOR, "type encoding switch shows the correct geometric node identity")
	view._set_feature_enabled("compact", true, false)
	view._set_feature_enabled("semantic_zoom", true, false)
	view.semantic_detail_level = 0
	view._apply_semantic_detail_level()
	_expect(_graph_node(view, 2).type_icon.visible and not _graph_node(view, 2).type_badge.visible, "type icon remains visible at compact low-detail zoom")
	view._set_feature_enabled("type_encoding", false, false)
	_expect(not _graph_node(view, 2).type_icon.visible, "disabling type encoding removes every icon without changing the node")
	view._set_feature_enabled("compact", false, false)
	view._set_feature_enabled("semantic_zoom", false, false)

	var baseline_selector_color := _graph_node(view, 2).header_bar.color
	view._set_feature_enabled("accessibility", true, false)
	_expect(_graph_node(view, 2).accessible_palette_enabled and _graph_node(view, 2).header_bar.color == Color("e69f00"), "accessibility switch applies the colorblind-safe Selector color")
	_expect("Ctrl+F" in view.search_edit.tooltip_text and "F3" in view.search_next_button.tooltip_text, "accessibility controls expose keyboard shortcuts through tooltips")
	view._on_search_changed("attack")
	var f3 := InputEventKey.new()
	f3.keycode = KEY_F3
	f3.pressed = true
	view._gui_input(f3)
	_expect(view.selected_node_id == 4 and view.search_result_index == 0, "F3 navigates to the next search result when accessibility is enabled")
	var ctrl_f := InputEventKey.new()
	ctrl_f.keycode = KEY_F
	ctrl_f.ctrl_pressed = true
	ctrl_f.pressed = true
	view._gui_input(ctrl_f)
	_expect(view.search_edit.has_focus(), "Ctrl+F focuses the node search field inside the behavior-tree panel")
	view._set_feature_enabled("accessibility", false, false)
	_expect(not _graph_node(view, 2).accessible_palette_enabled and _graph_node(view, 2).header_bar.color == baseline_selector_color, "disabling accessibility restores the original palette")

	view._set_feature_enabled("single_connection", true, false)
	var parent_graph := _graph_node(view, 2)
	var child_graph := _graph_node(view, 3)
	var edge_points := view.graph_edit._route_connection_line(
		parent_graph.position + Vector2(parent_graph.size.x * 0.5, parent_graph.size.y),
		child_graph.position + Vector2(child_graph.size.x * 0.5, 0.0)
	)
	var edge_hit := view.graph_edit.find_connection_at(edge_points[edge_points.size() / 2], 12.0)
	_expect(view.graph_edit.single_connection_rendering_enabled and view.graph_edit.connection_lines_thickness == 0.0 and not view.graph_edit.native_connection_layer.visible and not edge_hit.is_empty(), "single-connection mode hides native lines and provides custom edge hit testing")
	view.graph_edit.connection_route_cache.clear()
	var cached_edge := view.graph_edit._cached_connection_line("2>3", edge_points[0], edge_points[edge_points.size() - 1])
	var cached_edge_repeat := view.graph_edit._cached_connection_line("2>3", edge_points[0], edge_points[edge_points.size() - 1])
	var moved_cached_edge := view.graph_edit._cached_connection_line("2>3", edge_points[0] + Vector2(12.0, 0.0), edge_points[edge_points.size() - 1])
	_expect(cached_edge == cached_edge_repeat and view.graph_edit.connection_route_cache.size() == 1 and moved_cached_edge[0].is_equal_approx(edge_points[0] + Vector2(12.0, 0.0)), "connection route cache reuses stable edges and invalidates a moved endpoint")
	view._on_custom_edge_disconnect_requested(StringName("2"), StringName("3"))
	_expect(view.current_tree.find_node(3).parent_id == -1 and view.graph_edit.get_connection_list().size() == 3, "custom edge interaction disconnects exactly one resource connection")
	view._undo()
	_expect(view.current_tree.find_node(3).parent_id == 2 and view.graph_edit.get_connection_list().size() == 4, "custom edge disconnection is undoable")
	view._redo()
	_expect(view.current_tree.find_node(3).parent_id == -1, "custom edge disconnection is redoable")
	view._undo()
	view._set_feature_enabled("single_connection", false, false)
	_expect(not view.graph_edit.single_connection_rendering_enabled and view.graph_edit.connection_lines_thickness == 3.5 and view.graph_edit.native_connection_layer.visible and not _graph_node(view, 2).single_connection_rendering_enabled, "disabling single-connection mode restores one native editable line")
	view._set_feature_enabled("single_connection", true, false)
	_expect(view.graph_edit.connection_lines_thickness == 0.0 and not view.graph_edit.native_connection_layer.visible and _graph_node(view, 2).single_connection_rendering_enabled, "re-enabling single-connection mode restores custom rendering without graph changes")

	var snapshot := {
		"actor": "TestActor", "path_ids": [1, 2, 3, 4],
		"path_titles": ["Root", "Decision", "Combat", "Attack Target"],
		"path_text": "Root > Decision > Combat > Attack Target",
		"leaf_status_text": "FAILURE", "failure_reasons": {4: "Actor method failed"},
	}
	view._set_feature_enabled("active_path", true, false)
	view._apply_runtime_snapshot(snapshot)
	_expect(_graph_node(view, 4).runtime_active and view.graph_edit.active_path_ids.size() == 4, "active path switch highlights nodes and path")
	view._set_feature_enabled("active_path", false, false)
	_expect(not _graph_node(view, 4).runtime_highlight_enabled and view.graph_edit.active_path_ids.is_empty(), "disabling active path removes highlight")

	view._set_feature_enabled("branch_dimming", true, false)
	view._apply_runtime_snapshot(snapshot)
	_expect(view.branch_dimming_toggle.button_pressed, "branch dimming toolbar switch mirrors feature state")
	_expect(is_equal_approx(_graph_node(view, 5).modulate.a, BTGraphNode.INACTIVE_BRANCH_ALPHA), "branch dimming uses measured inactive opacity")
	_expect(is_equal_approx(_graph_node(view, 4).modulate.a, 1.0), "branch dimming preserves active path opacity")
	var patrol_snapshot := {
		"actor": "TestActor", "path_ids": [1, 2, 5],
		"path_titles": ["Root", "Decision", "Patrol"],
		"path_text": "Root > Decision > Patrol", "leaf_status_text": "RUNNING",
	}
	view._apply_runtime_snapshot(patrol_snapshot)
	_expect(is_equal_approx(_graph_node(view, 4).modulate.a, BTGraphNode.INACTIVE_BRANCH_ALPHA) and is_equal_approx(_graph_node(view, 5).modulate.a, 1.0), "branch dimming follows runtime path changes")
	view._apply_runtime_snapshot({"actor": "TestActor", "path_ids": [], "path_titles": [], "leaf_status_text": "UNKNOWN"})
	_expect(_all_node_opacities_reset(view), "empty runtime path never dims the whole tree")
	view._apply_runtime_snapshot(snapshot)
	view._on_live_debug_toggled(false)
	_expect(_all_node_opacities_reset(view), "stopping Live Debug restores every branch")
	view._on_live_debug_toggled(true)
	view._apply_runtime_snapshot(snapshot)
	view._set_feature_enabled("branch_dimming", false, false)
	_expect(not view.branch_dimming_toggle.button_pressed and _all_node_opacities_reset(view), "disabling branch dimming restores opacity")

	var fanout_tree := _make_fanout_tree()
	view.current_tree = fanout_tree
	view.selected_node_id = 2
	view._set_feature_enabled("multi_column", true, false)
	view._set_feature_enabled("stable_layout", false, false)
	var before_order := _child_ids(view.current_tree, 2)
	view._auto_arrange_tree()
	var after_order := _child_ids(view.current_tree, 2)
	_expect(_distinct_child_rows(view.current_tree, 2) > 1 and before_order == after_order, "multi-column layout wraps fan-out without changing order")
	view._set_feature_enabled("multi_column", false, false)
	view._auto_arrange_tree()
	_expect(_distinct_child_rows(view.current_tree, 2) == 1, "disabling multi-column restores one-row layout")
	var regular_layout_width := _resource_layout_bounds(view.current_tree).size.x
	view._auto_arrange_tree(true)
	var overview_layout_width := _resource_layout_bounds(view.current_tree).size.x
	view._set_feature_enabled("semantic_zoom", true, false)
	view.semantic_detail_level = 0
	view._apply_semantic_detail_level()
	view._update_auto_spacing(0.0, true)
	_expect(overview_layout_width < regular_layout_width, "overview arrange stores a denser default tree layout")
	_expect(_rendered_overlaps(view).is_empty(), "overview arrange keeps low-detail cards readable without temporary offsets")
	_expect(is_equal_approx(view.current_tree.find_node(4).position.x - view.current_tree.find_node(3).position.x, view.OVERVIEW_LAYOUT_HORIZONTAL_GAP), "overview arrange uses the low-detail card width plus a compact gap")
	view._undo()
	_expect(is_equal_approx(_resource_layout_bounds(view.current_tree).size.x, regular_layout_width), "overview arrange is undoable")
	view._set_feature_enabled("semantic_zoom", false, false)

	view._set_feature_enabled("enhanced_minimap", false, false)
	_expect(not view.graph_edit.minimap_enabled and not view.minimap_status_label.visible, "minimap switch disables overview")
	view._set_feature_enabled("enhanced_minimap", true, false)
	view._refresh_minimap_node_counts()
	view._update_minimap_status(true)
	_expect(view.graph_edit.minimap_enabled and view.minimap_toggle.button_pressed, "minimap switch restores overview")
	_expect(view.graph_edit.minimap_size.is_equal_approx(view.graph_edit.ENHANCED_MINIMAP_SIZE) and is_equal_approx(view.graph_edit.minimap_opacity, view.graph_edit.ENHANCED_MINIMAP_OPACITY), "enhanced minimap uses readable size and opacity")
	_expect("Overview 10/10 nodes" in view.minimap_status_label.text, "overview status reports complete node coverage")
	view.graph_edit.zoom = 0.75
	view._update_minimap_status()
	_expect("Detail 75%" in view.minimap_status_label.text, "overview status follows detail zoom")

	view._set_feature_enabled("semantic_zoom", true, false)
	view.graph_edit.zoom = 0.5
	view._update_semantic_zoom()
	_expect(view.semantic_detail_level == 0, "semantic zoom switch selects overview detail")
	view._set_feature_enabled("semantic_zoom", false, false)
	_expect(view.semantic_detail_level == 2, "disabling semantic zoom restores full detail")

	view.current_tree = _make_dense_zoom_tree()
	view._rebuild_graph()
	var dense_positions := _resource_positions(view.current_tree)
	view._set_feature_enabled("semantic_zoom", true, false)
	view._set_feature_enabled("auto_spacing", true, false)
	view.semantic_detail_level = 0
	view._apply_semantic_detail_level()
	view._update_auto_spacing(0.0, true)
	_expect(_rendered_overlaps(view).is_empty(), "dense overview is readable without expanding logical spacing")
	view.graph_edit.zoom = 1.0
	view.semantic_detail_level = 2
	view._apply_semantic_detail_level()
	view._update_auto_spacing(0.0, true)
	# GraphNode copies position_offset into its rendered Control position during
	# deferred layout. Wait before testing the same coordinates used for drawing.
	await process_frame
	await process_frame
	_expect(not _all_visual_offsets_zero(view), "zoom-aware auto spacing separates dense cards at full detail")
	_expect(_rendered_overlaps(view).is_empty(), "zoom-aware auto spacing resolves every dense-card overlap")
	_expect(_all_visual_offsets_nonnegative_y(view), "zoom-aware auto spacing never pulls lower nodes upward")
	_expect(_parent_child_gap_failures(view, view.AUTO_SPACING_CONNECTION_GAP).is_empty(), "zoom-aware auto spacing reserves visible parent-child connection channels")
	var connection_intersections := _connection_node_intersections(view)
	if not connection_intersections.is_empty():
		print("AUTO_SPACING_CONNECTION_INTERSECTIONS %s" % [connection_intersections])
	_expect(connection_intersections.is_empty(), "zoom-aware auto spacing keeps connections out of unrelated node cards")
	_expect(_resource_positions_equal(view.current_tree, dense_positions), "auto spacing never changes behavior-tree resource coordinates")
	view.semantic_detail_level = 0
	view._apply_semantic_detail_level()
	view._update_auto_spacing(0.0, true)
	view.graph_edit.zoom = 0.5
	view.graph_edit.scroll_offset = Vector2(260.0, 80.0)
	var viewport_center := view.graph_edit.size * 0.5
	view._on_graph_view_wheel_scrolled(viewport_center)
	var overview_samples := view.zoom_anchor_candidate_samples.duplicate(true)
	var overview_relation := _weighted_zoom_sample_relation(view, overview_samples, true)
	view.graph_edit.zoom = 1.0
	view._prepare_zoom_layout_anchor()
	view.semantic_detail_level = 2
	view._apply_semantic_detail_level()
	view._update_auto_spacing(0.0, true)
	view._restore_zoom_layout_anchor()
	var detail_relation := _weighted_zoom_sample_relation(view, overview_samples, false)
	_expect(detail_relation.distance_to(overview_relation) <= 0.01, "zoom-in layout preserves the viewport center's relative position within nearby nodes")
	view._clear_zoom_layout_anchor()
	view._on_graph_view_wheel_scrolled(viewport_center)
	var detail_samples := view.zoom_anchor_candidate_samples.duplicate(true)
	var detail_return_relation := _weighted_zoom_sample_relation(view, detail_samples, true)
	view.graph_edit.zoom = 0.5
	view._prepare_zoom_layout_anchor()
	view.semantic_detail_level = 0
	view._apply_semantic_detail_level()
	view._update_auto_spacing(0.0, true)
	view._restore_zoom_layout_anchor()
	var overview_return_relation := _weighted_zoom_sample_relation(view, detail_samples, false)
	_expect(overview_return_relation.distance_to(detail_return_relation) <= 0.01, "zoom-out layout preserves the viewport center's relative position within nearby nodes")
	view._set_feature_enabled("zoom_anchor", false, false)
	_expect(view.zoom_layout_anchor_id == -1 and view.zoom_anchor_candidate_id == -1, "disabling Zoom View Anchor clears all viewport compensation state")
	view._set_feature_enabled("zoom_anchor", true, false)
	_graph_node(view, 2).sync_to_resource()
	_expect(_resource_positions_equal(view.current_tree, dense_positions), "position synchronization excludes temporary visual offsets")
	view.semantic_detail_level = 0
	view._apply_semantic_detail_level()
	view._update_auto_spacing(0.0, true)
	_expect(_all_visual_offsets_zero(view) and _render_positions_match_resources(view), "zooming out restores the exact dense logical layout")
	view.semantic_detail_level = 2
	view._apply_semantic_detail_level()
	view._update_auto_spacing(0.0, true)
	view._set_feature_enabled("auto_spacing", false, false)
	_expect(_all_visual_offsets_zero(view) and _render_positions_match_resources(view), "disabling auto spacing clears all temporary layout residue")
	view._set_feature_enabled("semantic_zoom", false, false)

	view.current_tree = _make_dense_zoom_tree()
	view._rebuild_graph()
	var fisheye_positions := _resource_positions(view.current_tree)
	var fisheye_order := _child_ids(view.current_tree, 1)
	view._set_feature_enabled("fisheye", true, false)
	var focused_fisheye_node := _graph_node(view, 2)
	var fisheye_local_point := (focused_fisheye_node.position_offset + focused_fisheye_node.size * 0.5) * view.graph_edit.zoom - view.graph_edit.scroll_offset
	var fisheye_test_point := view.graph_edit.get_global_transform_with_canvas() * fisheye_local_point
	var fisheye_hit := view._fisheye_node_at(fisheye_test_point)
	_expect(fisheye_hit == focused_fisheye_node, "fisheye hit testing selects the node directly under the pointer")
	view._apply_fisheye_focus(focused_fisheye_node, 1.0)
	view._update_auto_spacing(0.0, true)
	_expect(_count_magnified_nodes(view) == 1 and _graph_node(view, 2).fisheye_magnification >= 1.24, "fisheye magnifies only the focused node")
	_expect(_all_unfocused_nodes_shrunk(view, 2), "fisheye shrinks every surrounding node")
	_expect(_rendered_overlaps(view).is_empty(), "fisheye context layout prevents card overlap")
	_expect(_child_ids(view.current_tree, 1) == fisheye_order and _rendered_child_order(view, 1) == fisheye_order, "fisheye preserves sibling left-to-right order")
	_expect(_rendered_parent_above_children(view), "fisheye preserves parent-above-child topology")
	_expect(_resource_positions_equal(view.current_tree, fisheye_positions), "fisheye layout never changes saved resource coordinates")
	view._reset_fisheye()
	view._update_auto_spacing(0.0, true)
	_expect(_all_fisheye_state_reset(view), "leaving fisheye restores scale and temporary layout offsets")

	view.current_tree = _make_view_tree()
	view.selected_node_id = 4
	view._rebuild_graph()
	view._set_feature_enabled("path_summary", true, false)
	view._apply_runtime_snapshot(snapshot)
	_expect(view.path_summary_toggle.button_pressed and view.runtime_path_scroll.visible, "path summary switch shows summary view")
	_expect(_button_count(view.runtime_path_container) == 4, "path summary creates clickable runtime path")
	_expect(view.runtime_path_actor_label.text == "Actor: TestActor" and view.runtime_path_status_label.text == "Status: FAILURE" and view.runtime_path_depth_label.text == "Depth: 4", "path summary reports actor status and depth")
	var current_path_button := _path_button_for_node(view, 4)
	_expect(current_path_button != null and bool(current_path_button.get_meta("is_current", false)) and current_path_button.text.begins_with("[CURRENT]"), "path summary marks current leaf")
	view._set_feature_enabled("subtree_collapse", true, false)
	view.current_tree.find_node(3).collapsed = true
	view._rebuild_graph()
	_expect(_graph_node(view, 4) == null, "path-summary target can begin inside collapsed subtree")
	current_path_button = _path_button_for_node(view, 4)
	current_path_button.pressed.emit()
	_expect(not view.current_tree.find_node(3).collapsed and view.selected_node_id == 4 and _graph_node(view, 4) != null, "path summary click expands and focuses hidden node")
	view._apply_runtime_snapshot(patrol_snapshot)
	_expect(_button_count(view.runtime_path_container) == 3 and "Depth: 3" == view.runtime_path_depth_label.text and bool(_path_button_for_node(view, 5).get_meta("is_current", false)), "path summary follows runtime path changes")
	view._apply_runtime_snapshot({"actor": "TestActor", "path_ids": [], "path_titles": [], "leaf_status_text": "UNKNOWN"})
	_expect(_button_count(view.runtime_path_container) == 0 and view.runtime_path_actor_label.text == "Actor: --" and view.runtime_path_status_label.text == "Status: IDLE" and view.runtime_path_depth_label.text == "Depth: 0", "path summary handles empty runtime path")
	view._set_feature_enabled("path_summary", false, false)
	_expect(not view.path_summary_toggle.button_pressed and not view.runtime_path_scroll.visible and not view.runtime_path_label.visible and view.runtime_path_container.get_child_count() == 0, "disabling path summary hides and clears summary view")

	view._set_feature_enabled("decorator_badges", true, false)
	_expect(_graph_node(view, 4).decorator_badges.visible, "decorator badge switch shows conditions")
	view._set_feature_enabled("decorator_badges", false, false)
	_expect(not _graph_node(view, 4).decorator_badges.visible, "disabling decorator badges hides conditions")

	view._set_feature_enabled("search", true, false)
	view._on_search_changed("attack target")
	_expect(view.search_result_ids == [4], "search finds node title across complete tree")
	view._on_search_changed("selector")
	_expect(view.search_result_ids == [2], "search finds node type")
	view._on_search_changed("description for patrol")
	_expect(view.search_result_ids == [5], "search finds node description")
	view._on_search_changed("attack_target")
	_expect(view.search_result_ids == [4], "search finds Action parameter")
	view._on_search_changed("can_attack")
	_expect(view.search_result_ids == [4], "search maps Decorator parameter match to owner node")
	view._on_search_changed("description")
	_expect(view.search_result_ids == [1, 2, 3, 4, 5] and view.search_result_label.text == "0/5 results", "search reports ordered match count")
	view._navigate_search_result(1)
	_expect(view.selected_node_id == 1 and view.search_result_label.text == "1/5 results" and _graph_node(view, 1).search_current, "search Next selects and highlights first result")
	view._navigate_search_result(-1)
	_expect(view.selected_node_id == 5 and view.search_result_label.text == "5/5 results" and _graph_node(view, 5).search_current, "search Previous wraps to final result")
	view._on_search_changed("attack_target")
	view._set_feature_enabled("subtree_collapse", true, false)
	view.current_tree.find_node(3).collapsed = true
	view._rebuild_graph()
	_expect(view.search_result_ids == [4] and _graph_node(view, 4) == null, "search indexes result hidden by collapsed subtree")
	view._on_search_submitted("attack_target")
	_expect(view.selected_node_id == 4 and not view.current_tree.find_node(3).collapsed and _graph_node(view, 4).search_current, "search Enter expands and focuses hidden result")
	view._on_search_changed("missing search value")
	_expect(view.search_result_ids.is_empty() and view.search_result_label.text == "No matches" and view.search_next_button.disabled, "search handles zero matches")
	view._on_search_changed("attack")
	_expect(_graph_node(view, 4).search_matches and not _graph_node(view, 5).search_matches, "search highlights matches and dims non-matches")
	view._set_feature_enabled("search", false, false)
	_expect(not view.search_toggle.button_pressed and view.search_query.is_empty() and view.search_result_ids.is_empty() and view.search_result_label.text == "0 results" and _graph_node(view, 5).self_modulate == Color.WHITE, "disabling search clears results and dimming")

	view._set_feature_enabled("orthogonal_edges", true, false)
	var orthogonal_line := view.graph_edit._get_connection_line(Vector2(10.0, 20.0), Vector2(90.0, 120.0))
	_expect(is_zero_approx(view.graph_edit.connection_lines_curvature) and orthogonal_line.size() == 4 and is_equal_approx(orthogonal_line[1].x, 10.0), "orthogonal edge switch creates right-angle route")
	view._set_feature_enabled("orthogonal_edges", false, false)
	_expect(is_equal_approx(view.graph_edit.connection_lines_curvature, 0.45), "disabling orthogonal edges restores baseline")

	view._set_feature_enabled("edge_bundling", true, false)
	var bundled_line := view.graph_edit._get_connection_line(Vector2(10.0, 20.0), Vector2(90.0, 120.0))
	_expect(view.graph_edit.connection_lines_curvature > 0.8 and bundled_line.size() == 4 and is_equal_approx(bundled_line[1].y, bundled_line[2].y), "edge bundling switch creates shared trunk route")
	view._set_feature_enabled("edge_bundling", false, false)
	_expect(is_equal_approx(view.graph_edit.connection_lines_curvature, 0.45), "disabling edge bundling restores baseline")

	var stable_position := view.current_tree.find_node(4).position
	view._set_feature_enabled("stable_layout", true, false)
	view._auto_arrange_tree()
	_expect(view.current_tree.find_node(4).position == stable_position, "stable layout preserves non-overlapping positions")
	view._set_feature_enabled("stable_layout", false, false)

	view.selected_node_id = 4
	view._set_feature_enabled("breadcrumb", true, false)
	view._refresh_navigation_paths()
	_expect(_button_count(view.selection_path_container) == 4, "breadcrumb switch shows selected hierarchy")
	view._set_feature_enabled("breadcrumb", false, false)
	_expect(view.selection_path_container.get_child_count() == 0, "disabling breadcrumb clears hierarchy")

	view._set_feature_enabled("failure_reason", true, false)
	var failure_snapshot := snapshot.duplicate(true)
	failure_snapshot["failure_reasons"] = {
		4: "Blackboard condition failed",
		6: "Blackboard 'can_attack' expected true, got false",
		5: "Actor method 'patrol' returned FAILURE",
		999: "Unknown node should be ignored",
		2: "",
	}
	view._apply_runtime_snapshot(failure_snapshot)
	_expect(view.failure_reason_toggle.button_pressed and view.failure_summary_button.visible, "failure reason switch shows annotation controls")
	_expect(view.visible_failure_annotations.size() == 2 and view.failure_summary_button.text == "Failures: 2" and view.failure_summary_button.get_popup().item_count == 2, "failure summary counts visible failed nodes")
	_expect(_graph_node(view, 4).failure_badge.visible and "FAIL: Decorator: Can Attack" in _graph_node(view, 4).failure_badge.text, "Decorator failure is mapped to owner with source label")
	_expect(_graph_node(view, 5).failure_badge.visible and "patrol" in _graph_node(view, 5).failure_badge.text, "Action failure receives node annotation")
	_expect(view.failure_summary_button.get_popup().get_item_text(0).begins_with("Attack Target:") and view.failure_summary_button.get_popup().get_item_text(1).begins_with("Patrol:"), "failure summary lists ordered reasons")
	view._on_failure_summary_selected(1)
	_expect(view.selected_node_id == 5, "failure summary item focuses failed node")
	var cleared_failure_snapshot := snapshot.duplicate(true)
	cleared_failure_snapshot["failure_reasons"] = {}
	view._apply_runtime_snapshot(cleared_failure_snapshot)
	_expect(view.failure_summary_button.text == "Failures: 0" and not _graph_node(view, 4).failure_badge.visible and not _graph_node(view, 5).failure_badge.visible, "new runtime frame clears resolved failures")
	view._apply_runtime_snapshot(failure_snapshot)
	view._on_live_debug_toggled(false)
	_expect(view.failure_summary_button.text == "Failures: 0" and not _graph_node(view, 4).failure_badge.visible, "stopping Live Debug clears failure annotations")
	view._on_live_debug_toggled(true)
	view._apply_runtime_snapshot(failure_snapshot)
	view._set_feature_enabled("failure_reason", false, false)
	_expect(not view.failure_reason_toggle.button_pressed and not view.failure_summary_button.visible and view.visible_failure_annotations.is_empty() and not _graph_node(view, 4).failure_badge.visible, "disabling failure reason removes annotations")

	for definition in view.FEATURE_DEFINITIONS:
		var key := str(definition[0])
		view._set_feature_enabled(key, true, false)
		view._set_feature_enabled(key, false, false)
	_expect(true, "all feature switches survive independent enable-disable cycles")
	for definition in view.FEATURE_DEFINITIONS:
		view._set_feature_enabled(str(definition[0]), true, false)
	view._apply_runtime_snapshot(snapshot)
	view._on_search_changed("attack")
	for definition in view.FEATURE_DEFINITIONS:
		view._set_feature_enabled(str(definition[0]), false, false)
	_expect(_all_feature_visual_residue_cleared(view), "disabling all features clears combined visual residue")
	var config := ConfigFile.new()
	view._populate_view_config(config)
	var persisted_count := 0
	for definition in view.FEATURE_DEFINITIONS:
		if config.has_section_key("features", str(definition[0])):
			persisted_count += 1
	_expect(persisted_count == view.FEATURE_DEFINITIONS.size(), "all feature switches are independently serializable")


func _test_compact_display_toolbar(view: BTEditorView) -> void:
	var popup := view.feature_menu_button.get_popup()
	var debug_popup := view.debug_menu_button.get_popup()
	var layout_popup := view.layout_menu_button.get_popup()
	var grid_index := popup.get_item_index(view.DISPLAY_MENU_GRID_ID)
	var main_toolbar := view.get_node_or_null("MainToolbar") as HBoxContainer
	var legacy_creation := view.get_node_or_null("LegacyCreationToolbar") as HBoxContainer
	_expect(main_toolbar != null and main_toolbar.visible, "one primary toolbar contains tree and common actions")
	_expect(not view.file_path_edit.visible and not view.tree_name_edit.visible, "internal resource path and duplicate tree-name fields stay hidden")
	var picker_labels_hide_paths := true
	for index in range(1, view.tree_path_picker.item_count):
		var picker_label := view.tree_path_picker.get_item_text(index)
		if "res://" in picker_label or "/" in picker_label or "\\" in picker_label:
			picker_labels_hide_paths = false
			break
	_expect(picker_labels_hide_paths, "tree picker shows readable names without resource paths")
	_expect(view.new_tree_dialog != null and view.new_tree_name_edit != null, "New opens a name-based workflow instead of requiring a path")
	_expect(legacy_creation != null and not legacy_creation.visible, "duplicate node creation toolbar stays hidden in favor of the canvas context menu")
	_expect(layout_popup.item_count == 9 and layout_popup.get_item_index(view.LAYOUT_MENU_FIT_ID) >= 0, "layout actions are consolidated into one menu")
	_expect(view.feature_menu_button.text == "Display", "display options use a compact menu label")
	_expect(popup.item_count == 10 and view.advanced_display_menu.item_count == 14 and grid_index >= 0, "Display shows common options and moves low-frequency switches into Advanced Display")
	_expect(not view.fisheye_toggle.visible and not view.compact_toggle.visible and not view.semantic_zoom_toggle.visible and not view.path_summary_toggle.visible and not view.grid_toggle.visible and not view.minimap_toggle.visible, "redundant display checkboxes stay hidden from the toolbar")
	var toolbar := view.get_node_or_null("ViewToolbar") as HBoxContainer
	_expect(toolbar != null and not toolbar.visible, "legacy view toolbar no longer consumes a separate row")
	var original_grid := view.graph_edit.show_grid
	view._on_feature_menu_pressed(view.DISPLAY_MENU_GRID_ID)
	_expect(view.graph_edit.show_grid != original_grid and popup.is_item_checked(grid_index) == view.graph_edit.show_grid, "Grid toggles and check mark synchronize through Display menu")
	view._on_feature_menu_pressed(view.DISPLAY_MENU_GRID_ID)
	var fisheye_index := popup.get_item_index(0)
	view._set_feature_enabled("fisheye", false, false)
	_expect(fisheye_index >= 0 and not popup.is_item_checked(fisheye_index) and not view.fisheye_toggle.button_pressed, "feature menu checks synchronize with compatibility state mirrors")
	view._set_feature_enabled("fisheye", true, false)
	_expect(view.debug_menu_button.text == "Debug" and debug_popup.item_count == 6, "runtime options use a compact Debug menu")
	_expect(not view.live_debug_toggle.visible and not view.branch_dimming_toggle.visible and not view.failure_reason_toggle.visible and not view.blackboard_toggle.visible and not view.schema_toggle.visible, "redundant runtime checkboxes stay hidden from the toolbar")
	_expect(not view.search_toggle.visible and view.search_edit.visible, "Search + Highlight uses the Display menu without hiding the search field")
	var runtime_toolbar := view.get_node_or_null("RuntimeToolbar") as HBoxContainer
	_expect(runtime_toolbar != null and runtime_toolbar.get_combined_minimum_size().x < 700.0, "compact runtime toolbar leaves room for Live Debug status")
	view._on_debug_menu_pressed(view.DEBUG_MENU_LIVE_ID)
	_expect(not view.runtime_debug_enabled and not debug_popup.is_item_checked(debug_popup.get_item_index(view.DEBUG_MENU_LIVE_ID)), "Debug menu toggles Live Debug and synchronizes its check mark")
	view._on_debug_menu_pressed(view.DEBUG_MENU_LIVE_ID)
	view._on_debug_menu_pressed(view.DEBUG_MENU_BLACKBOARD_ID)
	_expect(view.blackboard_panel.visible and debug_popup.is_item_checked(debug_popup.get_item_index(view.DEBUG_MENU_BLACKBOARD_ID)), "Debug menu opens Live Blackboard and synchronizes its check mark")
	view._on_debug_menu_pressed(view.DEBUG_MENU_BLACKBOARD_ID)
	view._on_debug_menu_pressed(view.DEBUG_MENU_SCHEMA_ID)
	_expect(view.schema_panel.visible and debug_popup.is_item_checked(debug_popup.get_item_index(view.DEBUG_MENU_SCHEMA_ID)), "Debug menu opens Schema authoring and synchronizes its check mark")
	view._on_debug_menu_pressed(view.DEBUG_MENU_SCHEMA_ID)


func _make_fanout_tree() -> BTTreeResource:
	var tree := BTTreeResource.new()
	tree.tree_name = "Fan-out Test"
	tree.root_node_id = 1
	tree.nodes.append(_node(1, BTNodeResource.TYPE_ROOT, -1, "Root", 600.0, 40.0))
	tree.nodes.append(_node(2, BTNodeResource.TYPE_SELECTOR, 1, "Wide Selector", 600.0, 250.0))
	for index in range(8):
		var child := _node(3 + index, BTNodeResource.TYPE_ACTION, 2, "Action %d" % (index + 1), 100.0 + index * 280.0, 500.0)
		child.parameters = {"action_name": "action_%d" % index}
		tree.nodes.append(child)
	return tree


func _make_dense_zoom_tree() -> BTTreeResource:
	var tree := BTTreeResource.new()
	tree.tree_name = "Dense Zoom Test"
	tree.root_node_id = 1
	tree.nodes = [
		_node(1, BTNodeResource.TYPE_ROOT, -1, "Dense Root", 540.0, 80.0),
		_node(2, BTNodeResource.TYPE_ACTION, 1, "Dense Left", 400.0, 245.0),
		_node(3, BTNodeResource.TYPE_ACTION, 1, "Dense Right", 680.0, 245.0),
	]
	return tree


func _resource_positions(tree: BTTreeResource) -> Dictionary:
	var positions := {}
	for node in tree.nodes:
		if node != null:
			positions[node.id] = node.position
	return positions


func _resource_layout_bounds(tree: BTTreeResource) -> Rect2:
	var initialized := false
	var bounds := Rect2()
	for node in tree.nodes:
		if node == null or node.decorator_parent_id != -1:
			continue
		var rect := Rect2(node.position, BTGraphNode.NORMAL_CARD_SIZE)
		bounds = bounds.merge(rect) if initialized else rect
		initialized = true
	return bounds


func _resource_positions_equal(tree: BTTreeResource, expected: Dictionary) -> bool:
	for node in tree.nodes:
		if node != null and not node.position.is_equal_approx(expected.get(node.id, Vector2.INF)):
			return false
	return true


func _all_visual_offsets_zero(view: BTEditorView) -> bool:
	for child in view.graph_edit.get_children():
		if child is BTGraphNode and not child.visual_offset.is_zero_approx():
			return false
	return true


func _all_visual_offsets_nonnegative_y(view: BTEditorView) -> bool:
	for child in view.graph_edit.get_children():
		if child is BTGraphNode and child.visual_offset.y < -0.01:
			return false
	return true


func _weighted_zoom_sample_relation(view: BTEditorView, samples: Array, use_recorded_relative: bool) -> Vector2:
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




func _render_positions_match_resources(view: BTEditorView) -> bool:
	for child in view.graph_edit.get_children():
		if child is BTGraphNode and not child.position_offset.is_equal_approx(child.node_resource.position):
			return false
	return true


func _rendered_overlaps(view: BTEditorView) -> Array[String]:
	var nodes: Array[BTGraphNode] = []
	for child in view.graph_edit.get_children():
		if child is BTGraphNode:
			nodes.append(child)
	var overlaps: Array[String] = []
	for left_index in range(nodes.size()):
		for right_index in range(left_index + 1, nodes.size()):
			if Rect2(nodes[left_index].position_offset, nodes[left_index].size).intersects(Rect2(nodes[right_index].position_offset, nodes[right_index].size)):
				overlaps.append("%s:%s" % [nodes[left_index].name, nodes[right_index].name])
	return overlaps


func _parent_child_gap_failures(view: BTEditorView, minimum_gap: float) -> Array[String]:
	var failures: Array[String] = []
	for resource in view.current_tree.nodes:
		if resource == null or resource.parent_id == -1 or resource.decorator_parent_id != -1:
			continue
		var parent := _graph_node(view, resource.parent_id)
		var child := _graph_node(view, resource.id)
		if parent == null or child == null:
			continue
		var gap := child.position_offset.y - (parent.position_offset.y + parent.size.y)
		if gap + 0.01 < minimum_gap:
			failures.append("%d>%d:%.1f" % [resource.parent_id, resource.id, gap])
	return failures


func _connection_node_intersections(view: BTEditorView) -> Array[String]:
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


func _count_magnified_nodes(view: BTEditorView) -> int:
	var count := 0
	for child in view.graph_edit.get_children():
		if child is BTGraphNode and child.fisheye_magnification > 1.001:
			count += 1
	return count


func _all_unfocused_nodes_shrunk(view: BTEditorView, focused_id: int) -> bool:
	for child in view.graph_edit.get_children():
		if child is BTGraphNode and child.node_resource.id != focused_id and child.fisheye_magnification > view.FISHEYE_CONTEXT_SCALE + 0.01:
			return false
	return true


func _rendered_child_order(view: BTEditorView, parent_id: int) -> Array[int]:
	var children := view.current_tree.get_children_of(parent_id)
	children.sort_custom(func(left: BTNodeResource, right: BTNodeResource):
		return _graph_node(view, left.id).position_offset.x < _graph_node(view, right.id).position_offset.x
	)
	var ids: Array[int] = []
	for node in children:
		ids.append(node.id)
	return ids


func _rendered_parent_above_children(view: BTEditorView) -> bool:
	for node in view.current_tree.nodes:
		if node == null or node.parent_id == -1 or node.decorator_parent_id != -1:
			continue
		var parent := _graph_node(view, node.parent_id)
		var child := _graph_node(view, node.id)
		if parent != null and child != null and parent.position_offset.y >= child.position_offset.y:
			return false
	return true


func _all_fisheye_state_reset(view: BTEditorView) -> bool:
	for child in view.graph_edit.get_children():
		if child is BTGraphNode and (not is_equal_approx(child.fisheye_magnification, 1.0) or not child.visual_offset.is_zero_approx()):
			return false
	return view.fisheye_focus_node_id == -1


func _all_node_scales_reset(view: BTEditorView) -> bool:
	for child in view.graph_edit.get_children():
		if child is BTGraphNode and not child.scale.is_equal_approx(Vector2.ONE):
			return false
	return true


func _all_node_opacities_reset(view: BTEditorView) -> bool:
	for child in view.graph_edit.get_children():
		if child is BTGraphNode and not is_equal_approx(child.modulate.a, 1.0):
			return false
	return true


func _all_feature_visual_residue_cleared(view: BTEditorView) -> bool:
	if not view.search_query.is_empty() or not view.search_result_ids.is_empty():
		print("FEATURE_RESIDUE search")
		return false
	if not view.graph_edit.active_path_ids.is_empty() or view.visible_failure_annotations.size() > 0:
		print("FEATURE_RESIDUE runtime collections path=%s failures=%s" % [str(view.graph_edit.active_path_ids), str(view.visible_failure_annotations)])
		return false
	if view.graph_edit.minimap_enabled or view.runtime_path_scroll.visible or view.failure_summary_button.visible:
		print("FEATURE_RESIDUE controls minimap=%s path=%s failures=%s" % [view.graph_edit.minimap_enabled, view.runtime_path_scroll.visible, view.failure_summary_button.visible])
		return false
	for child in view.graph_edit.get_children():
		if not (child is BTGraphNode):
			continue
		if child.fisheye_magnification != 1.0 or child.modulate.a != 1.0 or child.failure_badge.visible or child.runtime_highlight_enabled or not child.runtime_label.text.is_empty():
			print("FEATURE_RESIDUE node=%s fish=%s alpha=%s failure=%s highlight=%s label=%s" % [child.name, child.fisheye_magnification, child.modulate.a, child.failure_badge.visible, child.runtime_highlight_enabled, child.runtime_label.text])
			return false
	return true


func _child_ids(tree: BTTreeResource, parent_id: int) -> Array[int]:
	var ids: Array[int] = []
	for child in tree.get_children_of(parent_id):
		ids.append(child.id)
	return ids


func _distinct_child_rows(tree: BTTreeResource, parent_id: int) -> int:
	var rows: Dictionary = {}
	for child in tree.get_children_of(parent_id):
		rows[roundi(child.position.y)] = true
	return rows.size()


func _button_count(container: Container) -> int:
	var count := 0
	for child in container.get_children():
		if child is Button:
			count += 1
	return count


func _path_button_for_node(view: BTEditorView, node_id: int) -> Button:
	for child in view.runtime_path_container.get_children():
		if child is Button and int(child.get_meta("node_id", -1)) == node_id:
			return child
	return null


func _make_view_tree() -> BTTreeResource:
	var tree := BTTreeResource.new()
	tree.tree_name = "Editor View Test"
	tree.root_node_id = 1
	var root_node := _node(1, BTNodeResource.TYPE_ROOT, -1, "Root", 600.0, 40.0)
	var selector := _node(2, BTNodeResource.TYPE_SELECTOR, 1, "Decision", 600.0, 250.0)
	var sequence := _node(3, BTNodeResource.TYPE_SEQUENCE, 2, "Combat", 300.0, 460.0)
	var attack := _node(4, BTNodeResource.TYPE_ACTION, 3, "Attack Target", 200.0, 670.0)
	attack.parameters = {"action_name": "attack_target"}
	var patrol := _node(5, BTNodeResource.TYPE_ACTION, 2, "Patrol", 900.0, 460.0)
	var decorator := _node(6, BTNodeResource.TYPE_DECORATOR, -1, "Can Attack", 0.0, 0.0)
	decorator.decorator_parent_id = 4
	decorator.parameters = {"mode": "blackboard", "blackboard_key": "can_attack", "operator": "equals", "value": true}
	tree.nodes = [root_node, selector, sequence, attack, patrol, decorator]
	return tree


func _node(id: int, type_name: String, parent_id: int, title: String, x: float, y: float) -> BTNodeResource:
	var node := BTNodeResource.new()
	node.id = id
	node.node_type = type_name
	node.parent_id = parent_id
	node.title = title
	node.description = "Description for %s" % title
	node.position = Vector2(x, y)
	return node


func _blackboard_entry(key: String, value_type: String, default_value: Variant) -> BTBlackboardEntry:
	var entry := BTBlackboardEntry.new()
	entry.key = key
	entry.value_type = value_type
	entry.default_value = default_value
	return entry


func _graph_node(view: BTEditorView, id: int) -> BTGraphNode:
	return view.graph_edit.get_node_or_null(NodePath(str(id))) as BTGraphNode


func _graph_node_count(view: BTEditorView) -> int:
	var count := 0
	for child in view.graph_edit.get_children():
		if child is BTGraphNode:
			count += 1
	return count


func _expect(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		printerr("FAIL: %s" % label)
