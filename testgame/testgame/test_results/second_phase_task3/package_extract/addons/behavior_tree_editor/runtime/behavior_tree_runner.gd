extends Node
class_name BehaviorTreeRunner

const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")
const BTNodeResource = preload("res://addons/behavior_tree_editor/bt_node_resource.gd")
const BTStatus = preload("res://addons/behavior_tree_editor/runtime/bt_status.gd")
const DEBUG_BRIDGE_PATH := "res://.godot/behavior_tree_runtime_debug.json"

signal tree_ticked(status: int)
signal node_ticked(node_id: int, status: int)
signal active_path_changed(path_ids: Array, path_titles: Array, leaf_status: int)

@export var behavior_tree: BTTreeResource:
	set(value):
		if _behavior_tree == value:
			return
		_behavior_tree = value
		_reset_execution_state()
		_apply_blackboard_defaults()
	get:
		return _behavior_tree
@export var agent_path: NodePath
@export var actor_path: NodePath:
	set(value):
		_actor_path = value
		agent_path = value
		_actor_override_enabled = false
		if is_inside_tree():
			_resolve_agent()
	get:
		return _actor_path
@export var tick_on_process: bool = true
@export var tick_on_physics: bool = false
@export var auto_start: bool = true
@export var debug_enabled: bool = true
@export var editor_debug_bridge_enabled: bool = true
@export var editor_debug_bridge_interval: float = 0.08
@export var use_runtime_cache: bool = true:
	set(value):
		use_runtime_cache = value
		_clear_runtime_cache()
@export var blackboard: Dictionary = {}

static var _debug_bridge_snapshots: Dictionary = {}

var agent: Node
var is_running := false
var node_memory: Dictionary = {}
var active_path_ids: Array[int] = []
var active_path_titles: Array[String] = []
var active_leaf_status: int = BTStatus.FAILURE
var last_node_statuses: Dictionary = {}
var last_failure_reasons: Dictionary = {}
var _debug_bridge_elapsed := 0.0
var _actor_path: NodePath = NodePath("")
var _behavior_tree: BTTreeResource
var _actor_override_enabled := false
var _debug_stack: Array[BTNodeResource] = []
var _cached_tree_instance_id := 0
var _cached_topology_signature: Array = []
var _node_cache: Dictionary = {}
var _children_cache: Dictionary = {}
var _decorator_cache: Dictionary = {}


func _ready() -> void:
	add_to_group("behavior_tree_components")
	_resolve_agent()
	_apply_blackboard_defaults()
	is_running = auto_start


func _exit_tree() -> void:
	_debug_bridge_snapshots.erase(str(get_instance_id()))


func _process(delta: float) -> void:
	if is_running and tick_on_process:
		tick(delta)


func _physics_process(delta: float) -> void:
	if is_running and tick_on_physics:
		tick(delta)


func start_tree() -> void:
	_resolve_agent()
	_apply_blackboard_defaults()
	is_running = true


func stop_tree() -> void:
	is_running = false


func restart_tree() -> void:
	stop_tree()
	node_memory.clear()
	start_tree()


func set_actor(actor: Node) -> void:
	agent = actor
	_actor_override_enabled = actor != null


func _resolve_agent() -> void:
	if _actor_override_enabled and is_instance_valid(agent):
		return
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
		last_failure_reasons.clear()
		_debug_stack.clear()
	_ensure_runtime_cache(true)
	var root := _find_runtime_node(behavior_tree.root_node_id)
	if root == null:
		tree_ticked.emit(BTStatus.FAILURE)
		return BTStatus.FAILURE
	var status := _tick_node(root, delta)
	tree_ticked.emit(status)
	if debug_enabled:
		active_path_changed.emit(active_path_ids, active_path_titles, status)
		_update_editor_debug_bridge(delta)
	return status


func _tick_node(node: BTNodeResource, delta: float) -> int:
	if node == null:
		return BTStatus.FAILURE
	if debug_enabled:
		_debug_stack.append(node)
	if not node.enabled:
		_record_failure_reason(node, "Node is disabled")
		_record_node_status(node, BTStatus.FAILURE)
		_capture_active_path(BTStatus.FAILURE)
		node_ticked.emit(node.id, BTStatus.FAILURE)
		if debug_enabled:
			_debug_stack.pop_back()
		return BTStatus.FAILURE
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
		BTNodeResource.TYPE_RANDOM_SELECTOR:
			status = _tick_random_selector(node, delta)
		BTNodeResource.TYPE_PARALLEL:
			status = _tick_parallel(node, delta)
		BTNodeResource.TYPE_REPEAT:
			status = _tick_repeat(node, delta)
		BTNodeResource.TYPE_DECORATOR:
			status = _tick_decorator(node, delta)
		BTNodeResource.TYPE_CONDITION:
			status = _tick_condition(node, delta)
		BTNodeResource.TYPE_ACTION:
			status = _tick_action(node, delta)
		BTNodeResource.TYPE_WAIT:
			status = _tick_wait(node, delta)
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
	for decorator in _runtime_decorators(node.id):
		if decorator == null or not decorator.enabled:
			continue
		var status := _tick_attached_decorator(decorator, node, delta)
		_record_node_status(decorator, status)
		if status == BTStatus.FAILURE:
			_record_failure_reason(node, _decorator_failure_reason(decorator))
			_record_failure_reason(decorator, _decorator_failure_reason(decorator))
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
	var passed := _compare_blackboard_value(key, op, expected)
	var invert := bool(decorator.parameters.get("invert", false))
	if passed == invert:
		_record_failure_reason(decorator, _decorator_failure_reason(decorator))
		return BTStatus.FAILURE
	return BTStatus.SUCCESS


func _compare_blackboard_value(key: String, op: String, expected: Variant) -> bool:
	var actual: Variant = blackboard.get(key)
	match op:
		"exists", "is_set":
			return blackboard.has(key) and actual != null
		"not_exists", "is_not_set":
			return not blackboard.has(key) or actual == null
		"is_true":
			return bool(actual) == true
		"is_false":
			return bool(actual) == false
		"equals", "==":
			return actual == expected
		"not_equals", "!=":
			return actual != expected
		"greater", ">":
			return float(actual) > float(expected)
		"less", "<":
			return float(actual) < float(expected)
		"greater_or_equal", ">=":
			return float(actual) >= float(expected)
		"less_or_equal", "<=":
			return float(actual) <= float(expected)
		_:
			return actual == expected


func _tick_cooldown_decorator(decorator: BTNodeResource, delta: float, owner: BTNodeResource = null) -> int:
	if owner != null and _is_node_running(owner):
		return BTStatus.SUCCESS
	var key := "decorator_cooldown_%d" % decorator.id
	var remaining: float = float(node_memory.get(key, 0.0))
	if remaining > 0.0:
		node_memory[key] = max(0.0, remaining - delta)
		_record_failure_reason(decorator, "Cooldown is active (%.2fs remaining)" % remaining)
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
	if elapsed > float(decorator.parameters.get("duration", 1.0)):
		_record_failure_reason(decorator, "Time limit exceeded")
		return BTStatus.FAILURE
	return BTStatus.SUCCESS


func _tick_root(node: BTNodeResource, delta: float) -> int:
	var children := _runtime_children(node.id)
	if children.is_empty():
		return BTStatus.SUCCESS
	return _tick_node(children[0], delta)


func _tick_sequence(node: BTNodeResource, delta: float) -> int:
	var children := _runtime_children(node.id)
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
	var children := _runtime_children(node.id)
	var reactive := bool(node.parameters.get("reactive", false))
	var active_key := "selector_active_%d" % node.id
	var previous_index := int(node_memory.get(active_key, -1))
	var start_index := 0 if reactive else clampi(int(node_memory.get(node.id, 0)), 0, max(0, children.size() - 1))
	for index in range(start_index, children.size()):
		var child := children[index]
		var status := _tick_node(child, delta)
		if status == BTStatus.RUNNING:
			if reactive and previous_index >= 0 and previous_index != index and previous_index < children.size():
				_reset_subtree(children[previous_index])
			node_memory[node.id] = index
			node_memory[active_key] = index
			return status
		if status == BTStatus.SUCCESS:
			if reactive and previous_index >= 0 and previous_index != index and previous_index < children.size():
				_reset_subtree(children[previous_index])
			node_memory[node.id] = 0
			node_memory.erase(active_key)
			return status
	if reactive and previous_index >= 0 and previous_index < children.size():
		_reset_subtree(children[previous_index])
	node_memory[node.id] = 0
	node_memory.erase(active_key)
	return BTStatus.FAILURE


func _tick_random_selector(node: BTNodeResource, delta: float) -> int:
	var children := _runtime_children(node.id)
	if children.is_empty():
		return BTStatus.FAILURE
	var order_key := "random_selector_order_%d" % node.id
	var index_key := "random_selector_index_%d" % node.id
	var order: Array = node_memory.get(order_key, [])
	if order.size() != children.size():
		order = _make_random_order(node, children.size())
		node_memory[order_key] = order
		node_memory[index_key] = 0
	var start_index := clampi(int(node_memory.get(index_key, 0)), 0, children.size() - 1)
	for order_index in range(start_index, order.size()):
		var child_index := int(order[order_index])
		var status := _tick_node(children[child_index], delta)
		if status == BTStatus.RUNNING:
			node_memory[index_key] = order_index
			return BTStatus.RUNNING
		if status == BTStatus.SUCCESS:
			node_memory.erase(order_key)
			node_memory.erase(index_key)
			return BTStatus.SUCCESS
	node_memory.erase(order_key)
	node_memory.erase(index_key)
	return BTStatus.FAILURE


func _make_random_order(node: BTNodeResource, child_count: int) -> Array[int]:
	var order: Array[int] = []
	for index in range(child_count):
		order.append(index)
	var rng := RandomNumberGenerator.new()
	var configured_seed := int(node.parameters.get("seed", -1))
	if configured_seed >= 0:
		rng.seed = configured_seed
	else:
		rng.randomize()
	for index in range(child_count - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var value := order[index]
		order[index] = order[swap_index]
		order[swap_index] = value
	return order


func _tick_parallel(node: BTNodeResource, delta: float) -> int:
	var children := _runtime_children(node.id)
	if children.is_empty():
		return BTStatus.SUCCESS
	var state_key := "parallel_states_%d" % node.id
	var child_states: Dictionary = node_memory.get(state_key, {}).duplicate()
	for child in children:
		var previous_status: int = int(child_states.get(child.id, BTStatus.RUNNING))
		if previous_status == BTStatus.SUCCESS or previous_status == BTStatus.FAILURE:
			continue
		child_states[child.id] = _tick_node(child, delta)
	node_memory[state_key] = child_states

	var success_count := 0
	var failure_count := 0
	for child in children:
		var child_status: int = int(child_states.get(child.id, BTStatus.RUNNING))
		if child_status == BTStatus.SUCCESS:
			success_count += 1
		elif child_status == BTStatus.FAILURE:
			failure_count += 1
	var success_policy := str(node.parameters.get("success_policy", "all")).to_lower()
	var failure_policy := str(node.parameters.get("failure_policy", "any")).to_lower()
	var failure_reached := failure_count == children.size() if failure_policy == "all" else failure_count > 0
	var success_reached := success_count > 0 if success_policy == "any" else success_count == children.size()
	if failure_reached:
		_finish_parallel(node, children, state_key)
		return BTStatus.FAILURE
	if success_reached:
		_finish_parallel(node, children, state_key)
		return BTStatus.SUCCESS
	if success_count + failure_count == children.size():
		_record_failure_reason(node, "Parallel policies cannot resolve mixed child results")
		_finish_parallel(node, children, state_key)
		return BTStatus.FAILURE
	return BTStatus.RUNNING


func _finish_parallel(node: BTNodeResource, children: Array[BTNodeResource], state_key: String) -> void:
	for child in children:
		if _is_node_running(child):
			_reset_subtree(child)
	node_memory.erase(state_key)


func _tick_repeat(node: BTNodeResource, delta: float) -> int:
	var children := _runtime_children(node.id)
	if children.is_empty():
		_record_failure_reason(node, "Repeat requires one child")
		return BTStatus.FAILURE
	var child := children[0]
	var status := _tick_node(child, delta)
	if status == BTStatus.RUNNING:
		return BTStatus.RUNNING
	if status == BTStatus.FAILURE:
		node_memory.erase("repeat_count_%d" % node.id)
		_reset_subtree(child)
		return BTStatus.FAILURE
	var count_key := "repeat_count_%d" % node.id
	var completed := int(node_memory.get(count_key, 0)) + 1
	var target_count := int(node.parameters.get("repeat_count", -1))
	_reset_subtree(child)
	if target_count > 0 and completed >= target_count:
		node_memory.erase(count_key)
		return BTStatus.SUCCESS
	node_memory[count_key] = completed
	return BTStatus.RUNNING


func _tick_wait(node: BTNodeResource, delta: float) -> int:
	var duration := maxf(0.0, float(node.parameters.get("duration", 1.0)))
	if duration <= 0.0:
		return BTStatus.SUCCESS
	var key := "wait_elapsed_%d" % node.id
	var elapsed := float(node_memory.get(key, 0.0)) + maxf(0.0, delta)
	if elapsed >= duration:
		node_memory.erase(key)
		return BTStatus.SUCCESS
	node_memory[key] = elapsed
	return BTStatus.RUNNING


func _tick_decorator(node: BTNodeResource, delta: float) -> int:
	var children := _runtime_children(node.id)
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
	var expected: Variant = node.parameters.get("expected", node.parameters.get("value", true))
	var op := str(node.parameters.get("operator", "equals")).to_lower()
	var actual: Variant = blackboard.get(key)
	if not _compare_blackboard_value(key, op, expected):
		_record_failure_reason(node, "%s %s %s failed (actual: %s)" % [key, op, str(expected), str(actual)])
		return BTStatus.FAILURE
	return BTStatus.SUCCESS


func _tick_action(node: BTNodeResource, delta: float) -> int:
	var action_name := str(node.parameters.get("action_name", ""))
	if action_name.is_empty():
		return BTStatus.SUCCESS
	return _call_agent_status(action_name, node, delta)


func _call_agent_status(method_name: String, node: BTNodeResource, delta: float) -> int:
	if agent == null or not agent.has_method(method_name):
		_record_failure_reason(node, "Actor method '%s' is missing" % method_name)
		push_warning("BehaviorTreeComponent: actor has no method '%s' for node '%s'." % [method_name, node.title])
		return BTStatus.FAILURE
	var status := BTStatus.from_value(agent.call(method_name, blackboard, delta, node))
	if status == BTStatus.FAILURE:
		_record_failure_reason(node, "Actor method '%s' returned FAILURE" % method_name)
	return status


func get_active_path_text() -> String:
	var text := ""
	for index in range(active_path_titles.size()):
		if index > 0:
			text += " > "
		text += active_path_titles[index]
	return text


func get_debug_snapshot() -> Dictionary:
	var schema_types: Dictionary = {}
	var schema_errors := PackedStringArray()
	if behavior_tree != null and behavior_tree.blackboard_schema != null:
		schema_types = behavior_tree.blackboard_schema.type_map()
		schema_errors = behavior_tree.blackboard_schema.validate_blackboard(blackboard)
	return {
		"actor": agent.name if agent != null else name,
		"component": str(get_path()) if is_inside_tree() else name,
		"tree_name": behavior_tree.tree_name if behavior_tree != null else "",
		"tree_path": behavior_tree.resource_path if behavior_tree != null else "",
		"path_ids": active_path_ids.duplicate(),
		"path_titles": active_path_titles.duplicate(),
		"path_text": get_active_path_text(),
		"leaf_status": active_leaf_status,
		"leaf_status_text": status_to_text(active_leaf_status),
		"statuses": last_node_statuses.duplicate(),
		"failure_reasons": last_failure_reasons.duplicate(),
		"blackboard": blackboard.duplicate(true),
		"blackboard_schema_types": schema_types,
		"blackboard_schema_errors": Array(schema_errors),
	}


func _apply_blackboard_defaults() -> void:
	if behavior_tree != null and behavior_tree.blackboard_schema != null:
		behavior_tree.blackboard_schema.apply_defaults(blackboard)


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
	var temp_bridge_path := "%s.%d.tmp" % [DEBUG_BRIDGE_PATH, OS.get_process_id()]
	var file := FileAccess.open(temp_bridge_path, FileAccess.WRITE)
	if file == null:
		push_warning("BehaviorTreeComponent: could not write Live Debug bridge to %s." % temp_bridge_path)
		return
	file.store_string(JSON.stringify(payload))
	file.close()
	var target_path := ProjectSettings.globalize_path(DEBUG_BRIDGE_PATH)
	var temp_path := ProjectSettings.globalize_path(temp_bridge_path)
	if FileAccess.file_exists(DEBUG_BRIDGE_PATH):
		DirAccess.remove_absolute(target_path)
	if DirAccess.rename_absolute(temp_path, target_path) != OK:
		push_warning("BehaviorTreeComponent: could not publish Live Debug bridge to %s." % DEBUG_BRIDGE_PATH)


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


func _record_failure_reason(node: BTNodeResource, reason: String) -> void:
	if not debug_enabled or node == null or reason.is_empty():
		return
	last_failure_reasons[node.id] = reason


func _decorator_failure_reason(decorator: BTNodeResource) -> String:
	var mode := str(decorator.parameters.get("mode", "blackboard")).to_lower()
	match mode:
		"blackboard":
			var key := str(decorator.parameters.get("blackboard_key", ""))
			var actual: Variant = blackboard.get(key)
			return "%s %s %s failed (actual: %s)" % [
				key,
				str(decorator.parameters.get("operator", "equals")),
				str(decorator.parameters.get("value", true)),
				str(actual)
			]
		"cooldown":
			return "Cooldown is active"
		"time_limit":
			return "Time limit exceeded"
		"force_failure", "always_failure", "failer":
			return "Decorator forces failure"
		_:
			return "%s failed" % decorator.title


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
	var candidate_size := _debug_stack.size() + (1 if extra_node != null else 0)
	var candidate_priority := _debug_status_priority(status)
	var current_priority := _debug_status_priority(active_leaf_status) if not active_path_ids.is_empty() else -1
	if candidate_priority < current_priority:
		return
	if candidate_priority == current_priority and candidate_size < active_path_ids.size():
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


func _debug_status_priority(status: int) -> int:
	match status:
		BTStatus.RUNNING:
			return 2
		BTStatus.SUCCESS:
			return 1
		_:
			return 0


func _reset_subtree(node: BTNodeResource) -> void:
	if node == null:
		return
	node_memory.erase(node.id)
	_set_node_running(node, false)
	for key in node_memory.keys():
		var text := str(key)
		if text.ends_with("_%d" % node.id) or text.ends_with("_%d_%d" % [node.id, node.id]):
			node_memory.erase(key)
	for child in _runtime_children(node.id):
		_reset_subtree(child)


func _reset_execution_state() -> void:
	node_memory.clear()
	active_path_ids.clear()
	active_path_titles.clear()
	active_leaf_status = BTStatus.FAILURE
	last_node_statuses.clear()
	last_failure_reasons.clear()
	_debug_stack.clear()
	_debug_bridge_elapsed = 0.0
	_clear_runtime_cache()


func _clear_runtime_cache() -> void:
	_cached_tree_instance_id = 0
	_cached_topology_signature.clear()
	_node_cache.clear()
	_children_cache.clear()
	_decorator_cache.clear()


func _ensure_runtime_cache(validate_topology := false) -> void:
	if not use_runtime_cache or behavior_tree == null:
		return
	var tree_id := behavior_tree.get_instance_id()
	if not validate_topology and _cached_tree_instance_id == tree_id and _node_cache.size() == behavior_tree.nodes.size():
		return
	var topology_signature := _runtime_topology_signature()
	if _cached_tree_instance_id == tree_id and _cached_topology_signature == topology_signature and _node_cache.size() == behavior_tree.nodes.size():
		return
	_clear_runtime_cache()
	_cached_tree_instance_id = tree_id
	_cached_topology_signature = topology_signature
	for node in behavior_tree.nodes:
		if node == null:
			continue
		_node_cache[node.id] = node
		var owner_id := node.decorator_parent_id
		if owner_id != -1:
			if not _decorator_cache.has(owner_id):
				_decorator_cache[owner_id] = []
			_decorator_cache[owner_id].append(node)
		elif node.parent_id != -1:
			if not _children_cache.has(node.parent_id):
				_children_cache[node.parent_id] = []
			_children_cache[node.parent_id].append(node)
	for parent_id in _children_cache:
		_children_cache[parent_id].sort_custom(_runtime_node_order)
	for owner_id in _decorator_cache:
		_decorator_cache[owner_id].sort_custom(_runtime_node_order)


func _runtime_topology_signature() -> Array:
	var signature: Array = [behavior_tree.root_node_id, behavior_tree.nodes.size()]
	for node in behavior_tree.nodes:
		if node == null:
			signature.append_array([-1, -1, -1, -1, 0.0, 0.0])
			continue
		signature.append_array([
			node.get_instance_id(), node.id, node.parent_id, node.decorator_parent_id,
			node.position.x, node.position.y,
		])
	return signature


func _runtime_node_order(left: BTNodeResource, right: BTNodeResource) -> bool:
	if is_equal_approx(left.position.x, right.position.x):
		return left.position.y < right.position.y
	return left.position.x < right.position.x


func _find_runtime_node(node_id: int) -> BTNodeResource:
	if not use_runtime_cache:
		return behavior_tree.find_node(node_id)
	_ensure_runtime_cache()
	return _node_cache.get(node_id) as BTNodeResource


func _runtime_children(parent_id: int) -> Array[BTNodeResource]:
	if not use_runtime_cache:
		return behavior_tree.get_children_of(parent_id)
	_ensure_runtime_cache()
	var result: Array[BTNodeResource] = []
	for node in _children_cache.get(parent_id, []):
		result.append(node)
	return result


func _runtime_decorators(owner_id: int) -> Array[BTNodeResource]:
	if not use_runtime_cache:
		return behavior_tree.get_decorators_of(owner_id)
	_ensure_runtime_cache()
	var result: Array[BTNodeResource] = []
	for node in _decorator_cache.get(owner_id, []):
		result.append(node)
	return result
