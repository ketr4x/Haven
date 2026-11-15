class_name RezonansPlayer
extends CharacterBody2D

signal landed(position: Vector2)
signal jumped(position: Vector2)
signal wall_jumped(position: Vector2, normal: Vector2)
signal slide_started(position: Vector2, direction: Vector2)
signal slide_ended
signal sonic_shouted(origin: Vector2, direction: Vector2, loudness: float)
signal footstep_emitted(origin: Vector2, direction: Vector2, loudness: float)
signal rebound_boost_started
signal rebound_boost_ended
signal blind_impact_slowed(position: Vector2)

@export_category("Input")
@export var left_action: StringName = &"p1_left"
@export var right_action: StringName = &"p1_right"
@export var jump_action: StringName = &"p1_jump"
@export var shout_action: StringName = &"p1_shout"
@export var slide_action: StringName = &"p1_slide"

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

@export_category("Slide")
@export var slide_duration: float = 0.48
@export var slide_cooldown: float = 0.28
@export var slide_speed_multiplier: float = 1.32
@export var slide_deceleration: float = 420.0
@export var standing_hitbox_size: Vector2 = Vector2(36.0, 68.0)
@export var sliding_hitbox_size: Vector2 = Vector2(36.0, 38.0)

@export_category("Scream / Ping")
@export var shout_cooldown: float = 1.2

@export_category("Echolocation")
@export_range(1.0, 100.0) var max_loudness: float = 100.0
@export_range(1.0, 30.0) var step_loudness_cap: float = 8.0
@export var running_loudness_per_second: float = 24.0
@export var wall_loudness_per_second: float = 18.0
@export var shout_loudness_gain: float = 100.0
@export var footstep_interval: float = 0.35
@export var idle_loudness_decay_per_second: float = 18.0

@export_category("Rebound Boost")
@export var rebound_boost_duration: float = 1.8
@export var rebound_speed_multiplier: float = 1.38
@export var rebound_jump_multiplier: float = 1.18

@export_category("Blind Obstacle Penalty")
@export var blind_slow_duration: float = 1.25
@export_range(0.15, 0.85, 0.05) var blind_slow_multiplier: float = 0.42

const PLAYER_ONE_SHEET := preload("res://assets/art/player.png")
const PLAYER_TWO_SHEET := preload("res://assets/art/playe1r.png")
const OUTLINE_SHADER := preload("res://assets/shaders/player_outline.gdshader")
const SPRITE_FRAME_SIZE := Vector2i(16, 16)
const LAND_ANIM_HOLD_TIME := 0.10
const SLIDE_EXIT_ANIM_TIME := 0.12

@export_category("Presentation")
@export var camera_enabled: bool = false
@export var is_remote: bool = false
@export_range(1, 2, 1) var visual_slot: int = 1
@export var camera_zoom: Vector2 = Vector2(1.45, 1.45)
@export var camera_lookahead_x: float = 180.0
@export var camera_vertical_offset: float = -16.0
@export var camera_lookahead_lerp_speed: float = 7.0
@export var outline_color: Color = Color.WHITE

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _camera: Camera2D = $Camera2D
@onready var _player_sprite: AnimatedSprite2D = $PlayerSprite
@onready var _facing_marker: Polygon2D = $FacingMarker
@onready var _landing_dust: CPUParticles2D = $LandingDust
@onready var _wall_dust: CPUParticles2D = $WallDust

var facing_direction: float = 1.0
var loudness: float = 0.0
var _coyote_time_remaining: float = 0.0
var _wall_jump_time_remaining: float = 0.0
var _last_wall_normal: Vector2 = Vector2.ZERO
var _jump_buffer_remaining: float = 0.0
var _shout_cooldown_remaining: float = 0.0
var _boost_time_remaining: float = 0.0
var _blind_slow_time_remaining: float = 0.0
var _footstep_time_remaining: float = 0.0
var _slide_time_remaining: float = 0.0
var _slide_cooldown_remaining: float = 0.0
var _slide_exit_time_remaining: float = 0.0
var _is_sliding: bool = false
var _was_on_floor: bool = false
var _remote_target_position: Vector2 = Vector2.ZERO
var _remote_target_velocity: Vector2 = Vector2.ZERO
var _remote_has_target: bool = false
var remote_on_floor: bool = false
var remote_is_sliding: bool = false
var _is_flipping: bool = false
var _land_anim_time_remaining: float = 0.0


func _ready() -> void:
	if _collision_shape != null and _collision_shape.shape != null:
		_collision_shape.shape = _collision_shape.shape.duplicate()
		_apply_collision_profile(false)
	_camera.enabled = camera_enabled
	_camera.zoom = camera_zoom
	_camera.offset = Vector2(facing_direction * camera_lookahead_x, camera_vertical_offset)
	_setup_player_outline()
	_setup_player_sprite_frames(visual_slot)
	if _player_sprite != null:
		_player_sprite.animation_finished.connect(_on_player_sprite_animation_finished)
	set_facing_direction(facing_direction)
	_landing_dust.emitting = false
	_wall_dust.emitting = false


func _setup_player_outline() -> void:
	if _player_sprite == null:
		return
	var mat := _player_sprite.material as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = OUTLINE_SHADER
	else:
		mat = mat.duplicate() as ShaderMaterial
	mat.set_shader_parameter(&"outline_color", outline_color)
	mat.set_shader_parameter(&"outline_width", 1.0)
	_player_sprite.material = mat


func set_visual_slot(slot: int) -> void:
	visual_slot = clampi(slot, 1, 2)
	if is_inside_tree():
		_setup_player_sprite_frames(visual_slot)


func _setup_player_sprite_frames(slot: int) -> void:
	if _player_sprite == null:
		return
	var sheet: Texture2D = PLAYER_TWO_SHEET if slot == 2 else PLAYER_ONE_SHEET
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")

	# Row 0 (1st row): Idle — 9 frames (0..8), looping
	_add_sheet_animation(frames, &"idle", sheet, 0, [0, 1, 2, 3, 4, 5, 6, 7, 8], 10.0, true)
	# Row 1 (2nd row): Run — 10 frames (0..9), looping
	_add_sheet_animation(frames, &"run", sheet, 1, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], 14.0, true)
	# Row 2 (3rd row): Slide — 8 frames total (0..7):
	# - slide_enter: frames 0, 1 (entry transition)
	# - slide_loop: frames 2, 3, 4, 5 (active low-profile slide loop)
	# - slide_exit: frames 6, 7 (recovery transition back to upright)
	_add_sheet_animation(frames, &"slide_enter", sheet, 2, [0, 1], 18.0, false)
	_add_sheet_animation(frames, &"slide_loop", sheet, 2, [2, 3, 4, 5], 14.0, true)
	_add_sheet_animation(frames, &"slide_exit", sheet, 2, [6, 7], 16.0, false)
	# Row 3 (4th row): Flip — 8 frames total; frame 1 (idx 0) is idle, frame 2 (idx 1) starts flip, and frames 3-8 (idx 2..7) loop
	_add_sheet_animation(frames, &"flip_start", sheet, 3, [0, 1], 16.0, false)
	_add_sheet_animation(frames, &"flip_loop", sheet, 3, [2, 3, 4, 5, 6, 7], 15.0, true)
	# Row 4 (5th row): Fall & Jump (reversed) — 5 frames total (0..4):
	# - Jump uses frames 3, 2, 1, 0 (reversed air frames)
	# - Fall uses frames 0, 1, 2, 3 and holds on the second-to-last frame (idx 3) while in air
	# - Land uses the last frame (idx 4) when touching the ground
	_add_sheet_animation(frames, &"jump", sheet, 4, [3, 2, 1, 0], 14.0, false)
	_add_sheet_animation(frames, &"fall", sheet, 4, [0, 1, 2, 3], 12.0, false)
	_add_sheet_animation(frames, &"land", sheet, 4, [4], 12.0, false)

	_player_sprite.sprite_frames = frames
	_player_sprite.play(&"idle")
	_sync_sprite_modulate_compensation()


func _add_sheet_animation(
	frames: SpriteFrames,
	anim_name: StringName,
	sheet: Texture2D,
	row: int,
	columns: Array[int],
	fps: float,
	loop: bool
) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, loop)
	for col in columns:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(
			float(col * SPRITE_FRAME_SIZE.x),
			float(row * SPRITE_FRAME_SIZE.y),
			float(SPRITE_FRAME_SIZE.x),
			float(SPRITE_FRAME_SIZE.y),
		)
		frames.add_frame(anim_name, atlas)


func _sync_sprite_modulate_compensation() -> void:
	if _player_sprite == null:
		return
	# Compensate for parent Node2D modulate so player.png / playe1r.png render in their true pixel-art palette
	_player_sprite.self_modulate = Color(
		1.0 / maxf(0.05, modulate.r),
		1.0 / maxf(0.05, modulate.g),
		1.0 / maxf(0.05, modulate.b),
		1.0,
	)


func _on_player_sprite_animation_finished() -> void:
	if _player_sprite == null:
		return
	if _player_sprite.animation == &"flip_start" and _is_flipping:
		_player_sprite.play(&"flip_loop")
	elif _player_sprite.animation == &"slide_enter" and is_sliding():
		_player_sprite.play(&"slide_loop")
	elif _player_sprite.animation == &"slide_exit":
		_slide_exit_time_remaining = 0.0


func _update_sprite_animation(delta: float) -> void:
	if _player_sprite == null or _player_sprite.sprite_frames == null:
		return
	_sync_sprite_modulate_compensation()
	_player_sprite.flip_h = facing_direction < 0.0

	if _slide_exit_time_remaining > 0.0:
		_slide_exit_time_remaining = maxf(0.0, _slide_exit_time_remaining - delta)

	if is_sliding():
		_is_flipping = false
		if _player_sprite.animation != &"slide_enter" and _player_sprite.animation != &"slide_loop":
			_player_sprite.play(&"slide_enter")
		return

	var on_ground := is_player_on_floor()
	if on_ground:
		_is_flipping = false
		if _slide_exit_time_remaining > 0.0:
			if _player_sprite.animation != &"slide_exit":
				_player_sprite.play(&"slide_exit")
			return
		if _land_anim_time_remaining > 0.0:
			_land_anim_time_remaining = maxf(0.0, _land_anim_time_remaining - delta)
			if absf(velocity.x) <= 60.0:
				if _player_sprite.animation != &"land":
					_player_sprite.play(&"land")
				return
		if absf(velocity.x) > 20.0:
			if _player_sprite.animation != &"run":
				_player_sprite.play(&"run")
		else:
			if _player_sprite.animation != &"idle":
				_player_sprite.play(&"idle")
		return

	_land_anim_time_remaining = 0.0
	_slide_exit_time_remaining = 0.0
	if _is_flipping:
		if _player_sprite.animation != &"flip_start" and _player_sprite.animation != &"flip_loop":
			_player_sprite.play(&"flip_start")
		return

	if velocity.y < 0.0:
		if _player_sprite.animation != &"jump":
			_player_sprite.play(&"jump")
	else:
		if _player_sprite.animation != &"fall":
			_player_sprite.play(&"fall")


func _update_camera_lookahead(delta: float) -> void:
	if _camera == null:
		return
	_camera.zoom = camera_zoom
	var target_offset := Vector2(facing_direction * camera_lookahead_x, camera_vertical_offset)
	_camera.offset = _camera.offset.lerp(target_offset, clampf(delta * camera_lookahead_lerp_speed, 0.0, 1.0))


func set_facing_direction(direction: float) -> void:
	if is_zero_approx(direction):
		return
	facing_direction = signf(direction)
	_facing_marker.scale.x = facing_direction
	if _player_sprite != null:
		_player_sprite.flip_h = facing_direction < 0.0


func _physics_process(delta: float) -> void:
	if is_remote:
		_process_remote_puppet(delta)
		_update_sprite_animation(delta)
		_update_camera_lookahead(delta)
		return

	_update_rebound_boost(delta)
	_update_blind_slow(delta)
	_update_loudness(delta)
	_shout_cooldown_remaining = maxf(0.0, _shout_cooldown_remaining - delta)
	_slide_cooldown_remaining = maxf(0.0, _slide_cooldown_remaining - delta)
	_update_jump_buffer(delta)
	_update_slide_state(delta)
	_update_horizontal_velocity(delta)
	_apply_gravity(delta)
	_try_jump()
	_apply_wall_slide()

	move_and_slide()
	_update_ground_state(delta)
	_update_wall_jump_state(delta)
	_emit_footstep_if_running(delta)
	_emit_shout_if_requested()
	_update_sprite_animation(delta)
	_update_camera_lookahead(delta)


func _process_remote_puppet(delta: float) -> void:
	_update_rebound_boost(delta)
	if _remote_has_target:
		global_position = global_position.lerp(_remote_target_position, clampf(delta * 20.0, 0.0, 1.0))
		velocity = _remote_target_velocity


func apply_remote_snapshot(pos: Vector2, vel: Vector2, facing: float, on_floor: bool = false, sliding: bool = false) -> void:
	if not _remote_has_target:
		global_position = pos
		_remote_has_target = true
	_remote_target_position = pos
	_remote_target_velocity = vel
	remote_on_floor = on_floor
	if sliding and not remote_is_sliding:
		remote_is_sliding = true
		_apply_collision_profile(true)
		if _player_sprite != null:
			_player_sprite.play(&"slide_enter")
	elif not sliding and remote_is_sliding:
		remote_is_sliding = false
		_apply_collision_profile(false)
		_slide_exit_time_remaining = SLIDE_EXIT_ANIM_TIME
		if _player_sprite != null:
			_player_sprite.play(&"slide_exit")
	set_facing_direction(facing)


func is_player_on_floor() -> bool:
	return remote_on_floor if is_remote else is_on_floor()


func is_sliding() -> bool:
	return remote_is_sliding if is_remote else _is_sliding


func reset_remote_target(pos: Vector2) -> void:
	global_position = pos
	_remote_target_position = pos
	_remote_target_velocity = Vector2.ZERO
	remote_is_sliding = false
	_apply_collision_profile(false)


func cancel_rebound_boost() -> void:
	_boost_time_remaining = 0.0
	rebound_boost_ended.emit()


func trigger_remote_shout(shout_loudness: float) -> void:
	_add_loudness(shout_loudness_gain)
	sonic_shouted.emit(global_position, Vector2(facing_direction, 0.0), shout_loudness)


func trigger_remote_footstep(footstep_loudness: float) -> void:
	footstep_emitted.emit(global_position, Vector2(facing_direction, 0.0), footstep_loudness)


func trigger_remote_slide() -> void:
	remote_is_sliding = true
	_apply_collision_profile(true)
	if _player_sprite != null:
		_player_sprite.play(&"slide_enter")
	_play_particle_burst(_landing_dust)
	slide_started.emit(global_position, Vector2(facing_direction, 0.0))


func trigger_remote_jump() -> void:
	remote_is_sliding = false
	_apply_collision_profile(false)
	_is_flipping = is_rebound_boost_active()
	if _player_sprite != null:
		_player_sprite.play(&"flip_start" if _is_flipping else &"jump")
	jumped.emit(global_position)


func trigger_remote_wall_jump(normal: Vector2) -> void:
	remote_is_sliding = false
	_apply_collision_profile(false)
	_is_flipping = true
	if _player_sprite != null:
		_player_sprite.play(&"flip_start")
	_wall_dust.position = Vector2(-normal.x * 18.0, 10.0)
	_wall_dust.direction = Vector2(normal.x, -0.35).normalized()
	_play_particle_burst(_wall_dust)
	wall_jumped.emit(global_position, normal)


func trigger_remote_land() -> void:
	_is_flipping = false
	_land_anim_time_remaining = LAND_ANIM_HOLD_TIME
	if _player_sprite != null and not remote_is_sliding:
		_player_sprite.play(&"land")
	_play_particle_burst(_landing_dust)
	landed.emit(global_position)


func _update_loudness(delta: float) -> void:
	var gain := 0.0
	if absf(velocity.x) > 30.0:
		gain += running_loudness_per_second * delta
	if is_on_wall_only() and not is_on_floor():
		gain += wall_loudness_per_second * delta
	if is_zero_approx(gain):
		loudness = maxf(0.0, loudness - idle_loudness_decay_per_second * delta)
	elif loudness < step_loudness_cap:
		loudness = minf(step_loudness_cap, loudness + gain)
	else:
		loudness = maxf(step_loudness_cap, loudness - idle_loudness_decay_per_second * delta)


func _add_loudness(amount: float) -> void:
	loudness = clampf(loudness + amount, 0.0, max_loudness)


func apply_rebound_boost() -> void:
	_blind_slow_time_remaining = 0.0
	_boost_time_remaining = rebound_boost_duration
	rebound_boost_started.emit()


func apply_blind_obstacle_slowdown() -> void:
	_boost_time_remaining = 0.0
	_blind_slow_time_remaining = blind_slow_duration
	velocity.x *= blind_slow_multiplier
	blind_impact_slowed.emit(global_position)


func is_blind_slowed() -> bool:
	return _blind_slow_time_remaining > 0.0


func _update_rebound_boost(delta: float) -> void:
	if is_zero_approx(_boost_time_remaining):
		return

	_boost_time_remaining = maxf(0.0, _boost_time_remaining - delta)
	if is_zero_approx(_boost_time_remaining):
		rebound_boost_ended.emit()


func _update_blind_slow(delta: float) -> void:
	if is_zero_approx(_blind_slow_time_remaining):
		return
	_blind_slow_time_remaining = maxf(0.0, _blind_slow_time_remaining - delta)


func is_rebound_boost_active() -> bool:
	return _boost_time_remaining > 0.0


func _speed_multiplier() -> float:
	var multiplier := rebound_speed_multiplier if _boost_time_remaining > 0.0 else 1.0
	if _blind_slow_time_remaining > 0.0:
		multiplier *= blind_slow_multiplier
	return multiplier


func _jump_multiplier() -> float:
	return rebound_jump_multiplier if _boost_time_remaining > 0.0 else 1.0


var _jump_action_was_pressed: bool = false
var _slide_action_was_pressed: bool = false
var _shout_action_was_pressed: bool = false


func _is_action_newly_pressed(action: StringName, was_pressed_flag: bool) -> bool:
	if action.is_empty() or not InputMap.has_action(action):
		return false
	if Input.is_action_just_pressed(action):
		return true
	return Input.is_action_pressed(action) and not was_pressed_flag


func _update_jump_buffer(delta: float) -> void:
	var currently_pressed := not jump_action.is_empty() and InputMap.has_action(jump_action) and Input.is_action_pressed(jump_action)
	if _is_action_newly_pressed(jump_action, _jump_action_was_pressed):
		_jump_buffer_remaining = jump_buffer_time
	else:
		_jump_buffer_remaining = maxf(0.0, _jump_buffer_remaining - delta)
	_jump_action_was_pressed = currently_pressed


func _update_slide_state(delta: float) -> void:
	var currently_pressed := not slide_action.is_empty() and InputMap.has_action(slide_action) and Input.is_action_pressed(slide_action)
	var newly_pressed := _is_action_newly_pressed(slide_action, _slide_action_was_pressed)
	_slide_action_was_pressed = currently_pressed

	if _is_sliding:
		_slide_time_remaining = maxf(0.0, _slide_time_remaining - delta)
		if not is_on_floor():
			_end_slide(false)
			return
		if is_zero_approx(_slide_time_remaining):
			if _can_stand_up():
				_end_slide(true)
			else:
				# Stay in low-profile slide while underneath a low ceiling overhang
				_slide_time_remaining = 0.05
		return

	if newly_pressed and is_on_floor() and is_zero_approx(_slide_cooldown_remaining):
		_start_slide()


func _start_slide() -> void:
	var input_axis := _read_horizontal_axis()
	if not is_zero_approx(input_axis):
		set_facing_direction(input_axis)
	_is_sliding = true
	_slide_time_remaining = slide_duration
	_slide_cooldown_remaining = slide_duration + slide_cooldown
	_slide_exit_time_remaining = 0.0
	_apply_collision_profile(true)
	var min_slide_speed := run_speed * slide_speed_multiplier * _speed_multiplier()
	if absf(velocity.x) < min_slide_speed or signf(velocity.x) != facing_direction:
		velocity.x = facing_direction * min_slide_speed
	if _player_sprite != null:
		_player_sprite.play(&"slide_enter")
	_play_particle_burst(_landing_dust)
	slide_started.emit(global_position, Vector2(facing_direction, 0.0))


func _end_slide(play_exit_anim: bool = true) -> void:
	if not _is_sliding:
		return
	_is_sliding = false
	_slide_time_remaining = 0.0
	_apply_collision_profile(false)
	if play_exit_anim and is_on_floor():
		_slide_exit_time_remaining = SLIDE_EXIT_ANIM_TIME
		if _player_sprite != null:
			_player_sprite.play(&"slide_exit")
	slide_ended.emit()


func _can_stand_up() -> bool:
	var height_diff := standing_hitbox_size.y - sliding_hitbox_size.y
	if height_diff <= 0.0 or not is_inside_tree():
		return true
	return not test_move(global_transform, Vector2(0.0, -height_diff))


func _apply_collision_profile(sliding: bool) -> void:
	if _collision_shape == null:
		return
	var rect := _collision_shape.shape as RectangleShape2D
	if rect == null:
		return
	if sliding:
		rect.size = sliding_hitbox_size
		_collision_shape.position = Vector2(0.0, (standing_hitbox_size.y - sliding_hitbox_size.y) * 0.5)
	else:
		rect.size = standing_hitbox_size
		_collision_shape.position = Vector2.ZERO


func _read_horizontal_axis() -> float:
	if left_action.is_empty() or right_action.is_empty():
		return 0.0
	if not InputMap.has_action(left_action) or not InputMap.has_action(right_action):
		return 0.0
	return Input.get_axis(left_action, right_action)


func _update_horizontal_velocity(delta: float) -> void:
	if _is_sliding:
		var min_keep_speed := run_speed * 0.72 * _speed_multiplier()
		velocity.x = move_toward(velocity.x, facing_direction * min_keep_speed, slide_deceleration * delta)
		return

	var input_axis := _read_horizontal_axis()
	if not is_zero_approx(input_axis):
		set_facing_direction(input_axis)
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
		if _is_sliding:
			_end_slide(false)
		velocity = Vector2(_last_wall_normal.x * wall_jump_horizontal_speed, jump_velocity * _jump_multiplier())
		set_facing_direction(_last_wall_normal.x)
		_jump_buffer_remaining = 0.0
		_wall_jump_time_remaining = 0.0
		_is_flipping = true
		if _player_sprite != null:
			_player_sprite.play(&"flip_start")
		_wall_dust.position = Vector2(-_last_wall_normal.x * 18.0, 10.0)
		_wall_dust.direction = Vector2(_last_wall_normal.x, -0.35).normalized()
		_play_particle_burst(_wall_dust)
		wall_jumped.emit(global_position, _last_wall_normal)
		return

	if is_on_floor() or _coyote_time_remaining > 0.0:
		if _is_sliding:
			if not _can_stand_up():
				return
			_end_slide(false)
		velocity.y = jump_velocity * _jump_multiplier()
		_coyote_time_remaining = 0.0
		_jump_buffer_remaining = 0.0
		_is_flipping = is_rebound_boost_active()
		if _player_sprite != null:
			_player_sprite.play(&"flip_start" if _is_flipping else &"jump")
		jumped.emit(global_position)


func _apply_wall_slide() -> void:
	if is_on_wall_only() and not is_on_floor() and velocity.y > wall_slide_speed:
		velocity.y = wall_slide_speed


func _update_ground_state(delta: float) -> void:
	if is_on_floor():
		_coyote_time_remaining = coyote_time
		if not _was_on_floor:
			_is_flipping = false
			_land_anim_time_remaining = LAND_ANIM_HOLD_TIME
			if _player_sprite != null and absf(velocity.x) <= 60.0 and not _is_sliding:
				_player_sprite.play(&"land")
			_play_particle_burst(_landing_dust)
			landed.emit(global_position)
	else:
		_coyote_time_remaining = maxf(0.0, _coyote_time_remaining - delta)
	_was_on_floor = is_on_floor()


func _update_wall_jump_state(delta: float) -> void:
	if is_on_wall_only():
		_last_wall_normal = get_wall_normal()
		_wall_jump_time_remaining = wall_jump_coyote_time
	else:
		_wall_jump_time_remaining = maxf(0.0, _wall_jump_time_remaining - delta)


func _emit_footstep_if_running(delta: float) -> void:
	if not is_on_floor() or _is_sliding or absf(velocity.x) < 80.0:
		_footstep_time_remaining = 0.0
		return

	_footstep_time_remaining -= delta
	if _footstep_time_remaining <= 0.0:
		_footstep_time_remaining = footstep_interval
		if loudness <= step_loudness_cap:
			loudness = step_loudness_cap
		var capped_step_loudness := clampf(loudness, 1.0, step_loudness_cap)
		footstep_emitted.emit(global_position, Vector2(facing_direction, 0.0), capped_step_loudness)


func _emit_shout_if_requested() -> void:
	var currently_pressed := not shout_action.is_empty() and InputMap.has_action(shout_action) and Input.is_action_pressed(shout_action)
	var newly_pressed := _is_action_newly_pressed(shout_action, _shout_action_was_pressed)
	_shout_action_was_pressed = currently_pressed
	if newly_pressed and is_zero_approx(_shout_cooldown_remaining):
		_shout_cooldown_remaining = shout_cooldown
		loudness = max_loudness
		apply_rebound_boost()
		sonic_shouted.emit(global_position, Vector2(facing_direction, 0.0), loudness)


func _play_particle_burst(particles: CPUParticles2D) -> void:
	if particles == null:
		return
	particles.restart()
	particles.emitting = true
