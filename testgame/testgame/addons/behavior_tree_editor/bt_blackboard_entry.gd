@tool
extends Resource
class_name BTBlackboardEntry

const VALUE_TYPE_BOOL := "Bool"
const VALUE_TYPE_INT := "Int"
const VALUE_TYPE_FLOAT := "Float"
const VALUE_TYPE_STRING := "String"
const VALUE_TYPE_VECTOR2 := "Vector2"
const SUPPORTED_TYPES := [VALUE_TYPE_BOOL, VALUE_TYPE_INT, VALUE_TYPE_FLOAT, VALUE_TYPE_STRING, VALUE_TYPE_VECTOR2]

@export var key: String = "new_key"
@export_enum("Bool", "Int", "Float", "String", "Vector2") var value_type: String = VALUE_TYPE_BOOL
@export var default_value: Variant = false
@export_multiline var description: String = ""


func normalized_default() -> Variant:
	match value_type:
		VALUE_TYPE_BOOL:
			return bool(default_value)
		VALUE_TYPE_INT:
			return int(default_value)
		VALUE_TYPE_FLOAT:
			return float(default_value)
		VALUE_TYPE_STRING:
			return str(default_value)
		VALUE_TYPE_VECTOR2:
			return default_value if default_value is Vector2 else Vector2.ZERO
		_:
			return default_value


func accepts(value: Variant) -> bool:
	match value_type:
		VALUE_TYPE_BOOL:
			return typeof(value) == TYPE_BOOL
		VALUE_TYPE_INT:
			return typeof(value) == TYPE_INT
		VALUE_TYPE_FLOAT:
			return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT
		VALUE_TYPE_STRING:
			return typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME
		VALUE_TYPE_VECTOR2:
			return typeof(value) == TYPE_VECTOR2
		_:
			return false
