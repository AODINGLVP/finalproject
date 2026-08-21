extends SceneTree

const BTNodeResource = preload("res://addons/behavior_tree_editor/bt_node_resource.gd")
const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")
const TREE_PATH := "res://behavior_trees/complex_display_tree_241.tres"

var assertions := 0
var failures := 0


func _initialize() -> void:
	var tree := ResourceLoader.load(TREE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as BTTreeResource
	_expect(tree != null, "241-node complex tree loads")
	if tree != null:
		_expect(tree.nodes.size() == 241, "node count remains fixed at 241")
		_expect(tree.validate_tree().is_empty(), "tree has no structural validation errors")
		var counts := _type_counts(tree)
		for type_name in [BTNodeResource.TYPE_ROOT, BTNodeResource.TYPE_SEQUENCE, BTNodeResource.TYPE_SELECTOR, BTNodeResource.TYPE_RANDOM_SELECTOR, BTNodeResource.TYPE_PARALLEL, BTNodeResource.TYPE_REPEAT, BTNodeResource.TYPE_ACTION, BTNodeResource.TYPE_CONDITION, BTNodeResource.TYPE_WAIT, BTNodeResource.TYPE_DECORATOR]:
			_expect(int(counts.get(type_name, 0)) > 0, "tree contains %s nodes" % type_name)
		_expect(int(counts.get(BTNodeResource.TYPE_DECORATOR, 0)) == 31, "tree contains 31 attached display constraints")
		_expect(tree.get_children_of(tree.root_node_id).size() == 1, "Root has one decision-loop child")
		var priority := tree.find_node(3)
		_expect(priority != null and tree.get_children_of(priority.id).size() == 9, "priority selector exposes nine semantic decision domains")
		_expect(_seeded_random_selectors(tree), "all Random Selectors have deterministic seeds")
		_expect(_attached_decorators_valid(tree), "all Decorators are attached to non-Decorator owners")
	print("BT_COMPLEX_DISPLAY_TEST_SUMMARY assertions=%d passed=%d failed=%d" % [assertions, assertions - failures, failures])
	quit(0 if failures == 0 else 1)


func _type_counts(tree: BTTreeResource) -> Dictionary:
	var counts := {}
	for node in tree.nodes:
		counts[node.node_type] = int(counts.get(node.node_type, 0)) + 1
	return counts


func _seeded_random_selectors(tree: BTTreeResource) -> bool:
	for node in tree.nodes:
		if node.node_type == BTNodeResource.TYPE_RANDOM_SELECTOR and int(node.parameters.get("seed", -1)) < 0:
			return false
	return true


func _attached_decorators_valid(tree: BTTreeResource) -> bool:
	for node in tree.nodes:
		if node.node_type != BTNodeResource.TYPE_DECORATOR:
			continue
		var owner := tree.find_node(node.decorator_parent_id)
		if owner == null or owner.node_type == BTNodeResource.TYPE_DECORATOR:
			return false
	return true


func _expect(condition: bool, label: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		printerr("FAIL: %s" % label)
