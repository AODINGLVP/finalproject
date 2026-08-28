extends SceneTree

const BTNodeResource = preload("res://addons/behavior_tree_editor/bt_node_resource.gd")
const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")
const BTTreeLayout = preload("res://addons/behavior_tree_editor/bt_tree_layout.gd")

const TREE_DIRECTORY := "res://behavior_trees"
const ACTIVE_TARGET_FILES := [
	"arena_scout_31.tres",
	"arena_skirmisher_61.tres",
	"arena_hunter_121.tres",
	"arena_tactician_241.tres",
	"arena_commander_364.tres",
]
const TEMPLATE_TARGET_FILES := [
	"demo_npc_tree.tres",
	"example_guard_ai.tres",
]

var passed := 0
var failed := 0
var rearranged := 0
var target_files: Array = ACTIVE_TARGET_FILES
var expected_tree_count := 12

const EXPERIMENT_VERTICAL_STEP := 260.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if "--template" in OS.get_cmdline_user_args():
		target_files = TEMPLATE_TARGET_FILES
		expected_tree_count = 2
	var files := DirAccess.get_files_at(TREE_DIRECTORY)
	files.sort()
	var tree_count := 0
	for file_name in files:
		if file_name.get_extension().to_lower() != "tres":
			continue
		var path := TREE_DIRECTORY.path_join(file_name)
		var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		var tree := loaded as BTTreeResource
		if tree == null:
			continue
		tree_count += 1
		if target_files.has(file_name):
			_rearrange_and_verify(path, tree)
		else:
			_verify_existing_tree(path, tree)
	_expect(tree_count == expected_tree_count, "all %d behavior-tree resources in this project are inspected" % expected_tree_count)
	_expect(rearranged == target_files.size(), "all %d selected row-style or horizontal trees are rearranged" % target_files.size())
	print("BT_SAVED_TREE_LAYOUT_SUMMARY passed=%d failed=%d inspected=%d rearranged=%d" % [passed, failed, tree_count, rearranged])
	quit(0 if failed == 0 else 1)


func _rearrange_and_verify(path: String, tree: BTTreeResource) -> void:
	var failures_before := failed
	var semantic_before := _semantic_signature(tree)
	var child_order_before := _child_order_signature(tree)
	var decorator_order_before := _decorator_order_signature(tree)
	var before_bounds := _card_bounds(tree)
	var frozen_child_order := BTTreeLayout.capture_child_order(tree)
	var frozen_decorator_order := BTTreeLayout.capture_decorator_order(tree)
	BTTreeLayout.arrange(tree, frozen_child_order, frozen_decorator_order)
	_compact_experiment_vertical_levels(tree)
	_expect(tree.validate_tree().is_empty(), "%s remains structurally valid after tree layout" % path)
	_expect(_semantic_signature(tree) == semantic_before, "%s changes positions only" % path)
	_expect(_child_order_signature(tree) == child_order_before, "%s preserves every child execution order" % path)
	_expect(_decorator_order_signature(tree) == decorator_order_before, "%s preserves every Decorator order" % path)
	_expect(_overlap_pairs(tree) == 0, "%s has zero saved card overlaps" % path)
	var expected_vertical_gap := EXPERIMENT_VERTICAL_STEP - BTTreeLayout.CARD_SIZE.y
	_expect(absf(_parent_child_vertical_gap(tree) - expected_vertical_gap) <= 0.1, "%s uses the compact experiment parent-child gap" % path)
	_expect(absf(_maximum_parent_child_vertical_gap(tree) - expected_vertical_gap) <= 0.1, "%s keeps every saved depth step consistent" % path)
	_expect(_maximum_parent_center_error(tree) <= 1.1, "%s centers every parent over its first and last child" % path)
	_expect(_minimum_sibling_gap(tree) >= BTTreeLayout.HORIZONTAL_GAP - 1.1, "%s separates every pair of sibling cards" % path)
	if failed != failures_before:
		printerr("TREE_LAYOUT_SKIP_SAVE path=%s reason=pre-save validation" % path)
		return
	var save_error := ResourceSaver.save(tree, path)
	_expect(save_error == OK, "%s saves the tree layout" % path)
	var reloaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as BTTreeResource
	_expect(reloaded != null, "%s reloads after tree layout" % path)
	if reloaded == null:
		return
	_expect(_semantic_signature(reloaded) == semantic_before, "%s reload preserves behavior semantics" % path)
	_expect(_child_order_signature(reloaded) == child_order_before and _decorator_order_signature(reloaded) == decorator_order_before, "%s reload preserves complete execution order" % path)
	_expect(_overlap_pairs(reloaded) == 0 and _maximum_parent_center_error(reloaded) <= 1.1, "%s reload preserves the tree-shaped geometry" % path)
	var after_bounds := _card_bounds(reloaded)
	print("TREE_LAYOUT path=%s cards=%d before=%.0fx%.0f after=%.0fx%.0f min_vertical_gap=%.0f min_sibling_gap=%.0f" % [
		path,
		_card_nodes(reloaded).size(),
		before_bounds.size.x,
		before_bounds.size.y,
		after_bounds.size.x,
		after_bounds.size.y,
		_parent_child_vertical_gap(reloaded),
		_minimum_sibling_gap(reloaded),
	])
	rearranged += 1


func _compact_experiment_vertical_levels(tree: BTTreeResource) -> void:
	# The saved experiment layout is deliberately tighter than the full-detail
	# editor layout. Low-detail overview cards remain separated, while zooming in
	# gives the existing display reflow meaningful vertical work to perform.
	for node in tree.nodes:
		if node == null or node.decorator_parent_id != -1:
			continue
		var depth := roundi((node.position.y - BTTreeLayout.LAYOUT_START.y) / BTTreeLayout.VERTICAL_STEP)
		node.position.y = BTTreeLayout.LAYOUT_START.y + float(depth) * EXPERIMENT_VERTICAL_STEP
	for decorator in tree.nodes:
		if decorator == null or decorator.decorator_parent_id == -1:
			continue
		var owner := tree.find_node(decorator.decorator_parent_id)
		if owner != null:
			decorator.position.y = owner.position.y + BTTreeLayout.DECORATOR_VERTICAL_OFFSET


func _verify_existing_tree(path: String, tree: BTTreeResource) -> void:
	_expect(tree.validate_tree().is_empty(), "%s existing tree remains structurally valid" % path)
	_expect(_overlap_pairs(tree) == 0, "%s existing tree already has zero saved card overlaps" % path)
	_expect(_parent_child_vertical_gap(tree) >= 0.0, "%s existing tree already keeps parents above children" % path)


func _semantic_signature(tree: BTTreeResource) -> String:
	var node_values: Array = []
	for node in tree.nodes:
		if node == null:
			node_values.append(null)
			continue
		node_values.append([
			node.id,
			node.title,
			node.node_type,
			node.parent_id,
			node.decorator_parent_id,
			node.description,
			node.parameters.duplicate(true),
			node.enabled,
			node.collapsed,
		])
	var schema_path := tree.blackboard_schema.resource_path if tree.blackboard_schema != null else ""
	return var_to_str([tree.tree_name, tree.root_node_id, schema_path, node_values])


func _child_order_signature(tree: BTTreeResource) -> String:
	var parts := PackedStringArray()
	for node in tree.nodes:
		if node == null or node.decorator_parent_id != -1:
			continue
		var ids := PackedStringArray()
		for child in tree.get_children_of(node.id):
			ids.append(str(child.id))
		parts.append("%d:%s" % [node.id, ",".join(ids)])
	return "|".join(parts)


func _decorator_order_signature(tree: BTTreeResource) -> String:
	var order := BTTreeLayout.capture_decorator_order(tree)
	var parts := PackedStringArray()
	for node in tree.nodes:
		if node == null or node.decorator_parent_id != -1:
			continue
		var ids := PackedStringArray()
		for decorator_id_variant in order.get(node.id, []):
			ids.append(str(int(decorator_id_variant)))
		parts.append("%d:%s" % [node.id, ",".join(ids)])
	return "|".join(parts)


func _card_nodes(tree: BTTreeResource) -> Array[BTNodeResource]:
	var result: Array[BTNodeResource] = []
	for node in tree.nodes:
		if node != null and node.decorator_parent_id == -1:
			result.append(node)
	return result


func _card_bounds(tree: BTTreeResource) -> Rect2:
	var cards := _card_nodes(tree)
	if cards.is_empty():
		return Rect2()
	var result := Rect2(cards[0].position, BTTreeLayout.CARD_SIZE)
	for index in range(1, cards.size()):
		result = result.merge(Rect2(cards[index].position, BTTreeLayout.CARD_SIZE))
	return result


func _overlap_pairs(tree: BTTreeResource) -> int:
	var cards := _card_nodes(tree)
	var result := 0
	for left_index in range(cards.size()):
		var left_rect := Rect2(cards[left_index].position, BTTreeLayout.CARD_SIZE)
		for right_index in range(left_index + 1, cards.size()):
			if left_rect.intersects(Rect2(cards[right_index].position, BTTreeLayout.CARD_SIZE)):
				result += 1
	return result


func _parent_child_vertical_gap(tree: BTTreeResource) -> float:
	var minimum_gap := INF
	for parent in tree.nodes:
		if parent == null or parent.decorator_parent_id != -1:
			continue
		for child in tree.get_children_of(parent.id):
			minimum_gap = minf(minimum_gap, child.position.y - (parent.position.y + BTTreeLayout.CARD_SIZE.y))
	return minimum_gap if minimum_gap != INF else 0.0


func _maximum_parent_child_vertical_gap(tree: BTTreeResource) -> float:
	var maximum_gap := -INF
	for parent in tree.nodes:
		if parent == null or parent.decorator_parent_id != -1:
			continue
		for child in tree.get_children_of(parent.id):
			maximum_gap = maxf(maximum_gap, child.position.y - (parent.position.y + BTTreeLayout.CARD_SIZE.y))
	return maximum_gap if maximum_gap != -INF else 0.0


func _minimum_sibling_gap(tree: BTTreeResource) -> float:
	var minimum_gap := INF
	for parent in tree.nodes:
		if parent == null or parent.decorator_parent_id != -1:
			continue
		var children := tree.get_children_of(parent.id)
		for index in range(1, children.size()):
			minimum_gap = minf(minimum_gap, children[index].position.x - (children[index - 1].position.x + BTTreeLayout.CARD_SIZE.x))
	return minimum_gap if minimum_gap != INF else BTTreeLayout.HORIZONTAL_GAP


func _maximum_parent_center_error(tree: BTTreeResource) -> float:
	var maximum_error := 0.0
	for parent in tree.nodes:
		if parent == null or parent.decorator_parent_id != -1:
			continue
		var children := tree.get_children_of(parent.id)
		if children.is_empty():
			continue
		var parent_center := parent.position.x + BTTreeLayout.CARD_SIZE.x * 0.5
		var first_center := children[0].position.x + BTTreeLayout.CARD_SIZE.x * 0.5
		var last_center := children[children.size() - 1].position.x + BTTreeLayout.CARD_SIZE.x * 0.5
		maximum_error = maxf(maximum_error, absf(parent_center - (first_center + last_center) * 0.5))
	return maximum_error


func _expect(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		printerr("FAIL: %s" % label)
