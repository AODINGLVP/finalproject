@tool
extends Control
class_name BTTypeIcon

const ICON_SIZE := Vector2(30.0, 26.0)

var node_type := "Action"
var accent_color := Color.WHITE


func _ready() -> void:
	custom_minimum_size = ICON_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(value: String, color: Color) -> void:
	node_type = value
	accent_color = color
	tooltip_text = "%s node type icon" % value
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var fill := Color(accent_color.r, accent_color.g, accent_color.b, 0.28)
	var stroke := Color(0.96, 0.98, 1.0, 1.0)
	match node_type:
		"Root":
			draw_circle(center, 9.0, fill)
			draw_arc(center, 9.0, 0.0, TAU, 24, stroke, 2.0, true)
			draw_circle(center, 2.5, stroke)
		"Sequence":
			_draw_diamond(center, fill, stroke)
			draw_line(center + Vector2(-6.0, 0.0), center + Vector2(5.0, 0.0), stroke, 2.0, true)
			draw_line(center + Vector2(2.0, -3.0), center + Vector2(6.0, 0.0), stroke, 2.0, true)
			draw_line(center + Vector2(2.0, 3.0), center + Vector2(6.0, 0.0), stroke, 2.0, true)
		"Selector":
			_draw_diamond(center, fill, stroke)
			draw_circle(center, 3.0, stroke)
		"Random Selector":
			_draw_diamond(center, fill, stroke)
			draw_line(center + Vector2(-4.0, -4.0), center + Vector2(4.0, 4.0), stroke, 2.0, true)
			draw_line(center + Vector2(4.0, -4.0), center + Vector2(-4.0, 4.0), stroke, 2.0, true)
		"Parallel":
			_draw_diamond(center, fill, stroke)
			draw_line(center + Vector2(-4.0, -6.0), center + Vector2(-4.0, 6.0), stroke, 2.0, true)
			draw_line(center + Vector2(4.0, -6.0), center + Vector2(4.0, 6.0), stroke, 2.0, true)
		"Repeat":
			_draw_hexagon(center, fill, stroke)
			draw_arc(center, 5.0, -PI * 0.75, PI * 0.75, 14, stroke, 2.0, true)
			draw_line(center + Vector2(-5.0, 1.0), center + Vector2(-7.0, 5.0), stroke, 2.0, true)
		"Condition":
			var triangle := PackedVector2Array([center + Vector2(0.0, -10.0), center + Vector2(10.0, 8.0), center + Vector2(-10.0, 8.0)])
			draw_colored_polygon(triangle, fill)
			draw_polyline(PackedVector2Array([triangle[0], triangle[1], triangle[2], triangle[0]]), stroke, 2.0, true)
			draw_circle(center + Vector2(0.0, 3.0), 2.0, stroke)
		"Wait":
			_draw_hexagon(center, fill, stroke)
			draw_line(center + Vector2(-5.0, -6.0), center + Vector2(5.0, -6.0), stroke, 2.0, true)
			draw_line(center + Vector2(-5.0, 6.0), center + Vector2(5.0, 6.0), stroke, 2.0, true)
			draw_line(center + Vector2(-5.0, -6.0), center + Vector2(5.0, 6.0), stroke, 2.0, true)
			draw_line(center + Vector2(5.0, -6.0), center + Vector2(-5.0, 6.0), stroke, 2.0, true)
		"Decorator":
			var shield := PackedVector2Array([center + Vector2(-9.0, -8.0), center + Vector2(9.0, -8.0), center + Vector2(7.0, 4.0), center + Vector2(0.0, 10.0), center + Vector2(-7.0, 4.0)])
			draw_colored_polygon(shield, fill)
			draw_polyline(PackedVector2Array([shield[0], shield[1], shield[2], shield[3], shield[4], shield[0]]), stroke, 2.0, true)
		_:
			var rect := Rect2(center - Vector2(9.0, 9.0), Vector2(18.0, 18.0))
			draw_rect(rect, fill, true)
			draw_rect(rect, stroke, false, 2.0)


func _draw_diamond(center: Vector2, fill: Color, stroke: Color) -> void:
	var points := PackedVector2Array([center + Vector2(0.0, -10.0), center + Vector2(11.0, 0.0), center + Vector2(0.0, 10.0), center + Vector2(-11.0, 0.0)])
	draw_colored_polygon(points, fill)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), stroke, 2.0, true)


func _draw_hexagon(center: Vector2, fill: Color, stroke: Color) -> void:
	var points := PackedVector2Array([center + Vector2(-9.0, -8.0), center + Vector2(9.0, -8.0), center + Vector2(12.0, 0.0), center + Vector2(9.0, 8.0), center + Vector2(-9.0, 8.0), center + Vector2(-12.0, 0.0)])
	draw_colored_polygon(points, fill)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[4], points[5], points[0]]), stroke, 2.0, true)
