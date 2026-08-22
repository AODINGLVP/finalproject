extends CharacterBody2D

@export var speed := 260.0
@export var gravity := 900.0
@export var attack_duration := 0.18
@export var attack_damage := 1
@export var max_health := 8
@export var dash_speed := 620.0
@export var dash_duration := 0.16
@export var dash_cost := 35.0
@export var stamina_recovery := 24.0
@export var jump_velocity := 390.0
@export var climb_speed := 175.0
@export var idle_texture: Texture2D
@export var attack_texture: Texture2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_area: Area2D = $AttackArea

var facing := 1
var health := 8
var stamina := 100.0
var healing_charges := 2
var attack_timer := 0.0
var dash_timer := 0.0
var invulnerability_timer := 0.0
var cloak_timer := 0.0
var cloak_cooldown := 0.0
var cloaked := false
var hit_targets: Array[Node] = []
var spawn_position := Vector2.ZERO
var damage_flash_remaining := 0.0


func _ready() -> void:
	add_to_group("player")
	attack_area.monitoring = false
	sprite.texture = idle_texture
	health = max_health
	spawn_position = global_position


func _physics_process(delta: float) -> void:
	invulnerability_timer = maxf(0.0, invulnerability_timer - delta)
	if damage_flash_remaining > 0.0:
		damage_flash_remaining = maxf(0.0, damage_flash_remaining - delta)
		if damage_flash_remaining <= 0.0:
			modulate = Color.WHITE
	cloak_cooldown = maxf(0.0, cloak_cooldown - delta)
	if Input.is_action_just_pressed("stealth") and cloak_cooldown <= 0.0:
		cloak_timer = 2.0
		cloak_cooldown = 5.0
		cloaked = true
		self_modulate = Color(0.55, 0.85, 1.0, 0.42)
	if cloak_timer > 0.0:
		cloak_timer -= delta
		if cloak_timer <= 0.0:
			cloaked = false
			self_modulate = Color.WHITE
	stamina = minf(100.0, stamina + stamina_recovery * delta)
	var vertical_input := Input.get_axis("move_up", "move_down")
	var ladder := _nearby_ladder()
	var climbing := ladder != null and not is_zero_approx(vertical_input)
	var direction: float = Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		facing = -1 if direction < 0.0 else 1
		sprite.flip_h = facing < 0
	if Input.is_action_just_pressed("move_up") and is_on_floor() and ladder == null:
		velocity.y = -jump_velocity
	if Input.is_action_just_pressed("dash") and dash_timer <= 0.0 and stamina >= dash_cost:
		dash_timer = dash_duration
		stamina -= dash_cost
		invulnerability_timer = dash_duration
	if Input.is_action_just_pressed("heal") and healing_charges > 0 and health < max_health:
		healing_charges -= 1
		health = mini(max_health, health + 3)
	if climbing:
		velocity.x = (ladder.global_position.x - global_position.x) * 5.0
		velocity.y = vertical_input * climb_speed
	elif dash_timer > 0.0:
		dash_timer -= delta
		velocity.x = float(facing) * dash_speed
	else:
		velocity.x = direction * speed
		velocity.y += gravity * delta
	move_and_slide()

	if Input.is_action_just_pressed("attack"):
		_start_attack()
	_update_attack(delta)


func _nearby_ladder() -> Node2D:
	var nearest: Node2D
	var nearest_distance := INF
	for ladder in get_tree().get_nodes_in_group("ladders"):
		if not (ladder is Node2D):
			continue
		var offset: Vector2 = global_position - ladder.global_position
		if absf(offset.x) > 44.0 or absf(offset.y) > 120.0:
			continue
		var distance: float = offset.length_squared()
		if distance < nearest_distance:
			nearest = ladder
			nearest_distance = distance
	return nearest


func _start_attack() -> void:
	attack_timer = attack_duration
	hit_targets.clear()
	sprite.texture = attack_texture
	sprite.flip_h = facing < 0
	attack_area.position.x = 42.0 * facing
	attack_area.monitoring = true


func _update_attack(delta: float) -> void:
	if attack_timer <= 0.0:
		return
	for body in attack_area.get_overlapping_bodies():
		if body.is_in_group("enemies") and not hit_targets.has(body):
			hit_targets.append(body)
			if body.has_method("take_damage"):
				body.take_damage(attack_damage)
	attack_timer -= delta
	if attack_timer <= 0.0:
		attack_area.monitoring = false
		sprite.texture = idle_texture


func take_damage(amount: int) -> void:
	if invulnerability_timer > 0.0:
		return
	health -= amount
	invulnerability_timer = 0.35
	modulate = Color(1.0, 0.65, 0.65)
	if health <= 0:
		health = max_health
		stamina = 100.0
		healing_charges = 2
		cloaked = false
		self_modulate = Color.WHITE
		global_position = spawn_position
	damage_flash_remaining = 0.08


func collect_medkit(amount: int = 3) -> void:
	health = mini(max_health, health + amount)
	healing_charges = mini(3, healing_charges + 1)
