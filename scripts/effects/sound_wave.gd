class_name SoundWave
extends CharacterBody2D

signal bounced(position: Vector2, normal: Vector2, bounce_count: int)
signal absorbed(position: Vector2)
signal wall_broken(position: Vector2)
signal returned_to_owner(player: RezonansPlayer, captured_loudness: float, pulse_id: int)
signal expired

@export var speed: float = 820.0
@export_range(0, 8) var max_bounces: int = 4
@export var lifetime: float = 1.6
@export_range(0.05, 0.5, 0.05) var bounce_energy_loss: float = 0.2
@export_range(3, 8, 1) var max_trail_points: int = 5
@export_range(0.2, 4.0, 0.1) var alpha_drop_window: float = 2.0
@export_range(0.1, 0.98, 0.01) var alpha_loss_after_window: float = 0.80

var bounce_count: int = 0
var captured_loudness: float = 0.0
var pulse_id: int = 0
var emitter: RezonansPlayer
var trail_points: PackedVector2Array = PackedVector2Array()
var _remaining_lifetime: float = 0.0
var _decay_power: float = 1.0


func setup(source: RezonansPlayer, origin: Vector2, direction: Vector2, initial_loudness: float, pulse_identifier: int) -> void:
	emitter = source
	pulse_id = pulse_identifier
	captured_loudness = clampf(initial_loudness, 0.0, 100.0)
	scale = Vector2.ONE
	global_position = origin
	velocity = direction.normalized() * speed
	_remaining_lifetime = lifetime
	_decay_power = _compute_decay_power(lifetime)
	trail_points = PackedVector2Array([origin])


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

		if collider and collider.is_in_group(&"breakable_wall"):
			if captured_loudness >= 90.0:
				if collider.has_method("break_wall"):
					collider.break_wall(velocity.normalized())
				wall_broken.emit(collision_position)
				expired.emit()
				queue_free()
				return
			elif collider.has_method("pulse_resonance"):
				collider.pulse_resonance()

		bounce_count += 1
		var normal := collision.get_normal()
		var bounced_dir := velocity.bounce(normal).normalized()
		var next_speed := maxf(speed * 0.35, velocity.length() * (1.0 - bounce_energy_loss * 0.4))
		velocity = bounced_dir * next_speed
		global_position += normal * 0.5
		_append_trail_point(collision_position)
		bounced.emit(collision_position, normal, bounce_count)
		if _remaining_lifetime <= 0.0:
			expired.emit()
			queue_free()
			return
	else:
		_append_trail_point(global_position)


func _process(_delta: float) -> void:
	var fade := clampf(_remaining_lifetime / maxf(0.001, lifetime), 0.0, 1.0)
	modulate.a = pow(fade, _decay_power)


func _compute_decay_power(max_lifetime: float) -> float:
	if max_lifetime <= 0.002:
		return 1.0
	var drop_time := minf(alpha_drop_window, max_lifetime * 0.5)
	var ratio_at_drop := clampf(1.0 - drop_time / max_lifetime, 0.01, 0.99)
	var remaining_ratio_at_drop := clampf(1.0 - alpha_loss_after_window, 0.001, 0.99)
	return log(remaining_ratio_at_drop) / log(ratio_at_drop)


func _append_trail_point(point: Vector2) -> void:
	trail_points.append(point)
	while trail_points.size() > max_trail_points:
		trail_points.remove_at(0)


func _on_return_detector_body_entered(_body: Node2D) -> void:
	pass
