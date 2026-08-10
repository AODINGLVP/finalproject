extends SceneTree

const BRIDGE_PATH := "res://.godot/behavior_tree_runtime_debug.json"
const TREE_PATH := "res://behavior_trees/human_study_tree_364.tres"
const PATH_IDS := [1, 2, 5, 14, 41, 122, 363]
const PATH_TITLES := [
	"Root",
	"Decision Hub",
	"Branch_005",
	"Branch_014",
	"Branch_041",
	"Branch_122",
	"STUDY_TARGET_ACTION",
]

var refresh_duration_seconds := 0.0
var refresh_elapsed := 0.0
var refresh_enabled := false


func _initialize() -> void:
	refresh_duration_seconds = _read_duration_argument()
	if not write_snapshot():
		quit(1)
		return
	if refresh_duration_seconds <= 0.0:
		print("BT_HUMAN_STUDY_DEBUG_READY path=%s mode=once" % BRIDGE_PATH)
		quit(0)
		return
	refresh_enabled = true
	print("BT_HUMAN_STUDY_DEBUG_READY path=%s duration=%.1fs" % [BRIDGE_PATH, refresh_duration_seconds])


func _process(delta: float) -> bool:
	if not refresh_enabled:
		return false
	refresh_elapsed += delta
	refresh_duration_seconds -= delta
	if refresh_duration_seconds <= 0.0:
		print("BT_HUMAN_STUDY_DEBUG_COMPLETE")
		quit(0)
		return true
	if refresh_elapsed >= 0.25:
		refresh_elapsed = 0.0
		if not write_snapshot():
			quit(1)
	return false


static func make_payload() -> Dictionary:
	var statuses: Dictionary = {}
	for node_id in PATH_IDS:
		statuses[node_id] = "RUNNING"
	var now := Time.get_unix_time_from_system()
	return {
		"version": 1,
		"timestamp_msec": Time.get_ticks_msec(),
		"timestamp_unix": now,
		"components": [{
			"actor": "StudyNPC",
			"component": "/root/HumanStudy/BehaviorTreeComponent",
			"tree_name": "Human Study Tree 364",
			"tree_path": TREE_PATH,
			"path_ids": PATH_IDS.duplicate(),
			"path_titles": PATH_TITLES.duplicate(),
			"path_text": " > ".join(PATH_TITLES),
			"leaf_status": 2,
			"leaf_status_text": "RUNNING",
			"statuses": statuses,
			"failure_reasons": {},
			"blackboard": {
				"study_target_visible": true,
				"study_trial": "active_path",
			},
			"blackboard_schema_types": {
				"study_target_visible": "Bool",
				"study_trial": "String",
			},
			"blackboard_schema_errors": [],
			"timestamp_msec": Time.get_ticks_msec(),
			"timestamp_unix": now,
		}],
	}


static func write_snapshot() -> bool:
	var bridge_dir := ProjectSettings.globalize_path(BRIDGE_PATH.get_base_dir())
	DirAccess.make_dir_recursive_absolute(bridge_dir)
	var file := FileAccess.open(BRIDGE_PATH, FileAccess.WRITE)
	if file == null:
		printerr("FAIL: could not write human-study Live Debug bridge to %s" % BRIDGE_PATH)
		return false
	file.store_string(JSON.stringify(make_payload()))
	file.close()
	return true


func _read_duration_argument() -> float:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--duration="):
			return maxf(float(argument.trim_prefix("--duration=")), 0.0)
	return 0.0
