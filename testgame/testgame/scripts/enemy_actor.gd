extends CharacterBody2D

const BTStatus = preload("res://addons/behavior_tree_editor/runtime/bt_status.gd")

@export var speed := 95.0
@export var gravity := 900.0
@export var move_duration := 1.2
@export var attack_duration := 0.35
@export var attack_range := 70.0
@export var attack_damage := 1
@export var idle_texture: Texture2D
@export var attack_texture: Texture2D

@onready var sprite: Sprite2D = $Sprite2D

var health := 3
var facing := -1


func _ready() -> void:
	add_to_group("enemies")
	sprite.texture = idle_texture


func _physics_process(delta: float) -> void:
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


func take_damage(amount: int) -> void:
	health -= amount
	modulate = Color(1.0, 0.6, 0.6)
	if health <= 0:
		queue_free()
		return
	await get_tree().create_timer(0.08).timeout
	modulate = Color.WHITE


func _move_action(blackboard: Dictionary, delta: float, node: Resource, direction: int) -> int:
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
		board["player_on_left"] = false
		board["player_on_right"] = false
		return
	var offset: Vector2 = nearest_player.global_position - global_position
	board["player_in_range"] = abs(offset.x) <= attack_range and abs(offset.y) <= 48.0
	board["player_on_left"] = offset.x < 0.0
	board["player_on_right"] = offset.x >= 0.0
