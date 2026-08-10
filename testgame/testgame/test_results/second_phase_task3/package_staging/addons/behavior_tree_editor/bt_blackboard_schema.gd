@tool
extends Resource
class_name BTBlackboardSchema

const BTBlackboardEntry = preload("res://addons/behavior_tree_editor/bt_blackboard_entry.gd")

@export var entries: Array[BTBlackboardEntry] = []
@export var allow_dynamic_keys: bool = true


func find_entry(key: String) -> BTBlackboardEntry:
	for entry in entries:
		if entry != null and entry.key == key:
			return entry
	return null


func apply_defaults(blackboard: Dictionary) -> void:
	for entry in entries:
		if entry != null and not entry.key.is_empty() and not blackboard.has(entry.key):
			blackboard[entry.key] = entry.normalized_default()


func validate_schema() -> PackedStringArray:
	var errors := PackedStringArray()
	var known_keys: Dictionary = {}
	for entry in entries:
		if entry == null:
			errors.append("Schema contains a null entry.")
			continue
		var key := entry.key.strip_edges()
		if key.is_empty():
			errors.append("Schema contains an empty key.")
		elif known_keys.has(key):
			errors.append("Schema contains duplicate key '%s'." % key)
		known_keys[key] = true
		if not BTBlackboardEntry.SUPPORTED_TYPES.has(entry.value_type):
			errors.append("Blackboard key '%s' uses unsupported type '%s'." % [key, entry.value_type])
		elif not entry.accepts(entry.normalized_default()):
			errors.append("Blackboard key '%s' has an invalid default value." % key)
	return errors


func validate_blackboard(blackboard: Dictionary) -> PackedStringArray:
	var errors := validate_schema()
	for entry in entries:
		if entry == null or entry.key.is_empty() or not blackboard.has(entry.key):
			continue
		if not entry.accepts(blackboard[entry.key]):
			errors.append("Blackboard key '%s' expected %s, got %s." % [entry.key, entry.value_type, type_string(typeof(blackboard[entry.key]))])
	if not allow_dynamic_keys:
		for key in blackboard:
			if find_entry(str(key)) == null:
				errors.append("Blackboard key '%s' is not declared in the schema." % str(key))
	return errors


func type_map() -> Dictionary:
	var result: Dictionary = {}
	for entry in entries:
		if entry != null and not entry.key.is_empty():
			result[entry.key] = entry.value_type
	return result


func duplicate_schema():
	return duplicate(true)
