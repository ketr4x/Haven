class_name AudioFeedback
extends Node

@export_range(0.02, 0.5, 0.01) var wave_bounce_cooldown: float = 0.08

@onready var _footstep: AudioStreamPlayer = $Footstep
@onready var _land: AudioStreamPlayer = $Land
@onready var _jump: AudioStreamPlayer = $Jump
@onready var _wall_jump: AudioStreamPlayer = $WallJump
@onready var _shout: AudioStreamPlayer = $Shout
@onready var _wave_bounce: AudioStreamPlayer = $WaveBounce
@onready var _echo_return: AudioStreamPlayer = $EchoReturn
@onready var _finish: AudioStreamPlayer = $Finish
@onready var _wall_break: AudioStreamPlayer = $WallBreak
@onready var _slide: AudioStreamPlayer = get_node_or_null("Slide") as AudioStreamPlayer
@onready var _boost: AudioStreamPlayer = get_node_or_null("Boost") as AudioStreamPlayer
@onready var _impact_stun: AudioStreamPlayer = get_node_or_null("ImpactStun") as AudioStreamPlayer
@onready var _death: AudioStreamPlayer = get_node_or_null("Death") as AudioStreamPlayer

var _bounce_cooldown_remaining: float = 0.0

func _exit_tree() -> void:
	for player in [_footstep, _land, _jump, _wall_jump, _shout, _wave_bounce, _echo_return, _finish, _wall_break, _slide, _boost, _impact_stun, _death]:
		if player != null:
			player.stop()


func _process(delta: float) -> void:
	_bounce_cooldown_remaining = maxf(0.0, _bounce_cooldown_remaining - delta)


func play_footstep() -> void:
	_footstep.pitch_scale = randf_range(0.92, 1.08)
	_footstep.play()


func play_landing() -> void:
	_land.pitch_scale = randf_range(0.94, 1.06)
	_land.play()


func play_jump() -> void:
	_jump.pitch_scale = randf_range(0.95, 1.06)
	_jump.play()


func play_wall_jump() -> void:
	_wall_jump.pitch_scale = randf_range(0.95, 1.07)
	_wall_jump.play()


func play_shout() -> void:
	_shout.pitch_scale = randf_range(0.97, 1.03)
	_shout.play()


func play_wave_bounce(_position: Vector2, _normal: Vector2, bounce_count: int) -> void:
	if bounce_count > 3 or _bounce_cooldown_remaining > 0.0:
		return
	_bounce_cooldown_remaining = wave_bounce_cooldown
	_wave_bounce.pitch_scale = randf_range(0.92, 1.10)
	_wave_bounce.play()


func play_echo_return() -> void:
	_echo_return.play()


func play_finish() -> void:
	_finish.play()


func play_wall_break() -> void:
	if _wall_break != null:
		_wall_break.pitch_scale = randf_range(0.95, 1.05)
		_wall_break.play()


func play_slide() -> void:
	if _slide != null:
		_slide.pitch_scale = randf_range(0.94, 1.06)
		_slide.play()


func play_boost() -> void:
	if _boost != null:
		_boost.pitch_scale = randf_range(0.96, 1.04)
		_boost.play()


func play_impact() -> void:
	if _impact_stun != null:
		_impact_stun.pitch_scale = randf_range(0.94, 1.06)
		_impact_stun.play()


func play_death() -> void:
	if _death != null:
		_death.play()

