extends SceneTree

const BTEditorView = preload("res://addons/behavior_tree_editor/bt_editor_view.gd")
const BTGraphNode = preload("res://addons/behavior_tree_editor/bt_graph_node.gd")
const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")

const TREE_PATH := "res://behavior_trees/complex_display_tree_241.tres"
const OUTPUT_PATH := "res://test_results/drag_performance_baseline.csv"
const VIEWPORT_SIZE := Vector2i(1600, 900)
const DRAG_STEPS := 240
const MEASURED_TRIALS := 5


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.gui_embed_subwindows = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := BTEditorView.new()
	view.size = Vector2(VIEWPORT_SIZE)
	viewport.add_child(view)
	await process_frame
	await process_frame
	view.current_tree = load(TREE_PATH) as BTTreeResource
	view.current_tree_path = TREE_PATH
	view._refresh_entire_ui()
	view._focus_graph_node(3)
	await process_frame
	await process_frame
	var graph_node := view.graph_edit.get_node_or_null(NodePath("3")) as BTGraphNode
	if graph_node == null:
		printerr("FAIL: drag benchmark cannot find tactical priority node")
		quit(1)
		return
	var start_position := graph_node.position_offset
	# Discard one warmup run, then use a median so GPU scheduling noise does not
	# dominate the before/after comparison.
	_run_drag_trial(view, graph_node)
	var trial_times: Array[float] = []
	for trial in range(MEASURED_TRIALS):
		graph_node.position_offset = start_position
		graph_node.sync_to_resource()
		trial_times.append(_run_drag_trial(view, graph_node))
	trial_times.sort()
	var median_ms := trial_times[floori(float(trial_times.size()) / 2.0)]
	await process_frame
	var moved_distance := graph_node.position_offset.distance_to(start_position)
	var rendered_cards := 0
	for child in view.graph_edit.get_children():
		if child is BTGraphNode:
			rendered_cards += 1
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	file.store_csv_line(PackedStringArray(["resource_nodes", "rendered_cards", "drag_steps", "trials", "median_total_ms", "median_ms_per_step", "minimum_ms", "maximum_ms", "moved_distance"] ))
	file.store_csv_line(PackedStringArray([
		str(view.current_tree.nodes.size()),
		str(rendered_cards),
		str(DRAG_STEPS),
		str(MEASURED_TRIALS),
		str(median_ms),
		str(median_ms / float(DRAG_STEPS)),
		str(trial_times.front()),
		str(trial_times.back()),
		str(moved_distance),
	]))
	file.close()
	print("BT_DRAG_BASELINE nodes=%d cards=%d steps=%d trials=%d median_ms=%.3f ms_per_step=%.3f range=%.3f..%.3f moved=%.1f output=%s" % [
		view.current_tree.nodes.size(), rendered_cards, DRAG_STEPS, MEASURED_TRIALS, median_ms, median_ms / float(DRAG_STEPS), trial_times.front(), trial_times.back(), moved_distance, OUTPUT_PATH,
	])
	var valid := view.current_tree.nodes.size() == 241 and rendered_cards >= 200 and moved_distance > 100.0 and median_ms > 0.0
	view.free()
	viewport.free()
	quit(0 if valid else 1)


func _run_drag_trial(view: BTEditorView, graph_node: BTGraphNode) -> float:
	var pointer := graph_node.size * 0.5
	var drag_origin := pointer
	_push_button(graph_node, pointer, true)
	var started_usec := Time.get_ticks_usec()
	for step in range(DRAG_STEPS):
		var next_pointer := drag_origin + Vector2(float(step + 1), sin(float(step) * 0.15) * 12.0)
		var motion := InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = next_pointer
		motion.relative = next_pointer - pointer
		graph_node._gui_input(motion)
		view._process(1.0 / 120.0)
		RenderingServer.force_draw(false, 0.0)
		pointer = next_pointer
	var elapsed_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
	_push_button(graph_node, pointer, false)
	return elapsed_ms


func _push_button(graph_node: BTGraphNode, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	event.position = position
	graph_node._gui_input(event)
