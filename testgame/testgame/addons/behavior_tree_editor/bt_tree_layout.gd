@tool
extends RefCounted
class_name BTTreeLayout

const BTNodeResource = preload("res://addons/behavior_tree_editor/bt_node_resource.gd")
const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")

const CARD_SIZE := Vector2(250.0, 150.0)
const LAYOUT_START := Vector2(120.0, 100.0)
const HORIZONTAL_GAP := 110.0
const ROOT_BRANCH_EXTRA_GAP := 180.0
const SECONDARY_BRANCH_EXTRA_GAP := 90.0
const VERTICAL_STEP := 340.0
const DECORATOR_STEP := 48.0
const DECORATOR_VERTICAL_OFFSET := 174.0


static func capture_child_order(tree: BTTreeResource) -> Dictionary:
	var result: Dictionary = {}
	if tree == null:
		return result
	for node in tree.nodes:
		if node == null or node.decorator_parent_id != -1:
			continue
		var child_ids: Array[int] = []
		for child in tree.get_children_of(node.id):
			child_ids.append(child.id)
		result[node.id] = child_ids
	return result


static func capture_decorator_order(tree: BTTreeResource) -> Dictionary:
	var result: Dictionary = {}
	if tree == null:
		return result
	var source_order: Dictionary = {}
	for index in range(tree.nodes.size()):
		var source_node: BTNodeResource = tree.nodes[index]
		if source_node != null:
			source_order[source_node.id] = index
	for owner in tree.nodes:
		if owner == null or owner.decorator_parent_id != -1:
			continue
		var decorators: Array[BTNodeResource] = []
		for candidate in tree.nodes:
			if candidate != null and candidate.decorator_parent_id == owner.id:
				decorators.append(candidate)
		decorators.sort_custom(func(left: BTNodeResource, right: BTNodeResource) -> bool:
			if is_equal_approx(left.position.x, right.position.x):
				if is_equal_approx(left.position.y, right.position.y):
					return int(source_order.get(left.id, left.id)) < int(source_order.get(right.id, right.id))
				return left.position.y < right.position.y
			return left.position.x < right.position.x
		)
		if not decorators.is_empty():
			var decorator_ids: Array[int] = []
			for decorator in decorators:
				decorator_ids.append(decorator.id)
			result[owner.id] = decorator_ids
	return result


static func arrange(tree: BTTreeResource, child_order: Dictionary = {}, decorator_order: Dictionary = {}) -> Dictionary:
	if tree == null:
		return {}
	var root: BTNodeResource = tree.find_node(tree.root_node_id)
	if root == null:
		return {}
	var frozen_child_order := child_order.duplicate(true) if not child_order.is_empty() else capture_child_order(tree)
	var frozen_decorator_order := decorator_order.duplicate(true) if not decorator_order.is_empty() else capture_decorator_order(tree)
	var layout := _build_subtree_layout(tree, root, 0, frozen_child_order, {})
	var relative_positions: Dictionary = layout.get("positions", {})
	var minimum_center_x := INF
	var maximum_center_x := -INF
	for relative_position_variant in relative_positions.values():
		var relative_position := Vector2(relative_position_variant)
		minimum_center_x = minf(minimum_center_x, relative_position.x)
		maximum_center_x = maxf(maximum_center_x, relative_position.x)
	var x_offset := LAYOUT_START.x + CARD_SIZE.x * 0.5 - minimum_center_x
	for node_id_variant in relative_positions:
		var node: BTNodeResource = tree.find_node(int(node_id_variant))
		if node == null:
			continue
		var relative_position := Vector2(relative_positions[node_id_variant])
		node.position = Vector2(
			roundf(relative_position.x + x_offset - CARD_SIZE.x * 0.5),
			LAYOUT_START.y + relative_position.y * VERTICAL_STEP
		)
	_place_decorators(tree, frozen_decorator_order)
	return {
		"root_width": maximum_center_x - minimum_center_x + CARD_SIZE.x,
		"child_order": frozen_child_order,
		"decorator_order": frozen_decorator_order,
	}


static func _build_subtree_layout(tree: BTTreeResource, node: BTNodeResource, absolute_depth: int, child_order: Dictionary, visiting: Dictionary) -> Dictionary:
	if visiting.has(node.id):
		return _single_node_layout(node.id)
	visiting[node.id] = true
	var children := _children_from_order(tree, node.id, child_order)
	if children.is_empty():
		visiting.erase(node.id)
		return _single_node_layout(node.id)
	var child_layouts: Array[Dictionary] = []
	for child in children:
		child_layouts.append(_build_subtree_layout(tree, child, absolute_depth + 1, child_order, visiting))
	visiting.erase(node.id)
	var group_positions: Dictionary = {}
	var group_left: Dictionary = {}
	var group_right: Dictionary = {}
	var child_root_centers: Array[float] = []
	var minimum_center_distance := CARD_SIZE.x + _horizontal_gap_for_depth(absolute_depth)
	for child_layout in child_layouts:
		var child_left: Dictionary = child_layout.get("left", {})
		var child_right: Dictionary = child_layout.get("right", {})
		var shift := 0.0
		if not group_positions.is_empty():
			for child_depth_variant in child_left:
				var parent_depth := int(child_depth_variant) + 1
				if group_right.has(parent_depth):
					shift = maxf(shift, float(group_right[parent_depth]) - float(child_left[child_depth_variant]) + minimum_center_distance)
		child_root_centers.append(shift)
		var child_positions: Dictionary = child_layout.get("positions", {})
		for child_id_variant in child_positions:
			var child_position := Vector2(child_positions[child_id_variant])
			group_positions[child_id_variant] = Vector2(child_position.x + shift, child_position.y + 1.0)
		for child_depth_variant in child_left:
			var parent_depth := int(child_depth_variant) + 1
			var shifted_left := float(child_left[child_depth_variant]) + shift
			var shifted_right := float(child_right[child_depth_variant]) + shift
			group_left[parent_depth] = minf(float(group_left.get(parent_depth, shifted_left)), shifted_left)
			group_right[parent_depth] = maxf(float(group_right.get(parent_depth, shifted_right)), shifted_right)
	var children_midpoint := (child_root_centers[0] + child_root_centers[child_root_centers.size() - 1]) * 0.5
	for child_id_variant in group_positions:
		var child_position := Vector2(group_positions[child_id_variant])
		group_positions[child_id_variant] = Vector2(child_position.x - children_midpoint, child_position.y)
	for depth_variant in group_left:
		group_left[depth_variant] = float(group_left[depth_variant]) - children_midpoint
		group_right[depth_variant] = float(group_right[depth_variant]) - children_midpoint
	var positions := {node.id: Vector2.ZERO}
	for child_id_variant in group_positions:
		positions[child_id_variant] = group_positions[child_id_variant]
	var left_contour := {0: 0.0}
	var right_contour := {0: 0.0}
	for depth_variant in group_left:
		left_contour[depth_variant] = group_left[depth_variant]
		right_contour[depth_variant] = group_right[depth_variant]
	return {"positions": positions, "left": left_contour, "right": right_contour}


static func _single_node_layout(node_id: int) -> Dictionary:
	return {
		"positions": {node_id: Vector2.ZERO},
		"left": {0: 0.0},
		"right": {0: 0.0},
	}


static func _place_decorators(tree: BTTreeResource, decorator_order: Dictionary) -> void:
	for owner_id_variant in decorator_order:
		var owner_id := int(owner_id_variant)
		var owner: BTNodeResource = tree.find_node(owner_id)
		if owner == null:
			continue
		var decorator_ids: Array = decorator_order.get(owner_id, [])
		for index in range(decorator_ids.size()):
			var decorator: BTNodeResource = tree.find_node(int(decorator_ids[index]))
			if decorator == null:
				continue
			var centered_index := float(index) - float(decorator_ids.size() - 1) * 0.5
			decorator.position = owner.position + Vector2(centered_index * DECORATOR_STEP, DECORATOR_VERTICAL_OFFSET)


static func _children_from_order(tree: BTTreeResource, parent_id: int, child_order: Dictionary) -> Array[BTNodeResource]:
	var result: Array[BTNodeResource] = []
	var child_ids: Array = child_order.get(parent_id, [])
	for child_id_variant in child_ids:
		var child: BTNodeResource = tree.find_node(int(child_id_variant))
		if child != null and child.parent_id == parent_id and child.decorator_parent_id == -1:
			result.append(child)
	return result


static func _horizontal_gap_for_depth(depth: int) -> float:
	if depth == 0:
		return HORIZONTAL_GAP + ROOT_BRANCH_EXTRA_GAP
	if depth == 1:
		return HORIZONTAL_GAP + SECONDARY_BRANCH_EXTRA_GAP
	return HORIZONTAL_GAP
