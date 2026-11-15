class_name FrozenEcho
extends StaticBody2D

signal expired(position: Vector2)

@export_range(96.0, 288.0, 1.0) var bridge_length: float = 168.0
@export_range(4.0, 24.0, 1.0) var bridge_thickness: float = 12.0
@export_range(1.0, 8.0, 0.1) var lifetime: float = 4.0
@export_range(5.0, 60.0, 1.0) var maximum_run_angle_degrees: float = 40.0
@export var crystal_color: Color = Color(0.95, 0.76, 0.25, 1.0)

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D

var _time_remaining: float = 0.0


func _ready() -> void:
	add_to_group(&"frozen_echo")
	_time_remaining = lifetime
	var shape := RectangleShape2D.new()
	shape.size = Vector2(bridge_length, bridge_thickness)
	_collision_shape.shape = shape
	_collision_shape.one_way_collision = true
	queue_redraw()


func configure(direction: Vector2) -> void:
	var angle := clampf(direction.angle(), deg_to_rad(-maximum_run_angle_degrees), deg_to_rad(maximum_run_angle_degrees))
	rotation = angle


func _process(delta: float) -> void:
	_time_remaining = maxf(0.0, _time_remaining - delta)
	queue_redraw()
	if is_zero_approx(_time_remaining):
		expired.emit(global_position)
		queue_free()


func _draw() -> void:
	var pulse := 1.0
	if _time_remaining < 1.0:
		pulse = 0.35 + 0.65 * absf(sin(_time_remaining * 18.0))
	var color := Color(crystal_color.r, crystal_color.g, crystal_color.b, pulse)
	var half_length := bridge_length * 0.5
	var top := -bridge_thickness * 0.5
	var bottom := bridge_thickness * 0.5
	var points := PackedVector2Array([
		Vector2(-half_length, bottom), Vector2(-half_length * 0.6, top), Vector2(-half_length * 0.12, top - 5.0),
		Vector2(half_length * 0.32, top), Vector2(half_length, bottom),
	])
	draw_colored_polygon(points, color)
	draw_polyline(points + PackedVector2Array([points[0]]), Color.WHITE, 2.0, true)
