class_name BreakableWall
extends StaticBody2D

signal broken(position: Vector2)
signal resonated(position: Vector2)

@export var wall_size: Vector2 = Vector2(48.0, 96.0):
	set(value):
		wall_size = value
		_update_geometry()

@export var field_color: Color = Color(0.42, 0.86, 1.0, 0.22)
@export var edge_color: Color = Color(0.78, 0.96, 1.0, 0.92)
@export var debris_color: Color = Color(0.62, 0.94, 1.0, 0.95)

var is_broken: bool = false

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _body_visual: Polygon2D = $Body
@onready var _field_light: PointLight2D = get_node_or_null("FieldLight") as PointLight2D
@onready var _debris_particles: CPUParticles2D = $DebrisParticles

var _resonance_tween: Tween


func _ready() -> void:
	add_to_group(&"breakable_wall")
	_ensure_field_light_texture()
	_update_geometry()
	if _debris_particles != null:
		_debris_particles.emitting = false


func _ensure_field_light_texture() -> void:
	if _field_light == null or _field_light.texture != null:
		return
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.85),
		Color(0.85, 0.95, 1.0, 0.28),
		Color(0.5, 0.85, 1.0, 0.0),
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	_field_light.texture = tex


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
		_body_visual.color = Color.WHITE
		_body_visual.polygon = PackedVector2Array([
			Vector2(-half_w, -half_h),
			Vector2(half_w, -half_h),
			Vector2(half_w, half_h),
			Vector2(-half_w, half_h),
		])
		_body_visual.uv = PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(1.0, 0.0),
			Vector2(1.0, 1.0),
			Vector2(0.0, 1.0),
		])
		var mat := _body_visual.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter(&"field_color", field_color)
			mat.set_shader_parameter(&"edge_color", edge_color)
			mat.set_shader_parameter(&"field_size", wall_size)

	if _debris_particles != null:
		_debris_particles.emission_rect_extents = Vector2(half_w * 0.8, half_h * 0.8)
		_debris_particles.color = debris_color


func apply_horizontal_mirror(is_mirrored: bool) -> void:
	if is_mirrored:
		position.x = -position.x


func pulse_resonance() -> void:
	if is_broken:
		return
	resonated.emit(global_position)
	if _body_visual != null:
		var mat := _body_visual.material as ShaderMaterial
		if mat != null:
			if _resonance_tween != null and _resonance_tween.is_valid():
				_resonance_tween.kill()
			_resonance_tween = create_tween()
			mat.set_shader_parameter(&"resonance_pulse", 1.0)
			_resonance_tween.tween_method(
				func(v: float) -> void:
					mat.set_shader_parameter(&"resonance_pulse", v),
				1.0,
				0.0,
				0.28,
			).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func break_wall(impact_direction: Vector2 = Vector2.RIGHT) -> void:
	if is_broken:
		return
	is_broken = true

	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", true)

	if _body_visual != null:
		_body_visual.visible = false
	if _field_light != null:
		_field_light.enabled = false
		_field_light.visible = false

	if _debris_particles != null:
		var dir := impact_direction.normalized()
		if dir.is_zero_approx():
			dir = Vector2.RIGHT
		_debris_particles.direction = dir
		_debris_particles.restart()
		_debris_particles.emitting = true

	broken.emit(global_position)
