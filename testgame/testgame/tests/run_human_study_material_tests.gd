extends SceneTree

const BTNodeResource = preload("res://addons/behavior_tree_editor/bt_node_resource.gd")
const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")
const HumanStudyDebug = preload("res://tests/prepare_human_study_live_debug.gd")

var assertions := 0
var failures := 0


func _initialize() -> void:
	var fixture := HumanStudyDebug.load_fixture()
	_expect(not fixture.is_empty(), "241-node human-study fixture loads")
	var tree_path := str(fixture.get("formal_tree", ""))
	var tree := ResourceLoader.load(tree_path, "", ResourceLoader.CACHE_MODE_IGNORE) as BTTreeResource
	_expect(tree != null, "formal human-study tree loads")
	if tree == null:
		_finish()
		return
	_expect(tree.nodes.size() == int(fixture.get("resource_nodes", -1)), "formal study tree has the frozen resource-node count")
	_expect(tree.validate_tree().is_empty(), "formal study tree remains structurally valid")
	var methods: Array = fixture.get("methods", [])
	var tasks: Array = fixture.get("tasks", [])
	_expect(methods == ["Baseline", "Compact", "Collapse", "Fisheye", "Search", "Minimap"], "study compares the six pre-registered display conditions")
	_expect(tasks == ["Locate Action", "Trace Active Path", "Edit Decorator"], "study uses three game-development tasks")
	_validate_trace_targets(tree, fixture.get("trace_targets", []))
	_validate_decorator_targets(tree, fixture.get("decorator_targets", []))
	_validate_counterbalance(fixture)
	_finish()


func _validate_trace_targets(tree: BTTreeResource, targets: Array) -> void:
	_expect(targets.size() == 6, "six matched locate/trace targets are defined")
	var target_ids := {}
	var target_keys := {}
	for target_variant in targets:
		var target: Dictionary = target_variant
		var node_id := int(target.get("id", -1))
		var node := tree.find_node(node_id)
		_expect(node != null and node.node_type == BTNodeResource.TYPE_ACTION, "%s resolves to a real Action" % target.get("key", "unknown"))
		_expect(node != null and node.title == str(target.get("title", "")), "%s title is frozen" % target.get("key", "unknown"))
		var path_ids: Array = target.get("path_ids", [])
		var path_titles: Array = target.get("path_titles", [])
		_expect(path_ids.size() == 7 and path_titles.size() == 7, "%s uses a matched seven-node decision path" % target.get("key", "unknown"))
		_expect(_path_matches_tree(tree, path_ids, path_titles), "%s path follows real parent links" % target.get("key", "unknown"))
		_expect(int(path_ids.back()) == node_id, "%s path ends at its assigned Action" % target.get("key", "unknown"))
		target_ids[node_id] = true
		target_keys[str(target.get("key", ""))] = true
	_expect(target_ids.size() == 6 and target_keys.size() == 6, "locate/trace targets are unique")


func _validate_decorator_targets(tree: BTTreeResource, targets: Array) -> void:
	_expect(targets.size() == 6, "six matched Decorator-edit targets are defined")
	var target_ids := {}
	for target_variant in targets:
		var target: Dictionary = target_variant
		var decorator := tree.find_node(int(target.get("id", -1)))
		var owner := tree.find_node(int(target.get("owner_id", -1)))
		_expect(decorator != null and decorator.node_type == BTNodeResource.TYPE_DECORATOR, "%s resolves to a real Decorator" % target.get("key", "unknown"))
		_expect(owner != null and owner.node_type == BTNodeResource.TYPE_ACTION, "%s Decorator is attached to a real Action" % target.get("key", "unknown"))
		_expect(decorator != null and decorator.decorator_parent_id == owner.id, "%s Decorator ownership is frozen" % target.get("key", "unknown"))
		_expect(decorator != null and str(decorator.parameters.get("mode", "")) == str(target.get("mode", "")), "%s Decorator mode is frozen" % target.get("key", "unknown"))
		_expect(decorator != null and is_equal_approx(float(decorator.parameters.get("duration", -1.0)), float(target.get("start_duration", -2.0))), "%s starting duration is frozen" % target.get("key", "unknown"))
		_expect(is_equal_approx(float(target.get("target_duration", 0.0)) - float(target.get("start_duration", 0.0)), 0.1), "%s edit changes duration by exactly 0.10 seconds" % target.get("key", "unknown"))
		target_ids[int(target.get("id", -1))] = true
	_expect(target_ids.size() == 6, "Decorator-edit targets are unique")


func _validate_counterbalance(fixture: Dictionary) -> void:
	var methods: Array = fixture.get("methods", [])
	var method_orders: Array = fixture.get("method_orders", [])
	var task_orders: Array = fixture.get("task_orders", [])
	var participant_count := int(fixture.get("participants", 0))
	_expect(participant_count == 12, "study plans twelve participants")
	_expect(method_orders.size() == 6, "six balanced method orders are defined")
	for order_variant in method_orders:
		var order: Array = order_variant
		_expect(_same_members(order, methods), "every method order is a complete permutation")
	_expect(task_orders.size() == 3, "three rotated task orders are defined")
	for order_variant in task_orders:
		var order: Array = order_variant
		_expect(_same_members(order, fixture.get("tasks", [])), "every task order is a complete permutation")
	var pair_counts := {}
	var method_order_counts := {}
	var task_order_counts := {}
	for participant_index in range(participant_count):
		var method_order_index := participant_index % method_orders.size()
		var task_order_index := participant_index % task_orders.size()
		method_order_counts[method_order_index] = int(method_order_counts.get(method_order_index, 0)) + 1
		task_order_counts[task_order_index] = int(task_order_counts.get(task_order_index, 0)) + 1
		for method_index in range(methods.size()):
			var target_index := (method_index + participant_index) % methods.size()
			var pair_key := "%s:%d" % [str(methods[method_index]), target_index]
			pair_counts[pair_key] = int(pair_counts.get(pair_key, 0)) + 1
	var pairs_balanced := pair_counts.size() == methods.size() * methods.size()
	for count_variant in pair_counts.values():
		pairs_balanced = pairs_balanced and int(count_variant) == 2
	_expect(pairs_balanced, "every method-target pairing occurs exactly twice")
	_expect(method_order_counts.values().all(func(count: Variant) -> bool: return int(count) == 2), "every method order is assigned twice")
	_expect(task_order_counts.values().all(func(count: Variant) -> bool: return int(count) == 4), "every task order is assigned four times")


func _path_matches_tree(tree: BTTreeResource, path_ids: Array, path_titles: Array) -> bool:
	for index in range(path_ids.size()):
		var node := tree.find_node(int(path_ids[index]))
		if node == null or node.title != str(path_titles[index]):
			return false
		if index == 0:
			if node.id != tree.root_node_id:
				return false
		elif node.parent_id != int(path_ids[index - 1]):
			return false
	return true


func _same_members(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	for value in right:
		if left.count(value) != 1:
			return false
	return true


func _expect(condition: bool, label: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		printerr("FAIL: %s" % label)


func _finish() -> void:
	print("BT_HUMAN_STUDY_MATERIAL_SUMMARY assertions=%d passed=%d failed=%d" % [assertions, assertions - failures, failures])
	quit(0 if failures == 0 else 1)
