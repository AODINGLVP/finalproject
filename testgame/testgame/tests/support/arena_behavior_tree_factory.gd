extends RefCounted

const BTNodeResource = preload("res://addons/behavior_tree_editor/bt_node_resource.gd")
const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")
const BTTreeLayout = preload("res://addons/behavior_tree_editor/bt_tree_layout.gd")
const BTBlackboardSchema = preload("res://addons/behavior_tree_editor/bt_blackboard_schema.gd")

const SCHEMA_PATH := "res://behavior_trees/complex_guard_blackboard_schema.tres"
const SUPPORTED_SIZES := [31, 61, 121, 241, 364]

var _next_id := 1


func build(node_count: int) -> BTTreeResource:
	assert(SUPPORTED_SIZES.has(node_count), "Unsupported arena behavior-tree size: %d" % node_count)
	_next_id = 1
	var tree := BTTreeResource.new()
	tree.tree_name = _tree_name(node_count)
	tree.blackboard_schema = load(SCHEMA_PATH) as BTBlackboardSchema
	var root_node := _node(tree, BTNodeResource.TYPE_ROOT, -1, "Root", "Runtime entry point for this playable arena enemy.")
	tree.root_node_id = root_node.id
	var loop := _node(tree, BTNodeResource.TYPE_REPEAT, root_node.id, "Continuous Arena Decisions", "Continuously reevaluate the highest-priority useful behavior.", {"repeat_count": -1})
	var priority := _node(tree, BTNodeResource.TYPE_SELECTOR, loop.id, "Arena Tactical Priority", "Select the safest valid response before lower-priority patrol behavior.", {"reactive": true})
	match node_count:
		31:
			_build_scout(tree, priority)
		61:
			_build_skirmisher(tree, priority)
		121:
			_build_hunter(tree, priority)
		241:
			_build_tactician(tree, priority)
		364:
			_build_commander(tree, priority)
	_layout_tree(tree)
	return tree


func _tree_name(node_count: int) -> String:
	match node_count:
		31:
			return "Arena Scout (31 Nodes)"
		61:
			return "Arena Skirmisher (61 Nodes)"
		121:
			return "Arena Hunter (121 Nodes)"
		241:
			return "Arena Tactician (241 Nodes)"
		364:
			return "Arena Commander (364 Nodes)"
	return "Arena Enemy (%d Nodes)" % node_count


func _build_scout(tree: BTTreeResource, priority: BTNodeResource) -> void:
	_add_basic_dodge(tree, priority)
	_add_basic_melee(tree, priority)
	_add_direct_behavior(tree, priority, "3 Direct Chase", "Pursue a visible player outside melee range.", "should_chase", "chase_player")
	_add_direct_behavior(tree, priority, "4 Return to Post", "Return after the player is lost and the guard has drifted.", "should_return_home", "return_home")
	_add_small_patrol(tree, priority)
	_node(tree, BTNodeResource.TYPE_ACTION, priority.id, "6 Hold Guard Position", "Remain alert when no higher-priority movement is useful.", {"action_name": "idle_guard"})


func _build_skirmisher(tree: BTTreeResource, priority: BTNodeResource) -> void:
	_add_emergency(tree, priority, 1, false)
	_add_dodge(tree, priority, 1)
	_add_melee(tree, priority, 1)
	_add_direct_behavior(tree, priority, "4 Direct Obstacle Vault", "Jump a blocking arena obstacle before resuming pursuit.", "has_obstacle_ahead", "jump_over_obstacle")
	_add_pressure(tree, priority, 1)
	_add_direct_behavior(tree, priority, "6 Direct Chase", "Use a committed chase outside the pressure band.", "should_chase", "chase_player")
	_add_direct_behavior(tree, priority, "7 Last Position Search", "Travel to the remembered position after losing sight.", "has_last_known_position", "search_last_known")
	_add_direct_behavior(tree, priority, "8 Return to Post", "Return to the spawn post after search memory expires.", "should_return_home", "return_home")
	_add_direct_patrol(tree, priority)


func _build_hunter(tree: BTTreeResource, priority: BTNodeResource) -> void:
	_add_emergency(tree, priority, 1, true)
	_add_dodge(tree, priority, 2)
	_add_melee(tree, priority, 1)
	_add_obstacle(tree, priority, 1)
	_add_vertical(tree, priority, 1)
	_add_ranged(tree, priority, 1)
	_add_pressure(tree, priority, 1)
	_add_chase(tree, priority, 2)
	_add_search(tree, priority, 2)
	_add_return_home(tree, priority, 1)
	_add_patrol(tree, priority, 1)
	_add_idle(tree, priority, 1, 1)


func _build_tactician(tree: BTTreeResource, priority: BTNodeResource) -> void:
	_add_emergency(tree, priority, 3, true)
	_add_dodge(tree, priority, 3)
	_add_melee(tree, priority, 3)
	_add_obstacle(tree, priority, 2)
	_add_vertical(tree, priority, 2)
	_add_ranged(tree, priority, 2)
	_add_pressure(tree, priority, 3)
	_add_chase(tree, priority, 4)
	_add_search(tree, priority, 4)
	_add_return_home(tree, priority, 3)
	_add_patrol(tree, priority, 5)
	_add_idle(tree, priority, 4, 2)


func _build_commander(tree: BTTreeResource, priority: BTNodeResource) -> void:
	_add_emergency(tree, priority, 3, true)
	_add_doctrine(tree, priority, "2 Counteroffensive Guard", "Convert an incoming attack into controlled lateral spacing.", "should_dodge", "brace", [
		["dodge_left", "strafe_right"],
		["dodge_right", "strafe_left"],
		["retreat_from_player", "advance_cautiously"],
	], false, 1101, 1.15)
	_add_dodge(tree, priority, 3)
	_add_doctrine(tree, priority, "4 Close-Quarters Counter Chain", "Signal allies, then commit to a direction-aware melee counter.", "can_melee", "signal_allies", [
		["light_attack_left", "heavy_attack_left"],
		["light_attack_right", "heavy_attack_right"],
		["brace", "advance_aggressively"],
	], true, 1201, 1.30)
	_add_melee(tree, priority, 3)
	_add_doctrine(tree, priority, "6 Obstacle Breach Formation", "Read the obstacle and choose a direct or lateral vault approach.", "has_obstacle_ahead", "observe_area", [
		["jump_over_obstacle", "advance_aggressively"],
		["strafe_left", "jump_over_obstacle"],
		["strafe_right", "jump_over_obstacle"],
	], false, 1301, 1.45)
	_add_obstacle(tree, priority, 2)
	_add_doctrine(tree, priority, "8 Elevated Target Denial", "Coordinate a ladder approach or suppress the elevated player at range.", "should_climb_to_player", "signal_allies", [
		["climb_toward_player", "light_attack_left"],
		["climb_toward_player", "light_attack_right"],
		["aim_at_player", "fire_projectile"],
	], false, 1401, 1.60)
	_add_vertical(tree, priority, 2)
	_add_doctrine(tree, priority, "10 Mobile Ranged Salvo", "Aim once, then fire while changing lateral posture.", "can_use_ranged_attack", "aim_at_player", [
		["strafe_left", "fire_projectile"],
		["strafe_right", "fire_projectile"],
		["brace", "fire_projectile"],
	], true, 1501, 1.25)
	_add_ranged(tree, priority, 2)
	_add_pressure(tree, priority, 3)
	_add_doctrine(tree, priority, "13 Coordinated Pursuit", "Publish contact and vary the pursuit line before normal chase logic.", "should_chase", "signal_allies", [
		["advance_aggressively", "strafe_left"],
		["advance_cautiously", "strafe_right"],
		["chase_player", "observe_area"],
	], true, 1601, 1.10)
	_add_chase(tree, priority, 4)
	_add_search(tree, priority, 4)
	_add_return_home(tree, priority, 3)
	_add_patrol(tree, priority, 5)
	_add_idle(tree, priority, 4, 2)


func _add_basic_dodge(tree: BTTreeResource, parent: BTNodeResource) -> void:
	var branch := _node(tree, BTNodeResource.TYPE_SEQUENCE, parent.id, "1 Basic Dodge", "Evade one readable incoming attack.")
	_node(tree, BTNodeResource.TYPE_CONDITION, branch.id, "Incoming Attack?", "Check the player's active attack window.", {"condition_name": "should_dodge"})
	var action := _node(tree, BTNodeResource.TYPE_ACTION, branch.id, "Dodge Away", "Move left to create immediate defensive spacing.", {"action_name": "dodge_left"})
	_decorator(tree, action, "Basic Dodge Cooldown", "cooldown", 0.45)


func _add_basic_melee(tree: BTTreeResource, parent: BTNodeResource) -> void:
	var branch := _node(tree, BTNodeResource.TYPE_SEQUENCE, parent.id, "2 Directional Melee", "Select a strike from the player's current side.")
	_node(tree, BTNodeResource.TYPE_CONDITION, branch.id, "Inside Melee Range?", "Only attack when the player can be hit.", {"condition_name": "can_melee"})
	var direction := _node(tree, BTNodeResource.TYPE_SELECTOR, branch.id, "Resolve Attack Side", "Evaluate left before right using live player position.")
	for side_index in range(2):
		var side := "Left" if side_index == 0 else "Right"
		var suffix := "left" if side_index == 0 else "right"
		var side_branch := _node(tree, BTNodeResource.TYPE_SEQUENCE, direction.id, "%s Strike" % side, "Gate and execute one directional light attack.")
		_node(tree, BTNodeResource.TYPE_CONDITION, side_branch.id, "Can Attack %s?" % side, "Check range and side together.", {"condition_name": "can_attack_%s" % suffix})
		_node(tree, BTNodeResource.TYPE_ACTION, side_branch.id, "Light Attack %s" % side, "Deliver a quick directional strike.", {"action_name": "light_attack_%s" % suffix})


func _add_direct_behavior(tree: BTTreeResource, parent: BTNodeResource, title: String, description: String, condition_name: String, action_name: String) -> void:
	var branch := _node(tree, BTNodeResource.TYPE_SEQUENCE, parent.id, title, description)
	_node(tree, BTNodeResource.TYPE_CONDITION, branch.id, "%s?" % title.trim_prefix(title.get_slice(" ", 0) + " "), "Check whether this arena response is currently valid.", {"condition_name": condition_name})
	_node(tree, BTNodeResource.TYPE_ACTION, branch.id, "%s Action" % title.trim_prefix(title.get_slice(" ", 0) + " "), "Execute the complete response using the enemy Actor API.", {"action_name": action_name})


func _add_small_patrol(tree: BTTreeResource, parent: BTNodeResource) -> void:
	var branch := _node(tree, BTNodeResource.TYPE_SEQUENCE, parent.id, "5 Two-Way Patrol", "Patrol only while no player is visible.")
	var invert := _node(tree, BTNodeResource.TYPE_DECORATOR, branch.id, "No Visible Player", "Invert the live player-detection result.", {"mode": "invert"})
	_node(tree, BTNodeResource.TYPE_CONDITION, invert.id, "Player Detected?", "Read current arena perception.", {"condition_name": "is_player_detected"})
	var routes := _node(tree, BTNodeResource.TYPE_RANDOM_SELECTOR, branch.id, "Choose Patrol Direction", "Vary the next patrol leg without inventing a new Actor method.", {"seed": 31})
	for index in range(2):
		var route := _node(tree, BTNodeResource.TYPE_SEQUENCE, routes.id, "Patrol %s" % ("Left" if index == 0 else "Right"), "Walk one timed patrol leg.")
		_node(tree, BTNodeResource.TYPE_ACTION, route.id, "Move %s" % ("Left" if index == 0 else "Right"), "Traverse the open arena floor.", {"action_name": "move_left" if index == 0 else "move_right"})


func _add_direct_patrol(tree: BTTreeResource, parent: BTNodeResource) -> void:
	var branch := _node(tree, BTNodeResource.TYPE_SEQUENCE, parent.id, "9 Alert Patrol", "Resume patrol only after live detection is lost.")
	var invert := _node(tree, BTNodeResource.TYPE_DECORATOR, branch.id, "No Visible Player", "Invert the player-detection result.", {"mode": "invert"})
	_node(tree, BTNodeResource.TYPE_CONDITION, invert.id, "Player Detected?", "Read current arena perception.", {"condition_name": "is_player_detected"})
	_node(tree, BTNodeResource.TYPE_ACTION, branch.id, "Sweep Patrol Lane", "Walk left through the guarded lane before reevaluating.", {"action_name": "move_left"})


func _add_emergency(tree: BTTreeResource, parent: BTNodeResource, variants: int, include_route_limit: bool) -> void:
	var branch := _node(tree, BTNodeResource.TYPE_SEQUENCE, parent.id, "1 Emergency Recovery", "Critical health overrides every offensive plan.")
	_node(tree, BTNodeResource.TYPE_CONDITION, branch.id, "Critical and Threatened?", "Require both critical health and a detected player.", {"condition_name": "is_critical_and_threatened"})
	var choices := _node(tree, BTNodeResource.TYPE_RANDOM_SELECTOR, branch.id, "Choose Safe Recovery Route", "Vary retreat timing while preserving the recovery goal.", {"seed": 101})
	for index in range(variants):
		var route := _node(tree, BTNodeResource.TYPE_SEQUENCE, choices.id, "Recovery Route %d" % (index + 1), "Create distance, stabilize, then heal.")
		_node(tree, BTNodeResource.TYPE_ACTION, route.id, "Retreat Burst %d" % (index + 1), "Move away from the player.", {"action_name": "retreat_from_player"})
		_node(tree, BTNodeResource.TYPE_WAIT, route.id, "Recovery Breathing %d" % (index + 1), "Pause briefly before healing.", {"duration": 0.05 + index * 0.04})
		var heal := _node(tree, BTNodeResource.TYPE_ACTION, route.id, "Heal Safely %d" % (index + 1), "Restore health after reaching safer spacing.", {"action_name": "heal_self"})
		_decorator(tree, heal, "Healing Cooldown %d" % (index + 1), "cooldown", 2.2 + index * 0.2)
		if include_route_limit:
			_decorator(tree, route, "Recovery Time Limit %d" % (index + 1), "time_limit", 1.8)


func _add_dodge(tree: BTTreeResource, parent: BTNodeResource, variants: int) -> void:
	var branch := _node(tree, BTNodeResource.TYPE_SEQUENCE, parent.id, "2 Reactive Defense", "Evade when the nearby player begins an attack.")
	_node(tree, BTNodeResource.TYPE_CONDITION, branch.id, "Incoming Attack?", "Read the player's live attack window.", {"condition_name": "should_dodge"})
	var choices := _node(tree, BTNodeResource.TYPE_RANDOM_SELECTOR, branch.id, "Defensive Response", "Choose a lateral dodge or stationary brace.", {"seed": 202})
	var methods := ["dodge_left", "dodge_right", "brace"]
	var labels := ["Dodge Left", "Dodge Right", "Brace Impact"]
	for index in range(variants):
		var response := _node(tree, BTNodeResource.TYPE_SEQUENCE, choices.id, "%s Response" % labels[index], "A complete reaction with recovery frames.")
		var action := _node(tree, BTNodeResource.TYPE_ACTION, response.id, labels[index], "Avoid or absorb the incoming strike.", {"action_name": methods[index]})
		_node(tree, BTNodeResource.TYPE_WAIT, response.id, "Defense Recovery %d" % (index + 1), "Prevent an instantaneous attack after defense.", {"duration": 0.06 + index * 0.03})
		_decorator(tree, action, "Defense Cooldown %d" % (index + 1), "cooldown", 0.45 + index * 0.1)


func _add_melee(tree: BTTreeResource, parent: BTNodeResource, combos_per_side: int) -> void:
	var branch := _node(tree, BTNodeResource.TYPE_SEQUENCE, parent.id, "3 Directional Melee Combat", "Use direction-aware light and heavy combinations in melee range.")
	_node(tree, BTNodeResource.TYPE_CONDITION, branch.id, "Inside Melee Range?", "Only enter combo selection when the player can be hit.", {"condition_name": "can_melee"})
	var direction_selector := _node(tree, BTNodeResource.TYPE_SELECTOR, branch.id, "Resolve Attack Direction", "Left is evaluated before right using current position.")
	for direction_index in range(2):
		var side := "Left" if direction_index == 0 else "Right"
		var suffix := "left" if direction_index == 0 else "right"
		var side_branch := _node(tree, BTNodeResource.TYPE_SEQUENCE, direction_selector.id, "%s Combat" % side, "Direction gate followed by a varied combo.")
		_node(tree, BTNodeResource.TYPE_CONDITION, side_branch.id, "Can Attack %s?" % side, "Check range and side together.", {"condition_name": "can_attack_%s" % suffix})
		var combos := _node(tree, BTNodeResource.TYPE_RANDOM_SELECTOR, side_branch.id, "%s Combo Choice" % side, "Choose a complete direction-correct attack pattern.", {"seed": 310 + direction_index})
		for combo_index in range(combos_per_side):
			var combo := _node(tree, BTNodeResource.TYPE_SEQUENCE, combos.id, "%s Combo %d" % [side, combo_index + 1], "Light/heavy ordering creates a distinct commitment window.")
			var first_method := "heavy_attack_%s" % suffix if combo_index == 1 else "light_attack_%s" % suffix
			var second_method := "light_attack_%s" % suffix if combo_index == 1 else "heavy_attack_%s" % suffix
			_node(tree, BTNodeResource.TYPE_ACTION, combo.id, "%s Opening %d" % [side, combo_index + 1], "First strike of the combo.", {"action_name": first_method})
			_node(tree, BTNodeResource.TYPE_WAIT, combo.id, "%s Combo Link %d" % [side, combo_index + 1], "Telegraph the link between strikes.", {"duration": 0.05 + combo_index * 0.03})
			var finisher := _node(tree, BTNodeResource.TYPE_ACTION, combo.id, "%s Finisher %d" % [side, combo_index + 1], "Second strike completes the pattern.", {"action_name": second_method})
			_decorator(tree, finisher, "%s Combo Cooldown %d" % [side, combo_index + 1], "cooldown", 0.55 + combo_index * 0.12)


func _add_obstacle(tree: BTTreeResource, parent: BTNodeResource, variants: int) -> void:
	var branch := _node(tree, BTNodeResource.TYPE_SEQUENCE, parent.id, "4 Obstacle Traversal", "Jump over a blocking crate instead of pushing against it.")
	_node(tree, BTNodeResource.TYPE_CONDITION, branch.id, "Obstacle Ahead?", "Use the horizontal obstacle sensor.", {"condition_name": "has_obstacle_ahead"})
	var choices := _node(tree, BTNodeResource.TYPE_RANDOM_SELECTOR, branch.id, "Obstacle Solution", "Choose a direct or guarded vault cadence.", {"seed": 505})
	for index in range(variants):
		var route := _node(tree, BTNodeResource.TYPE_SEQUENCE, choices.id, "Vault Route %d" % (index + 1), "Commit to one complete obstacle crossing.")
		_node(tree, BTNodeResource.TYPE_ACTION, route.id, "Jump Obstacle %d" % (index + 1), "Apply vertical impulse and forward movement until landing.", {"action_name": "jump_over_obstacle"})
	_decorator(tree, branch, "Obstacle Traversal Limit", "time_limit", 1.8)


func _add_vertical(tree: BTTreeResource, parent: BTNodeResource, variants: int) -> void:
	var branch := _node(tree, BTNodeResource.TYPE_SEQUENCE, parent.id, "5 Vertical Pursuit", "Use ladders when the player occupies an elevated platform.")
	_node(tree, BTNodeResource.TYPE_CONDITION, branch.id, "Player Above Near Ladder?", "Check vertical separation and a nearby ladder trigger.", {"condition_name": "should_climb_to_player"})
	var choices := _node(tree, BTNodeResource.TYPE_RANDOM_SELECTOR, branch.id, "Climb Approach", "Choose a direct or guarded ladder approach.", {"seed": 707})
	for index in range(variants):
		var route := _node(tree, BTNodeResource.TYPE_SEQUENCE, choices.id, "Climb Route %d" % (index + 1), "Align with the ladder and climb toward the platform.")
		_node(tree, BTNodeResource.TYPE_ACTION, route.id, "Climb Ladder %d" % (index + 1), "Move to the ladder and climb toward the player.", {"action_name": "climb_toward_player"})
	_decorator(tree, branch, "Vertical Pursuit Limit", "time_limit", 3.0)


func _add_ranged(tree: BTTreeResource, parent: BTNodeResource, variants: int) -> void:
	var branch := _node(tree, BTNodeResource.TYPE_SEQUENCE, parent.id, "6 Ranged Suppression", "Fire visible projectiles when the player is beyond melee range.")
	_node(tree, BTNodeResource.TYPE_CONDITION, branch.id, "Clear Ranged Shot?", "Require a detected target at a useful projectile distance.", {"condition_name": "can_use_ranged_attack"})
	var choices := _node(tree, BTNodeResource.TYPE_RANDOM_SELECTOR, branch.id, "Ranged Firing Pattern", "Alternate between quick and carefully aimed shots.", {"seed": 404})
	for index in range(variants):
		var pattern := _node(tree, BTNodeResource.TYPE_SEQUENCE, choices.id, "Ranged Pattern %d" % (index + 1), "Aim, telegraph, and release one projectile.")
		_node(tree, BTNodeResource.TYPE_ACTION, pattern.id, "Aim Projectile %d" % (index + 1), "Face and track the current player position.", {"action_name": "aim_at_player"})
		_node(tree, BTNodeResource.TYPE_WAIT, pattern.id, "Ranged Telegraph %d" % (index + 1), "Give the player a readable reaction window.", {"duration": 0.08 + index * 0.07})
		_node(tree, BTNodeResource.TYPE_ACTION, pattern.id, "Fire Projectile %d" % (index + 1), "Spawn a damaging projectile toward the tracked target.", {"action_name": "fire_projectile"})
	_decorator(tree, branch, "Ranged Attack Cooldown", "cooldown", 0.9)


func _add_pressure(tree: BTTreeResource, parent: BTNodeResource, variants: int) -> void:
	var branch := _node(tree, BTNodeResource.TYPE_SEQUENCE, parent.id, "7 Mid-Range Pressure", "Reposition instead of running straight at a nearby target.")
	_node(tree, BTNodeResource.TYPE_CONDITION, branch.id, "Pressure Range?", "Require a detected target outside melee but still nearby.", {"condition_name": "should_apply_pressure"})
	var choices := _node(tree, BTNodeResource.TYPE_RANDOM_SELECTOR, branch.id, "Pressure Pattern", "Mix lateral steps with cautious or aggressive advances.", {"seed": 404})
	var strafes := ["strafe_left", "strafe_right", "brace"]
	for index in range(variants):
		var pattern := _node(tree, BTNodeResource.TYPE_SEQUENCE, choices.id, "Pressure Pattern %d" % (index + 1), "Create a readable approach pattern.")
		var reposition := _node(tree, BTNodeResource.TYPE_ACTION, pattern.id, "Pressure Reposition %d" % (index + 1), "Use a lateral step or brief guard.", {"action_name": strafes[index]})
		_node(tree, BTNodeResource.TYPE_WAIT, pattern.id, "Pressure Read %d" % (index + 1), "Briefly reassess the player.", {"duration": 0.05})
		_node(tree, BTNodeResource.TYPE_ACTION, pattern.id, "Pressure Advance %d" % (index + 1), "Close distance after repositioning.", {"action_name": "advance_aggressively" if index == 2 else "advance_cautiously"})
		_decorator(tree, reposition, "Pressure Cooldown %d" % (index + 1), "cooldown", 0.35 + index * 0.1)


func _add_chase(tree: BTTreeResource, parent: BTNodeResource, variants: int) -> void:
	var branch := _node(tree, BTNodeResource.TYPE_SEQUENCE, parent.id, "8 Coordinated Chase", "Pursue a visible target outside close pressure range.")
	_node(tree, BTNodeResource.TYPE_CONDITION, branch.id, "Should Chase?", "Require detection outside attack and pressure range.", {"condition_name": "should_chase"})
	var choices := _node(tree, BTNodeResource.TYPE_RANDOM_SELECTOR, branch.id, "Chase Strategy", "Choose direct, cautious, or lateral pursuit.", {"seed": 505})
	var methods := ["chase_player", "advance_cautiously", "strafe_left", "strafe_right"]
	for index in range(variants):
		var strategy := _node(tree, BTNodeResource.TYPE_SEQUENCE, choices.id, "Chase Strategy %d" % (index + 1), "Move and publish alert state together, then reassess.")
		var parallel := _node(tree, BTNodeResource.TYPE_PARALLEL, strategy.id, "Chase Preparation %d" % (index + 1), "Run movement and ally signalling concurrently.", {"success_policy": "all", "failure_policy": "any"})
		var movement := _node(tree, BTNodeResource.TYPE_ACTION, parallel.id, "Chase Movement %d" % (index + 1), "Execute the selected pursuit movement.", {"action_name": methods[index]})
		_node(tree, BTNodeResource.TYPE_ACTION, parallel.id, "Signal Contact %d" % (index + 1), "Tell nearby guards the player is visible.", {"action_name": "signal_allies"})
		_node(tree, BTNodeResource.TYPE_WAIT, strategy.id, "Chase Reassessment %d" % (index + 1), "Yield before the reactive selector checks distance again.", {"duration": 0.04 + index * 0.02})
		_decorator(tree, movement, "Chase Step Limit %d" % (index + 1), "time_limit", 0.8)


func _add_search(tree: BTTreeResource, parent: BTNodeResource, variants: int) -> void:
	var branch := _node(tree, BTNodeResource.TYPE_SEQUENCE, parent.id, "9 Last-Known-Position Search", "Search after loss of sight instead of forgetting immediately.")
	_node(tree, BTNodeResource.TYPE_CONDITION, branch.id, "Has Last Known Position?", "Use memory retained after visual detection is lost.", {"condition_name": "has_last_known_position"})
	var choices := _node(tree, BTNodeResource.TYPE_RANDOM_SELECTOR, branch.id, "Search Pattern", "Use directional and direct search paths.", {"seed": 606})
	var sweeps := ["search_sweep_left", "search_last_known", "search_sweep_right", "search_last_known"]
	for index in range(variants):
		var pattern := _node(tree, BTNodeResource.TYPE_SEQUENCE, choices.id, "Search Pattern %d" % (index + 1), "Sweep, pause, and scan before giving up memory.")
		var sweep := _node(tree, BTNodeResource.TYPE_ACTION, pattern.id, "Search Movement %d" % (index + 1), "Move through the last-known area.", {"action_name": sweeps[index]})
		_node(tree, BTNodeResource.TYPE_WAIT, pattern.id, "Listen During Search %d" % (index + 1), "Pause so the search remains readable in play.", {"duration": 0.08 + index * 0.02})
		_node(tree, BTNodeResource.TYPE_ACTION, pattern.id, "Scan Search Area %d" % (index + 1), "Stationary scan completes this search leg.", {"action_name": "scan_for_player"})
		_decorator(tree, sweep, "Search Leg Limit %d" % (index + 1), "time_limit", 1.25)


func _add_return_home(tree: BTTreeResource, parent: BTNodeResource, variants: int) -> void:
	var branch := _node(tree, BTNodeResource.TYPE_SEQUENCE, parent.id, "10 Return to Guard Post", "Prevent patrol drift after the target is gone.")
	_node(tree, BTNodeResource.TYPE_CONDITION, branch.id, "Too Far From Home?", "Return only when no target memory remains.", {"condition_name": "should_return_home"})
	var choices := _node(tree, BTNodeResource.TYPE_RANDOM_SELECTOR, branch.id, "Return Formation", "Choose a guarded return cadence.", {"seed": 707})
	for index in range(variants):
		var route := _node(tree, BTNodeResource.TYPE_SEQUENCE, choices.id, "Return Route %d" % (index + 1), "Move home, pause, and verify the area.")
		var movement := _node(tree, BTNodeResource.TYPE_ACTION, route.id, "Return Movement %d" % (index + 1), "Move toward the original spawn position.", {"action_name": "return_home"})
		_node(tree, BTNodeResource.TYPE_WAIT, route.id, "Return Pause %d" % (index + 1), "Break a long return into observable decisions.", {"duration": 0.05 + index * 0.03})
		_node(tree, BTNodeResource.TYPE_ACTION, route.id, "Verify Guard Post %d" % (index + 1), "Observe before resuming patrol.", {"action_name": "observe_area"})
		_decorator(tree, movement, "Return Step Limit %d" % (index + 1), "time_limit", 0.9)


func _add_patrol(tree: BTTreeResource, parent: BTNodeResource, variants: int) -> void:
	var branch := _node(tree, BTNodeResource.TYPE_SEQUENCE, parent.id, "11 Layered Patrol", "Fallback patrol only when the player is not detected.")
	var invert := _node(tree, BTNodeResource.TYPE_DECORATOR, branch.id, "No Visible Player", "Invert the perception condition.", {"mode": "invert"})
	_node(tree, BTNodeResource.TYPE_CONDITION, invert.id, "Player Detected?", "Read current arena perception.", {"condition_name": "is_player_detected"})
	var choices := _node(tree, BTNodeResource.TYPE_RANDOM_SELECTOR, branch.id, "Patrol Route Choice", "Route variation avoids one mechanical loop.", {"seed": 808})
	var moves := ["move_left", "move_right", "strafe_left", "strafe_right", "move_left"]
	for index in range(variants):
		var route := _node(tree, BTNodeResource.TYPE_SEQUENCE, choices.id, "Patrol Route %d" % (index + 1), "Move for a timed leg and observe the endpoint.")
		var parallel := _node(tree, BTNodeResource.TYPE_PARALLEL, route.id, "Patrol Motion %d" % (index + 1), "Pair movement with its route timer.", {"success_policy": "all", "failure_policy": "any"})
		var movement := _node(tree, BTNodeResource.TYPE_ACTION, parallel.id, "Patrol Movement %d" % (index + 1), "Traverse one patrol leg.", {"action_name": moves[index]})
		_node(tree, BTNodeResource.TYPE_WAIT, parallel.id, "Patrol Leg Timer %d" % (index + 1), "Minimum time spent on this leg.", {"duration": 0.2 + index * 0.04})
		_node(tree, BTNodeResource.TYPE_ACTION, route.id, "Observe Patrol Point %d" % (index + 1), "Scan at the end of the leg.", {"action_name": "observe_area"})
		_decorator(tree, movement, "Patrol Leg Limit %d" % (index + 1), "time_limit", 1.5)


func _add_idle(tree: BTTreeResource, parent: BTNodeResource, variants: int, cooldown_count: int) -> void:
	var choices := _node(tree, BTNodeResource.TYPE_RANDOM_SELECTOR, parent.id, "12 Guard Idle Variations", "Always-available fallback with varied observation.", {"seed": 909})
	for index in range(variants):
		var idle := _node(tree, BTNodeResource.TYPE_SEQUENCE, choices.id, "Idle Variation %d" % (index + 1), "Hold a guard stance and wait before reevaluating.")
		var action := _node(tree, BTNodeResource.TYPE_ACTION, idle.id, "Guard Stance %d" % (index + 1), "Hold position without disabling perception.", {"action_name": "idle_guard" if index % 2 == 0 else "observe_area"})
		_node(tree, BTNodeResource.TYPE_WAIT, idle.id, "Idle Wait %d" % (index + 1), "Keep the fallback visible long enough to observe.", {"duration": 0.12 + index * 0.04})
		if index < cooldown_count:
			_decorator(tree, action, "Idle Cooldown %d" % (index + 1), "cooldown", 0.25 + index * 0.1)


func _add_doctrine(tree: BTTreeResource, parent: BTNodeResource, title: String, description: String, condition_name: String, preparation_action: String, patterns: Array, include_preparation_wait: bool, seed: int, cooldown: float) -> void:
	assert(patterns.size() == 3)
	var branch := _node(tree, BTNodeResource.TYPE_SEQUENCE, parent.id, title, description)
	_node(tree, BTNodeResource.TYPE_CONDITION, branch.id, "%s Available?" % title, "Use an existing Actor condition to gate this advanced response.", {"condition_name": condition_name})
	_node(tree, BTNodeResource.TYPE_ACTION, branch.id, "%s Preparation" % title, "Prepare the advanced response using a real enemy action.", {"action_name": preparation_action})
	if include_preparation_wait:
		_node(tree, BTNodeResource.TYPE_WAIT, branch.id, "%s Read" % title, "Provide a short telegraph before the selected pattern.", {"duration": 0.06})
	var choices := _node(tree, BTNodeResource.TYPE_RANDOM_SELECTOR, branch.id, "%s Pattern" % title, "Select one of three action sequences with distinct movement and timing.", {"seed": seed})
	for index in range(3):
		var methods: Array = patterns[index]
		var pattern := _node(tree, BTNodeResource.TYPE_SEQUENCE, choices.id, "%s Variant %d" % [title, index + 1], "Execute a distinct two-action tactical pattern.")
		_node(tree, BTNodeResource.TYPE_ACTION, pattern.id, "%s Opening %d" % [title, index + 1], "First committed action in this variant.", {"action_name": str(methods[0])})
		_node(tree, BTNodeResource.TYPE_WAIT, pattern.id, "%s Link %d" % [title, index + 1], "Separate the actions with a readable cadence.", {"duration": 0.04 + index * 0.03})
		var finish := _node(tree, BTNodeResource.TYPE_ACTION, pattern.id, "%s Finish %d" % [title, index + 1], "Second action completes the tactical variant.", {"action_name": str(methods[1])})
		_decorator(tree, finish, "%s Variant Cooldown %d" % [title, index + 1], "cooldown", cooldown + index * 0.12)
	_decorator(tree, branch, "%s Doctrine Cooldown" % title, "cooldown", cooldown * 2.0)


func _node(tree: BTTreeResource, type_name: String, parent_id: int, title: String, description: String, parameters := {}) -> BTNodeResource:
	var node := BTNodeResource.new()
	node.id = _next_id
	_next_id += 1
	node.node_type = type_name
	node.parent_id = parent_id
	node.title = title
	node.description = description
	node.parameters = parameters
	tree.nodes.append(node)
	return node


func _decorator(tree: BTTreeResource, owner: BTNodeResource, title: String, mode: String, duration: float) -> void:
	var decorator := _node(tree, BTNodeResource.TYPE_DECORATOR, -1, title, "Attached %s constraint for a bounded tactical response." % mode, {"mode": mode, "duration": duration})
	decorator.decorator_parent_id = owner.id


func _layout_tree(tree: BTTreeResource) -> void:
	BTTreeLayout.arrange(tree)
