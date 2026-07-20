@tool
extends Resource
class_name BTNodeResource

const TYPE_ROOT := "Root"
const TYPE_SEQUENCE := "Sequence"
const TYPE_SELECTOR := "Selector"
const TYPE_ACTION := "Action"
const TYPE_CONDITION := "Condition"
const TYPE_DECORATOR := "Decorator"

@export var id: int = -1
@export var title: String = "Node"
@export var node_type: String = TYPE_ACTION
@export var position: Vector2 = Vector2.ZERO
@export var parent_id: int = -1
@export var decorator_parent_id: int = -1
@export_multiline var description: String = ""
@export var parameters: Dictionary = {}
@export var enabled: bool = true
@export var collapsed: bool = false
