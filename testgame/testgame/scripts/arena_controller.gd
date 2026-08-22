extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var help_label: Label = $UI/TopPanel/TopContent/Help
@onready var player_label: Label = $UI/TopPanel/TopContent/PlayerStatus

var ai_paused := false
var hud_elapsed := 0.0
var enemy_spawn_positions: Dictionary = {}


func _ready() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy_spawn_positions[enemy.name] = enemy.global_position
	_update_hud()
	queue_redraw()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart_arena"):
		_reset_arena()
	if Input.is_action_just_pressed("toggle_ai"):
		_toggle_ai()
	hud_elapsed -= delta
	if hud_elapsed <= 0.0:
		hud_elapsed = 0.1
		_update_hud()
	queue_redraw()


func _draw() -> void:
	for x in range(0, 1281, 80):
		draw_line(Vector2(x, 72), Vector2(x, 610), Color(0.15, 0.23, 0.28, 0.34), 1.0)
	for y in range(90, 611, 65):
		draw_line(Vector2(0, y), Vector2(1280, y), Color(0.15, 0.23, 0.28, 0.34), 1.0)
	draw_rect(Rect2(330, 475, 250, 120), Color(0.12, 0.42, 0.48, 0.12), true)
	draw_rect(Rect2(330, 475, 250, 120), Color(0.25, 0.78, 0.82, 0.35), false, 2.0)
	draw_rect(Rect2(840, 500, 170, 95), Color(0.72, 0.20, 0.14, 0.12), true)
	draw_rect(Rect2(840, 500, 170, 95), Color(0.98, 0.38, 0.25, 0.45), false, 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(350, 500), "STEALTH TEST ZONE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.45, 0.9, 0.92, 0.75))
	draw_string(font, Vector2(860, 525), "DAMAGE ZONE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.55, 0.4, 0.78))
	draw_string(font, Vector2(610, 485), "JUMP", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.72, 0.28, 0.9))
	draw_string(font, Vector2(700, 380), "CLIMB", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.9, 1.0, 0.9))
	draw_string(font, Vector2(985, 285), "HIGH GROUND", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.9, 1.0, 0.9))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not (enemy is CharacterBody2D) or not enemy.visible:
			continue
		var ratio: float = clampf(float(enemy.health) / float(enemy.max_health), 0.0, 1.0)
		var origin: Vector2 = enemy.global_position + Vector2(-28, -54)
		draw_rect(Rect2(origin, Vector2(56, 7)), Color(0.08, 0.1, 0.12, 0.9), true)
		draw_rect(Rect2(origin + Vector2(1, 1), Vector2(54.0 * ratio, 5)), Color(0.25, 0.92, 0.58), true)


func _update_hud() -> void:
	if not is_instance_valid(player):
		return
	player_label.text = "PLAYER  HP %d/%d   STAMINA %d   HEALS %d   CLOAK %s" % [
		player.health, player.max_health, roundi(player.stamina), player.healing_charges,
		"ACTIVE" if player.cloaked else ("READY" if player.cloak_cooldown <= 0.0 else "%.1fs" % player.cloak_cooldown)
	]
	help_label.text = "A/D Move  W/Up Jump+Climb  S/Down Climb  J Attack  Space Dash  H Heal  C Cloak  T AI  R Reset"


func _toggle_ai() -> void:
	ai_paused = not ai_paused
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var runner := enemy.get_node_or_null("BehaviorTreeComponent")
		if runner == null:
			continue
		if ai_paused:
			runner.stop_tree()
			enemy.velocity.x = 0.0
		else:
			runner.start_tree()


func _reset_arena() -> void:
	player.health = player.max_health
	player.stamina = 100.0
	player.healing_charges = 2
	player.cloaked = false
	player.self_modulate = Color.WHITE
	player.global_position = player.spawn_position
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.health = enemy.max_health
		enemy.visible = true
		enemy.set_physics_process(true)
		enemy.global_position = enemy_spawn_positions.get(enemy.name, enemy.home_position)
		enemy.modulate = Color.WHITE
		var runner := enemy.get_node_or_null("BehaviorTreeComponent")
		if runner != null:
			runner.blackboard.clear()
			runner.restart_tree()
	ai_paused = false
