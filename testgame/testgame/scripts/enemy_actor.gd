extends CharacterBody2D

const BTStatus = preload("res://addons/behavior_tree_editor/runtime/bt_status.gd")

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


func _attack_action(blackboard: Dictionary, delta: float, node: Resource, direction: int) -> int:
	current_behavior = "Attack Left" if direction < 0 else "Attack Right"
	var key := _action_key(node)
	var hit_key := "%s_hit" % key
	var elapsed: float = blackboard.get(key, 0.0)
	facing = direction
	velocity.x = 0.0
	sprite.texture = attack_texture
	sprite.flip_h = facing < 0
	if not blackboard.get(hit_key, false):
		_try_hit_player()
		blackboard[hit_key] = true
	elapsed += delta
	blackboard[key] = elapsed
	if elapsed >= attack_duration:
		sprite.texture = idle_texture
		blackboard.erase(key)
		blackboard.erase(hit_key)
		return BTStatus.SUCCESS
	return BTStatus.RUNNING


func _try_hit_player() -> void:
	for player in get_tree().get_nodes_in_group("player"):
		var offset: Vector2 = player.global_position - global_position
		var is_in_front: bool = (offset.x < 0.0 and facing < 0) or (offset.x > 0.0 and facing > 0) or is_zero_approx(offset.x)
		if is_in_front and abs(offset.x) <= attack_range and abs(offset.y) <= 42.0:
			if player.has_method("take_damage"):
				player.take_damage(attack_damage)


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
	board["health"] = health
	board["health_ratio"] = float(health) / float(max_health)
	board["low_health"] = health <= 3
	board["critical_health"] = health <= 1
	if board["player_detected"]:
		board["last_known_player_x"] = nearest_player.global_position.x
		board["has_last_known_position"] = true
