extends SceneTree

const BTNodeResource = preload("res://addons/behavior_tree_editor/bt_node_resource.gd")
const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")
const BTBlackboardSchema = preload("res://addons/behavior_tree_editor/bt_blackboard_schema.gd")
const BTBlackboardEntry = preload("res://addons/behavior_tree_editor/bt_blackboard_entry.gd")

const OUTPUT_PATH := "res://behavior_trees/playable_complex_enemy_213.tres"

var next_id := 1
var failures := 0


func _initialize() -> void:
	var tree := _build_tree()
	_layout_tree(tree)
	_check(tree.nodes.size() == 213, "playable complex enemy tree contains exactly 213 nodes")
	_check(tree.validate_tree().is_empty(), "playable complex enemy tree validates")
	var save_error := ResourceSaver.save(tree, OUTPUT_PATH)
	_check(save_error == OK, "playable complex enemy tree saves")
	var loaded := ResourceLoader.load(OUTPUT_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as BTTreeResource
	_check(loaded != null and loaded.nodes.size() == 213, "playable complex enemy tree reloads")
	print("BT_PLAYABLE_COMPLEX_TREE_GENERATOR nodes=%d failed=%d output=%s" % [tree.nodes.size(), failures, OUTPUT_PATH])
	quit(0 if failures == 0 else 1)


func _build_tree() -> BTTreeResource:
	var tree := BTTreeResource.new()
	tree.tree_name = "Playable Complex Tactical Enemy (213 Nodes)"
	tree.blackboard_schema = _build_schema()
	var root_node := _node(tree, BTNodeResource.TYPE_ROOT, -1, "Root", "Runtime entry point for the playable tactical enemy.")
	tree.root_node_id = root_node.id
	var loop := _node(tree, BTNodeResource.TYPE_REPEAT, root_node.id, "Continuous Tactical Decisions", "Continuously reevaluate the highest useful behavior.", {"repeat_count": -1})
	var priority := _node(tree, BTNodeResource.TYPE_SELECTOR, loop.id, "Reactive Tactical Priority", "Emergency, dodge, melee, pressure, chase, search, return, patrol, then idle.", {"reactive": true})
	_add_emergency(tree, priority)
	_add_dodge(tree, priority)
	_add_melee(tree, priority)
	_add_pressure(tree, priority)
	_add_chase(tree, priority)
	_add_search(tree, priority)
	_add_return_home(tree, priority)
	_add_patrol(tree, priority)
	_add_idle(tree, priority)
	return tree


func _add_emergency(tree: BTTreeResource, parent: BTNodeResource) -> void:
	var branch := _node(tree, BTNodeResource.TYPE_SEQUENCE, parent.id, "1 Emergency Recovery", "Critical health overrides every offensive plan.")
	_node(tree, BTNodeResource.TYPE_CONDITION, branch.id, "Critical and Threatened?", "Requires both critical health and a detected player.", {"condition_name": "is_critical_and_threatened"})
	var choices := _node(tree, BTNodeResource.TYPE_RANDOM_SELECTOR, branch.id, "Choose Safe Recovery Route", "Vary retreat direction and timing while preserving the same goal.", {"seed": 101})
	for index in range(3):
		var route := _node(tree, BTNodeResource.TYPE_SEQUENCE, choices.id, "Recovery Route %d" % (index + 1), "Create distance, stabilize, then heal.")
		_node(tree, BTNodeResource.TYPE_ACTION, route.id, "Retreat Burst %d" % (index + 1), "Move away from the player.", {"action_name": "retreat_from_player"})
		_node(tree, BTNodeResource.TYPE_WAIT, route.id, "Recovery Breathing %d" % (index + 1), "Short readable pause before healing.", {"duration": 0.05 + index * 0.04})
		var heal := _node(tree, BTNodeResource.TYPE_ACTION, route.id, "Heal Safely %d" % (index + 1), "Restore health after reaching safer spacing.", {"action_name": "heal_self"})
		_decorator(tree, heal, "Healing Cooldown %d" % (index + 1), "cooldown", 2.2 + index * 0.2)
		_decorator(tree, route, "Recovery Time Limit %d" % (index + 1), "time_limit", 1.8)


func _add_dodge(tree: BTTreeResource, parent: BTNodeResource) -> void:
	var branch := _node(tree, BTNodeResource.TYPE_SEQUENCE, parent.id, "2 Reactive Defense", "Evade when the nearby player begins an attack.")
	_node(tree, BTNodeResource.TYPE_CONDITION, branch.id, "Incoming Attack?", "Reads the player's live attack window.", {"condition_name": "should_dodge"})
	var choices := _node(tree, BTNodeResource.TYPE_RANDOM_SELECTOR, branch.id, "Defensive Response", "Choose a lateral dodge or a stationary brace.", {"seed": 202})
	var methods := ["dodge_left", "dodge_right", "brace"]
	var labels := ["Dodge Left", "Dodge Right", "Brace Impact"]
	for index in range(3):
		var response := _node(tree, BTNodeResource.TYPE_SEQUENCE, choices.id, "%s Response" % labels[index], "A complete reaction with recovery frames.")
		var action := _node(tree, BTNodeResource.TYPE_ACTION, response.id, labels[index], "Avoid or absorb the incoming strike.", {"action_name": methods[index]})
		_node(tree, BTNodeResource.TYPE_WAIT, response.id, "Defense Recovery %d" % (index + 1), "Prevents instantaneous attack after defense.", {"duration": 0.06 + index * 0.03})
		_decorator(tree, action, "Defense Cooldown %d" % (index + 1), "cooldown", 0.45 + index * 0.1)


func _add_melee(tree: BTTreeResource, parent: BTNodeResource) -> void:
	var branch := _node(tree, BTNodeResource.TYPE_SEQUENCE, parent.id, "3 Directional Melee Combat", "Use direction-aware light and heavy combinations in melee range.")
	_node(tree, BTNodeResource.TYPE_CONDITION, branch.id, "Inside Melee Range?", "Only enter combo selection when the player can be hit.", {"condition_name": "can_melee"})
	var direction_selector := _node(tree, BTNodeResource.TYPE_SELECTOR, branch.id, "Resolve Attack Direction", "Left is evaluated before right using current position.")
	for direction_index in range(2):
		var side := "Left" if direction_index == 0 else "Right"
		var suffix := "left" if direction_index == 0 else "right"
		var side_branch := _node(tree, BTNodeResource.TYPE_SEQUENCE, direction_selector.id, "%s Combat" % side, "Direction gate followed by a varied combo.")
		_node(tree, BTNodeResource.TYPE_CONDITION, side_branch.id, "Can Attack %s?" % side, "Checks range and side together.", {"condition_name": "can_attack_%s" % suffix})
		var combos := _node(tree, BTNodeResource.TYPE_RANDOM_SELECTOR, side_branch.id, "%s Combo Choice" % side, "Choose one of three complete attack patterns.", {"seed": 310 + direction_index})
		for combo_index in range(3):
			var combo := _node(tree, BTNodeResource.TYPE_SEQUENCE, combos.id, "%s Combo %d" % [side, combo_index + 1], "Light/heavy ordering creates different commitment windows.")
			var first_method := "heavy_attack_%s" % suffix if combo_index == 1 else "light_attack_%s" % suffix
			var second_method := "light_attack_%s" % suffix if combo_index == 1 else "heavy_attack_%s" % suffix
			_node(tree, BTNodeResource.TYPE_ACTION, combo.id, "%s Opening %d" % [side, combo_index + 1], "First strike of the combo.", {"action_name": first_method})
			_node(tree, BTNodeResource.TYPE_WAIT, combo.id, "%s Combo Link %d" % [side, combo_index + 1], "Telegraphed link between strikes.", {"duration": 0.05 + combo_index * 0.03})
			var finisher := _node(tree, BTNodeResource.TYPE_ACTION, combo.id, "%s Finisher %d" % [side, combo_index + 1], "Second strike completes the pattern.", {"action_name": second_method})
			_decorator(tree, finisher, "%s Combo Cooldown %d" % [side, combo_index + 1], "cooldown", 0.55 + combo_index * 0.12)


func _add_pressure(tree: BTTreeResource, parent: BTNodeResource) -> void:
	var branch := _node(tree, BTNodeResource.TYPE_SEQUENCE, parent.id, "4 Mid-Range Pressure", "Reposition instead of running straight at a nearby target.")
	_node(tree, BTNodeResource.TYPE_CONDITION, branch.id, "Pressure Range?", "Target is detected, outside melee, but still nearby.", {"condition_name": "should_apply_pressure"})
	var choices := _node(tree, BTNodeResource.TYPE_RANDOM_SELECTOR, branch.id, "Pressure Pattern", "Mix lateral steps with cautious or aggressive advances.", {"seed": 404})
	var strafes := ["strafe_left", "strafe_right", "brace"]
	for index in range(3):
		var pattern := _node(tree, BTNodeResource.TYPE_SEQUENCE, choices.id, "Pressure Pattern %d" % (index + 1), "Create a readable approach pattern.")
		var reposition := _node(tree, BTNodeResource.TYPE_ACTION, pattern.id, "Pressure Reposition %d" % (index + 1), "Lateral movement or brief guard.", {"action_name": strafes[index]})
		_node(tree, BTNodeResource.TYPE_WAIT, pattern.id, "Pressure Read %d" % (index + 1), "Briefly reassess the player.", {"duration": 0.05})
		_node(tree, BTNodeResource.TYPE_ACTION, pattern.id, "Pressure Advance %d" % (index + 1), "Close distance after repositioning.", {"action_name": "advance_aggressively" if index == 2 else "advance_cautiously"})
		_decorator(tree, reposition, "Pressure Cooldown %d" % (index + 1), "cooldown", 0.35 + index * 0.1)


func _add_chase(tree: BTTreeResource, parent: BTNodeResource) -> void:
	var branch := _node(tree, BTNodeResource.TYPE_SEQUENCE, parent.id, "5 Coordinated Chase", "Pursue a visible target outside close pressure range.")
	_node(tree, BTNodeResource.TYPE_CONDITION, branch.id, "Should Chase?", "Requires detection outside attack range.", {"condition_name": "should_chase"})
	var choices := _node(tree, BTNodeResource.TYPE_RANDOM_SELECTOR, branch.id, "Chase Strategy", "Choose direct, cautious, left-feint, or right-feint pursuit.", {"seed": 505})
	var methods := ["advance_aggressively", "advance_cautiously", "strafe_left", "strafe_right"]
	for index in range(4):
		var strategy := _node(tree, BTNodeResource.TYPE_SEQUENCE, choices.id, "Chase Strategy %d" % (index + 1), "Concurrent movement and ally signalling followed by reassessment.")
		var parallel := _node(tree, BTNodeResource.TYPE_PARALLEL, strategy.id, "Chase Preparation %d" % (index + 1), "Move and publish alert state together.", {"success_policy": "all", "failure_policy": "any"})
		var movement := _node(tree, BTNodeResource.TYPE_ACTION, parallel.id, "Chase Movement %d" % (index + 1), "Execute the selected pursuit movement.", {"action_name": methods[index]})
		_node(tree, BTNodeResource.TYPE_ACTION, parallel.id, "Signal Contact %d" % (index + 1), "Tell nearby guards the player is visible.", {"action_name": "signal_allies"})
		_node(tree, BTNodeResource.TYPE_WAIT, strategy.id, "Chase Reassessment %d" % (index + 1), "Yield before the reactive selector checks distance again.", {"duration": 0.04 + index * 0.02})
		_decorator(tree, movement, "Chase Step Limit %d" % (index + 1), "time_limit", 0.8)


func _add_search(tree: BTTreeResource, parent: BTNodeResource) -> void:
	var branch := _node(tree, BTNodeResource.TYPE_SEQUENCE, parent.id, "6 Last-Known-Position Search", "Search after cloak or loss of sight instead of forgetting immediately.")
	_node(tree, BTNodeResource.TYPE_CONDITION, branch.id, "Has Last Known Position?", "Memory persists when visual detection is lost.", {"condition_name": "has_last_known_position"})
	var choices := _node(tree, BTNodeResource.TYPE_RANDOM_SELECTOR, branch.id, "Search Pattern", "Use four deterministic but varied sweep patterns.", {"seed": 606})
	var sweeps := ["search_sweep_left", "search_sweep_right", "search_last_known", "search_last_known"]
	for index in range(4):
		var pattern := _node(tree, BTNodeResource.TYPE_SEQUENCE, choices.id, "Search Pattern %d" % (index + 1), "Sweep, pause, then scan before giving up memory.")
		var sweep := _node(tree, BTNodeResource.TYPE_ACTION, pattern.id, "Search Movement %d" % (index + 1), "Move through the last-known area.", {"action_name": sweeps[index]})
		_node(tree, BTNodeResource.TYPE_WAIT, pattern.id, "Listen During Search %d" % (index + 1), "A small pause makes the search legible in play.", {"duration": 0.08 + index * 0.02})
		_node(tree, BTNodeResource.TYPE_ACTION, pattern.id, "Scan Search Area %d" % (index + 1), "Stationary scan completes the pattern.", {"action_name": "scan_for_player"})
		_decorator(tree, sweep, "Search Leg Limit %d" % (index + 1), "time_limit", 1.25)


func _add_return_home(tree: BTTreeResource, parent: BTNodeResource) -> void:
	var branch := _node(tree, BTNodeResource.TYPE_SEQUENCE, parent.id, "7 Return to Guard Post", "Prevent patrol drift after the target is gone.")
	_node(tree, BTNodeResource.TYPE_CONDITION, branch.id, "Too Far From Home?", "Only return when no target memory remains.", {"condition_name": "should_return_home"})
	var choices := _node(tree, BTNodeResource.TYPE_RANDOM_SELECTOR, branch.id, "Return Formation", "Choose a guarded return cadence.", {"seed": 707})
	for index in range(3):
		var route := _node(tree, BTNodeResource.TYPE_SEQUENCE, choices.id, "Return Route %d" % (index + 1), "Move home, pause, then verify the area.")
		var movement := _node(tree, BTNodeResource.TYPE_ACTION, route.id, "Return Movement %d" % (index + 1), "Move toward the original spawn position.", {"action_name": "return_home"})
		_node(tree, BTNodeResource.TYPE_WAIT, route.id, "Return Pause %d" % (index + 1), "Break a long return into observable decisions.", {"duration": 0.05 + index * 0.03})
		_node(tree, BTNodeResource.TYPE_ACTION, route.id, "Verify Guard Post %d" % (index + 1), "Observe before resuming patrol.", {"action_name": "observe_area"})
		_decorator(tree, movement, "Return Step Limit %d" % (index + 1), "time_limit", 0.9)


func _add_patrol(tree: BTTreeResource, parent: BTNodeResource) -> void:
	var branch := _node(tree, BTNodeResource.TYPE_SEQUENCE, parent.id, "8 Layered Patrol", "Fallback patrol only when the player is not currently detected.")
	var invert := _node(tree, BTNodeResource.TYPE_DECORATOR, branch.id, "No Visible Player", "Invert the perception condition.", {"mode": "invert"})
	_node(tree, BTNodeResource.TYPE_CONDITION, invert.id, "Player Detected?", "The inverted result gates patrol.", {"condition_name": "is_player_detected"})
	var choices := _node(tree, BTNodeResource.TYPE_RANDOM_SELECTOR, branch.id, "Patrol Route Choice", "Five routes prevent a single mechanical loop.", {"seed": 808})
	var moves := ["move_left", "move_right", "strafe_left", "strafe_right", "move_left"]
	for index in range(5):
		var route := _node(tree, BTNodeResource.TYPE_SEQUENCE, choices.id, "Patrol Route %d" % (index + 1), "Movement and timing run concurrently, followed by observation.")
		var parallel := _node(tree, BTNodeResource.TYPE_PARALLEL, route.id, "Patrol Motion %d" % (index + 1), "Pair a movement task with its route timer.", {"success_policy": "all", "failure_policy": "any"})
		var movement := _node(tree, BTNodeResource.TYPE_ACTION, parallel.id, "Patrol Movement %d" % (index + 1), "Traverse one patrol leg.", {"action_name": moves[index]})
		_node(tree, BTNodeResource.TYPE_WAIT, parallel.id, "Patrol Leg Timer %d" % (index + 1), "Minimum time spent on this leg.", {"duration": 0.2 + index * 0.04})
		_node(tree, BTNodeResource.TYPE_ACTION, route.id, "Observe Patrol Point %d" % (index + 1), "Scan at the end of the leg.", {"action_name": "observe_area"})
		_decorator(tree, movement, "Patrol Leg Limit %d" % (index + 1), "time_limit", 1.5)


func _add_idle(tree: BTTreeResource, parent: BTNodeResource) -> void:
	var choices := _node(tree, BTNodeResource.TYPE_RANDOM_SELECTOR, parent.id, "9 Guard Idle Variations", "Always-available final fallback with varied facing and observation.", {"seed": 909})
	for index in range(4):
		var idle := _node(tree, BTNodeResource.TYPE_SEQUENCE, choices.id, "Idle Variation %d" % (index + 1), "Short idle action followed by an explicit wait.")
		var action := _node(tree, BTNodeResource.TYPE_ACTION, idle.id, "Guard Stance %d" % (index + 1), "Hold position without disabling perception.", {"action_name": "idle_guard" if index % 2 == 0 else "observe_area"})
		_node(tree, BTNodeResource.TYPE_WAIT, idle.id, "Idle Wait %d" % (index + 1), "Keep the fallback RUNNING long enough to observe.", {"duration": 0.12 + index * 0.04})
		if index < 2:
			_decorator(tree, action, "Idle Cooldown %d" % (index + 1), "cooldown", 0.25 + index * 0.1)


func _node(tree: BTTreeResource, type_name: String, parent_id: int, title: String, description: String, parameters := {}) -> BTNodeResource:
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


func _decorator(tree: BTTreeResource, owner: BTNodeResource, title: String, mode: String, duration: float) -> void:
	var decorator := _node(tree, BTNodeResource.TYPE_DECORATOR, -1, title, "Attached %s constraint for runtime safety and editor visibility." % mode, {"mode": mode, "duration": duration})
	decorator.decorator_parent_id = owner.id


func _build_schema() -> BTBlackboardSchema:
	var schema := BTBlackboardSchema.new()
	schema.allow_dynamic_keys = true
	var definitions := [
		["player_detected", "Bool", false], ["player_in_range", "Bool", false],
		["player_on_left", "Bool", false], ["player_on_right", "Bool", false],
		["player_x", "Float", 0.0], ["player_distance", "Float", 9999.0],
		["player_attacking", "Bool", false], ["player_health", "Int", 8],
		["health", "Int", 6], ["health_ratio", "Float", 1.0],
		["low_health", "Bool", false], ["critical_health", "Bool", false],
		["last_known_player_x", "Float", 0.0], ["has_last_known_position", "Bool", false],
		["home_distance", "Float", 0.0], ["nearby_allies", "Int", 0], ["alert_level", "Float", 0.0],
	]
	for definition in definitions:
		var entry := BTBlackboardEntry.new()
		entry.key = str(definition[0])
		entry.value_type = str(definition[1])
		entry.default_value = definition[2]
		entry.description = "Playable tactical enemy runtime value."
		schema.entries.append(entry)
	return schema


func _layout_tree(tree: BTTreeResource) -> void:
	var levels := {}
	var queue: Array[Array] = [[tree.root_node_id, 0]]
	while not queue.is_empty():
		var item: Array = queue.pop_front()
		var node_id := int(item[0])
		var depth := int(item[1])
		if not levels.has(depth):
			levels[depth] = []
		(levels[depth] as Array).append(node_id)
		for child in tree.get_children_of(node_id):
			queue.append([child.id, depth + 1])
	for depth in levels:
		var ids: Array = levels[depth]
		var width := float(ids.size() - 1) * 300.0
		for index in range(ids.size()):
			tree.find_node(int(ids[index])).position = Vector2(index * 300.0 - width * 0.5 + 12000.0, float(depth) * 190.0 + 100.0)
	for node in tree.nodes:
		if node.decorator_parent_id == -1:
			continue
		var owner := tree.find_node(node.decorator_parent_id)
		node.position = owner.position + Vector2(-90.0, 125.0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		printerr("FAIL: %s" % label)
