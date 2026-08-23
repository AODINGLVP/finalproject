extends SceneTree

const BTNodeResource = preload("res://addons/behavior_tree_editor/bt_node_resource.gd")
const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")

const TREE_SIZES := [121, 364]
const OUTPUT_PATTERN := "res://behavior_trees/human_study_tree_%d.tres"
const CARD_SIZE := Vector2(250.0, 150.0)
const LAYOUT_START := Vector2(120.0, 100.0)
const LAYOUT_HORIZONTAL_GAP := 80.0
const LAYOUT_VERTICAL_STEP := 260.0

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
	_check(target_decorator != null and target_decorator.parameters.get("blackboard_key", "") == "study_target_visible", "%s target Decorator has a stable blackboard key" % output_path)
	_check(_saved_layout_overlaps(loaded) == 0, "%s has zero saved card overlaps" % output_path)
	_check(_saved_card_positions_unique(loaded), "%s has distinct saved card coordinates" % output_path)


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
		"blackboard_key": "study_target_visible",
		"operator": "equals",
		"value": true,
	}
	tree.nodes.append(decorator)
	_assign_saved_layout(tree)
	return tree


func _assign_saved_layout(tree: BTTreeResource) -> void:
	var root_node := tree.find_node(tree.root_node_id)
	if root_node == null:
		return
	var subtree_widths: Dictionary = {}
	_measure_subtree_width(tree, root_node, subtree_widths)
	_place_subtree(tree, root_node, 0, LAYOUT_START.x, subtree_widths)
	for node in tree.nodes:
		if node == null or node.decorator_parent_id == -1:
			continue
		var owner := tree.find_node(node.decorator_parent_id)
		if owner != null:
			node.position = owner.position


func _measure_subtree_width(tree: BTTreeResource, node: BTNodeResource, widths: Dictionary) -> float:
	var minimum_width := CARD_SIZE.x + LAYOUT_HORIZONTAL_GAP
	var children := tree.get_children_of(node.id)
	if children.is_empty():
		widths[node.id] = minimum_width
		return minimum_width
	var children_width := 0.0
	for child in children:
		children_width += _measure_subtree_width(tree, child, widths)
	var result := maxf(minimum_width, children_width)
	widths[node.id] = result
	return result


func _place_subtree(tree: BTTreeResource, node: BTNodeResource, depth: int, left: float, widths: Dictionary) -> void:
	var width := float(widths.get(node.id, CARD_SIZE.x + LAYOUT_HORIZONTAL_GAP))
	node.position = Vector2(left + (width - CARD_SIZE.x) * 0.5, LAYOUT_START.y + float(depth) * LAYOUT_VERTICAL_STEP)
	var children := tree.get_children_of(node.id)
	if children.is_empty():
		return
	var children_width := 0.0
	for child in children:
		children_width += float(widths.get(child.id, CARD_SIZE.x + LAYOUT_HORIZONTAL_GAP))
	var child_left := left + (width - children_width) * 0.5
	for child in children:
		_place_subtree(tree, child, depth + 1, child_left, widths)
		child_left += float(widths.get(child.id, CARD_SIZE.x + LAYOUT_HORIZONTAL_GAP))


func _saved_layout_overlaps(tree: BTTreeResource) -> int:
	var cards: Array[BTNodeResource] = []
	for node in tree.nodes:
		if node != null and node.decorator_parent_id == -1:
			cards.append(node)
	var overlaps := 0
	for left_index in range(cards.size()):
		for right_index in range(left_index + 1, cards.size()):
			if Rect2(cards[left_index].position, CARD_SIZE).intersects(Rect2(cards[right_index].position, CARD_SIZE)):
				overlaps += 1
	return overlaps


func _saved_card_positions_unique(tree: BTTreeResource) -> bool:
	var positions := {}
	for node in tree.nodes:
		if node == null or node.decorator_parent_id != -1:
			continue
		var key := "%.3f,%.3f" % [node.position.x, node.position.y]
		if positions.has(key):
			return false
		positions[key] = true
	return true


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
