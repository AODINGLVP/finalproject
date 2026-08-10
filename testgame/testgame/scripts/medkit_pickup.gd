extends Area2D

@export var heal_amount := 3
@export var respawn_time := 5.0

var available := true


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not available or not body.is_in_group("player"):
		return
	available = false
	visible = false
	monitoring = false
	if body.has_method("collect_medkit"):
		body.collect_medkit(heal_amount)
	await get_tree().create_timer(respawn_time).timeout
	available = true
	visible = true
	monitoring = true

