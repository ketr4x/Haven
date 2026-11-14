class_name PlayerWorld
extends Node2D

signal player_finished(player_number: int)

@export var player_number: int = 1
@export var left_action: StringName = &"p1_left"
@export var right_action: StringName = &"p1_right"
@export var jump_action: StringName = &"p1_jump"
@export var shout_action: StringName = &"p1_shout"
@export var player_color: Color = Color(1, 0.32, 0.62, 1)
@export var sound_wave_scene: PackedScene
@export var reveal_ring_scene: PackedScene
@export_range(0.1, 1.0) var footstep_loudness_multiplier: float = 0.35
@export_range(0.1, 1.0) var footstep_ring_scale: float = 0.45

@onready var _generator: CourseGenerator = $CourseGenerator
@onready var _player: RezonansPlayer = $Player
@onready var _finish_area: FinishArea = $FinishArea
@onready var _waves: Node2D = $Waves
@onready var _echo_overlay: EchoOverlay = $EchoCanvas/EchoOverlay

var _next_pulse_id: int = 0
var _activated_pulses: Dictionary = {}

func _ready() -> void:
	_player.left_action = left_action
	_player.right_action = right_action
	_player.jump_action = jump_action
	_player.shout_action = shout_action
	_player.modulate = player_color
	var camera := _player.get_node("Camera2D") as Camera2D
	camera.enabled = true
	camera.make_current()

	_generator.course_generated.connect(_on_course_generated)
	_finish_area.player_finished.connect(_on_finish_area_player_finished)
	_player.sonic_shouted.connect(_on_player_pulsed.bind(16, 1.0))
	_player.footstep_emitted.connect(_on_footstep_emitted)


func generate_course(seed: int) -> void:
	_generator.generate_course(seed)


func _on_footstep_emitted(origin: Vector2, direction: Vector2, loudness: float) -> void:
	_on_player_pulsed(origin, direction, loudness * footstep_loudness_multiplier, 8, footstep_ring_scale)


func _on_player_pulsed(origin: Vector2, _direction: Vector2, loudness: float, ray_count: int, ring_scale: float = 1.0) -> void:
	_next_pulse_id += 1
	var pulse := reveal_ring_scene.instantiate() as RevealRing
	_waves.add_child(pulse)
	pulse.global_position = origin
	pulse.configure(loudness, ring_scale)

	for index in ray_count:
		var direction := Vector2.from_angle(TAU * float(index) / float(ray_count))
		var wave := sound_wave_scene.instantiate() as SoundWave
		_waves.add_child(wave)
		wave.setup(_player, origin + direction * 24.0, direction, loudness, _next_pulse_id)
		wave.bounced.connect(pulse.add_bounce)
		wave.returned_to_owner.connect(_on_wave_returned)


func _on_wave_returned(_owner: RezonansPlayer, loudness: float, pulse_id: int) -> void:
	if _activated_pulses.has(pulse_id):
		return
	_activated_pulses[pulse_id] = true
	_player.apply_rebound_boost()
	_echo_overlay.trigger(loudness)


func _on_course_generated(_seed: int, _signature: String) -> void:
	var generator_origin := _generator.global_position
	_player.global_position = generator_origin + _generator.player_spawn
	_player.velocity = Vector2.ZERO
	_finish_area.global_position = generator_origin + _generator.finish_position
	_finish_area.monitoring = true
	_activated_pulses.clear()
	_clear_waves()


func _clear_waves() -> void:
	for wave in _waves.get_children():
		_waves.remove_child(wave)
		wave.queue_free()


func _on_finish_area_player_finished(_finisher: RezonansPlayer) -> void:
	_finish_area.set_deferred("monitoring", false)
	player_finished.emit(player_number)
