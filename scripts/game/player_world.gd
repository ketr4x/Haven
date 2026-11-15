class_name PlayerWorld
extends Node2D

signal player_finished(player_number: int)
signal player_died(player_number: int)

const VIGNETTE_SHADER := preload("res://assets/shaders/player_vignette.gdshader")

@export var player_number: int = 1
@export var left_action: StringName = &"p1_left"
@export var right_action: StringName = &"p1_right"
@export var jump_action: StringName = &"p1_jump"
@export var shout_action: StringName = &"p1_shout"
@export var slide_action: StringName = &"p1_slide"
@export var player_color: Color = Color(1, 0.32, 0.62, 1)
@export var mirror_course_horizontally: bool = false
@export var sound_wave_scene: PackedScene
@export var reveal_ring_scene: PackedScene
@export_range(1.0, 100.0, 1.0) var intro_pulse_loudness: float = 60.0
@export_range(20.0, 200.0, 5.0) var walking_echo_speed_threshold: float = 80.0
@export_range(0.1, 1.0) var footstep_loudness_multiplier: float = 0.35
@export_range(0.1, 1.0) var footstep_ring_scale: float = 0.45
@export_range(0.05, 2.0, 0.05) var respawn_delay: float = 0.35

@export_category("Sonar Overhaul")
@export var scream_ray_count: int = 90
@export var scream_range_multiplier: float = 1.5
@export var scream_extra_bounces: int = 1
@export var jump_land_ray_count: int = 120
@export var jump_land_range_multiplier: float = 0.68
@export var footstep_ray_count: int = 40
@export var footstep_range_multiplier: float = 0.22
@export_range(1.0, 20.0, 0.5) var max_footstep_loudness: float = 8.0
@export_range(0.05, 0.5, 0.05) var unlit_obstacle_light_threshold: float = 0.2

@export_category("Darkness Vignette")
@export_range(0.05, 0.6, 0.005) var base_vignette_inner_radius: float = 0.165
@export_range(0.15, 1.0, 0.005) var base_vignette_outer_radius: float = 0.465
@export_range(0.2, 1.0, 0.01) var base_vignette_darkness: float = 0.68
@export_range(0.15, 0.9, 0.01) var scream_vignette_inner_radius: float = 0.44
@export_range(0.3, 1.4, 0.01) var scream_vignette_outer_radius: float = 0.98
@export_range(0.15, 1.0, 0.01) var scream_vignette_darkness: float = 0.42
@export var scream_vignette_hold_duration: float = 4.0

@onready var _generator: CourseGenerator = $CourseGenerator
@onready var _player: RezonansPlayer = $Player
@onready var _finish_area: FinishArea = $FinishArea
@onready var _audio_feedback: AudioFeedback = $AudioFeedback
@onready var _waves: Node2D = $FeedbackCanvas/Waves
@onready var _echo_overlay: EchoOverlay = $EchoCanvas/EchoOverlay

var sonar_grid: SonarGrid
var vignette_rect: ColorRect
var _vignette_material: ShaderMaterial
var _vignette_pulse_strength: float = 0.0
var _silence_dim_amount: float = 0.0
var _shout_glow_amount: float = 0.0
var _next_pulse_id: int = 0
var _activated_pulses: Dictionary = {}
var death_height: float = INF
var _race_active: bool = false
var _respawn_time_remaining: float = 0.0
var _blind_collision_cooldown: float = 0.0
var _pending_events: Array[String] = []


func _ready() -> void:
	_apply_player_configuration()
	_echo_overlay.visible = false

	sonar_grid = SonarGrid.new()
	sonar_grid.name = "SonarGrid"
	var accent := _accent_color_for_player(player_number, player_color)
	sonar_grid.set_player_accent_color(accent)
	add_child(sonar_grid)
	sonar_grid.wave_bounced.connect(_audio_feedback.play_wave_bounce)
	sonar_grid.wall_broken.connect(_on_sonar_wall_broken)

	_setup_vignette_overlay(accent)
	var camera := _player.get_node("Camera2D") as Camera2D
	camera.enabled = true
	camera.make_current()

	_generator.course_generated.connect(_on_course_generated)
	_finish_area.player_finished.connect(_on_finish_area_player_finished)
	_player.sonic_shouted.connect(_on_player_sonic_shouted)
	_player.footstep_emitted.connect(_on_footstep_emitted)
	_player.footstep_emitted.connect(_on_player_footstep_emitted)
	_player.landed.connect(_on_player_landed)
	_player.jumped.connect(_on_player_jumped)
	_player.wall_jumped.connect(_on_player_wall_jumped)
	_player.slide_started.connect(_on_player_slide_started)

	_player.sonic_shouted.connect(func(_o: Vector2, _d: Vector2, _l: float) -> void: _queue_local_event("shout"))
	_player.footstep_emitted.connect(func(_o: Vector2, _d: Vector2, _l: float) -> void: _queue_local_event("footstep"))
	_player.jumped.connect(func(_p: Vector2) -> void: _queue_local_event("jump"))
	_player.landed.connect(func(_p: Vector2) -> void: _queue_local_event("land"))
	_player.wall_jumped.connect(func(_p: Vector2, _n: Vector2) -> void: _queue_local_event("wall_jump"))
	_player.slide_started.connect(func(_p: Vector2, _d: Vector2) -> void: _queue_local_event("slide"))
	_player.impact_stunned.connect(func(_p: Vector2) -> void: _queue_local_event("impact_stun"))
	player_died.connect(func(_p: int) -> void: _queue_local_event("died"))


func _setup_vignette_overlay(_accent: Color) -> void:
	var echo_canvas := get_node_or_null("EchoCanvas") as CanvasLayer
	if echo_canvas == null:
		return
	vignette_rect = ColorRect.new()
	vignette_rect.name = "VignetteOverlay"
	vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_material = ShaderMaterial.new()
	_vignette_material.shader = VIGNETTE_SHADER
	vignette_rect.material = _vignette_material
	echo_canvas.add_child(vignette_rect)
	_update_vignette_uniforms(0.0)


func _process(delta: float) -> void:
	_blind_collision_cooldown = maxf(0.0, _blind_collision_cooldown - delta)
	_update_vignette_overlay(delta)
	var dust := get_node_or_null("DustParticles") as CPUParticles2D
	if dust != null and _player != null:
		dust.global_position = _player.global_position
		dust.modulate.a = lerpf(1.0, 0.58, _silence_dim_amount)

	if _player != null and not _player.is_remote:
		if _respawn_time_remaining > 0.0:
			_respawn_time_remaining = maxf(0.0, _respawn_time_remaining - delta)
			if is_zero_approx(_respawn_time_remaining) and _race_active:
				_respawn_player()
			return

		if _race_active and _player.global_position.y > death_height:
			_handle_player_fall()
			return

		if _race_active and _player.is_physics_processing():
			_check_unlit_airborne_collision()

	if _player != null \
		and _race_active \
		and _player.is_player_on_floor() \
		and not _player.is_sliding() \
		and absf(_player.velocity.x) >= walking_echo_speed_threshold:
		_echo_overlay.walking_preview(_player.loudness)


func _update_vignette_overlay(delta: float) -> void:
	if _vignette_pulse_strength > 0.0:
		var decay := delta / maxf(0.1, scream_vignette_hold_duration)
		_vignette_pulse_strength = maxf(0.0, _vignette_pulse_strength - decay)
	if _shout_glow_amount > 0.0:
		_shout_glow_amount = maxf(0.0, _shout_glow_amount - delta * 2.8)

	var has_active_waves := sonar_grid != null and not sonar_grid.active_rays.is_empty()
	var target_silence := 0.0 if (has_active_waves or _vignette_pulse_strength > 0.10) else (1.0 if _race_active else 0.35)
	var silence_rate := 5.5 if target_silence < _silence_dim_amount else 1.15
	_silence_dim_amount = move_toward(_silence_dim_amount, target_silence, delta * silence_rate)

	if sonar_grid != null:
		sonar_grid.set_silence_dim(_silence_dim_amount)
	if _player != null:
		_player.set_ambient_light_scale(1.0 - 0.32 * _silence_dim_amount)

	_update_vignette_uniforms(_vignette_pulse_strength)


func _update_vignette_uniforms(strength: float) -> void:
	if _vignette_material == null:
		return
	var eased := pow(clampf(strength, 0.0, 1.0), 0.65)
	_vignette_material.set_shader_parameter(
		"inner_radius",
		lerpf(base_vignette_inner_radius, scream_vignette_inner_radius, eased),
	)
	_vignette_material.set_shader_parameter(
		"outer_radius",
		lerpf(base_vignette_outer_radius, scream_vignette_outer_radius, eased),
	)
	_vignette_material.set_shader_parameter(
		"darkness_alpha",
		lerpf(base_vignette_darkness, scream_vignette_darkness, eased),
	)
	_vignette_material.set_shader_parameter("silence_dim", _silence_dim_amount)
	_vignette_material.set_shader_parameter("pulse_glow", _shout_glow_amount)


func configure_for_local_slot(slot: int) -> void:
	player_number = slot
	left_action = &"p1_left" if slot == 1 else &"p2_left"
	right_action = &"p1_right" if slot == 1 else &"p2_right"
	jump_action = &"p1_jump" if slot == 1 else &"p2_jump"
	shout_action = &"p1_shout" if slot == 1 else &"p2_shout"
	slide_action = &"p1_slide" if slot == 1 else &"p2_slide"
	mirror_course_horizontally = false
	player_color = Color(0.74902, 0.411765, 0.47451, 1) if slot == 1 else Color(0.509804, 0.709804, 0.85098, 1)
	_player.is_remote = false
	_apply_player_configuration()


func configure_for_online_slot(slot: int) -> void:
	player_number = slot
	left_action = &"p1_left"
	right_action = &"p1_right"
	jump_action = &"p1_jump"
	shout_action = &"p1_shout"
	slide_action = &"p1_slide"
	mirror_course_horizontally = false
	player_color = Color(0.74902, 0.411765, 0.47451, 1) if slot == 1 else Color(0.509804, 0.709804, 0.85098, 1)
	_player.is_remote = false
	_apply_player_configuration()


func configure_as_remote_opponent(slot: int) -> void:
	player_number = slot
	left_action = &""
	right_action = &""
	jump_action = &""
	shout_action = &""
	slide_action = &""
	mirror_course_horizontally = false
	player_color = Color(0.74902, 0.411765, 0.47451, 1) if slot == 1 else Color(0.509804, 0.709804, 0.85098, 1)
	_player.is_remote = true
	_finish_area.monitoring = false
	_apply_player_configuration()


func course_signature() -> String:
	return _generator.course_signature


func progress_fraction() -> float:
	var spawn := _generator.to_global(_generator.player_spawn)
	var finish := _generator.to_global(_generator.finish_position)
	var course_distance := absf(finish.x - spawn.x)
	if is_zero_approx(course_distance):
		return 0.0
	return clampf(absf(_player.global_position.x - spawn.x) / course_distance, 0.0, 1.0)


func current_loudness() -> float:
	return _player.loudness


func has_rebound_boost() -> bool:
	return _player.is_rebound_boost_active()


func player_global_position() -> Vector2:
	return _player.global_position


func player_velocity() -> Vector2:
	return _player.velocity


func player_facing_direction() -> float:
	return _player.facing_direction


func player_is_on_floor() -> bool:
	return _player.is_player_on_floor()


func _queue_local_event(event_name: String) -> void:
	if _pending_events.size() < 10:
		_pending_events.append(event_name)


func consume_pending_events() -> Array[String]:
	var events := _pending_events.duplicate()
	_pending_events.clear()
	return events


func apply_remote_snapshot(pos: Vector2, vel: Vector2, facing: float, on_floor: bool, loudness: float, boost_active: bool, events: Array) -> void:
	_player.loudness = loudness
	if boost_active and not _player.is_rebound_boost_active():
		_player.apply_rebound_boost()
	elif not boost_active and _player.is_rebound_boost_active():
		_player.cancel_rebound_boost()
	_player.apply_remote_snapshot(pos, vel, facing, on_floor, _player.remote_is_sliding)
	if on_floor and absf(vel.x) >= walking_echo_speed_threshold:
		_echo_overlay.walking_preview(loudness)
	for event in events:
		match str(event):
			"shout":
				_player.trigger_remote_shout(loudness)
			"footstep":
				_player.trigger_remote_footstep(loudness)
			"jump":
				_player.trigger_remote_jump()
			"land":
				_player.trigger_remote_land()
			"wall_jump":
				_player.trigger_remote_wall_jump(Vector2.LEFT if facing > 0.0 else Vector2.RIGHT)
			"slide":
				_player.trigger_remote_slide()
			"impact_stun":
				_player.trigger_remote_impact_stun()
			"died":
				_clear_waves()
				_player.global_position = _generator.to_global(_generator.player_spawn)
				_player.reset_remote_target(_player.global_position)


func _apply_player_configuration() -> void:
	_player.left_action = left_action
	_player.right_action = right_action
	_player.jump_action = jump_action
	_player.shout_action = shout_action
	_player.slide_action = slide_action
	_player.modulate = player_color
	_player.set_visual_slot(player_number)
	_generator.mirror_horizontally = mirror_course_horizontally
	_echo_overlay.set_player_color(player_color)
	if sonar_grid != null:
		var accent := _accent_color_for_player(player_number, player_color)
		sonar_grid.set_player_accent_color(accent)


func generate_course(seed: int) -> void:
	_generator.generate_course(seed)


func set_race_active(is_active: bool) -> void:
	_race_active = is_active
	if not is_active:
		_respawn_time_remaining = 0.0
	_player.set_physics_process(is_active)
	_finish_area.monitoring = is_active and not _player.is_remote


func emit_intro_pulse() -> void:
	if sonar_grid == null:
		return
	_vignette_pulse_strength = maxf(_vignette_pulse_strength, 0.65)
	_update_vignette_uniforms(_vignette_pulse_strength)
	sonar_grid.emit_pulse(
		_player.global_position,
		Vector2(_player.facing_direction, 0.0),
		scream_ray_count,
		1.0,
		0,
		SonarGrid.PulseKind.INTRO,
	)


func _on_player_sonic_shouted(origin: Vector2, direction: Vector2, loudness: float) -> void:
	_audio_feedback.play_shout()
	_audio_feedback.play_echo_return()
	_on_player_pulsed(
		origin,
		direction,
		loudness,
		scream_ray_count,
		scream_range_multiplier,
		scream_extra_bounces,
		SonarGrid.PulseKind.SCREAM,
	)


func _on_sonar_wall_broken(_position: Vector2, _cell: Vector2i) -> void:
	_audio_feedback.play_wall_break()
	_vignette_pulse_strength = maxf(_vignette_pulse_strength, 0.45)
	_shout_glow_amount = maxf(_shout_glow_amount, 0.65)
	if _player != null:
		_player.add_camera_trauma(0.32)
	_update_vignette_uniforms(_vignette_pulse_strength)


func _on_player_footstep_emitted(_origin: Vector2, _direction: Vector2, _loudness: float) -> void:
	_audio_feedback.play_footstep()


func _on_player_slide_started(_position: Vector2, _direction: Vector2) -> void:
	# Slide is fast and stealthy: no sonar wave pulse is emitted.
	pass


func _on_player_landed(position: Vector2) -> void:
	_audio_feedback.play_landing()
	_vignette_pulse_strength = maxf(_vignette_pulse_strength, 0.32)
	_update_vignette_uniforms(_vignette_pulse_strength)
	if sonar_grid != null:
		sonar_grid.emit_pulse(
			position,
			Vector2(_player.facing_direction, 0.0),
			jump_land_ray_count,
			jump_land_range_multiplier,
			0,
			SonarGrid.PulseKind.LAND,
		)


func _on_player_jumped(position: Vector2) -> void:
	_audio_feedback.play_jump()
	_vignette_pulse_strength = maxf(_vignette_pulse_strength, 0.32)
	_update_vignette_uniforms(_vignette_pulse_strength)
	if sonar_grid != null:
		sonar_grid.emit_pulse(
			position,
			Vector2(_player.facing_direction, 0.0),
			jump_land_ray_count,
			jump_land_range_multiplier,
			0,
			SonarGrid.PulseKind.JUMP,
		)


func _on_player_wall_jumped(position: Vector2, normal: Vector2) -> void:
	_audio_feedback.play_wall_jump()
	_vignette_pulse_strength = maxf(_vignette_pulse_strength, 0.4)
	_update_vignette_uniforms(_vignette_pulse_strength)
	if sonar_grid != null:
		sonar_grid.emit_pulse(
			position,
			normal,
			jump_land_ray_count,
			jump_land_range_multiplier,
			0,
			SonarGrid.PulseKind.JUMP,
		)


func _on_footstep_emitted(origin: Vector2, direction: Vector2, loudness: float) -> void:
	# Footsteps emit restrained local waves so running does not replace jumping/shouting for vision.
	_vignette_pulse_strength = maxf(_vignette_pulse_strength, 0.06)
	_update_vignette_uniforms(_vignette_pulse_strength)
	if sonar_grid != null:
		var clamped_step_loudness := clampf(loudness, 1.0, max_footstep_loudness)
		var step_scale := minf(
			footstep_range_multiplier,
			footstep_range_multiplier * (clamped_step_loudness / maxf(1.0, max_footstep_loudness)),
		)
		sonar_grid.emit_pulse(
			origin,
			direction,
			footstep_ray_count,
			step_scale,
			-3,
			SonarGrid.PulseKind.RUN,
		)


func _on_player_pulsed(
	origin: Vector2,
	direction: Vector2,
	loudness: float,
	ray_count: int = 90,
	range_multiplier: float = 1.5,
	extra_bounces: int = 1,
	pulse_kind: int = SonarGrid.PulseKind.SCREAM
) -> void:
	_next_pulse_id += 1
	_echo_overlay.preview(loudness)
	_player.apply_rebound_boost()
	_vignette_pulse_strength = 1.0
	_shout_glow_amount = 1.0
	_silence_dim_amount = 0.0
	_update_vignette_uniforms(_vignette_pulse_strength)
	if sonar_grid != null:
		sonar_grid.emit_pulse(
			origin,
			direction,
			ray_count if ray_count >= 90 else scream_ray_count,
			range_multiplier,
			extra_bounces,
			pulse_kind,
		)


func _check_unlit_airborne_collision() -> void:
	if sonar_grid == null or _blind_collision_cooldown > 0.0:
		return
	var slide_count := _player.get_slide_collision_count()
	for idx in slide_count:
		var collision := _player.get_slide_collision(idx)
		if collision == null:
			continue
		var normal := collision.get_normal()
		# Ignore standing on top of a surface or grazing low ceilings; penalize running horizontally into unlit airborne blocks.
		if absf(normal.y) > 0.65:
			continue
		var probe_pos := collision.get_position() - normal * 12.0
		if sonar_grid.is_unlit_airborne_obstacle_at_world_pos(probe_pos, unlit_obstacle_light_threshold):
			_blind_collision_cooldown = 0.45
			_player.apply_blind_obstacle_slowdown()
			var cell := sonar_grid.world_to_grid(probe_pos)
			sonar_grid.illuminate_cell(cell, 1.0, 0)
			return


func _on_course_generated(_seed: int, _signature: String) -> void:
	_respawn_time_remaining = 0.0
	_vignette_pulse_strength = 0.0
	_silence_dim_amount = 0.0
	_shout_glow_amount = 0.0
	_update_vignette_uniforms(0.0)
	death_height = _generator.to_global(Vector2(0.0, _generator.fall_death_y)).y
	_player.global_position = _generator.to_global(_generator.player_spawn)
	_player.velocity = Vector2.ZERO
	_player.set_facing_direction(-1.0 if mirror_course_horizontally else 1.0)
	if _player.is_remote:
		_player.reset_remote_target(_player.global_position)
	_finish_area.global_position = _generator.to_global(_generator.finish_position)
	_finish_area.monitoring = not _player.is_remote
	_activated_pulses.clear()
	_clear_waves()
	if sonar_grid != null:
		sonar_grid.rebuild_from_generator(_generator)


func _handle_player_fall() -> void:
	_player.set_physics_process(false)
	_player.velocity = Vector2.ZERO
	_clear_waves()
	_respawn_time_remaining = respawn_delay
	player_died.emit(player_number)


func _respawn_player() -> void:
	_player.global_position = _generator.to_global(_generator.player_spawn)
	_player.velocity = Vector2.ZERO
	_player.set_facing_direction(-1.0 if mirror_course_horizontally else 1.0)
	_player.set_physics_process(_race_active)


func _clear_waves() -> void:
	if sonar_grid != null:
		sonar_grid.clear_waves()
	for wave in _waves.get_children():
		_waves.remove_child(wave)
		wave.queue_free()


func _on_finish_area_player_finished(_finisher: RezonansPlayer) -> void:
	_finish_area.set_deferred("monitoring", false)
	_audio_feedback.play_finish()
	player_finished.emit(player_number)


func _accent_color_for_player(number: int, fallback: Color) -> Color:
	if number == 1:
		return Color(0.86, 0.56, 0.62, 1.0)
	if number == 2:
		return Color(0.64, 0.84, 0.95, 1.0)
	return fallback
