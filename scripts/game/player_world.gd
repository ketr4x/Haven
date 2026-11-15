class_name PlayerWorld
extends Node2D

signal player_finished(player_number: int)
signal player_died(player_number: int)
signal wave_bounced(position: Vector2, normal: Vector2)
signal echo_frozen(position: Vector2)
signal bungee_triggered(position: Vector2)

@export_category("Player")
@export var player_number: int = 1
@export var player_color: Color = Color(0.74902, 0.411765, 0.47451, 1)

@export_category("Echo Hook")
@export var sound_wave_scene: PackedScene
@export var reveal_ring_scene: PackedScene
@export var frozen_echo_scene: PackedScene
@export_range(1, 2, 1) var maximum_frozen_echoes: int = 2
@export_range(800.0, 2_400.0, 50.0) var wave_speed: float = 1_500.0
@export_range(400.0, 2_400.0, 50.0) var wave_range: float = 1_680.0
@export_range(1, 4, 1) var maximum_live_waves: int = 2
@export_range(0.05, 2.0, 0.05) var respawn_delay: float = 0.35
@export_range(0.1, 1.0, 0.05) var bungee_window_duration: float = 0.4
@export_range(1.0, 16.0, 0.5) var bungee_recharge_duration: float = 8.0

@onready var _generator: CourseGenerator = $CourseGenerator
@onready var _player: RezonansPlayer = $Player
@onready var _finish_area: FinishArea = $FinishArea
@onready var _audio_feedback: AudioFeedback = $AudioFeedback
@onready var _waves: Node2D = $FeedbackCanvas/Waves
@onready var _frozen_echoes: Node2D = $FrozenEchoes
@onready var _echo_overlay: EchoOverlay = $EchoCanvas/EchoOverlay
@onready var _bungee_prompt: Label = $BungeeCanvas/BungeePrompt

var death_height: float = INF
var _race_active: bool = false
var _respawn_time_remaining: float = 0.0
var _next_wave_id: int = 0
var _reflected_waves: Array[SoundWave] = []
var _last_checkpoint_position: Vector2 = Vector2.ZERO
var _bungee_available: bool = true
var _bungee_recharge_remaining: float = 0.0
var _bungee_deadline_ms: int = 0
var _bungee_anchor: Vector2 = Vector2.ZERO


func _ready() -> void:
	_player.modulate = player_color
	_echo_overlay.set_player_color(player_color)
	_echo_overlay.set_reveal_source(_player)
	var camera := _player.get_node("Camera2D") as Camera2D
	camera.enabled = true
	camera.make_current()
	_generator.course_generated.connect(_on_course_generated)
	_finish_area.player_finished.connect(_on_finish_area_player_finished)
	_player.wave_fired.connect(_on_wave_fired)
	_player.freeze_requested.connect(_on_freeze_requested)
	_player.obstacle_hit.connect(_on_player_obstacle_hit)


func _process(delta: float) -> void:
	_update_bungee(delta)
	if _bungee_deadline_ms > 0:
		return
	if _respawn_time_remaining > 0.0:
		_respawn_time_remaining = maxf(0.0, _respawn_time_remaining - delta)
		if is_zero_approx(_respawn_time_remaining) and _race_active:
			_respawn_player()
		return
	if _race_active and _player.global_position.y > death_height:
		_handle_player_fall()
	elif _race_active:
		_update_checkpoint()


func generate_course(seed: int) -> void:
	_generator.generate_course(seed)


func set_race_active(is_active: bool) -> void:
	_race_active = is_active
	if not is_active:
		_respawn_time_remaining = 0.0
	_player.set_physics_process(is_active)
	_finish_area.monitoring = is_active


func emit_intro_pulse() -> void:
	pass


func _on_wave_fired(origin: Vector2, direction: Vector2) -> void:
	if sound_wave_scene == null:
		return
	while _waves.get_child_count() >= maximum_live_waves:
		var oldest := _waves.get_child(0)
		_waves.remove_child(oldest)
		oldest.queue_free()
	_next_wave_id += 1
	var wave := sound_wave_scene.instantiate() as SoundWave
	_waves.add_child(wave)
	wave.speed = wave_speed
	wave.max_bounces = 1
	wave.setup(_player, origin, direction, 100.0, _next_wave_id, 1.0, false, wave_range)
	wave.surface_reached.connect(_echo_overlay.register_hit)
	wave.wave_bounced.connect(_on_wave_bounced.bind(wave))
	wave.absorbed.connect(_on_wave_absorbed)


func _on_wave_bounced(position: Vector2, normal: Vector2, bounce_count: int, wave: SoundWave) -> void:
	if bounce_count != 1:
		return
	_reflected_waves.append(wave)
	wave_bounced.emit(position, normal)
	_audio_feedback.play_wave_bounce(position, normal, bounce_count)


func _on_wave_absorbed(_position: Vector2) -> void:
	_audio_feedback.play_shout()


func _on_freeze_requested() -> void:
	for index in range(_reflected_waves.size() - 1, -1, -1):
		var wave := _reflected_waves[index]
		if not is_instance_valid(wave) or not wave.is_reflected:
			_reflected_waves.remove_at(index)
			continue
		if frozen_echo_scene == null:
			return
		while _frozen_echoes.get_child_count() >= maximum_frozen_echoes:
			var oldest_echo := _frozen_echoes.get_child(0)
			_frozen_echoes.remove_child(oldest_echo)
			oldest_echo.queue_free()
		var frozen_echo := frozen_echo_scene.instantiate() as FrozenEcho
		_frozen_echoes.add_child(frozen_echo)
		frozen_echo.global_position = wave.global_position
		frozen_echo.configure(wave.velocity.normalized())
		frozen_echo.expired.connect(_on_frozen_echo_expired)
		if absf(_player.global_position.x - frozen_echo.global_position.x) <= frozen_echo.bridge_length * 0.5 and _player.global_position.y >= frozen_echo.global_position.y - 24.0:
			_player.global_position.y = frozen_echo.global_position.y - frozen_echo.bridge_thickness * 0.5 - 22.0
			_player.velocity.y = minf(_player.velocity.y, 0.0)
		wave.queue_free()
		_reflected_waves.remove_at(index)
		_echo_overlay.register_hit(frozen_echo.global_position, Vector2.UP, 100.0, 48.0)
		echo_frozen.emit(frozen_echo.global_position)
		if not _player.is_on_floor() and Input.is_action_pressed(_player.freeze_and_grapple_action):
			_player.attach_grapple(frozen_echo)
		return


func _on_frozen_echo_expired(position: Vector2) -> void:
	_echo_overlay.register_hit(position, Vector2.UP, 60.0, 48.0)


func _on_player_obstacle_hit(_position: Vector2, _normal: Vector2, _impact_speed: float) -> void:
	_audio_feedback.play_wave_bounce(Vector2.ZERO, Vector2.ZERO, 1)


func _on_course_generated(_seed: int, _signature: String) -> void:
	_respawn_time_remaining = 0.0
	death_height = _generator.to_global(Vector2(0.0, _generator.fall_death_y)).y
	_player.global_position = _generator.to_global(_generator.player_spawn)
	_last_checkpoint_position = _player.global_position
	_bungee_available = true
	_bungee_recharge_remaining = 0.0
	_bungee_deadline_ms = 0
	_bungee_prompt.visible = false
	_player.velocity = Vector2.ZERO
	_player.set_facing_direction(1.0)
	_finish_area.global_position = _generator.to_global(_generator.finish_position)
	_finish_area.monitoring = true
	_reflected_waves.clear()
	_clear_waves()


func _update_checkpoint() -> void:
	for node in _generated_chunks_in_order():
		var chunk := node as CourseChunk
		if chunk != null and _player.global_position.x >= chunk.global_position.x:
			_last_checkpoint_position = chunk.global_position + chunk.entry_position()


func _generated_chunks_in_order() -> Array[Node]:
	return _generator.get_node("GeneratedChunks").get_children()


func _update_bungee(delta: float) -> void:
	if not _bungee_available:
		_bungee_recharge_remaining = maxf(0.0, _bungee_recharge_remaining - delta)
		if is_zero_approx(_bungee_recharge_remaining):
			_bungee_available = true
	if _bungee_deadline_ms <= 0:
		return
	_bungee_prompt.visible = true
	_bungee_prompt.modulate.a = 0.5 + 0.5 * absf(sin(Time.get_ticks_msec() * 0.012))
	if Input.is_action_just_pressed(&"jump") or Input.is_action_just_pressed(&"freeze_and_grapple"):
		_player.global_position = _bungee_anchor
		_player.velocity = Vector2(520.0, -900.0)
		_player.set_physics_process(_race_active)
		_bungee_available = false
		_bungee_recharge_remaining = bungee_recharge_duration
		_bungee_deadline_ms = 0
		_bungee_prompt.visible = false
		Engine.time_scale = 1.0
		bungee_triggered.emit(_bungee_anchor)
		return
	if Time.get_ticks_msec() >= _bungee_deadline_ms:
		_bungee_deadline_ms = 0
		_bungee_prompt.visible = false
		Engine.time_scale = 1.0
		_respawn_time_remaining = respawn_delay


func _handle_player_fall() -> void:
	_player.set_physics_process(false)
	_player.velocity = Vector2.ZERO
	_clear_waves()
	if _bungee_available:
		_bungee_anchor = _last_checkpoint_position
		for echo in _frozen_echoes.get_children():
			var frozen_echo := echo as FrozenEcho
			if frozen_echo != null:
				_bungee_anchor = frozen_echo.global_position
		_bungee_deadline_ms = Time.get_ticks_msec() + roundi(bungee_window_duration * 1_000.0)
		Engine.time_scale = 0.25
		return
	_respawn_time_remaining = respawn_delay
	player_died.emit(player_number)


func _respawn_player() -> void:
	_player.global_position = _last_checkpoint_position
	_player.velocity = Vector2.ZERO
	_player.set_physics_process(_race_active)


func _clear_waves() -> void:
	for wave in _waves.get_children():
		wave.queue_free()


func _on_finish_area_player_finished(_finisher: RezonansPlayer) -> void:
	_finish_area.set_deferred("monitoring", false)
	_audio_feedback.play_finish()
	player_finished.emit(player_number)
