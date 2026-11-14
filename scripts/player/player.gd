class_name RezonansPlayer
extends CharacterBody2D

signal landed(position: Vector2, impact_speed: float)
signal jumped(position: Vector2)
signal wall_jumped(position: Vector2, normal: Vector2)
signal sonic_shouted(origin: Vector2, direction: Vector2, loudness: float)
signal big_scream_minus_emitted(origin: Vector2, direction: Vector2, loudness: float)
signal big_scream_plus_emitted(origin: Vector2, direction: Vector2, loudness: float)
signal footstep_emitted(origin: Vector2, direction: Vector2, loudness: float)
signal obstacle_hit(position: Vector2, normal: Vector2, impact_speed: float)
signal rebound_boost_started
signal rebound_boost_ended

@export_category("Input")
@export var left_action: StringName = &"p1_left"
@export var right_action: StringName = &"p1_right"
@export var jump_action: StringName = &"p1_jump"
@export var shout_action: StringName = &"p1_shout"
@export var big_scream_minus_action: StringName = &"p1_big_scream_minus"
@export var big_scream_plus_action: StringName = &"p1_big_scream_plus"

@export_category("Movement")
@export var run_speed: float = 300.0
@export var ground_acceleration: float = 2_400.0
@export var air_acceleration: float = 1_500.0
@export var ground_deceleration: float = 2_800.0
@export var gravity: float = 1_600.0
@export var jump_velocity: float = -560.0
@export var wall_slide_speed: float = 120.0
@export var wall_jump_horizontal_speed: float = 340.0
@export_range(0.05, 0.3, 0.01) var wall_jump_coyote_time: float = 0.16
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

@export_category("Sound Actions")
@export var shout_cooldown: float = 0.45
@export var big_scream_cooldown: float = 0.8
@export_range(1.0, 100.0, 1.0) var big_scream_loudness: float = 100.0

@export_category("Echolocation")
@export_range(1.0, 100.0) var max_loudness: float = 100.0
@export var running_loudness_per_second: float = 24.0
@export var wall_loudness_per_second: float = 36.0
@export var footstep_interval: float = 0.3
@export var idle_loudness_decay_per_second: float = 18.0
@export var hard_landing_speed: float = 480.0
@export var hard_landing_loudness_gain: float = 34.0

@export_category("Echo Surf")
@export_range(0.05, 0.3, 0.01) var echo_timing_window: float = 0.2
@export var echo_boost_speed_multiplier: float = 1.8
@export var echo_boost_jump_multiplier: float = 1.38
@export_range(0.1, 1.0, 0.05) var echo_slow_duration: float = 0.5
@export_range(0.3, 0.95, 0.05) var echo_slow_multiplier: float = 0.65

@export_category("Obstacle Impact")
@export var obstacle_impact_speed: float = 235.0
@export_range(0.0, 0.04, 0.005) var impact_hitstop_duration: float = 0.035
@export var obstacle_rebound_speed: float = 190.0
@export var obstacle_rebound_upward_speed: float = 72.0
@export_range(0.05, 0.5, 0.01) var obstacle_impact_cooldown: float = 0.2
@export_range(0.05, 0.4, 0.01) var camera_shake_duration: float = 0.16
@export_range(1.0, 12.0, 1.0) var camera_shake_strength: float = 5.0

@export_category("Rebound Boost")
@export var rebound_boost_duration: float = 1.4
@export var rebound_speed_multiplier: float = 1.35
@export var rebound_jump_multiplier: float = 1.18

@export_category("Presentation")
@export var camera_enabled: bool = false

@onready var _camera: Camera2D = $Camera2D
@onready var _boost_aura: Polygon2D = $BoostAura
@onready var _facing_marker: Polygon2D = $FacingMarker
@onready var _landing_dust: CPUParticles2D = $LandingDust
@onready var _wall_dust: CPUParticles2D = $WallDust
@onready var _shout_sparks: CPUParticles2D = $ShoutSparks
@onready var _boost_trail: CPUParticles2D = $BoostTrail
@onready var _impact_debris: CPUParticles2D = $ImpactDebris

var facing_direction: float = 1.0
var loudness: float = 0.0
var _coyote_time_remaining: float = 0.0
var _wall_jump_time_remaining: float = 0.0
var _last_wall_normal: Vector2 = Vector2.ZERO
var _jump_buffer_remaining: float = 0.0
var _jump_press_age: float = INF
var _echo_opportunity_remaining: float = 0.0
var _echo_slow_remaining: float = 0.0
var _shout_cooldown_remaining: float = 0.0
var _big_scream_cooldown_remaining: float = 0.0
var _boost_time_remaining: float = 0.0
var _footstep_time_remaining: float = 0.0
var _was_on_floor: bool = false
var _impact_hitstop_remaining: float = 0.0
var _impact_cooldown_remaining: float = 0.0
var _queued_rebound_velocity: Vector2 = Vector2.ZERO
var _camera_shake_remaining: float = 0.0
var _camera_shake_phase: float = 0.0
var _camera_base_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	_camera.enabled = camera_enabled
	_camera_base_offset = _camera.offset
	set_facing_direction(facing_direction)
	_boost_aura.visible = false
	_landing_dust.emitting = false
	_wall_dust.emitting = false
	_shout_sparks.emitting = false
	_boost_trail.emitting = false
	_impact_debris.emitting = false


func set_facing_direction(direction: float) -> void:
	if is_zero_approx(direction):
		return
	facing_direction = signf(direction)
	_facing_marker.scale.x = facing_direction


func offer_echo_boost(timing_window: float = -1.0) -> void:
	var window := echo_timing_window if timing_window < 0.0 else timing_window
	if _jump_press_age <= window:
		_activate_echo_boost()
	else:
		_echo_opportunity_remaining = maxf(_echo_opportunity_remaining, window)


func apply_echo_slow() -> void:
	_echo_slow_remaining = echo_slow_duration
	velocity.x *= echo_slow_multiplier


func _physics_process(delta: float) -> void:
	_update_impact_feedback(delta)
	_update_echo_timing(delta)
	_update_jump_buffer(delta)
	if _impact_hitstop_remaining > 0.0:
		return

	_update_rebound_boost(delta)
	_update_loudness(delta)
	_shout_cooldown_remaining = maxf(0.0, _shout_cooldown_remaining - delta)
	_big_scream_cooldown_remaining = maxf(0.0, _big_scream_cooldown_remaining - delta)
	_update_horizontal_velocity(delta)
	_apply_gravity(delta)
	_try_jump()
	_apply_wall_slide()

	var velocity_before_move := velocity
	move_and_slide()
	_handle_obstacle_impact(velocity_before_move)
	_update_ground_state(delta, maxf(0.0, velocity_before_move.y))
	_update_wall_jump_state(delta)
	_emit_footstep_if_running(delta)
	_emit_shout_if_requested()
	_emit_big_scream_if_requested()


func _update_echo_timing(delta: float) -> void:
	_jump_press_age = minf(_jump_press_age + delta, 10.0)
	_echo_opportunity_remaining = maxf(0.0, _echo_opportunity_remaining - delta)
	_echo_slow_remaining = maxf(0.0, _echo_slow_remaining - delta)


func _update_loudness(delta: float) -> void:
	var gain := 0.0
	if absf(velocity.x) > 30.0:
		gain += running_loudness_per_second * delta
	if is_on_wall_only() and not is_on_floor():
		gain += wall_loudness_per_second * delta
	if is_zero_approx(gain):
		loudness = maxf(0.0, loudness - idle_loudness_decay_per_second * delta)
	else:
		loudness = minf(max_loudness, loudness + gain)


func _add_loudness(amount: float) -> void:
	loudness = clampf(loudness + amount, 0.0, max_loudness)


func apply_rebound_boost() -> void:
	_boost_time_remaining = rebound_boost_duration
	velocity.x = facing_direction * maxf(absf(velocity.x), run_speed * rebound_speed_multiplier)
	_boost_aura.visible = true
	_boost_trail.emitting = true
	rebound_boost_started.emit()


func _activate_echo_boost() -> void:
	apply_rebound_boost()
	velocity.x = facing_direction * maxf(absf(velocity.x), run_speed * echo_boost_speed_multiplier)
	velocity.y = minf(velocity.y, jump_velocity * echo_boost_jump_multiplier)
	_echo_opportunity_remaining = 0.0
	_jump_buffer_remaining = 0.0


func _update_rebound_boost(delta: float) -> void:
	if is_zero_approx(_boost_time_remaining):
		return

	_boost_time_remaining = maxf(0.0, _boost_time_remaining - delta)
	if is_zero_approx(_boost_time_remaining):
		_boost_aura.visible = false
		_boost_trail.emitting = false
		rebound_boost_ended.emit()


func _speed_multiplier() -> float:
	var multiplier := rebound_speed_multiplier if _boost_time_remaining > 0.0 else 1.0
	if _echo_slow_remaining > 0.0:
		multiplier *= echo_slow_multiplier
	return multiplier


func _jump_multiplier() -> float:
	return rebound_jump_multiplier if _boost_time_remaining > 0.0 else 1.0


func _update_jump_buffer(delta: float) -> void:
	if Input.is_action_just_pressed(jump_action):
		_jump_press_age = 0.0
		_jump_buffer_remaining = jump_buffer_time
		if _echo_opportunity_remaining > 0.0:
			_activate_echo_boost()
	else:
		_jump_buffer_remaining = maxf(0.0, _jump_buffer_remaining - delta)


func _update_horizontal_velocity(delta: float) -> void:
	var input_axis := Input.get_axis(left_action, right_action)
	if not is_zero_approx(input_axis):
		set_facing_direction(input_axis)
		_boost_trail.direction = Vector2(-facing_direction, -0.15).normalized()
		var acceleration := ground_acceleration if is_on_floor() else air_acceleration
		velocity.x = move_toward(velocity.x, input_axis * run_speed * _speed_multiplier(), acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, ground_deceleration * delta)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta


func _try_jump() -> void:
	if is_zero_approx(_jump_buffer_remaining):
		return

	if _wall_jump_time_remaining > 0.0:
		velocity = Vector2(_last_wall_normal.x * wall_jump_horizontal_speed, jump_velocity * _jump_multiplier())
		set_facing_direction(_last_wall_normal.x)
		_jump_buffer_remaining = 0.0
		_wall_jump_time_remaining = 0.0
		_wall_dust.position = Vector2(-_last_wall_normal.x * 12.0, 6.0)
		_wall_dust.direction = Vector2(_last_wall_normal.x, -0.35).normalized()
		_play_particle_burst(_wall_dust)
		wall_jumped.emit(global_position, _last_wall_normal)
		return

	if is_on_floor() or _coyote_time_remaining > 0.0:
		velocity.y = jump_velocity * _jump_multiplier()
		_coyote_time_remaining = 0.0
		_jump_buffer_remaining = 0.0
		jumped.emit(global_position)


func _apply_wall_slide() -> void:
	if is_on_wall_only() and not is_on_floor() and velocity.y > wall_slide_speed:
		velocity.y = wall_slide_speed


func _update_ground_state(delta: float, impact_speed: float) -> void:
	if is_on_floor():
		_coyote_time_remaining = coyote_time
		if not _was_on_floor:
			_play_particle_burst(_landing_dust)
			if impact_speed >= hard_landing_speed:
				_add_loudness(hard_landing_loudness_gain)
			landed.emit(global_position, impact_speed)
	else:
		_coyote_time_remaining = maxf(0.0, _coyote_time_remaining - delta)
	_was_on_floor = is_on_floor()


func _update_wall_jump_state(delta: float) -> void:
	if is_on_wall_only():
		_last_wall_normal = get_wall_normal()
		_wall_jump_time_remaining = wall_jump_coyote_time
	else:
		_wall_jump_time_remaining = maxf(0.0, _wall_jump_time_remaining - delta)


func _handle_obstacle_impact(velocity_before_move: Vector2) -> void:
	if _impact_cooldown_remaining > 0.0:
		return
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var normal := collision.get_normal()
		if absf(normal.x) < 0.72:
			continue
		var impact_speed := velocity_before_move.dot(-normal)
		if impact_speed < obstacle_impact_speed:
			continue
		_trigger_obstacle_impact(collision.get_position(), normal, impact_speed, velocity_before_move)
		return


func _trigger_obstacle_impact(
		position: Vector2,
		normal: Vector2,
		impact_speed: float,
		velocity_before_move: Vector2,
) -> void:
	_impact_cooldown_remaining = obstacle_impact_cooldown
	_impact_hitstop_remaining = minf(impact_hitstop_duration, 0.04)
	_queued_rebound_velocity = Vector2(
		normal.x * obstacle_rebound_speed,
		minf(velocity_before_move.y, -obstacle_rebound_upward_speed),
	)
	velocity = Vector2.ZERO
	_camera_shake_remaining = camera_shake_duration
	_camera_shake_phase = 0.0
	_impact_debris.position = to_local(position)
	_impact_debris.direction = Vector2(normal.x, -0.25).normalized()
	_play_particle_burst(_impact_debris)
	obstacle_hit.emit(position, normal, impact_speed)


func _update_impact_feedback(delta: float) -> void:
	_impact_cooldown_remaining = maxf(0.0, _impact_cooldown_remaining - delta)
	if _impact_hitstop_remaining > 0.0:
		_impact_hitstop_remaining = maxf(0.0, _impact_hitstop_remaining - delta)
		if is_zero_approx(_impact_hitstop_remaining):
			velocity = _queued_rebound_velocity

	if _camera_shake_remaining <= 0.0:
		_camera.offset = _camera_base_offset
		return
	_camera_shake_remaining = maxf(0.0, _camera_shake_remaining - delta)
	_camera_shake_phase += delta * 58.0
	var shake_ratio := _camera_shake_remaining / camera_shake_duration
	var strength := camera_shake_strength * shake_ratio
	_camera.offset = _camera_base_offset + Vector2(
		roundf(sin(_camera_shake_phase) * strength),
		roundf(cos(_camera_shake_phase * 1.7) * strength * 0.65),
	)


func _emit_footstep_if_running(delta: float) -> void:
	if not is_on_floor() or absf(velocity.x) < 80.0:
		_footstep_time_remaining = 0.0
		return

	_footstep_time_remaining -= delta
	if _footstep_time_remaining <= 0.0:
		_footstep_time_remaining = footstep_interval
		footstep_emitted.emit(global_position, Vector2(facing_direction, 0.0), loudness)


func _emit_shout_if_requested() -> void:
	if Input.is_action_just_pressed(shout_action) and is_zero_approx(_shout_cooldown_remaining):
		_shout_cooldown_remaining = shout_cooldown
		_play_particle_burst(_shout_sparks)
		# Manual shouts are cosmetic; movement now controls echolocation visibility.
		sonic_shouted.emit(global_position, Vector2(facing_direction, 0.0), loudness)


func _emit_big_scream_if_requested() -> void:
	if _big_scream_cooldown_remaining > 0.0:
		return
	var direction := Vector2(facing_direction, 0.0)
	var origin := global_position + direction * 18.0
	if Input.is_action_just_pressed(big_scream_minus_action):
		_big_scream_cooldown_remaining = big_scream_cooldown
		_play_particle_burst(_shout_sparks)
		big_scream_minus_emitted.emit(origin, direction, big_scream_loudness)
	elif Input.is_action_just_pressed(big_scream_plus_action):
		_big_scream_cooldown_remaining = big_scream_cooldown
		_play_particle_burst(_shout_sparks)
		big_scream_plus_emitted.emit(origin, direction, big_scream_loudness)


func _play_particle_burst(particles: CPUParticles2D) -> void:
	particles.restart()
	particles.emitting = true
