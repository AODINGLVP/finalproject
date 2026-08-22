extends SceneTree

const BRIDGE_PATH := "res://.godot/behavior_tree_runtime_debug.json"
const FIXTURE_PATH := "res://tests/fixtures/human_study_241_targets.json"
const TREE_PATH := "res://behavior_trees/complex_display_tree_241.tres"
const DEFAULT_TARGET_KEY := "ranged"

var refresh_duration_seconds := 0.0
var refresh_elapsed := 0.0
var refresh_enabled := false
var target_key := DEFAULT_TARGET_KEY


func _initialize() -> void:
	refresh_duration_seconds = _read_duration_argument()
	target_key = _read_target_argument()
	if not write_snapshot(target_key):
		quit(1)
		return
	if refresh_duration_seconds <= 0.0:
		print("BT_HUMAN_STUDY_DEBUG_READY path=%s target=%s mode=once" % [BRIDGE_PATH, target_key])
		quit(0)
		return
	refresh_enabled = true
	print("BT_HUMAN_STUDY_DEBUG_READY path=%s target=%s duration=%.1fs" % [BRIDGE_PATH, target_key, refresh_duration_seconds])


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
		if not write_snapshot(target_key):
			quit(1)
	return false


static func make_payload(selected_target_key := DEFAULT_TARGET_KEY) -> Dictionary:
	var target := trace_target(selected_target_key)
	if target.is_empty():
		return {}
	var path_ids: Array = target.get("path_ids", [])
	var path_titles: Array = target.get("path_titles", [])
	var statuses: Dictionary = {}
	for node_id in path_ids:
		statuses[node_id] = "RUNNING"
	var now := Time.get_unix_time_from_system()
	return {
		"version": 1,
		"timestamp_msec": Time.get_ticks_msec(),
		"timestamp_unix": now,
		"components": [{
			"actor": "ArenaEnemy",
			"component": "/root/ComplexArena/Enemy/BehaviorTreeComponent",
			"tree_name": "Playable Complex Enemy 241",
			"tree_path": TREE_PATH,
			"path_ids": path_ids.duplicate(),
			"path_titles": path_titles.duplicate(),
			"path_text": " > ".join(path_titles),
			"leaf_status": 2,
			"leaf_status_text": "RUNNING",
			"statuses": statuses,
			"failure_reasons": {},
			"blackboard": {
				"player_detected": true,
				"study_target": selected_target_key,
			},
			"blackboard_schema_types": {
				"player_detected": "Bool",
				"study_target": "String",
			},
			"blackboard_schema_errors": [],
			"timestamp_msec": Time.get_ticks_msec(),
			"timestamp_unix": now,
		}],
}


static func write_snapshot(selected_target_key := DEFAULT_TARGET_KEY) -> bool:
	var payload := make_payload(selected_target_key)
	if payload.is_empty():
		printerr("FAIL: unknown human-study target %s" % selected_target_key)
		return false
	var bridge_dir := ProjectSettings.globalize_path(BRIDGE_PATH.get_base_dir())
	DirAccess.make_dir_recursive_absolute(bridge_dir)
	var file := FileAccess.open(BRIDGE_PATH, FileAccess.WRITE)
	if file == null:
		printerr("FAIL: could not write human-study Live Debug bridge to %s" % BRIDGE_PATH)
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	return true


static func trace_target(selected_target_key: String) -> Dictionary:
	var fixture := load_fixture()
	for target_variant in fixture.get("trace_targets", []):
		var target: Dictionary = target_variant
		if str(target.get("key", "")) == selected_target_key:
			return target
	return {}


static func load_fixture() -> Dictionary:
	var file := FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	if file == null:
		printerr("FAIL: cannot read human-study fixture %s" % FIXTURE_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		printerr("FAIL: invalid human-study fixture JSON")
		return {}
	return parsed as Dictionary


func _read_duration_argument() -> float:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--duration="):
			return maxf(float(argument.trim_prefix("--duration=")), 0.0)
	return 0.0


func _read_target_argument() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--target="):
			return argument.trim_prefix("--target=").strip_edges().to_lower()
	return DEFAULT_TARGET_KEY
