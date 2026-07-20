extends Node
class_name BehaviorTreeRunner

const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")
const BTNodeResource = preload("res://addons/behavior_tree_editor/bt_node_resource.gd")
const BTStatus = preload("res://addons/behavior_tree_editor/runtime/bt_status.gd")
const DEBUG_BRIDGE_PATH := "res://.godot/behavior_tree_runtime_debug.json"

signal tree_ticked(status: int)
signal node_ticked(node_id: int, status: int)
signal active_path_changed(path_ids: Array, path_titles: Array, leaf_status: int)

@export var behavior_tree: BTTreeResource
@export var agent_path: NodePath
@export var actor_path: NodePath:
	set(value):
		_actor_path = value
		agent_path = value
	get:
		return _actor_path
@export var tick_on_process: bool = true
@export var tick_on_physics: bool = false
@export var auto_start: bool = true
@export var debug_enabled: bool = true
@export var editor_debug_bridge_enabled: bool = true
@export var editor_debug_bridge_interval: float = 0.08
@export var blackboard: Dictionary = {}

static var _debug_bridge_snapshots: Dictionary = {}

var agent: Node
var is_running := false
var node_memory: Dictionary = {}
var active_path_ids: Array[int] = []
var active_path_titles: Array[String] = []
var active_leaf_status: int = BTStatus.FAILURE
var last_node_statuses: Dictionary = {}
var _debug_bridge_elapsed := 0.0
var _actor_path: NodePath = NodePath("")
var _debug_stack: Array[BTNodeResource] = []


func _ready() -> void:
	add_to_group("behavior_tree_components")
	_resolve_agent()
	is_running = auto_start


func _process(delta: float) -> void:
	if is_running and tick_on_process:
		tick(delta)


func _physics_process(delta: float) -> void:
	if is_running and tick_on_physics:
		tick(delta)


func start_tree() -> void:
	_resolve_agent()
	is_running = true


func stop_tree() -> void:
	is_running = false


func restart_tree() -> void:
	stop_tree()
	node_memory.clear()
	start_tree()


func set_actor(actor: Node) -> void:
	agent = actor


func _resolve_agent() -> void:
	var target_path := actor_path if actor_path != NodePath("") else agent_path
	agent = get_node_or_null(target_path) if target_path != NodePath("") else get_parent()


func tick(delta: float = 0.0) -> int:
	if behavior_tree == null or behavior_tree.root_node_id == -1:
		tree_ticked.emit(BTStatus.FAILURE)
		return BTStatus.FAILURE
	if debug_enabled:
		active_path_ids.clear()
		active_path_titles.clear()
		active_leaf_status = BTStatus.FAILURE
		last_node_statuses.clear()
		_debug_stack.clear()
	var root := behavior_tree.find_node(behavior_tree.root_node_id)
	var status := _tick_node(root, delta)
	tree_ticked.emit(status)
	if debug_enabled:
		active_path_changed.emit(active_path_ids, active_path_titles, status)
		_update_editor_debug_bridge(delta)
	return status


func _tick_node(node: BTNodeResource, delta: float) -> int:
	if node == null or not node.enabled:
		return BTStatus.FAILURE
	if debug_enabled:
		_debug_stack.append(node)
	if not _passes_decorators(node, delta):
		_reset_subtree(node)
		_record_node_status(node, BTStatus.FAILURE)
		_capture_active_path(BTStatus.FAILURE)
		if debug_enabled:
			_debug_stack.pop_back()
		return BTStatus.FAILURE

	var status := BTStatus.FAILURE
	match node.node_type:
		BTNodeResource.TYPE_ROOT:
			status = _tick_root(node, delta)
		BTNodeResource.TYPE_SEQUENCE:
			status = _tick_sequence(node, delta)
		BTNodeResource.TYPE_SELECTOR:
			status = _tick_selector(node, delta)
		BTNodeResource.TYPE_DECORATOR:
			status = _tick_decorator(node, delta)
		BTNodeResource.TYPE_CONDITION:
			status = _tick_condition(node, delta)
		BTNodeResource.TYPE_ACTION:
			status = _tick_action(node, delta)
		_:
			status = BTStatus.FAILURE

	if status == BTStatus.RUNNING or node.node_type == BTNodeResource.TYPE_ACTION or node.node_type == BTNodeResource.TYPE_CONDITION:
		_capture_active_path(status)
	_set_node_running(node, status == BTStatus.RUNNING)
	_record_node_status(node, status)
	node_ticked.emit(node.id, status)
	if debug_enabled:
		_debug_stack.pop_back()
	return status


func _passes_decorators(node: BTNodeResource, delta: float) -> bool:
	for decorator in behavior_tree.get_decorators_of(node.id):
		if decorator == null or not decorator.enabled:
			continue
		var status := _tick_attached_decorator(decorator, node, delta)
		_record_node_status(decorator, status)
		if status == BTStatus.FAILURE:
			_capture_active_path(BTStatus.FAILURE, decorator)
			return false
	return true


func _tick_attached_decorator(decorator: BTNodeResource, owner: BTNodeResource, delta: float) -> int:
	var mode := str(decorator.parameters.get("mode", "blackboard")).to_lower()
	match mode:
		"blackboard":
			return _tick_blackboard_decorator(decorator)
		"cooldown":
			return _tick_cooldown_decorator(decorator, delta, owner)
		"time_limit":
			return _tick_time_limit_decorator(decorator, owner, delta)
		"force_success", "always_success", "succeeder":
			return BTStatus.SUCCESS
		"force_failure", "always_failure", "failer":
			return BTStatus.FAILURE
		"invert":
			return BTStatus.FAILURE
		_:
			return BTStatus.SUCCESS


func _tick_blackboard_decorator(decorator: BTNodeResource) -> int:
	var key := str(decorator.parameters.get("blackboard_key", ""))
	var op := str(decorator.parameters.get("operator", "equals")).to_lower()
	var expected: Variant = decorator.parameters.get("value", true)
	var actual: Variant = blackboard.get(key)
	var passed := false
	match op:
		"exists", "is_set":
			passed = blackboard.has(key) and actual != null
		"not_exists", "is_not_set":
			passed = not blackboard.has(key) or actual == null
		"is_true":
			passed = bool(actual) == true
		"is_false":
			passed = bool(actual) == false
		"equals", "==":
			passed = actual == expected
		"not_equals", "!=":
			passed = actual != expected
		"greater", ">":
			passed = float(actual) > float(expected)
		"less", "<":
			passed = float(actual) < float(expected)
		"greater_or_equal", ">=":
			passed = float(actual) >= float(expected)
		"less_or_equal", "<=":
			passed = float(actual) <= float(expected)
		_:
			passed = actual == expected
	var invert := bool(decorator.parameters.get("invert", false))
	return BTStatus.SUCCESS if passed != invert else BTStatus.FAILURE


func _tick_cooldown_decorator(decorator: BTNodeResource, delta: float, owner: BTNodeResource = null) -> int:
	if owner != null and _is_node_running(owner):
		return BTStatus.SUCCESS
	var key := "decorator_cooldown_%d" % decorator.id
	var remaining: float = float(node_memory.get(key, 0.0))
	if remaining > 0.0:
		node_memory[key] = max(0.0, remaining - delta)
		return BTStatus.FAILURE
	node_memory[key] = float(decorator.parameters.get("duration", 1.0))
	return BTStatus.SUCCESS


func _tick_time_limit_decorator(decorator: BTNodeResource, owner: BTNodeResource, delta: float) -> int:
	var key := "decorator_time_limit_%d_%d" % [decorator.id, owner.id]
	var elapsed := 0.0
	if _is_node_running(owner):
		elapsed = float(node_memory.get(key, 0.0))
	elapsed += delta
	node_memory[key] = elapsed
	return BTStatus.SUCCESS if elapsed <= float(decorator.parameters.get("duration", 1.0)) else BTStatus.FAILURE


func _tick_root(node: BTNodeResource, delta: float) -> int:
	var children := behavior_tree.get_children_of(node.id)
	if children.is_empty():
		return BTStatus.SUCCESS
	return _tick_node(children[0], delta)


func _tick_sequence(node: BTNodeResource, delta: float) -> int:
	var children := behavior_tree.get_children_of(node.id)
	var start_index: int = int(node_memory.get(node.id, 0))
	for index in range(start_index, children.size()):
		var child := children[index]
		var status := _tick_node(child, delta)
		if status == BTStatus.RUNNING:
			node_memory[node.id] = index
			return status
		if status == BTStatus.FAILURE:
			node_memory[node.id] = 0
			return status
	node_memory[node.id] = 0
	return BTStatus.SUCCESS


func _tick_selector(node: BTNodeResource, delta: float) -> int:
	var children := behavior_tree.get_children_of(node.id)
	for index in range(children.size()):
		var child := children[index]
		var status := _tick_node(child, delta)
		if status == BTStatus.RUNNING:
			node_memory[node.id] = index
			return status
		if status == BTStatus.SUCCESS:
			node_memory[node.id] = 0
			return status
	node_memory[node.id] = 0
	return BTStatus.FAILURE


func _tick_decorator(node: BTNodeResource, delta: float) -> int:
	var children := behavior_tree.get_children_of(node.id)
	if children.is_empty():
		return BTStatus.FAILURE
	var child := children[0]
	var mode := str(node.parameters.get("mode", "invert")).to_lower()
	match mode:
		"blackboard":
			if _tick_blackboard_decorator(node) == BTStatus.FAILURE:
				_reset_subtree(child)
				return BTStatus.FAILURE
			return _tick_node(child, delta)
		"cooldown":
			if _tick_cooldown_decorator(node, delta, child) == BTStatus.FAILURE:
				_reset_subtree(child)
				return BTStatus.FAILURE
			return _tick_node(child, delta)
		"time_limit":
			if _tick_time_limit_decorator(node, child, delta) == BTStatus.FAILURE:
				_reset_subtree(child)
				return BTStatus.FAILURE
			return _tick_node(child, delta)
	var status := _tick_node(child, delta)
	match mode:
		"repeat_forever":
			if status != BTStatus.RUNNING:
				_reset_subtree(child)
			return BTStatus.RUNNING
		"invert":
			if status == BTStatus.SUCCESS:
				return BTStatus.FAILURE
			if status == BTStatus.FAILURE:
				return BTStatus.SUCCESS
			return BTStatus.RUNNING
		"always_success", "force_success", "succeeder":
			return BTStatus.SUCCESS
		"always_failure", "force_failure", "failer":
			return BTStatus.FAILURE
		_:
			return status


func _tick_condition(node: BTNodeResource, delta: float) -> int:
	var condition_name := str(node.parameters.get("condition_name", ""))
	if not condition_name.is_empty():
		return _call_agent_status(condition_name, node, delta)
	var key := str(node.parameters.get("blackboard_key", ""))
	var expected: Variant = node.parameters.get("expected", true)
	return BTStatus.SUCCESS if blackboard.get(key) == expected else BTStatus.FAILURE


func _tick_action(node: BTNodeResource, delta: float) -> int:
	var action_name := str(node.parameters.get("action_name", ""))
	if action_name.is_empty():
		return BTStatus.SUCCESS
	return _call_agent_status(action_name, node, delta)


func _call_agent_status(method_name: String, node: BTNodeResource, delta: float) -> int:
	if agent == null or not agent.has_method(method_name):
		push_warning("BehaviorTreeComponent: actor has no method '%s' for node '%s'." % [method_name, node.title])
		return BTStatus.FAILURE
	return BTStatus.from_value(agent.call(method_name, blackboard, delta, node))


func get_active_path_text() -> String:
	var text := ""
	for index in range(active_path_titles.size()):
		if index > 0:
			text += " > "
		text += active_path_titles[index]
	return text


func get_debug_snapshot() -> Dictionary:
	return {
		"actor": agent.name if agent != null else name,
		"component": str(get_path()),
		"tree_name": behavior_tree.tree_name if behavior_tree != null else "",
		"tree_path": behavior_tree.resource_path if behavior_tree != null else "",
		"path_ids": active_path_ids.duplicate(),
		"path_titles": active_path_titles.duplicate(),
		"path_text": get_active_path_text(),
		"leaf_status": active_leaf_status,
		"leaf_status_text": status_to_text(active_leaf_status),
		"statuses": last_node_statuses.duplicate(),
		"blackboard": blackboard.duplicate(true),
	}


func _update_editor_debug_bridge(delta: float) -> void:
	if not editor_debug_bridge_enabled:
		return
	_debug_bridge_elapsed -= delta
	if _debug_bridge_elapsed > 0.0:
		return
	_debug_bridge_elapsed = editor_debug_bridge_interval
	var key := str(get_instance_id())
	var snapshot := get_debug_snapshot()
	snapshot["timestamp_msec"] = Time.get_ticks_msec()
	snapshot["timestamp_unix"] = Time.get_unix_time_from_system()
	_debug_bridge_snapshots[key] = snapshot
	var payload := {
		"version": 1,
		"timestamp_msec": Time.get_ticks_msec(),
		"timestamp_unix": Time.get_unix_time_from_system(),
		"components": _debug_bridge_snapshots.values(),
	}
	var bridge_dir := ProjectSettings.globalize_path(DEBUG_BRIDGE_PATH.get_base_dir())
	DirAccess.make_dir_recursive_absolute(bridge_dir)
	var file := FileAccess.open(DEBUG_BRIDGE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("BehaviorTreeComponent: could not write Live Debug bridge to %s." % DEBUG_BRIDGE_PATH)
		return
	file.store_string(JSON.stringify(payload))
	file.close()


func status_to_text(status: int) -> String:
	match status:
		BTStatus.SUCCESS:
			return "SUCCESS"
		BTStatus.FAILURE:
			return "FAILURE"
		BTStatus.RUNNING:
			return "RUNNING"
		_:
			return "UNKNOWN"


func _record_node_status(node: BTNodeResource, status: int) -> void:
	if not debug_enabled or node == null:
		return
	last_node_statuses[node.id] = status_to_text(status)


func _set_node_running(node: BTNodeResource, running: bool) -> void:
	if node == null:
		return
	var key := "node_running_%d" % node.id
	if running:
		node_memory[key] = true
	else:
		node_memory.erase(key)


func _is_node_running(node: BTNodeResource) -> bool:
	if node == null:
		return false
	return bool(node_memory.get("node_running_%d" % node.id, false))


func _capture_active_path(status: int, extra_node: BTNodeResource = null) -> void:
	if not debug_enabled:
		return
	active_leaf_status = status
	active_path_ids.clear()
	active_path_titles.clear()
	for stack_node in _debug_stack:
		if stack_node == null:
			continue
		active_path_ids.append(stack_node.id)
		active_path_titles.append(stack_node.title)
	if extra_node != null:
		active_path_ids.append(extra_node.id)
		active_path_titles.append(extra_node.title)


func _reset_subtree(node: BTNodeResource) -> void:
	if node == null:
		return
	node_memory.erase(node.id)
	_set_node_running(node, false)
	for child in behavior_tree.get_children_of(node.id):
		_reset_subtree(child)
