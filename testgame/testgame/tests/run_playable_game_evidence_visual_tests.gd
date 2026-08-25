extends SceneTree

const BTEditorView = preload("res://addons/behavior_tree_editor/bt_editor_view.gd")
const BTGraphNode = preload("res://addons/behavior_tree_editor/bt_graph_node.gd")
const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")
const BehaviorTreeRunner = preload("res://addons/behavior_tree_editor/runtime/behavior_tree_runner.gd")

const VIEWPORT_SIZE := Vector2i(1600, 900)
const OUTPUT_DIR := "res://test_results/supervisor_game_evidence"
const TREE_PATH := "res://behavior_trees/arena_tactician_241.tres"
const GAME_PATH := "res://scenes/test_game.tscn"
const BRIDGE_PATH := "res://.godot/behavior_tree_runtime_debug.json"
const OVERVIEW_FILE := "01_tactician_241_overview.png"
const LIVE_DEBUG_FILE := "02_tactician_241_live_debug.png"
const EXPECTED_RESOURCE_NODES := 241
const EXPECTED_GRAPH_CARDS := 202

var passed := 0
var failed := 0
var viewport: SubViewport
var view: BTEditorView
var game: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var tree_hash_before := _file_sha256(TREE_PATH)
	var bridge_backup := _read_bridge_backup()
	_remove_bridge()
	var make_dir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_expect(make_dir_error == OK, "supervisor game-evidence output directory is available")

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
	await _settle()
	view.set_process(false)
	view._on_live_debug_toggled(false)
	view.last_runtime_snapshot.clear()
	for definition in view.FEATURE_DEFINITIONS:
		view._set_feature_enabled(str(definition[0]), bool(definition[2]), false)
	view._set_feature_enabled("compact", true, false)
	view._set_feature_enabled("semantic_zoom", true, false)
	view._set_feature_enabled("active_path", true, false)
	view._set_feature_enabled("branch_dimming", true, false)

	var loaded_tree := ResourceLoader.load(TREE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as BTTreeResource
	_expect(loaded_tree != null, "actual Tactician behavior-tree resource loads")
	if loaded_tree != null:
		view.current_tree = loaded_tree
		view.current_tree_path = TREE_PATH
		view.file_path_edit.text = TREE_PATH
		view.selected_node_id = loaded_tree.root_node_id
		view.next_node_id = loaded_tree.nodes.size() + 1
		view._refresh_entire_ui()
		view._auto_arrange_tree()
		view._fit_visible_tree()
		await _settle()
		_expect(loaded_tree.resource_path == TREE_PATH, "editor displays the game resource rather than a generated fixture")
		_expect(loaded_tree.nodes.size() == EXPECTED_RESOURCE_NODES, "actual Tactician resource contains 241 nodes")
		_expect(_graph_node_count() == EXPECTED_GRAPH_CARDS, "actual Tactician resource renders 202 graph cards plus attached Decorators")

	var overview := await _capture(OVERVIEW_FILE)
	_assert_image(overview, "241-node optimized overview has the fixed size and varied colors")

	var packed := ResourceLoader.load(GAME_PATH) as PackedScene
	_expect(packed != null, "playable game scene loads for runtime evidence")
	var frozen_runner_ids: Array[int] = []
	if packed != null:
		game = packed.instantiate()
		root.add_child(game)
		var tactician := game.get_node_or_null("EnemyTactician") as CharacterBody2D
		var player := game.get_node_or_null("Player") as CharacterBody2D
		var runner := game.get_node_or_null("EnemyTactician/BehaviorTreeComponent") as BehaviorTreeRunner
		_expect(tactician != null and player != null and runner != null, "playable game contains the real Tactician actor and BehaviorTreeComponent")
		_disable_other_debug_bridges(runner)
		if tactician != null and player != null and runner != null:
			tactician.global_position = Vector2(300.0, 520.0)
			player.global_position = Vector2(550.0, 520.0)
			runner.editor_debug_bridge_enabled = true
			# Publish every test frame so the file and the frozen component state are identical.
			runner.editor_debug_bridge_interval = 0.0
			runner.debug_enabled = true
			runner.start_tree()
			for _frame in range(24):
				await physics_frame
			runner.stop_tree()
			frozen_runner_ids = _to_int_array(runner.active_path_ids)
			var direct_snapshot := runner.get_debug_snapshot()
			_expect(runner.behavior_tree != null and runner.behavior_tree.resource_path == TREE_PATH, "real Tactician component runs the same 241-node resource shown by the editor")
			_expect(str(direct_snapshot.get("actor", "")) == "EnemyTactician", "real runtime snapshot identifies EnemyTactician")
			_expect(not frozen_runner_ids.is_empty(), "real Tactician execution produces a non-empty active path")
			_expect(_all_ids_exist(frozen_runner_ids), "real Tactician active path refers only to nodes in the displayed resource")

	_expect(FileAccess.file_exists(BRIDGE_PATH), "real BehaviorTreeComponent publishes the Live Debug bridge")
	if view.current_tree != null and FileAccess.file_exists(BRIDGE_PATH):
		view._on_live_debug_toggled(true)
		view.runtime_debug_elapsed = 0.0
		view._poll_runtime_debug(1.0)
		await _settle()
		var bridge_ids := _to_int_array(view.last_runtime_snapshot.get("path_ids", []))
		_expect(str(view.last_runtime_snapshot.get("actor", "")) == "EnemyTactician", "editor receives EnemyTactician through the real Live Debug bridge")
		_expect(str(view.last_runtime_snapshot.get("tree_path", "")) == TREE_PATH, "editor receives an exact 241-node tree-path match through the bridge")
		_expect(not bridge_ids.is_empty(), "editor receives a non-empty path_ids array through the bridge")
		_expect(bridge_ids == frozen_runner_ids, "bridge path_ids match the final path produced by the real component")
		_expect(_all_ids_exist(bridge_ids), "bridged path_ids all belong to the displayed 241-node tree")
		_expect(_to_int_array(view.graph_edit.active_path_ids) == bridge_ids, "Live Debug applies the bridged path to editor connections")
		var visible_leaf_id := _visible_runtime_node_id(bridge_ids[bridge_ids.size() - 1]) if not bridge_ids.is_empty() else -1
		var visible_leaf := _graph_node(visible_leaf_id)
		_expect(visible_leaf != null and visible_leaf.runtime_active, "Live Debug marks the real runtime leaf card as active")
		if visible_leaf != null:
			view.graph_edit.zoom = maxf(view.graph_edit.zoom, 0.36)
			view._focus_graph_node(visible_leaf_id)
			await _settle()

	var live_debug := await _capture(LIVE_DEBUG_FILE)
	_assert_image(live_debug, "real Tactician Live Debug view has the fixed size and varied colors")
	_expect(_sample_difference_count(overview, live_debug) >= 250, "overview and framed Live Debug evidence are visibly different")

	await _cleanup_scene_nodes()
	_restore_bridge(bridge_backup)
	var tree_hash_after := _file_sha256(TREE_PATH)
	_expect(not tree_hash_before.is_empty() and tree_hash_after == tree_hash_before, "visual evidence test does not rewrite the game behavior-tree resource")

	print("BT_PLAYABLE_GAME_EVIDENCE_VISUAL_SUMMARY passed=%d failed=%d output=%s" % [passed, failed, OUTPUT_DIR])
	quit(0 if failed == 0 else 1)


func _disable_other_debug_bridges(tactician_runner: BehaviorTreeRunner) -> void:
	if game == null:
		return
	for enemy_name in ["EnemyScout", "EnemySkirmisher", "EnemyHunter", "EnemyTactician", "EnemyCommander"]:
		var runner := game.get_node_or_null("%s/BehaviorTreeComponent" % enemy_name) as BehaviorTreeRunner
		if runner != null and runner != tactician_runner:
			runner.editor_debug_bridge_enabled = false


func _cleanup_scene_nodes() -> void:
	if is_instance_valid(game):
		game.queue_free()
		await process_frame
		await process_frame
	if is_instance_valid(view):
		view.queue_free()
		await process_frame
	if is_instance_valid(viewport):
		viewport.queue_free()
		await process_frame


func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func _capture(file_name: String) -> Image:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.force_draw(false, 0.0)
	await process_frame
	var image := viewport.get_texture().get_image()
	var output_path := OUTPUT_DIR.path_join(file_name)
	var error := FAILED
	for attempt in range(3):
		error = image.save_png(output_path)
		if error == OK:
			break
		print("PLAYABLE_EVIDENCE_VISUAL_RETRY file=%s attempt=%d error=%d" % [file_name, attempt + 1, error])
		await process_frame
	_expect(error == OK, "%s saves as PNG" % file_name)
	return image


func _assert_image(image: Image, label: String) -> void:
	var valid_size := image.get_width() == VIEWPORT_SIZE.x and image.get_height() == VIEWPORT_SIZE.y
	var sample := image.duplicate()
	sample.resize(320, 180, Image.INTERPOLATE_NEAREST)
	var colors: Dictionary = {}
	for y in range(sample.get_height()):
		for x in range(sample.get_width()):
			colors[sample.get_pixel(x, y).to_html(false)] = true
	_expect(valid_size and colors.size() >= 20, label)


func _sample_difference_count(left: Image, right: Image) -> int:
	if left.is_empty() or right.is_empty():
		return 0
	var left_sample := left.duplicate()
	var right_sample := right.duplicate()
	left_sample.resize(320, 180, Image.INTERPOLATE_NEAREST)
	right_sample.resize(320, 180, Image.INTERPOLATE_NEAREST)
	var changed := 0
	for y in range(left_sample.get_height()):
		for x in range(left_sample.get_width()):
			var left_color: Color = left_sample.get_pixel(x, y)
			var right_color: Color = right_sample.get_pixel(x, y)
			var difference := absf(left_color.r - right_color.r) + absf(left_color.g - right_color.g) + absf(left_color.b - right_color.b)
			if difference > 0.08:
				changed += 1
	return changed


func _graph_node_count() -> int:
	var count := 0
	for child in view.graph_edit.get_children():
		if child is BTGraphNode:
			count += 1
	return count


func _graph_node(node_id: int) -> BTGraphNode:
	if view == null or node_id < 0:
		return null
	return view.graph_edit.get_node_or_null(NodePath(str(node_id))) as BTGraphNode


func _visible_runtime_node_id(node_id: int) -> int:
	if view == null or view.current_tree == null:
		return -1
	var resource := view.current_tree.find_node(node_id)
	if resource == null:
		return -1
	return resource.decorator_parent_id if resource.decorator_parent_id != -1 else resource.id


func _all_ids_exist(path_ids: Array[int]) -> bool:
	if view == null or view.current_tree == null:
		return false
	for node_id in path_ids:
		if view.current_tree.find_node(node_id) == null:
			return false
	return true


func _to_int_array(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value as Array:
		result.append(int(item))
	return result


func _file_sha256(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(FileAccess.get_file_as_bytes(path)) != OK:
		return ""
	return context.finish().hex_encode()


func _read_bridge_backup() -> Dictionary:
	if not FileAccess.file_exists(BRIDGE_PATH):
		return {"exists": false, "text": ""}
	var file := FileAccess.open(BRIDGE_PATH, FileAccess.READ)
	if file == null:
		return {"exists": true, "text": ""}
	var text := file.get_as_text()
	file.close()
	return {"exists": true, "text": text}


func _remove_bridge() -> void:
	if FileAccess.file_exists(BRIDGE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BRIDGE_PATH))


func _restore_bridge(backup: Dictionary) -> void:
	_remove_bridge()
	if not bool(backup.get("exists", false)):
		return
	var file := FileAccess.open(BRIDGE_PATH, FileAccess.WRITE)
	if file == null:
		_expect(false, "previous Live Debug bridge is restored")
		return
	file.store_string(str(backup.get("text", "")))
	file.close()
	_expect(true, "previous Live Debug bridge is restored")


func _expect(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		printerr("FAIL: %s" % label)
