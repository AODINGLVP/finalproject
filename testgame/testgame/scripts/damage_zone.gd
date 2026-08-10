extends Area2D

@export var damage_interval := 0.75

var elapsed := 0.0


func _physics_process(delta: float) -> void:
	elapsed -= delta
	if elapsed > 0.0:
		return
	elapsed = damage_interval
	for body in get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(1)
