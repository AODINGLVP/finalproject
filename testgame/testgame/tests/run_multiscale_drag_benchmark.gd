extends SceneTree

const BTEditorView = preload("res://addons/behavior_tree_editor/bt_editor_view.gd")
const BTGraphNode = preload("res://addons/behavior_tree_editor/bt_graph_node.gd")
const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")
const TreeFactory = preload("res://tests/support/multiscale_tree_factory.gd")

const TREE_SIZES := [31, 61, 121, 241, 364]
const VIEWPORT_SIZE := Vector2i(1600, 900)
const DRAG_STEPS := 240
const MEASURED_TRIALS := 10
const DEFAULT_OUTPUT := "res://test_results/multiscale_drag_block.csv"

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var version_label := _argument("version", "Unspecified")
	var block_label := _argument("block", "1")
	var size_order := _argument("size-order", "ascending")
	var output_path := _argument("output", DEFAULT_OUTPUT)
	var ordered_sizes := TREE_SIZES.duplicate()
	if size_order == "descending":
		ordered_sizes.reverse()

	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.gui_embed_subwindows = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := BTEditorView.new()
	view.size = Vector2(VIEWPORT_SIZE)
	viewport.add_child(view)
	await _settle_frames()
	_configure_stable_drag_view(view)

	var rows: Array[PackedStringArray] = []
	rows.append(PackedStringArray([
		"version", "block", "size_order", "tree_size", "resource_nodes", "rendered_cards", "decorators",
		"trial", "drag_steps", "total_ms", "ms_per_step", "moved_distance", "resource_synced",
		"order_preserved", "engine_version", "renderer", "gpu", "viewport",
	]))
	for size_variant in ordered_sizes:
		var tree_size := int(size_variant)
		var tree := TreeFactory.generate(tree_size) as BTTreeResource
		failures += _expect(tree.nodes.size() == tree_size, "%s block %s creates exact %d-node tree" % [version_label, block_label, tree_size])
		failures += _expect(tree.validate_tree().is_empty(), "%s block %s validates %d-node tree" % [version_label, block_label, tree_size])
		view.current_tree = tree
		view.current_tree_path = "res://benchmarks/drag_scale_%d.tres" % tree_size
		view.next_node_id = tree_size + 1
		view._refresh_entire_ui()
		view._auto_arrange_tree()
		await _settle_frames()
		var target_id := TreeFactory.focus_target_id(tree)
		var graph_node := view.graph_edit.get_node_or_null(NodePath(str(target_id))) as BTGraphNode
		if graph_node == null:
			failures += _expect(false, "%s block %s finds %d-node drag target" % [version_label, block_label, tree_size])
			continue
		var start_position := graph_node.position_offset
		var order_signature := _order_signature(tree)
		await _reset_drag_target(view, graph_node, start_position)
		_run_drag_trial(view, graph_node)
		for trial in range(1, MEASURED_TRIALS + 1):
			await _reset_drag_target(view, graph_node, start_position)
			var elapsed_ms := _run_drag_trial(view, graph_node)
			var moved_distance := graph_node.position_offset.distance_to(start_position)
			var resource_synced := graph_node.node_resource.position.is_equal_approx(graph_node.position_offset)
			var order_preserved := _order_signature(tree) == order_signature
			rows.append(PackedStringArray([
				version_label, block_label, size_order, str(tree_size), str(tree.nodes.size()),
				str(TreeFactory.card_count(tree)), str(TreeFactory.decorator_count(tree)), str(trial),
				str(DRAG_STEPS), str(elapsed_ms), str(elapsed_ms / float(DRAG_STEPS)), str(moved_distance),
				str(resource_synced), str(order_preserved), str(Engine.get_version_info().get("string", "unknown")),
				RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name(),
				"%dx%d" % [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
			]))
			failures += _expect(elapsed_ms > 0.0, "%s block %s %d-node trial %d records drag time" % [version_label, block_label, tree_size, trial])
			failures += _expect(moved_distance > 150.0, "%s block %s %d-node trial %d moves the card" % [version_label, block_label, tree_size, trial])
			failures += _expect(resource_synced, "%s block %s %d-node trial %d persists final position" % [version_label, block_label, tree_size, trial])
			failures += _expect(order_preserved, "%s block %s %d-node trial %d preserves execution order" % [version_label, block_label, tree_size, trial])
		print("BT_MULTISCALE_DRAG_PROGRESS version=%s block=%s size=%d trials=%d" % [version_label, block_label, tree_size, MEASURED_TRIALS])

	_write_rows(output_path, rows)
	print("BT_MULTISCALE_DRAG_SUMMARY version=%s block=%s order=%s sizes=%d observations=%d failed=%d output=%s" % [
		version_label, block_label, size_order, TREE_SIZES.size(), TREE_SIZES.size() * MEASURED_TRIALS,
		failures, output_path,
	])
	view.free()
	viewport.free()
	quit(0 if failures == 0 else 1)


func _configure_stable_drag_view(view: BTEditorView) -> void:
	for key in ["fisheye", "compact", "semantic_zoom", "auto_spacing", "stable_layout", "orthogonal_edges", "edge_bundling"]:
		view._set_feature_enabled(key, false, false)
	view._set_feature_enabled("single_connection", true, false)
	view.graph_edit.zoom = 1.0


func _reset_drag_target(view: BTEditorView, graph_node: BTGraphNode, start_position: Vector2) -> void:
	graph_node.position_offset = start_position
	graph_node.sync_to_resource()
	view.graph_edit.queue_redraw()
	await _settle_frames()


func _run_drag_trial(view: BTEditorView, graph_node: BTGraphNode) -> float:
	var pointer := graph_node.size * 0.5
	var drag_origin := pointer
	var started_usec := Time.get_ticks_usec()
	_push_button(graph_node, pointer, true)
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
	_push_button(graph_node, pointer, false)
	return float(Time.get_ticks_usec() - started_usec) / 1000.0


func _push_button(graph_node: BTGraphNode, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	event.position = position
	graph_node._gui_input(event)


func _settle_frames() -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw(false, 0.0)
	await process_frame


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


func _argument(name: String, fallback: String) -> String:
	var prefix := "--%s=" % name
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return fallback


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
