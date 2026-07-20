@tool
extends Resource
class_name BTTreeResource

@export var tree_name: String = "New Behavior Tree"
@export var root_node_id: int = -1
@export var nodes: Array[BTNodeResource] = []


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
	tree.nodes = []
	for node in nodes:
		if node != null:
			tree.nodes.append(node.duplicate(true) as BTNodeResource)
	return tree
