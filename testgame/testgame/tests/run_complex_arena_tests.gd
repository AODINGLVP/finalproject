extends SceneTree

const BTStatus = preload("res://addons/behavior_tree_editor/runtime/bt_status.gd")

var passed := 0
var failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/test_game.tscn") as PackedScene
	_expect(packed != null, "complex arena scene loads")
	if packed == null:
		_finish()
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var player = game.get_node("Player")
	var enemy = game.get_node("EnemyTactician")
	var runner = enemy.get_node("BehaviorTreeComponent")
	runner.tick_on_physics = false
	runner.stop_tree()
	_expect(runner.behavior_tree.resource_path == "res://behavior_trees/arena_tactician_241.tres", "Tactician uses the real playable 241-node resource")
	_expect(runner.behavior_tree.nodes.size() == 241, "playable behavior tree contains 200+ meaningful nodes")
	_expect(_tree_has_type(runner.behavior_tree, "Repeat") and _tree_has_type(runner.behavior_tree, "Random Selector") and _tree_has_type(runner.behavior_tree, "Parallel") and _tree_has_type(runner.behavior_tree, "Wait"), "complex tree uses every new runtime node type")
	_expect(runner.behavior_tree.blackboard_schema != null and runner.behavior_tree.blackboard_schema.entries.size() == 23, "complex tree binds the traversal-aware typed blackboard schema")
	_expect(_tree_has_title(runner.behavior_tree, "1 Emergency Recovery") and _tree_has_title(runner.behavior_tree, "12 Guard Idle Variations"), "priority tree contains all twelve tactical layers")
	_expect(game.has_node("Medkit") and game.has_node("DamageZone") and game.has_node("ObstacleA") and game.has_node("PlatformA") and game.has_node("LadderA"), "arena includes pickups, hazards, obstacles, platforms, and ladders")
	_expect(game.has_node("UI/TopPanel/TopContent/PlayerStatus"), "arena includes gameplay HUD without runtime tree overlay")

	_reset_runner(runner)
	enemy.health = enemy.max_health
	player.cloaked = false
	player.global_position = enemy.global_position + Vector2(45, 0)
	enemy._update_blackboard()
	_expect(runner.tick(0.1) == BTStatus.RUNNING, "right-side attack starts running")
	_expect("3 Directional Melee Combat" in runner.active_path_titles and "Right Combat" in runner.active_path_titles, "selector chooses direction-aware right combo")

	_reset_runner(runner)
	player.global_position = enemy.global_position + Vector2(-45, 0)
	enemy._update_blackboard()
	runner.tick(0.1)
	_expect("3 Directional Melee Combat" in runner.active_path_titles and "Left Combat" in runner.active_path_titles, "selector chooses direction-aware left combo")

	_reset_runner(runner)
	player.attack_timer = 0.15
	player.global_position = enemy.global_position + Vector2(55, 0)
	enemy._update_blackboard()
	runner.tick(0.05)
	_expect("2 Reactive Defense" in runner.active_path_titles and enemy.current_behavior in ["Dodge Left", "Dodge Right", "Brace"], "enemy reacts to the player's live attack window")
	player.attack_timer = 0.0

	_reset_runner(runner)
	player.global_position = enemy.global_position + Vector2(135, 0)
	enemy._update_blackboard()
	runner.tick(0.1)
	_expect("7 Mid-Range Pressure" in runner.active_path_titles and enemy.current_behavior in ["Strafe Left", "Strafe Right", "Brace"], "enemy uses a pressure pattern at middle range")

	_reset_runner(runner)
	enemy.global_position = Vector2(300, 520)
	player.global_position = Vector2(550, 520)
	await physics_frame
	enemy._update_blackboard()
	_expect(runner.blackboard.get("player_detected", false), "blackboard records detected player")
	runner.tick(0.1)
	_expect("6 Ranged Suppression" in runner.active_path_titles, "enemy selects ranged suppression at projectile distance")
	for index in range(6):
		runner.tick(0.1)
	_expect(not get_nodes_in_group("enemy_projectiles").is_empty(), "ranged branch spawns a visible enemy projectile")
	for projectile in get_nodes_in_group("enemy_projectiles"):
		projectile.queue_free()

	_reset_runner(runner)
	enemy.global_position = Vector2(590, 520)
	player.global_position = Vector2(760, 520)
	await physics_frame
	enemy._update_blackboard()
	_expect(runner.blackboard.get("obstacle_ahead", false), "enemy ray sensing detects the blocking crate")
	runner.tick(0.1)
	_expect("4 Obstacle Traversal" in runner.active_path_titles and enemy.current_behavior == "Jump Obstacle" and enemy.velocity.y < 0.0, "enemy jumps instead of walking into an obstacle")

	_reset_runner(runner)
	enemy.global_position = Vector2(735, 520)
	player.global_position = Vector2(790, 350)
	await physics_frame
	enemy._update_blackboard()
	_expect(runner.blackboard.get("player_above", false) and runner.blackboard.get("near_ladder", false), "blackboard detects elevated player and nearby ladder")
	runner.tick(0.1)
	_expect("5 Vertical Pursuit" in runner.active_path_titles and enemy.current_behavior == "Climb Ladder" and enemy.velocity.y < 0.0, "enemy uses ladder pursuit for an elevated player")

	_reset_runner(runner)
	enemy.target_locked = false
	player.global_position = enemy.global_position + Vector2(enemy.lose_target_range + 100.0, 0)
	enemy._update_blackboard()
	runner.tick(0.1)
	_expect("11 Layered Patrol" in runner.active_path_titles and "Patrol Route Choice" in runner.active_path_titles, "enemy patrols through varied routes before acquiring a target")
	player.global_position = enemy.global_position + Vector2(320, 0)
	enemy._update_blackboard()
	var distance_before: float = absf(player.global_position.x - enemy.global_position.x)
	runner.tick(0.1)
	_expect("8 Coordinated Chase" in runner.active_path_titles, "detection immediately preempts running patrol with pursuit")
	enemy.move_and_slide()
	var distance_after: float = absf(player.global_position.x - enemy.global_position.x)
	_expect(enemy.velocity.x > 0.0 and distance_after < distance_before, "chase movement closes distance to player")

	_reset_runner(runner)
	player.cloaked = false
	player.global_position = enemy.global_position + Vector2(180, 0)
	enemy._update_blackboard()
	player.cloaked = true
	enemy._update_blackboard()
	_expect(not runner.blackboard.get("player_detected", true) and runner.blackboard.get("has_last_known_position", false), "cloak preserves last-known position")
	runner.tick(0.1)
	_expect("9 Last-Known-Position Search" in runner.active_path_titles, "selector chooses a multi-pattern search branch")

	_reset_runner(runner)
	player.cloaked = false
	player.global_position = enemy.global_position + Vector2(700, 0)
	enemy._update_blackboard()
	runner.blackboard["has_last_known_position"] = false
	runner.tick(0.1)
	_expect("11 Layered Patrol" in runner.active_path_titles and _path_contains_prefix(runner.active_path_titles, "Patrol Motion"), "selector chooses fallback patrol with concurrent movement and timing")

	_reset_runner(runner)
	enemy.global_position = enemy.home_position + Vector2(220, 0)
	enemy.target_locked = false
	player.global_position = enemy.global_position + Vector2(700, 0)
	enemy._update_blackboard()
	runner.blackboard["has_last_known_position"] = false
	runner.tick(0.1)
	_expect("10 Return to Guard Post" in runner.active_path_titles and enemy.current_behavior == "Return Home", "enemy returns to its post after patrol drift")
	enemy.global_position = enemy.home_position

	_reset_runner(runner)
	enemy.health = 1
	player.global_position = enemy.global_position + Vector2(150, 0)
	enemy._update_blackboard()
	_expect(runner.blackboard.get("critical_health", false), "blackboard exposes critical health")
	runner.tick(0.1)
	_expect("1 Emergency Recovery" in runner.active_path_titles and enemy.current_behavior == "Retreat", "critical enemy chooses emergency retreat")
	var emergency_status := BTStatus.RUNNING
	for index in range(12):
		emergency_status = runner.tick(0.1)
		if enemy.current_behavior == "Heal":
			break
	_expect(enemy.current_behavior == "Heal", "emergency sequence advances to healing")
	for index in range(10):
		emergency_status = runner.tick(0.1)
		if enemy.health > 1:
			break
	_expect(enemy.health > 1, "healing action restores enemy health")

	_reset_runner(runner)
	enemy.health = enemy.max_health
	player.global_position = enemy.global_position + Vector2(40, 0)
	enemy._update_blackboard()
	runner.tick(0.4)
	runner.tick(0.1)
	var reasons: Dictionary = runner.get_debug_snapshot().get("failure_reasons", {})
	_expect(not reasons.is_empty(), "runtime snapshot exposes decorator failure reasons")
	_expect(runner.get_debug_snapshot().get("blackboard_schema_errors", []).is_empty(), "complex actor blackboard satisfies its declared schema")

	player.collect_medkit(3)
	_expect(player.healing_charges >= 1 and player.health <= player.max_health, "player pickup API restores bounded resources")
	game.free()
	await process_frame
	await process_frame
	_finish()


func _reset_runner(runner: Node) -> void:
	runner.node_memory.clear()
	runner.active_path_ids.clear()
	runner.active_path_titles.clear()
	runner.last_failure_reasons.clear()
	runner.blackboard.clear()


func _tree_has_type(tree: Resource, type_name: String) -> bool:
	for node in tree.nodes:
		if node != null and node.node_type == type_name:
			return true
	return false


func _tree_has_title(tree: Resource, title: String) -> bool:
	for node in tree.nodes:
		if node != null and node.title == title:
			return true
	return false


func _path_contains_any(path: Array, titles: Array[String]) -> bool:
	for title in titles:
		if title in path:
			return true
	return false


func _path_contains_prefix(path: Array, prefix: String) -> bool:
	for title in path:
		if str(title).begins_with(prefix):
			return true
	return false


func _finish() -> void:
	print("BT_COMPLEX_ARENA_TEST_SUMMARY passed=%d failed=%d" % [passed, failed])
	_quit_with_result.call_deferred(0 if failed == 0 else 1)


func _quit_with_result(code: int) -> void:
	quit(code)


func _expect(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		printerr("FAIL: %s" % label)
