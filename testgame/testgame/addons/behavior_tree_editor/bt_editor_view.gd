@tool
extends VBoxContainer
class_name BTEditorView

const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")
const BTNodeResource = preload("res://addons/behavior_tree_editor/bt_node_resource.gd")
const BTGraphNode = preload("res://addons/behavior_tree_editor/bt_graph_node.gd")
const BTGraphEdit = preload("res://addons/behavior_tree_editor/bt_graph_edit.gd")
const BTPaletteItem = preload("res://addons/behavior_tree_editor/bt_palette_item.gd")
const RUNTIME_DEBUG_PATH := "res://.godot/behavior_tree_runtime_debug.json"

const NODE_TYPES := [
	BTNodeResource.TYPE_ROOT,
	BTNodeResource.TYPE_SEQUENCE,
	BTNodeResource.TYPE_SELECTOR,
	BTNodeResource.TYPE_ACTION,
	BTNodeResource.TYPE_CONDITION,
	BTNodeResource.TYPE_DECORATOR
]
const FISHEYE_RADIUS := 430.0
const FISHEYE_MAX_SCALE := 1.32
const FISHEYE_MIN_SCALE := 1.0
const FISHEYE_LERP_SPEED := 12.0
const FISHEYE_WHEEL_PAUSE := 0.2

var plugin: EditorPlugin
var current_tree: BTTreeResource
var current_tree_path: String = "res://behavior_trees/new_behavior_tree.tres"
var selected_node_id: int = -1
var next_node_id: int = 1
var undo_stack: Array[BTTreeResource] = []
var redo_stack: Array[BTTreeResource] = []
var pending_context_position: Vector2 = Vector2.ZERO
var suppress_inspector_changes := false
var runtime_debug_enabled := true
var runtime_debug_elapsed := 0.0
var runtime_debug_actor := ""
var fisheye_enabled := true
var fisheye_wheel_pause_elapsed := 0.0

var graph_edit: BTGraphEdit
var tree_name_edit: LineEdit
var file_path_edit: LineEdit
var tree_path_picker: OptionButton
var node_type_picker: OptionButton
var status_label: Label
var root_button: Button
var child_button: Button
var delete_button: Button
var undo_button: Button
var redo_button: Button
var live_debug_toggle: CheckBox
var fisheye_toggle: CheckBox
var runtime_debug_label: Label
var context_menu: PopupMenu

var inspector_panel: PanelContainer
var selected_label: Label
var node_title_edit: LineEdit
var node_type_edit: OptionButton
var node_description_edit: TextEdit
var node_parameters_edit: TextEdit


func _ready() -> void:
	size_flags_vertical = SIZE_EXPAND_FILL
	size_flags_horizontal = SIZE_EXPAND_FILL
	set_process(true)
	_build_ui()
	_refresh_tree_path_picker()
	_new_tree()


func _process(delta: float) -> void:
	_poll_runtime_debug(delta)
	_update_fisheye(delta)


func _build_ui() -> void:
	var toolbar := HBoxContainer.new()
	toolbar.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(toolbar)

	var new_button := Button.new()
	new_button.text = "New Tree"
	new_button.pressed.connect(_new_tree)
	toolbar.add_child(new_button)

	undo_button = Button.new()
	undo_button.text = "Undo"
	undo_button.pressed.connect(_undo)
	toolbar.add_child(undo_button)

	redo_button = Button.new()
	redo_button.text = "Redo"
	redo_button.pressed.connect(_redo)
	toolbar.add_child(redo_button)

	var save_button := Button.new()
	save_button.text = "Save Tree"
	save_button.pressed.connect(_save_tree)
	toolbar.add_child(save_button)

	var load_button := Button.new()
	load_button.text = "Load Tree"
	load_button.pressed.connect(_load_tree)
	toolbar.add_child(load_button)

	var arrange_button := Button.new()
	arrange_button.text = "Auto Arrange"
	arrange_button.pressed.connect(_auto_arrange_tree)
	toolbar.add_child(arrange_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	var tree_name_label := Label.new()
	tree_name_label.text = "Tree Name"
	toolbar.add_child(tree_name_label)

	tree_name_edit = LineEdit.new()
	tree_name_edit.custom_minimum_size = Vector2(220.0, 0.0)
	tree_name_edit.text_submitted.connect(_on_tree_name_submitted)
	tree_name_edit.focus_exited.connect(_on_tree_name_focus_exited)
	toolbar.add_child(tree_name_edit)

	var path_row := HBoxContainer.new()
	path_row.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(path_row)

	var path_label := Label.new()
	path_label.text = "Resource Path"
	path_row.add_child(path_label)

	file_path_edit = LineEdit.new()
	file_path_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	file_path_edit.text = current_tree_path
	path_row.add_child(file_path_edit)

	tree_path_picker = OptionButton.new()
	tree_path_picker.custom_minimum_size = Vector2(280.0, 0.0)
	tree_path_picker.tooltip_text = "Select a behavior tree found in this project."
	tree_path_picker.item_selected.connect(_on_tree_path_selected)
	path_row.add_child(tree_path_picker)

	var refresh_paths_button := Button.new()
	refresh_paths_button.text = "Refresh"
	refresh_paths_button.tooltip_text = "Scan the project for behavior tree resources."
	refresh_paths_button.pressed.connect(_refresh_tree_path_picker)
	path_row.add_child(refresh_paths_button)

	var runtime_row := HBoxContainer.new()
	runtime_row.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(runtime_row)

	live_debug_toggle = CheckBox.new()
	live_debug_toggle.text = "Live Debug"
	live_debug_toggle.button_pressed = true
	live_debug_toggle.toggled.connect(_on_live_debug_toggled)
	runtime_row.add_child(live_debug_toggle)

	fisheye_toggle = CheckBox.new()
	fisheye_toggle.text = "Fisheye"
	fisheye_toggle.button_pressed = true
	fisheye_toggle.toggled.connect(_on_fisheye_toggled)
	runtime_row.add_child(fisheye_toggle)

	runtime_debug_label = Label.new()
	runtime_debug_label.size_flags_horizontal = SIZE_EXPAND_FILL
	runtime_debug_label.text = "Run the game to highlight the active behavior path here."
	runtime_row.add_child(runtime_debug_label)

	var creation_row := HBoxContainer.new()
	creation_row.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(creation_row)

	var node_type_label := Label.new()
	node_type_label.text = "New Node Type"
	creation_row.add_child(node_type_label)

	node_type_picker = OptionButton.new()
	for node_type in NODE_TYPES:
		node_type_picker.add_item(node_type)
	creation_row.add_child(node_type_picker)

	root_button = Button.new()
	root_button.text = "Add Root"
	root_button.pressed.connect(_on_add_root_pressed)
	creation_row.add_child(root_button)

	child_button = Button.new()
	child_button.text = "Add Child"
	child_button.pressed.connect(_on_add_child_pressed)
	creation_row.add_child(child_button)

	delete_button = Button.new()
	delete_button.text = "Delete Selected"
	delete_button.pressed.connect(_delete_selected_node)
	creation_row.add_child(delete_button)

	status_label = Label.new()
	status_label.size_flags_horizontal = SIZE_EXPAND_FILL
	status_label.text = "Create a root node to start building the behavior tree."
	creation_row.add_child(status_label)

	var content := HSplitContainer.new()
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	content.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(content)

	var palette := VBoxContainer.new()
	palette.custom_minimum_size = Vector2(130.0, 0.0)
	content.add_child(palette)

	var palette_title := Label.new()
	palette_title.text = "Node Palette"
	palette.add_child(palette_title)

	_add_palette_group(palette, "Composite", [BTNodeResource.TYPE_SEQUENCE, BTNodeResource.TYPE_SELECTOR])
	_add_palette_group(palette, "Task", [BTNodeResource.TYPE_ACTION, BTNodeResource.TYPE_CONDITION])
	_add_palette_group(palette, "Decorator", [BTNodeResource.TYPE_DECORATOR])
	_add_palette_group(palette, "Entry", [BTNodeResource.TYPE_ROOT])

	graph_edit = BTGraphEdit.new()
	graph_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	graph_edit.size_flags_vertical = SIZE_EXPAND_FILL
	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	graph_edit.canvas_context_requested.connect(_on_canvas_context_requested)
	graph_edit.node_type_dropped.connect(_on_node_type_dropped)
	graph_edit.viewport_wheel_scrolled.connect(_on_graph_view_wheel_scrolled)
	content.add_child(graph_edit)

	context_menu = PopupMenu.new()
	context_menu.add_item("Add Root", 0)
	context_menu.add_separator()
	context_menu.add_item("Add Sequence", 1)
	context_menu.add_item("Add Selector", 2)
	context_menu.add_item("Add Action", 3)
	context_menu.add_item("Add Condition", 4)
	context_menu.add_item("Add Decorator", 5)
	context_menu.add_separator()
	context_menu.add_item("Disconnect From Parent", 20)
	context_menu.add_item("Delete Selected", 21)
	context_menu.add_item("Enable / Disable Selected", 22)
	context_menu.add_item("Collapse / Expand Selected", 23)
	context_menu.add_separator()
	context_menu.add_item("Auto Arrange Tree", 30)
	context_menu.add_item("Attach Blackboard Decorator", 31)
	context_menu.add_item("Attach Cooldown Decorator", 32)
	context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	add_child(context_menu)

	inspector_panel = PanelContainer.new()
	inspector_panel.custom_minimum_size = Vector2(320.0, 0.0)
	content.add_child(inspector_panel)

	var inspector := VBoxContainer.new()
	inspector_panel.add_child(inspector)

	var inspector_title := Label.new()
	inspector_title.text = "Node Inspector"
	inspector.add_child(inspector_title)

	selected_label = Label.new()
	selected_label.text = "No node selected"
	inspector.add_child(selected_label)

	var node_title_label := Label.new()
	node_title_label.text = "Title"
	inspector.add_child(node_title_label)

	node_title_edit = LineEdit.new()
	node_title_edit.text_changed.connect(_on_node_fields_changed)
	inspector.add_child(node_title_edit)

	var node_type_edit_label := Label.new()
	node_type_edit_label.text = "Type"
	inspector.add_child(node_type_edit_label)

	node_type_edit = OptionButton.new()
	for node_type in NODE_TYPES:
		node_type_edit.add_item(node_type)
	node_type_edit.item_selected.connect(_on_node_type_selected)
	inspector.add_child(node_type_edit)

	var description_label := Label.new()
	description_label.text = "Description"
	inspector.add_child(description_label)

	node_description_edit = TextEdit.new()
	node_description_edit.custom_minimum_size = Vector2(0.0, 120.0)
	node_description_edit.text_changed.connect(_on_node_fields_changed)
	inspector.add_child(node_description_edit)

	var parameters_label := Label.new()
	parameters_label.text = "Parameters (JSON object)"
	inspector.add_child(parameters_label)

	node_parameters_edit = TextEdit.new()
	node_parameters_edit.size_flags_vertical = SIZE_EXPAND_FILL
	node_parameters_edit.text_changed.connect(_on_node_fields_changed)
	inspector.add_child(node_parameters_edit)


func _add_palette_group(parent: Control, title: String, types: Array) -> void:
	var label := Label.new()
	label.text = title
	label.modulate = Color(0.78, 0.82, 0.9)
	parent.add_child(label)
	for node_type in types:
		var palette_item := BTPaletteItem.new()
		palette_item.text = node_type
		palette_item.node_type = node_type
		palette_item.tooltip_text = "Drag or click to add %s" % node_type
		palette_item.pressed.connect(_add_node_from_palette.bind(node_type))
		parent.add_child(palette_item)


func _refresh_tree_path_picker() -> void:
	if not is_instance_valid(tree_path_picker):
		return
	var previous_path := file_path_edit.text.strip_edges() if is_instance_valid(file_path_edit) else current_tree_path
	tree_path_picker.clear()
	tree_path_picker.add_item("Select Behavior Tree...")
	tree_path_picker.set_item_metadata(0, "")
	var paths: Array[String] = []
	_collect_behavior_tree_paths("res://", paths)
	paths.sort()
	for path in paths:
		var label := "%s  (%s)" % [path.get_file().get_basename(), path.get_base_dir()]
		var index := tree_path_picker.item_count
		tree_path_picker.add_item(label)
		tree_path_picker.set_item_metadata(index, path)
	_select_tree_path_in_picker(previous_path)


func _collect_behavior_tree_paths(directory_path: String, result: Array[String]) -> void:
	var dir := DirAccess.open(directory_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var path := directory_path.path_join(entry)
		if dir.current_is_dir():
			_collect_behavior_tree_paths(path, result)
		elif entry.get_extension().to_lower() == "tres" and _is_behavior_tree_resource(path):
			result.append(path)
		entry = dir.get_next()
	dir.list_dir_end()


func _is_behavior_tree_resource(path: String) -> bool:
	var resource := ResourceLoader.load(path)
	return resource != null and resource is BTTreeResource


func _select_tree_path_in_picker(path: String) -> void:
	if not is_instance_valid(tree_path_picker):
		return
	for index in range(tree_path_picker.item_count):
		if str(tree_path_picker.get_item_metadata(index)) == path:
			tree_path_picker.select(index)
			return
	tree_path_picker.select(0)


func _on_tree_path_selected(index: int) -> void:
	var path := str(tree_path_picker.get_item_metadata(index))
	if path.is_empty():
		return
	file_path_edit.text = path
	_load_tree()


func _new_tree() -> void:
	if current_tree != null:
		_push_history()
	current_tree = BTTreeResource.new()
	current_tree.tree_name = "New Behavior Tree"
	current_tree.root_node_id = -1
	current_tree.nodes = []
	selected_node_id = -1
	next_node_id = 1
	undo_stack.clear()
	redo_stack.clear()
	current_tree_path = "res://behavior_trees/new_behavior_tree.tres"
	file_path_edit.text = current_tree_path if is_instance_valid(file_path_edit) else current_tree_path
	_select_tree_path_in_picker(current_tree_path)
	_refresh_entire_ui()
	_set_status("Created a new empty behavior tree.")


func _load_tree() -> void:
	var path := file_path_edit.text.strip_edges()
	if path.is_empty():
		_set_status("Please enter a resource path to load.")
		return
	var resource := ResourceLoader.load(path)
	if resource == null or not resource is BTTreeResource:
		_set_status("Load failed. Path must point to a BTTreeResource .tres file.")
		return
	current_tree = resource
	current_tree_path = path
	file_path_edit.text = current_tree_path
	_select_tree_path_in_picker(current_tree_path)
	selected_node_id = -1
	next_node_id = _calculate_next_id()
	undo_stack.clear()
	redo_stack.clear()
	_refresh_entire_ui()
	_set_status("Loaded behavior tree from %s" % path)


func _save_tree() -> void:
	if current_tree == null:
		_set_status("Nothing to save.")
		return
	_sync_inspector_into_selected_node()
	current_tree.tree_name = tree_name_edit.text.strip_edges()
	var path := file_path_edit.text.strip_edges()
	if path.is_empty():
		path = "res://behavior_trees/new_behavior_tree.tres"
		file_path_edit.text = path
	if not path.begins_with("res://"):
		_set_status("Save path must start with res://")
		return
	var folder_path := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder_path)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder_path))
	var error := ResourceSaver.save(current_tree, path)
	if error != OK:
		_set_status("Save failed with error code %d" % error)
		return
	current_tree_path = path
	_refresh_tree_path_picker()
	_select_tree_path_in_picker(current_tree_path)
	_set_status("Saved behavior tree to %s" % path)


func _on_add_root_pressed() -> void:
	if current_tree.root_node_id != -1:
		_set_status("This tree already has a root node.")
		return
	_push_history()
	var node := _create_node(BTNodeResource.TYPE_ROOT, Vector2(120.0, 120.0), -1)
	current_tree.root_node_id = node.id
	selected_node_id = node.id
	_refresh_entire_ui()
	_set_status("Added root node.")


func _on_add_child_pressed() -> void:
	if selected_node_id == -1:
		_set_status("Select a parent node first.")
		return
	_push_history()
	var type_name := node_type_picker.get_item_text(node_type_picker.selected)
	if type_name == BTNodeResource.TYPE_ROOT:
		type_name = BTNodeResource.TYPE_ACTION
	var parent_node := current_tree.find_node(selected_node_id)
	var sibling_index := current_tree.get_children_of(parent_node.id).size()
	var offset := Vector2((sibling_index - 1) * 260.0, 180.0)
	var node := _create_node(type_name, parent_node.position + offset, parent_node.id)
	selected_node_id = node.id
	_refresh_entire_ui()
	_set_status("Added child node under %s." % parent_node.title)


func _delete_selected_node() -> void:
	if selected_node_id == -1:
		_set_status("No node selected.")
		return
	if selected_node_id == current_tree.root_node_id:
		_set_status("Delete the children first, then delete the root node.")
		return
	_push_history()
	var descendant_ids := _collect_subtree_and_attached_decorator_ids(selected_node_id)
	var remaining: Array[BTNodeResource] = []
	for node in current_tree.nodes:
		if node == null or descendant_ids.has(node.id):
			continue
		remaining.append(node)
	current_tree.nodes = remaining
	selected_node_id = -1
	_refresh_entire_ui()
	_set_status("Deleted selected node and its subtree.")


func _create_node(type_name: String, position: Vector2, parent_id: int) -> BTNodeResource:
	var node := BTNodeResource.new()
	node.id = next_node_id
	next_node_id += 1
	node.node_type = type_name
	node.title = "%s Node" % type_name
	node.description = _default_description_for(type_name)
	node.position = position
	node.parent_id = parent_id
	node.parameters = _default_parameters_for(type_name)
	current_tree.nodes.append(node)
	return node


func _refresh_entire_ui() -> void:
	if not is_instance_valid(tree_name_edit):
		return
	tree_name_edit.text = current_tree.tree_name
	_rebuild_graph()
	_refresh_inspector()
	_update_history_buttons()


func _rebuild_graph() -> void:
	for child in graph_edit.get_children():
		if child is BTGraphNode:
			graph_edit.remove_child(child)
			child.queue_free()
	graph_edit.clear_connections()

	for node_resource in current_tree.nodes:
		if node_resource == null or _is_attached_decorator(node_resource) or _is_node_hidden_by_collapsed_ancestor(node_resource):
			continue
		var graph_node := BTGraphNode.new()
		graph_edit.add_child(graph_node)
		graph_node.setup(
			node_resource,
			_get_sibling_order(node_resource),
			current_tree.get_decorators_of(node_resource.id),
			current_tree.get_children_of(node_resource.id).size(),
			_count_collapsible_descendants(node_resource.id),
			_build_collapsed_preview(node_resource.id)
		)
		graph_node.collapse_toggled.connect(_on_graph_node_collapse_toggled)
		graph_node.gui_input.connect(_on_graph_node_gui_input.bind(graph_node))
		graph_node.position_offset_changed.connect(_on_graph_node_position_changed.bind(graph_node))

	for node_resource in current_tree.nodes:
		if node_resource == null or _is_attached_decorator(node_resource) or node_resource.parent_id == -1 or _is_node_hidden_by_collapsed_ancestor(node_resource):
			continue
		var parent_name := str(node_resource.parent_id)
		var child_name := str(node_resource.id)
		if graph_edit.get_node_or_null(NodePath(parent_name)) != null and graph_edit.get_node_or_null(NodePath(child_name)) != null:
			graph_edit.connect_node(parent_name, 0, child_name, 0)


func _refresh_inspector() -> void:
	var node := _get_selected_node()
	suppress_inspector_changes = true
	if node == null:
		selected_label.text = "No node selected"
		node_title_edit.text = ""
		node_type_edit.select(0)
		node_description_edit.text = ""
		node_parameters_edit.text = "{}"
		suppress_inspector_changes = false
		return
	selected_label.text = "Editing Node #%d" % node.id
	node_title_edit.text = node.title
	node_type_edit.select(max(0, NODE_TYPES.find(node.node_type)))
	node_description_edit.text = node.description
	node_parameters_edit.text = JSON.stringify(node.parameters, "\t")
	suppress_inspector_changes = false


func _on_graph_node_gui_input(event: InputEvent, graph_node: BTGraphNode) -> void:
	if not (event is InputEventMouseButton):
		return
	if not event.pressed:
		return
	selected_node_id = int(String(graph_node.name))
	_refresh_inspector()
	if event.button_index == MOUSE_BUTTON_RIGHT:
		pending_context_position = graph_node.position_offset
		_popup_context_menu()
	else:
		_set_status("Selected node #%d." % selected_node_id)


func _on_graph_node_position_changed(graph_node: BTGraphNode) -> void:
	graph_node.sync_to_resource()


func _on_graph_node_collapse_toggled(node_id: int) -> void:
	var node := current_tree.find_node(node_id)
	if node == null:
		return
	_push_history()
	node.collapsed = not node.collapsed
	selected_node_id = node.id
	_rebuild_graph()
	_refresh_inspector()
	_set_status("%s subtree for %s." % ["Collapsed" if node.collapsed else "Expanded", node.title])


func _on_connection_request(from_node: StringName, _from_port: int, to_node: StringName, _to_port: int) -> void:
	if from_node == to_node:
		_set_status("A node cannot connect to itself.")
		return
	var child := current_tree.find_node(int(String(to_node)))
	var parent := current_tree.find_node(int(String(from_node)))
	if child == null or parent == null:
		return
	if child.node_type == BTNodeResource.TYPE_ROOT:
		_set_status("The root node cannot be a child.")
		return
	if _would_create_cycle(parent.id, child.id):
		_set_status("This connection would create a cycle.")
		return
	_push_history()
	child.parent_id = parent.id
	_rebuild_graph()
	_set_status("Connected %s -> %s" % [parent.title, child.title])


func _on_disconnection_request(from_node: StringName, _from_port: int, to_node: StringName, _to_port: int) -> void:
	var child := current_tree.find_node(int(String(to_node)))
	if child == null:
		return
	_push_history()
	child.parent_id = -1
	_rebuild_graph()
	_set_status("Disconnected node #%d from its parent." % child.id)


func _on_tree_name_submitted(_text: String) -> void:
	if current_tree != null:
		current_tree.tree_name = tree_name_edit.text.strip_edges()


func _on_tree_name_focus_exited() -> void:
	if current_tree != null:
		current_tree.tree_name = tree_name_edit.text.strip_edges()


func _on_live_debug_toggled(enabled: bool) -> void:
	runtime_debug_enabled = enabled
	if not enabled:
		_clear_runtime_highlights()
		if is_instance_valid(runtime_debug_label):
			runtime_debug_label.text = "Live Debug disabled."


func _on_fisheye_toggled(enabled: bool) -> void:
	fisheye_enabled = enabled
	if not enabled:
		_reset_fisheye()


func _on_node_fields_changed() -> void:
	if suppress_inspector_changes:
		return
	_push_history()
	_sync_inspector_into_selected_node()


func _on_node_type_selected(_index: int) -> void:
	if suppress_inspector_changes:
		return
	_push_history()
	_sync_inspector_into_selected_node()


func _poll_runtime_debug(delta: float) -> void:
	if not runtime_debug_enabled:
		return
	runtime_debug_elapsed -= delta
	if runtime_debug_elapsed > 0.0:
		return
	runtime_debug_elapsed = 0.12
	if not FileAccess.file_exists(RUNTIME_DEBUG_PATH):
		_clear_runtime_highlights()
		if is_instance_valid(runtime_debug_label):
			runtime_debug_label.text = "Live Debug waiting for bridge file: %s" % RUNTIME_DEBUG_PATH
		return
	var file := FileAccess.open(RUNTIME_DEBUG_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed := JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var payload: Dictionary = parsed
	var timestamp := float(payload.get("timestamp_unix", 0.0))
	if timestamp > 0.0 and Time.get_unix_time_from_system() - timestamp > 2.0:
		_clear_runtime_highlights()
		if is_instance_valid(runtime_debug_label):
			runtime_debug_label.text = "Live Debug waiting for a running game..."
		return
	var snapshot := _select_runtime_snapshot(payload.get("components", []))
	if snapshot.is_empty():
		_clear_runtime_highlights()
		if is_instance_valid(runtime_debug_label):
			var running_tree := _describe_first_runtime_tree(payload.get("components", []))
			runtime_debug_label.text = "No exact tree path match for %s. %s" % [current_tree_path, running_tree]
		return
	_apply_runtime_snapshot(snapshot)


func _select_runtime_snapshot(components: Variant) -> Dictionary:
	if typeof(components) != TYPE_ARRAY:
		return {}
	var path := file_path_edit.text.strip_edges() if is_instance_valid(file_path_edit) else current_tree_path
	if path.is_empty():
		path = current_tree_path
	for item in components:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var snapshot: Dictionary = item
		if str(snapshot.get("tree_path", "")) == path:
			return snapshot
	for item in components:
		if typeof(item) == TYPE_DICTIONARY:
			return item
	return {}


func _describe_first_runtime_tree(components: Variant) -> String:
	if typeof(components) != TYPE_ARRAY:
		return ""
	for item in components:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var snapshot: Dictionary = item
		var tree_path := str(snapshot.get("tree_path", ""))
		if not tree_path.is_empty():
			return "Running tree: %s" % tree_path
	return ""


func _apply_runtime_snapshot(snapshot: Dictionary) -> void:
	var active_ids: Array = snapshot.get("path_ids", [])
	var leaf_id := -1
	if not active_ids.is_empty():
		leaf_id = int(active_ids[active_ids.size() - 1])
	var leaf_status := str(snapshot.get("leaf_status_text", "UNKNOWN"))
	for child in graph_edit.get_children():
		if not (child is BTGraphNode):
			continue
		var graph_node: BTGraphNode = child
		var node_id := int(String(graph_node.name))
		var is_active := _array_has_node_id(active_ids, node_id) or _node_contains_any_id(node_id, active_ids)
		graph_node.set_runtime_state(is_active, node_id == leaf_id, leaf_status)
	var actor := str(snapshot.get("actor", "Unknown"))
	var path_text := str(snapshot.get("path_text", ""))
	if is_instance_valid(runtime_debug_label):
		runtime_debug_label.text = "Live Debug: %s | %s | %s" % [
			actor,
			path_text if not path_text.is_empty() else "No active path",
			leaf_status
		]


func _clear_runtime_highlights() -> void:
	if not is_instance_valid(graph_edit):
		return
	for child in graph_edit.get_children():
		if child is BTGraphNode:
			child.set_runtime_state(false, false, "")


func _update_fisheye(delta: float) -> void:
	if not is_instance_valid(graph_edit):
		return
	if fisheye_wheel_pause_elapsed > 0.0:
		fisheye_wheel_pause_elapsed -= delta
		return
	if not fisheye_enabled:
		graph_edit.fisheye_focus_position = Vector2.ZERO
		graph_edit.queue_redraw()
		return
	var mouse_position := get_viewport().get_mouse_position()
	if not graph_edit.get_global_rect().has_point(mouse_position):
		_reset_fisheye(delta)
		return
	var weight_sum := 0.0
	var weighted_local_position := Vector2.ZERO
	for child in graph_edit.get_children():
		if not (child is BTGraphNode):
			continue
		var graph_node: BTGraphNode = child
		var center := graph_node.get_global_rect().get_center()
		var distance := center.distance_to(mouse_position)
		var influence := _fisheye_influence(distance)
		var target_scale := lerpf(FISHEYE_MIN_SCALE, FISHEYE_MAX_SCALE, influence)
		_apply_node_fisheye_scale(graph_node, target_scale, influence, delta)
		if influence > 0.0:
			weight_sum += influence
			weighted_local_position += graph_edit.get_global_transform().affine_inverse() * center * influence
	if weight_sum > 0.0:
		graph_edit.fisheye_focus_position = weighted_local_position / weight_sum
	else:
		graph_edit.fisheye_focus_position = graph_edit.get_global_transform().affine_inverse() * mouse_position
	graph_edit.queue_redraw()


func _on_graph_view_wheel_scrolled() -> void:
	fisheye_wheel_pause_elapsed = FISHEYE_WHEEL_PAUSE


func _fisheye_influence(distance: float) -> float:
	if distance >= FISHEYE_RADIUS:
		return 0.0
	var normalized := clampf(distance / FISHEYE_RADIUS, 0.0, 1.0)
	var falloff := 1.0 - normalized
	return falloff * falloff * (3.0 - 2.0 * falloff)


func _apply_node_fisheye_scale(graph_node: BTGraphNode, target_scale: float, influence: float, delta: float) -> void:
	graph_node.pivot_offset = graph_node.size * 0.5
	var blend := clampf(delta * FISHEYE_LERP_SPEED, 0.0, 1.0)
	var current_scale := graph_node.scale.x
	var next_scale := lerpf(current_scale, target_scale, blend)
	graph_node.scale = Vector2(next_scale, next_scale)
	graph_node.z_index = 100 + int(influence * 1000.0) if influence > 0.0 else 0


func _reset_fisheye(delta := 0.0) -> void:
	if not is_instance_valid(graph_edit):
		return
	graph_edit.fisheye_focus_position = Vector2.ZERO
	var blend := 1.0 if delta <= 0.0 else clampf(delta * FISHEYE_LERP_SPEED, 0.0, 1.0)
	for child in graph_edit.get_children():
		if not (child is BTGraphNode):
			continue
		var graph_node: BTGraphNode = child
		var next_scale := lerpf(graph_node.scale.x, 1.0, blend)
		graph_node.scale = Vector2(next_scale, next_scale)
		graph_node.z_index = 0
	graph_edit.queue_redraw()


func _array_has_node_id(values: Array, node_id: int) -> bool:
	for value in values:
		if int(value) == node_id:
			return true
	return false


func _sync_inspector_into_selected_node() -> void:
	var node := _get_selected_node()
	if node == null:
		return
	node.title = node_title_edit.text.strip_edges()
	node.node_type = node_type_edit.get_item_text(node_type_edit.selected)
	node.description = node_description_edit.text
	var parsed := JSON.parse_string(node_parameters_edit.text)
	if typeof(parsed) == TYPE_DICTIONARY:
		node.parameters = parsed
	var graph_node := graph_edit.get_node_or_null(NodePath(str(node.id)))
	if graph_node != null:
		graph_node.setup(
			node,
			_get_sibling_order(node),
			current_tree.get_decorators_of(node.id),
			current_tree.get_children_of(node.id).size(),
			_count_collapsible_descendants(node.id),
			_build_collapsed_preview(node.id)
		)


func _add_node_from_palette(type_name: String) -> void:
	var position := Vector2(160.0, 160.0)
	if selected_node_id != -1:
		var parent := current_tree.find_node(selected_node_id)
		if parent != null:
			var sibling_index := current_tree.get_children_of(parent.id).size()
			position = parent.position + Vector2((sibling_index - 1) * 260.0, 180.0)
	_create_node_from_ui(type_name, position)


func _on_node_type_dropped(type_name: String, local_position: Vector2) -> void:
	_create_node_from_ui(type_name, _graph_local_to_tree_position(local_position))


func _on_canvas_context_requested(local_position: Vector2) -> void:
	pending_context_position = _graph_local_to_tree_position(local_position)
	_popup_context_menu()


func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		0:
			_create_node_from_ui(BTNodeResource.TYPE_ROOT, pending_context_position)
		1:
			_create_node_from_ui(BTNodeResource.TYPE_SEQUENCE, pending_context_position)
		2:
			_create_node_from_ui(BTNodeResource.TYPE_SELECTOR, pending_context_position)
		3:
			_create_node_from_ui(BTNodeResource.TYPE_ACTION, pending_context_position)
		4:
			_create_node_from_ui(BTNodeResource.TYPE_CONDITION, pending_context_position)
		5:
			_create_node_from_ui(BTNodeResource.TYPE_DECORATOR, pending_context_position)
		20:
			_disconnect_selected_node()
		21:
			_delete_selected_node()
		22:
			_toggle_selected_enabled()
		23:
			_toggle_selected_collapsed()
		30:
			_auto_arrange_tree()
		31:
			_attach_decorator_to_selected("Blackboard", {
				"mode": "blackboard",
				"blackboard_key": "can_attack",
				"operator": "equals",
				"value": true,
				"invert": false
			})
		32:
			_attach_decorator_to_selected("Cooldown", {
				"mode": "cooldown",
				"duration": 1.0
			})


func _create_node_from_ui(type_name: String, position: Vector2) -> void:
	if type_name == BTNodeResource.TYPE_ROOT:
		if current_tree.root_node_id != -1:
			_set_status("This tree already has a root node.")
			return
		_push_history()
		var root := _create_node(BTNodeResource.TYPE_ROOT, position, -1)
		current_tree.root_node_id = root.id
		selected_node_id = root.id
		_refresh_entire_ui()
		_set_status("Added root node.")
		return

	if type_name == BTNodeResource.TYPE_DECORATOR and selected_node_id != -1:
		_attach_decorator_to_selected("Blackboard", _default_parameters_for(BTNodeResource.TYPE_DECORATOR))
		return

	var parent_id := selected_node_id
	if current_tree.find_node(parent_id) == null:
		parent_id = -1
	_push_history()
	var node := _create_node(type_name, position, parent_id)
	selected_node_id = node.id
	_refresh_entire_ui()
	_set_status("Added %s node." % type_name)


func _attach_decorator_to_selected(title: String, parameters: Dictionary) -> void:
	var owner := _get_selected_node()
	if owner == null:
		_set_status("Select a node before attaching a decorator.")
		return
	if owner.node_type == BTNodeResource.TYPE_DECORATOR:
		_set_status("Decorators cannot own decorators.")
		return
	_push_history()
	var decorator := _create_node(BTNodeResource.TYPE_DECORATOR, owner.position + Vector2(0.0, -90.0), -1)
	decorator.title = title
	decorator.description = "Attached decorator for %s." % owner.title
	decorator.parameters = parameters.duplicate(true)
	decorator.decorator_parent_id = owner.id
	selected_node_id = owner.id
	_refresh_entire_ui()
	_set_status("Attached %s decorator to %s." % [title, owner.title])


func _graph_local_to_tree_position(local_position: Vector2) -> Vector2:
	return (local_position / max(0.01, graph_edit.zoom)) + graph_edit.scroll_offset


func _popup_context_menu() -> void:
	context_menu.set_item_disabled(context_menu.get_item_index(0), current_tree.root_node_id != -1)
	var has_selection := selected_node_id != -1
	context_menu.set_item_disabled(context_menu.get_item_index(20), not has_selection or selected_node_id == current_tree.root_node_id)
	context_menu.set_item_disabled(context_menu.get_item_index(21), not has_selection)
	context_menu.set_item_disabled(context_menu.get_item_index(22), not has_selection)
	context_menu.set_item_disabled(context_menu.get_item_index(23), not has_selection or current_tree.get_children_of(selected_node_id).is_empty())
	context_menu.set_item_disabled(context_menu.get_item_index(31), not has_selection)
	context_menu.set_item_disabled(context_menu.get_item_index(32), not has_selection)
	context_menu.position = DisplayServer.mouse_get_position()
	context_menu.popup()


func _disconnect_selected_node() -> void:
	var node := _get_selected_node()
	if node == null or node.parent_id == -1:
		_set_status("Selected node has no parent.")
		return
	_push_history()
	node.parent_id = -1
	_rebuild_graph()
	_set_status("Disconnected selected node from its parent.")


func _toggle_selected_enabled() -> void:
	var node := _get_selected_node()
	if node == null:
		return
	_push_history()
	node.enabled = not node.enabled
	_refresh_entire_ui()
	_set_status("%s node #%d." % ["Enabled" if node.enabled else "Disabled", node.id])


func _toggle_selected_collapsed() -> void:
	var node := _get_selected_node()
	if node == null:
		return
	if current_tree.get_children_of(node.id).is_empty():
		_set_status("Selected node has no child subtree to collapse.")
		return
	_on_graph_node_collapse_toggled(node.id)


func _auto_arrange_tree() -> void:
	if current_tree == null or current_tree.root_node_id == -1:
		_set_status("Create or load a tree before arranging.")
		return
	var root := current_tree.find_node(current_tree.root_node_id)
	if root == null:
		_set_status("Root node is missing.")
		return
	_push_history()
	var cursor := {"x": 120.0}
	_arrange_subtree(root, 0, cursor)
	_refresh_entire_ui()
	_set_status("Auto arranged tree in behavior-tree layout.")


func _arrange_subtree(node: BTNodeResource, depth: int, cursor: Dictionary) -> float:
	var children := current_tree.get_children_of(node.id)
	var y := 120.0 + float(depth) * 210.0
	if children.is_empty():
		var leaf_x: float = cursor["x"]
		node.position = Vector2(leaf_x, y)
		cursor["x"] = leaf_x + 280.0
		return leaf_x

	var child_positions: Array[float] = []
	for child in children:
		child_positions.append(_arrange_subtree(child, depth + 1, cursor))
	var first_x := child_positions[0]
	var last_x := child_positions[child_positions.size() - 1]
	node.position = Vector2((first_x + last_x) * 0.5, y)
	return node.position.x


func _get_sibling_order(node: BTNodeResource) -> int:
	if node == null or node.parent_id == -1:
		return -1
	var siblings := current_tree.get_children_of(node.parent_id)
	return siblings.find(node) + 1


func _push_history() -> void:
	if current_tree == null:
		return
	undo_stack.append(current_tree.duplicate_tree())
	redo_stack.clear()
	if undo_stack.size() > 50:
		undo_stack.pop_front()
	_update_history_buttons()


func _undo() -> void:
	if undo_stack.is_empty() or current_tree == null:
		return
	redo_stack.append(current_tree.duplicate_tree())
	current_tree = undo_stack.pop_back()
	selected_node_id = -1
	next_node_id = _calculate_next_id()
	_refresh_entire_ui()
	_set_status("Undo complete.")


func _redo() -> void:
	if redo_stack.is_empty() or current_tree == null:
		return
	undo_stack.append(current_tree.duplicate_tree())
	current_tree = redo_stack.pop_back()
	selected_node_id = -1
	next_node_id = _calculate_next_id()
	_refresh_entire_ui()
	_set_status("Redo complete.")


func _update_history_buttons() -> void:
	if is_instance_valid(undo_button):
		undo_button.disabled = undo_stack.is_empty()
	if is_instance_valid(redo_button):
		redo_button.disabled = redo_stack.is_empty()


func _calculate_next_id() -> int:
	var max_id := 0
	for node in current_tree.nodes:
		if node != null:
			max_id = max(max_id, node.id)
	return max_id + 1


func _get_selected_node() -> BTNodeResource:
	if current_tree == null or selected_node_id == -1:
		return null
	return current_tree.find_node(selected_node_id)


func _collect_descendant_ids(node_id: int) -> Array[int]:
	var result: Array[int] = []
	for node in current_tree.nodes:
		if node != null and node.parent_id == node_id:
			result.append(node.id)
			result.append_array(_collect_descendant_ids(node.id))
	return result


func _collect_subtree_and_attached_decorator_ids(node_id: int) -> Array[int]:
	var result := _collect_descendant_ids(node_id)
	result.append(node_id)
	for node in current_tree.nodes:
		if node == null:
			continue
		if node.decorator_parent_id == node_id or result.has(node.decorator_parent_id):
			result.append(node.id)
	return result


func _count_collapsible_descendants(node_id: int) -> int:
	return _collect_descendant_ids(node_id).size()


func _build_collapsed_preview(node_id: int) -> String:
	var lines: Array[String] = []
	var children := current_tree.get_children_of(node_id)
	var max_children := min(children.size(), 4)
	for index in range(max_children):
		var child := children[index]
		var grandchildren := current_tree.get_children_of(child.id)
		var child_text := _short_node_label(child)
		if not grandchildren.is_empty():
			var names: Array[String] = []
			var max_grandchildren := min(grandchildren.size(), 3)
			for grandchild_index in range(max_grandchildren):
				names.append(_short_node_label(grandchildren[grandchild_index]))
			if grandchildren.size() > max_grandchildren:
				names.append("...")
			child_text += " -> %s" % ", ".join(names)
		lines.append(child_text)
	if children.size() > max_children:
		lines.append("...")
	return "\n".join(lines)


func _short_node_label(node: BTNodeResource) -> String:
	if node == null:
		return ""
	var label := "%s: %s" % [node.node_type, node.title]
	if label.length() > 36:
		return "%s..." % label.substr(0, 33)
	return label


func _is_node_hidden_by_collapsed_ancestor(node: BTNodeResource) -> bool:
	if node == null:
		return false
	var cursor := current_tree.find_node(node.parent_id)
	while cursor != null:
		if cursor.collapsed:
			return true
		cursor = current_tree.find_node(cursor.parent_id)
	return false


func _is_attached_decorator(node: BTNodeResource) -> bool:
	return node != null and node.decorator_parent_id != -1


func _node_contains_any_id(node_id: int, values: Array) -> bool:
	var descendants := _collect_descendant_ids(node_id)
	for value in values:
		if descendants.has(int(value)):
			return true
	return false


func _would_create_cycle(parent_id: int, child_id: int) -> bool:
	if parent_id == child_id:
		return true
	var cursor := current_tree.find_node(parent_id)
	while cursor != null and cursor.parent_id != -1:
		if cursor.parent_id == child_id:
			return true
		cursor = current_tree.find_node(cursor.parent_id)
	return false


func _default_description_for(type_name: String) -> String:
	match type_name:
		BTNodeResource.TYPE_ROOT:
			return "Entry point for the tree."
		BTNodeResource.TYPE_SEQUENCE:
			return "Runs children from left to right until one fails."
		BTNodeResource.TYPE_SELECTOR:
			return "Runs children until one succeeds."
		BTNodeResource.TYPE_ACTION:
			return "Leaf action executed by the agent."
		BTNodeResource.TYPE_CONDITION:
			return "Leaf condition check."
		BTNodeResource.TYPE_DECORATOR:
			return "Wraps one child and changes its behavior."
		_:
			return ""


func _default_parameters_for(type_name: String) -> Dictionary:
	match type_name:
		BTNodeResource.TYPE_ACTION:
			return {"action_name": "move_to_target"}
		BTNodeResource.TYPE_CONDITION:
			return {"condition_name": "", "blackboard_key": "has_target", "expected": true}
		BTNodeResource.TYPE_DECORATOR:
			return {"mode": "blackboard", "blackboard_key": "can_attack", "operator": "equals", "value": true, "invert": false}
		_:
			return {}


func _set_status(message: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = message
