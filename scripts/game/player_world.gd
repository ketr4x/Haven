class_name PlayerWorld
extends Node2D

enum ReturnEffect {
	NONE,
	ECHO_SURF,
	SLOW,
	PLUS_BOOST,
}

signal player_finished(player_number: int)

@export_category("Player")
@export var player_number: int = 1
@export var left_action: StringName = &"p1_left"
@export var right_action: StringName = &"p1_right"
@export var jump_action: StringName = &"p1_jump"
@export var shout_action: StringName = &"p1_shout"
@export var big_scream_minus_action: StringName = &"p1_big_scream_minus"
@export var big_scream_plus_action: StringName = &"p1_big_scream_plus"
@export var player_color: Color = Color(1, 0.32, 0.62, 1)
@export var mirror_course_horizontally: bool = false

@export_category("Sound Propagation")
@export var sound_wave_scene: PackedScene
@export var reveal_ring_scene: PackedScene
@export_range(8, 96) var intro_wave_count: int = 48
@export_range(4, 24) var footstep_wave_count: int = 8
@export_range(8, 48) var large_footstep_wave_count: int = 28
@export_range(4, 32) var jump_wave_count: int = 12
@export_range(6, 32) var landing_wave_count: int = 12
@export_range(24, 96) var hard_landing_wave_count: int = 72
@export_range(8, 64) var big_scream_wave_count: int = 36
@export_range(4, 40) var wall_jump_wave_count: int = 20
@export_range(2, 8) var large_footstep_frequency: int = 4
@export_range(0.5, 0.9, 0.05) var forward_wave_ratio: float = 0.7
@export_range(0.1, 0.8, 0.05) var rear_intensity: float = 0.42
@export_range(1.0, 100.0, 1.0) var intro_pulse_loudness: float = 55.0
@export_range(1.0, 100.0, 1.0) var reflected_echo_threshold: float = 30.0

@export_category("Action Loudness")
@export_range(0.1, 1.0) var footstep_loudness_multiplier: float = 0.28
@export_range(0.1, 1.0) var jump_loudness_multiplier: float = 0.28
@export_range(0.1, 1.0) var landing_loudness_multiplier: float = 0.42
@export_range(0.1, 1.0) var wall_jump_loudness_multiplier: float = 0.55
@export_range(0.1, 1.0) var footstep_ring_scale: float = 0.45
@export_range(0.4, 1.0) var large_footstep_ring_scale: float = 0.8

@onready var _generator: CourseGenerator = $CourseGenerator
@onready var _player: RezonansPlayer = $Player
@onready var _finish_area: FinishArea = $FinishArea
@onready var _audio_feedback: AudioFeedback = $AudioFeedback
@onready var _waves: Node2D = $FeedbackCanvas/Waves
@onready var _echo_overlay: EchoOverlay = $EchoCanvas/EchoOverlay

var _next_pulse_id: int = 0
var _footstep_count: int = 0
var _activated_pulses: Dictionary = {}
var _reflected_pulses: Dictionary = {}
var _pulse_return_effects: Dictionary = {}
var _pulse_echo_colors: Dictionary = {}

func _ready() -> void:
	_player.left_action = left_action
	_player.right_action = right_action
	_player.jump_action = jump_action
	_player.shout_action = shout_action
	_player.big_scream_minus_action = big_scream_minus_action
	_player.big_scream_plus_action = big_scream_plus_action
	_player.modulate = player_color
	_generator.mirror_horizontally = mirror_course_horizontally
	_echo_overlay.set_player_color(player_color)
	_echo_overlay.set_reveal_source(_player)
	var camera := _player.get_node("Camera2D") as Camera2D
	camera.enabled = true
	camera.make_current()

	_generator.course_generated.connect(_on_course_generated)
	_finish_area.player_finished.connect(_on_finish_area_player_finished)
	_player.sonic_shouted.connect(_on_player_sonic_shouted)
	_player.big_scream_minus_emitted.connect(_on_big_scream_minus_emitted)
	_player.big_scream_plus_emitted.connect(_on_big_scream_plus_emitted)
	_player.footstep_emitted.connect(_on_footstep_emitted)
	_player.landed.connect(_on_player_landed)
	_player.jumped.connect(_on_player_jumped)
	_player.wall_jumped.connect(_on_player_wall_jumped)
	_player.obstacle_hit.connect(_on_player_obstacle_hit)


func generate_course(seed: int) -> void:
	_generator.generate_course(seed)


func set_race_active(is_active: bool) -> void:
	_player.set_physics_process(is_active)
	_finish_area.monitoring = is_active


func emit_intro_pulse() -> void:
	_spawn_sound_pulse(
		_player.global_position + Vector2(0.0, 8.0),
		Vector2(_player.facing_direction, 0.0),
		intro_pulse_loudness,
		intro_wave_count,
		ReturnEffect.NONE,
		0.72,
		0.78,
	)


func _on_player_sonic_shouted(_origin: Vector2, _direction: Vector2, _loudness: float) -> void:
	_audio_feedback.play_shout()


func _on_big_scream_minus_emitted(origin: Vector2, direction: Vector2, loudness: float) -> void:
	_audio_feedback.play_shout()
	_spawn_concentrated_pulse(origin, direction, loudness, false)


func _on_big_scream_plus_emitted(origin: Vector2, direction: Vector2, loudness: float) -> void:
	_audio_feedback.play_shout()
	_spawn_concentrated_pulse(origin, direction, loudness, true)


func _on_footstep_emitted(origin: Vector2, direction: Vector2, loudness: float) -> void:
	_audio_feedback.play_footstep()
	_footstep_count += 1
	var is_large_step := _footstep_count % large_footstep_frequency == 0
	var action_loudness := maxf(6.0, loudness * footstep_loudness_multiplier)
	var wave_count := footstep_wave_count
	var return_effect := ReturnEffect.NONE
	var ring_scale := footstep_ring_scale
	var direction_ratio := 0.55
	if is_large_step:
		action_loudness = maxf(45.0, loudness * 0.65)
		wave_count = large_footstep_wave_count
		return_effect = ReturnEffect.ECHO_SURF
		ring_scale = large_footstep_ring_scale
		direction_ratio = 0.82
	_spawn_sound_pulse(
		origin + Vector2(0.0, 12.0),
		direction,
		action_loudness,
		wave_count,
		return_effect,
		ring_scale,
		direction_ratio,
	)


func _on_player_landed(position: Vector2, impact_speed: float) -> void:
	_audio_feedback.play_landing()
	var direction := Vector2(_player.facing_direction, 0.0)
	if impact_speed >= _player.hard_landing_speed:
		var impact_ratio := clampf(
			inverse_lerp(_player.hard_landing_speed, _player.hard_landing_speed * 1.8, impact_speed),
			0.0,
			1.0,
		)
		var action_loudness := lerpf(65.0, 100.0, impact_ratio)
		_spawn_sound_pulse(
			position + Vector2(0.0, 12.0),
			direction,
			action_loudness,
			hard_landing_wave_count,
			ReturnEffect.ECHO_SURF,
			1.0,
			0.86,
		)
		return

	var action_loudness := maxf(16.0, _player.loudness * landing_loudness_multiplier)
	_spawn_sound_pulse(
		position + Vector2(0.0, 12.0),
		direction,
		action_loudness,
		landing_wave_count,
		ReturnEffect.NONE,
		0.7,
		0.7,
	)


func _on_player_jumped(position: Vector2) -> void:
	_audio_feedback.play_jump()
	var action_loudness := maxf(12.0, _player.loudness * jump_loudness_multiplier)
	_spawn_sound_pulse(
		position + Vector2(0.0, 12.0),
		Vector2(_player.facing_direction, 0.0),
		action_loudness,
		jump_wave_count,
		ReturnEffect.NONE,
		0.6,
		0.72,
	)


func _on_player_wall_jumped(position: Vector2, normal: Vector2) -> void:
	_audio_feedback.play_wall_jump()
	var action_loudness := maxf(24.0, _player.loudness * wall_jump_loudness_multiplier)
	_spawn_sound_pulse(position, normal, action_loudness, wall_jump_wave_count, ReturnEffect.NONE, 0.75, 0.78)


func _on_player_obstacle_hit(_position: Vector2, _normal: Vector2, _impact_speed: float) -> void:
	_audio_feedback.play_wave_bounce(Vector2.ZERO, Vector2.ZERO, 1)


func _on_player_pulsed(
		origin: Vector2,
		direction: Vector2,
		loudness: float,
		ray_count: int,
		ring_scale: float = 1.0,
) -> void:
	# Kept for deterministic checks and authored events; no input action calls this method.
	_spawn_sound_pulse(origin, direction, loudness, ray_count, ReturnEffect.ECHO_SURF, ring_scale)


func _spawn_sound_pulse(
		origin: Vector2,
		forward: Vector2,
		loudness: float,
		ray_count: int,
		return_effect: int,
		ring_scale: float,
		emission_forward_ratio: float = -1.0,
) -> void:
	if sound_wave_scene == null or reveal_ring_scene == null:
		return
	var normalized_forward := forward.normalized() if not forward.is_zero_approx() else Vector2.RIGHT
	var direction_ratio := forward_wave_ratio if emission_forward_ratio < 0.0 \
		else clampf(emission_forward_ratio, 0.5, 0.95)
	var source_velocity := _player.velocity
	var pulse := _spawn_reveal_ring(origin, normalized_forward, loudness, ring_scale, source_velocity)
	var probe_cone_degrees := pulse.arc_angle_degrees * lerpf(1.0, 0.72, direction_ratio)
	var pulse_id := _begin_pulse(return_effect, Color(1.0, 0.46, 0.54, 1.0))
	for wave_direction in _sample_concentrated_directions(normalized_forward, ray_count, probe_cone_degrees):
		_spawn_wave_probe(
			origin,
			wave_direction,
			loudness,
			pulse_id,
			_directional_intensity(wave_direction, normalized_forward),
			return_effect,
			pulse.maximum_radius,
			normalized_forward,
			source_velocity,
		)


func _spawn_concentrated_pulse(origin: Vector2, forward: Vector2, loudness: float, is_positive: bool) -> void:
	if sound_wave_scene == null or reveal_ring_scene == null:
		return
	var normalized_forward := forward.normalized() if not forward.is_zero_approx() else Vector2.RIGHT
	var source_velocity := _player.velocity
	var pulse := reveal_ring_scene.instantiate() as RevealRing
	_waves.add_child(pulse)
	pulse.global_position = origin
	pulse.configure_big_scream(normalized_forward, is_positive, source_velocity)
	var return_effect := ReturnEffect.PLUS_BOOST if is_positive else ReturnEffect.SLOW
	var echo_color := Color(0.95, 0.72, 0.24, 1.0) if is_positive else Color(1.0, 0.2, 0.32, 1.0)
	var pulse_id := _begin_pulse(return_effect, echo_color, true)
	for wave_direction in _sample_concentrated_directions(normalized_forward, big_scream_wave_count, 30.0):
		_spawn_wave_probe(
			origin,
			wave_direction,
			loudness,
			pulse_id,
			1.0,
			return_effect,
			pulse.maximum_radius,
			normalized_forward,
			source_velocity,
		)


func _begin_pulse(return_effect: int, echo_color: Color, store_echo_color: bool = false) -> int:
	_next_pulse_id += 1
	var pulse_id := _next_pulse_id
	if return_effect != ReturnEffect.NONE:
		_pulse_return_effects[pulse_id] = return_effect
	if store_echo_color:
		_pulse_echo_colors[pulse_id] = echo_color
	var expired_pulse_id := pulse_id - 256
	if expired_pulse_id > 0:
		_pulse_return_effects.erase(expired_pulse_id)
		_pulse_echo_colors.erase(expired_pulse_id)
		_reflected_pulses.erase(expired_pulse_id)
		_activated_pulses.erase(expired_pulse_id)
	return pulse_id


func _spawn_wave_probe(
		origin: Vector2,
		direction: Vector2,
		loudness: float,
		pulse_id: int,
		intensity: float,
		return_effect: int,
		maximum_distance: float,
		forward: Vector2,
		source_velocity: Vector2 = Vector2.ZERO,
) -> void:
	var wave := sound_wave_scene.instantiate() as SoundWave
	_waves.add_child(wave)
	wave.setup(
		_player,
		origin + direction * 2.0,
		direction,
		loudness,
		pulse_id,
		intensity,
		return_effect != ReturnEffect.NONE,
		maximum_distance,
		source_velocity,
	)
	wave.surface_reached.connect(_echo_overlay.register_hit)
	wave.bounced.connect(_audio_feedback.play_wave_bounce)
	wave.bounced.connect(_on_probe_bounced.bind(forward, loudness, pulse_id))
	wave.returned_to_owner.connect(_on_wave_returned)


func _sample_concentrated_directions(forward: Vector2, ray_count: int, cone_degrees: float) -> Array[Vector2]:
	var directions: Array[Vector2] = []
	var half_cone := deg_to_rad(cone_degrees) * 0.5
	for index in ray_count:
		var progress := 0.5 if ray_count == 1 else float(index) / float(ray_count - 1)
		directions.append(Vector2.from_angle(forward.angle() + lerpf(-half_cone, half_cone, progress)))
	return directions


func _directional_intensity(direction: Vector2, forward: Vector2) -> float:
	var forward_amount := clampf((direction.normalized().dot(forward.normalized()) + 1.0) * 0.5, 0.0, 1.0)
	return lerpf(rear_intensity, 1.0, forward_amount * forward_amount)


func _spawn_reveal_ring(
		origin: Vector2,
		direction: Vector2,
		loudness: float,
		ring_scale: float,
		source_velocity: Vector2 = Vector2.ZERO,
) -> RevealRing:
	var pulse := reveal_ring_scene.instantiate() as RevealRing
	_waves.add_child(pulse)
	pulse.global_position = origin
	pulse.configure(loudness, ring_scale, direction, source_velocity)
	return pulse


func _on_probe_bounced(
		position: Vector2,
		normal: Vector2,
		bounce_count: int,
		forward: Vector2,
		loudness: float,
		pulse_id: int,
) -> void:
	if bounce_count != 1 or loudness < reflected_echo_threshold or _reflected_pulses.has(pulse_id):
		return
	if absf(normal.x) < 0.72 or normal.dot(forward) > -0.55:
		return
	_reflected_pulses[pulse_id] = true
	var return_direction := (_player.global_position - position).normalized()
	var echo_color: Color = _pulse_echo_colors.get(pulse_id, Color(1.0, 0.46, 0.54, 1.0))
	var echo := reveal_ring_scene.instantiate() as RevealRing
	_waves.add_child(echo)
	echo.global_position = position + normal * 4.0
	echo.configure_echo(return_direction, loudness, echo_color)


func _on_wave_returned(_owner: RezonansPlayer, _loudness: float, pulse_id: int) -> void:
	if _activated_pulses.has(pulse_id):
		return
	var return_effect := int(_pulse_return_effects.get(pulse_id, ReturnEffect.NONE))
	if return_effect == ReturnEffect.NONE:
		return
	_activated_pulses[pulse_id] = true
	_audio_feedback.play_echo_return()
	match return_effect:
		ReturnEffect.ECHO_SURF:
			_player.offer_echo_boost()
		ReturnEffect.SLOW:
			_player.apply_echo_slow()
		ReturnEffect.PLUS_BOOST:
			_player.apply_rebound_boost()
			_player.offer_echo_boost()


func _on_course_generated(_seed: int, _signature: String) -> void:
	_player.global_position = _generator.to_global(_generator.player_spawn)
	_player.velocity = Vector2.ZERO
	_player.set_facing_direction(-1.0 if mirror_course_horizontally else 1.0)
	_finish_area.global_position = _generator.to_global(_generator.finish_position)
	_finish_area.monitoring = true
	_footstep_count = 0
	_activated_pulses.clear()
	_reflected_pulses.clear()
	_pulse_return_effects.clear()
	_pulse_echo_colors.clear()
	_clear_waves()


func _clear_waves() -> void:
	for wave in _waves.get_children():
		_waves.remove_child(wave)
		wave.queue_free()


func _on_finish_area_player_finished(_finisher: RezonansPlayer) -> void:
	_finish_area.set_deferred("monitoring", false)
	_audio_feedback.play_finish()
	player_finished.emit(player_number)
