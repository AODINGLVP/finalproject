extends Area2D

@export var speed := 360.0
@export var damage := 1
@export var lifetime := 2.2

var direction := Vector2.RIGHT


func _ready() -> void:
	add_to_group("enemy_projectiles")
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func configure(origin: Vector2, target: Vector2, projectile_damage := 1) -> void:
	global_position = origin
	direction = origin.direction_to(target)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	damage = projectile_damage
	rotation = direction.angle()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
	elif body.is_in_group("obstacles"):
		queue_free()
