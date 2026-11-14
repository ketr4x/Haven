class_name RezonansPlayer
extends CharacterBody2D

signal landed(position: Vector2)
signal wall_jumped(position: Vector2, normal: Vector2)
signal sonic_shouted(origin: Vector2, direction: Vector2, loudness: float)
signal footstep_emitted(origin: Vector2, direction: Vector2, loudness: float)
signal rebound_boost_started
signal rebound_boost_ended

@export_category("Input")
@export var left_action: StringName = &"p1_left"
@export var right_action: StringName = &"p1_right"
@export var jump_action: StringName = &"p1_jump"
@export var shout_action: StringName = &"p1_shout"

@export_category("Movement")
@export var run_speed: float = 300.0
@export var ground_acceleration: float = 2_400.0
@export var air_acceleration: float = 1_500.0
@export var ground_deceleration: float = 2_800.0
@export var gravity: float = 1_600.0
@export var jump_velocity: float = -560.0
@export var wall_slide_speed: float = 120.0
@export var wall_jump_horizontal_speed: float = 340.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

@export_category("Sonic Shout")
@export var shout_cooldown: float = 0.45

@export_category("Echolocation")
@export_range(1.0, 100.0) var max_loudness: float = 100.0
@export var running_loudness_per_second: float = 24.0
@export var wall_loudness_per_second: float = 36.0
@export var shout_loudness_gain: float = 42.0
@export var footstep_interval: float = 0.3
@export var idle_loudness_decay_per_second: float = 18.0

@export_category("Rebound Boost")
@export var rebound_boost_duration: float = 1.4
@export var rebound_speed_multiplier: float = 1.35
@export var rebound_jump_multiplier: float = 1.18

@export_category("Presentation")
@export var camera_enabled: bool = false

@onready var _camera: Camera2D = $Camera2D
@onready var _boost_aura: Polygon2D = $BoostAura

var facing_direction: float = 1.0
var loudness: float = 0.0
var _coyote_time_remaining: float = 0.0
var _jump_buffer_remaining: float = 0.0
var _shout_cooldown_remaining: float = 0.0
var _boost_time_remaining: float = 0.0
var _footstep_time_remaining: float = 0.0
var _was_on_floor: bool = false

func _ready() -> void:
	_camera.enabled = camera_enabled
	_boost_aura.visible = false


func _physics_process(delta: float) -> void:
	_update_rebound_boost(delta)
	_update_loudness(delta)
	_shout_cooldown_remaining = maxf(0.0, _shout_cooldown_remaining - delta)
	_update_jump_buffer(delta)
	_update_horizontal_velocity(delta)
	_apply_gravity(delta)
	_try_jump()
	_apply_wall_slide()

	move_and_slide()
	_update_ground_state(delta)
	_emit_footstep_if_running(delta)
	_emit_shout_if_requested()


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
	_boost_aura.visible = true
	rebound_boost_started.emit()


func _update_rebound_boost(delta: float) -> void:
	if is_zero_approx(_boost_time_remaining):
		return

	_boost_time_remaining = maxf(0.0, _boost_time_remaining - delta)
	if is_zero_approx(_boost_time_remaining):
		_boost_aura.visible = false
		rebound_boost_ended.emit()


func _speed_multiplier() -> float:
	return rebound_speed_multiplier if _boost_time_remaining > 0.0 else 1.0


func _jump_multiplier() -> float:
	return rebound_jump_multiplier if _boost_time_remaining > 0.0 else 1.0


func _update_jump_buffer(delta: float) -> void:
	if Input.is_action_just_pressed(jump_action):
		_jump_buffer_remaining = jump_buffer_time
	else:
		_jump_buffer_remaining = maxf(0.0, _jump_buffer_remaining - delta)


func _update_horizontal_velocity(delta: float) -> void:
	var input_axis := Input.get_axis(left_action, right_action)
	if not is_zero_approx(input_axis):
		facing_direction = signf(input_axis)
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

	if is_on_floor() or _coyote_time_remaining > 0.0:
		velocity.y = jump_velocity * _jump_multiplier()
		_coyote_time_remaining = 0.0
		_jump_buffer_remaining = 0.0
		return

	if is_on_wall_only():
		var wall_normal := get_wall_normal()
		velocity = Vector2(wall_normal.x * wall_jump_horizontal_speed, jump_velocity * _jump_multiplier())
		facing_direction = signf(wall_normal.x)
		_jump_buffer_remaining = 0.0
		wall_jumped.emit(global_position, wall_normal)


func _apply_wall_slide() -> void:
	if is_on_wall_only() and not is_on_floor() and velocity.y > wall_slide_speed:
		velocity.y = wall_slide_speed


func _update_ground_state(delta: float) -> void:
	if is_on_floor():
		_coyote_time_remaining = coyote_time
		if not _was_on_floor:
			landed.emit(global_position)
	else:
		_coyote_time_remaining = maxf(0.0, _coyote_time_remaining - delta)
	_was_on_floor = is_on_floor()


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
		_add_loudness(shout_loudness_gain)
		sonic_shouted.emit(global_position, Vector2(facing_direction, 0.0), loudness)
