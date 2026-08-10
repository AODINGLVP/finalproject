extends Node2D

const BTStatus = preload("res://addons/behavior_tree_editor/runtime/bt_status.gd")

@export var speed := 120.0
@export var patrol_points: Array[Vector2] = [Vector2(120, 120), Vector2(420, 120)]

var patrol_index := 0


func has_target(blackboard: Dictionary, _delta: float, _node: Resource) -> int:
	return BTStatus.SUCCESS if blackboard.get("has_target", false) else BTStatus.FAILURE


func patrol(blackboard: Dictionary, delta: float, _node: Resource) -> int:
	if patrol_points.is_empty():
		return BTStatus.FAILURE
	var target := patrol_points[patrol_index]
	global_position = global_position.move_toward(target, speed * delta)
	if global_position.distance_to(target) < 4.0:
		patrol_index = (patrol_index + 1) % patrol_points.size()
	blackboard["state"] = "patrol"
	return BTStatus.RUNNING


func chase_target(blackboard: Dictionary, delta: float, _node: Resource) -> int:
	var target_position: Vector2 = blackboard.get("target_position", global_position)
	global_position = global_position.move_toward(target_position, speed * delta)
	blackboard["state"] = "chase"
	return BTStatus.RUNNING


func move_to_target(blackboard: Dictionary, delta: float, node: Resource) -> int:
	return chase_target(blackboard, delta, node)
