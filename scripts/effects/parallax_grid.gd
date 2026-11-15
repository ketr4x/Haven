class_name ParallaxGrid
extends Node2D

@export_category("Grid")
@export_range(24.0, 160.0, 1.0) var minor_spacing: float = 48.0
@export_range(2, 8, 1) var major_line_interval: int = 4
@export_range(0.01, 0.5, 0.01) var parallax_strength: float = 0.14
@export_range(1.0, 96.0, 1.0) var drift_speed: float = 22.0
@export var minor_line_color: Color = Color(0.19, 0.29, 0.44, 0.22)
@export var major_line_color: Color = Color(0.32, 0.52, 0.7, 0.32)

var _elapsed: float = 0.0
var _camera_position: Vector2 = Vector2.ZERO


func _process(delta: float) -> void:
	_elapsed += delta
	var camera := get_viewport().get_camera_2d()
	if is_instance_valid(camera):
		_camera_position = camera.get_screen_center_position()
	queue_redraw()


func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	var offset := _camera_position * parallax_strength + Vector2(_elapsed * drift_speed, _elapsed * drift_speed * 0.35)
	var x_start := -fposmod(offset.x, minor_spacing) - minor_spacing
	var y_start := -fposmod(offset.y, minor_spacing) - minor_spacing
	var x_index: int = 0
	var x := x_start
	while x <= viewport_size.x + minor_spacing:
		var is_major := posmod(x_index, major_line_interval) == 0
		draw_line(
			Vector2(x, 0.0),
			Vector2(x, viewport_size.y),
			major_line_color if is_major else minor_line_color,
			1.0,
		)
		x += minor_spacing
		x_index += 1
	var y_index: int = 0
	var y := y_start
	while y <= viewport_size.y + minor_spacing:
		var is_major := posmod(y_index, major_line_interval) == 0
		draw_line(
			Vector2(0.0, y),
			Vector2(viewport_size.x, y),
			major_line_color if is_major else minor_line_color,
			1.0,
		)
		y += minor_spacing
		y_index += 1
