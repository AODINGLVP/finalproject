@tool
extends Resource
class_name BTTreeResource

const BTBlackboardSchema = preload("res://addons/behavior_tree_editor/bt_blackboard_schema.gd")

@export var tree_name: String = "New Behavior Tree"
@export var root_node_id: int = -1
@export var nodes: Array[BTNodeResource] = []
@export var blackboard_schema: BTBlackboardSchema


func find_node(node_id: int) -> BTNodeResource:
	for node in nodes:
		if node != null and node.id == node_id:
			return node
	return null


func get_children_of(parent_id: int) -> Array[BTNodeResource]:
	var result: Array[BTNodeResource] = []
	for node in nodes:
		if node != null and node.parent_id == parent_id and node.decorator_parent_id == -1:
			result.append(node)
	result.sort_custom(func(a: BTNodeResource, b: BTNodeResource) -> bool:
		if is_equal_approx(a.position.x, b.position.x):
			return a.position.y < b.position.y
		return a.position.x < b.position.x
	)
	return result


func get_decorators_of(owner_id: int) -> Array[BTNodeResource]:
	var result: Array[BTNodeResource] = []
	for node in nodes:
		if node != null and node.decorator_parent_id == owner_id:
			result.append(node)
	result.sort_custom(func(a: BTNodeResource, b: BTNodeResource) -> bool:
		return a.position.x < b.position.x
	)
	return result


func duplicate_tree() -> BTTreeResource:
	var tree := BTTreeResource.new()
	tree.tree_name = tree_name
	tree.root_node_id = root_node_id
	tree.blackboard_schema = blackboard_schema.duplicate_schema() if blackboard_schema != null else null
	tree.nodes = []
	for node in nodes:
		if node != null:
			tree.nodes.append(node.duplicate(true) as BTNodeResource)
	return tree


func can_accept_child(parent: BTNodeResource) -> bool:
	if parent == null or parent.decorator_parent_id != -1:
		return false
	match parent.node_type:
		BTNodeResource.TYPE_ROOT, BTNodeResource.TYPE_DECORATOR, BTNodeResource.TYPE_REPEAT:
			return get_children_of(parent.id).size() < 1
		BTNodeResource.TYPE_SEQUENCE, BTNodeResource.TYPE_SELECTOR, BTNodeResource.TYPE_RANDOM_SELECTOR, BTNodeResource.TYPE_PARALLEL:
			return true
		_:
			return false


func get_blackboard_references() -> Dictionary:
	var references: Dictionary = {}
	for node in nodes:
		if node == null:
			continue
		var key := _blackboard_key_for_node(node)
		if key.is_empty():
			continue
		if not references.has(key):
			references[key] = []
		(references[key] as Array).append({"id": node.id, "title": node.title, "type": node.node_type})
	return references


func get_unused_blackboard_keys() -> PackedStringArray:
	var unused := PackedStringArray()
	if blackboard_schema == null:
		return unused
	var references := get_blackboard_references()
	for entry in blackboard_schema.entries:
		if entry != null and not entry.key.strip_edges().is_empty() and not references.has(entry.key.strip_edges()):
			unused.append(entry.key.strip_edges())
	return unused


func validate_blackboard_references() -> PackedStringArray:
	var errors := PackedStringArray()
	for node in nodes:
		if node == null or not _uses_blackboard_key(node):
			continue
		var key := str(node.parameters.get("blackboard_key", "")).strip_edges()
		if key.is_empty():
			errors.append("Node %d (%s) requires a Blackboard key." % [node.id, node.title])
		elif blackboard_schema != null and not blackboard_schema.allow_dynamic_keys and blackboard_schema.find_entry(key) == null:
			errors.append("Node %d (%s) references undeclared Blackboard key '%s'." % [node.id, node.title, key])
	return errors


func validate_tree() -> PackedStringArray:
	var errors := PackedStringArray()
	if blackboard_schema != null:
		errors.append_array(blackboard_schema.validate_schema())
	errors.append_array(validate_blackboard_references())
	var ids: Dictionary = {}
	for node in nodes:
		if node == null:
			errors.append("Tree contains a null node resource.")
			continue
		if ids.has(node.id):
			errors.append("Duplicate node id: %d." % node.id)
		ids[node.id] = true
	if root_node_id == -1:
		errors.append("Tree has no root node.")
	else:
		var root := find_node(root_node_id)
		if root == null:
			errors.append("Root node id %d does not exist." % root_node_id)
		elif root.node_type != BTNodeResource.TYPE_ROOT:
			errors.append("Root node id %d is not a Root node." % root_node_id)
		elif root.parent_id != -1:
			errors.append("Root node cannot have a parent.")
	for node in nodes:
		if node == null:
			continue
		if node.decorator_parent_id != -1:
			var owner := find_node(node.decorator_parent_id)
			if node.node_type != BTNodeResource.TYPE_DECORATOR:
				errors.append("Node %d is attached as a decorator but has type %s." % [node.id, node.node_type])
			if owner == null:
				errors.append("Decorator %d references missing owner %d." % [node.id, node.decorator_parent_id])
			elif owner.node_type == BTNodeResource.TYPE_DECORATOR:
				errors.append("Decorator %d cannot decorate decorator %d." % [node.id, owner.id])
			var attached_mode := str(node.parameters.get("mode", "blackboard")).to_lower()
			if not ["blackboard", "cooldown", "time_limit", "force_success", "always_success", "succeeder", "force_failure", "always_failure", "failer"].has(attached_mode):
				errors.append("Decorator %d mode '%s' must be a structural decorator." % [node.id, attached_mode])
			continue
		if node.id != root_node_id and node.parent_id == -1:
			errors.append("Node %d is disconnected from the tree." % node.id)
		if node.id != root_node_id and node.parent_id != -1 and find_node(node.parent_id) == null:
			errors.append("Node %d references missing parent %d." % [node.id, node.parent_id])
		var children := get_children_of(node.id)
		if [BTNodeResource.TYPE_ACTION, BTNodeResource.TYPE_CONDITION, BTNodeResource.TYPE_WAIT].has(node.node_type) and not children.is_empty():
			errors.append("Leaf node %d (%s) cannot have children." % [node.id, node.node_type])
		if [BTNodeResource.TYPE_ROOT, BTNodeResource.TYPE_DECORATOR, BTNodeResource.TYPE_REPEAT].has(node.node_type) and children.size() > 1:
			errors.append("Node %d (%s) can have only one child." % [node.id, node.node_type])
		if _has_parent_cycle(node):
			errors.append("Parent cycle detected at node %d." % node.id)
	if root_node_id != -1:
		var reachable: Dictionary = {}
		_collect_reachable(root_node_id, reachable)
		for node in nodes:
			if node != null and node.decorator_parent_id == -1 and not reachable.has(node.id):
				errors.append("Node %d is not reachable from the root." % node.id)
	return errors


func _uses_blackboard_key(node: BTNodeResource) -> bool:
	if node.node_type == BTNodeResource.TYPE_CONDITION:
		return str(node.parameters.get("condition_name", "")).strip_edges().is_empty()
	if node.node_type == BTNodeResource.TYPE_DECORATOR:
		return str(node.parameters.get("mode", "blackboard")).to_lower() == "blackboard"
	return false


func _blackboard_key_for_node(node: BTNodeResource) -> String:
	if not _uses_blackboard_key(node):
		return ""
	return str(node.parameters.get("blackboard_key", "")).strip_edges()


func _has_parent_cycle(node: BTNodeResource) -> bool:
	var visited: Dictionary = {}
	var cursor := node
	while cursor != null and cursor.parent_id != -1:
		if visited.has(cursor.id):
			return true
		visited[cursor.id] = true
		cursor = find_node(cursor.parent_id)
	return false


func _collect_reachable(node_id: int, result: Dictionary) -> void:
	if result.has(node_id):
		return
	result[node_id] = true
	for child in get_children_of(node_id):
		_collect_reachable(child.id, result)
