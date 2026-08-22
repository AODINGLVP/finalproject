extends SceneTree

const BTEditorView = preload("res://addons/behavior_tree_editor/bt_editor_view.gd")
const BTGraphNode = preload("res://addons/behavior_tree_editor/bt_graph_node.gd")
const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")
const HumanStudyDebug = preload("res://tests/prepare_human_study_live_debug.gd")

const VIEWPORT_SIZE := Vector2i(1600, 900)
const OUTPUT_DIR := "res://test_results/human_study_visual"
const FORMAL_TREE_PATH := "res://behavior_trees/complex_display_tree_241.tres"
const TRACE_TARGET_KEY := "ranged"

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
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	view = BTEditorView.new()
	view.set_anchors_preset(Control.PRESET_TOP_LEFT)
	view.size = Vector2(VIEWPORT_SIZE)
	viewport.add_child(view)
	await _settle()
	view.set_process(false)

	await _load_arrange_and_fit("res://behavior_trees/human_study_tree_121.tres")
	var medium := await _capture("01_tree_121_overview")
	_assert_image(medium, "121-node study tree renders")
	_expect(_graph_node_count() == 120, "121-node study tree shows 120 graph cards plus one attached Decorator")
	_expect(_graph_node(120) != null, "121-node target Action exists on the canvas")

	var target := HumanStudyDebug.trace_target(TRACE_TARGET_KEY)
	var target_id := int(target.get("id", -1))
	var target_title := str(target.get("title", ""))
	var path_ids: Array[int] = []
	for value in target.get("path_ids", []):
		path_ids.append(int(value))
	await _load_arrange_and_fit(FORMAL_TREE_PATH)
	var large := await _capture("02_tree_241_overview")
	_assert_image(large, "241-node playable study tree renders")
	_expect(view.current_tree.nodes.size() == 241, "formal study tree has 241 resource nodes")
	_expect(_graph_node_count() == 202, "241-node study tree shows 202 graph cards plus 39 attached Decorators")
	_expect(_graph_node(target_id) != null, "meaningful ranged target Action exists on the canvas")

	view._set_feature_enabled("search", true, false)
	view._on_search_changed(target_title)
	view._on_search_submitted(target_title)
	await _settle()
	var searched := await _capture("03_tree_241_target_search")
	_assert_image(searched, "241-node target search renders")
	_expect(view.search_result_ids == [target_id], "search returns only the assigned meaningful target Action")
	_expect(_graph_node(target_id).search_matches, "assigned meaningful target Action is highlighted")
	var target_center := _graph_node(target_id).get_global_rect().get_center()
	var canvas_rect := view.graph_edit.get_global_rect()
	if not canvas_rect.has_point(target_center):
		printerr("VISUAL_DIAGNOSTIC target_center=%s canvas=%s zoom=%.3f scroll=%s node_offset=%s" % [target_center, canvas_rect, view.graph_edit.zoom, view.graph_edit.scroll_offset, _graph_node(target_id).position_offset])
	_expect(canvas_rect.has_point(target_center), "search navigation centers target Action inside the graph canvas")

	view._on_search_changed("")
	view._set_feature_enabled("active_path", true, false)
	view._set_feature_enabled("branch_dimming", true, false)
	var bridge_backup := _read_bridge_text()
	_expect(HumanStudyDebug.write_snapshot(TRACE_TARGET_KEY), "deterministic playable-tree Live Debug fixture writes a fresh bridge snapshot")
	view.runtime_debug_enabled = true
	view.runtime_debug_elapsed = 0.0
	view._poll_runtime_debug(1.0)
	await _settle()
	var live_debug := await _capture("04_tree_241_live_debug_path")
	_assert_image(live_debug, "241-node deterministic Live Debug path renders")
	_expect(view.last_runtime_snapshot.get("actor", "") == "ArenaEnemy", "editor polls the deterministic playable actor through the public Live Debug path")
	_expect(view.graph_edit.active_path_ids == path_ids, "Live Debug highlights the assigned seven-node gameplay chain")
	_expect(_graph_node(target_id).runtime_active and _graph_node(target_id).runtime_leaf, "assigned target Action is the active RUNNING leaf")
	_expect(is_equal_approx(_graph_node(105).modulate.a, BTGraphNode.INACTIVE_BRANCH_ALPHA), "non-current ranged branches are dimmed during the study trial")
	view._set_feature_enabled("branch_dimming", false, false)
	_expect(is_equal_approx(_graph_node(105).modulate.a, 1.0), "disabling study branch dimming restores full opacity")
	_restore_bridge_text(bridge_backup)

	print("BT_HUMAN_STUDY_VISUAL_SUMMARY passed=%d failed=%d output=%s" % [passed, failed, OUTPUT_DIR])
	view.free()
	viewport.free()
	quit(0 if failed == 0 else 1)


func _load_arrange_and_fit(path: String) -> void:
	view.current_tree = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as BTTreeResource
	view.current_tree_path = path
	view.file_path_edit.text = path
	view.selected_node_id = view.current_tree.root_node_id
	view.next_node_id = view.current_tree.nodes.size() + 1
	view._refresh_entire_ui()
	view._auto_arrange_tree()
	view._fit_visible_tree()
	await _settle()


func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func _capture(name: String) -> Image:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.force_draw(false, 0.0)
	await process_frame
	var image := viewport.get_texture().get_image()
	var save_error := image.save_png(OUTPUT_DIR.path_join("%s.png" % name))
	_expect(save_error == OK, "%s screenshot saves" % name)
	return image


func _assert_image(image: Image, label: String) -> void:
	var sample := image.duplicate()
	sample.resize(320, 180, Image.INTERPOLATE_NEAREST)
	var colors: Dictionary = {}
	for y in range(sample.get_height()):
		for x in range(sample.get_width()):
			colors[sample.get_pixel(x, y).to_html(false)] = true
	_expect(image.get_width() == VIEWPORT_SIZE.x and image.get_height() == VIEWPORT_SIZE.y and colors.size() >= 20, label)


func _read_bridge_text() -> String:
	if not FileAccess.file_exists(HumanStudyDebug.BRIDGE_PATH):
		return ""
	var file := FileAccess.open(HumanStudyDebug.BRIDGE_PATH, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _restore_bridge_text(previous_text: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(HumanStudyDebug.BRIDGE_PATH)
	if previous_text.is_empty():
		if FileAccess.file_exists(HumanStudyDebug.BRIDGE_PATH):
			DirAccess.remove_absolute(absolute_path)
		return
	var file := FileAccess.open(HumanStudyDebug.BRIDGE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(previous_text)
		file.close()


func _graph_node_count() -> int:
	var count := 0
	for child in view.graph_edit.get_children():
		if child is BTGraphNode:
			count += 1
	return count


func _graph_node(id: int) -> BTGraphNode:
	for child in view.graph_edit.get_children():
		if child is BTGraphNode and int(child.name.trim_prefix("Node_")) == id:
			return child
	return null


func _expect(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		printerr("FAIL: %s" % label)
