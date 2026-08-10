extends Node

const BTStatus = preload("res://addons/behavior_tree_editor/runtime/bt_status.gd")

var calls: Array[String] = []
var running_ticks := 0


func success_action(_blackboard: Dictionary, _delta: float, _node: Resource) -> int:
	calls.append("success")
	return BTStatus.SUCCESS


func failure_action(_blackboard: Dictionary, _delta: float, _node: Resource) -> int:
	calls.append("failure")
	return BTStatus.FAILURE


func running_then_success(_blackboard: Dictionary, _delta: float, _node: Resource) -> int:
	calls.append("running")
	running_ticks += 1
	return BTStatus.RUNNING if running_ticks == 1 else BTStatus.SUCCESS


func always_running(_blackboard: Dictionary, _delta: float, _node: Resource) -> int:
	calls.append("always_running")
	return BTStatus.RUNNING


func gated_success(blackboard: Dictionary, _delta: float, _node: Resource) -> int:
	calls.append("gated")
	return BTStatus.SUCCESS if bool(blackboard.get("gate", false)) else BTStatus.FAILURE


func scripted_status(blackboard: Dictionary, _delta: float, node: Resource) -> int:
	calls.append(str(node.title))
	var counts: Dictionary = blackboard.get("scripted_counts", {})
	var count := int(counts.get(node.id, 0)) + 1
	counts[node.id] = count
	blackboard["scripted_counts"] = counts
	if count <= int(node.parameters.get("running_ticks", 0)):
		return BTStatus.RUNNING
	return int(node.parameters.get("result", BTStatus.SUCCESS))


func condition_true(_blackboard: Dictionary, _delta: float, _node: Resource) -> bool:
	calls.append("condition_true")
	return true


func condition_false(_blackboard: Dictionary, _delta: float, _node: Resource) -> bool:
	calls.append("condition_false")
	return false
