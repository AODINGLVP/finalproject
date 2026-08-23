extends SceneTree

const BTNodeResource = preload("res://addons/behavior_tree_editor/bt_node_resource.gd")
const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")
const ArenaBehaviorTreeFactory = preload("res://tests/support/arena_behavior_tree_factory.gd")
const EnemyActorScript = preload("res://scripts/enemy_actor.gd")

const OUTPUTS := {
	31: "res://behavior_trees/arena_scout_31.tres",
	61: "res://behavior_trees/arena_skirmisher_61.tres",
	121: "res://behavior_trees/arena_hunter_121.tres",
	241: "res://behavior_trees/arena_tactician_241.tres",
	364: "res://behavior_trees/arena_commander_364.tres",
}
const SIZES := [31, 61, 121, 241, 364]

var _failures := 0


func _initialize() -> void:
	var factory := ArenaBehaviorTreeFactory.new()
	var actor_methods := _actor_method_names()
	for node_count in SIZES:
		var tree := factory.build(node_count)
		var output_path := str(OUTPUTS[node_count])
		_validate_tree(tree, node_count, actor_methods)
		var original_order := _execution_order_signature(tree)
		var save_error := ResourceSaver.save(tree, output_path)
		_check(save_error == OK, "%d-node arena tree saves" % node_count)
		var loaded := ResourceLoader.load(output_path, "", ResourceLoader.CACHE_MODE_IGNORE) as BTTreeResource
		_check(loaded != null, "%d-node arena tree reloads" % node_count)
		if loaded != null:
			_validate_tree(loaded, node_count, actor_methods)
			_check(_execution_order_signature(loaded) == original_order, "%d-node arena tree preserves execution order after reload" % node_count)
		print("ARENA_TREE_GENERATED size=%d cards=%d decorators=%d path=%s" % [node_count, _card_count(tree), tree.nodes.size() - _card_count(tree), output_path])
	print("ARENA_TREE_GENERATOR assertions_failed=%d outputs=%d" % [_failures, OUTPUTS.size()])
	quit(0 if _failures == 0 else 1)


func _validate_tree(tree: BTTreeResource, expected_count: int, actor_methods: Dictionary) -> void:
	_check(tree != null, "%d-node arena tree exists" % expected_count)
	if tree == null:
		return
	_check(tree.nodes.size() == expected_count, "%d-node arena tree has exact resource-node count" % expected_count)
	var validation_errors := tree.validate_tree()
	_check(validation_errors.is_empty(), "%d-node arena tree passes structural validation%s" % [expected_count, "" if validation_errors.is_empty() else ": " + "; ".join(validation_errors)])
	var positions := {}
	var action_count := 0
	var condition_count := 0
	var invalid_methods := PackedStringArray()
	var placeholder_nodes := PackedStringArray()
	for node in tree.nodes:
		if node == null:
			continue
		var lower_text := (node.title + " " + node.description).to_lower()
		if lower_text.contains("placeholder") or lower_text.contains("scale_action") or lower_text.contains("scale_condition"):
			placeholder_nodes.append("%d:%s" % [node.id, node.title])
		if node.decorator_parent_id == -1:
			var position_key := "%0.3f,%0.3f" % [node.position.x, node.position.y]
			if positions.has(position_key):
				placeholder_nodes.append("overlapping saved positions %s and %d" % [str(positions[position_key]), node.id])
			positions[position_key] = node.id
		if node.node_type == BTNodeResource.TYPE_ACTION:
			action_count += 1
			var action_name := str(node.parameters.get("action_name", "")).strip_edges()
			if action_name.is_empty() or not actor_methods.has(action_name):
				invalid_methods.append("Action %d -> %s" % [node.id, action_name])
			if action_name.begins_with("scale_"):
				placeholder_nodes.append("%d:%s" % [node.id, action_name])
		elif node.node_type == BTNodeResource.TYPE_CONDITION:
			condition_count += 1
			var condition_name := str(node.parameters.get("condition_name", "")).strip_edges()
			if condition_name.is_empty() or not actor_methods.has(condition_name):
				invalid_methods.append("Condition %d -> %s" % [node.id, condition_name])
			if condition_name.begins_with("scale_"):
				placeholder_nodes.append("%d:%s" % [node.id, condition_name])
	_check(action_count > 0 and condition_count > 0, "%d-node arena tree contains executable actions and conditions" % expected_count)
	_check(invalid_methods.is_empty(), "%d-node arena tree only calls enemy_actor.gd methods%s" % [expected_count, "" if invalid_methods.is_empty() else ": " + "; ".join(invalid_methods)])
	_check(placeholder_nodes.is_empty(), "%d-node arena tree contains no placeholders or duplicate saved card positions%s" % [expected_count, "" if placeholder_nodes.is_empty() else ": " + "; ".join(placeholder_nodes)])
	_validate_required_capabilities(tree, expected_count)


func _validate_required_capabilities(tree: BTTreeResource, node_count: int) -> void:
	var calls := {}
	for node in tree.nodes:
		if node == null:
			continue
		if node.node_type == BTNodeResource.TYPE_ACTION:
			calls[str(node.parameters.get("action_name", ""))] = true
		elif node.node_type == BTNodeResource.TYPE_CONDITION:
			calls[str(node.parameters.get("condition_name", ""))] = true
	var required := [
		"should_dodge", "can_melee", "should_chase", "should_return_home", "is_player_detected",
		"dodge_left", "light_attack_left", "light_attack_right", "chase_player", "return_home",
	]
	if node_count >= 61:
		required.append_array(["is_critical_and_threatened", "has_obstacle_ahead", "should_apply_pressure", "has_last_known_position", "retreat_from_player", "heal_self", "jump_over_obstacle", "search_last_known"])
	if node_count >= 121:
		required.append_array(["should_climb_to_player", "can_use_ranged_attack", "climb_toward_player", "aim_at_player", "fire_projectile", "signal_allies", "scan_for_player"])
	if node_count >= 241:
		required.append_array(["dodge_right", "brace", "heavy_attack_left", "heavy_attack_right", "strafe_right", "advance_aggressively", "search_sweep_left", "search_sweep_right", "observe_area", "idle_guard"])
	var missing := PackedStringArray()
	for method_name in required:
		if not calls.has(method_name):
			missing.append(method_name)
	_check(missing.is_empty(), "%d-node arena tree includes its intended gameplay capabilities%s" % [node_count, "" if missing.is_empty() else ": " + ", ".join(missing)])
	if node_count == 364:
		var expected_doctrines := {
			"2 Counteroffensive Guard": true,
			"4 Close-Quarters Counter Chain": true,
			"6 Obstacle Breach Formation": true,
			"8 Elevated Target Denial": true,
			"10 Mobile Ranged Salvo": true,
			"13 Coordinated Pursuit": true,
		}
		var found_doctrines := {}
		for node in tree.nodes:
			if node != null and expected_doctrines.has(node.title):
				found_doctrines[node.title] = true
		_check(found_doctrines.size() == expected_doctrines.size(), "364-node commander includes six distinct advanced tactical branches")


func _actor_method_names() -> Dictionary:
	var result := {}
	var actor_probe := EnemyActorScript.new()
	for method_data in actor_probe.get_method_list():
		result[str(method_data.get("name", ""))] = true
	actor_probe.free()
	return result


func _card_count(tree: BTTreeResource) -> int:
	var result := 0
	for node in tree.nodes:
		if node != null and node.decorator_parent_id == -1:
			result += 1
	return result


func _execution_order_signature(tree: BTTreeResource) -> String:
	var parts := PackedStringArray()
	for node in tree.nodes:
		if node == null or node.decorator_parent_id != -1:
			continue
		var child_ids := PackedStringArray()
		for child in tree.get_children_of(node.id):
			child_ids.append(str(child.id))
		parts.append("%d:%s" % [node.id, ",".join(child_ids)])
	return "|".join(parts)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		_failures += 1
		printerr("FAIL: %s" % label)
