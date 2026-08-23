@tool
extends VBoxContainer
class_name BTEditorView

const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")
const BTNodeResource = preload("res://addons/behavior_tree_editor/bt_node_resource.gd")
const BTGraphNode = preload("res://addons/behavior_tree_editor/bt_graph_node.gd")
const BTGraphEdit = preload("res://addons/behavior_tree_editor/bt_graph_edit.gd")
const BTPaletteItem = preload("res://addons/behavior_tree_editor/bt_palette_item.gd")
const BTBlackboardEntry = preload("res://addons/behavior_tree_editor/bt_blackboard_entry.gd")
const BTBlackboardSchema = preload("res://addons/behavior_tree_editor/bt_blackboard_schema.gd")
const RUNTIME_DEBUG_PATH := "res://.godot/behavior_tree_runtime_debug.json"

const NODE_TYPES := [
	BTNodeResource.TYPE_ROOT,
	BTNodeResource.TYPE_SEQUENCE,
	BTNodeResource.TYPE_SELECTOR,
	BTNodeResource.TYPE_RANDOM_SELECTOR,
	BTNodeResource.TYPE_PARALLEL,
	BTNodeResource.TYPE_REPEAT,
	BTNodeResource.TYPE_ACTION,
	BTNodeResource.TYPE_CONDITION,
	BTNodeResource.TYPE_WAIT,
	BTNodeResource.TYPE_DECORATOR
]
const FISHEYE_MAX_SCALE := 1.25
const FISHEYE_CONTEXT_SCALE := 0.78
const FISHEYE_LERP_SPEED := 12.0
const FISHEYE_WHEEL_PAUSE := 0.2
const FISHEYE_RESUME_POINTER_DISTANCE := 6.0
const VIEW_SETTINGS_PATH := "user://behavior_tree_editor_view.cfg"
const MULTI_COLUMN_THRESHOLD := 5
const MULTI_COLUMN_COUNT := 4
const LAYOUT_START := Vector2(120.0, 100.0)
const LAYOUT_HORIZONTAL_GAP := 330.0
const LAYOUT_VERTICAL_GAP := 310.0
const LAYOUT_MIN_VERTICAL_CLEARANCE := 60.0
const OVERVIEW_LAYOUT_HORIZONTAL_GAP := BTGraphNode.NORMAL_CARD_SIZE.x + 24.0
const OVERVIEW_LAYOUT_VERTICAL_GAP := BTGraphNode.NORMAL_CARD_SIZE.y + 24.0
const AUTO_SPACING_GAP := 24.0
const AUTO_SPACING_ITERATIONS := 32
const AUTO_SPACING_SEPARATION_EPSILON := 0.05
const AUTO_SPACING_IDENTICAL_GROUP_MIN_SIZE := 5
const AUTO_SPACING_POSITION_BUCKET := 0.05
const AUTO_SPACING_LERP_SPEED := 14.0
const AUTO_SPACING_EPSILON := 0.1
const ZOOM_LAYOUT_ANCHOR_STABLE_FRAMES := 8
const ZOOM_LAYOUT_ANCHOR_RELEASE_DELAY := 0.65
const ZOOM_CENTER_SAMPLE_LIMIT := 12
const ZOOM_CENTER_SAMPLE_RADIUS_FACTOR := 1.25
const DISPLAY_MENU_GRID_ID := 1000
const DEBUG_MENU_LIVE_ID := 0
const DEBUG_MENU_DIM_ID := 1
const DEBUG_MENU_FAILURE_ID := 2
const DEBUG_MENU_BLACKBOARD_ID := 3
const DEBUG_MENU_SCHEMA_ID := 4
const LAYOUT_MENU_AUTO_ARRANGE_ID := 0
const LAYOUT_MENU_OVERVIEW_ID := 1
const LAYOUT_MENU_COLLAPSE_ID := 2
const LAYOUT_MENU_EXPAND_ID := 3
const LAYOUT_MENU_FOCUS_ID := 4
const LAYOUT_MENU_SHOW_ALL_ID := 5
const LAYOUT_MENU_FIT_ID := 6
const FEATURE_DEFINITIONS := [
	["fisheye", "Fisheye / Focus+Context", true],
	["subtree_collapse", "Subtree Collapse / Expand", true],
	["compact", "Compact Mode", false],
	["type_encoding", "Shape / Icon Type Encoding", false],
	["accessibility", "Accessibility / Colorblind Palette", false],
	["single_connection", "Single Connection Rendering", true],
	["active_path", "Active Path Highlight", true],
	["branch_dimming", "Non-active Branch Dimming", false],
	["multi_column", "Multi-column Layout", false],
	["enhanced_minimap", "Overview + Detail / Enhanced Minimap", true],
	["semantic_zoom", "Semantic Zoom", false],
	["auto_spacing", "Zoom-Aware Auto Spacing", true],
	["zoom_anchor", "Zoom View Anchor", true],
	["path_summary", "Path Summary View", false],
	["decorator_badges", "Decorator Condition Badges", true],
	["search", "Search + Highlight", true],
	["orthogonal_edges", "Orthogonal Edges", false],
	["edge_bundling", "Edge Bundling", false],
	["stable_layout", "Stable Incremental Layout", false],
	["breadcrumb", "Breadcrumb Navigation", false],
	["failure_reason", "Failure Reason Annotation", true],
]

var plugin: EditorPlugin
var current_tree: BTTreeResource
var current_tree_path: String = "res://behavior_trees/new_behavior_tree.tres"
var selected_node_id: int = -1
var next_node_id: int = 1
var undo_stack: Array[BTTreeResource] = []
var redo_stack: Array[BTTreeResource] = []
var pending_context_position: Vector2 = Vector2.ZERO
var suppress_inspector_changes := false
var suppress_schema_changes := false
var runtime_debug_enabled := true
var runtime_debug_elapsed := 0.0
var runtime_debug_actor := ""
var fisheye_enabled := true
var fisheye_wheel_pause_elapsed := 0.0
var fisheye_focus_node_id := -1
var fisheye_waiting_for_pointer_motion := false
var fisheye_resume_pointer_position := Vector2.ZERO
var compact_mode_enabled := false
var semantic_zoom_enabled := false
var semantic_detail_level := 2
var focus_root_id := -1
var search_query := ""
var search_result_ids: Array[int] = []
var search_result_index := -1
var feature_states: Dictionary = {}
var last_runtime_snapshot: Dictionary = {}
var last_runtime_visual_signature := ""
var drag_history_snapshot: BTTreeResource
var drag_history_node_id := -1
var drag_history_position := Vector2.ZERO

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
var branch_dimming_toggle: CheckBox
var failure_reason_toggle: CheckBox
var failure_summary_button: MenuButton
var fisheye_toggle: CheckBox
var compact_toggle: CheckBox
var semantic_zoom_toggle: CheckBox
var path_summary_toggle: CheckBox
var search_toggle: CheckBox
var grid_toggle: CheckBox
var minimap_toggle: CheckBox
var minimap_status_label: Label
var feature_menu_button: MenuButton
var advanced_display_menu: PopupMenu
var debug_menu_button: MenuButton
var layout_menu_button: MenuButton
var new_tree_dialog: ConfirmationDialog
var new_tree_name_edit: LineEdit
var path_navigation_row: VBoxContainer
var runtime_path_label: Label
var runtime_path_scroll: ScrollContainer
var runtime_path_container: HBoxContainer
var runtime_path_actor_label: Label
var runtime_path_status_label: Label
var runtime_path_depth_label: Label
var selection_path_scroll: ScrollContainer
var selection_path_container: HBoxContainer
var selection_path_row: HBoxContainer
var search_edit: LineEdit
var search_result_label: Label
var search_previous_button: Button
var search_next_button: Button
var runtime_debug_label: Label
var blackboard_toggle: CheckBox
var blackboard_panel: PanelContainer
var blackboard_summary_label: Label
var blackboard_grid: GridContainer
var schema_toggle: CheckBox
var schema_panel: PanelContainer
var schema_summary_label: Label
var schema_dynamic_keys_toggle: CheckBox
var schema_grid: GridContainer
var schema_row_controls: Array[Dictionary] = []
var context_menu: PopupMenu

var inspector_panel: PanelContainer
var selected_label: Label
var node_title_edit: LineEdit
var node_type_edit: OptionButton
var node_description_edit: TextEdit
var typed_parameters_container: VBoxContainer
var palette_scroll: ScrollContainer
var palette_content: VBoxContainer
var advanced_parameters_toggle: CheckButton
var node_parameters_edit: TextEdit
var parameter_controls: Dictionary = {}
var parameter_rows: Dictionary = {}
var decorator_picker: OptionButton
var edit_decorator_button: Button
var remove_decorator_button: Button
var return_to_owner_button: Button
var minimap_status_signature := ""
var minimap_visible_node_count := 0
var minimap_total_node_count := 0
var visible_failure_annotations: Array[Dictionary] = []
var auto_spacing_targets: Dictionary = {}
var auto_spacing_signature := ""
var pending_auto_spacing_anchor_id := -1
var drag_auto_spacing_base_targets: Dictionary = {}
var drag_auto_spacing_original_targets: Dictionary = {}
var pending_auto_spacing_seed_targets: Dictionary = {}
var live_auto_spacing_refresh_pending := false
var zoom_anchor_candidate_id := -1
var zoom_anchor_candidate_screen_position := Vector2.ZERO
var zoom_anchor_candidate_zoom := 1.0
var zoom_anchor_candidate_frames := 0
var zoom_anchor_candidate_view_center := Vector2.ZERO
var zoom_anchor_candidate_samples: Array[Dictionary] = []
var zoom_layout_anchor_id := -1
var zoom_layout_anchor_screen_position := Vector2.ZERO
var zoom_layout_anchor_last_center := Vector2.ZERO
var zoom_layout_anchor_last_zoom := 1.0
var zoom_layout_anchor_stable_frames := 0
var zoom_layout_anchor_release_elapsed := 0.0
var zoom_layout_anchor_restore_queued := false
var zoom_layout_anchor_samples: Array[Dictionary] = []


func _ready() -> void:
	size_flags_vertical = SIZE_EXPAND_FILL
	size_flags_horizontal = SIZE_EXPAND_FILL
	set_process(true)
	_build_ui()
	_initialize_feature_states()
	_load_view_settings()
	_refresh_tree_path_picker()
	_new_tree()


func _process(delta: float) -> void:
	_poll_runtime_debug(delta)
	zoom_layout_anchor_release_elapsed = maxf(0.0, zoom_layout_anchor_release_elapsed - delta)
	_prepare_zoom_layout_anchor()
	if drag_history_node_id == -1:
		_update_fisheye(delta)
	_update_semantic_zoom()
	_update_auto_spacing(delta)
	_restore_zoom_layout_anchor()
	_queue_zoom_layout_anchor_post_layout_restore()
	_update_minimap_status()


func _gui_input(event: InputEvent) -> void:
	if not _feature_enabled("accessibility") or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F and event.ctrl_pressed:
		search_edit.grab_focus()
		search_edit.select_all()
		accept_event()
	elif event.keycode == KEY_F3:
		_navigate_search_result(-1 if event.shift_pressed else 1)
		accept_event()


func _build_ui() -> void:
	var toolbar := HBoxContainer.new()
	toolbar.name = "MainToolbar"
	toolbar.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(toolbar)
	var tree_label := Label.new()
	tree_label.text = "Tree"
	toolbar.add_child(tree_label)

	tree_path_picker = OptionButton.new()
	tree_path_picker.custom_minimum_size = Vector2(260.0, 0.0)
	tree_path_picker.size_flags_horizontal = SIZE_EXPAND_FILL
	tree_path_picker.tooltip_text = "Choose a behavior tree from this project."
	tree_path_picker.item_selected.connect(_on_tree_path_selected)
	toolbar.add_child(tree_path_picker)

	var refresh_paths_button := Button.new()
	refresh_paths_button.text = "↻"
	refresh_paths_button.tooltip_text = "Refresh the behavior tree list."
	refresh_paths_button.pressed.connect(_refresh_tree_path_picker)
	toolbar.add_child(refresh_paths_button)

	var new_button := Button.new()
	new_button.text = "New"
	new_button.tooltip_text = "Create a named behavior tree."
	new_button.pressed.connect(_show_new_tree_dialog)
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
	save_button.text = "Save"
	save_button.pressed.connect(_save_tree)
	toolbar.add_child(save_button)

	# Compatibility mirrors retain the existing save/load implementation without
	# exposing internal resource paths or duplicate tree-name fields to users.
	tree_name_edit = LineEdit.new()
	tree_name_edit.text_submitted.connect(_on_tree_name_submitted)
	tree_name_edit.focus_exited.connect(_on_tree_name_focus_exited)
	tree_name_edit.visible = false
	toolbar.add_child(tree_name_edit)

	file_path_edit = LineEdit.new()
	file_path_edit.text = current_tree_path
	file_path_edit.visible = false
	toolbar.add_child(file_path_edit)

	layout_menu_button = MenuButton.new()
	layout_menu_button.text = "Layout"
	layout_menu_button.tooltip_text = "Arrange, focus, collapse, or fit the graph."
	toolbar.add_child(layout_menu_button)
	_build_layout_menu()

	feature_menu_button = MenuButton.new()
	feature_menu_button.text = "Display"
	feature_menu_button.tooltip_text = "Graph readability and appearance options."
	toolbar.add_child(feature_menu_button)
	_build_feature_menu()

	debug_menu_button = MenuButton.new()
	debug_menu_button.text = "Debug"
	debug_menu_button.tooltip_text = "Live Debug, failures, Blackboard values, and schema authoring."
	toolbar.add_child(debug_menu_button)
	_build_debug_menu()

	new_tree_dialog = ConfirmationDialog.new()
	new_tree_dialog.title = "New Behavior Tree"
	new_tree_dialog.ok_button_text = "Create"
	new_tree_dialog.confirmed.connect(_create_named_tree)
	add_child(new_tree_dialog)
	new_tree_name_edit = LineEdit.new()
	new_tree_name_edit.placeholder_text = "Behavior tree name"
	new_tree_name_edit.custom_minimum_size = Vector2(360.0, 0.0)
	new_tree_dialog.add_child(new_tree_name_edit)

	var runtime_row := HBoxContainer.new()
	runtime_row.name = "RuntimeToolbar"
	runtime_row.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(runtime_row)

	# Keep compatibility controls as hidden state mirrors for existing projects and tests.
	live_debug_toggle = CheckBox.new()
	live_debug_toggle.text = "Live Debug"
	live_debug_toggle.button_pressed = true
	live_debug_toggle.toggled.connect(_on_live_debug_toggled)
	live_debug_toggle.visible = false
	runtime_row.add_child(live_debug_toggle)

	branch_dimming_toggle = CheckBox.new()
	branch_dimming_toggle.text = "Dim Inactive"
	branch_dimming_toggle.tooltip_text = "Fade nodes outside the current runtime path while Live Debug is active."
	branch_dimming_toggle.toggled.connect(_on_branch_dimming_toggled)
	branch_dimming_toggle.visible = false
	runtime_row.add_child(branch_dimming_toggle)

	failure_reason_toggle = CheckBox.new()
	failure_reason_toggle.text = "Failure Reasons"
	failure_reason_toggle.tooltip_text = "Annotate failed nodes and list the latest runtime failure causes."
	failure_reason_toggle.toggled.connect(_on_failure_reason_toggled)
	failure_reason_toggle.visible = false
	runtime_row.add_child(failure_reason_toggle)

	failure_summary_button = MenuButton.new()
	failure_summary_button.text = "Failures: 0"
	failure_summary_button.tooltip_text = "Select a failure to center its node."
	failure_summary_button.get_popup().id_pressed.connect(_on_failure_summary_selected)
	runtime_row.add_child(failure_summary_button)

	blackboard_toggle = CheckBox.new()
	blackboard_toggle.text = "Blackboard"
	blackboard_toggle.tooltip_text = "Show typed values from the current Live Debug actor inside the editor."
	blackboard_toggle.toggled.connect(_on_blackboard_panel_toggled)
	blackboard_toggle.visible = false
	runtime_row.add_child(blackboard_toggle)

	schema_toggle = CheckBox.new()
	schema_toggle.text = "Edit Schema"
	schema_toggle.tooltip_text = "Author typed blackboard keys stored in this behavior tree resource."
	schema_toggle.toggled.connect(_on_schema_panel_toggled)
	schema_toggle.visible = false
	runtime_row.add_child(schema_toggle)

	runtime_debug_label = Label.new()
	runtime_debug_label.size_flags_horizontal = SIZE_EXPAND_FILL
	runtime_debug_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	runtime_debug_label.clip_text = true
	runtime_debug_label.text = "Run the game to highlight the active behavior path here."
	runtime_row.add_child(runtime_debug_label)

	blackboard_panel = PanelContainer.new()
	blackboard_panel.visible = false
	add_child(blackboard_panel)
	var blackboard_content := VBoxContainer.new()
	blackboard_panel.add_child(blackboard_content)
	blackboard_summary_label = Label.new()
	blackboard_summary_label.text = "Live Blackboard: waiting for a running actor."
	blackboard_content.add_child(blackboard_summary_label)
	var blackboard_scroll := ScrollContainer.new()
	blackboard_scroll.custom_minimum_size = Vector2(0.0, 120.0)
	blackboard_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	blackboard_content.add_child(blackboard_scroll)
	blackboard_grid = GridContainer.new()
	blackboard_grid.columns = 4
	blackboard_grid.size_flags_horizontal = SIZE_EXPAND_FILL
	blackboard_scroll.add_child(blackboard_grid)
	_refresh_blackboard_panel({})

	schema_panel = PanelContainer.new()
	schema_panel.visible = false
	add_child(schema_panel)
	var schema_content := VBoxContainer.new()
	schema_panel.add_child(schema_content)
	var schema_header := HBoxContainer.new()
	schema_content.add_child(schema_header)
	var schema_title := Label.new()
	schema_title.text = "Blackboard Schema Authoring"
	schema_title.tooltip_text = "These declarations are saved with the tree. Live Blackboard values are displayed separately."
	schema_title.size_flags_horizontal = SIZE_EXPAND_FILL
	schema_header.add_child(schema_title)
	schema_dynamic_keys_toggle = CheckBox.new()
	schema_dynamic_keys_toggle.text = "Allow Dynamic Keys"
	schema_dynamic_keys_toggle.tooltip_text = "When disabled, runtime keys not declared below are reported as schema errors."
	schema_dynamic_keys_toggle.toggled.connect(_on_schema_dynamic_keys_toggled)
	schema_header.add_child(schema_dynamic_keys_toggle)
	var schema_add_button := Button.new()
	schema_add_button.text = "Add Key"
	schema_add_button.tooltip_text = "Add a typed blackboard declaration."
	schema_add_button.pressed.connect(_add_schema_entry)
	schema_header.add_child(schema_add_button)
	schema_summary_label = Label.new()
	schema_summary_label.text = "Schema: 0 keys - valid."
	schema_summary_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	schema_summary_label.tooltip_text = "Schema validation status."
	schema_content.add_child(schema_summary_label)
	var schema_scroll := ScrollContainer.new()
	schema_scroll.custom_minimum_size = Vector2(0.0, 168.0)
	schema_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	schema_content.add_child(schema_scroll)
	schema_grid = GridContainer.new()
	schema_grid.columns = 6
	schema_grid.size_flags_horizontal = SIZE_EXPAND_FILL
	schema_scroll.add_child(schema_grid)
	_refresh_schema_editor()

	var view_row := HBoxContainer.new()
	view_row.name = "ViewToolbar"
	view_row.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(view_row)

	# Retain these controls as compatibility state mirrors without duplicating the menu in the toolbar.
	fisheye_toggle = CheckBox.new()
	fisheye_toggle.text = "Fisheye"
	fisheye_toggle.button_pressed = true
	fisheye_toggle.toggled.connect(_on_fisheye_toggled)
	fisheye_toggle.visible = false
	view_row.add_child(fisheye_toggle)

	compact_toggle = CheckBox.new()
	compact_toggle.text = "Compact"
	compact_toggle.tooltip_text = "Use smaller cards with only the node title and type color."
	compact_toggle.toggled.connect(_on_compact_toggled)
	compact_toggle.visible = false
	view_row.add_child(compact_toggle)

	semantic_zoom_toggle = CheckBox.new()
	semantic_zoom_toggle.text = "Semantic Zoom"
	semantic_zoom_toggle.tooltip_text = "Reduce card information when zoomed out; Zoom-Aware Auto Spacing prevents expanded cards from overlapping."
	semantic_zoom_toggle.toggled.connect(_on_semantic_zoom_toggled)
	semantic_zoom_toggle.visible = false
	view_row.add_child(semantic_zoom_toggle)

	path_summary_toggle = CheckBox.new()
	path_summary_toggle.text = "Path Summary"
	path_summary_toggle.tooltip_text = "Show the current Root-to-leaf runtime path with actor, status, and depth."
	path_summary_toggle.toggled.connect(_on_path_summary_toggled)
	path_summary_toggle.visible = false
	view_row.add_child(path_summary_toggle)

	grid_toggle = CheckBox.new()
	grid_toggle.text = "Grid"
	grid_toggle.button_pressed = true
	grid_toggle.toggled.connect(_on_grid_toggled)
	grid_toggle.visible = false
	view_row.add_child(grid_toggle)

	minimap_toggle = CheckBox.new()
	minimap_toggle.text = "Minimap"
	minimap_toggle.button_pressed = true
	minimap_toggle.toggled.connect(_on_minimap_toggled)
	minimap_toggle.visible = false
	view_row.add_child(minimap_toggle)
	minimap_status_label = Label.new()
	minimap_status_label.tooltip_text = "Visible nodes represented in the overview and the current detail-view zoom."
	minimap_status_label.visible = false
	view_row.add_child(minimap_status_label)

	view_row.visible = false

	var search_row := HBoxContainer.new()
	search_row.name = "SearchToolbar"
	search_row.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(search_row)
	search_toggle = CheckBox.new()
	search_toggle.text = "Search"
	search_toggle.tooltip_text = "Search and highlight nodes across the complete tree."
	search_toggle.toggled.connect(_on_search_toggled)
	search_toggle.visible = false
	search_row.add_child(search_toggle)
	search_edit = LineEdit.new()
	search_edit.placeholder_text = "Find a node..."
	search_edit.tooltip_text = "Search all nodes. Accessibility shortcuts: Ctrl+F focuses search; F3/Shift+F3 moves through results."
	search_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	search_edit.clear_button_enabled = true
	search_edit.text_changed.connect(_on_search_changed)
	search_edit.text_submitted.connect(_on_search_submitted)
	search_row.add_child(search_edit)
	search_result_label = Label.new()
	search_result_label.text = "0 results"
	search_row.add_child(search_result_label)
	search_previous_button = Button.new()
	search_previous_button.text = "‹"
	search_previous_button.tooltip_text = "Previous result (Shift+F3 when Accessibility is enabled)."
	search_previous_button.pressed.connect(_navigate_search_result.bind(-1))
	search_row.add_child(search_previous_button)
	search_next_button = Button.new()
	search_next_button.text = "›"
	search_next_button.tooltip_text = "Next result (F3 when Accessibility is enabled)."
	search_next_button.pressed.connect(_navigate_search_result.bind(1))
	search_row.add_child(search_next_button)

	path_navigation_row = VBoxContainer.new()
	path_navigation_row.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(path_navigation_row)
	var runtime_path_row := HBoxContainer.new()
	runtime_path_row.size_flags_horizontal = SIZE_EXPAND_FILL
	path_navigation_row.add_child(runtime_path_row)
	runtime_path_label = Label.new()
	runtime_path_label.text = "Runtime Path"
	runtime_path_row.add_child(runtime_path_label)
	runtime_path_actor_label = Label.new()
	runtime_path_row.add_child(runtime_path_actor_label)
	runtime_path_status_label = Label.new()
	runtime_path_row.add_child(runtime_path_status_label)
	runtime_path_depth_label = Label.new()
	runtime_path_row.add_child(runtime_path_depth_label)
	runtime_path_scroll = ScrollContainer.new()
	runtime_path_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	runtime_path_scroll.custom_minimum_size = Vector2(0.0, 36.0)
	runtime_path_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	runtime_path_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	runtime_path_row.add_child(runtime_path_scroll)
	runtime_path_container = HBoxContainer.new()
	runtime_path_container.size_flags_horizontal = SIZE_EXPAND_FILL
	runtime_path_scroll.add_child(runtime_path_container)
	selection_path_row = HBoxContainer.new()
	selection_path_row.size_flags_horizontal = SIZE_EXPAND_FILL
	selection_path_row.visible = false
	path_navigation_row.add_child(selection_path_row)
	var selection_path_label := Label.new()
	selection_path_label.text = "Selection"
	selection_path_row.add_child(selection_path_label)
	selection_path_scroll = ScrollContainer.new()
	selection_path_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	selection_path_scroll.custom_minimum_size = Vector2(0.0, 36.0)
	selection_path_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	selection_path_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	selection_path_row.add_child(selection_path_scroll)
	selection_path_container = HBoxContainer.new()
	selection_path_container.size_flags_horizontal = SIZE_EXPAND_FILL
	selection_path_scroll.add_child(selection_path_container)

	var creation_row := HBoxContainer.new()
	creation_row.name = "LegacyCreationToolbar"
	creation_row.size_flags_horizontal = SIZE_EXPAND_FILL
	creation_row.visible = false
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
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label.clip_text = true
	add_child(status_label)

	var content := HSplitContainer.new()
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	content.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(content)

	var palette := VBoxContainer.new()
	palette.name = "NodePalette"
	palette.visible = false
	palette.custom_minimum_size = Vector2.ZERO
	palette.size_flags_vertical = SIZE_EXPAND_FILL
	content.add_child(palette)

	var palette_title := Label.new()
	palette_title.text = "Node Palette"
	palette.add_child(palette_title)

	palette_scroll = ScrollContainer.new()
	palette_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	palette_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	palette_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	palette_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	palette.add_child(palette_scroll)

	palette_content = VBoxContainer.new()
	palette_content.size_flags_horizontal = SIZE_EXPAND_FILL
	palette_scroll.add_child(palette_content)

	graph_edit = BTGraphEdit.new()
	graph_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	graph_edit.size_flags_vertical = SIZE_EXPAND_FILL
	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	graph_edit.custom_edge_disconnect_requested.connect(_on_custom_edge_disconnect_requested)
	graph_edit.manual_connection_requested.connect(_on_manual_connection_requested)
	graph_edit.canvas_context_requested.connect(_on_canvas_context_requested)
	graph_edit.node_type_dropped.connect(_on_node_type_dropped)
	graph_edit.viewport_wheel_scrolled.connect(_on_graph_view_wheel_scrolled)
	content.add_child(graph_edit)

	context_menu = PopupMenu.new()
	context_menu.add_item("Create Root", 0)
	context_menu.add_separator()
	context_menu.add_item("Create Sequence", 1)
	context_menu.add_item("Create Selector", 2)
	context_menu.add_item("Create Random Selector", 7)
	context_menu.add_item("Create Parallel", 6)
	context_menu.add_item("Create Repeat", 8)
	context_menu.add_separator()
	context_menu.add_item("Create Action", 3)
	context_menu.add_item("Create Condition", 4)
	context_menu.add_item("Create Wait", 9)
	context_menu.add_item("Create Decorator", 5)
	context_menu.add_separator()
	context_menu.add_item("Disconnect From Parent", 20)
	context_menu.add_item("Delete Selected", 21)
	context_menu.add_item("Enable / Disable Selected", 22)
	context_menu.add_item("Collapse / Expand Selected", 23)
	context_menu.add_separator()
	context_menu.add_item("Auto Arrange Tree", 30)
	context_menu.add_item("Arrange for Overview", 34)
	context_menu.add_item("Attach Blackboard Decorator", 31)
	context_menu.add_item("Attach Cooldown Decorator", 32)
	context_menu.add_item("Attach Time Limit Decorator", 33)
	context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	add_child(context_menu)

	inspector_panel = PanelContainer.new()
	inspector_panel.custom_minimum_size = Vector2(320.0, 0.0)
	content.add_child(inspector_panel)

	var inspector_scroll := ScrollContainer.new()
	inspector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inspector_panel.add_child(inspector_scroll)
	var inspector := VBoxContainer.new()
	inspector.size_flags_horizontal = SIZE_EXPAND_FILL
	inspector_scroll.add_child(inspector)

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
	parameters_label.text = "Parameters"
	inspector.add_child(parameters_label)

	typed_parameters_container = VBoxContainer.new()
	inspector.add_child(typed_parameters_container)

	advanced_parameters_toggle = CheckButton.new()
	advanced_parameters_toggle.text = "Advanced JSON"
	advanced_parameters_toggle.toggled.connect(_on_advanced_parameters_toggled)
	inspector.add_child(advanced_parameters_toggle)

	node_parameters_edit = TextEdit.new()
	node_parameters_edit.custom_minimum_size = Vector2(0.0, 150.0)
	node_parameters_edit.visible = false
	node_parameters_edit.text_changed.connect(_on_advanced_parameters_changed)
	inspector.add_child(node_parameters_edit)

	var decorator_label := Label.new()
	decorator_label.text = "Attached Decorators"
	inspector.add_child(decorator_label)

	decorator_picker = OptionButton.new()
	inspector.add_child(decorator_picker)

	var decorator_actions := HBoxContainer.new()
	inspector.add_child(decorator_actions)
	edit_decorator_button = Button.new()
	edit_decorator_button.text = "Edit"
	edit_decorator_button.pressed.connect(_edit_picked_decorator)
	decorator_actions.add_child(edit_decorator_button)
	remove_decorator_button = Button.new()
	remove_decorator_button.text = "Remove"
	remove_decorator_button.pressed.connect(_remove_picked_decorator)
	decorator_actions.add_child(remove_decorator_button)
	return_to_owner_button = Button.new()
	return_to_owner_button.text = "Return to Owner"
	return_to_owner_button.pressed.connect(_return_to_decorator_owner)
	decorator_actions.add_child(return_to_owner_button)


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


func _initialize_feature_states() -> void:
	for definition in FEATURE_DEFINITIONS:
		var key := str(definition[0])
		if not feature_states.has(key):
			feature_states[key] = bool(definition[2])


func _build_feature_menu() -> void:
	if not is_instance_valid(feature_menu_button):
		return
	var popup := feature_menu_button.get_popup()
	popup.clear()
	advanced_display_menu = PopupMenu.new()
	advanced_display_menu.name = "AdvancedDisplayMenu"
	var common_features := ["fisheye", "subtree_collapse", "compact", "type_encoding", "enhanced_minimap", "semantic_zoom", "search"]
	for index in range(FEATURE_DEFINITIONS.size()):
		var definition: Array = FEATURE_DEFINITIONS[index]
		if common_features.has(str(definition[0])):
			popup.add_check_item(str(definition[1]), index)
		else:
			advanced_display_menu.add_check_item(str(definition[1]), index)
	popup.add_submenu_node_item("Advanced Display", advanced_display_menu)
	popup.add_separator()
	popup.add_check_item("Grid", DISPLAY_MENU_GRID_ID)
	popup.id_pressed.connect(_on_feature_menu_pressed)
	advanced_display_menu.id_pressed.connect(_on_feature_menu_pressed)


func _build_layout_menu() -> void:
	var popup := layout_menu_button.get_popup()
	popup.add_item("Auto Arrange", LAYOUT_MENU_AUTO_ARRANGE_ID)
	popup.add_item("Arrange for Overview", LAYOUT_MENU_OVERVIEW_ID)
	popup.add_separator()
	popup.add_item("Collapse All", LAYOUT_MENU_COLLAPSE_ID)
	popup.add_item("Expand All", LAYOUT_MENU_EXPAND_ID)
	popup.add_item("Focus Selected Subtree", LAYOUT_MENU_FOCUS_ID)
	popup.add_item("Show Complete Tree", LAYOUT_MENU_SHOW_ALL_ID)
	popup.add_separator()
	popup.add_item("Fit to View", LAYOUT_MENU_FIT_ID)
	popup.id_pressed.connect(_on_layout_menu_pressed)


func _on_layout_menu_pressed(index: int) -> void:
	match index:
		LAYOUT_MENU_AUTO_ARRANGE_ID:
			_auto_arrange_tree()
		LAYOUT_MENU_OVERVIEW_ID:
			_auto_arrange_tree(true)
		LAYOUT_MENU_COLLAPSE_ID:
			_set_all_subtrees_collapsed(true)
		LAYOUT_MENU_EXPAND_ID:
			_set_all_subtrees_collapsed(false)
		LAYOUT_MENU_FOCUS_ID:
			_focus_selected_subtree()
		LAYOUT_MENU_SHOW_ALL_ID:
			_clear_subtree_focus()
		LAYOUT_MENU_FIT_ID:
			_fit_visible_tree()


func _build_debug_menu() -> void:
	if not is_instance_valid(debug_menu_button):
		return
	var popup := debug_menu_button.get_popup()
	popup.clear()
	popup.add_check_item("Live Debug", DEBUG_MENU_LIVE_ID)
	popup.add_check_item("Dim Inactive Branches", DEBUG_MENU_DIM_ID)
	popup.add_check_item("Failure Reasons", DEBUG_MENU_FAILURE_ID)
	popup.add_separator()
	popup.add_check_item("Live Blackboard", DEBUG_MENU_BLACKBOARD_ID)
	popup.add_check_item("Edit Blackboard Schema", DEBUG_MENU_SCHEMA_ID)
	popup.id_pressed.connect(_on_debug_menu_pressed)
	_update_debug_menu_checks()


func _on_debug_menu_pressed(index: int) -> void:
	match index:
		DEBUG_MENU_LIVE_ID:
			_on_live_debug_toggled(not runtime_debug_enabled)
		DEBUG_MENU_DIM_ID:
			_set_feature_enabled("branch_dimming", not _feature_enabled("branch_dimming"))
		DEBUG_MENU_FAILURE_ID:
			_set_feature_enabled("failure_reason", not _feature_enabled("failure_reason"))
		DEBUG_MENU_BLACKBOARD_ID:
			_on_blackboard_panel_toggled(not blackboard_panel.visible)
		DEBUG_MENU_SCHEMA_ID:
			_on_schema_panel_toggled(not schema_panel.visible)
	_update_debug_menu_checks()


func _update_debug_menu_checks() -> void:
	if not is_instance_valid(debug_menu_button):
		return
	var popup := debug_menu_button.get_popup()
	popup.set_item_checked(popup.get_item_index(DEBUG_MENU_LIVE_ID), runtime_debug_enabled)
	popup.set_item_checked(popup.get_item_index(DEBUG_MENU_DIM_ID), _feature_enabled("branch_dimming"))
	popup.set_item_checked(popup.get_item_index(DEBUG_MENU_FAILURE_ID), _feature_enabled("failure_reason"))
	popup.set_item_checked(popup.get_item_index(DEBUG_MENU_BLACKBOARD_ID), is_instance_valid(blackboard_panel) and blackboard_panel.visible)
	popup.set_item_checked(popup.get_item_index(DEBUG_MENU_SCHEMA_ID), is_instance_valid(schema_panel) and schema_panel.visible)


func _on_feature_menu_pressed(index: int) -> void:
	if index == DISPLAY_MENU_GRID_ID:
		_on_grid_toggled(not graph_edit.show_grid)
		_update_feature_menu_checks()
		return
	if index < 0 or index >= FEATURE_DEFINITIONS.size():
		return
	var key := str(FEATURE_DEFINITIONS[index][0])
	_set_feature_enabled(key, not _feature_enabled(key))


func _feature_enabled(key: String) -> bool:
	return bool(feature_states.get(key, false))


func _set_feature_enabled(key: String, enabled: bool, persist := true) -> void:
	if not feature_states.has(key):
		return
	var was_enabled := _feature_enabled(key)
	feature_states[key] = enabled
	match key:
		"fisheye":
			fisheye_enabled = enabled
			if not enabled:
				_reset_fisheye()
			if is_instance_valid(fisheye_toggle):
				fisheye_toggle.set_pressed_no_signal(enabled)
		"branch_dimming":
			if is_instance_valid(branch_dimming_toggle):
				branch_dimming_toggle.set_pressed_no_signal(enabled)
		"compact":
			compact_mode_enabled = enabled
			auto_spacing_signature = ""
			_refresh_auto_spacing_deferred.call_deferred()
		"semantic_zoom":
			semantic_zoom_enabled = enabled
			if not enabled:
				semantic_detail_level = 2
			auto_spacing_signature = ""
			_refresh_auto_spacing_deferred.call_deferred()
		"auto_spacing":
			if not enabled:
				_reset_auto_spacing()
			else:
				auto_spacing_signature = ""
				_refresh_auto_spacing_deferred.call_deferred()
		"zoom_anchor":
			if not enabled:
				_clear_zoom_layout_anchor()
		"enhanced_minimap":
			if is_instance_valid(graph_edit):
				graph_edit.set_enhanced_minimap(enabled)
			if is_instance_valid(minimap_toggle):
				minimap_toggle.set_pressed_no_signal(enabled)
			minimap_status_signature = ""
		"search":
			if is_instance_valid(search_toggle):
				search_toggle.set_pressed_no_signal(enabled)
			if not enabled:
				search_query = ""
				search_result_ids.clear()
				search_result_index = -1
				if is_instance_valid(search_edit):
					search_edit.set_text("")
			_update_search_controls()
		"path_summary":
			if is_instance_valid(path_summary_toggle):
				path_summary_toggle.set_pressed_no_signal(enabled)
			_set_path_summary_visible(enabled)
			if not enabled:
				_clear_container(runtime_path_container)
		"breadcrumb":
			if is_instance_valid(selection_path_row):
				selection_path_row.visible = enabled
			if not enabled:
				_clear_container(selection_path_container)
		"failure_reason":
			if is_instance_valid(failure_reason_toggle):
				failure_reason_toggle.set_pressed_no_signal(enabled)
			if not enabled:
				visible_failure_annotations.clear()
			_refresh_failure_summary()
	_apply_feature_states()
	if key == "fisheye" and was_enabled and not enabled and current_tree != null and is_instance_valid(graph_edit):
		_rebuild_graph_after_fisheye()
	if key == "subtree_collapse" and current_tree != null and is_instance_valid(graph_edit):
		_rebuild_graph()
	if persist:
		_save_view_settings()


func _apply_feature_states() -> void:
	_update_feature_menu_checks()
	if is_instance_valid(search_edit):
		search_edit.editable = _feature_enabled("search")
	if is_instance_valid(search_previous_button):
		search_previous_button.disabled = not _feature_enabled("search") or search_result_ids.is_empty()
	if is_instance_valid(search_next_button):
		search_next_button.disabled = not _feature_enabled("search") or search_result_ids.is_empty()
	if is_instance_valid(graph_edit):
		graph_edit.set_edge_display(_feature_enabled("orthogonal_edges"), _feature_enabled("edge_bundling"))
		graph_edit.set_single_connection_rendering(_feature_enabled("single_connection"))
		graph_edit.set_enhanced_minimap(_feature_enabled("enhanced_minimap"))
	_update_minimap_status(true)
	for child in graph_edit.get_children() if is_instance_valid(graph_edit) else []:
		if not (child is BTGraphNode):
			continue
		var graph_node: BTGraphNode = child
		graph_node.set_compact_mode(_feature_enabled("compact"))
		graph_node.set_type_encoding_enabled(_feature_enabled("type_encoding"))
		graph_node.set_accessible_palette_enabled(_feature_enabled("accessibility"))
		graph_node.set_single_connection_rendering_enabled(_feature_enabled("single_connection"))
		graph_node.set_semantic_detail_level(semantic_detail_level if _feature_enabled("semantic_zoom") else 2)
		graph_node.set_subtree_collapse_enabled(_feature_enabled("subtree_collapse"))
		graph_node.set_decorator_badges_enabled(_feature_enabled("decorator_badges"))
		var node_id := graph_node.node_resource.id
		graph_node.set_search_state(_feature_enabled("search") and not search_query.is_empty(), search_result_ids.has(node_id), _current_search_result_id() == node_id)
	if last_runtime_snapshot.is_empty():
		_clear_runtime_highlights()
	else:
		_apply_runtime_snapshot(last_runtime_snapshot)
	_refresh_navigation_paths()


func _refresh_navigation_paths() -> void:
	if _feature_enabled("path_summary"):
		var runtime_ids: Array = last_runtime_snapshot.get("path_ids", [])
		var runtime_titles: Array = last_runtime_snapshot.get("path_titles", [])
		_populate_path_buttons(runtime_path_container, runtime_ids, runtime_titles, "No active path", true)
		_update_path_summary_metadata(runtime_ids)
	if _feature_enabled("breadcrumb"):
		var selection_ids: Array[int] = []
		var selection_titles: Array[String] = []
		var cursor := _get_selected_node()
		while cursor != null:
			selection_ids.push_front(cursor.id)
			selection_titles.push_front(cursor.title)
			cursor = current_tree.find_node(cursor.parent_id) if current_tree != null else null
		_populate_path_buttons(selection_path_container, selection_ids, selection_titles, "No selection")


func _populate_path_buttons(container: HBoxContainer, ids: Array, titles: Array, empty_text: String, mark_current := false) -> void:
	if not is_instance_valid(container):
		return
	_clear_container(container)
	if ids.is_empty():
		var empty_label := Label.new()
		empty_label.text = empty_text
		empty_label.modulate = Color(0.65, 0.68, 0.74, 1.0)
		container.add_child(empty_label)
		return
	for index in range(ids.size()):
		if index > 0:
			var separator := Label.new()
			separator.text = ">"
			container.add_child(separator)
		var button := Button.new()
		button.flat = true
		var title := str(titles[index]) if index < titles.size() else "#%d" % int(ids[index])
		var is_current := mark_current and index == ids.size() - 1
		button.text = "[CURRENT] %s" % title if is_current else title
		button.tooltip_text = "Select and center node #%d." % int(ids[index])
		button.set_meta("node_id", int(ids[index]))
		button.set_meta("is_current", is_current)
		if is_current:
			button.modulate = Color("facc15")
		button.pressed.connect(_focus_graph_node.bind(int(ids[index])))
		container.add_child(button)


func _set_path_summary_visible(enabled: bool) -> void:
	for control in [runtime_path_label, runtime_path_actor_label, runtime_path_status_label, runtime_path_depth_label, runtime_path_scroll]:
		if is_instance_valid(control):
			control.visible = enabled


func _update_path_summary_metadata(path_ids: Array) -> void:
	var actor := str(last_runtime_snapshot.get("actor", "--"))
	var status := str(last_runtime_snapshot.get("leaf_status_text", "IDLE"))
	if path_ids.is_empty():
		actor = "--"
		status = "IDLE"
	runtime_path_actor_label.text = "Actor: %s" % actor
	runtime_path_status_label.text = "Status: %s" % status
	runtime_path_depth_label.text = "Depth: %d" % path_ids.size()
	match status:
		"RUNNING":
			runtime_path_status_label.modulate = Color("60a5fa")
		"SUCCESS":
			runtime_path_status_label.modulate = Color("4ade80")
		"FAILURE":
			runtime_path_status_label.modulate = Color("f87171")
		_:
			runtime_path_status_label.modulate = Color.WHITE


func _clear_container(container: Container) -> void:
	if not is_instance_valid(container):
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _focus_graph_node(node_id: int) -> void:
	var resource := current_tree.find_node(node_id) if current_tree != null else null
	if resource != null and resource.decorator_parent_id != -1:
		node_id = resource.decorator_parent_id
	var graph_node := graph_edit.get_node_or_null(NodePath(str(node_id))) as BTGraphNode
	if graph_node == null:
		resource = current_tree.find_node(node_id) if current_tree != null else null
		if resource != null:
			focus_root_id = -1
			var cursor := current_tree.find_node(resource.parent_id)
			while cursor != null:
				cursor.collapsed = false
				cursor = current_tree.find_node(cursor.parent_id)
			_rebuild_graph()
			graph_node = graph_edit.get_node_or_null(NodePath(str(node_id))) as BTGraphNode
	if graph_node == null:
		return
	selected_node_id = node_id
	graph_node.selected = true
	var node_center := graph_node.position_offset + graph_node.size * 0.5
	graph_edit.scroll_offset = node_center * maxf(graph_edit.zoom, 0.01) - graph_edit.size * 0.5
	_refresh_inspector()
	_refresh_navigation_paths()


func _update_feature_menu_checks() -> void:
	if not is_instance_valid(feature_menu_button):
		return
	var popup := feature_menu_button.get_popup()
	for index in range(FEATURE_DEFINITIONS.size()):
		var item_index := popup.get_item_index(index)
		if item_index >= 0:
			popup.set_item_checked(item_index, _feature_enabled(str(FEATURE_DEFINITIONS[index][0])))
		elif is_instance_valid(advanced_display_menu):
			item_index = advanced_display_menu.get_item_index(index)
			if item_index >= 0:
				advanced_display_menu.set_item_checked(item_index, _feature_enabled(str(FEATURE_DEFINITIONS[index][0])))
	var grid_index := popup.get_item_index(DISPLAY_MENU_GRID_ID)
	if grid_index >= 0:
		popup.set_item_checked(grid_index, graph_edit.show_grid if is_instance_valid(graph_edit) else true)
	_update_debug_menu_checks()


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
	var name_counts := {}
	for path in paths:
		var resource_name := path.get_file().get_basename()
		name_counts[resource_name] = int(name_counts.get(resource_name, 0)) + 1
	for path in paths:
		var resource_name := path.get_file().get_basename()
		var label := resource_name
		if int(name_counts.get(resource_name, 0)) > 1:
			label = "%s — %s" % [resource_name, path.get_base_dir().get_file()]
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


func _show_new_tree_dialog() -> void:
	new_tree_name_edit.text = ""
	new_tree_dialog.popup_centered()
	new_tree_name_edit.grab_focus()


func _create_named_tree() -> void:
	var requested_name := new_tree_name_edit.text.strip_edges()
	if requested_name.is_empty():
		requested_name = "New Behavior Tree"
	_new_tree()
	current_tree.tree_name = requested_name
	tree_name_edit.text = requested_name
	var safe_name := requested_name.to_snake_case()
	if safe_name.is_empty():
		safe_name = "behavior_tree"
	var candidate := "res://behavior_trees/%s.tres" % safe_name
	var suffix := 2
	while ResourceLoader.exists(candidate):
		candidate = "res://behavior_trees/%s_%d.tres" % [safe_name, suffix]
		suffix += 1
	current_tree_path = candidate
	file_path_edit.text = candidate
	_set_status("Created %s. Add a Root node to begin." % requested_name)


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
	_set_status("Loaded %s." % current_tree.tree_name)


func _save_tree() -> void:
	if current_tree == null:
		_set_status("Nothing to save.")
		return
	_sync_inspector_into_selected_node()
	current_tree.tree_name = tree_name_edit.text.strip_edges()
	var validation_errors := current_tree.validate_tree()
	if not validation_errors.is_empty():
		_set_status("Save blocked: %s" % validation_errors[0])
		return
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
	_set_status("Saved %s." % current_tree.tree_name)


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
	var type_name := node_type_picker.get_item_text(node_type_picker.selected)
	if type_name == BTNodeResource.TYPE_ROOT:
		type_name = BTNodeResource.TYPE_ACTION
	var parent_node := current_tree.find_node(selected_node_id)
	if parent_node == null or not current_tree.can_accept_child(parent_node):
		_set_status("%s nodes cannot accept another child." % [parent_node.node_type if parent_node != null else "Selected"])
		return
	_push_history()
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
	_push_history()
	var descendant_ids := _collect_subtree_and_attached_decorator_ids(selected_node_id)
	var remaining: Array[BTNodeResource] = []
	for node in current_tree.nodes:
		if node == null or descendant_ids.has(node.id):
			continue
		remaining.append(node)
	current_tree.nodes = remaining
	if selected_node_id == current_tree.root_node_id:
		current_tree.root_node_id = -1
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
	_refresh_schema_editor()
	_update_history_buttons()


func _rebuild_graph() -> void:
	minimap_status_signature = ""
	last_runtime_visual_signature = ""
	auto_spacing_signature = ""
	auto_spacing_targets.clear()
	pending_auto_spacing_anchor_id = -1
	drag_auto_spacing_base_targets.clear()
	drag_auto_spacing_original_targets.clear()
	pending_auto_spacing_seed_targets.clear()
	_refresh_search_results(true)
	graph_edit.cancel_manual_connection()
	graph_edit.clear_connections()
	for child in graph_edit.get_children():
		if child is BTGraphNode:
			graph_edit.remove_child(child)
			child.queue_free()

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
		graph_node.set_compact_mode(compact_mode_enabled)
		graph_node.set_type_encoding_enabled(_feature_enabled("type_encoding"))
		graph_node.set_accessible_palette_enabled(_feature_enabled("accessibility"))
		graph_node.set_single_connection_rendering_enabled(_feature_enabled("single_connection"))
		graph_node.set_semantic_detail_level(semantic_detail_level)
		graph_node.set_subtree_collapse_enabled(_feature_enabled("subtree_collapse"))
		graph_node.set_decorator_badges_enabled(_feature_enabled("decorator_badges"))
		graph_node.set_search_state(not search_query.is_empty(), search_result_ids.has(node_resource.id), _current_search_result_id() == node_resource.id)
		graph_node.collapse_toggled.connect(_on_graph_node_collapse_toggled)
		graph_node.drag_started.connect(_on_graph_node_drag_started)
		graph_node.drag_finished.connect(_on_graph_node_drag_finished)
		graph_node.gui_input.connect(_on_graph_node_gui_input.bind(graph_node))
		graph_node.position_offset_changed.connect(_on_graph_node_position_changed.bind(graph_node))

	for node_resource in current_tree.nodes:
		if node_resource == null or _is_attached_decorator(node_resource) or node_resource.parent_id == -1 or _is_node_hidden_by_collapsed_ancestor(node_resource):
			continue
		var parent_name := str(node_resource.parent_id)
		var child_name := str(node_resource.id)
		if graph_edit.get_node_or_null(NodePath(parent_name)) != null and graph_edit.get_node_or_null(NodePath(child_name)) != null:
			graph_edit.connect_node(parent_name, 0, child_name, 0)
	_apply_feature_states()
	_refresh_auto_spacing_deferred.call_deferred()
	_refresh_minimap_node_counts()
	_update_minimap_status(true)


func _refresh_inspector() -> void:
	var node := _get_selected_node()
	suppress_inspector_changes = true
	if node == null:
		selected_label.text = "No node selected"
		node_type_edit.disabled = false
		node_title_edit.text = ""
		node_type_edit.select(0)
		node_description_edit.text = ""
		node_parameters_edit.text = "{}"
		_refresh_typed_parameters(null)
		_refresh_decorator_picker(null)
		suppress_inspector_changes = false
		return
	selected_label.text = "Editing Node #%d" % node.id
	node_type_edit.disabled = node.id == current_tree.root_node_id or node.decorator_parent_id != -1
	node_title_edit.text = node.title
	node_type_edit.select(max(0, NODE_TYPES.find(node.node_type)))
	node_description_edit.text = node.description
	node_parameters_edit.text = JSON.stringify(node.parameters, "\t")
	_refresh_typed_parameters(node)
	_refresh_decorator_picker(node)
	suppress_inspector_changes = false


func _refresh_decorator_picker(node: BTNodeResource) -> void:
	if not is_instance_valid(decorator_picker):
		return
	decorator_picker.clear()
	var owner := node
	if node != null and node.decorator_parent_id != -1:
		owner = current_tree.find_node(node.decorator_parent_id)
	if owner != null:
		for decorator in current_tree.get_decorators_of(owner.id):
			var index := decorator_picker.item_count
			decorator_picker.add_item("%s [%s]" % [decorator.title, str(decorator.parameters.get("mode", "blackboard"))])
			decorator_picker.set_item_metadata(index, decorator.id)
	var has_decorators := decorator_picker.item_count > 0
	decorator_picker.disabled = not has_decorators
	edit_decorator_button.disabled = not has_decorators
	remove_decorator_button.disabled = not has_decorators
	return_to_owner_button.visible = node != null and node.decorator_parent_id != -1


func _edit_picked_decorator() -> void:
	if decorator_picker.item_count == 0:
		return
	selected_node_id = int(decorator_picker.get_item_metadata(decorator_picker.selected))
	_refresh_inspector()
	_set_status("Editing attached decorator #%d." % selected_node_id)


func _remove_picked_decorator() -> void:
	if decorator_picker.item_count == 0:
		return
	var decorator_id := int(decorator_picker.get_item_metadata(decorator_picker.selected))
	var decorator := current_tree.find_node(decorator_id)
	if decorator == null:
		return
	var owner_id := decorator.decorator_parent_id
	_push_history()
	current_tree.nodes.erase(decorator)
	selected_node_id = owner_id
	_refresh_entire_ui()
	_set_status("Removed attached decorator #%d." % decorator_id)


func _return_to_decorator_owner() -> void:
	var decorator := _get_selected_node()
	if decorator == null or decorator.decorator_parent_id == -1:
		return
	selected_node_id = decorator.decorator_parent_id
	_refresh_inspector()
	_set_status("Returned to decorator owner node #%d." % selected_node_id)


func _on_graph_node_gui_input(event: InputEvent, graph_node: BTGraphNode) -> void:
	if not (event is InputEventMouseButton):
		return
	if not event.pressed:
		return
	selected_node_id = int(String(graph_node.name))
	_refresh_inspector()
	_refresh_navigation_paths()
	if event.button_index == MOUSE_BUTTON_RIGHT:
		pending_context_position = graph_node.position_offset
		_popup_context_menu()
	else:
		_set_status("Selected node #%d." % selected_node_id)


func _on_graph_node_position_changed(graph_node: BTGraphNode) -> void:
	# Resource mutation emits change notifications into the editor. On a large tree,
	# doing that for every pointer sample is much more expensive than the visual move.
	# Keep the card responsive and persist the final logical position on release.
	if graph_node.manual_dragging:
		pending_auto_spacing_anchor_id = graph_node.node_resource.id
		# Resource coordinates intentionally stay unchanged during a drag, so the
		# normal cache key cannot observe pointer movement without this invalidation.
		auto_spacing_signature = ""
		_queue_live_auto_spacing_refresh()
	else:
		graph_node.sync_to_resource()
	graph_edit.queue_redraw()


func _queue_live_auto_spacing_refresh() -> void:
	# Mouse devices can emit several motion events in one frame. Coalesce them into
	# one solve while still completing avoidance before the next rendered frame.
	if live_auto_spacing_refresh_pending:
		return
	live_auto_spacing_refresh_pending = true
	_refresh_live_auto_spacing_deferred.call_deferred()


func _refresh_live_auto_spacing_deferred() -> void:
	live_auto_spacing_refresh_pending = false
	if _active_dragged_graph_node() != null:
		_update_auto_spacing(0.0, true)


func _on_graph_node_drag_started(node_id: int) -> void:
	var node := current_tree.find_node(node_id)
	if node == null:
		return
	# A wheel burst may still be restoring the previous viewport anchor. Once a
	# card is grabbed, pointer tracking owns the view and scrolling must stay put.
	_clear_zoom_layout_anchor()
	_reset_fisheye()
	var graph_node := graph_edit.get_node_or_null(NodePath(str(node_id))) as BTGraphNode
	drag_auto_spacing_original_targets = _capture_current_auto_spacing_offsets()
	drag_auto_spacing_base_targets = _build_drag_auto_spacing_baseline(node_id)
	if graph_node != null:
		# Keep the card exactly where it was rendered when grabbed. The current
		# temporary offset becomes the live drag origin, not a resource write.
		graph_node.capture_rendered_position_for_manual_drag()
		drag_auto_spacing_base_targets[node_id] = Vector2.ZERO
		auto_spacing_targets = drag_auto_spacing_base_targets.duplicate(true)
	pending_auto_spacing_seed_targets.clear()
	pending_auto_spacing_anchor_id = node_id
	auto_spacing_signature = ""
	drag_history_snapshot = null
	drag_history_node_id = node_id
	drag_history_position = node.position


func _on_graph_node_drag_finished(node_id: int) -> void:
	var node := current_tree.find_node(node_id)
	if node == null or node_id != drag_history_node_id:
		return
	var graph_node := graph_edit.get_node_or_null(NodePath(str(node_id))) as BTGraphNode
	if graph_node != null and not graph_node.manual_drag_moved:
		_restore_auto_spacing_after_click()
		drag_history_snapshot = null
		drag_history_node_id = -1
		return
	if graph_node != null:
		# A dragged card is placed where the user released it, even when the card
		# previously had a temporary collision-avoidance offset. The local solver
		# treats this card as the fixed point and moves only colliding neighbours.
		graph_node.sync_rendered_position_to_resource()
		pending_auto_spacing_anchor_id = node_id
	if not node.position.is_equal_approx(drag_history_position):
		# Build the undo snapshot after movement, away from the latency-sensitive
		# pointer-down path, then restore only this node's previous position in it.
		drag_history_snapshot = current_tree.duplicate_tree()
		var snapshot_node := drag_history_snapshot.find_node(node_id)
		if snapshot_node != null:
			snapshot_node.position = drag_history_position
		undo_stack.append(drag_history_snapshot)
		redo_stack.clear()
		if undo_stack.size() > 50:
			undo_stack.pop_front()
		_update_history_buttons()
	drag_history_snapshot = null
	drag_history_node_id = -1
	# The live solution already represents the released geometry. Reuse it for
	# the release-time verification instead of restarting a large-tree solve.
	pending_auto_spacing_seed_targets = auto_spacing_targets.duplicate(true)
	drag_auto_spacing_base_targets.clear()
	drag_auto_spacing_original_targets.clear()
	# BTGraphNode emits drag_finished immediately before it clears manual_dragging.
	# Defer one frame so local collision avoidance sees the released position.
	auto_spacing_signature = ""
	_refresh_auto_spacing_deferred.call_deferred()


func _on_graph_node_collapse_toggled(node_id: int) -> void:
	if not _feature_enabled("subtree_collapse"):
		_set_status("Enable Subtree Collapse / Expand in Display Features first.")
		return
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
	if child.decorator_parent_id != -1:
		_set_status("Attached decorators cannot be connected as tree nodes.")
		return
	if not current_tree.can_accept_child(parent) and child.parent_id != parent.id:
		_set_status("%s nodes cannot accept another child." % parent.node_type)
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


func _on_custom_edge_disconnect_requested(from_node: StringName, to_node: StringName) -> void:
	_on_disconnection_request(from_node, 0, to_node, 0)


func _on_manual_connection_requested(from_node: StringName, to_node: StringName) -> void:
	_on_connection_request(from_node, 0, to_node, 0)


func _on_tree_name_submitted(_text: String) -> void:
	if current_tree != null:
		current_tree.tree_name = tree_name_edit.text.strip_edges()


func _on_tree_name_focus_exited() -> void:
	if current_tree != null:
		current_tree.tree_name = tree_name_edit.text.strip_edges()


func _on_live_debug_toggled(enabled: bool) -> void:
	runtime_debug_enabled = enabled
	if is_instance_valid(live_debug_toggle):
		live_debug_toggle.set_pressed_no_signal(enabled)
	if not enabled:
		_clear_runtime_highlights()
		if is_instance_valid(runtime_debug_label):
			runtime_debug_label.text = "Live Debug disabled."
	_update_debug_menu_checks()


func _on_blackboard_panel_toggled(enabled: bool) -> void:
	blackboard_panel.visible = enabled
	if is_instance_valid(blackboard_toggle):
		blackboard_toggle.set_pressed_no_signal(enabled)
	if enabled:
		_refresh_blackboard_panel(last_runtime_snapshot)
	_update_debug_menu_checks()


func _on_schema_panel_toggled(enabled: bool) -> void:
	schema_panel.visible = enabled
	if is_instance_valid(schema_toggle):
		schema_toggle.set_pressed_no_signal(enabled)
	if enabled:
		_refresh_schema_editor()
	_update_debug_menu_checks()


func _ensure_blackboard_schema() -> BTBlackboardSchema:
	if current_tree.blackboard_schema == null:
		current_tree.blackboard_schema = BTBlackboardSchema.new()
	return current_tree.blackboard_schema


func _add_schema_entry() -> void:
	if current_tree == null:
		return
	_push_history()
	var schema := _ensure_blackboard_schema()
	var entry := BTBlackboardEntry.new()
	entry.key = _next_schema_key(schema)
	schema.entries.append(entry)
	_refresh_schema_editor()
	_set_status("Added blackboard schema key '%s'." % entry.key)


func _remove_schema_entry(index: int) -> void:
	if current_tree == null or current_tree.blackboard_schema == null or index < 0 or index >= current_tree.blackboard_schema.entries.size():
		return
	_push_history()
	current_tree.blackboard_schema.entries.remove_at(index)
	_refresh_schema_editor()
	_set_status("Removed blackboard schema key.")


func _on_schema_dynamic_keys_toggled(enabled: bool) -> void:
	if suppress_schema_changes or current_tree == null:
		return
	var current_value := current_tree.blackboard_schema.allow_dynamic_keys if current_tree.blackboard_schema != null else true
	if current_value == enabled:
		return
	_push_history()
	_ensure_blackboard_schema().allow_dynamic_keys = enabled
	_refresh_schema_editor()
	_set_status("Blackboard dynamic keys %s." % ["allowed" if enabled else "restricted"])


func _next_schema_key(schema: BTBlackboardSchema) -> String:
	var suffix := schema.entries.size() + 1
	var candidate := "new_key_%d" % suffix
	while schema.find_entry(candidate) != null:
		suffix += 1
		candidate = "new_key_%d" % suffix
	return candidate


func _set_schema_key(index: int, value: String) -> void:
	var entry := _schema_entry(index)
	if suppress_schema_changes or entry == null or entry.key == value:
		return
	_push_history()
	entry.key = value
	_refresh_schema_editor()


func _set_schema_type(index: int, type_index: int) -> void:
	var entry := _schema_entry(index)
	if suppress_schema_changes or entry == null or type_index < 0 or type_index >= BTBlackboardEntry.SUPPORTED_TYPES.size():
		return
	var value_type: String = BTBlackboardEntry.SUPPORTED_TYPES[type_index]
	if entry.value_type == value_type:
		return
	_push_history()
	entry.value_type = value_type
	entry.default_value = _normalized_schema_default(entry.default_value, value_type)
	_refresh_schema_editor()


func _set_schema_default(index: int, value: Variant) -> void:
	var entry := _schema_entry(index)
	if suppress_schema_changes or entry == null:
		return
	var normalized := _normalized_schema_default(value, entry.value_type)
	if entry.default_value == normalized:
		return
	_push_history()
	entry.default_value = normalized
	_refresh_schema_editor()


func _set_schema_vector_component(index: int, component: String, value: float) -> void:
	var entry := _schema_entry(index)
	if suppress_schema_changes or entry == null:
		return
	var current := entry.default_value if entry.default_value is Vector2 else Vector2.ZERO
	var changed := Vector2(value, current.y) if component == "x" else Vector2(current.x, value)
	_set_schema_default(index, changed)


func _set_schema_description(index: int, value: String) -> void:
	var entry := _schema_entry(index)
	if suppress_schema_changes or entry == null or entry.description == value:
		return
	_push_history()
	entry.description = value
	_refresh_schema_editor()


func _schema_entry(index: int) -> BTBlackboardEntry:
	if current_tree == null or current_tree.blackboard_schema == null or index < 0 or index >= current_tree.blackboard_schema.entries.size():
		return null
	return current_tree.blackboard_schema.entries[index]


func _normalized_schema_default(value: Variant, value_type: String) -> Variant:
	match value_type:
		BTBlackboardEntry.VALUE_TYPE_BOOL:
			return value if typeof(value) == TYPE_BOOL else false
		BTBlackboardEntry.VALUE_TYPE_INT:
			return int(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else 0
		BTBlackboardEntry.VALUE_TYPE_FLOAT:
			return float(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else 0.0
		BTBlackboardEntry.VALUE_TYPE_STRING:
			return str(value) if typeof(value) in [TYPE_STRING, TYPE_STRING_NAME] else ""
		BTBlackboardEntry.VALUE_TYPE_VECTOR2:
			return value if value is Vector2 else Vector2.ZERO
		_:
			return value


func _refresh_schema_editor() -> void:
	if not is_instance_valid(schema_grid) or current_tree == null:
		return
	suppress_schema_changes = true
	for child in schema_grid.get_children():
		schema_grid.remove_child(child)
		child.queue_free()
	schema_row_controls.clear()
	var schema: BTBlackboardSchema = current_tree.blackboard_schema
	schema_dynamic_keys_toggle.button_pressed = schema.allow_dynamic_keys if schema != null else true
	var errors := schema.validate_schema() if schema != null else PackedStringArray()
	errors.append_array(current_tree.validate_blackboard_references())
	var entry_count := schema.entries.size() if schema != null else 0
	var references := current_tree.get_blackboard_references()
	var unused_keys := current_tree.get_unused_blackboard_keys()
	if errors.is_empty():
		schema_summary_label.text = "Schema: %d keys - valid; %d referenced, %d unused." % [entry_count, references.size(), unused_keys.size()]
		schema_summary_label.modulate = Color("86efac")
		var details := PackedStringArray(["No schema validation errors."])
		if not unused_keys.is_empty():
			details.append("Unused keys: %s" % ", ".join(unused_keys))
		for key in references:
			var locations: Array[String] = []
			for reference in references[key]:
				locations.append("#%d %s" % [int(reference.get("id", -1)), str(reference.get("title", "Node"))])
			details.append("%s: %s" % [key, ", ".join(locations)])
		schema_summary_label.tooltip_text = "\n".join(details)
	else:
		schema_summary_label.text = "Schema: %d keys - %d validation error%s." % [entry_count, errors.size(), "" if errors.size() == 1 else "s"]
		schema_summary_label.modulate = Color("f87171")
		schema_summary_label.tooltip_text = "\n".join(errors)
	for header_text in ["Key", "Type", "Default", "Description", "Status", ""]:
		var header := Label.new()
		header.text = header_text
		header.modulate = Color("93c5fd")
		schema_grid.add_child(header)
	if schema == null or schema.entries.is_empty():
		var empty := Label.new()
		empty.text = "No declared keys. Runtime keys remain dynamic until a schema entry is added."
		empty.modulate = Color("94a3b8")
		schema_grid.add_child(empty)
		for unused in range(5):
			schema_grid.add_child(Control.new())
	else:
		for index in range(schema.entries.size()):
			_build_schema_row(index, schema.entries[index], errors)
	suppress_schema_changes = false


func _build_schema_row(index: int, entry: BTBlackboardEntry, errors: PackedStringArray) -> void:
	if entry == null:
		var null_label := Label.new()
		null_label.text = "<null entry>"
		null_label.modulate = Color("f87171")
		schema_grid.add_child(null_label)
		for unused in range(4):
			schema_grid.add_child(Control.new())
		var null_remove := Button.new()
		null_remove.text = "Remove"
		null_remove.pressed.connect(_remove_schema_entry.bind(index))
		schema_grid.add_child(null_remove)
		return
	var controls: Dictionary = {}
	var key_edit := LineEdit.new()
	key_edit.custom_minimum_size.x = 150.0
	key_edit.text = entry.key
	key_edit.placeholder_text = "key_name"
	key_edit.text_submitted.connect(func(value: String) -> void: _set_schema_key(index, value))
	key_edit.focus_exited.connect(func() -> void: _set_schema_key(index, key_edit.text))
	schema_grid.add_child(key_edit)
	controls["key"] = key_edit

	var type_edit := OptionButton.new()
	type_edit.custom_minimum_size.x = 105.0
	for value_type in BTBlackboardEntry.SUPPORTED_TYPES:
		type_edit.add_item(value_type)
	type_edit.select(maxi(0, BTBlackboardEntry.SUPPORTED_TYPES.find(entry.value_type)))
	type_edit.item_selected.connect(func(type_index: int) -> void: _set_schema_type(index, type_index))
	schema_grid.add_child(type_edit)
	controls["type"] = type_edit

	var default_control := _make_schema_default_control(index, entry)
	schema_grid.add_child(default_control)
	controls["default"] = default_control

	var description_edit := LineEdit.new()
	description_edit.custom_minimum_size.x = 230.0
	description_edit.text = entry.description
	description_edit.placeholder_text = "Purpose and expected use"
	description_edit.text_submitted.connect(func(value: String) -> void: _set_schema_description(index, value))
	description_edit.focus_exited.connect(func() -> void: _set_schema_description(index, description_edit.text))
	schema_grid.add_child(description_edit)
	controls["description"] = description_edit

	var row_errors := _schema_errors_for_entry(entry, errors)
	var status := Label.new()
	status.text = "Valid" if row_errors.is_empty() else "Error"
	status.modulate = Color("86efac") if row_errors.is_empty() else Color("f87171")
	status.tooltip_text = "Entry is valid." if row_errors.is_empty() else "\n".join(row_errors)
	schema_grid.add_child(status)
	controls["status"] = status

	var remove_button := Button.new()
	remove_button.text = "Remove"
	remove_button.tooltip_text = "Remove this declaration."
	remove_button.pressed.connect(_remove_schema_entry.bind(index))
	schema_grid.add_child(remove_button)
	controls["remove"] = remove_button
	schema_row_controls.append(controls)


func _make_schema_default_control(index: int, entry: BTBlackboardEntry) -> Control:
	match entry.value_type:
		BTBlackboardEntry.VALUE_TYPE_BOOL:
			var check := CheckBox.new()
			check.text = "True" if bool(entry.normalized_default()) else "False"
			check.button_pressed = bool(entry.normalized_default())
			check.toggled.connect(func(enabled: bool) -> void:
				check.text = "True" if enabled else "False"
				_set_schema_default(index, enabled)
			)
			return check
		BTBlackboardEntry.VALUE_TYPE_INT, BTBlackboardEntry.VALUE_TYPE_FLOAT:
			var number := SpinBox.new()
			number.custom_minimum_size.x = 145.0
			number.min_value = -1000000.0
			number.max_value = 1000000.0
			number.step = 1.0 if entry.value_type == BTBlackboardEntry.VALUE_TYPE_INT else 0.01
			number.value = float(entry.normalized_default())
			number.value_changed.connect(func(value: float) -> void:
				_set_schema_default(index, int(value) if entry.value_type == BTBlackboardEntry.VALUE_TYPE_INT else value)
			)
			return number
		BTBlackboardEntry.VALUE_TYPE_VECTOR2:
			var vector_row := HBoxContainer.new()
			var vector: Vector2 = entry.normalized_default()
			for component in ["x", "y"]:
				var number := SpinBox.new()
				number.custom_minimum_size.x = 95.0
				number.min_value = -1000000.0
				number.max_value = 1000000.0
				number.step = 0.01
				number.prefix = "%s " % component.to_upper()
				number.value = vector.x if component == "x" else vector.y
				number.value_changed.connect(func(value: float) -> void: _set_schema_vector_component(index, component, value))
				vector_row.add_child(number)
			return vector_row
		_:
			var text_edit := LineEdit.new()
			text_edit.custom_minimum_size.x = 180.0
			text_edit.text = str(entry.normalized_default())
			text_edit.text_submitted.connect(func(value: String) -> void: _set_schema_default(index, value))
			text_edit.focus_exited.connect(func() -> void: _set_schema_default(index, text_edit.text))
			return text_edit


func _schema_errors_for_entry(entry: BTBlackboardEntry, errors: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	for error in errors:
		if entry.key.strip_edges().is_empty() and "empty key" in error:
			result.append(error)
		elif not entry.key.strip_edges().is_empty() and ("'%s'" % entry.key.strip_edges()) in error:
			result.append(error)
	return result


func _on_branch_dimming_toggled(enabled: bool) -> void:
	_set_feature_enabled("branch_dimming", enabled)


func _on_failure_reason_toggled(enabled: bool) -> void:
	_set_feature_enabled("failure_reason", enabled)


func _on_fisheye_toggled(enabled: bool) -> void:
	_set_feature_enabled("fisheye", enabled)


func _on_compact_toggled(enabled: bool) -> void:
	_set_feature_enabled("compact", enabled)


func _on_semantic_zoom_toggled(enabled: bool) -> void:
	_set_feature_enabled("semantic_zoom", enabled)


func _on_path_summary_toggled(enabled: bool) -> void:
	_set_feature_enabled("path_summary", enabled)


func _on_search_toggled(enabled: bool) -> void:
	_set_feature_enabled("search", enabled)


func _on_grid_toggled(enabled: bool) -> void:
	graph_edit.show_grid = enabled
	if is_instance_valid(grid_toggle):
		grid_toggle.set_pressed_no_signal(enabled)
	_update_feature_menu_checks()
	_save_view_settings()


func _on_minimap_toggled(enabled: bool) -> void:
	_set_feature_enabled("enhanced_minimap", enabled)


func _update_minimap_status(force := false) -> void:
	if not is_instance_valid(minimap_status_label) or not is_instance_valid(graph_edit):
		return
	var enabled := _feature_enabled("enhanced_minimap")
	var detail_percent := roundi(graph_edit.zoom * 100.0)
	var signature := "%s:%d:%d:%d" % [str(enabled), minimap_visible_node_count, minimap_total_node_count, detail_percent]
	if not force and signature == minimap_status_signature:
		return
	minimap_status_signature = signature
	minimap_status_label.text = "Overview %d/%d nodes | Detail %d%%" % [minimap_visible_node_count, minimap_total_node_count, detail_percent]
	minimap_status_label.visible = false
	if is_instance_valid(feature_menu_button):
		feature_menu_button.tooltip_text = "%s\n%s" % [
			"Display optimizations and graph appearance. Each option can be toggled independently.",
			minimap_status_label.text if enabled else "Overview minimap disabled.",
		]


func _refresh_minimap_node_counts() -> void:
	minimap_visible_node_count = 0
	for child in graph_edit.get_children() if is_instance_valid(graph_edit) else []:
		if child is BTGraphNode:
			minimap_visible_node_count += 1
	minimap_total_node_count = 0
	if current_tree != null:
		for node in current_tree.nodes:
			if node != null and not _is_attached_decorator(node):
				minimap_total_node_count += 1


func _update_semantic_zoom() -> void:
	if not semantic_zoom_enabled or not is_instance_valid(graph_edit):
		return
	var next_level := 2
	if graph_edit.zoom < 0.62:
		next_level = 0
	elif graph_edit.zoom < 0.88:
		next_level = 1
	if next_level == semantic_detail_level:
		return
	semantic_detail_level = next_level
	_apply_semantic_detail_level()


func _apply_semantic_detail_level() -> void:
	for child in graph_edit.get_children():
		if child is BTGraphNode:
			child.set_semantic_detail_level(semantic_detail_level)
	_refresh_auto_spacing_deferred.call_deferred()


func _refresh_auto_spacing_deferred() -> void:
	if not is_instance_valid(graph_edit):
		return
	_update_auto_spacing(0.0, true)


func _update_auto_spacing(delta: float, immediate := false) -> void:
	if not is_instance_valid(graph_edit):
		return
	var dragged_node := _active_dragged_graph_node()
	var dragged_node_id := dragged_node.node_resource.id if dragged_node != null and dragged_node.node_resource != null else -1
	# Auto Spacing is an independent display feature. Low-detail Semantic Zoom
	# changes card contents, but it must never disable collision prevention.
	var enabled := _feature_enabled("auto_spacing") or fisheye_focus_node_id != -1
	var signature := _auto_spacing_layout_signature() if enabled else "disabled"
	var overlap_repair_required := false
	if signature != auto_spacing_signature:
		overlap_repair_required = dragged_node_id == -1 and _rendered_auto_spacing_has_overlap()
		auto_spacing_signature = signature
		var anchor_node_id := dragged_node_id if dragged_node_id != -1 else (fisheye_focus_node_id if fisheye_focus_node_id != -1 else pending_auto_spacing_anchor_id)
		var seed_targets: Dictionary = {}
		if dragged_node_id != -1:
			seed_targets = drag_auto_spacing_base_targets
		elif not pending_auto_spacing_seed_targets.is_empty():
			seed_targets = pending_auto_spacing_seed_targets
		auto_spacing_targets = _solve_auto_spacing_offsets(anchor_node_id, seed_targets) if enabled else {}
		pending_auto_spacing_anchor_id = -1
		pending_auto_spacing_seed_targets.clear()
	# Live avoidance must finish in the same rendered frame as the pointer move;
	# interpolating here would knowingly display an overlapping intermediate state.
	var blend := 1.0 if immediate or delta <= 0.0 or dragged_node_id != -1 or overlap_repair_required else clampf(delta * AUTO_SPACING_LERP_SPEED, 0.0, 1.0)
	var changed := false
	for child in graph_edit.get_children():
		if not (child is BTGraphNode):
			continue
		var graph_node: BTGraphNode = child
		if graph_node == dragged_node:
			continue
		var target: Vector2 = auto_spacing_targets.get(graph_node.node_resource.id, Vector2.ZERO)
		var next_offset := graph_node.visual_offset.lerp(target, blend)
		if next_offset.distance_squared_to(target) <= AUTO_SPACING_EPSILON * AUTO_SPACING_EPSILON:
			next_offset = target
		if not graph_node.visual_offset.is_equal_approx(next_offset):
			graph_node.set_visual_offset(next_offset)
			changed = true
	if changed:
		graph_edit.queue_redraw()


func _auto_spacing_layout_signature() -> String:
	var values: Array[String] = [str(semantic_detail_level), "focus:%d" % fisheye_focus_node_id]
	for child in graph_edit.get_children():
		if child is BTGraphNode and child.node_resource != null:
			var layout_position: Vector2 = child.get_logical_position() if child.manual_dragging else child.node_resource.position
			values.append("%d:%d:%.3f:%.3f:%.3f:%.3f" % [
				child.node_resource.id,
				child.node_resource.parent_id,
				layout_position.x,
				layout_position.y,
				child.size.x,
				child.size.y,
			])
	values.sort()
	return "|".join(values)


func _solve_auto_spacing_offsets(anchor_node_id := -1, initial_offsets: Dictionary = {}) -> Dictionary:
	var nodes: Array[BTGraphNode] = []
	var nodes_by_id: Dictionary = {}
	var base_positions: Dictionary = {}
	var source_order: Dictionary = {}
	if current_tree != null:
		for source_index in range(current_tree.nodes.size()):
			var source_node := current_tree.nodes[source_index]
			if source_node != null:
				source_order[source_node.id] = source_index
	for child in graph_edit.get_children():
		if child is BTGraphNode and child.node_resource != null:
			nodes.append(child)
			nodes_by_id[child.node_resource.id] = child
			base_positions[child.node_resource.id] = child.position_offset - child.visual_offset
	var offsets: Dictionary = {}
	for graph_node in nodes:
		var node_id: int = graph_node.node_resource.id
		offsets[node_id] = Vector2(initial_offsets.get(node_id, Vector2.ZERO))
	var anchor_influence: Dictionary = {}
	if nodes_by_id.has(anchor_node_id):
		offsets[anchor_node_id] = Vector2.ZERO
		anchor_influence[anchor_node_id] = 0

	# Old or damaged resources can contain many cards at the exact same point.
	# There is no relative layout to preserve in such a group, so seed only that
	# group into a compact temporary grid before applying normal local avoidance.
	if initial_offsets.is_empty():
		_seed_identical_auto_spacing_groups(nodes, base_positions, offsets, source_order, anchor_node_id)

	for _iteration in range(AUTO_SPACING_ITERATIONS):
		var collision_pairs := _auto_spacing_collision_pairs(nodes, base_positions, offsets, source_order)
		for pair in collision_pairs:
			var left := pair[0] as BTGraphNode
			var right := pair[1] as BTGraphNode
			_apply_auto_spacing_collision_pair(left, right, base_positions, offsets, source_order, anchor_influence)
		var order_changed := _preserve_auto_spacing_order(nodes, nodes_by_id, base_positions, offsets, source_order, anchor_influence)
		if collision_pairs.is_empty() and not order_changed:
			break
	# Continue only on the small set still involved in collisions. This preserves
	# freeform positions while avoiding another 128 full-tree topology scan.
	_resolve_auto_spacing_residual_collisions(nodes, base_positions, offsets, source_order, anchor_influence)
	return offsets


func _apply_auto_spacing_collision_pair(left: BTGraphNode, right: BTGraphNode, base_positions: Dictionary, offsets: Dictionary, source_order: Dictionary, anchor_influence: Dictionary, one_sided := false) -> bool:
	var left_rect := _auto_spacing_rect(left, base_positions, offsets, true)
	var right_rect := _auto_spacing_rect(right, base_positions, offsets, true)
	if not left_rect.intersects(right_rect):
		return false
	var overlap_x := minf(left_rect.end.x, right_rect.end.x) - maxf(left_rect.position.x, right_rect.position.x)
	var overlap_y := minf(left_rect.end.y, right_rect.end.y) - maxf(left_rect.position.y, right_rect.position.y)
	if overlap_x <= 0.0 or overlap_y <= 0.0:
		return false
	var left_id: int = left.node_resource.id
	var right_id: int = right.node_resource.id
	var left_base_center := Vector2(base_positions[left_id]) + left.size * 0.5
	var right_base_center := Vector2(base_positions[right_id]) + right.size * 0.5
	var axis := Vector2.RIGHT if overlap_x <= overlap_y else Vector2.DOWN
	var left_axis_value := left_base_center.x if axis == Vector2.RIGHT else left_base_center.y
	var right_axis_value := right_base_center.x if axis == Vector2.RIGHT else right_base_center.y
	var left_precedes_right := left_axis_value < right_axis_value
	if is_equal_approx(left_axis_value, right_axis_value):
		left_precedes_right = int(source_order.get(left_id, left_id)) < int(source_order.get(right_id, right_id))
	# Use the distance to the required ordered boundary, not only the current
	# intersection width. If earlier avoidance carried two cards across one
	# another, this restores their saved order in one correction.
	var penetration := 0.0
	if axis == Vector2.RIGHT:
		penetration = left_rect.end.x - right_rect.position.x if left_precedes_right else right_rect.end.x - left_rect.position.x
	else:
		penetration = left_rect.end.y - right_rect.position.y if left_precedes_right else right_rect.end.y - left_rect.position.y
	var direction := axis if left_precedes_right else -axis
	var weights := _auto_spacing_pair_weights(left_id, right_id, anchor_influence)
	if one_sided and weights.is_equal_approx(Vector2.ONE):
		# The normal balanced correction preserves a component's centre, but a long
		# residual chain can converge asymptotically. At this final local stage,
		# keep the earlier saved card fixed and move only its ordered successor.
		weights = Vector2(0.0, 1.0) if left_precedes_right else Vector2(1.0, 0.0)
	var weight_sum := weights.x + weights.y
	if weight_sum <= 0.0:
		return false
	var correction := direction * (penetration + AUTO_SPACING_SEPARATION_EPSILON)
	offsets[left_id] = Vector2(offsets[left_id]) - correction * (weights.x / weight_sum)
	offsets[right_id] = Vector2(offsets[right_id]) + correction * (weights.y / weight_sum)
	return true


func _resolve_auto_spacing_residual_collisions(nodes: Array[BTGraphNode], base_positions: Dictionary, offsets: Dictionary, source_order: Dictionary, anchor_influence: Dictionary) -> void:
	# A one-sided Gauss-Seidel pass propagates a dragged card's displacement along
	# a packed chain without the nested 64 x 128 rescans used by the diagnostic
	# implementation. At most one new card needs to join the chain per pass, so a
	# node-count bound is sufficient and keeps large-tree work predictable.
	for _pass_index in range(nodes.size() + 1):
		var collision_pairs := _auto_spacing_collision_pairs(nodes, base_positions, offsets, source_order)
		if collision_pairs.is_empty():
			return
		var changed := false
		for pair in collision_pairs:
			changed = _apply_auto_spacing_collision_pair(pair[0] as BTGraphNode, pair[1] as BTGraphNode, base_positions, offsets, source_order, anchor_influence, true) or changed
		if not changed:
			return


func _seed_identical_auto_spacing_groups(nodes: Array[BTGraphNode], base_positions: Dictionary, offsets: Dictionary, source_order: Dictionary, anchor_node_id: int) -> void:
	var groups: Dictionary = {}
	for graph_node in nodes:
		var node_id: int = graph_node.node_resource.id
		var position := Vector2(base_positions[node_id])
		var key := "%d:%d" % [roundi(position.x / AUTO_SPACING_POSITION_BUCKET), roundi(position.y / AUTO_SPACING_POSITION_BUCKET)]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(graph_node)
	for key in groups:
		var group: Array = groups[key]
		if group.size() < AUTO_SPACING_IDENTICAL_GROUP_MIN_SIZE:
			continue
		group.sort_custom(func(left: BTGraphNode, right: BTGraphNode) -> bool:
			return int(source_order.get(left.node_resource.id, left.node_resource.id)) < int(source_order.get(right.node_resource.id, right.node_resource.id))
		)
		var maximum_size := Vector2.ZERO
		for member in group:
			maximum_size.x = maxf(maximum_size.x, member.size.x)
			maximum_size.y = maxf(maximum_size.y, member.size.y)
		var step := maximum_size + Vector2.ONE * AUTO_SPACING_GAP
		var column_count := maxi(1, ceili(sqrt(float(group.size()) * step.y / maxf(step.x, 1.0))))
		var row_count := ceili(float(group.size()) / float(column_count))
		var seeded_positions: Dictionary = {}
		var anchor_seed := Vector2.ZERO
		for index in range(group.size()):
			var member := group[index] as BTGraphNode
			var column := index % column_count
			var row := index / column_count
			var members_in_row := mini(column_count, group.size() - row * column_count)
			var seed := Vector2(
				(float(column) - float(members_in_row - 1) * 0.5) * step.x,
				(float(row) - float(row_count - 1) * 0.5) * step.y
			)
			seeded_positions[member.node_resource.id] = seed
			if member.node_resource.id == anchor_node_id:
				anchor_seed = seed
		var translation := -anchor_seed if seeded_positions.has(anchor_node_id) else Vector2.ZERO
		for member in group:
			var member_id: int = member.node_resource.id
			offsets[member_id] = Vector2(seeded_positions[member_id]) + translation


func _auto_spacing_collision_pairs(nodes: Array[BTGraphNode], base_positions: Dictionary, offsets: Dictionary, source_order: Dictionary) -> Array[Array]:
	var ordered: Array[BTGraphNode] = nodes.duplicate()
	ordered.sort_custom(func(left: BTGraphNode, right: BTGraphNode) -> bool:
		var left_rect := _auto_spacing_rect(left, base_positions, offsets, true)
		var right_rect := _auto_spacing_rect(right, base_positions, offsets, true)
		if not is_equal_approx(left_rect.position.x, right_rect.position.x):
			return left_rect.position.x < right_rect.position.x
		if not is_equal_approx(left_rect.position.y, right_rect.position.y):
			return left_rect.position.y < right_rect.position.y
		return int(source_order.get(left.node_resource.id, left.node_resource.id)) < int(source_order.get(right.node_resource.id, right.node_resource.id))
	)
	var pairs: Array[Array] = []
	for left_index in range(ordered.size()):
		var left := ordered[left_index]
		var left_rect := _auto_spacing_rect(left, base_positions, offsets, true)
		for right_index in range(left_index + 1, ordered.size()):
			var right := ordered[right_index]
			var right_rect := _auto_spacing_rect(right, base_positions, offsets, true)
			if right_rect.position.x >= left_rect.end.x:
				break
			if left_rect.intersects(right_rect):
				pairs.append([left, right])
	return pairs


func _rendered_auto_spacing_has_overlap() -> bool:
	var ordered: Array[BTGraphNode] = []
	for child in graph_edit.get_children() if is_instance_valid(graph_edit) else []:
		if child is BTGraphNode and child.visible and child.node_resource != null:
			ordered.append(child)
	ordered.sort_custom(func(left: BTGraphNode, right: BTGraphNode) -> bool:
		if not is_equal_approx(left.position_offset.x, right.position_offset.x):
			return left.position_offset.x < right.position_offset.x
		return left.node_resource.id < right.node_resource.id
	)
	for left_index in range(ordered.size()):
		var left := ordered[left_index]
		var left_rect := Rect2(left.position_offset, left.size)
		for right_index in range(left_index + 1, ordered.size()):
			var right := ordered[right_index]
			if right.position_offset.x >= left_rect.end.x:
				break
			if left_rect.intersects(Rect2(right.position_offset, right.size)):
				return true
	return false


func _auto_spacing_rect(graph_node: BTGraphNode, base_positions: Dictionary, offsets: Dictionary, padded := false) -> Rect2:
	var node_id: int = graph_node.node_resource.id
	var rect := Rect2(Vector2(base_positions[node_id]) + Vector2(offsets.get(node_id, Vector2.ZERO)), graph_node.size)
	return rect.grow(AUTO_SPACING_GAP * 0.5) if padded else rect


func _auto_spacing_pair_weights(first_id: int, second_id: int, anchor_influence: Dictionary) -> Vector2:
	var first_influenced := anchor_influence.has(first_id)
	var second_influenced := anchor_influence.has(second_id)
	if first_influenced and not second_influenced:
		anchor_influence[second_id] = int(anchor_influence[first_id]) + 1
		return Vector2(0.0, 1.0)
	if second_influenced and not first_influenced:
		anchor_influence[first_id] = int(anchor_influence[second_id]) + 1
		return Vector2(1.0, 0.0)
	if first_influenced and second_influenced:
		var first_depth := int(anchor_influence[first_id])
		var second_depth := int(anchor_influence[second_id])
		if first_depth < second_depth:
			return Vector2(0.0, 1.0)
		if second_depth < first_depth:
			return Vector2(1.0, 0.0)
	return Vector2.ONE


func _preserve_auto_spacing_order(nodes: Array[BTGraphNode], nodes_by_id: Dictionary, base_positions: Dictionary, offsets: Dictionary, source_order: Dictionary, anchor_influence: Dictionary) -> bool:
	var changed := false
	var children_by_parent: Dictionary = {}
	for graph_node in nodes:
		var parent_id: int = graph_node.node_resource.parent_id
		if nodes_by_id.has(parent_id):
			var parent := nodes_by_id[parent_id] as BTGraphNode
			var parent_base := Vector2(base_positions[parent_id])
			var child_base := Vector2(base_positions[graph_node.node_resource.id])
			var base_vertical_delta := child_base.y - parent_base.y
			if base_vertical_delta > AUTO_SPACING_SEPARATION_EPSILON:
				changed = _apply_auto_spacing_order_constraint(parent, graph_node, Vector2.DOWN, base_positions, offsets, anchor_influence) or changed
			elif base_vertical_delta < -AUTO_SPACING_SEPARATION_EPSILON:
				changed = _apply_auto_spacing_order_constraint(graph_node, parent, Vector2.DOWN, base_positions, offsets, anchor_influence) or changed
			if not children_by_parent.has(parent_id):
				children_by_parent[parent_id] = []
			children_by_parent[parent_id].append(graph_node)
	for parent_id in children_by_parent:
		var siblings: Array = children_by_parent[parent_id]
		siblings.sort_custom(func(left: BTGraphNode, right: BTGraphNode) -> bool:
			var left_x := Vector2(base_positions[left.node_resource.id]).x
			var right_x := Vector2(base_positions[right.node_resource.id]).x
			if not is_equal_approx(left_x, right_x):
				return left_x < right_x
			return int(source_order.get(left.node_resource.id, left.node_resource.id)) < int(source_order.get(right.node_resource.id, right.node_resource.id))
		)
		for index in range(siblings.size() - 1):
			var left := siblings[index] as BTGraphNode
			var right := siblings[index + 1] as BTGraphNode
			var base_horizontal_delta := Vector2(base_positions[right.node_resource.id]).x - Vector2(base_positions[left.node_resource.id]).x
			if base_horizontal_delta > AUTO_SPACING_SEPARATION_EPSILON:
				changed = _apply_auto_spacing_order_constraint(left, right, Vector2.RIGHT, base_positions, offsets, anchor_influence) or changed
	return changed


func _apply_auto_spacing_order_constraint(first: BTGraphNode, second: BTGraphNode, axis: Vector2, base_positions: Dictionary, offsets: Dictionary, anchor_influence: Dictionary) -> bool:
	var first_id: int = first.node_resource.id
	var second_id: int = second.node_resource.id
	var first_position := Vector2(base_positions[first_id]) + Vector2(offsets[first_id])
	var second_position := Vector2(base_positions[second_id]) + Vector2(offsets[second_id])
	var current_delta := (second_position - first_position).dot(axis)
	if current_delta >= AUTO_SPACING_SEPARATION_EPSILON:
		return false
	var weights := _auto_spacing_pair_weights(first_id, second_id, anchor_influence)
	var first_weight := weights.x
	var second_weight := weights.y
	var weight_sum := first_weight + second_weight
	if weight_sum <= 0.0:
		return false
	var correction := axis * (AUTO_SPACING_SEPARATION_EPSILON - current_delta)
	offsets[first_id] = Vector2(offsets[first_id]) - correction * (first_weight / weight_sum)
	offsets[second_id] = Vector2(offsets[second_id]) + correction * (second_weight / weight_sum)
	return true


func _reset_auto_spacing() -> void:
	if not is_instance_valid(graph_edit):
		return
	auto_spacing_targets.clear()
	auto_spacing_signature = ""
	pending_auto_spacing_anchor_id = -1
	drag_auto_spacing_base_targets.clear()
	drag_auto_spacing_original_targets.clear()
	pending_auto_spacing_seed_targets.clear()
	for child in graph_edit.get_children():
		if child is BTGraphNode:
			child.set_visual_offset(Vector2.ZERO)
	graph_edit.queue_redraw()


func _active_dragged_graph_node() -> BTGraphNode:
	for child in graph_edit.get_children() if is_instance_valid(graph_edit) else []:
		if child is BTGraphNode and child.manual_dragging:
			return child
	return null


func _capture_current_auto_spacing_offsets() -> Dictionary:
	var result: Dictionary = {}
	for child in graph_edit.get_children() if is_instance_valid(graph_edit) else []:
		if child is BTGraphNode and child.node_resource != null:
			result[child.node_resource.id] = child.visual_offset
	return result


func _restore_auto_spacing_after_click() -> void:
	auto_spacing_targets = drag_auto_spacing_original_targets.duplicate(true)
	for child in graph_edit.get_children() if is_instance_valid(graph_edit) else []:
		if child is BTGraphNode and child.node_resource != null:
			child.set_visual_offset(Vector2(auto_spacing_targets.get(child.node_resource.id, Vector2.ZERO)))
	drag_auto_spacing_base_targets.clear()
	drag_auto_spacing_original_targets.clear()
	pending_auto_spacing_seed_targets.clear()
	pending_auto_spacing_anchor_id = -1
	auto_spacing_signature = _auto_spacing_layout_signature()
	graph_edit.queue_redraw()


func _build_drag_auto_spacing_baseline(dragged_node_id: int) -> Dictionary:
	var nodes: Array[BTGraphNode] = []
	var base_positions: Dictionary = {}
	var offsets := _capture_current_auto_spacing_offsets()
	for child in graph_edit.get_children() if is_instance_valid(graph_edit) else []:
		if child is BTGraphNode and child.node_resource != null:
			nodes.append(child)
			base_positions[child.node_resource.id] = child.position_offset - child.visual_offset
	offsets[dragged_node_id] = Vector2.ZERO
	# Remove offsets that were needed only because of the card now being dragged.
	# Testing a zero offset against the still-valid layout is much cheaper than
	# restarting the 32-iteration global solver on every pointer-down.
	for _pass_index in range(3):
		var changed := false
		for graph_node in nodes:
			var node_id: int = graph_node.node_resource.id
			if node_id == dragged_node_id:
				continue
			var previous_offset := Vector2(offsets.get(node_id, Vector2.ZERO))
			if previous_offset.is_zero_approx():
				continue
			offsets[node_id] = Vector2.ZERO
			if _auto_spacing_node_collides(graph_node, nodes, base_positions, offsets, dragged_node_id):
				offsets[node_id] = previous_offset
			else:
				changed = true
		if not changed:
			break
	return offsets


func _auto_spacing_node_collides(graph_node: BTGraphNode, nodes: Array[BTGraphNode], base_positions: Dictionary, offsets: Dictionary, excluded_node_id: int) -> bool:
	var node_id: int = graph_node.node_resource.id
	var candidate_rect := _auto_spacing_rect(graph_node, base_positions, offsets, true)
	for other in nodes:
		var other_id: int = other.node_resource.id
		if other_id == node_id or other_id == excluded_node_id:
			continue
		if candidate_rect.intersects(_auto_spacing_rect(other, base_positions, offsets, true)):
			return true
	return false


func _on_search_changed(text: String) -> void:
	if not _feature_enabled("search"):
		return
	search_query = text.strip_edges().to_lower()
	_refresh_search_results(false)
	_apply_search_results_to_graph()


func _on_search_submitted(_text: String) -> void:
	_navigate_search_result(1)


func _refresh_search_results(preserve_current: bool) -> void:
	var previous_id := _current_search_result_id() if preserve_current else -1
	search_result_ids.clear()
	search_result_index = -1
	if not search_query.is_empty() and current_tree != null:
		for node in current_tree.nodes:
			if node == null or _is_attached_decorator(node):
				continue
			if _node_matches_search(node):
				search_result_ids.append(node.id)
		search_result_ids.sort()
	if previous_id != -1:
		search_result_index = search_result_ids.find(previous_id)
	_update_search_controls()


func _apply_search_results_to_graph() -> void:
	for child in graph_edit.get_children():
		if not (child is BTGraphNode):
			continue
		var graph_node: BTGraphNode = child
		var node_id := graph_node.node_resource.id
		graph_node.set_search_state(not search_query.is_empty(), search_result_ids.has(node_id), _current_search_result_id() == node_id)


func _navigate_search_result(direction: int) -> void:
	if not _feature_enabled("search") or search_result_ids.is_empty():
		return
	if search_result_index < 0:
		search_result_index = 0 if direction >= 0 else search_result_ids.size() - 1
	else:
		search_result_index = posmod(search_result_index + direction, search_result_ids.size())
	_update_search_controls()
	_apply_search_results_to_graph()
	_focus_graph_node(_current_search_result_id())


func _current_search_result_id() -> int:
	if search_result_index < 0 or search_result_index >= search_result_ids.size():
		return -1
	return search_result_ids[search_result_index]


func _update_search_controls() -> void:
	if is_instance_valid(search_result_label):
		if search_query.is_empty():
			search_result_label.text = "0 results"
		elif search_result_ids.is_empty():
			search_result_label.text = "No matches"
		elif search_result_index < 0:
			search_result_label.text = "0/%d results" % search_result_ids.size()
		else:
			search_result_label.text = "%d/%d results" % [search_result_index + 1, search_result_ids.size()]
	var navigation_disabled := not _feature_enabled("search") or search_result_ids.is_empty()
	if is_instance_valid(search_previous_button):
		search_previous_button.disabled = navigation_disabled
	if is_instance_valid(search_next_button):
		search_next_button.disabled = navigation_disabled


func _node_matches_search(node: BTNodeResource) -> bool:
	if search_query.is_empty() or node == null:
		return true
	var haystack := "%s %s %s %s" % [node.title, node.node_type, node.description, JSON.stringify(node.parameters)]
	for decorator in current_tree.get_decorators_of(node.id):
		haystack += " %s %s" % [decorator.title, JSON.stringify(decorator.parameters)]
	return search_query in haystack.to_lower()


func _set_all_subtrees_collapsed(collapsed: bool) -> void:
	if current_tree == null:
		return
	if not _feature_enabled("subtree_collapse"):
		_set_status("Enable Subtree Collapse / Expand in Display Features first.")
		return
	_push_history()
	for node in current_tree.nodes:
		if node != null and not current_tree.get_children_of(node.id).is_empty():
			node.collapsed = collapsed
	_rebuild_graph()
	_set_status("%s all subtrees." % ["Collapsed" if collapsed else "Expanded"])


func _focus_selected_subtree() -> void:
	if _get_selected_node() == null:
		_set_status("Select a node to focus its subtree.")
		return
	focus_root_id = selected_node_id
	_rebuild_graph()
	_set_status("Focused subtree at node #%d." % focus_root_id)


func _clear_subtree_focus() -> void:
	focus_root_id = -1
	_rebuild_graph()
	_set_status("Showing the complete behavior tree.")


func _fit_visible_tree() -> void:
	var visible_nodes: Array[BTGraphNode] = []
	for child in graph_edit.get_children():
		if child is BTGraphNode:
			visible_nodes.append(child)
	if visible_nodes.is_empty():
		return
	var bounds := Rect2(visible_nodes[0].position_offset, visible_nodes[0].size)
	for node in visible_nodes:
		bounds = bounds.merge(Rect2(node.position_offset, node.size))
	var viewport_size := graph_edit.size - Vector2(80.0, 80.0)
	var target_zoom := min(viewport_size.x / max(1.0, bounds.size.x), viewport_size.y / max(1.0, bounds.size.y))
	graph_edit.zoom = clampf(target_zoom, graph_edit.zoom_min, graph_edit.zoom_max)
	graph_edit.scroll_offset = bounds.position * graph_edit.zoom - Vector2(40.0, 40.0)


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
	_refresh_inspector()


func _on_advanced_parameters_toggled(enabled: bool) -> void:
	node_parameters_edit.visible = enabled


func _on_advanced_parameters_changed() -> void:
	if suppress_inspector_changes:
		return
	var node := _get_selected_node()
	if node == null:
		return
	var parser := JSON.new()
	if parser.parse(node_parameters_edit.text) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		_set_status("Parameters must be a valid JSON object; previous parameters were preserved.")
		return
	_push_history()
	node.parameters = parser.data
	suppress_inspector_changes = true
	_refresh_typed_parameters(node)
	suppress_inspector_changes = false
	_refresh_selected_graph_node(node)


func _refresh_typed_parameters(node: BTNodeResource) -> void:
	for child in typed_parameters_container.get_children():
		child.free()
	parameter_controls.clear()
	parameter_rows.clear()
	if node == null:
		var empty_label := Label.new()
		empty_label.text = "Select a node to edit its parameters."
		typed_parameters_container.add_child(empty_label)
		return
	match node.node_type:
		BTNodeResource.TYPE_ACTION:
			_add_parameter_line("action_name", "Actor Method", str(node.parameters.get("action_name", "")))
		BTNodeResource.TYPE_CONDITION:
			var condition_mode := "actor_method" if not str(node.parameters.get("condition_name", "")).is_empty() else "blackboard"
			_add_parameter_option("__condition_mode", "Mode", ["actor_method", "blackboard"], condition_mode)
			_add_parameter_line("condition_name", "Actor Method", str(node.parameters.get("condition_name", "")))
			_add_blackboard_key_parameter(str(node.parameters.get("blackboard_key", "")))
			_add_parameter_option("operator", "Operator", _comparison_operators(), str(node.parameters.get("operator", "equals")))
			_add_parameter_line("expected", "Expected Value (JSON)", JSON.stringify(node.parameters.get("expected", node.parameters.get("value", true))))
			_update_parameter_row_visibility(node.node_type)
		BTNodeResource.TYPE_SELECTOR:
			_add_parameter_bool("reactive", "Reactive", bool(node.parameters.get("reactive", false)))
		BTNodeResource.TYPE_PARALLEL:
			_add_parameter_option("success_policy", "Success Policy", ["all", "any"], str(node.parameters.get("success_policy", "all")))
			_add_parameter_option("failure_policy", "Failure Policy", ["any", "all"], str(node.parameters.get("failure_policy", "any")))
		BTNodeResource.TYPE_RANDOM_SELECTOR:
			_add_parameter_number("seed", "Seed (-1 = random)", float(node.parameters.get("seed", -1)), -1.0, 2147483647.0, 1.0)
		BTNodeResource.TYPE_REPEAT:
			_add_parameter_number("repeat_count", "Repeat Count (-1 = forever)", float(node.parameters.get("repeat_count", -1)), -1.0, 1000000.0, 1.0)
		BTNodeResource.TYPE_WAIT:
			_add_parameter_number("duration", "Duration (seconds)", float(node.parameters.get("duration", 1.0)), 0.0, 86400.0, 0.05)
		BTNodeResource.TYPE_DECORATOR:
			_add_parameter_option("mode", "Mode", ["blackboard", "cooldown", "time_limit", "invert", "force_success", "force_failure", "repeat_forever"], str(node.parameters.get("mode", "blackboard")))
			_add_blackboard_key_parameter(str(node.parameters.get("blackboard_key", "")))
			_add_parameter_option("operator", "Operator", _comparison_operators(), str(node.parameters.get("operator", "equals")))
			_add_parameter_line("value", "Comparison Value (JSON)", JSON.stringify(node.parameters.get("value", true)))
			_add_parameter_bool("invert", "Invert Result", bool(node.parameters.get("invert", false)))
			_add_parameter_number("duration", "Duration (seconds)", float(node.parameters.get("duration", 1.0)), 0.0, 86400.0, 0.05)
			_update_parameter_row_visibility(node.node_type)
		_:
			var no_parameters := Label.new()
			no_parameters.text = "This node has no built-in parameters."
			typed_parameters_container.add_child(no_parameters)


func _add_parameter_row(key: String, label_text: String, control: Control) -> void:
	var row := VBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	row.add_child(label)
	row.add_child(control)
	typed_parameters_container.add_child(row)
	parameter_controls[key] = control
	parameter_rows[key] = row


func _add_parameter_line(key: String, label_text: String, value: String) -> void:
	var edit := LineEdit.new()
	edit.text = value
	edit.text_changed.connect(func(_value: String) -> void: _on_typed_parameter_changed())
	_add_parameter_row(key, label_text, edit)


func _add_blackboard_key_parameter(value: String) -> void:
	var row_control := VBoxContainer.new()
	var edit := LineEdit.new()
	edit.text = value
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.placeholder_text = "Schema key or dynamic key"
	edit.text_changed.connect(func(_value: String) -> void: _on_typed_parameter_changed())
	row_control.add_child(edit)
	var picker := OptionButton.new()
	picker.tooltip_text = "Choose a declared Schema key. Free typing remains available for dynamic keys."
	picker.add_item("Choose Schema Key...")
	picker.set_item_metadata(0, "")
	var selected_index := 0
	if current_tree != null and current_tree.blackboard_schema != null:
		for entry in current_tree.blackboard_schema.entries:
			if entry == null or entry.key.strip_edges().is_empty():
				continue
			picker.add_item("%s [%s]" % [entry.key, entry.value_type])
			picker.set_item_metadata(picker.item_count - 1, entry.key)
			if entry.key == value:
				selected_index = picker.item_count - 1
	picker.select(selected_index)
	picker.item_selected.connect(func(index: int) -> void:
		var selected_key := str(picker.get_item_metadata(index))
		if not selected_key.is_empty():
			edit.text = selected_key
	)
	row_control.add_child(picker)
	_add_parameter_row("blackboard_key", "Blackboard Key", row_control)
	parameter_controls["blackboard_key"] = edit
	parameter_controls["__blackboard_key_picker"] = picker


func _add_parameter_option(key: String, label_text: String, options: Array[String], value: String) -> void:
	var option := OptionButton.new()
	for item in options:
		option.add_item(item.replace("_", " ").capitalize())
		option.set_item_metadata(option.item_count - 1, item)
	var selected_index := options.find(value)
	option.select(maxi(0, selected_index))
	option.item_selected.connect(func(_index: int) -> void: _on_typed_parameter_changed(true))
	_add_parameter_row(key, label_text, option)


func _add_parameter_bool(key: String, label_text: String, value: bool) -> void:
	var check := CheckBox.new()
	check.text = "Enabled"
	check.button_pressed = value
	check.toggled.connect(func(_value: bool) -> void: _on_typed_parameter_changed())
	_add_parameter_row(key, label_text, check)


func _add_parameter_number(key: String, label_text: String, value: float, minimum: float, maximum: float, step: float) -> void:
	var number := SpinBox.new()
	number.min_value = minimum
	number.max_value = maximum
	number.step = step
	number.value = value
	number.allow_greater = false
	number.allow_lesser = false
	number.value_changed.connect(func(_value: float) -> void: _on_typed_parameter_changed())
	_add_parameter_row(key, label_text, number)


func _comparison_operators() -> Array[String]:
	return ["exists", "not_exists", "is_true", "is_false", "equals", "not_equals", ">", "<", ">=", "<="]


func _on_typed_parameter_changed(refresh_visibility := false) -> void:
	if suppress_inspector_changes:
		return
	var node := _get_selected_node()
	if node == null:
		return
	_push_history()
	var parameters := node.parameters.duplicate(true)
	if node.node_type == BTNodeResource.TYPE_CONDITION:
		var condition_mode := str(_typed_parameter_value("__condition_mode"))
		if condition_mode == "actor_method":
			parameters["condition_name"] = str(_typed_parameter_value("condition_name")).strip_edges()
		else:
			parameters["condition_name"] = ""
			parameters["blackboard_key"] = str(_typed_parameter_value("blackboard_key")).strip_edges()
			parameters["operator"] = str(_typed_parameter_value("operator"))
			parameters["expected"] = _parse_json_value(str(_typed_parameter_value("expected")), parameters.get("expected", true))
	else:
		for key in parameter_controls:
			if not str(key).begins_with("__"):
				var value: Variant = _typed_parameter_value(str(key))
				if str(key) == "value":
					value = _parse_json_value(str(value), parameters.get(key, true))
				parameters[key] = value
	node.parameters = parameters
	suppress_inspector_changes = true
	node_parameters_edit.text = JSON.stringify(node.parameters, "\t")
	suppress_inspector_changes = false
	if refresh_visibility:
		_update_parameter_row_visibility(node.node_type)
	_refresh_selected_graph_node(node)


func _typed_parameter_value(key: String) -> Variant:
	var control: Control = parameter_controls.get(key)
	if control is LineEdit:
		return control.text
	if control is OptionButton:
		return control.get_item_metadata(control.selected)
	if control is CheckBox:
		return control.button_pressed
	if control is SpinBox:
		if control.step >= 1.0:
			return int(control.value)
		return control.value
	return null


func _parse_json_value(text: String, fallback: Variant) -> Variant:
	var parser := JSON.new()
	if parser.parse(text) == OK:
		return parser.data
	_set_status("Value must be a valid JSON literal; previous value was preserved.")
	return fallback


func _update_parameter_row_visibility(node_type: String) -> void:
	if node_type == BTNodeResource.TYPE_CONDITION:
		var actor_mode := str(_typed_parameter_value("__condition_mode")) == "actor_method"
		_set_parameter_rows_visible(["condition_name"], actor_mode)
		_set_parameter_rows_visible(["blackboard_key", "operator", "expected"], not actor_mode)
	elif node_type == BTNodeResource.TYPE_DECORATOR:
		var mode := str(_typed_parameter_value("mode"))
		_set_parameter_rows_visible(["blackboard_key", "operator", "value", "invert"], mode == "blackboard")
		_set_parameter_rows_visible(["duration"], mode == "cooldown" or mode == "time_limit")


func _set_parameter_rows_visible(keys: Array[String], visible: bool) -> void:
	for key in keys:
		var row: Control = parameter_rows.get(key)
		if row != null:
			row.visible = visible


func _refresh_selected_graph_node(node: BTNodeResource) -> void:
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
	var parser := JSON.new()
	if parser.parse(text) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return
	var payload: Dictionary = parser.data
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
	last_runtime_snapshot = snapshot.duplicate(true)
	_refresh_blackboard_panel(snapshot)
	var visual_signature := _runtime_visual_signature(snapshot)
	if visual_signature == last_runtime_visual_signature:
		return
	last_runtime_visual_signature = visual_signature
	var active_ids: Array = snapshot.get("path_ids", [])
	var failure_reasons: Dictionary = snapshot.get("failure_reasons", {})
	visible_failure_annotations.clear()
	if _feature_enabled("failure_reason"):
		visible_failure_annotations.assign(_build_failure_annotations(failure_reasons))
	_refresh_failure_summary()
	var leaf_id := -1
	if not active_ids.is_empty():
		leaf_id = int(active_ids[active_ids.size() - 1])
	var leaf_status := str(snapshot.get("leaf_status_text", "UNKNOWN"))
	var has_active_path := not active_ids.is_empty()
	for child in graph_edit.get_children():
		if not (child is BTGraphNode):
			continue
		var graph_node: BTGraphNode = child
		var node_id := int(String(graph_node.name))
		var is_active := _array_has_node_id(active_ids, node_id) or _node_contains_any_id(node_id, active_ids)
		var reason := _failure_reason_for_visible_node(node_id)
		graph_node.set_runtime_state(
			is_active,
			node_id == leaf_id,
			leaf_status,
			_feature_enabled("active_path"),
			_feature_enabled("branch_dimming"),
			reason,
			_feature_enabled("failure_reason"),
			has_active_path
		)
	_update_active_connections(active_ids)
	var actor := str(snapshot.get("actor", "Unknown"))
	var path_text := str(snapshot.get("path_text", ""))
	if is_instance_valid(runtime_debug_label):
		var runtime_text := "Live Debug: %s | %s | %s" % [
			actor,
			path_text if not path_text.is_empty() else "No active path",
			leaf_status
		]
		runtime_debug_label.text = runtime_text
		runtime_debug_label.tooltip_text = runtime_text
	_refresh_navigation_paths()


func _update_active_connections(active_ids: Array) -> void:
	graph_edit.set_active_path(active_ids if _feature_enabled("active_path") else [])
	# Active connections are rendered by BTGraphEdit from the top/bottom ports.
	# Native GraphEdit activity would reveal its side-mounted helper line.


func _clear_runtime_highlights() -> void:
	if not is_instance_valid(graph_edit):
		return
	last_runtime_snapshot.clear()
	_refresh_blackboard_panel({})
	last_runtime_visual_signature = ""
	visible_failure_annotations.clear()
	_refresh_failure_summary()
	for child in graph_edit.get_children():
		if child is BTGraphNode:
			child.set_runtime_state(false, false, "", false, false, "", false, false)
	_update_active_connections([])


func _refresh_blackboard_panel(snapshot: Dictionary) -> void:
	if not is_instance_valid(blackboard_grid):
		return
	for child in blackboard_grid.get_children():
		child.free()
	var board: Dictionary = snapshot.get("blackboard", {}) if typeof(snapshot.get("blackboard", {})) == TYPE_DICTIONARY else {}
	var schema_types: Dictionary = snapshot.get("blackboard_schema_types", {}) if typeof(snapshot.get("blackboard_schema_types", {})) == TYPE_DICTIONARY else {}
	var schema_errors: Array = snapshot.get("blackboard_schema_errors", []) if typeof(snapshot.get("blackboard_schema_errors", [])) == TYPE_ARRAY else []
	var actor := str(snapshot.get("actor", "--"))
	blackboard_summary_label.text = "Live Blackboard: %s | %d keys | %d schema errors" % [actor, board.size(), schema_errors.size()]
	for heading in ["Key", "Type", "Value", "Schema"]:
		var label := Label.new()
		label.text = heading
		_configure_blackboard_column(label, blackboard_grid.get_child_count() % 4)
		label.add_theme_color_override("font_color", Color("93c5fd"))
		blackboard_grid.add_child(label)
	var keys: Array = board.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a).naturalnocasecmp_to(str(b)) < 0)
	for key_value in keys:
		var key := str(key_value)
		var value: Variant = board[key_value]
		var declared_type := str(schema_types.get(key, ""))
		var row_error := _blackboard_error_for_key(key, schema_errors)
		var values := [key, type_string(typeof(value)), _format_blackboard_value(value), "Dynamic" if declared_type.is_empty() else declared_type]
		if not row_error.is_empty():
			values[3] = "ERROR"
		for column in range(values.size()):
			var label := Label.new()
			label.text = str(values[column])
			_configure_blackboard_column(label, column)
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			label.tooltip_text = row_error if not row_error.is_empty() else str(values[column])
			if not row_error.is_empty():
				label.add_theme_color_override("font_color", Color("f87171"))
			elif column == 3 and not declared_type.is_empty():
				label.add_theme_color_override("font_color", Color("86efac"))
			blackboard_grid.add_child(label)
	if board.is_empty():
		var empty := Label.new()
		empty.text = "No blackboard values in the current runtime snapshot."
		empty.size_flags_horizontal = SIZE_EXPAND_FILL
		blackboard_grid.add_child(empty)
		for _index in range(3):
			blackboard_grid.add_child(Control.new())


func _configure_blackboard_column(label: Label, column: int) -> void:
	match column:
		0:
			label.custom_minimum_size.x = 220.0
		1:
			label.custom_minimum_size.x = 110.0
		2:
			label.custom_minimum_size.x = 260.0
			label.size_flags_horizontal = SIZE_EXPAND_FILL
		3:
			label.custom_minimum_size.x = 130.0


func _blackboard_error_for_key(key: String, errors: Array) -> String:
	for error in errors:
		var text := str(error)
		if "'%s'" % key in text:
			return text
	return ""


func _format_blackboard_value(value: Variant) -> String:
	if value is String:
		return value
	if value is Vector2:
		return "(%.2f, %.2f)" % [value.x, value.y]
	return str(value)


func _build_failure_annotations(failure_reasons: Dictionary) -> Array[Dictionary]:
	var annotations_by_owner: Dictionary = {}
	for key in failure_reasons.keys():
		var source_id := int(str(key))
		var source := current_tree.find_node(source_id) if current_tree != null else null
		if source == null:
			continue
		var owner_id := source.decorator_parent_id if source.decorator_parent_id != -1 else source.id
		var reason := str(failure_reasons[key]).strip_edges()
		if reason.is_empty():
			continue
		var display_reason := "Decorator: %s - %s" % [source.title, reason] if source.decorator_parent_id != -1 else reason
		var existing: Dictionary = annotations_by_owner.get(owner_id, {})
		if existing.is_empty() or source.decorator_parent_id != -1:
			annotations_by_owner[owner_id] = {"node_id": owner_id, "source_id": source_id, "source_title": source.title, "reason": display_reason}
	var annotations: Array[Dictionary] = []
	for owner_id in annotations_by_owner.keys():
		annotations.append(annotations_by_owner[owner_id])
	annotations.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["node_id"]) < int(b["node_id"]))
	return annotations


func _failure_reason_for_visible_node(node_id: int) -> String:
	for annotation in visible_failure_annotations:
		if int(annotation.get("node_id", -1)) == node_id:
			return str(annotation.get("reason", ""))
	return ""


func _refresh_failure_summary() -> void:
	if not is_instance_valid(failure_summary_button):
		return
	var enabled := _feature_enabled("failure_reason")
	failure_summary_button.visible = enabled and not visible_failure_annotations.is_empty()
	failure_summary_button.text = "Failures: %d" % visible_failure_annotations.size()
	var popup := failure_summary_button.get_popup()
	popup.clear()
	for index in range(visible_failure_annotations.size()):
		var annotation: Dictionary = visible_failure_annotations[index]
		var node := current_tree.find_node(int(annotation.get("node_id", -1))) if current_tree != null else null
		var title := node.title if node != null else "Node #%d" % int(annotation.get("node_id", -1))
		popup.add_item("%s: %s" % [title, str(annotation.get("reason", ""))], index)


func _on_failure_summary_selected(index: int) -> void:
	if index < 0 or index >= visible_failure_annotations.size():
		return
	_focus_graph_node(int(visible_failure_annotations[index].get("node_id", -1)))


func _runtime_visual_signature(snapshot: Dictionary) -> String:
	return JSON.stringify({
		"actor": snapshot.get("actor", ""),
		"path_ids": snapshot.get("path_ids", []),
		"path_titles": snapshot.get("path_titles", []),
		"path_text": snapshot.get("path_text", ""),
		"leaf_status_text": snapshot.get("leaf_status_text", "UNKNOWN"),
		"failure_reasons": snapshot.get("failure_reasons", {}),
		"active_path_enabled": _feature_enabled("active_path"),
		"branch_dimming_enabled": _feature_enabled("branch_dimming"),
		"failure_reason_enabled": _feature_enabled("failure_reason"),
		"path_summary_enabled": _feature_enabled("path_summary"),
	})


func _update_fisheye(delta: float) -> void:
	if not is_instance_valid(graph_edit):
		return
	if fisheye_wheel_pause_elapsed > 0.0 or zoom_layout_anchor_id != -1 or zoom_anchor_candidate_id != -1:
		fisheye_wheel_pause_elapsed = maxf(0.0, fisheye_wheel_pause_elapsed - delta)
		return
	var mouse_position := get_viewport().get_mouse_position()
	if fisheye_waiting_for_pointer_motion:
		if mouse_position.distance_to(fisheye_resume_pointer_position) < FISHEYE_RESUME_POINTER_DISTANCE:
			return
		fisheye_waiting_for_pointer_motion = false
		return
	if not fisheye_enabled:
		fisheye_focus_node_id = -1
		graph_edit.fisheye_focus_position = Vector2.ZERO
		graph_edit.queue_redraw()
		return
	if not graph_edit.get_global_rect().has_point(mouse_position):
		_reset_fisheye(delta)
		return
	var focused_node := _fisheye_node_at(mouse_position)
	if focused_node == null:
		_reset_fisheye(delta)
		return
	_apply_fisheye_focus(focused_node, delta)


func _apply_fisheye_focus(focused_node: BTGraphNode, delta: float) -> void:
	if focused_node == null or focused_node.node_resource == null:
		_reset_fisheye(delta)
		return
	fisheye_focus_node_id = focused_node.node_resource.id
	for child in graph_edit.get_children():
		if not (child is BTGraphNode):
			continue
		var graph_node: BTGraphNode = child
		var is_focused := graph_node == focused_node
		_apply_node_fisheye_scale(graph_node, FISHEYE_MAX_SCALE if is_focused else FISHEYE_CONTEXT_SCALE, 1.0 if is_focused else 0.0, delta)
	graph_edit.fisheye_focus_position = focused_node.position_offset + focused_node.size * 0.5
	graph_edit.queue_redraw()


func _on_graph_view_wheel_scrolled(local_position: Vector2) -> void:
	fisheye_wheel_pause_elapsed = FISHEYE_WHEEL_PAUSE
	zoom_layout_anchor_release_elapsed = ZOOM_LAYOUT_ANCHOR_RELEASE_DELAY
	_capture_zoom_layout_anchor(local_position)
	if fisheye_enabled:
		fisheye_waiting_for_pointer_motion = true
		fisheye_resume_pointer_position = graph_edit.get_global_transform_with_canvas() * local_position
		_reset_fisheye()


func _capture_zoom_layout_anchor(_local_position: Vector2) -> void:
	if not _feature_enabled("zoom_anchor") or not is_instance_valid(graph_edit):
		return
	# One wheel burst keeps a snapshot of the viewport center and its neighboring
	# nodes. This avoids switching anchors when temporary layout offsets move cards.
	if zoom_layout_anchor_id != -1 or zoom_anchor_candidate_id != -1:
		return
	var viewport_center := graph_edit.size * 0.5
	var view_center := _graph_view_center_tree_position()
	graph_edit.set_zoom_scroll_boundary(view_center, graph_edit.size / maxf(graph_edit.zoom, 0.01))
	var samples := _capture_zoom_center_samples(view_center, viewport_center)
	if samples.is_empty():
		return
	zoom_anchor_candidate_id = int(samples[0].get("id", -1))
	zoom_anchor_candidate_screen_position = viewport_center
	zoom_anchor_candidate_zoom = graph_edit.zoom
	zoom_anchor_candidate_frames = 2
	zoom_anchor_candidate_view_center = view_center
	zoom_anchor_candidate_samples = samples


func _prepare_zoom_layout_anchor() -> void:
	if zoom_anchor_candidate_id == -1 or not is_instance_valid(graph_edit):
		return
	if not is_equal_approx(graph_edit.zoom, zoom_anchor_candidate_zoom):
		zoom_layout_anchor_id = zoom_anchor_candidate_id
		zoom_layout_anchor_screen_position = zoom_anchor_candidate_screen_position
		zoom_layout_anchor_samples = zoom_anchor_candidate_samples.duplicate(true)
		zoom_layout_anchor_last_center = zoom_anchor_candidate_view_center
		zoom_layout_anchor_last_zoom = graph_edit.zoom
		zoom_layout_anchor_stable_frames = 0
		zoom_anchor_candidate_id = -1
		zoom_anchor_candidate_frames = 0
		zoom_anchor_candidate_samples.clear()
		return
	zoom_anchor_candidate_frames -= 1
	if zoom_anchor_candidate_frames <= 0:
		zoom_anchor_candidate_id = -1
		zoom_anchor_candidate_samples.clear()


func _restore_zoom_layout_anchor() -> void:
	if zoom_layout_anchor_id == -1 or not _feature_enabled("zoom_anchor") or not is_instance_valid(graph_edit):
		return
	var solved_center := _solve_zoom_view_center()
	if solved_center == Vector2.INF:
		_clear_zoom_layout_anchor()
		return
	graph_edit.set_zoom_scroll_boundary(solved_center, graph_edit.size / maxf(graph_edit.zoom, 0.01))
	var target_scroll := solved_center * graph_edit.zoom - zoom_layout_anchor_screen_position
	if not graph_edit.scroll_offset.is_equal_approx(target_scroll):
		graph_edit.scroll_offset = target_scroll
	var layout_stable := solved_center.distance_squared_to(zoom_layout_anchor_last_center) <= AUTO_SPACING_EPSILON * AUTO_SPACING_EPSILON
	var zoom_stable := is_equal_approx(graph_edit.zoom, zoom_layout_anchor_last_zoom)
	zoom_layout_anchor_stable_frames = zoom_layout_anchor_stable_frames + 1 if layout_stable and zoom_stable else 0
	zoom_layout_anchor_last_center = solved_center
	zoom_layout_anchor_last_zoom = graph_edit.zoom
	if zoom_layout_anchor_release_elapsed <= 0.0 and zoom_layout_anchor_stable_frames >= ZOOM_LAYOUT_ANCHOR_STABLE_FRAMES and zoom_anchor_candidate_id == -1:
		_clear_zoom_layout_anchor()


func _capture_zoom_center_samples(view_center: Vector2, viewport_center: Vector2) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var sample_radius := maxf(graph_edit.size.length() * ZOOM_CENTER_SAMPLE_RADIUS_FACTOR, 1.0)
	for child in graph_edit.get_children():
		if not (child is BTGraphNode) or not child.visible or child.node_resource == null:
			continue
		var graph_node: BTGraphNode = child
		var node_center: Vector2 = graph_node.position_offset + graph_node.size * 0.5
		var screen_distance: float = _graph_node_screen_center(graph_node).distance_to(viewport_center)
		candidates.append({
			"id": graph_node.node_resource.id,
			"relative": node_center - view_center,
			"distance": screen_distance,
			"weight": 1.0 / (1.0 + screen_distance / sample_radius),
		})
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return float(left.get("distance", INF)) < float(right.get("distance", INF))
	)
	if candidates.size() > ZOOM_CENTER_SAMPLE_LIMIT:
		candidates.resize(ZOOM_CENTER_SAMPLE_LIMIT)
	return candidates


func _solve_zoom_view_center() -> Vector2:
	var weighted_center := Vector2.ZERO
	var total_weight := 0.0
	for sample in zoom_layout_anchor_samples:
		var node_id := int(sample.get("id", -1))
		var graph_node := graph_edit.get_node_or_null(NodePath(str(node_id))) as BTGraphNode
		if graph_node == null or not graph_node.visible:
			continue
		var node_center := graph_node.position_offset + graph_node.size * 0.5
		var relative := Vector2(sample.get("relative", Vector2.ZERO))
		var weight := maxf(float(sample.get("weight", 1.0)), 0.001)
		weighted_center += (node_center - relative) * weight
		total_weight += weight
	return weighted_center / total_weight if total_weight > 0.0 else Vector2.INF


func _graph_view_center_tree_position() -> Vector2:
	return (graph_edit.scroll_offset + graph_edit.size * 0.5) / maxf(graph_edit.zoom, 0.01)


func _queue_zoom_layout_anchor_post_layout_restore() -> void:
	if zoom_layout_anchor_id == -1 or zoom_layout_anchor_restore_queued:
		return
	zoom_layout_anchor_restore_queued = true
	_restore_zoom_layout_anchor_post_layout.call_deferred()


func _restore_zoom_layout_anchor_post_layout() -> void:
	zoom_layout_anchor_restore_queued = false
	# GraphNode size resets and auto-spacing are deferred by Godot. Correct once
	# more after those updates so the viewport never displays their intermediate offset.
	_restore_zoom_layout_anchor()


func _nearest_visible_graph_node(local_position: Vector2) -> BTGraphNode:
	var nearest: BTGraphNode
	var nearest_distance := INF
	for child in graph_edit.get_children():
		if not (child is BTGraphNode) or not child.visible:
			continue
		var center := _graph_node_screen_center(child)
		var distance := center.distance_squared_to(local_position)
		if nearest == null or distance < nearest_distance:
			nearest = child
			nearest_distance = distance
	return nearest


func _graph_node_screen_center(graph_node: BTGraphNode) -> Vector2:
	return (graph_node.position_offset + graph_node.size * 0.5) * graph_edit.zoom - graph_edit.scroll_offset


func _clear_zoom_layout_anchor() -> void:
	zoom_anchor_candidate_id = -1
	zoom_anchor_candidate_frames = 0
	zoom_anchor_candidate_samples.clear()
	zoom_layout_anchor_id = -1
	zoom_layout_anchor_stable_frames = 0
	zoom_layout_anchor_release_elapsed = 0.0
	zoom_layout_anchor_restore_queued = false
	zoom_layout_anchor_samples.clear()


func _fisheye_node_at(mouse_position: Vector2) -> BTGraphNode:
	var focused: BTGraphNode
	var closest_distance := INF
	var graph_local := graph_edit.get_global_transform_with_canvas().affine_inverse() * mouse_position
	var tree_position := _graph_local_to_tree_position(graph_local)
	for child in graph_edit.get_children():
		if not (child is BTGraphNode) or not child.visible:
			continue
		var graph_node: BTGraphNode = child
		var rendered_rect := Rect2(graph_node.position_offset, graph_node.size)
		if not rendered_rect.has_point(tree_position):
			continue
		var distance := rendered_rect.get_center().distance_squared_to(tree_position)
		if focused == null or graph_node.z_index > focused.z_index or (graph_node.z_index == focused.z_index and distance <= closest_distance):
			focused = graph_node
			closest_distance = distance
	return focused


func _apply_node_fisheye_scale(graph_node: BTGraphNode, target_scale: float, influence: float, delta: float) -> void:
	var blend := clampf(delta * FISHEYE_LERP_SPEED, 0.0, 1.0)
	var current_scale := graph_node.fisheye_magnification
	var next_scale := lerpf(current_scale, target_scale, blend)
	graph_node.set_fisheye_magnification(next_scale)
	graph_node.z_index = 100 + int(influence * 1000.0) if influence > 0.0 else 0


func _reset_fisheye(delta := 0.0) -> void:
	if not is_instance_valid(graph_edit):
		return
	graph_edit.fisheye_focus_position = Vector2.ZERO
	fisheye_focus_node_id = -1
	var blend := 1.0 if delta <= 0.0 else clampf(delta * FISHEYE_LERP_SPEED, 0.0, 1.0)
	for child in graph_edit.get_children():
		if not (child is BTGraphNode):
			continue
		var graph_node: BTGraphNode = child
		var next_scale := lerpf(graph_node.fisheye_magnification, 1.0, blend)
		graph_node.set_fisheye_magnification(next_scale)
		# Clear transforms left by plugin versions that scaled GraphNode directly.
		graph_node.scale = Vector2.ONE
		graph_node.pivot_offset = Vector2.ZERO
		if is_equal_approx(next_scale, 1.0):
			graph_node.z_index = 0
	graph_edit.queue_redraw()


func _rebuild_graph_after_fisheye() -> void:
	# GraphEdit caches connection endpoints without accounting for child Control scale.
	# Recreating only the graph controls clears that cache without changing tree data.
	var saved_zoom := graph_edit.zoom
	var saved_scroll := graph_edit.scroll_offset
	_rebuild_graph()
	graph_edit.zoom = saved_zoom
	graph_edit.scroll_offset = saved_scroll
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
	var parser := JSON.new()
	if parser.parse(node_parameters_edit.text) == OK and typeof(parser.data) == TYPE_DICTIONARY:
		node.parameters = parser.data
	else:
		_set_status("Parameters must be a valid JSON object; previous parameters were preserved.")
	_refresh_selected_graph_node(node)


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
		6:
			_create_node_from_ui(BTNodeResource.TYPE_PARALLEL, pending_context_position)
		7:
			_create_node_from_ui(BTNodeResource.TYPE_RANDOM_SELECTOR, pending_context_position)
		8:
			_create_node_from_ui(BTNodeResource.TYPE_REPEAT, pending_context_position)
		9:
			_create_node_from_ui(BTNodeResource.TYPE_WAIT, pending_context_position)
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
		34:
			_auto_arrange_tree(true)
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
		33:
			_attach_decorator_to_selected("Time Limit", {
				"mode": "time_limit",
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

	var parent_id := selected_node_id
	var parent := current_tree.find_node(parent_id)
	if parent == null or not current_tree.can_accept_child(parent):
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
	return (local_position + graph_edit.scroll_offset) / maxf(0.01, graph_edit.zoom)


func _popup_context_menu() -> void:
	context_menu.set_item_disabled(context_menu.get_item_index(0), current_tree.root_node_id != -1)
	var has_selection := selected_node_id != -1
	context_menu.set_item_disabled(context_menu.get_item_index(20), not has_selection or selected_node_id == current_tree.root_node_id)
	context_menu.set_item_disabled(context_menu.get_item_index(21), not has_selection)
	context_menu.set_item_disabled(context_menu.get_item_index(22), not has_selection)
	context_menu.set_item_disabled(context_menu.get_item_index(23), not has_selection or current_tree.get_children_of(selected_node_id).is_empty())
	context_menu.set_item_disabled(context_menu.get_item_index(31), not has_selection)
	context_menu.set_item_disabled(context_menu.get_item_index(32), not has_selection)
	context_menu.set_item_disabled(context_menu.get_item_index(33), not has_selection)
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


func _auto_arrange_tree(overview_dense := false) -> void:
	if current_tree == null or current_tree.root_node_id == -1:
		_set_status("Create or load a tree before arranging.")
		return
	var root := current_tree.find_node(current_tree.root_node_id)
	if root == null:
		_set_status("Root node is missing.")
		return
	_push_history()
	var original_positions: Dictionary = {}
	for node in current_tree.nodes:
		if node != null and not _is_attached_decorator(node):
			original_positions[node.id] = node.position
	var depth_heights: Dictionary = {}
	_collect_layout_depth_heights(root, 0, depth_heights, overview_dense)
	var depth_positions := _build_layout_depth_positions(depth_heights, overview_dense)
	var cursor := {"x": LAYOUT_START.x}
	_arrange_subtree(root, 0, cursor, depth_positions, OVERVIEW_LAYOUT_HORIZONTAL_GAP if overview_dense else LAYOUT_HORIZONTAL_GAP)
	if _feature_enabled("multi_column") and not overview_dense:
		_apply_multi_column_layout()
	if _feature_enabled("stable_layout") and not overview_dense:
		_apply_stable_incremental_layout(original_positions)
	_refresh_entire_ui()
	_set_status("Auto arranged tree for dense overview." if overview_dense else "Auto arranged tree in behavior-tree layout.")


func _collect_layout_depth_heights(node: BTNodeResource, depth: int, depth_heights: Dictionary, overview_dense := false) -> void:
	var graph_node := graph_edit.get_node_or_null(NodePath(str(node.id))) as BTGraphNode
	var node_height := BTGraphNode.NORMAL_CARD_SIZE.y if overview_dense else (graph_node.size.y if graph_node != null else LAYOUT_VERTICAL_GAP - LAYOUT_MIN_VERTICAL_CLEARANCE)
	depth_heights[depth] = maxf(float(depth_heights.get(depth, 0.0)), node_height)
	for child in current_tree.get_children_of(node.id):
		_collect_layout_depth_heights(child, depth + 1, depth_heights, overview_dense)


func _build_layout_depth_positions(depth_heights: Dictionary, overview_dense := false) -> Dictionary:
	var positions := {0: LAYOUT_START.y}
	var max_depth := 0
	for depth in depth_heights:
		max_depth = maxi(max_depth, int(depth))
	for depth in range(max_depth):
		var layer_step := OVERVIEW_LAYOUT_VERTICAL_GAP if overview_dense else maxf(LAYOUT_VERTICAL_GAP, float(depth_heights.get(depth, 0.0)) + LAYOUT_MIN_VERTICAL_CLEARANCE)
		positions[depth + 1] = float(positions[depth]) + layer_step
	return positions


func _arrange_subtree(node: BTNodeResource, depth: int, cursor: Dictionary, depth_positions: Dictionary, horizontal_gap := LAYOUT_HORIZONTAL_GAP) -> float:
	var children := current_tree.get_children_of(node.id)
	var y := float(depth_positions.get(depth, LAYOUT_START.y + float(depth) * LAYOUT_VERTICAL_GAP))
	if children.is_empty():
		var leaf_x: float = cursor["x"]
		node.position = Vector2(leaf_x, y)
		cursor["x"] = leaf_x + horizontal_gap
		return leaf_x

	var child_positions: Array[float] = []
	for child in children:
		child_positions.append(_arrange_subtree(child, depth + 1, cursor, depth_positions, horizontal_gap))
	var first_x := child_positions[0]
	var last_x := child_positions[child_positions.size() - 1]
	node.position = Vector2((first_x + last_x) * 0.5, y)
	return node.position.x


func _apply_multi_column_layout() -> void:
	for parent in current_tree.nodes:
		if parent == null or _is_attached_decorator(parent):
			continue
		var children := current_tree.get_children_of(parent.id)
		if children.size() <= MULTI_COLUMN_THRESHOLD:
			continue
		var column_count := mini(MULTI_COLUMN_COUNT, ceili(sqrt(float(children.size()))))
		var rows_per_column := ceili(float(children.size()) / float(column_count))
		for index in range(children.size()):
			var column := index / rows_per_column
			var row := index % rows_per_column
			var target := Vector2(
				parent.position.x + (float(column) - float(column_count - 1) * 0.5) * 300.0,
				parent.position.y + LAYOUT_VERTICAL_GAP + float(row) * 210.0
			)
			_shift_subtree(children[index], target - children[index].position)


func _shift_subtree(node: BTNodeResource, offset: Vector2) -> void:
	node.position += offset
	for child in current_tree.get_children_of(node.id):
		_shift_subtree(child, offset)


func _apply_stable_incremental_layout(original_positions: Dictionary) -> void:
	var arranged_positions: Dictionary = {}
	for node in current_tree.nodes:
		if node != null and not _is_attached_decorator(node):
			arranged_positions[node.id] = node.position
	var settled: Array[Rect2] = []
	var ordered_nodes: Array[BTNodeResource] = []
	_collect_layout_order(current_tree.find_node(current_tree.root_node_id), ordered_nodes)
	for node in ordered_nodes:
		var candidate: Vector2 = Vector2(original_positions[node.id]) if original_positions.has(node.id) else Vector2(arranged_positions[node.id])
		var bounds := Rect2(candidate, Vector2(250.0, 150.0)).grow(20.0)
		if _rect_overlaps_any(bounds, settled):
			candidate = arranged_positions[node.id]
			bounds = Rect2(candidate, Vector2(250.0, 150.0)).grow(20.0)
			while _rect_overlaps_any(bounds, settled):
				candidate.x += 280.0
				bounds.position = candidate
		node.position = candidate
		settled.append(bounds)


func _collect_layout_order(node: BTNodeResource, result: Array[BTNodeResource]) -> void:
	if node == null:
		return
	result.append(node)
	for child in current_tree.get_children_of(node.id):
		_collect_layout_order(child, result)


func _rect_overlaps_any(rect: Rect2, existing: Array[Rect2]) -> bool:
	for other in existing:
		if rect.intersects(other):
			return true
	return false


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
	if focus_root_id != -1 and not _is_in_focused_branch(node):
		return true
	if not _feature_enabled("subtree_collapse"):
		return false
	var cursor := current_tree.find_node(node.parent_id)
	while cursor != null:
		if cursor.collapsed:
			if focus_root_id == -1 or not _is_ancestor_of(cursor.id, focus_root_id):
				return true
		cursor = current_tree.find_node(cursor.parent_id)
	return false


func _is_in_focused_branch(node: BTNodeResource) -> bool:
	if node.id == focus_root_id:
		return true
	var focus_descendants := _collect_descendant_ids(focus_root_id)
	if focus_descendants.has(node.id):
		return true
	var cursor := current_tree.find_node(focus_root_id)
	while cursor != null:
		if cursor.id == node.id:
			return true
		cursor = current_tree.find_node(cursor.parent_id)
	return false


func _is_ancestor_of(candidate_id: int, node_id: int) -> bool:
	var cursor := current_tree.find_node(node_id)
	while cursor != null:
		if cursor.id == candidate_id:
			return true
		cursor = current_tree.find_node(cursor.parent_id)
	return false


func _load_view_settings() -> void:
	var config := ConfigFile.new()
	if config.load(VIEW_SETTINGS_PATH) == OK:
		for definition in FEATURE_DEFINITIONS:
			var key := str(definition[0])
			var legacy_default := bool(definition[2])
			if key == "fisheye":
				legacy_default = bool(config.get_value("view", "fisheye", legacy_default))
			elif key == "compact":
				legacy_default = bool(config.get_value("view", "compact", legacy_default))
			elif key == "semantic_zoom":
				legacy_default = bool(config.get_value("view", "semantic_zoom", legacy_default))
			elif key == "enhanced_minimap":
				legacy_default = bool(config.get_value("view", "minimap", legacy_default))
			feature_states[key] = bool(config.get_value("features", key, legacy_default))
		fisheye_enabled = _feature_enabled("fisheye")
		compact_mode_enabled = _feature_enabled("compact")
		semantic_zoom_enabled = _feature_enabled("semantic_zoom")
		if is_instance_valid(grid_toggle):
			grid_toggle.set_pressed_no_signal(bool(config.get_value("view", "grid", true)))
		if is_instance_valid(minimap_toggle):
			minimap_toggle.set_pressed_no_signal(bool(config.get_value("view", "minimap", true)))
	if is_instance_valid(fisheye_toggle):
		fisheye_toggle.set_pressed_no_signal(fisheye_enabled)
	if is_instance_valid(branch_dimming_toggle):
		branch_dimming_toggle.set_pressed_no_signal(_feature_enabled("branch_dimming"))
	if is_instance_valid(failure_reason_toggle):
		failure_reason_toggle.set_pressed_no_signal(_feature_enabled("failure_reason"))
	if is_instance_valid(compact_toggle):
		compact_toggle.set_pressed_no_signal(compact_mode_enabled)
	if is_instance_valid(semantic_zoom_toggle):
		semantic_zoom_toggle.set_pressed_no_signal(semantic_zoom_enabled)
	if is_instance_valid(path_summary_toggle):
		path_summary_toggle.set_pressed_no_signal(_feature_enabled("path_summary"))
	if is_instance_valid(search_toggle):
		search_toggle.set_pressed_no_signal(_feature_enabled("search"))
	if is_instance_valid(graph_edit):
		graph_edit.show_grid = grid_toggle.button_pressed
		graph_edit.set_enhanced_minimap(_feature_enabled("enhanced_minimap"))
	_apply_feature_states()


func _save_view_settings() -> void:
	var config := ConfigFile.new()
	_populate_view_config(config)
	config.save(VIEW_SETTINGS_PATH)


func _populate_view_config(config: ConfigFile) -> void:
	for definition in FEATURE_DEFINITIONS:
		var key := str(definition[0])
		config.set_value("features", key, _feature_enabled(key))
	config.set_value("view", "fisheye", fisheye_enabled)
	config.set_value("view", "compact", compact_mode_enabled)
	config.set_value("view", "semantic_zoom", semantic_zoom_enabled)
	config.set_value("view", "grid", graph_edit.show_grid if is_instance_valid(graph_edit) else true)
	config.set_value("view", "minimap", graph_edit.minimap_enabled if is_instance_valid(graph_edit) else true)


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
		BTNodeResource.TYPE_RANDOM_SELECTOR:
			return "Tries children in a randomized order until one succeeds."
		BTNodeResource.TYPE_PARALLEL:
			return "Ticks all children and resolves them using success and failure policies."
		BTNodeResource.TYPE_REPEAT:
			return "Repeats its child a fixed number of times or forever."
		BTNodeResource.TYPE_ACTION:
			return "Leaf action executed by the agent."
		BTNodeResource.TYPE_CONDITION:
			return "Leaf condition check."
		BTNodeResource.TYPE_WAIT:
			return "Waits for a configured duration without calling the actor."
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
		BTNodeResource.TYPE_PARALLEL:
			return {"success_policy": "all", "failure_policy": "any"}
		BTNodeResource.TYPE_RANDOM_SELECTOR:
			return {"seed": -1}
		BTNodeResource.TYPE_REPEAT:
			return {"repeat_count": -1}
		BTNodeResource.TYPE_WAIT:
			return {"duration": 1.0}
		_:
			return {}


func _set_status(message: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = message
