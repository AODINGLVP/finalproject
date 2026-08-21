extends SceneTree

const BTNodeResource = preload("res://addons/behavior_tree_editor/bt_node_resource.gd")
const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")
const BTBlackboardEntry = preload("res://addons/behavior_tree_editor/bt_blackboard_entry.gd")
const BTBlackboardSchema = preload("res://addons/behavior_tree_editor/bt_blackboard_schema.gd")
const BehaviorTreeRunner = preload("res://addons/behavior_tree_editor/runtime/behavior_tree_runner.gd")
const BTStatus = preload("res://addons/behavior_tree_editor/runtime/bt_status.gd")
const TestAgent = preload("res://tests/bt_test_agent.gd")

var passed := 0
var failed := 0


func _initialize() -> void:
	_run_all.call_deferred()


func _run_all() -> void:
	_test_status_conversion()
	_test_child_order_and_duplicate()
	_test_tree_validation()
	_test_tree_validation_edge_cases()
	_test_sequence_running_resume()
	_test_selector_running_resume()
	_test_reactive_selector_preemption()
	_test_parallel_composite()
	_test_random_selector()
	_test_repeat_and_wait()
	_test_blackboard_decorators()
	_test_timed_attached_decorators()
	_test_condition_methods()
	_test_structural_decorators()
	_test_runtime_edge_cases()
	_test_blackboard_schema()
	_test_runner_lifecycle_and_tree_swap()
	_test_runner_automatic_tick_modes()
	_test_multi_runner_debug_bridge()
	_test_actor_binding_and_debug_path()
	_test_resource_round_trip()
	_test_example_resources()
	print("BT_TEST_SUMMARY passed=%d failed=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)


func _test_status_conversion() -> void:
	_expect(BTStatus.from_value(true) == BTStatus.SUCCESS, "status bool true")
	_expect(BTStatus.from_value(false) == BTStatus.FAILURE, "status bool false")
	_expect(BTStatus.from_value("running") == BTStatus.RUNNING, "status string running")
	_expect(BTStatus.from_value(999) == BTStatus.FAILURE, "status rejects invalid int")


func _test_child_order_and_duplicate() -> void:
	var tree := BTTreeResource.new()
	var parent := _node(1, BTNodeResource.TYPE_SEQUENCE, -1, 100.0)
	var right := _node(2, BTNodeResource.TYPE_ACTION, 1, 400.0)
	var left := _node(3, BTNodeResource.TYPE_ACTION, 1, 100.0)
	tree.nodes = [parent, right, left]
	_expect(tree.get_children_of(1).map(func(item): return item.id) == [3, 2], "children execute left to right")
	var copy := tree.duplicate_tree()
	copy.find_node(2).title = "Changed"
	_expect(tree.find_node(2).title != copy.find_node(2).title, "duplicate tree is deep")


func _test_tree_validation() -> void:
	var tree := _base_tree(BTNodeResource.TYPE_SEQUENCE)
	_expect(tree.validate_tree().is_empty(), "valid tree passes validation")
	_expect(tree.can_accept_child(tree.find_node(2)), "sequence accepts multiple children")
	_expect(not tree.can_accept_child(tree.find_node(3)), "action rejects children")
	var invalid_child := _node(4, BTNodeResource.TYPE_ACTION, 3, 0.0)
	tree.nodes.append(invalid_child)
	_expect(_errors_contain(tree.validate_tree(), "cannot have children"), "leaf child is rejected")
	var bad_root := _node(5, BTNodeResource.TYPE_ACTION, 1, 900.0)
	tree.nodes.append(bad_root)
	_expect(_errors_contain(tree.validate_tree(), "only one child"), "root child limit is checked")
	var disconnected := _node(6, BTNodeResource.TYPE_ACTION, -1, 0.0)
	tree.nodes.append(disconnected)
	_expect(_errors_contain(tree.validate_tree(), "disconnected"), "disconnected nodes are reported")


func _test_tree_validation_edge_cases() -> void:
	var duplicate_ids := _base_tree(BTNodeResource.TYPE_SEQUENCE)
	duplicate_ids.nodes.append(_node(3, BTNodeResource.TYPE_ACTION, 2, 500.0))
	_expect(_errors_contain(duplicate_ids.validate_tree(), "Duplicate node id"), "validation rejects duplicate ids")

	var missing_root := _base_tree(BTNodeResource.TYPE_SEQUENCE)
	missing_root.root_node_id = -1
	_expect(_errors_contain(missing_root.validate_tree(), "no root"), "validation rejects missing root")
	missing_root.root_node_id = 999
	_expect(_errors_contain(missing_root.validate_tree(), "does not exist"), "validation rejects missing root resource")

	var wrong_root := _base_tree(BTNodeResource.TYPE_SEQUENCE)
	wrong_root.root_node_id = 2
	_expect(_errors_contain(wrong_root.validate_tree(), "not a Root"), "validation rejects wrong root type")
	wrong_root = _base_tree(BTNodeResource.TYPE_SEQUENCE)
	wrong_root.find_node(1).parent_id = 2
	_expect(_errors_contain(wrong_root.validate_tree(), "Root node cannot have a parent"), "validation rejects parented root")

	var missing_parent := _base_tree(BTNodeResource.TYPE_SEQUENCE)
	missing_parent.find_node(3).parent_id = 999
	_expect(_errors_contain(missing_parent.validate_tree(), "missing parent"), "validation rejects missing parent")
	var cyclic := _base_tree(BTNodeResource.TYPE_SEQUENCE)
	cyclic.find_node(2).parent_id = 3
	cyclic.find_node(3).node_type = BTNodeResource.TYPE_SEQUENCE
	cyclic.find_node(3).parent_id = 2
	_expect(_errors_contain(cyclic.validate_tree(), "Parent cycle"), "validation rejects parent cycles")

	var null_tree := _base_tree(BTNodeResource.TYPE_SEQUENCE)
	null_tree.nodes.append(null)
	_expect(_errors_contain(null_tree.validate_tree(), "null node"), "validation rejects null resources")

	var decorator_tree := _base_tree(BTNodeResource.TYPE_SEQUENCE)
	var missing_owner := _node(10, BTNodeResource.TYPE_DECORATOR, -1, 0.0)
	missing_owner.decorator_parent_id = 999
	decorator_tree.nodes.append(missing_owner)
	_expect(_errors_contain(decorator_tree.validate_tree(), "missing owner"), "validation rejects missing Decorator owner")
	missing_owner.decorator_parent_id = 11
	var decorator_owner := _node(11, BTNodeResource.TYPE_DECORATOR, 2, 0.0)
	decorator_tree.nodes.append(decorator_owner)
	_expect(_errors_contain(decorator_tree.validate_tree(), "cannot decorate decorator"), "validation rejects decorating a Decorator")
	missing_owner.decorator_parent_id = 3
	missing_owner.parameters = {"mode": "invert"}
	_expect(_errors_contain(decorator_tree.validate_tree(), "must be a structural decorator"), "validation rejects structural mode on attached Decorator")

	var deep_copy := _base_tree(BTNodeResource.TYPE_SEQUENCE)
	deep_copy.find_node(3).parameters = {"nested": {"values": [1, 2, 3]}}
	var copied := deep_copy.duplicate_tree()
	copied.find_node(3).parameters["nested"]["values"][0] = 99
	_expect(deep_copy.find_node(3).parameters["nested"]["values"][0] == 1, "duplicate tree owns nested parameter data")

	var tie_order := BTTreeResource.new()
	tie_order.nodes = [
		_node(1, BTNodeResource.TYPE_SEQUENCE, -1, 0.0),
		_node(2, BTNodeResource.TYPE_ACTION, 1, 100.0),
		_node(3, BTNodeResource.TYPE_ACTION, 1, 100.0),
	]
	tie_order.find_node(2).position.y = 300.0
	tie_order.find_node(3).position.y = 200.0
	_expect(tie_order.get_children_of(1).map(func(item): return item.id) == [3, 2], "child order uses vertical tie breaker")


func _test_sequence_running_resume() -> void:
	var tree := _base_tree(BTNodeResource.TYPE_SEQUENCE)
	var first := tree.find_node(3)
	first.parameters = {"action_name": "running_then_success"}
	var second := _node(4, BTNodeResource.TYPE_ACTION, 2, 500.0)
	second.parameters = {"action_name": "success_action"}
	tree.nodes.append(second)
	var context := _runner_for(tree)
	var runner: BehaviorTreeRunner = context.runner
	var agent: Node = context.agent
	_expect(runner.tick(0.1) == BTStatus.RUNNING, "sequence returns running")
	_expect(runner.tick(0.1) == BTStatus.SUCCESS, "sequence resumes and completes")
	_expect(agent.calls == ["running", "running", "success"], "sequence call order")
	_free_runner_context(context)


func _test_selector_running_resume() -> void:
	var tree := _base_tree(BTNodeResource.TYPE_SELECTOR)
	var first := tree.find_node(3)
	first.parameters = {"action_name": "failure_action"}
	var second := _node(4, BTNodeResource.TYPE_ACTION, 2, 500.0)
	second.parameters = {"action_name": "running_then_success"}
	tree.nodes.append(second)
	var context := _runner_for(tree)
	var runner: BehaviorTreeRunner = context.runner
	var agent: Node = context.agent
	_expect(runner.tick(0.1) == BTStatus.RUNNING, "selector returns running")
	_expect(runner.tick(0.1) == BTStatus.SUCCESS, "selector resumes running child")
	_expect(agent.calls == ["failure", "running", "running"], "selector does not repeat earlier branches")
	_free_runner_context(context)


func _test_reactive_selector_preemption() -> void:
	var tree := _base_tree(BTNodeResource.TYPE_SELECTOR)
	var selector := tree.find_node(2)
	selector.parameters = {"reactive": true}
	var gated := tree.find_node(3)
	gated.parameters = {"action_name": "gated_success"}
	var fallback := _node(4, BTNodeResource.TYPE_ACTION, 2, 500.0)
	fallback.parameters = {"action_name": "always_running"}
	tree.nodes.append(fallback)
	var context := _runner_for(tree)
	var runner: BehaviorTreeRunner = context.runner
	var agent: Node = context.agent
	runner.blackboard["gate"] = false
	_expect(runner.tick(0.1) == BTStatus.RUNNING, "reactive selector starts fallback branch")
	runner.blackboard["gate"] = true
	_expect(runner.tick(0.1) == BTStatus.SUCCESS, "reactive selector preempts running fallback")
	_expect(agent.calls == ["gated", "always_running", "gated"], "reactive selector reevaluates higher-priority branch")
	_free_runner_context(context)


func _test_parallel_composite() -> void:
	var tree := _base_tree(BTNodeResource.TYPE_PARALLEL)
	var parallel := tree.find_node(2)
	var running := tree.find_node(3)
	running.parameters = {"action_name": "running_then_success"}
	var immediate := _node(4, BTNodeResource.TYPE_ACTION, 2, 500.0)
	immediate.parameters = {"action_name": "success_action"}
	tree.nodes.append(immediate)
	_expect(tree.can_accept_child(parallel) and tree.validate_tree().is_empty(), "Parallel accepts multiple children and validates")
	var context := _runner_for(tree)
	var runner: BehaviorTreeRunner = context.runner
	var agent: Node = context.agent
	_expect(runner.tick(0.1) == BTStatus.RUNNING, "Parallel waits while one child is running")
	_expect(agent.calls == ["running", "success"], "Parallel ticks every unfinished child")
	_expect(runner.tick(0.1) == BTStatus.SUCCESS, "Parallel succeeds when all children succeed")
	_expect(agent.calls == ["running", "success", "running"], "Parallel remembers completed child terminal state")
	_expect(not runner.node_memory.has("parallel_states_2"), "Parallel clears completion memory")
	_free_runner_context(context)

	tree = _base_tree(BTNodeResource.TYPE_PARALLEL)
	parallel = tree.find_node(2)
	parallel.parameters = {"success_policy": "any", "failure_policy": "all"}
	tree.find_node(3).parameters = {"action_name": "failure_action"}
	immediate = _node(4, BTNodeResource.TYPE_ACTION, 2, 500.0)
	immediate.parameters = {"action_name": "success_action"}
	tree.nodes.append(immediate)
	context = _runner_for(tree)
	runner = context.runner
	_expect(runner.tick() == BTStatus.SUCCESS, "Parallel supports any-success and all-failure policies")
	_free_runner_context(context)

	tree = _base_tree(BTNodeResource.TYPE_PARALLEL)
	parallel = tree.find_node(2)
	tree.find_node(3).parameters = {"action_name": "always_running"}
	var failed := _node(4, BTNodeResource.TYPE_ACTION, 2, 500.0)
	failed.parameters = {"action_name": "failure_action"}
	tree.nodes.append(failed)
	context = _runner_for(tree)
	runner = context.runner
	_expect(runner.tick() == BTStatus.FAILURE, "Parallel default policy fails when any child fails")
	_expect(not runner.node_memory.has("node_running_3") and not runner.node_memory.has("parallel_states_2"), "Parallel failure interrupts and clears running children")
	_free_runner_context(context)

	var empty_parallel := _base_tree(BTNodeResource.TYPE_PARALLEL)
	empty_parallel.nodes.erase(empty_parallel.find_node(3))
	context = _runner_for(empty_parallel)
	_expect(context.runner.tick() == BTStatus.SUCCESS, "empty Parallel succeeds deterministically")
	_free_runner_context(context)


func _test_random_selector() -> void:
	var tree := _base_tree(BTNodeResource.TYPE_RANDOM_SELECTOR)
	var selector := tree.find_node(2)
	selector.parameters = {"seed": 42}
	for child in tree.get_children_of(2):
		child.parameters = {"action_name": "scripted_status", "result": BTStatus.FAILURE}
	var success := _node(4, BTNodeResource.TYPE_ACTION, 2, 500.0)
	success.title = "Success Choice"
	success.parameters = {"action_name": "scripted_status", "result": BTStatus.SUCCESS}
	var failure := _node(5, BTNodeResource.TYPE_ACTION, 2, 900.0)
	failure.title = "Failure Choice"
	failure.parameters = {"action_name": "scripted_status", "result": BTStatus.FAILURE}
	tree.nodes.append_array([success, failure])
	_expect(tree.can_accept_child(selector) and tree.validate_tree().is_empty(), "Random Selector accepts multiple children and validates")
	var first_context := _runner_for(tree)
	var first_runner: BehaviorTreeRunner = first_context.runner
	_expect(first_runner.tick() == BTStatus.SUCCESS, "Random Selector finds a successful randomized child")
	var first_order: Array[String] = first_context.agent.calls.duplicate()
	_free_runner_context(first_context)
	var second_context := _runner_for(tree)
	_expect(second_context.runner.tick() == BTStatus.SUCCESS and second_context.agent.calls == first_order, "Random Selector fixed seed is reproducible")
	_free_runner_context(second_context)

	tree = _base_tree(BTNodeResource.TYPE_RANDOM_SELECTOR)
	selector = tree.find_node(2)
	selector.parameters = {"seed": 7}
	var running := tree.find_node(3)
	running.title = "Running Choice"
	running.parameters = {"action_name": "scripted_status", "running_ticks": 1, "result": BTStatus.SUCCESS}
	first_context = _runner_for(tree)
	first_runner = first_context.runner
	_expect(first_runner.tick() == BTStatus.RUNNING and first_runner.tick() == BTStatus.SUCCESS, "Random Selector resumes the selected RUNNING child")
	_expect(first_context.agent.calls == ["Running Choice", "Running Choice"], "Random Selector does not reshuffle while running")
	_expect(not first_runner.node_memory.has("random_selector_order_2"), "Random Selector clears order after completion")
	_free_runner_context(first_context)


func _test_repeat_and_wait() -> void:
	var tree := BTTreeResource.new()
	var root_node := _node(1, BTNodeResource.TYPE_ROOT, -1, 0.0)
	var repeat := _node(2, BTNodeResource.TYPE_REPEAT, 1, 0.0)
	repeat.parameters = {"repeat_count": 3}
	var action := _node(3, BTNodeResource.TYPE_ACTION, 2, 0.0)
	action.parameters = {"action_name": "success_action"}
	tree.root_node_id = 1
	tree.nodes = [root_node, repeat]
	_expect(tree.can_accept_child(repeat), "empty Repeat accepts its first child")
	tree.nodes.append(action)
	_expect(not tree.can_accept_child(repeat) and tree.validate_tree().is_empty(), "Repeat accepts exactly one child and validates")
	var extra := _node(4, BTNodeResource.TYPE_ACTION, 2, 500.0)
	tree.nodes.append(extra)
	_expect(not tree.can_accept_child(repeat) and _errors_contain(tree.validate_tree(), "only one child"), "Repeat rejects a second child")
	tree.nodes.erase(extra)
	var context := _runner_for(tree)
	var runner: BehaviorTreeRunner = context.runner
	_expect(runner.tick() == BTStatus.RUNNING and runner.tick() == BTStatus.RUNNING and runner.tick() == BTStatus.SUCCESS, "finite Repeat completes after configured successes")
	_expect(context.agent.calls == ["success", "success", "success"], "Repeat resets and executes child for every iteration")
	_expect(not runner.node_memory.has("repeat_count_2"), "finite Repeat clears iteration memory")
	_free_runner_context(context)

	repeat.parameters = {"repeat_count": -1}
	context = _runner_for(tree)
	runner = context.runner
	_expect(runner.tick() == BTStatus.RUNNING and runner.tick() == BTStatus.RUNNING, "infinite Repeat remains RUNNING")
	runner.restart_tree()
	_expect(not runner.node_memory.has("repeat_count_2"), "runner restart clears Repeat memory")
	_free_runner_context(context)

	action.parameters = {"action_name": "failure_action"}
	repeat.parameters = {"repeat_count": 3}
	context = _runner_for(tree)
	_expect(context.runner.tick() == BTStatus.FAILURE, "Repeat propagates child failure")
	_free_runner_context(context)

	var wait_tree := _base_tree(BTNodeResource.TYPE_SEQUENCE)
	var wait := wait_tree.find_node(3)
	wait.node_type = BTNodeResource.TYPE_WAIT
	wait.parameters = {"duration": 0.5}
	context = _runner_for(wait_tree)
	runner = context.runner
	_expect(runner.tick(0.2) == BTStatus.RUNNING and runner.tick(0.2) == BTStatus.RUNNING, "Wait accumulates delta while duration remains")
	_expect(runner.tick(0.1) == BTStatus.SUCCESS, "Wait succeeds when duration elapses")
	_expect(not runner.node_memory.has("wait_elapsed_3"), "Wait clears elapsed memory after success")
	runner.tick(0.2)
	runner.restart_tree()
	_expect(not runner.node_memory.has("wait_elapsed_3"), "runner restart clears Wait memory")
	wait.parameters = {"duration": 0.0}
	_expect(runner.tick(0.0) == BTStatus.SUCCESS, "zero-duration Wait succeeds immediately")
	var invalid_child := _node(4, BTNodeResource.TYPE_ACTION, 3, 500.0)
	wait_tree.nodes.append(invalid_child)
	_expect(not wait_tree.can_accept_child(wait) and _errors_contain(wait_tree.validate_tree(), "cannot have children"), "Wait is validated as a leaf node")
	_free_runner_context(context)


func _test_blackboard_decorators() -> void:
	var tree := _base_tree(BTNodeResource.TYPE_SEQUENCE)
	tree.find_node(3).parameters = {"action_name": "success_action"}
	var decorator := _node(10, BTNodeResource.TYPE_DECORATOR, -1, 0.0)
	decorator.decorator_parent_id = 3
	decorator.parameters = {"mode": "blackboard", "blackboard_key": "health", "operator": ">=", "value": 2}
	tree.nodes.append(decorator)
	var context := _runner_for(tree)
	var runner: BehaviorTreeRunner = context.runner
	runner.blackboard["health"] = 1
	_expect(runner.tick() == BTStatus.FAILURE, "blackboard decorator blocks owner")
	_expect("health" in str(runner.get_debug_snapshot().get("failure_reasons", {}).get(3, "")), "blackboard failure reason is captured")
	runner.blackboard["health"] = 3
	_expect(runner.tick() == BTStatus.SUCCESS, "blackboard decorator allows owner")
	decorator.parameters["invert"] = true
	_expect(runner.tick() == BTStatus.FAILURE, "blackboard decorator invert")
	_free_runner_context(context)


func _test_timed_attached_decorators() -> void:
	var tree := _base_tree(BTNodeResource.TYPE_SEQUENCE)
	var action := tree.find_node(3)
	action.parameters = {"action_name": "success_action"}
	var cooldown := _node(10, BTNodeResource.TYPE_DECORATOR, -1, 0.0)
	cooldown.decorator_parent_id = 3
	cooldown.parameters = {"mode": "cooldown", "duration": 0.5}
	tree.nodes.append(cooldown)
	var context := _runner_for(tree)
	var runner: BehaviorTreeRunner = context.runner
	_expect(runner.tick(0.1) == BTStatus.SUCCESS, "cooldown decorator allows first execution")
	_expect(runner.tick(0.2) == BTStatus.FAILURE, "cooldown decorator blocks early retry")
	_expect("Cooldown" in str(runner.get_debug_snapshot().get("failure_reasons", {}).get(3, "")), "cooldown failure reason is captured")
	runner.tick(0.3)
	_expect(runner.tick(0.0) == BTStatus.SUCCESS, "cooldown decorator allows retry after duration")
	cooldown.parameters = {"mode": "time_limit", "duration": 0.15}
	action.parameters = {"action_name": "always_running"}
	runner.node_memory.clear()
	_expect(runner.tick(0.1) == BTStatus.RUNNING, "time limit allows running action initially")
	_expect(runner.tick(0.1) == BTStatus.FAILURE, "time limit aborts overdue action")
	_expect("Time limit" in str(runner.get_debug_snapshot().get("failure_reasons", {}).get(3, "")), "time-limit failure reason is captured")
	_free_runner_context(context)


func _test_condition_methods() -> void:
	var tree := _base_tree(BTNodeResource.TYPE_SEQUENCE)
	var condition := tree.find_node(3)
	condition.node_type = BTNodeResource.TYPE_CONDITION
	condition.parameters = {"condition_name": "condition_true"}
	var context := _runner_for(tree)
	var runner: BehaviorTreeRunner = context.runner
	_expect(runner.tick() == BTStatus.SUCCESS, "condition can call actor method")
	condition.parameters = {"condition_name": "condition_false"}
	_expect(runner.tick() == BTStatus.FAILURE, "false actor condition fails")
	_expect("condition_false" in str(runner.get_debug_snapshot().get("failure_reasons", {}).get(3, "")), "condition failure reason is captured")
	condition.node_type = BTNodeResource.TYPE_ACTION
	condition.parameters = {"action_name": "failure_action"}
	_expect(runner.tick() == BTStatus.FAILURE, "failed actor action fails")
	_expect("failure_action" in str(runner.get_debug_snapshot().get("failure_reasons", {}).get(3, "")), "action failure reason is captured")
	_free_runner_context(context)


func _test_structural_decorators() -> void:
	var tree := BTTreeResource.new()
	var root := _node(1, BTNodeResource.TYPE_ROOT, -1, 0.0)
	var invert := _node(2, BTNodeResource.TYPE_DECORATOR, 1, 0.0)
	invert.parameters = {"mode": "invert"}
	var action := _node(3, BTNodeResource.TYPE_ACTION, 2, 0.0)
	action.parameters = {"action_name": "failure_action"}
	tree.root_node_id = 1
	tree.nodes = [root, invert, action]
	var context := _runner_for(tree)
	var runner: BehaviorTreeRunner = context.runner
	_expect(runner.tick() == BTStatus.SUCCESS, "invert decorator changes failure to success")
	invert.parameters = {"mode": "repeat_forever"}
	_expect(runner.tick() == BTStatus.RUNNING, "repeat decorator keeps tree running")
	invert.parameters = {"mode": "always_success"}
	_expect(runner.tick() == BTStatus.SUCCESS, "structural Decorator can force success")
	invert.parameters = {"mode": "always_failure"}
	action.parameters = {"action_name": "success_action"}
	_expect(runner.tick() == BTStatus.FAILURE, "structural Decorator can force failure")
	_free_runner_context(context)


func _test_runtime_edge_cases() -> void:
	var empty_root_tree := BTTreeResource.new()
	empty_root_tree.root_node_id = 1
	empty_root_tree.nodes = [_node(1, BTNodeResource.TYPE_ROOT, -1, 0.0)]
	var context := _runner_for(empty_root_tree)
	_expect(context.runner.tick() == BTStatus.SUCCESS, "empty root executes deterministically")
	_free_runner_context(context)

	var empty_sequence := _base_tree(BTNodeResource.TYPE_SEQUENCE)
	empty_sequence.nodes.erase(empty_sequence.find_node(3))
	context = _runner_for(empty_sequence)
	_expect(context.runner.tick() == BTStatus.SUCCESS, "empty Sequence succeeds")
	_free_runner_context(context)

	var empty_selector := _base_tree(BTNodeResource.TYPE_SELECTOR)
	empty_selector.nodes.erase(empty_selector.find_node(3))
	context = _runner_for(empty_selector)
	_expect(context.runner.tick() == BTStatus.FAILURE, "empty Selector fails")
	_free_runner_context(context)

	var disabled_tree := _base_tree(BTNodeResource.TYPE_SEQUENCE)
	disabled_tree.find_node(3).enabled = false
	context = _runner_for(disabled_tree)
	_expect(context.runner.tick() == BTStatus.FAILURE, "disabled node fails")
	var disabled_snapshot: Dictionary = context.runner.get_debug_snapshot()
	_expect("disabled" in str(disabled_snapshot.get("failure_reasons", {}).get(3, "")).to_lower(), "disabled node reports failure reason")
	_expect(disabled_snapshot.get("path_ids", []) == [1, 2, 3], "disabled node remains visible in active debug path")
	_free_runner_context(context)

	var missing_method_tree := _base_tree(BTNodeResource.TYPE_SEQUENCE)
	missing_method_tree.find_node(3).parameters = {"action_name": "method_does_not_exist"}
	context = _runner_for(missing_method_tree)
	_expect(context.runner.tick() == BTStatus.FAILURE, "missing actor method fails safely")
	_expect("missing" in str(context.runner.get_debug_snapshot().get("failure_reasons", {}).get(3, "")).to_lower(), "missing actor method reports reason")
	_free_runner_context(context)

	var condition_tree := _base_tree(BTNodeResource.TYPE_SEQUENCE)
	var condition := condition_tree.find_node(3)
	condition.node_type = BTNodeResource.TYPE_CONDITION
	condition.parameters = {"blackboard_key": "ready", "expected": true}
	context = _runner_for(condition_tree)
	context.runner.blackboard["ready"] = false
	_expect(context.runner.tick() == BTStatus.FAILURE, "blackboard Condition rejects unexpected value")
	context.runner.blackboard["ready"] = true
	_expect(context.runner.tick() == BTStatus.SUCCESS, "blackboard Condition accepts expected value")
	_free_runner_context(context)

	var condition_operator_tree := _base_tree(BTNodeResource.TYPE_SEQUENCE)
	var operator_condition := condition_operator_tree.find_node(3)
	operator_condition.node_type = BTNodeResource.TYPE_CONDITION
	context = _runner_for(condition_operator_tree)
	var condition_cases := [
		[">", 8, 5, true], ["not_equals", "alert", "idle", true],
		["exists", Vector2.ONE, null, true], ["<", 9, 3, false],
	]
	for item in condition_cases:
		operator_condition.parameters = {"blackboard_key": "condition_value", "operator": item[0], "expected": item[2]}
		context.runner.blackboard["condition_value"] = item[1]
		var expected_status: int = BTStatus.SUCCESS if item[3] else BTStatus.FAILURE
		_expect(context.runner.tick() == expected_status, "blackboard Condition operator %s" % item[0])
	_free_runner_context(context)

	var operator_tree := _base_tree(BTNodeResource.TYPE_SEQUENCE)
	operator_tree.find_node(3).parameters = {"action_name": "success_action"}
	var decorator := _node(10, BTNodeResource.TYPE_DECORATOR, -1, 0.0)
	decorator.decorator_parent_id = 3
	operator_tree.nodes.append(decorator)
	context = _runner_for(operator_tree)
	var cases := [
		["exists", 7, 0, true], ["not_exists", null, 0, true],
		["is_true", true, false, true], ["is_false", false, true, true],
		["equals", 4, 4, true], ["not_equals", 4, 5, true],
		[">", 5, 4, true], ["<", 3, 4, true], [">=", 4, 4, true], ["<=", 4, 4, true],
	]
	for item in cases:
		decorator.parameters = {"mode": "blackboard", "blackboard_key": "value", "operator": item[0], "value": item[2]}
		if item[0] == "not_exists":
			context.runner.blackboard.erase("value")
		else:
			context.runner.blackboard["value"] = item[1]
		_expect(context.runner.tick() == BTStatus.SUCCESS, "blackboard Decorator operator %s" % item[0])
	_free_runner_context(context)


func _test_runner_lifecycle_and_tree_swap() -> void:
	var first_tree := _base_tree(BTNodeResource.TYPE_SEQUENCE)
	first_tree.find_node(3).parameters = {"action_name": "running_then_success"}
	var second := _node(4, BTNodeResource.TYPE_ACTION, 2, 500.0)
	second.parameters = {"action_name": "success_action"}
	first_tree.nodes.append(second)
	var context := _runner_for(first_tree)
	var runner: BehaviorTreeRunner = context.runner
	runner.start_tree()
	_expect(runner.is_running, "runner starts")
	runner.stop_tree()
	_expect(not runner.is_running, "runner stops")
	runner.start_tree()
	_expect(runner.tick() == BTStatus.RUNNING and not runner.node_memory.is_empty(), "runner stores running state")
	runner.restart_tree()
	_expect(runner.is_running and runner.node_memory.is_empty(), "runner restart clears state")

	var replacement := _base_tree(BTNodeResource.TYPE_SEQUENCE)
	replacement.find_node(3).parameters = {"action_name": "success_action"}
	runner.node_memory[2] = 7
	runner.behavior_tree = replacement
	_expect(runner.node_memory.is_empty(), "changing behavior tree clears previous execution memory")
	_expect(runner.tick() == BTStatus.SUCCESS, "replacement tree starts from its first child")
	_free_runner_context(context)


func _test_blackboard_schema() -> void:
	var schema := BTBlackboardSchema.new()
	schema.entries = [
		_blackboard_entry("ready", "Bool", true),
		_blackboard_entry("health", "Int", 100),
		_blackboard_entry("speed", "Float", 2.5),
		_blackboard_entry("state", "String", "idle"),
		_blackboard_entry("target", "Vector2", Vector2(10.0, 20.0)),
	]
	_expect(schema.validate_schema().is_empty(), "blackboard schema accepts supported typed entries")
	var board := {"health": 75, "temporary_timer": 0.2}
	schema.apply_defaults(board)
	_expect(board.get("ready") == true and board.get("health") == 75 and is_equal_approx(float(board.get("speed")), 2.5), "blackboard schema applies defaults without overwriting existing values")
	_expect(board.get("state") == "idle" and board.get("target") == Vector2(10.0, 20.0), "blackboard schema supports String and Vector2 defaults")
	_expect(schema.validate_blackboard(board).is_empty(), "blackboard schema allows dynamic runtime keys by default")
	board["health"] = "invalid"
	_expect(_errors_contain(schema.validate_blackboard(board), "expected Int"), "blackboard schema reports declared-key type mismatch")
	board["health"] = 75
	schema.allow_dynamic_keys = false
	_expect(_errors_contain(schema.validate_blackboard(board), "not declared"), "strict blackboard schema rejects undeclared keys")
	schema.allow_dynamic_keys = true

	var duplicate_schema := BTBlackboardSchema.new()
	duplicate_schema.entries = [_blackboard_entry("ready", "Bool", false), _blackboard_entry("ready", "Bool", true)]
	_expect(_errors_contain(duplicate_schema.validate_schema(), "duplicate key"), "blackboard schema rejects duplicate keys")

	var tree := _base_tree(BTNodeResource.TYPE_SEQUENCE)
	tree.blackboard_schema = schema
	var context := _runner_for(tree)
	var runner: BehaviorTreeRunner = context.runner
	_expect(runner.blackboard.get("ready") == true and runner.blackboard.get("health") == 100, "runner initializes blackboard from tree schema")
	runner.blackboard["health"] = "wrong"
	var snapshot := runner.get_debug_snapshot()
	_expect(snapshot.get("blackboard_schema_types", {}).get("health") == "Int", "Live Debug snapshot exposes schema types")
	_expect(not snapshot.get("blackboard_schema_errors", []).is_empty(), "Live Debug snapshot exposes schema validation errors")
	_free_runner_context(context)

	var copy := tree.duplicate_tree()
	copy.blackboard_schema.entries[0].default_value = false
	_expect(tree.blackboard_schema.entries[0].default_value == true, "tree duplicate owns independent blackboard schema entries")

	var path := "user://bt_blackboard_schema_round_trip.tres"
	var save_error := ResourceSaver.save(tree, path)
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as BTTreeResource
	_expect(save_error == OK and loaded != null and loaded.blackboard_schema != null, "blackboard schema saves with behavior tree")
	_expect(loaded != null and loaded.blackboard_schema.entries.size() == 5 and loaded.blackboard_schema.find_entry("target").default_value == Vector2(10.0, 20.0), "blackboard schema data survives resource round trip")

	var reference_tree := _base_tree(BTNodeResource.TYPE_SEQUENCE)
	var reference_condition := reference_tree.find_node(3)
	reference_condition.node_type = BTNodeResource.TYPE_CONDITION
	reference_condition.title = "Ready Check"
	reference_condition.parameters = {"blackboard_key": "ready", "operator": "is_true", "expected": true}
	reference_tree.blackboard_schema = schema.duplicate_schema()
	reference_tree.blackboard_schema.allow_dynamic_keys = false
	var references := reference_tree.get_blackboard_references()
	_expect(references.has("ready") and references["ready"].size() == 1 and references["ready"][0].get("id") == 3, "tree indexes Blackboard references with node locations")
	_expect(reference_tree.get_unused_blackboard_keys().has("health") and not reference_tree.get_unused_blackboard_keys().has("ready"), "tree reports declared but unused Blackboard keys")
	_expect(reference_tree.validate_blackboard_references().is_empty(), "strict schema accepts declared Blackboard references")
	reference_condition.parameters["blackboard_key"] = "missing_key"
	_expect(_errors_contain(reference_tree.validate_tree(), "undeclared Blackboard key"), "strict schema rejects undeclared node Blackboard references")
	reference_tree.blackboard_schema.allow_dynamic_keys = true
	_expect(not _errors_contain(reference_tree.validate_tree(), "undeclared Blackboard key"), "dynamic schema preserves custom Blackboard key compatibility")
	reference_condition.parameters["blackboard_key"] = ""
	_expect(_errors_contain(reference_tree.validate_tree(), "requires a Blackboard key"), "empty Blackboard references fail validation in every schema mode")


func _test_runner_automatic_tick_modes() -> void:
	var tree := _base_tree(BTNodeResource.TYPE_SEQUENCE)
	tree.find_node(3).parameters = {"action_name": "success_action"}
	var context := _runner_for(tree)
	var runner: BehaviorTreeRunner = context.runner
	var counter := {"ticks": 0}
	runner.tree_ticked.connect(func(_status): counter["ticks"] += 1)
	runner.is_running = true
	runner.tick_on_process = true
	runner.tick_on_physics = false
	runner._process(0.1)
	_expect(counter["ticks"] == 1, "process tick mode executes once")
	runner.tick_on_process = false
	runner.tick_on_physics = true
	runner._physics_process(0.1)
	_expect(counter["ticks"] == 2, "physics tick mode executes once")
	runner.stop_tree()
	runner._process(0.1)
	runner._physics_process(0.1)
	_expect(counter["ticks"] == 2, "stopped runner ignores automatic tick modes")
	_free_runner_context(context)


func _test_multi_runner_debug_bridge() -> void:
	var bridge_path := BehaviorTreeRunner.DEBUG_BRIDGE_PATH
	if FileAccess.file_exists(bridge_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(bridge_path))
	var tree_a := _base_tree(BTNodeResource.TYPE_SEQUENCE)
	tree_a.tree_name = "Bridge A"
	tree_a.find_node(3).parameters = {"action_name": "success_action"}
	var tree_b := tree_a.duplicate_tree()
	tree_b.tree_name = "Bridge B"
	var context_a := _runner_for(tree_a)
	var context_b := _runner_for(tree_b)
	context_a.runner.editor_debug_bridge_enabled = true
	context_b.runner.editor_debug_bridge_enabled = true
	context_a.runner.tick(0.1)
	context_b.runner.tick(0.1)
	var file := FileAccess.open(bridge_path, FileAccess.READ)
	var parser := JSON.new()
	var parse_ok := file != null
	if file != null:
		parse_ok = parser.parse(file.get_as_text()) == OK
		file.close()
	var components: Array = parser.data.get("components", []) if parse_ok and typeof(parser.data) == TYPE_DICTIONARY else []
	_expect(parse_ok and components.size() >= 2, "multiple runners publish one valid Live Debug payload")
	var process_temp_path := "%s.%d.tmp" % [bridge_path, OS.get_process_id()]
	_expect(not FileAccess.file_exists(process_temp_path), "Live Debug atomic publish leaves no process temp file")
	_free_runner_context(context_a)
	_free_runner_context(context_b)
	if FileAccess.file_exists(bridge_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(bridge_path))


func _test_actor_binding_and_debug_path() -> void:
	var tree := _base_tree(BTNodeResource.TYPE_SEQUENCE)
	tree.tree_name = "Debug Tree"
	tree.find_node(3).title = "Bound Action"
	tree.find_node(3).parameters = {"action_name": "success_action"}
	var context := _runner_for(tree)
	var runner: BehaviorTreeRunner = context.runner
	runner.set_actor(context.agent)
	_expect(runner.tick() == BTStatus.SUCCESS, "actor method binding")
	_expect(runner.active_path_ids == [1, 2, 3], "debug active path ids")
	_expect(runner.get_active_path_text() == "Root > Composite > Bound Action", "debug active path text")
	var snapshot := runner.get_debug_snapshot()
	_expect(snapshot.get("leaf_status_text") == "SUCCESS", "debug snapshot status")
	_free_runner_context(context)


func _test_resource_round_trip() -> void:
	var tree := _base_tree(BTNodeResource.TYPE_SEQUENCE)
	tree.tree_name = "Round Trip"
	var path := "user://bt_round_trip_test.tres"
	var save_error := ResourceSaver.save(tree, path)
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_expect(save_error == OK and loaded is BTTreeResource, "resource save and load")
	if loaded is BTTreeResource:
		_expect(loaded.tree_name == tree.tree_name and loaded.nodes.size() == tree.nodes.size(), "resource data round trip")


func _test_example_resources() -> void:
	for path in [
		"res://behavior_trees/enemy_patrol_combat.tres",
		"res://behavior_trees/demo_npc_tree.tres",
		"res://behavior_trees/example_guard_combat_tree.tres",
		"res://behavior_trees/complex_guard_validation_tree.tres"
	]:
		var tree := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		_expect(tree is BTTreeResource, "load example %s" % path.get_file())
		if tree is BTTreeResource:
			_expect(tree.validate_tree().is_empty(), "validate example %s" % path.get_file())


func _base_tree(composite_type: String) -> BTTreeResource:
	var tree := BTTreeResource.new()
	var root := _node(1, BTNodeResource.TYPE_ROOT, -1, 0.0)
	root.title = "Root"
	var composite := _node(2, composite_type, 1, 0.0)
	composite.title = "Composite"
	var action := _node(3, BTNodeResource.TYPE_ACTION, 2, 0.0)
	action.title = "Action"
	tree.root_node_id = 1
	tree.nodes = [root, composite, action]
	return tree


func _node(id: int, type_name: String, parent_id: int, x: float) -> BTNodeResource:
	var node := BTNodeResource.new()
	node.id = id
	node.node_type = type_name
	node.title = type_name
	node.parent_id = parent_id
	node.position = Vector2(x, float(id) * 100.0)
	return node


func _blackboard_entry(key: String, value_type: String, default_value: Variant) -> BTBlackboardEntry:
	var entry := BTBlackboardEntry.new()
	entry.key = key
	entry.value_type = value_type
	entry.default_value = default_value
	return entry


func _runner_for(tree: BTTreeResource) -> Dictionary:
	var host := Node.new()
	var agent := TestAgent.new()
	var runner := BehaviorTreeRunner.new()
	host.add_child(agent)
	host.add_child(runner)
	root.add_child(host)
	runner.behavior_tree = tree
	runner.tick_on_process = false
	runner.tick_on_physics = false
	runner.editor_debug_bridge_enabled = false
	runner.set_actor(agent)
	return {"host": host, "agent": agent, "runner": runner}


func _free_runner_context(context: Dictionary) -> void:
	(context.host as Node).free()


func _errors_contain(errors: PackedStringArray, text: String) -> bool:
	for error in errors:
		if text in error:
			return true
	return false


func _expect(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		printerr("FAIL: %s" % label)
