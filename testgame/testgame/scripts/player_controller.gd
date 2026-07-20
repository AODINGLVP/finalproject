extends CharacterBody2D

@export var speed := 260.0
@export var gravity := 900.0
@export var attack_duration := 0.18
@export var attack_damage := 1
@export var idle_texture: Texture2D
@export var attack_texture: Texture2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_area: Area2D = $AttackArea

var facing := 1
var health := 5
var attack_timer := 0.0
var hit_targets: Array[Node] = []


func _ready() -> void:
	add_to_group("player")
	attack_area.monitoring = false
	sprite.texture = idle_texture


func _physics_process(delta: float) -> void:
	var direction: float = Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		facing = -1 if direction < 0.0 else 1
		sprite.flip_h = facing < 0
	velocity.x = direction * speed
	velocity.y += gravity * delta
	move_and_slide()

	if Input.is_action_just_pressed("attack"):
		_start_attack()
	_update_attack(delta)


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
	health -= amount
	modulate = Color(1.0, 0.65, 0.65)
	await get_tree().create_timer(0.08).timeout
	modulate = Color.WHITE
