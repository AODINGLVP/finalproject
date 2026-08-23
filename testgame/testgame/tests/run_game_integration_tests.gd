extends SceneTree

const ENEMY_SPECS := [
	["EnemyScout", "res://behavior_trees/arena_scout_31.tres", 31],
	["EnemySkirmisher", "res://behavior_trees/arena_skirmisher_61.tres", 61],
	["EnemyHunter", "res://behavior_trees/arena_hunter_121.tres", 121],
	["EnemyTactician", "res://behavior_trees/arena_tactician_241.tres", 241],
	["EnemyCommander", "res://behavior_trees/arena_commander_364.tres", 364],
]

var passed := 0
var failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/test_game.tscn") as PackedScene
	_expect(packed != null, "test game scene loads")
	if packed == null:
		_finish()
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	var player := game.get_node("Player")
	var enemies: Array[Node] = []
	var assigned_paths: Dictionary = {}
	for spec_variant in ENEMY_SPECS:
		var spec: Array = spec_variant
		var enemy_node := game.get_node_or_null(String(spec[0]))
		_expect(enemy_node != null, "%s exists" % String(spec[0]))
		if enemy_node == null:
			continue
		enemies.append(enemy_node)
		var component: Node = enemy_node.get_node_or_null("BehaviorTreeComponent")
		_expect(component != null and component.behavior_tree != null, "%s has behavior tree component" % enemy_node.name)
		if component == null or component.behavior_tree == null:
			continue
		var expected_path := String(spec[1])
		var expected_nodes := int(spec[2])
		_expect(component.behavior_tree.resource_path == expected_path, "%s uses its real %d-node tree" % [enemy_node.name, expected_nodes])
		_expect(component.behavior_tree.nodes.size() == expected_nodes, "%s tree contains exactly %d resource nodes" % [enemy_node.name, expected_nodes])
		_expect(not assigned_paths.has(component.behavior_tree.resource_path), "%s does not reuse another enemy's behavior tree" % enemy_node.name)
		assigned_paths[component.behavior_tree.resource_path] = true
		_expect(component.agent == enemy_node, "%s behavior tree is bound to the correct Actor" % enemy_node.name)
	_expect(enemies.size() == ENEMY_SPECS.size() and assigned_paths.size() == ENEMY_SPECS.size(), "test game has five enemies with five distinct tree scales")
	_expect(game.total_enemy_count == 5 and game.remaining_enemy_count == 5 and not game.game_completed, "arena begins with five finite enemies and no completion state")

	var health_before: int = player.health
	var player_position_before: Vector2 = player.global_position
	player.invulnerability_timer = 0.0
	player.take_damage(1_000_000)
	_expect(player.infinite_health and player.health == health_before, "infinite-health player cannot lose health")
	_expect(player.global_position == player_position_before, "infinite-health player is not respawned or moved by lethal damage")

	if not enemies.is_empty():
		var enemy: Node = enemies[0]
		var runner: Node = enemy.get_node("BehaviorTreeComponent")
		_expect(not enemy.respawns_enabled and not enemy.is_defeated, "arena enemy begins alive with automatic respawn disabled")
		enemy.take_damage(enemy.max_health)
		await process_frame
		await physics_frame
		_expect(enemy.is_defeated and not enemy.visible and not runner.is_running, "lethal damage permanently defeats the enemy and stops its tree")
		_expect(game.remaining_enemy_count == 4 and not game.game_completed, "one defeat reduces the finite enemy count without completing the arena")
		enemy._physics_process(2.1)
		_expect(enemy.is_defeated and not enemy.visible and enemy.health == 0 and not runner.is_running, "defeated enemy cannot automatically revive after the former respawn delay")
	game.free()
	await process_frame
	await process_frame
	_finish()


func _finish() -> void:
	print("BT_GAME_TEST_SUMMARY passed=%d failed=%d" % [passed, failed])
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
