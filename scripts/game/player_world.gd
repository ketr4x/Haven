class_name PlayerWorld
extends Node2D

signal player_finished(player_number: int)
signal player_died(player_number: int)

@export var player_number: int = 1
@export var left_action: StringName = &"p1_left"
@export var right_action: StringName = &"p1_right"
@export var jump_action: StringName = &"p1_jump"
@export var shout_action: StringName = &"p1_shout"
@export var player_color: Color = Color(1, 0.32, 0.62, 1)
@export var mirror_course_horizontally: bool = false
@export var sound_wave_scene: PackedScene
@export var reveal_ring_scene: PackedScene
@export_range(1.0, 100.0, 1.0) var intro_pulse_loudness: float = 60.0
@export_range(20.0, 200.0, 5.0) var walking_echo_speed_threshold: float = 80.0
@export_range(0.1, 1.0) var footstep_loudness_multiplier: float = 0.35
@export_range(0.1, 1.0) var footstep_ring_scale: float = 0.45
@export_range(0.05, 2.0, 0.05) var respawn_delay: float = 0.35

@onready var _generator: CourseGenerator = $CourseGenerator
@onready var _player: RezonansPlayer = $Player
@onready var _finish_area: FinishArea = $FinishArea
@onready var _audio_feedback: AudioFeedback = $AudioFeedback
@onready var _waves: Node2D = $FeedbackCanvas/Waves
@onready var _echo_overlay: EchoOverlay = $EchoCanvas/EchoOverlay

var _next_pulse_id: int = 0
var _activated_pulses: Dictionary = {}
var death_height: float = INF
var _race_active: bool = false
var _respawn_time_remaining: float = 0.0
var _pending_events: Array[String] = []

func _ready() -> void:
	_apply_player_configuration()
	var camera := _player.get_node("Camera2D") as Camera2D
	camera.enabled = true
	camera.make_current()

	_generator.course_generated.connect(_on_course_generated)
	_finish_area.player_finished.connect(_on_finish_area_player_finished)
	_player.sonic_shouted.connect(_on_player_pulsed.bind(16, 1.0))
	_player.sonic_shouted.connect(_on_player_sonic_shouted)
	_player.footstep_emitted.connect(_on_footstep_emitted)
	_player.footstep_emitted.connect(_on_player_footstep_emitted)
	_player.landed.connect(_on_player_landed)
	_player.jumped.connect(_on_player_jumped)
	_player.wall_jumped.connect(_on_player_wall_jumped)

	_player.sonic_shouted.connect(func(_o: Vector2, _d: Vector2, _l: float) -> void: _queue_local_event("shout"))
	_player.footstep_emitted.connect(func(_o: Vector2, _d: Vector2, _l: float) -> void: _queue_local_event("footstep"))
	_player.jumped.connect(func(_p: Vector2) -> void: _queue_local_event("jump"))
	_player.landed.connect(func(_p: Vector2) -> void: _queue_local_event("land"))
	_player.wall_jumped.connect(func(_p: Vector2, _n: Vector2) -> void: _queue_local_event("wall_jump"))
	player_died.connect(func(_p: int) -> void: _queue_local_event("died"))


func _process(delta: float) -> void:
	if not _player.is_remote:
		if _respawn_time_remaining > 0.0:
			_respawn_time_remaining = maxf(0.0, _respawn_time_remaining - delta)
			if is_zero_approx(_respawn_time_remaining) and _race_active:
				_respawn_player()
			return

		if _race_active and _player.global_position.y > death_height:
			_handle_player_fall()
			return

	if _race_active \
		and _player.is_player_on_floor() \
		and absf(_player.velocity.x) >= walking_echo_speed_threshold:
		_echo_overlay.walking_preview(_player.loudness)


func configure_for_local_slot(slot: int) -> void:
	player_number = slot
	left_action = &"p1_left" if slot == 1 else &"p2_left"
	right_action = &"p1_right" if slot == 1 else &"p2_right"
	jump_action = &"p1_jump" if slot == 1 else &"p2_jump"
	shout_action = &"p1_shout" if slot == 1 else &"p2_shout"
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
	_player.apply_remote_snapshot(pos, vel, facing, on_floor)
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
			"died":
				_clear_waves()
				_player.global_position = _generator.to_global(_generator.player_spawn)
				_player.reset_remote_target(_player.global_position)


func _apply_player_configuration() -> void:
	_player.left_action = left_action
	_player.right_action = right_action
	_player.jump_action = jump_action
	_player.shout_action = shout_action
	_player.modulate = player_color
	_generator.mirror_horizontally = mirror_course_horizontally
	_echo_overlay.set_player_color(player_color)


func generate_course(seed: int) -> void:
	_generator.generate_course(seed)


func set_race_active(is_active: bool) -> void:
	_race_active = is_active
	if not is_active:
		_respawn_time_remaining = 0.0
	_player.set_physics_process(is_active)
	_finish_area.monitoring = is_active and not _player.is_remote


func emit_intro_pulse() -> void:
	_on_player_pulsed(_player.global_position, Vector2(_player.facing_direction, 0.0), intro_pulse_loudness, 16)


func _on_player_sonic_shouted(_origin: Vector2, _direction: Vector2, _loudness: float) -> void:
	_audio_feedback.play_shout()


func _on_player_footstep_emitted(_origin: Vector2, _direction: Vector2, _loudness: float) -> void:
	_audio_feedback.play_footstep()


func _on_player_landed(_position: Vector2) -> void:
	_audio_feedback.play_landing()


func _on_player_jumped(_position: Vector2) -> void:
	_audio_feedback.play_jump()


func _on_player_wall_jumped(_position: Vector2, _normal: Vector2) -> void:
	_audio_feedback.play_wall_jump()


func _on_footstep_emitted(origin: Vector2, _direction: Vector2, loudness: float) -> void:
	# Footsteps show current loudness without granting a free echo return or boost.
	_spawn_reveal_ring(origin, loudness * footstep_loudness_multiplier, footstep_ring_scale)


func _on_player_pulsed(origin: Vector2, _direction: Vector2, loudness: float, ray_count: int, ring_scale: float = 1.0) -> void:
	_next_pulse_id += 1
	_echo_overlay.preview(loudness)
	var pulse := _spawn_reveal_ring(origin, loudness, ring_scale)

	for index in ray_count:
		var direction := Vector2.from_angle(TAU * float(index) / float(ray_count))
		var wave := sound_wave_scene.instantiate() as SoundWave
		_waves.add_child(wave)
		wave.setup(_player, origin + direction * 8.0, direction, loudness, _next_pulse_id)
		wave.bounced.connect(pulse.add_bounce)
		wave.absorbed.connect(pulse.add_absorption)
		wave.bounced.connect(_audio_feedback.play_wave_bounce)
		wave.returned_to_owner.connect(_on_wave_returned)


func _spawn_reveal_ring(origin: Vector2, loudness: float, ring_scale: float) -> RevealRing:
	var pulse := reveal_ring_scene.instantiate() as RevealRing
	_waves.add_child(pulse)
	pulse.global_position = origin
	pulse.configure(loudness, ring_scale)
	return pulse


func _on_wave_returned(_owner: RezonansPlayer, loudness: float, pulse_id: int) -> void:
	if _activated_pulses.has(pulse_id):
		return
	_activated_pulses[pulse_id] = true
	_audio_feedback.play_echo_return()
	_player.apply_rebound_boost()
	_echo_overlay.trigger(loudness)


func _on_course_generated(_seed: int, _signature: String) -> void:
	_respawn_time_remaining = 0.0
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
	for wave in _waves.get_children():
		_waves.remove_child(wave)
		wave.queue_free()


func _on_finish_area_player_finished(_finisher: RezonansPlayer) -> void:
	_finish_area.set_deferred("monitoring", false)
	_audio_feedback.play_finish()
	player_finished.emit(player_number)
