extends RefCounted

const BTNodeResource = preload("res://addons/behavior_tree_editor/bt_node_resource.gd")
const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")

const DECORATOR_RATIO := 39.0 / 241.0
const COMPOSITE_TYPES := [
	BTNodeResource.TYPE_SELECTOR,
	BTNodeResource.TYPE_SEQUENCE,
	BTNodeResource.TYPE_RANDOM_SELECTOR,
	BTNodeResource.TYPE_PARALLEL,
]
const LEAF_TYPES := [
	BTNodeResource.TYPE_ACTION,
	BTNodeResource.TYPE_CONDITION,
	BTNodeResource.TYPE_WAIT,
]


static func generate(node_count: int) -> BTTreeResource:
	assert(node_count >= 15)
	var decorator_count := maxi(1, roundi(float(node_count) * DECORATOR_RATIO))
	var card_count := node_count - decorator_count
	var tree := BTTreeResource.new()
	tree.tree_name = "Controlled Scale Tree %d" % node_count
	tree.root_node_id = 1
	tree.nodes.append(_node(1, BTNodeResource.TYPE_ROOT, -1, "Root"))
	var entry := _node(2, BTNodeResource.TYPE_SELECTOR, 1, "Scaled Tactical Priority")
	tree.nodes.append(entry)

	var queue: Array[BTNodeResource] = [entry]
	var leaf_nodes: Array[BTNodeResource] = []
	var next_id := 3
	while next_id <= card_count and not queue.is_empty():
		var parent: BTNodeResource = queue.pop_front()
		for branch in range(3):
			if next_id > card_count:
				break
			var remaining := card_count - next_id
			var make_composite := remaining > 9
			var type_name := str(COMPOSITE_TYPES[(next_id + branch) % COMPOSITE_TYPES.size()]) if make_composite else str(LEAF_TYPES[(next_id + branch) % LEAF_TYPES.size()])
			var child := _node(next_id, type_name, parent.id, _title_for(type_name, next_id))
			_configure_node(child)
			tree.nodes.append(child)
			if make_composite:
				queue.append(child)
			else:
				leaf_nodes.append(child)
			next_id += 1

	while next_id <= card_count:
		var type_name := str(LEAF_TYPES[next_id % LEAF_TYPES.size()])
		var child := _node(next_id, type_name, entry.id, _title_for(type_name, next_id))
		_configure_node(child)
		tree.nodes.append(child)
		leaf_nodes.append(child)
		next_id += 1

	var target := tree.find_node(card_count)
	if target == null or not tree.get_children_of(target.id).is_empty():
		target = leaf_nodes.back()
	target.node_type = BTNodeResource.TYPE_ACTION
	target.title = "SCALE_TARGET_%03d" % node_count
	target.description = "Stable target for the %d-node controlled scaling experiment." % node_count
	target.parameters = {"action_name": "scale_target_%03d" % node_count}

	for index in range(decorator_count):
		var owner := leaf_nodes[index % leaf_nodes.size()]
		var decorator_id := card_count + index + 1
		var decorator := _node(decorator_id, BTNodeResource.TYPE_DECORATOR, -1, "Scale Decorator %03d" % decorator_id)
		decorator.decorator_parent_id = owner.id
		decorator.description = "Attached cooldown used to preserve realistic card density."
		decorator.parameters = {
			"mode": "cooldown",
			"duration": 0.25 + float(index % 5) * 0.1,
		}
		tree.nodes.append(decorator)
	return tree


static func card_count(tree: BTTreeResource) -> int:
	var count := 0
	for node in tree.nodes:
		if node != null and node.decorator_parent_id == -1:
			count += 1
	return count


static func decorator_count(tree: BTTreeResource) -> int:
	return tree.nodes.size() - card_count(tree)


static func search_target_id(tree: BTTreeResource) -> int:
	for node in tree.nodes:
		if node != null and node.title.begins_with("SCALE_TARGET_"):
			return node.id
	return -1


static func focus_target_id(tree: BTTreeResource) -> int:
	var total_cards := card_count(tree)
	var desired_visible := maxi(4, roundi(float(total_cards) * 0.14))
	var best_id := -1
	var best_distance := 1_000_000
	for node in tree.nodes:
		if node == null or node.id == tree.root_node_id or node.parent_id == tree.root_node_id or tree.get_children_of(node.id).is_empty() or node.decorator_parent_id != -1:
			continue
		var subtree_cards := _subtree_card_count(tree, node.id)
		var path_cards := _ancestor_card_count(tree, node.id)
		var visible_cards := subtree_cards + path_cards
		var distance := absi(visible_cards - desired_visible)
		if distance < best_distance:
			best_distance = distance
			best_id = node.id
	return best_id


static func focus_path_ids(tree: BTTreeResource, focus_id: int) -> Array[int]:
	var result: Array[int] = []
	var cursor := tree.find_node(focus_id)
	while cursor != null:
		result.push_front(cursor.id)
		cursor = tree.find_node(cursor.parent_id)
	return result


static func _subtree_card_count(tree: BTTreeResource, node_id: int) -> int:
	var count := 1
	for child in tree.get_children_of(node_id):
		count += _subtree_card_count(tree, child.id)
	return count


static func _ancestor_card_count(tree: BTTreeResource, node_id: int) -> int:
	var count := 0
	var cursor := tree.find_node(node_id)
	while cursor != null and cursor.parent_id != -1:
		count += 1
		cursor = tree.find_node(cursor.parent_id)
	return count


static func _node(id: int, type_name: String, parent_id: int, title: String) -> BTNodeResource:
	var node := BTNodeResource.new()
	node.id = id
	node.node_type = type_name
	node.parent_id = parent_id
	node.title = title
	node.description = "Controlled benchmark node %d with stable descriptive content." % id
	return node


static func _title_for(type_name: String, id: int) -> String:
	return "%s %03d" % [type_name, id]


static func _configure_node(node: BTNodeResource) -> void:
	match node.node_type:
		BTNodeResource.TYPE_ACTION:
			node.parameters = {"action_name": "scale_action_%03d" % node.id}
		BTNodeResource.TYPE_CONDITION:
			node.parameters = {"condition_name": "scale_condition_%03d" % node.id}
		BTNodeResource.TYPE_WAIT:
			node.parameters = {"duration": 0.25 + float(node.id % 4) * 0.25}
		BTNodeResource.TYPE_RANDOM_SELECTOR:
			node.parameters = {"seed": node.id}
		BTNodeResource.TYPE_PARALLEL:
			node.parameters = {"success_policy": "all", "failure_policy": "any"}
