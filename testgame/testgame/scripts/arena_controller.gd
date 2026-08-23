extends Node2D

signal arena_completed

@onready var player: CharacterBody2D = $Player
@onready var help_label: Label = $UI/TopPanel/TopContent/Help
@onready var player_label: Label = $UI/TopPanel/TopContent/PlayerStatus
@onready var victory_panel: PanelContainer = $UI/VictoryPanel
@onready var victory_label: Label = $UI/VictoryPanel/VictoryContent/VictoryLabel

var ai_paused := false
var hud_elapsed := 0.0
var enemy_spawn_positions: Dictionary = {}
var tracked_enemies: Array[Node] = []
var defeated_enemy_ids: Dictionary = {}
var total_enemy_count := 0
var remaining_enemy_count := 0
var game_completed := false


func _ready() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		tracked_enemies.append(enemy)
		enemy_spawn_positions[enemy.name] = enemy.global_position
		var defeated_callable := Callable(self, "_on_enemy_defeated")
		if enemy.has_signal("defeated") and not enemy.is_connected("defeated", defeated_callable):
			enemy.connect("defeated", defeated_callable)
		_attach_identity_label(enemy)
	total_enemy_count = tracked_enemies.size()
	remaining_enemy_count = total_enemy_count
	victory_panel.visible = false
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


func _attach_identity_label(enemy: Node) -> void:
	if enemy.has_node("BehaviorTreeIdentity"):
		return
	var runner := enemy.get_node_or_null("BehaviorTreeComponent")
	var tree_size := 0
	if runner != null and runner.behavior_tree != null:
		tree_size = int(runner.behavior_tree.nodes.size())
	var identity := Label.new()
	identity.name = "BehaviorTreeIdentity"
	identity.position = Vector2(-84.0, -112.0 if tree_size == 61 else -90.0)
	identity.size = Vector2(168.0, 22.0)
	identity.text = "%s  %d nodes" % [str(enemy.get("archetype_name")), tree_size]
	identity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.z_index = 20
	identity.add_theme_font_size_override("font_size", 12)
	identity.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0, 0.98))
	identity.add_theme_color_override("font_shadow_color", Color(0.01, 0.03, 0.05, 0.95))
	identity.add_theme_constant_override("shadow_offset_x", 1)
	identity.add_theme_constant_override("shadow_offset_y", 1)
	enemy.add_child(identity)


func _update_hud() -> void:
	if not is_instance_valid(player):
		return
	var health_text := "INFINITE" if player.infinite_health else "%d/%d" % [player.health, player.max_health]
	player_label.text = "PLAYER  HP %s   STAMINA %d   HEALS %d   CLOAK %s   ENEMIES %d/%d" % [
		health_text, roundi(player.stamina), player.healing_charges,
		"ACTIVE" if player.cloaked else ("READY" if player.cloak_cooldown <= 0.0 else "%.1fs" % player.cloak_cooldown),
		remaining_enemy_count, total_enemy_count
	]
	help_label.text = "A/D Move  W/Up Jump+Climb  S/Down Climb  J Attack  Space Dash  C Cloak  T AI  R Reset"
	if game_completed:
		help_label.text = "Arena complete. Press R to replay the five behavior-tree encounters."
	elif ai_paused:
		help_label.text += "   [AI PAUSED]"


func _toggle_ai() -> void:
	if game_completed:
		return
	ai_paused = not ai_paused
	for enemy in tracked_enemies:
		if not is_instance_valid(enemy) or bool(enemy.get("is_defeated")):
			continue
		var runner := enemy.get_node_or_null("BehaviorTreeComponent")
		if runner == null:
			continue
		if ai_paused:
			runner.stop_tree()
			enemy.velocity.x = 0.0
		else:
			runner.start_tree()


func _reset_arena() -> void:
	for projectile in get_tree().get_nodes_in_group("enemy_projectiles"):
		projectile.queue_free()
	player.reset_for_round()
	defeated_enemy_ids.clear()
	game_completed = false
	remaining_enemy_count = total_enemy_count
	victory_panel.visible = false
	for enemy in tracked_enemies:
		if not is_instance_valid(enemy):
			continue
		enemy.reset_for_round()
		enemy.global_position = enemy_spawn_positions.get(enemy.name, enemy.home_position)
	ai_paused = false
	_update_hud()


func _on_enemy_defeated(enemy: Node) -> void:
	if game_completed or not is_instance_valid(enemy):
		return
	var enemy_id := enemy.get_instance_id()
	if defeated_enemy_ids.has(enemy_id):
		return
	defeated_enemy_ids[enemy_id] = true
	remaining_enemy_count = maxi(0, total_enemy_count - defeated_enemy_ids.size())
	_update_hud()
	if remaining_enemy_count == 0:
		_complete_arena()


func _complete_arena() -> void:
	if game_completed:
		return
	game_completed = true
	ai_paused = true
	for enemy in tracked_enemies:
		if not is_instance_valid(enemy):
			continue
		var runner := enemy.get_node_or_null("BehaviorTreeComponent")
		if runner != null:
			runner.stop_tree()
	for projectile in get_tree().get_nodes_in_group("enemy_projectiles"):
		projectile.queue_free()
	victory_label.text = "VICTORY\nAll five behavior-tree enemies defeated.\nPress R to replay."
	victory_panel.visible = true
	_update_hud()
	arena_completed.emit()
