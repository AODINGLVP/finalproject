extends CharacterBody2D

const BTStatus = preload("res://addons/behavior_tree_editor/runtime/bt_status.gd")
const EnemyProjectileScene = preload("res://scenes/enemy_projectile.tscn")

@export var speed := 95.0
@export var gravity := 900.0
@export var move_duration := 1.2
@export var attack_duration := 0.35
@export var attack_range := 70.0
@export var attack_damage := 1
@export var max_health := 6
@export var detection_range := 330.0
@export var lose_target_range := 460.0
@export var chase_speed := 145.0
@export var retreat_speed := 175.0
@export var decision_duration := 0.22
@export var search_duration := 0.85
@export var heal_duration := 0.65
@export var jump_velocity := 410.0
@export var climb_speed := 145.0
@export var idle_texture: Texture2D
@export var attack_texture: Texture2D

@onready var sprite: Sprite2D = $Sprite2D

var health := 6
var facing := -1
var home_position := Vector2.ZERO
var current_behavior := "Initialize"
var target_locked := false
var damage_flash_remaining := 0.0
var respawn_remaining := 0.0
var alert_level := 0.0


func _ready() -> void:
	add_to_group("enemies")
	sprite.texture = idle_texture
	health = max_health
	home_position = global_position


func _physics_process(delta: float) -> void:
	if respawn_remaining > 0.0:
		respawn_remaining = maxf(0.0, respawn_remaining - delta)
		if respawn_remaining <= 0.0:
			_finish_respawn()
		return
	if damage_flash_remaining > 0.0:
		damage_flash_remaining = maxf(0.0, damage_flash_remaining - delta)
		if damage_flash_remaining <= 0.0:
			modulate = Color.WHITE
	velocity.y += gravity * delta
	_update_blackboard()
	move_and_slide()


func move_left(blackboard: Dictionary, delta: float, node: Resource) -> int:
	return _move_action(blackboard, delta, node, -1)


func move_right(blackboard: Dictionary, delta: float, node: Resource) -> int:
	return _move_action(blackboard, delta, node, 1)


func attack_left(blackboard: Dictionary, delta: float, node: Resource) -> int:
	return _attack_action(blackboard, delta, node, -1)


func attack_right(blackboard: Dictionary, delta: float, node: Resource) -> int:
	return _attack_action(blackboard, delta, node, 1)


func is_critical_and_threatened(blackboard: Dictionary, _delta: float, _node: Resource) -> int:
	return BTStatus.SUCCESS if bool(blackboard.get("critical_health", false)) and bool(blackboard.get("player_detected", false)) else BTStatus.FAILURE


func can_attack_left(blackboard: Dictionary, _delta: float, _node: Resource) -> int:
	return BTStatus.SUCCESS if bool(blackboard.get("player_in_range", false)) and bool(blackboard.get("player_on_left", false)) else BTStatus.FAILURE


func can_attack_right(blackboard: Dictionary, _delta: float, _node: Resource) -> int:
	return BTStatus.SUCCESS if bool(blackboard.get("player_in_range", false)) and bool(blackboard.get("player_on_right", false)) else BTStatus.FAILURE


func should_chase(blackboard: Dictionary, _delta: float, _node: Resource) -> int:
	return BTStatus.SUCCESS if bool(blackboard.get("player_detected", false)) and not bool(blackboard.get("player_in_range", false)) else BTStatus.FAILURE


func is_player_detected(blackboard: Dictionary, _delta: float, _node: Resource) -> int:
	return BTStatus.SUCCESS if bool(blackboard.get("player_detected", false)) else BTStatus.FAILURE


func has_last_known_position(blackboard: Dictionary, _delta: float, _node: Resource) -> int:
	return BTStatus.SUCCESS if bool(blackboard.get("has_last_known_position", false)) else BTStatus.FAILURE


func should_dodge(blackboard: Dictionary, _delta: float, _node: Resource) -> int:
	return BTStatus.SUCCESS if bool(blackboard.get("player_attacking", false)) and float(blackboard.get("player_distance", INF)) <= attack_range + 55.0 else BTStatus.FAILURE


func can_melee(blackboard: Dictionary, _delta: float, _node: Resource) -> int:
	return BTStatus.SUCCESS if bool(blackboard.get("player_in_range", false)) else BTStatus.FAILURE


func should_apply_pressure(blackboard: Dictionary, _delta: float, _node: Resource) -> int:
	var distance := float(blackboard.get("player_distance", INF))
	return BTStatus.SUCCESS if bool(blackboard.get("player_detected", false)) and distance > attack_range and distance <= 190.0 else BTStatus.FAILURE


func should_return_home(blackboard: Dictionary, _delta: float, _node: Resource) -> int:
	return BTStatus.SUCCESS if not bool(blackboard.get("player_detected", false)) and not bool(blackboard.get("has_last_known_position", false)) and float(blackboard.get("home_distance", 0.0)) > 150.0 else BTStatus.FAILURE


func can_use_ranged_attack(blackboard: Dictionary, _delta: float, _node: Resource) -> int:
	var distance := float(blackboard.get("player_distance", INF))
	return BTStatus.SUCCESS if bool(blackboard.get("player_detected", false)) and distance > 190.0 and distance <= 300.0 else BTStatus.FAILURE


func has_obstacle_ahead(blackboard: Dictionary, _delta: float, _node: Resource) -> int:
	return BTStatus.SUCCESS if bool(blackboard.get("obstacle_ahead", false)) else BTStatus.FAILURE


func should_climb_to_player(blackboard: Dictionary, _delta: float, _node: Resource) -> int:
	return BTStatus.SUCCESS if bool(blackboard.get("player_detected", false)) and bool(blackboard.get("player_above", false)) and bool(blackboard.get("near_ladder", false)) else BTStatus.FAILURE


func retreat_from_player(blackboard: Dictionary, delta: float, node: Resource) -> int:
	current_behavior = "Retreat"
	var target_x := float(blackboard.get("player_x", global_position.x))
	var direction := -1 if target_x >= global_position.x else 1
	return _timed_move(blackboard, delta, node, direction, retreat_speed, decision_duration)


func heal_self(blackboard: Dictionary, delta: float, node: Resource) -> int:
	current_behavior = "Heal"
	velocity.x = 0.0
	sprite.texture = idle_texture
	var key := _action_key(node)
	var elapsed := float(blackboard.get(key, 0.0)) + delta
	blackboard[key] = elapsed
	if elapsed < heal_duration:
		modulate = Color(0.55, 1.0, 0.7)
		return BTStatus.RUNNING
	health = mini(max_health, health + 3)
	blackboard.erase(key)
	modulate = Color.WHITE
	return BTStatus.SUCCESS


func chase_player(blackboard: Dictionary, delta: float, node: Resource) -> int:
	current_behavior = "Chase"
	var target_x := float(blackboard.get("player_x", global_position.x))
	var direction := -1 if target_x < global_position.x else 1
	return _timed_move(blackboard, delta, node, direction, chase_speed, decision_duration)


func dodge_left(blackboard: Dictionary, delta: float, node: Resource) -> int:
	current_behavior = "Dodge Left"
	return _timed_move(blackboard, delta, node, -1, retreat_speed * 1.15, 0.16)


func dodge_right(blackboard: Dictionary, delta: float, node: Resource) -> int:
	current_behavior = "Dodge Right"
	return _timed_move(blackboard, delta, node, 1, retreat_speed * 1.15, 0.16)


func brace(blackboard: Dictionary, delta: float, node: Resource) -> int:
	return _timed_stationary_action(blackboard, delta, node, "Brace", 0.14)


func light_attack_left(blackboard: Dictionary, delta: float, node: Resource) -> int:
	return _attack_action(blackboard, delta, node, -1, 0.22, 1, "Light Attack Left")


func light_attack_right(blackboard: Dictionary, delta: float, node: Resource) -> int:
	return _attack_action(blackboard, delta, node, 1, 0.22, 1, "Light Attack Right")


func heavy_attack_left(blackboard: Dictionary, delta: float, node: Resource) -> int:
	return _attack_action(blackboard, delta, node, -1, 0.48, 2, "Heavy Attack Left")


func heavy_attack_right(blackboard: Dictionary, delta: float, node: Resource) -> int:
	return _attack_action(blackboard, delta, node, 1, 0.48, 2, "Heavy Attack Right")


func strafe_left(blackboard: Dictionary, delta: float, node: Resource) -> int:
	current_behavior = "Strafe Left"
	return _timed_move(blackboard, delta, node, -1, speed * 0.8, 0.24)


func strafe_right(blackboard: Dictionary, delta: float, node: Resource) -> int:
	current_behavior = "Strafe Right"
	return _timed_move(blackboard, delta, node, 1, speed * 0.8, 0.24)


func advance_cautiously(blackboard: Dictionary, delta: float, node: Resource) -> int:
	current_behavior = "Cautious Advance"
	return _move_toward_player(blackboard, delta, node, speed * 0.75, 0.28)


func advance_aggressively(blackboard: Dictionary, delta: float, node: Resource) -> int:
	current_behavior = "Aggressive Advance"
	return _move_toward_player(blackboard, delta, node, chase_speed * 1.12, 0.24)


func signal_allies(blackboard: Dictionary, _delta: float, _node: Resource) -> int:
	current_behavior = "Signal Allies"
	alert_level = 1.0
	blackboard["alert_level"] = alert_level
	return BTStatus.SUCCESS


func scan_for_player(blackboard: Dictionary, delta: float, node: Resource) -> int:
	return _timed_stationary_action(blackboard, delta, node, "Scan", 0.18)


func search_sweep_left(blackboard: Dictionary, delta: float, node: Resource) -> int:
	current_behavior = "Search Left"
	return _timed_move(blackboard, delta, node, -1, speed * 0.62, 0.34)


func search_sweep_right(blackboard: Dictionary, delta: float, node: Resource) -> int:
	current_behavior = "Search Right"
	return _timed_move(blackboard, delta, node, 1, speed * 0.62, 0.34)


func return_home(blackboard: Dictionary, delta: float, node: Resource) -> int:
	current_behavior = "Return Home"
	var distance := home_position.x - global_position.x
	if absf(distance) <= 18.0:
		velocity.x = 0.0
		return BTStatus.SUCCESS
	return _timed_move(blackboard, delta, node, -1 if distance < 0.0 else 1, speed, 0.3)


func observe_area(blackboard: Dictionary, delta: float, node: Resource) -> int:
	return _timed_stationary_action(blackboard, delta, node, "Observe", 0.22)


func idle_guard(blackboard: Dictionary, delta: float, node: Resource) -> int:
	return _timed_stationary_action(blackboard, delta, node, "Guard Idle", 0.3)


func aim_at_player(blackboard: Dictionary, delta: float, node: Resource) -> int:
	var target_x := float(blackboard.get("player_x", global_position.x))
	facing = -1 if target_x < global_position.x else 1
	sprite.flip_h = facing < 0
	return _timed_stationary_action(blackboard, delta, node, "Aim Ranged", 0.16)


func fire_projectile(blackboard: Dictionary, _delta: float, _node: Resource) -> int:
	current_behavior = "Ranged Attack"
	var projectile = EnemyProjectileScene.instantiate()
	var parent := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	parent.add_child(projectile)
	var target := Vector2(float(blackboard.get("player_x", global_position.x + facing * 100.0)), float(blackboard.get("player_y", global_position.y)))
	projectile.configure(global_position + Vector2(facing * 30.0, -8.0), target, attack_damage)
	return BTStatus.SUCCESS


func jump_over_obstacle(blackboard: Dictionary, delta: float, node: Resource) -> int:
	current_behavior = "Jump Obstacle"
	var key := _action_key(node)
	var launched_key := "%s_launched" % key
	var elapsed := float(blackboard.get(key, 0.0)) + delta
	var direction := int(blackboard.get("obstacle_direction", facing))
	if not bool(blackboard.get(launched_key, false)):
		blackboard[launched_key] = true
		velocity.y = -jump_velocity
	velocity.x = float(direction) * chase_speed
	blackboard[key] = elapsed
	if elapsed > 0.2 and is_on_floor():
		blackboard.erase(key)
		blackboard.erase(launched_key)
		return BTStatus.SUCCESS
	if elapsed >= 1.5:
		blackboard.erase(key)
		blackboard.erase(launched_key)
		return BTStatus.FAILURE
	return BTStatus.RUNNING


func climb_toward_player(blackboard: Dictionary, delta: float, node: Resource) -> int:
	current_behavior = "Climb Ladder"
	var ladder_x := float(blackboard.get("ladder_x", global_position.x))
	var horizontal := ladder_x - global_position.x
	velocity.x = clampf(horizontal * 4.0, -speed, speed)
	velocity.y = -climb_speed if absf(horizontal) <= 24.0 else minf(velocity.y, 0.0)
	var key := _action_key(node)
	var elapsed := float(blackboard.get(key, 0.0)) + delta
	blackboard[key] = elapsed
	if not bool(blackboard.get("player_above", false)) or elapsed >= 2.4:
		blackboard.erase(key)
		return BTStatus.SUCCESS
	return BTStatus.RUNNING


func search_last_known(blackboard: Dictionary, delta: float, node: Resource) -> int:
	current_behavior = "Search"
	var target_x := float(blackboard.get("last_known_player_x", home_position.x))
	var distance := target_x - global_position.x
	var direction := -1 if distance < 0.0 else 1
	facing = direction
	sprite.flip_h = facing < 0
	velocity.x = 0.0 if absf(distance) < 14.0 else float(direction) * speed * 0.7
	var key := _action_key(node)
	var elapsed := float(blackboard.get(key, 0.0)) + delta
	blackboard[key] = elapsed
	if elapsed < search_duration:
		return BTStatus.RUNNING
	velocity.x = 0.0
	blackboard.erase(key)
	blackboard["has_last_known_position"] = false
	return BTStatus.SUCCESS


func take_damage(amount: int) -> void:
	health -= amount
	modulate = Color(1.0, 0.6, 0.6)
	if health <= 0:
		visible = false
		$CollisionShape2D.set_deferred("disabled", true)
		var component := get_node_or_null("BehaviorTreeComponent")
		if component != null:
			component.stop_tree()
		velocity = Vector2.ZERO
		respawn_remaining = 2.0
		return
	damage_flash_remaining = 0.08


func _finish_respawn() -> void:
	health = max_health
	global_position = home_position
	visible = true
	modulate = Color.WHITE
	$CollisionShape2D.set_deferred("disabled", false)
	var component := get_node_or_null("BehaviorTreeComponent")
	if component != null:
		component.restart_tree()


func _move_action(blackboard: Dictionary, delta: float, node: Resource, direction: int) -> int:
	current_behavior = "Patrol Left" if direction < 0 else "Patrol Right"
	var key := _action_key(node)
	var elapsed: float = blackboard.get(key, 0.0)
	facing = direction
	sprite.texture = idle_texture
	sprite.flip_h = facing < 0
	velocity.x = speed * direction
	elapsed += delta
	blackboard[key] = elapsed
	if elapsed >= move_duration:
		velocity.x = 0.0
		blackboard.erase(key)
		return BTStatus.SUCCESS
	return BTStatus.RUNNING


func _attack_action(blackboard: Dictionary, delta: float, node: Resource, direction: int, duration := -1.0, damage := -1, behavior_label := "") -> int:
	current_behavior = behavior_label if not behavior_label.is_empty() else ("Attack Left" if direction < 0 else "Attack Right")
	var key := _action_key(node)
	var hit_key := "%s_hit" % key
	var elapsed: float = blackboard.get(key, 0.0)
	facing = direction
	velocity.x = 0.0
	sprite.texture = attack_texture
	sprite.flip_h = facing < 0
	if not blackboard.get(hit_key, false):
		_try_hit_player(attack_damage if damage < 0 else damage)
		blackboard[hit_key] = true
	elapsed += delta
	blackboard[key] = elapsed
	var active_duration := attack_duration if duration < 0.0 else duration
	if elapsed >= active_duration:
		sprite.texture = idle_texture
		blackboard.erase(key)
		blackboard.erase(hit_key)
		return BTStatus.SUCCESS
	return BTStatus.RUNNING


func _try_hit_player(damage := -1) -> void:
	for player in get_tree().get_nodes_in_group("player"):
		var offset: Vector2 = player.global_position - global_position
		var is_in_front: bool = (offset.x < 0.0 and facing < 0) or (offset.x > 0.0 and facing > 0) or is_zero_approx(offset.x)
		if is_in_front and abs(offset.x) <= attack_range and abs(offset.y) <= 42.0:
			if player.has_method("take_damage"):
				player.take_damage(attack_damage if damage < 0 else damage)


func _action_key(node: Resource) -> String:
	return "enemy_action_%s" % str(node.get("id"))


func _timed_move(blackboard: Dictionary, delta: float, node: Resource, direction: int, action_speed: float, duration: float) -> int:
	var key := _action_key(node)
	var elapsed := float(blackboard.get(key, 0.0)) + delta
	facing = direction
	sprite.texture = idle_texture
	sprite.flip_h = facing < 0
	velocity.x = action_speed * float(direction)
	blackboard[key] = elapsed
	if elapsed >= duration:
		blackboard.erase(key)
		return BTStatus.SUCCESS
	return BTStatus.RUNNING


func _move_toward_player(blackboard: Dictionary, delta: float, node: Resource, action_speed: float, duration: float) -> int:
	var target_x := float(blackboard.get("player_x", global_position.x))
	return _timed_move(blackboard, delta, node, -1 if target_x < global_position.x else 1, action_speed, duration)


func _timed_stationary_action(blackboard: Dictionary, delta: float, node: Resource, label: String, duration: float) -> int:
	current_behavior = label
	velocity.x = 0.0
	sprite.texture = idle_texture
	var key := _action_key(node)
	var elapsed := float(blackboard.get(key, 0.0)) + delta
	blackboard[key] = elapsed
	if elapsed < duration:
		return BTStatus.RUNNING
	blackboard.erase(key)
	return BTStatus.SUCCESS


func _update_blackboard() -> void:
	var component := get_node_or_null("BehaviorTreeComponent")
	if component == null:
		return
	var nearest_player: Node2D = null
	var nearest_distance := INF
	for player in get_tree().get_nodes_in_group("player"):
		if not (player is Node2D):
			continue
		var distance := global_position.distance_to(player.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_player = player
	var board: Dictionary = component.blackboard
	var obstacle_direction := facing
	if nearest_player != null:
		obstacle_direction = -1 if nearest_player.global_position.x < global_position.x else 1
	board["obstacle_direction"] = obstacle_direction
	board["obstacle_ahead"] = _obstacle_ahead(obstacle_direction)
	var ladder := _nearest_ladder()
	board["near_ladder"] = ladder != null
	board["ladder_x"] = ladder.global_position.x if ladder != null else global_position.x
	if nearest_player == null:
		board["player_in_range"] = false
		board["player_detected"] = false
		board["player_on_left"] = false
		board["player_on_right"] = false
		target_locked = false
		return
	var offset: Vector2 = nearest_player.global_position - global_position
	var player_is_cloaked := bool(nearest_player.get("cloaked"))
	var active_detection_range := lose_target_range if target_locked else detection_range
	target_locked = not player_is_cloaked and nearest_distance <= active_detection_range
	board["player_in_range"] = not player_is_cloaked and abs(offset.x) <= attack_range and abs(offset.y) <= 48.0
	board["player_detected"] = target_locked
	board["player_on_left"] = offset.x < 0.0
	board["player_on_right"] = offset.x >= 0.0
	board["player_x"] = nearest_player.global_position.x
	board["player_y"] = nearest_player.global_position.y
	board["player_distance"] = nearest_distance
	board["player_above"] = nearest_player.global_position.y < global_position.y - 65.0
	board["player_attacking"] = float(nearest_player.get("attack_timer")) > 0.0
	board["player_health"] = int(nearest_player.get("health"))
	board["home_distance"] = global_position.distance_to(home_position)
	board["nearby_allies"] = _nearby_ally_count()
	board["alert_level"] = alert_level
	board["health"] = health
	board["health_ratio"] = float(health) / float(max_health)
	board["low_health"] = health <= 3
	board["critical_health"] = health <= 1
	if board["player_detected"]:
		board["last_known_player_x"] = nearest_player.global_position.x
		board["has_last_known_position"] = true


func _nearby_ally_count() -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy != self and enemy is Node2D and enemy.visible and global_position.distance_to(enemy.global_position) <= 260.0:
			count += 1
	return count


func _nearest_ladder() -> Node2D:
	var nearest: Node2D
	var best_distance := INF
	for ladder in get_tree().get_nodes_in_group("ladders"):
		if not (ladder is Node2D):
			continue
		var horizontal_distance := absf(global_position.x - ladder.global_position.x)
		var vertical_distance := absf(global_position.y - ladder.global_position.y)
		if horizontal_distance > 150.0 or vertical_distance > 170.0:
			continue
		var distance := horizontal_distance + vertical_distance * 0.25
		if distance < best_distance:
			nearest = ladder
			best_distance = distance
	return nearest


func _obstacle_ahead(direction: int) -> bool:
	if not is_inside_tree():
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(float(direction) * 72.0, 0.0), 1, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and is_instance_valid(hit.get("collider")) and (hit.get("collider") as Node).is_in_group("obstacles")
