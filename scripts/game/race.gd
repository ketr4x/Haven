extends Control

@export var sound_wave_scene: PackedScene
@export var reveal_ring_scene: PackedScene

@onready var _course_generator: CourseGenerator = $SharedSimulation/CourseGenerator
@onready var _player_one: RezonansPlayer = $SharedSimulation/PlayerOne
@onready var _player_two: RezonansPlayer = $SharedSimulation/PlayerTwo
@onready var _finish_area: FinishArea = $SharedSimulation/FinishArea
@onready var _waves: Node2D = $SharedSimulation/Waves
@onready var _top_viewport: SubViewport = $Presentation/SplitScreen/TopContainer/TopViewport
@onready var _bottom_viewport: SubViewport = $Presentation/SplitScreen/BottomContainer/BottomViewport
@onready var _top_camera: Camera2D = $Presentation/SplitScreen/TopContainer/TopViewport/TopCamera
@onready var _bottom_camera: Camera2D = $Presentation/SplitScreen/BottomContainer/BottomViewport/BottomCamera
@onready var _top_echo_overlay: EchoOverlay = $Presentation/SplitScreen/TopContainer/TopViewport/TopEchoCanvas/EchoOverlay
@onready var _bottom_echo_overlay: EchoOverlay = $Presentation/SplitScreen/BottomContainer/BottomViewport/BottomEchoCanvas/EchoOverlay
@onready var _seed_label: Label = $GlobalUi/Seed
@onready var _winner_label: Label = $GlobalUi/Winner

var _race_finished: bool = false
var _next_pulse_id: int = 0
var _activated_pulses: Dictionary = {}

func _ready() -> void:
	var shared_world := get_viewport().world_2d
	_top_viewport.world_2d = shared_world
	_bottom_viewport.world_2d = shared_world

	_course_generator.course_generated.connect(_on_course_generated)
	_finish_area.player_finished.connect(_on_player_finished)
	_player_one.sonic_shouted.connect(_on_player_shouted.bind(_player_one, 16))
	_player_two.sonic_shouted.connect(_on_player_shouted.bind(_player_two, 16))
	_player_one.footstep_emitted.connect(_on_player_shouted.bind(_player_one, 8))
	_player_two.footstep_emitted.connect(_on_player_shouted.bind(_player_two, 8))
	_course_generator.generate_course()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		_course_generator.generate_course()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"new_seed"):
		_course_generator.generate_course(_course_generator.seed_value + 1)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_top_camera.position = _player_one.global_position
	_bottom_camera.position = _player_two.global_position


func _on_player_shouted(origin: Vector2, _direction: Vector2, loudness: float, player: RezonansPlayer, ray_count: int) -> void:
	_next_pulse_id += 1
	var pulse := reveal_ring_scene.instantiate() as RevealRing
	_waves.add_child(pulse)
	pulse.global_position = origin
	pulse.configure(loudness)

	for index in ray_count:
		var direction := Vector2.from_angle(TAU * float(index) / float(ray_count))
		var wave := sound_wave_scene.instantiate() as SoundWave
		_waves.add_child(wave)
		wave.setup(player, origin + direction * 24.0, direction, loudness, _next_pulse_id)
		wave.returned_to_owner.connect(_on_wave_returned)


func _on_wave_bounced(_position: Vector2, _normal: Vector2, _bounce_count: int) -> void:
	pass


func _on_wave_returned(player: RezonansPlayer, captured_loudness: float, pulse_id: int) -> void:
	if _activated_pulses.has(pulse_id):
		return

	_activated_pulses[pulse_id] = true
	player.apply_rebound_boost()
	if player == _player_one:
		_top_echo_overlay.trigger(captured_loudness)
	else:
		_bottom_echo_overlay.trigger(captured_loudness)


func _on_course_generated(seed: int, _signature: String) -> void:
	var spawn_position := _course_generator.global_position + _course_generator.player_spawn
	_player_one.global_position = spawn_position + Vector2(-18, 0)
	_player_two.global_position = spawn_position + Vector2(18, 0)
	_player_one.velocity = Vector2.ZERO
	_player_two.velocity = Vector2.ZERO
	_finish_area.global_position = _course_generator.global_position + _course_generator.finish_position
	_finish_area.monitoring = true
	_race_finished = false
	_seed_label.text = "Course %d   R: rematch   N: new course" % seed
	_winner_label.text = ""


func _on_player_finished(player: RezonansPlayer) -> void:
	if _race_finished:
		return

	_race_finished = true
	_finish_area.set_deferred("monitoring", false)
	var winner_name := "PLAYER 1" if player == _player_one else "PLAYER 2"
	_winner_label.text = "%s WINS!  R: REMATCH  ·  N: NEW COURSE" % winner_name
