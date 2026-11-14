class_name SoundWave
extends Node2D

signal bounced(position: Vector2, normal: Vector2, bounce_count: int)
signal surface_reached(position: Vector2, normal: Vector2, intensity: float, tile_size: float)
signal returned_to_owner(player: RezonansPlayer, captured_loudness: float, pulse_id: int)
signal expired

@export var speed: float = 900.0
@export_flags_2d_physics var collision_mask: int = 1
@export_range(0, 5) var max_bounces: int = 3
@export_range(0.1, 1.0, 0.05) var minimum_lifetime: float = 0.35
@export_range(0.5, 3.0, 0.05) var maximum_lifetime: float = 1.85
@export_range(0.1, 1.0, 0.05) var bounce_retention: float = 0.68
@export_range(4.0, 32.0, 1.0) var return_arming_distance: float = 10.0

var velocity: Vector2 = Vector2.ZERO
var bounce_count: int = 0
var captured_loudness: float = 0.0
var pulse_id: int = 0
var emitter: RezonansPlayer
var lifetime: float = 0.0
var _remaining_lifetime: float = 0.0
var _energy: float = 0.0
var _return_distance: float = 42.0
var _has_returned: bool = false
var _can_return: bool = true
var _distance_after_bounce: float = 0.0
var _distance_traveled: float = 0.0
var _maximum_travel_distance: float = INF
var _has_expired: bool = false

func setup(
		source: RezonansPlayer,
		origin: Vector2,
		direction: Vector2,
		initial_loudness: float,
		pulse_identifier: int,
		intensity_multiplier: float = 1.0,
		can_return: bool = true,
		maximum_travel_distance: float = -1.0,
		source_velocity: Vector2 = Vector2.ZERO,
) -> void:
	emitter = source
	pulse_id = pulse_identifier
	captured_loudness = clampf(initial_loudness, 0.0, 100.0)
	_energy = clampf(captured_loudness * intensity_multiplier, 0.0, 100.0)
	velocity = direction.normalized() * speed + source_velocity
	var effective_speed := maxf(velocity.length(), 1.0)
	lifetime = lerpf(minimum_lifetime, maximum_lifetime, _energy / 100.0)
	if maximum_travel_distance > 0.0:
		_maximum_travel_distance = maximum_travel_distance * effective_speed / speed
	else:
		_maximum_travel_distance = effective_speed * lifetime
	lifetime = maxf(lifetime, _maximum_travel_distance / effective_speed + 0.05)
	_remaining_lifetime = lifetime
	_return_distance = lerpf(34.0, 72.0, captured_loudness / 100.0)
	_can_return = can_return
	global_position = origin


func _physics_process(delta: float) -> void:
	_remaining_lifetime -= delta
	if _remaining_lifetime <= 0.0 or _energy < 1.0:
		_expire()
		return

	var remaining_distance := _maximum_travel_distance - _distance_traveled
	if remaining_distance <= 0.0:
		_expire()
		return
	var segment_start := global_position
	var step_distance := minf(velocity.length() * delta, remaining_distance)
	var segment_end := segment_start + velocity.normalized() * step_distance
	var query := PhysicsRayQueryParameters2D.create(segment_start, segment_end, collision_mask)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var collision: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)

	if collision.is_empty():
		var traveled_distance := segment_start.distance_to(segment_end)
		_distance_traveled += traveled_distance
		global_position = segment_end
		if bounce_count > 0:
			_distance_after_bounce += traveled_distance
			if _segment_returns_to_owner(segment_start, segment_end, velocity):
				_return_to_owner()
				return
		if _distance_traveled >= _maximum_travel_distance:
			_expire()
		return

	var collision_position: Vector2 = collision["position"]
	var normal: Vector2 = collision["normal"]
	var collision_distance := segment_start.distance_to(collision_position)
	_distance_traveled += collision_distance
	if bounce_count > 0:
		_distance_after_bounce += collision_distance
		if _segment_returns_to_owner(segment_start, collision_position, velocity):
			_return_to_owner()
			return

	bounce_count += 1
	var life_ratio := clampf(_remaining_lifetime / lifetime, 0.0, 1.0)
	var reveal_data := _get_surface_reveal_data(collision, collision_position, normal)
	surface_reached.emit(reveal_data[0], normal, _energy * life_ratio, reveal_data[1])
	bounced.emit(collision_position, normal, bounce_count)
	velocity = velocity.bounce(normal)
	_energy *= bounce_retention
	_distance_after_bounce = 0.0
	global_position = collision_position + normal
	if bounce_count >= max_bounces:
		_expire()


func _get_surface_reveal_data(
		collision: Dictionary,
		collision_position: Vector2,
		normal: Vector2,
) -> Array:
	var collider := collision.get("collider") as Node2D
	if not collider is TileMapLayer:
		return [collision_position, 0.0]

	var tile_layer := collider as TileMapLayer
	if tile_layer.tile_set == null:
		return [collision_position, 0.0]
	var forward_dir := velocity.normalized() if not velocity.is_zero_approx() else -normal
	var probe_points: Array[Vector2] = [
		collision_position - normal * 2.0,
		collision_position - normal * 8.0,
		collision_position + forward_dir * 4.0,
	]
	var found_cell := Vector2i.ZERO
	var has_cell := false
	for probe_point in probe_points:
		var candidate_cell := tile_layer.local_to_map(tile_layer.to_local(probe_point))
		if tile_layer.get_cell_source_id(candidate_cell) >= 0:
			found_cell = candidate_cell
			has_cell = true
			break
	if not has_cell:
		return [collision_position, 0.0]
	var tile_center := tile_layer.to_global(tile_layer.map_to_local(found_cell))
	var tile_scale := maxf(absf(tile_layer.global_scale.x), absf(tile_layer.global_scale.y))
	var tile_size := float(maxi(tile_layer.tile_set.tile_size.x, tile_layer.tile_set.tile_size.y)) * tile_scale
	return [tile_center, tile_size]


func _segment_returns_to_owner(
		segment_start: Vector2,
		segment_end: Vector2,
		travel_velocity: Vector2,
) -> bool:
	if not _can_return or _has_returned or bounce_count == 0 or not is_instance_valid(emitter):
		return false
	if _distance_after_bounce < return_arming_distance:
		return false
	var to_owner := emitter.global_position - segment_start
	if travel_velocity.dot(to_owner) <= 0.0:
		return false
	var closest_point := Geometry2D.get_closest_point_to_segment(
		emitter.global_position,
		segment_start,
		segment_end,
	)
	return closest_point.distance_to(emitter.global_position) <= _return_distance


func _return_to_owner() -> void:
	if _has_returned:
		return
	_has_returned = true
	returned_to_owner.emit(emitter, captured_loudness, pulse_id)
	_expire()


func _expire() -> void:
	if _has_expired:
		return
	_has_expired = true
	set_physics_process(false)
	expired.emit()
	queue_free()
