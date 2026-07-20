@tool
extends GraphEdit
class_name BTGraphEdit

signal canvas_context_requested(local_position: Vector2)
signal node_type_dropped(node_type: String, local_position: Vector2)
signal viewport_wheel_scrolled

const FISHEYE_RADIUS := 430.0

var fisheye_focus_position := Vector2.ZERO


func _ready() -> void:
	right_disconnects = true
	show_grid = true
	snapping_enabled = true
	minimap_enabled = true
	connection_lines_thickness = 4.0
	connection_lines_curvature = 0.45


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and _is_wheel_button(event.button_index):
		viewport_wheel_scrolled.emit()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		canvas_context_requested.emit(event.position)
		accept_event()


func _is_wheel_button(button_index: int) -> bool:
	return button_index == MOUSE_BUTTON_WHEEL_UP \
		or button_index == MOUSE_BUTTON_WHEEL_DOWN \
		or button_index == MOUSE_BUTTON_WHEEL_LEFT \
		or button_index == MOUSE_BUTTON_WHEEL_RIGHT


func _draw() -> void:
	if fisheye_focus_position == Vector2.ZERO:
		return
	draw_circle(fisheye_focus_position, FISHEYE_RADIUS, Color(0.45, 0.75, 1.0, 0.055))
	draw_arc(fisheye_focus_position, FISHEYE_RADIUS, 0.0, TAU, 96, Color(0.45, 0.75, 1.0, 0.18), 2.0)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.get("kind", "") == "bt_node_type"


func _drop_data(at_position: Vector2, data: Variant) -> void:
	node_type_dropped.emit(str(data.get("node_type", "")), at_position)
