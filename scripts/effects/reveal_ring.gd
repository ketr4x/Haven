class_name RevealRing
extends Node2D

@export_range(40.0, 800.0, 10.0) var maximum_radius: float = 420.0
@export_range(300.0, 1_200.0, 10.0) var propagation_speed: float = 900.0
@export_range(30.0, 120.0, 1.0) var arc_angle_degrees: float = 70.0
@export_range(0.01, 0.12, 0.01) var arc_interval: float = 0.05
@export_range(1, 9) var arc_count: int = 7
@export_range(0.0, 1.0, 0.05) var starting_alpha: float = 0.75
@export_range(1.0, 8.0, 0.25) var pixel_spacing: float = 1.5
@export_range(0.0, 4.0, 0.25) var wave_amplitude: float = 2.25
@export_range(1.0, 6.0, 0.25) var primary_wave_cycles: float = 3.5
@export_range(3.0, 12.0, 0.5) var secondary_wave_cycles: float = 8.5
@export_range(24, 160) var occlusion_sample_count: int = 96
@export_range(16, 640) var maximum_pixels_per_arc: int = 480
@export_flags_2d_physics var collision_mask: int = 1

var duration: float = 0.0
var _elapsed: float = 0.0
var _arc_duration: float = 0.0
var _direction_angle: float = 0.0
var _source_velocity: Vector2 = Vector2.ZERO
var _base_color: Color = Color.WHITE
var _is_echo: bool = false
var _occlusion_ready: bool = false
var _occlusion_limits: PackedFloat32Array = PackedFloat32Array()
var _draw_batches: Array[Dictionary] = []

func configure(
		captured_loudness: float,
		expansion_multiplier: float = 1.0,
		direction: Vector2 = Vector2.RIGHT,
		source_velocity: Vector2 = Vector2.ZERO,
) -> void:
	var loudness_ratio := clampf(captured_loudness, 0.0, 100.0) / 100.0
	var visual_scale := clampf(expansion_multiplier, 0.12, 1.0)
	maximum_radius = lerpf(210.0, 1_680.0, loudness_ratio) * visual_scale
	_arc_duration = maximum_radius / propagation_speed
	duration = _arc_duration + arc_interval * float(arc_count - 1)
	_direction_angle = (direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT).angle()
	_source_velocity = source_velocity
	_base_color = Color.WHITE
	_is_echo = false
	_occlusion_ready = false
	_update_arcs()


func configure_echo(
		direction: Vector2,
		_captured_loudness: float,
		color: Color = Color(1.0, 0.2, 0.32, 1.0),
) -> void:
	arc_count = 1
	maximum_radius = 1_680.0
	propagation_speed = 900.0
	_arc_duration = maximum_radius / propagation_speed
	duration = _arc_duration
	_direction_angle = (direction.normalized() if not direction.is_zero_approx() else Vector2.LEFT).angle()
	_source_velocity = Vector2.ZERO
	_base_color = color
	starting_alpha = 0.82
	_is_echo = true
	_occlusion_ready = false
	_update_arcs()


func configure_big_scream(
		direction: Vector2,
		is_positive: bool,
		source_velocity: Vector2 = Vector2.ZERO,
) -> void:
	arc_angle_degrees = 30.0
	arc_count = 5
	maximum_radius = 1_680.0
	propagation_speed = 900.0
	_arc_duration = maximum_radius / propagation_speed
	duration = _arc_duration + arc_interval * float(arc_count - 1)
	_direction_angle = (direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT).angle()
	_source_velocity = source_velocity
	_base_color = Color(0.95, 0.72, 0.24, 1.0) if is_positive else Color(0.92, 0.2, 0.3, 1.0)
	starting_alpha = 0.86
	_is_echo = false
	_occlusion_ready = false
	_update_arcs()


func _process(delta: float) -> void:
	if not _source_velocity.is_zero_approx() and delta > 0.0:
		_advance_origin(delta)
		_occlusion_ready = false
	if not _occlusion_ready:
		_build_occlusion_limits()
	_elapsed += delta
	_update_arcs()
	if _elapsed >= duration:
		queue_free()


func _draw() -> void:
	for batch in _draw_batches:
		var color: Color = batch["color"]
		var pixels: PackedVector2Array = batch["pixels"]
		for pixel in pixels:
			draw_rect(Rect2(pixel, Vector2.ONE), color, true)


func _update_arcs() -> void:
	_draw_batches.clear()
	for index in arc_count:
		var local_age := _elapsed - arc_interval * float(index)
		if local_age < 0.0 or local_age >= _arc_duration:
			continue

		var progress := clampf(local_age / _arc_duration, 0.0, 1.0)
		var radius := lerpf(6.0, maximum_radius, progress)
		var alpha := starting_alpha * (1.0 - progress)
		_draw_batches.append({
			"pixels": _make_pixel_arc(radius, index),
			"color": Color(_base_color.r, _base_color.g, _base_color.b, alpha),
		})
	queue_redraw()


func _make_pixel_arc(radius: float, arc_index: int) -> PackedVector2Array:
	var pixels := PackedVector2Array()
	var arc_radians := deg_to_rad(arc_angle_degrees)
	var arc_length := maxf(radius * arc_radians, 1.0)
	var pixel_count := clampi(ceili(arc_length / pixel_spacing), 10, maximum_pixels_per_arc)
	var half_arc := arc_radians * 0.5
	var previous_pixel := Vector2(INF, INF)
	for index in pixel_count:
		var progress := float(index) / float(maxi(pixel_count - 1, 1))
		var angle := _direction_angle + lerpf(-half_arc, half_arc, progress)
		var arc_phase := float(arc_index) * 1.7
		var primary_wave := sin(progress * TAU * primary_wave_cycles + arc_phase)
		var secondary_wave := sin(progress * TAU * secondary_wave_cycles + float(arc_index) * 0.83) * 0.58
		var bounce_wave := sin(progress * PI * 2.0 + arc_phase * 0.6) * 0.32
		var pixel_radius := radius + (primary_wave + secondary_wave + bounce_wave) * wave_amplitude
		if pixel_radius > _get_occlusion_limit(progress) + 0.5:
			continue
		var pixel := (Vector2.from_angle(angle) * pixel_radius).round()
		if pixel == previous_pixel:
			continue
		pixels.append(pixel)
		previous_pixel = pixel
	return pixels


func _advance_origin(delta: float) -> void:
	var motion := _source_velocity * delta
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + motion, collision_mask)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var collision := space_state.intersect_ray(query)
	if collision.is_empty():
		global_position += motion
	else:
		var normal: Vector2 = collision["normal"]
		global_position = (collision["position"] as Vector2) + normal * 2.0
		_source_velocity = _source_velocity.slide(normal)


func _build_occlusion_limits() -> void:
	_occlusion_limits.resize(occlusion_sample_count)
	var half_arc := deg_to_rad(arc_angle_degrees) * 0.5
	var space_state := get_world_2d().direct_space_state
	for index in occlusion_sample_count:
		var progress := float(index) / float(maxi(occlusion_sample_count - 1, 1))
		var angle := _direction_angle + lerpf(-half_arc, half_arc, progress)
		var ray_end := global_position + Vector2.from_angle(angle) * (maximum_radius + wave_amplitude + 2.0)
		var query := PhysicsRayQueryParameters2D.create(global_position, ray_end, collision_mask)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var collision := space_state.intersect_ray(query)
		if collision.is_empty():
			_occlusion_limits[index] = maximum_radius + wave_amplitude + 2.0
		else:
			var collision_position: Vector2 = collision["position"]
			_occlusion_limits[index] = maxf(0.0, global_position.distance_to(collision_position))
	_occlusion_ready = true


func _get_occlusion_limit(progress: float) -> float:
	if not _occlusion_ready or _occlusion_limits.is_empty():
		return maximum_radius + wave_amplitude + 2.0
	var sample_position := clampf(progress, 0.0, 1.0) * float(_occlusion_limits.size() - 1)
	var lower_index := clampi(floori(sample_position), 0, _occlusion_limits.size() - 1)
	var upper_index := clampi(ceili(sample_position), 0, _occlusion_limits.size() - 1)
	# Taking the nearer neighboring hit prevents pixels leaking through thin tile corners.
	return minf(_occlusion_limits[lower_index], _occlusion_limits[upper_index])


func get_active_arc_count() -> int:
	return _draw_batches.size()


func get_current_pixel_count() -> int:
	var count := 0
	for batch in _draw_batches:
		count += (batch["pixels"] as PackedVector2Array).size()
	return count


func get_rendered_pixel_positions() -> PackedVector2Array:
	var result := PackedVector2Array()
	for batch in _draw_batches:
		result.append_array(batch["pixels"] as PackedVector2Array)
	return result


func get_arc_alpha(index: int) -> float:
	if index < 0 or index >= _draw_batches.size():
		return 0.0
	return (_draw_batches[index]["color"] as Color).a


func get_occlusion_limit(progress: float) -> float:
	return _get_occlusion_limit(progress)


func is_echo() -> bool:
	return _is_echo
