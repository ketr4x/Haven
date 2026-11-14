class_name SoundWave
extends CharacterBody2D

signal bounced(position: Vector2, normal: Vector2, bounce_count: int)
signal returned_to_owner(player: RezonansPlayer, captured_loudness: float, pulse_id: int)
signal expired

@export var speed: float = 760.0
@export_range(0, 5) var max_bounces: int = 2
@export var lifetime: float = 1.6
@export var beam_fade_distance: float = 1_200.0
@export_range(0.0, 1.0) var beam_min_alpha: float = 0.06

@onready var _beam_trail: Line2D = $BeamTrail

var bounce_count: int = 0
var captured_loudness: float = 0.0
var pulse_id: int = 0
var emitter: RezonansPlayer
var _remaining_lifetime: float = 0.0
var _has_returned: bool = false
var _travel_distance: float = 0.0
var _initial_beam_alpha: float = 0.0
var _trail_points: PackedVector2Array = PackedVector2Array()

func setup(source: RezonansPlayer, origin: Vector2, direction: Vector2, initial_loudness: float, pulse_identifier: int) -> void:
	emitter = source
	pulse_id = pulse_identifier
	captured_loudness = clampf(initial_loudness, 0.0, 100.0)
	var size_multiplier := lerpf(0.55, 2.1, captured_loudness / 100.0)
	scale = Vector2.ONE * size_multiplier
	global_position = origin
	velocity = direction.normalized() * speed
	_remaining_lifetime = lifetime
	_travel_distance = 0.0
	_trail_points = PackedVector2Array([origin, origin])
	_initial_beam_alpha = lerpf(0.32, 0.82, captured_loudness / 100.0)
	_beam_trail.default_color.a = _initial_beam_alpha
	_update_beam_trail()


func _physics_process(delta: float) -> void:
	_remaining_lifetime -= delta
	if _remaining_lifetime <= 0.0:
		expired.emit()
		queue_free()
		return

	var previous_position := global_position
	var collision := move_and_collide(velocity * delta)
	_travel_distance += previous_position.distance_to(global_position)
	_append_trail_point(global_position)
	if collision:
		bounce_count += 1
		var normal := collision.get_normal()
		velocity = velocity.bounce(normal)
		global_position += normal * 0.5
		_append_trail_point(global_position)
		bounced.emit(global_position, normal, bounce_count)
		if bounce_count >= max_bounces:
			expired.emit()
			queue_free()
			return

	_update_beam_visibility()
	if bounce_count > 0 and emitter and global_position.distance_to(emitter.global_position) <= 42.0 * scale.x:
		_return_to_owner()


func _append_trail_point(point: Vector2) -> void:
	if _trail_points.is_empty() or _trail_points[_trail_points.size() - 1].distance_to(point) > 0.1:
		_trail_points.append(point)
	_update_beam_trail()


func _update_beam_trail() -> void:
	_beam_trail.global_position = Vector2.ZERO
	_beam_trail.points = _trail_points


func _update_beam_visibility() -> void:
	var fade_progress := clampf(_travel_distance / beam_fade_distance, 0.0, 1.0)
	_beam_trail.default_color.a = lerpf(_initial_beam_alpha, beam_min_alpha, fade_progress)


func _process(_delta: float) -> void:
	var fade := clampf(_remaining_lifetime / lifetime, 0.0, 1.0)
	modulate.a = fade


func _on_return_detector_body_entered(body: Node2D) -> void:
	if _has_returned or bounce_count == 0 or body != emitter:
		return

	_return_to_owner()


func _return_to_owner() -> void:
	if _has_returned:
		return

	_has_returned = true
	returned_to_owner.emit(emitter, captured_loudness, pulse_id)
	expired.emit()
	queue_free()
