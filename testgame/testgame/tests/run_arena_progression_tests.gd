extends SceneTree

const ACTOR_SPECS := [
	{
		"actor_name": "EnemyScout",
		"tree_path": "res://behavior_trees/arena_scout_31.tres",
		"node_count": 31,
	},
	{
		"actor_name": "EnemySkirmisher",
		"tree_path": "res://behavior_trees/arena_skirmisher_61.tres",
		"node_count": 61,
	},
	{
		"actor_name": "EnemyHunter",
		"tree_path": "res://behavior_trees/arena_hunter_121.tres",
		"node_count": 121,
	},
	{
		"actor_name": "EnemyTactician",
		"tree_path": "res://behavior_trees/arena_tactician_241.tres",
		"node_count": 241,
	},
	{
		"actor_name": "EnemyCommander",
		"tree_path": "res://behavior_trees/arena_commander_364.tres",
		"node_count": 364,
	},
]

const PERMANENCE_FRAMES := 150

var passed := 0
var failed := 0
var arena_completed_emissions := 0
var original_tree_hashes: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_capture_original_tree_hashes()
	var packed := load("res://scenes/test_game.tscn") as PackedScene
	_expect(packed != null, "arena progression scene loads")
	if packed == null:
		_verify_tree_hashes_unchanged()
		_finish()
		return

	var arena := packed.instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame

	if arena.has_signal("arena_completed"):
		arena.connect("arena_completed", Callable(self, "_on_arena_completed"))
	_expect(arena.has_signal("arena_completed"), "arena exposes one completion signal")
	_expect(_has_property(arena, &"total_enemy_count"), "arena exposes total_enemy_count")
	_expect(_has_property(arena, &"remaining_enemy_count"), "arena exposes remaining_enemy_count")
	_expect(_has_property(arena, &"game_completed"), "arena exposes game_completed")
	if _has_property(arena, &"total_enemy_count"):
		_expect(int(arena.get("total_enemy_count")) == ACTOR_SPECS.size(), "arena declares five fixed enemies")
	if _has_property(arena, &"remaining_enemy_count"):
		_expect(int(arena.get("remaining_enemy_count")) == ACTOR_SPECS.size(), "all five enemies begin alive")
	if _has_property(arena, &"game_completed"):
		_expect(not bool(arena.get("game_completed")), "arena does not begin completed")

	var victory_panel := arena.find_child("VictoryPanel", true, false) as CanvasItem
	_expect(victory_panel != null, "arena contains VictoryPanel")
	if victory_panel != null:
		_expect(not victory_panel.visible, "VictoryPanel begins hidden")

	var player := arena.get_node_or_null("Player")
	_expect(player != null, "arena contains Player")
	if player != null:
		_test_infinite_player_health(player)

	var actors: Array[Node] = []
	var initial_positions: Dictionary = {}
	var runtime_paths := {}
	for spec_variant in ACTOR_SPECS:
		var spec: Dictionary = spec_variant
		var actor_name := String(spec["actor_name"])
		var actor := arena.get_node_or_null(actor_name)
		_expect(actor != null, "%s exists" % actor_name)
		if actor == null:
			continue
		actors.append(actor)
		initial_positions[actor_name] = actor.get("home_position") if _has_property(actor, &"home_position") else actor.global_position
		_validate_actor_contract(actor, spec, runtime_paths)

	_expect(actors.size() == ACTOR_SPECS.size(), "all five fixed actors are available")
	_expect(runtime_paths.size() == ACTOR_SPECS.size(), "each actor uses a unique behavior-tree resource path")

	if actors.size() == ACTOR_SPECS.size():
		await _defeat_actors_in_order(arena, player, actors)
		await _verify_defeat_is_permanent(actors)
		_verify_completed_state(arena, victory_panel, actors)
		await _reset_and_verify(arena, victory_panel, actors, initial_positions)

	arena.free()
	await process_frame
	await process_frame
	_verify_tree_hashes_unchanged()
	_finish()


func _capture_original_tree_hashes() -> void:
	for spec_variant in ACTOR_SPECS:
		var spec: Dictionary = spec_variant
		var tree_path := String(spec["tree_path"])
		var exists := FileAccess.file_exists(tree_path)
		_expect(exists, "%s exists before runtime" % tree_path.get_file())
		original_tree_hashes[tree_path] = FileAccess.get_sha256(tree_path) if exists else ""


func _validate_actor_contract(actor: Node, spec: Dictionary, runtime_paths: Dictionary) -> void:
	var actor_name := String(spec["actor_name"])
	var expected_path := String(spec["tree_path"])
	var expected_count := int(spec["node_count"])
	_expect(_has_property(actor, &"is_defeated"), "%s exposes is_defeated" % actor_name)
	_expect(_has_property(actor, &"respawns_enabled"), "%s exposes respawns_enabled" % actor_name)
	if _has_property(actor, &"is_defeated"):
		_expect(not bool(actor.get("is_defeated")), "%s begins undefeated" % actor_name)
	if _has_property(actor, &"respawns_enabled"):
		_expect(not bool(actor.get("respawns_enabled")), "%s has permanent defeat enabled" % actor_name)
	_expect(actor.has_signal("defeated"), "%s exposes defeated signal" % actor_name)
	_expect(actor.has_method("reset_for_round"), "%s exposes reset_for_round" % actor_name)

	var runner := actor.get_node_or_null("BehaviorTreeComponent")
	_expect(runner != null, "%s has BehaviorTreeComponent" % actor_name)
	if runner == null:
		return
	_expect(runner.get("agent") == actor, "%s runner resolves its parent Actor" % actor_name)
	var tree := runner.get("behavior_tree") as Resource
	_expect(tree != null, "%s has an assigned behavior tree" % actor_name)
	if tree == null:
		return
	var runtime_path := tree.resource_path
	_expect(runtime_path == expected_path, "%s binds %s" % [actor_name, expected_path.get_file()])
	_expect(not runtime_paths.has(runtime_path), "%s does not reuse another Actor's resource path" % actor_name)
	runtime_paths[runtime_path] = actor_name
	var nodes: Array = tree.get("nodes")
	_expect(nodes.size() == expected_count, "%s tree has exactly %d nodes" % [actor_name, expected_count])
	var validation_errors: PackedStringArray = tree.call("validate_tree")
	_expect(validation_errors.is_empty(), "%s tree passes structural validation: %s" % [actor_name, "; ".join(validation_errors)])
	var unresolved_methods := _unresolved_actor_methods(actor, nodes)
	_expect(unresolved_methods.is_empty(), "%s resolves every Action/Condition method: %s" % [actor_name, ", ".join(unresolved_methods)])


func _unresolved_actor_methods(actor: Node, nodes: Array) -> PackedStringArray:
	var unresolved := PackedStringArray()
	for node_variant in nodes:
		var node_resource := node_variant as Resource
		if node_resource == null:
			unresolved.append("<null node>")
			continue
		var node_type := String(node_resource.get("node_type"))
		if node_type != "Action" and node_type != "Condition":
			continue
		var parameters: Dictionary = node_resource.get("parameters")
		var key := "action_name" if node_type == "Action" else "condition_name"
		var method_name := String(parameters.get(key, "")).strip_edges()
		if method_name.is_empty():
			if node_type == "Condition" and parameters.has("blackboard_key"):
				continue
			unresolved.append("%s #%s has no %s" % [node_type, str(node_resource.get("id")), key])
			continue
		if not actor.has_method(method_name):
			unresolved.append("%s #%s -> %s" % [node_type, str(node_resource.get("id")), method_name])
	return unresolved


func _test_infinite_player_health(player: Node) -> void:
	_expect(_has_property(player, &"infinite_health"), "Player exposes infinite_health")
	if _has_property(player, &"infinite_health"):
		_expect(bool(player.get("infinite_health")), "Player infinite health is enabled")
	_expect(player.has_method("take_damage"), "Player exposes take_damage")
	if not player.has_method("take_damage"):
		return
	var health_before := int(player.get("health"))
	var position_before := (player as Node2D).global_position
	player.call("take_damage", 1_000_000)
	_expect(int(player.get("health")) == health_before, "large damage cannot reduce infinite Player health")
	_expect((player as Node2D).global_position == position_before, "large damage cannot respawn or move infinite-health Player")


func _defeat_actors_in_order(arena: Node, player: Node, actors: Array[Node]) -> void:
	for index in range(actors.size()):
		var actor := actors[index]
		var runner := actor.get_node_or_null("BehaviorTreeComponent")
		_expect(actor.has_method("take_damage"), "%s can receive Player attack damage" % actor.name)
		if not actor.has_method("take_damage") or player == null:
			continue
		await _attack_until_defeated(player, actor)
		await process_frame
		_expect(bool(actor.get("is_defeated")), "%s is defeated through the Player attack area" % actor.name)
		_expect(not actor.visible, "%s is hidden after defeat" % actor.name)
		if runner != null:
			_expect(not bool(runner.get("is_running")), "%s behavior tree stops after defeat" % actor.name)
		if _has_property(arena, &"remaining_enemy_count"):
			var expected_remaining := ACTOR_SPECS.size() - index - 1
			_expect(int(arena.get("remaining_enemy_count")) == expected_remaining, "remaining enemy count becomes %d" % expected_remaining)
		if _has_property(arena, &"game_completed"):
			_expect(bool(arena.get("game_completed")) == (index == actors.size() - 1), "completion state changes only on final defeat")
		if index < actors.size() - 1:
			_expect(arena_completed_emissions == 0, "completion signal is not emitted early")
	_expect(arena_completed_emissions == 1, "final enemy emits arena_completed exactly once")
	var final_actor: Node = actors.back()
	final_actor.call("take_damage", int(final_actor.get("max_health")) + 10_000)
	await process_frame
	_expect(arena_completed_emissions == 1, "repeated damage cannot emit arena_completed twice")


func _attack_until_defeated(player: Node, actor: Node) -> void:
	actor.set_physics_process(false)
	var attacks_used := 0
	while not bool(actor.get("is_defeated")) and attacks_used < 10:
		var health_before := int(actor.get("health"))
		actor.set("velocity", Vector2.ZERO)
		(player as Node2D).global_position = (actor as Node2D).global_position + Vector2(-40.0, 0.0)
		player.set("velocity", Vector2.ZERO)
		player.set("facing", 1)
		await physics_frame
		player.call("_start_attack")
		await physics_frame
		await physics_frame
		player.call("_update_attack", float(player.get("attack_duration")) + 0.01)
		await process_frame
		attacks_used += 1
		_expect(int(actor.get("health")) < health_before or bool(actor.get("is_defeated")), "%s loses health to Player attack %d" % [actor.name, attacks_used])
	_expect(attacks_used < 10, "%s can be defeated with the configured Player attack" % actor.name)


func _verify_defeat_is_permanent(actors: Array[Node]) -> void:
	for _frame in range(PERMANENCE_FRAMES):
		await physics_frame
	for actor in actors:
		_expect(bool(actor.get("is_defeated")), "%s remains defeated beyond the former respawn window" % actor.name)
		_expect(not actor.visible, "%s does not reappear automatically" % actor.name)
		var runner := actor.get_node_or_null("BehaviorTreeComponent")
		if runner != null:
			_expect(not bool(runner.get("is_running")), "%s tree remains stopped while defeated" % actor.name)


func _verify_completed_state(arena: Node, victory_panel: CanvasItem, actors: Array[Node]) -> void:
	if _has_property(arena, &"total_enemy_count"):
		_expect(int(arena.get("total_enemy_count")) == actors.size(), "total enemy count remains fixed after completion")
	if _has_property(arena, &"remaining_enemy_count"):
		_expect(int(arena.get("remaining_enemy_count")) == 0, "no enemies remain after completion")
	if _has_property(arena, &"game_completed"):
		_expect(bool(arena.get("game_completed")), "arena enters completed state")
	if victory_panel != null:
		_expect(victory_panel.visible, "VictoryPanel is visible after completion")


func _reset_and_verify(arena: Node, victory_panel: CanvasItem, actors: Array[Node], initial_positions: Dictionary) -> void:
	_expect(arena.has_method("_reset_arena"), "arena exposes reset operation")
	if not arena.has_method("_reset_arena"):
		return
	arena.call("_reset_arena")
	if _has_property(arena, &"total_enemy_count"):
		_expect(int(arena.get("total_enemy_count")) == actors.size(), "reset preserves five-enemy total")
	if _has_property(arena, &"remaining_enemy_count"):
		_expect(int(arena.get("remaining_enemy_count")) == actors.size(), "reset restores all five enemies")
	if _has_property(arena, &"game_completed"):
		_expect(not bool(arena.get("game_completed")), "reset clears completion state")
	if victory_panel != null:
		_expect(not victory_panel.visible, "reset hides VictoryPanel")
	_expect(arena_completed_emissions == 1, "reset does not emit another completion signal")
	for actor in actors:
		_expect(not bool(actor.get("is_defeated")), "%s reset clears defeated state" % actor.name)
		_expect(actor.visible, "%s reset restores visibility" % actor.name)
		_expect(int(actor.get("health")) == int(actor.get("max_health")), "%s reset restores full health" % actor.name)
		var expected_position: Vector2 = initial_positions.get(String(actor.name), actor.global_position)
		_expect(actor.global_position.distance_to(expected_position) < 2.0, "%s reset restores spawn position" % actor.name)
		var runner := actor.get_node_or_null("BehaviorTreeComponent")
		_expect(runner != null and bool(runner.get("is_running")), "%s reset restarts its behavior tree" % actor.name)
		_expect(not bool(actor.get("respawns_enabled")), "%s reset keeps automatic respawn disabled" % actor.name)
	await process_frame
	for actor in actors:
		var collision := actor.get_node_or_null("CollisionShape2D") as CollisionShape2D
		_expect(collision != null and not collision.disabled, "%s reset restores collision" % actor.name)


func _verify_tree_hashes_unchanged() -> void:
	for spec_variant in ACTOR_SPECS:
		var spec: Dictionary = spec_variant
		var tree_path := String(spec["tree_path"])
		var before_hash := String(original_tree_hashes.get(tree_path, ""))
		var exists := FileAccess.file_exists(tree_path)
		var after_hash := FileAccess.get_sha256(tree_path) if exists else ""
		_expect(exists and not before_hash.is_empty() and after_hash == before_hash, "%s SHA-256 is unchanged after play/reset" % tree_path.get_file())


func _has_property(object: Object, property_name: StringName) -> bool:
	for property_variant in object.get_property_list():
		var property: Dictionary = property_variant
		if StringName(property.get("name", "")) == property_name:
			return true
	return false


func _on_arena_completed() -> void:
	arena_completed_emissions += 1


func _finish() -> void:
	print("BT_ARENA_PROGRESSION_TEST_SUMMARY passed=%d failed=%d" % [passed, failed])
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
