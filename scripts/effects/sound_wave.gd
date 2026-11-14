class_name SoundWave
extends CharacterBody2D

signal bounced(position: Vector2, normal: Vector2, bounce_count: int)
signal absorbed(position: Vector2)
signal returned_to_owner(player: RezonansPlayer, captured_loudness: float, pulse_id: int)
signal expired

@export var speed: float = 760.0
@export_range(0, 5) var max_bounces: int = 2
@export var lifetime: float = 1.6

var bounce_count: int = 0
var captured_loudness: float = 0.0
var pulse_id: int = 0
var emitter: RezonansPlayer
var _remaining_lifetime: float = 0.0
var _return_distance: float = 42.0
var _has_returned: bool = false

func setup(source: RezonansPlayer, origin: Vector2, direction: Vector2, initial_loudness: float, pulse_identifier: int) -> void:
	emitter = source
	pulse_id = pulse_identifier
	captured_loudness = clampf(initial_loudness, 0.0, 100.0)
	var size_multiplier := lerpf(0.55, 2.1, captured_loudness / 100.0)
	# Radial probes stay small so floor-facing rays never spawn embedded in terrain.
	scale = Vector2.ONE
	_return_distance = 42.0 * size_multiplier
	global_position = origin
	velocity = direction.normalized() * speed
	_remaining_lifetime = lifetime


func _physics_process(delta: float) -> void:
	_remaining_lifetime -= delta
	if _remaining_lifetime <= 0.0:
		expired.emit()
		queue_free()
		return

	var collision := move_and_collide(velocity * delta)
	if collision:
		var collision_position := collision.get_position()
		var collider := collision.get_collider() as Node
		if collider and collider.is_in_group(&"sound_absorber"):
			absorbed.emit(collision_position)
			expired.emit()
			queue_free()
			return

		bounce_count += 1
		var normal := collision.get_normal()
		velocity = velocity.bounce(normal)
		global_position += normal * 0.5
		bounced.emit(collision_position, normal, bounce_count)
		if bounce_count >= max_bounces:
			expired.emit()
			queue_free()
			return

	if bounce_count > 0 and emitter and global_position.distance_to(emitter.global_position) <= _return_distance:
		_return_to_owner()


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
