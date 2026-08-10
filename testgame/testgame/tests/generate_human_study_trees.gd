extends SceneTree

const BTNodeResource = preload("res://addons/behavior_tree_editor/bt_node_resource.gd")
const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")

const TREE_SIZES := [121, 364]
const OUTPUT_PATTERN := "res://behavior_trees/human_study_tree_%d.tres"

var failures := 0


func _initialize() -> void:
	for tree_size in TREE_SIZES:
		_generate_save_and_verify(tree_size)
	print("BT_HUMAN_STUDY_TREE_SUMMARY generated=%d failed=%d" % [TREE_SIZES.size(), failures])
	quit(0 if failures == 0 else 1)


func _generate_save_and_verify(node_count: int) -> void:
	var tree := _generate_tree(node_count)
	var output_path := OUTPUT_PATTERN % node_count
	var save_error := ResourceSaver.save(tree, output_path)
	if save_error != OK:
		_fail("save %s returned %s" % [output_path, error_string(save_error)])
		return
	var loaded := ResourceLoader.load(output_path, "", ResourceLoader.CACHE_MODE_IGNORE) as BTTreeResource
	if loaded == null:
		_fail("reload %s" % output_path)
		return
	var target_action_id := node_count - 1
	var target_action := loaded.find_node(target_action_id)
	var target_decorator := loaded.find_node(node_count)
	_check(loaded.nodes.size() == node_count, "%s contains %d nodes" % [output_path, node_count])
	_check(loaded.root_node_id == 1, "%s has Root #1" % output_path)
	_check(loaded.validate_tree().is_empty(), "%s passes structural validation" % output_path)
	_check(target_action != null and target_action.title == "STUDY_TARGET_ACTION", "%s has target Action #%d" % [output_path, target_action_id])
	_check(target_action != null and target_action.parameters.get("action_name", "") == "study_target_action", "%s target Action has a stable method" % output_path)
	_check(target_decorator != null and target_decorator.decorator_parent_id == target_action_id, "%s has target Decorator #%d" % [output_path, node_count])
	_check(target_decorator != null and target_decorator.parameters.get("key", "") == "study_target_visible", "%s target Decorator has a stable blackboard key" % output_path)


func _generate_tree(node_count: int) -> BTTreeResource:
	var structural_count := node_count - 1
	var tree := BTTreeResource.new()
	tree.tree_name = "Human Study Tree %d" % node_count
	tree.root_node_id = 1
	var root_node := _node(1, BTNodeResource.TYPE_ROOT, -1, "Root")
	tree.nodes.append(root_node)
	var entry := _node(2, BTNodeResource.TYPE_SELECTOR, 1, "Decision Hub")
	tree.nodes.append(entry)
	var queue: Array[BTNodeResource] = [entry]
	var next_id := 3
	while next_id <= structural_count and not queue.is_empty():
		var parent: BTNodeResource = queue.pop_front()
		for branch in range(3):
			if next_id > structural_count:
				break
			var remaining := structural_count - next_id
			var type_name := BTNodeResource.TYPE_SELECTOR if remaining > 9 else BTNodeResource.TYPE_ACTION
			var child := _node(next_id, type_name, parent.id, "Branch_%03d" % next_id)
			if type_name == BTNodeResource.TYPE_ACTION:
				child.parameters = {"action_name": "study_action_%03d" % next_id}
			tree.nodes.append(child)
			if type_name == BTNodeResource.TYPE_SELECTOR:
				queue.append(child)
			next_id += 1
	while next_id <= structural_count:
		var parent := entry
		var child := _node(next_id, BTNodeResource.TYPE_ACTION, parent.id, "Task_%03d" % next_id)
		child.parameters = {"action_name": "study_action_%03d" % next_id}
		tree.nodes.append(child)
		next_id += 1

	var target_action := tree.find_node(structural_count)
	target_action.title = "STUDY_TARGET_ACTION"
	target_action.description = "Stable target used by the controlled human comparison study."
	target_action.parameters = {"action_name": "study_target_action"}
	var decorator := _node(node_count, BTNodeResource.TYPE_DECORATOR, -1, "STUDY_TARGET_DECORATOR")
	decorator.decorator_parent_id = target_action.id
	decorator.description = "Edit the comparison value from true to false during the study task."
	decorator.parameters = {
		"mode": "blackboard",
		"key": "study_target_visible",
		"operator": "equals",
		"value": true,
	}
	tree.nodes.append(decorator)
	return tree


func _node(id: int, type_name: String, parent_id: int, title: String) -> BTNodeResource:
	var node := BTNodeResource.new()
	node.id = id
	node.node_type = type_name
	node.parent_id = parent_id
	node.title = title
	node.description = "Human-study benchmark node %d for controlled display comparison." % id
	return node


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	failures += 1
	printerr("FAIL: %s" % label)
