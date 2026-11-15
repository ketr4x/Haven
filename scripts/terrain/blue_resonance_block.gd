class_name BlueResonanceBlock
extends StaticBody2D

signal shattered(position: Vector2)

@export var block_size: Vector2 = Vector2(48.0, 48.0)
@export var block_color: Color = Color(0.2, 0.56, 1.0, 1.0)

var _is_shattered: bool = false


func _ready() -> void:
	add_to_group(&"blue_resonance_block")
	var collision_shape := $CollisionShape2D as CollisionShape2D
	var shape := RectangleShape2D.new()
	shape.size = block_size
	collision_shape.shape = shape
	queue_redraw()


func shatter() -> void:
	if _is_shattered:
		return
	_is_shattered = true
	shattered.emit(global_position)
	queue_free()


func _draw() -> void:
	var rect := Rect2(-block_size * 0.5, block_size)
	draw_rect(rect, Color(0.04, 0.12, 0.28, 1.0), true)
	draw_rect(rect.grow(-3.0), block_color, true)
	draw_rect(rect.grow(-7.0), Color(0.12, 0.26, 0.58, 1.0), true)
	draw_line(rect.position, rect.position + Vector2(rect.size.x, 0.0), Color(0.78, 0.94, 1.0, 1.0), 2.0)
