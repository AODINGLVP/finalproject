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
	var enemy = game.get_node("EnemyB")
	var runner = enemy.get_node("BehaviorTreeComponent")
	runner.tick_on_physics = false
	runner.stop_tree()
	_expect(runner.behavior_tree.tree_name == "Complex Guard Validation Tree", "complex guard tree is assigned")
	_expect(runner.behavior_tree.nodes.size() == 36, "complex tree contains all validation nodes")
	_expect(_tree_has_type(runner.behavior_tree, "Repeat") and _tree_has_type(runner.behavior_tree, "Random Selector") and _tree_has_type(runner.behavior_tree, "Parallel") and _tree_has_type(runner.behavior_tree, "Wait"), "complex tree uses every new runtime node type")
	_expect(runner.behavior_tree.blackboard_schema != null and runner.behavior_tree.blackboard_schema.entries.size() == 11, "complex tree binds a typed blackboard schema")
	_expect(runner.behavior_tree.find_node(33).parameters.get("duration") == 0.25 and runner.behavior_tree.find_node(36).parameters.get("duration") == 0.25, "both patrol Wait nodes keep the configured duration")
	_expect(game.has_node("Medkit") and game.has_node("DamageZone"), "arena includes pickup and hazard systems")
	_expect(game.has_node("UI/TopPanel/TopContent/PlayerStatus"), "arena includes gameplay HUD without runtime tree overlay")

	_reset_runner(runner)
	enemy.health = enemy.max_health
	player.cloaked = false
	player.global_position = enemy.global_position + Vector2(45, 0)
	enemy._update_blackboard()
	_expect(runner.tick(0.1) == BTStatus.RUNNING, "right-side attack starts running")
	_expect("Attack Right" in runner.active_path_titles, "selector chooses attack-right branch")

	_reset_runner(runner)
	player.global_position = enemy.global_position + Vector2(-45, 0)
	enemy._update_blackboard()
	runner.tick(0.1)
	_expect("Attack Left" in runner.active_path_titles, "selector chooses attack-left branch")

	_reset_runner(runner)
	player.global_position = enemy.global_position + Vector2(220, 0)
	enemy._update_blackboard()
	_expect(runner.blackboard.get("player_detected", false), "blackboard records detected player")
	runner.tick(0.1)
	_expect("Chase Player" in runner.active_path_titles and enemy.current_behavior == "Chase", "selector chooses chase branch")

	_reset_runner(runner)
	enemy.target_locked = false
	player.global_position = enemy.global_position + Vector2(enemy.lose_target_range + 100.0, 0)
	enemy._update_blackboard()
	runner.tick(0.1)
	_expect("Patrol Sequence" in runner.active_path_titles and "Random Patrol Direction" in runner.active_path_titles and _path_contains_any(runner.active_path_titles, ["Parallel Left Patrol", "Parallel Right Patrol"]), "enemy patrols through Random Selector and Parallel before acquiring a target")
	player.global_position = enemy.global_position + Vector2(250, 0)
	enemy._update_blackboard()
	var distance_before: float = absf(player.global_position.x - enemy.global_position.x)
	runner.tick(0.1)
	_expect("Chase Player" in runner.active_path_titles, "detection immediately preempts running patrol")
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
	_expect("Search Last Known" in runner.active_path_titles and enemy.current_behavior == "Search", "selector chooses search branch")

	_reset_runner(runner)
	player.cloaked = false
	player.global_position = enemy.global_position + Vector2(700, 0)
	enemy._update_blackboard()
	runner.blackboard["has_last_known_position"] = false
	runner.tick(0.1)
	var patrol_statuses: Dictionary = runner.get_debug_snapshot().get("statuses", {})
	var movement_ticked: bool = patrol_statuses.get(32, "") == "RUNNING" or patrol_statuses.get(35, "") == "RUNNING"
	var wait_ticked: bool = patrol_statuses.get(33, "") == "RUNNING" or patrol_statuses.get(36, "") == "RUNNING"
	_expect("Patrol Sequence" in runner.active_path_titles and movement_ticked and wait_ticked, "selector chooses fallback patrol with concurrent Wait")

	_reset_runner(runner)
	enemy.health = 1
	player.global_position = enemy.global_position + Vector2(150, 0)
	enemy._update_blackboard()
	_expect(runner.blackboard.get("critical_health", false), "blackboard exposes critical health")
	runner.tick(0.1)
	_expect("Retreat From Player" in runner.active_path_titles and enemy.current_behavior == "Retreat", "critical enemy chooses emergency retreat")
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


func _path_contains_any(path: Array, titles: Array[String]) -> bool:
	for title in titles:
		if title in path:
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
