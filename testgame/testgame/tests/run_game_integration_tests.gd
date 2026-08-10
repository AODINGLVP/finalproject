extends SceneTree

const BTStatus = preload("res://addons/behavior_tree_editor/runtime/bt_status.gd")

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
	var enemies := [game.get_node("EnemyA"), game.get_node("EnemyB"), game.get_node("EnemyC")]
	_expect(enemies.size() == 3, "test game has three enemies")
	for enemy_value in enemies:
		var enemy_node: Node = enemy_value
		var component: Node = enemy_node.get_node_or_null("BehaviorTreeComponent")
		_expect(component != null and component.behavior_tree != null, "%s has behavior tree component" % enemy_node.name)

	var enemy: Node = enemies[0]
	var runner: Node = enemy.get_node("BehaviorTreeComponent")
	runner.tick_on_physics = false
	runner.stop_tree()
	player.global_position = enemy.global_position + Vector2(40.0, 0.0)
	var health_before: int = player.health
	enemy._update_blackboard()
	var attack_status: int = runner.tick(0.1)
	_expect(attack_status == BTStatus.RUNNING, "nearby player starts attack action")
	_expect("Attack Right" in runner.active_path_titles, "behavior tree selects attack-right branch")
	_expect(player.health == health_before - enemy.attack_damage, "behavior-tree attack damages player")

	runner.restart_tree()
	runner.stop_tree()
	player.global_position = enemy.global_position + Vector2(500.0, 0.0)
	enemy._update_blackboard()
	var patrol_status: int = runner.tick(0.1)
	_expect(patrol_status == BTStatus.RUNNING, "distant player starts patrol action")
	_expect("Patrol Sequence" in runner.active_path_titles, "behavior tree falls back to patrol branch")
	_expect("Move Left" in runner.active_path_titles, "patrol begins with leftmost action")
	var home_position: Vector2 = enemy.home_position
	enemy.take_damage(enemy.max_health)
	_expect(not enemy.visible and enemy.respawn_remaining > 0.0 and not runner.is_running, "enemy death stops its behavior tree and starts local respawn state")
	enemy._physics_process(2.1)
	_expect(enemy.visible and enemy.health == enemy.max_health and enemy.global_position == home_position and runner.is_running, "enemy respawns and restarts its behavior tree without SceneTreeTimer")
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
