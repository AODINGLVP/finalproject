extends RefCounted
class_name BTStatus

const SUCCESS := 1
const FAILURE := 2
const RUNNING := 3


static func from_value(value: Variant) -> int:
	match typeof(value):
		TYPE_BOOL:
			return SUCCESS if value else FAILURE
		TYPE_NIL:
			return FAILURE
		TYPE_INT:
			return value if [SUCCESS, FAILURE, RUNNING].has(value) else FAILURE
		TYPE_STRING:
			match str(value).to_lower():
				"success", "succeeded", "ok":
					return SUCCESS
				"running", "wait":
					return RUNNING
				_:
					return FAILURE
		_:
			return FAILURE
	return FAILURE
