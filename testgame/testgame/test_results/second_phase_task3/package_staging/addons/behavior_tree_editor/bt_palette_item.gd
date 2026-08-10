@tool
extends Button
class_name BTPaletteItem

var node_type: String = ""


func _get_drag_data(_at_position: Vector2) -> Variant:
	if node_type.is_empty():
		return null
	var preview := Label.new()
	preview.text = node_type
	set_drag_preview(preview)
	return {
		"kind": "bt_node_type",
		"node_type": node_type,
	}
