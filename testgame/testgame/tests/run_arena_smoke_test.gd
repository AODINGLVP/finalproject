extends SceneTree

const ENEMY_NAMES := ["EnemyScout", "EnemySkirmisher", "EnemyHunter", "EnemyTactician", "EnemyCommander"]
const EXPECTED_TREE_SIZES := [31, 61, 121, 241, 364]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/test_game.tscn") as PackedScene
	if packed == null:
		printerr("FAIL: arena smoke scene load")
		quit(1)
		return
	var game := packed.instantiate()
	root.add_child(game)
	for frame in range(180):
		await physics_frame
	var active_runners := 0
	var actual_tree_sizes: Array[int] = []
	var all_alive := true
	for enemy_name in ENEMY_NAMES:
		var enemy = game.get_node(enemy_name)
		var runner = game.get_node("%s/BehaviorTreeComponent" % enemy_name)
		if not runner.active_path_ids.is_empty():
			active_runners += 1
		actual_tree_sizes.append(runner.behavior_tree.nodes.size())
		all_alive = all_alive and not enemy.is_defeated and enemy.visible and enemy.health > 0
	var hud_text: String = game.get_node("UI/TopPanel/TopContent/PlayerStatus").text
	var victory_panel: CanvasItem = game.get_node("UI/VictoryPanel")
	var arena_ready: bool = game.total_enemy_count == 5 and game.remaining_enemy_count == 5 and not game.game_completed and not victory_panel.visible
	var hud_ready := "INFINITE" in hud_text and "ENEMIES 5/5" in hud_text
	var screenshot := root.get_texture().get_image()
	var screenshot_path := "res://test_results/arena_multiscale_five_enemies.png"
	var screenshot_error := screenshot.save_png(screenshot_path)
	print("ARENA_SMOKE active_runners=%d tree_sizes=%s all_alive=%s hud_ready=%s screenshot=%s" % [active_runners, str(actual_tree_sizes), str(all_alive), str(hud_ready), screenshot_path])
	game.free()
	await process_frame
	await process_frame
	_quit_with_result.call_deferred(0 if active_runners == 5 and actual_tree_sizes == EXPECTED_TREE_SIZES and all_alive and arena_ready and hud_ready and screenshot_error == OK else 1)


func _quit_with_result(code: int) -> void:
	quit(code)
