class_name BreakableWall
extends StaticBody2D

signal broken(position: Vector2)
signal resonated(position: Vector2)

@export var wall_size: Vector2 = Vector2(48.0, 96.0):
	set(value):
		wall_size = value
		_update_geometry()

@export var wall_color: Color = Color(0.18, 0.20, 0.26, 1.0)
@export var crack_color: Color = Color(0.98, 0.62, 0.25, 0.95)
@export var debris_color: Color = Color(0.98, 0.62, 0.25, 1.0)

var is_broken: bool = false

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _body_visual: Polygon2D = $Body
@onready var _cracks_visual: Polygon2D = $Cracks
@onready var _debris_particles: CPUParticles2D = $DebrisParticles


func _ready() -> void:
	add_to_group(&"breakable_wall")
	_update_geometry()
	if _debris_particles != null:
		_debris_particles.emitting = false


func _update_geometry() -> void:
	var half_w := wall_size.x * 0.5
	var half_h := wall_size.y * 0.5

	if _collision_shape != null:
		var rect_shape := _collision_shape.shape as RectangleShape2D
		if rect_shape == null:
			rect_shape = RectangleShape2D.new()
			_collision_shape.shape = rect_shape
		rect_shape.size = wall_size

	if _body_visual != null:
		_body_visual.color = wall_color
		_body_visual.polygon = PackedVector2Array([
			Vector2(-half_w, -half_h),
			Vector2(half_w, -half_h),
			Vector2(half_w, half_h),
			Vector2(-half_w, half_h),
		])

	if _cracks_visual != null:
		_cracks_visual.color = crack_color
		_cracks_visual.polygon = _generate_crack_polygon(half_w, half_h)

	if _debris_particles != null:
		_debris_particles.emission_rect_extents = Vector2(half_w * 0.8, half_h * 0.8)


func _generate_crack_polygon(half_w: float, half_h: float) -> PackedVector2Array:
	# Jagged, stylized fissure lines through the center of the wall block
	var w3 := half_w * 0.35
	var w6 := half_w * 0.65
	var h4 := half_h * 0.45
	return PackedVector2Array([
		Vector2(-w3, -half_h + 3.0),
		Vector2(2.0, -h4),
		Vector2(-w6, 0.0),
		Vector2(4.0, h4),
		Vector2(-w3, half_h - 3.0),
		Vector2(0.0, half_h - 3.0),
		Vector2(half_w * 0.4, h4 + 3.0),
		Vector2(-w3 + 4.0, 0.0),
		Vector2(half_w * 0.3, -h4 - 2.0),
		Vector2(-w3 + 3.0, -half_h + 3.0),
	])


func apply_horizontal_mirror(is_mirrored: bool) -> void:
	if is_mirrored:
		position.x = -position.x


func pulse_resonance() -> void:
	if is_broken:
		return
	resonated.emit(global_position)
	if _cracks_visual != null:
		var tween := create_tween()
		tween.tween_property(_cracks_visual, "modulate", Color(1.8, 1.4, 1.0, 1.0), 0.08)
		tween.tween_property(_cracks_visual, "modulate", Color.WHITE, 0.22)


func break_wall(impact_direction: Vector2 = Vector2.RIGHT) -> void:
	if is_broken:
		return
	is_broken = true

	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", true)

	if _body_visual != null:
		_body_visual.visible = false
	if _cracks_visual != null:
		_cracks_visual.visible = false

	if _debris_particles != null:
		var dir := impact_direction.normalized()
		if dir.is_zero_approx():
			dir = Vector2.RIGHT
		_debris_particles.direction = dir
		_debris_particles.restart()
		_debris_particles.emitting = true

	broken.emit(global_position)
