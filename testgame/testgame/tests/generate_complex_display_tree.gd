extends SceneTree

const BTNodeResource = preload("res://addons/behavior_tree_editor/bt_node_resource.gd")
const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")

const OUTPUT_PATH := "res://behavior_trees/complex_display_tree_241.tres"
const DOMAINS := [
	["Emergency Recovery", "is_critically_wounded", "retreat", "recover"],
	["Close Combat", "enemy_in_melee_range", "face_enemy", "melee_attack"],
	["Ranged Combat", "enemy_in_ranged_range", "take_aim", "ranged_attack"],
	["Chase Target", "has_visible_target", "update_target", "chase_target"],
	["Search Last Position", "has_last_known_position", "plan_search", "search_area"],
	["Investigate Sound", "heard_suspicious_sound", "locate_sound", "investigate_sound"],
	["Squad Coordination", "has_squad_orders", "share_contact", "follow_orders"],
	["Resource Collection", "needs_supplies", "select_pickup", "collect_supply"],
	["Patrol and Idle", "patrol_enabled", "choose_waypoint", "patrol_route"],
]

var next_id := 1
var failures := 0


func _initialize() -> void:
	var tree := _build_tree()
	_check(tree.nodes.size() == 241, "complex display tree contains exactly 241 nodes")
	_check(tree.validate_tree().is_empty(), "complex display tree passes structural validation")
	var save_error := ResourceSaver.save(tree, OUTPUT_PATH)
	_check(save_error == OK, "complex display tree saves")
	var loaded := ResourceLoader.load(OUTPUT_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as BTTreeResource
	_check(loaded != null and loaded.nodes.size() == 241, "complex display tree reloads with all nodes")
	print("BT_COMPLEX_DISPLAY_GENERATOR nodes=%d failed=%d output=%s" % [tree.nodes.size(), failures, OUTPUT_PATH])
	quit(0 if failures == 0 else 1)


func _build_tree() -> BTTreeResource:
	var tree := BTTreeResource.new()
	tree.tree_name = "Complex Multi-System NPC (241 Nodes)"
	var root_node := _append(tree, BTNodeResource.TYPE_ROOT, -1, "Root", "Entry point for the complete NPC decision model.")
	tree.root_node_id = root_node.id
	var loop := _append(tree, BTNodeResource.TYPE_REPEAT, root_node.id, "Continuous Decision Loop", "Reevaluate priorities while the NPC is active.", {"repeat_count": -1})
	var priority := _append(tree, BTNodeResource.TYPE_SELECTOR, loop.id, "NPC Priority Selector", "Emergency, combat, pursuit, investigation, support, resources, then patrol.", {"reactive": true})

	var decorator_owners: Array[BTNodeResource] = []
	for domain_index in range(DOMAINS.size()):
		var definition: Array = DOMAINS[domain_index]
		var branch := _append(tree, BTNodeResource.TYPE_SEQUENCE, priority.id, str(definition[0]), "A complete decision domain with sensing, concurrent preparation, choice, and recovery.")
		var condition := _append(tree, BTNodeResource.TYPE_CONDITION, branch.id, "Check %s" % definition[0], "Actor condition gating this priority branch.", {"condition_name": str(definition[1])})
		var parallel := _append(tree, BTNodeResource.TYPE_PARALLEL, branch.id, "%s Preparation" % definition[0], "Run sensing, movement preparation, and communication concurrently.", {"success_policy": "all", "failure_policy": "one"})
		decorator_owners.append(condition)
		for lane_index in range(3):
			var lane_name: String = ["Sense", "Position", "Coordinate"][lane_index]
			var lane := _append(tree, BTNodeResource.TYPE_SEQUENCE, parallel.id, "%s %s Lane" % [definition[0], lane_name], "Ordered work for the %s lane." % lane_name.to_lower())
			var prepare := _append(tree, BTNodeResource.TYPE_ACTION, lane.id, "%s %s" % [lane_name, definition[0]], "Prepare this decision lane.", {"action_name": "%s_%s_%d" % [definition[2], lane_name.to_lower(), domain_index]})
			_append(tree, BTNodeResource.TYPE_WAIT, lane.id, "%s Response Window" % lane_name, "Small asynchronous window that exposes RUNNING state.", {"duration": 0.05 + lane_index * 0.05})
			var choice := _append(tree, BTNodeResource.TYPE_RANDOM_SELECTOR, lane.id, "%s %s Choice" % [definition[0], lane_name], "Seeded alternative keeps the fixture deterministic while exercising random choice.", {"seed": 4100 + domain_index * 10 + lane_index})
			_append(tree, BTNodeResource.TYPE_ACTION, choice.id, "%s Conservative" % lane_name, "Low-risk response.", {"action_name": "%s_conservative_%d" % [definition[3], lane_index]})
			_append(tree, BTNodeResource.TYPE_ACTION, choice.id, "%s Assertive" % lane_name, "High-priority response.", {"action_name": "%s_assertive_%d" % [definition[3], lane_index]})
			decorator_owners.append(prepare)
		var retry := _append(tree, BTNodeResource.TYPE_REPEAT, branch.id, "%s Retry" % definition[0], "Retry the domain action twice before yielding to the next priority.", {"repeat_count": 2})
		var execute := _append(tree, BTNodeResource.TYPE_ACTION, retry.id, "Execute %s" % definition[0], "Primary actor method for this decision domain.", {"action_name": str(definition[3])})
		decorator_owners.append(execute)

	# The structural tree has 210 nodes. Add 31 attached decorators to exercise
	# blackboard, cooldown, and time-limit badges without changing execution order.
	for decorator_index in range(31):
		var owner: BTNodeResource = decorator_owners[decorator_index]
		var mode_index := decorator_index % 3
		var parameters: Dictionary
		var title: String
		if mode_index == 0:
			title = "Context Gate %02d" % (decorator_index + 1)
			parameters = {"mode": "blackboard", "blackboard_key": "context_ready_%02d" % (decorator_index + 1), "operator": "equals", "value": true}
		elif mode_index == 1:
			title = "Cooldown %02d" % (decorator_index + 1)
			parameters = {"mode": "cooldown", "duration": 0.5 + decorator_index * 0.1}
		else:
			title = "Time Limit %02d" % (decorator_index + 1)
			parameters = {"mode": "time_limit", "duration": 1.0 + decorator_index * 0.1}
		var decorator := _append(tree, BTNodeResource.TYPE_DECORATOR, -1, title, "Attached constraint used by the large-tree display evaluation.", parameters)
		decorator.decorator_parent_id = owner.id
	return tree


func _append(tree: BTTreeResource, type_name: String, parent_id: int, title: String, description: String, parameters := {}) -> BTNodeResource:
	var node := BTNodeResource.new()
	node.id = next_id
	next_id += 1
	node.node_type = type_name
	node.parent_id = parent_id
	node.title = title
	node.description = description
	node.parameters = parameters
	tree.nodes.append(node)
	return node


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		printerr("FAIL: %s" % label)
