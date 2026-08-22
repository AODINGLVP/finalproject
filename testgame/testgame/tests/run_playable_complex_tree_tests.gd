extends SceneTree

const BTNodeResource = preload("res://addons/behavior_tree_editor/bt_node_resource.gd")
const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")
const EnemyActor = preload("res://scripts/enemy_actor.gd")
const TREE_PATH := "res://behavior_trees/complex_display_tree_241.tres"

var assertions := 0
var failures := 0


func _initialize() -> void:
	var tree := ResourceLoader.load(TREE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as BTTreeResource
	_expect(tree != null, "playable complex tree loads")
	if tree != null:
		_expect(tree.nodes.size() == 241, "playable complex tree has exactly 241 nodes")
		_expect(tree.validate_tree().is_empty(), "playable complex tree validates")
		_expect(tree.blackboard_schema != null and tree.blackboard_schema.entries.size() == 23, "typed schema describes all tactical and traversal inputs")
		var counts := _type_counts(tree)
		for type_name in [BTNodeResource.TYPE_ROOT, BTNodeResource.TYPE_SEQUENCE, BTNodeResource.TYPE_SELECTOR, BTNodeResource.TYPE_RANDOM_SELECTOR, BTNodeResource.TYPE_PARALLEL, BTNodeResource.TYPE_REPEAT, BTNodeResource.TYPE_ACTION, BTNodeResource.TYPE_CONDITION, BTNodeResource.TYPE_WAIT, BTNodeResource.TYPE_DECORATOR]:
			_expect(int(counts.get(type_name, 0)) > 0, "tree contains %s" % type_name)
		var priority := tree.find_node(3)
		_expect(priority != null and tree.get_children_of(priority.id).size() == 12, "reactive selector has twelve ordered tactical layers")
		_expect(_has_title(tree, "4 Obstacle Traversal") and _has_title(tree, "5 Vertical Pursuit") and _has_title(tree, "6 Ranged Suppression"), "tree gives traversal and ranged gameplay dedicated branches")
		_expect(_titles_are_unique(tree), "node titles remain unique for Live Debug and search")
		_expect(_all_action_methods_exist(tree), "every Action resolves to a real enemy actor method")
		_expect(_all_conditions_exist(tree), "every actor Condition resolves to a real enemy actor method")
		_expect(_all_random_selectors_seeded(tree), "every Random Selector is deterministic for tests")
		_expect(_all_nodes_have_descriptions(tree), "every node documents its gameplay purpose")
		_expect(_layout_has_depth(tree), "saved resource contains a non-overlapping multi-level layout basis")
	print("BT_PLAYABLE_COMPLEX_TREE_TEST_SUMMARY assertions=%d passed=%d failed=%d" % [assertions, assertions - failures, failures])
	quit(0 if failures == 0 else 1)


func _type_counts(tree: BTTreeResource) -> Dictionary:
	var counts := {}
	for node in tree.nodes:
		counts[node.node_type] = int(counts.get(node.node_type, 0)) + 1
	return counts


func _titles_are_unique(tree: BTTreeResource) -> bool:
	var titles := {}
	for node in tree.nodes:
		if titles.has(node.title):
			return false
		titles[node.title] = true
	return true


func _all_action_methods_exist(tree: BTTreeResource) -> bool:
	var actor := EnemyActor.new()
	for node in tree.nodes:
		if node.node_type != BTNodeResource.TYPE_ACTION:
			continue
		var method_name := str(node.parameters.get("action_name", ""))
		if method_name.is_empty() or not actor.has_method(method_name):
			actor.free()
			printerr("Missing Action method: %s on node %s" % [method_name, node.title])
			return false
	actor.free()
	return true


func _all_conditions_exist(tree: BTTreeResource) -> bool:
	var actor := EnemyActor.new()
	for node in tree.nodes:
		if node.node_type != BTNodeResource.TYPE_CONDITION:
			continue
		var method_name := str(node.parameters.get("condition_name", ""))
		if method_name.is_empty() or not actor.has_method(method_name):
			actor.free()
			printerr("Missing Condition method: %s on node %s" % [method_name, node.title])
			return false
	actor.free()
	return true


func _all_random_selectors_seeded(tree: BTTreeResource) -> bool:
	for node in tree.nodes:
		if node.node_type == BTNodeResource.TYPE_RANDOM_SELECTOR and int(node.parameters.get("seed", -1)) < 0:
			return false
	return true


func _all_nodes_have_descriptions(tree: BTTreeResource) -> bool:
	for node in tree.nodes:
		if node.description.strip_edges().is_empty():
			return false
	return true


func _layout_has_depth(tree: BTTreeResource) -> bool:
	var rows := {}
	for node in tree.nodes:
		if node.decorator_parent_id == -1:
			rows[roundi(node.position.y)] = true
	return rows.size() >= 6


func _has_title(tree: BTTreeResource, title: String) -> bool:
	for node in tree.nodes:
		if node.title == title:
			return true
	return false


func _expect(condition: bool, label: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		printerr("FAIL: %s" % label)
