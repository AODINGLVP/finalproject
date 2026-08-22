extends Area2D

@export var heal_amount := 3
@export var respawn_time := 5.0

var available := true
var respawn_timer: Timer


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	respawn_timer = Timer.new()
	respawn_timer.one_shot = true
	respawn_timer.timeout.connect(_on_respawn_timeout)
	add_child(respawn_timer)


func _on_body_entered(body: Node) -> void:
	if not available or not body.is_in_group("player"):
		return
	available = false
	visible = false
	set_deferred("monitoring", false)
	if body.has_method("collect_medkit"):
		body.collect_medkit(heal_amount)
	respawn_timer.start(respawn_time)


func _on_respawn_timeout() -> void:
	available = true
	visible = true
	set_deferred("monitoring", true)
