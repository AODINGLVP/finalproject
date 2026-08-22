extends SceneTree


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
	for enemy_name in ["EnemyA", "EnemyB", "EnemyC"]:
		var runner = game.get_node("%s/BehaviorTreeComponent" % enemy_name)
		if not runner.active_path_ids.is_empty():
			active_runners += 1
	var hud_text: String = game.get_node("UI/TopPanel/TopContent/PlayerStatus").text
	var complex_alive: bool = game.get_node("EnemyB").health > 0 and game.get_node("EnemyC").health > 0
	var screenshot := root.get_texture().get_image()
	var screenshot_path := "res://test_results/arena_playable_241.png"
	var screenshot_error := screenshot.save_png(screenshot_path)
	print("ARENA_SMOKE active_runners=%d player_hud_chars=%d complex_alive=%s screenshot=%s" % [active_runners, hud_text.length(), str(complex_alive), screenshot_path])
	game.free()
	await process_frame
	await process_frame
	_quit_with_result.call_deferred(0 if active_runners == 3 and hud_text.length() > 20 and complex_alive and screenshot_error == OK else 1)


func _quit_with_result(code: int) -> void:
	quit(code)
