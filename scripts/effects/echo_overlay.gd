class_name EchoOverlay
extends ColorRect

@export_range(0.1, 10.0, 0.1) var reveal_duration: float = 4.0
@export_range(0.1, 2.0, 0.05) var preview_duration: float = 0.55
@export_range(0.0, 1.0, 0.05) var preview_strength: float = 0.45

var _time_remaining: float = 0.0
var _active_duration: float = 0.0
var _peak_strength: float = 0.0
var _radius: float = 0.0

func _ready() -> void:
	# Player worlds instance this overlay twice; uniforms must not cross viewport boundaries.
	material = material.duplicate()


func set_player_color(color: Color) -> void:
	var shader_material := material as ShaderMaterial
	shader_material.set_shader_parameter("player_color", color)


func preview(captured_loudness: float) -> void:
	if _peak_strength > preview_strength and _time_remaining > 0.0:
		return
	_activate(captured_loudness, preview_duration, preview_strength)


func trigger(captured_loudness: float) -> void:
	_activate(captured_loudness, reveal_duration, 1.0)


func _activate(captured_loudness: float, duration: float, strength: float) -> void:
	var reveal_radius := lerpf(0.55, 1.35, clampf(captured_loudness, 0.0, 100.0) / 100.0)
	_radius = maxf(_radius, reveal_radius)
	_active_duration = duration
	_time_remaining = duration
	_peak_strength = strength
	_set_reveal(_peak_strength)


func _process(delta: float) -> void:
	if is_zero_approx(_time_remaining):
		_radius = 0.0
		_peak_strength = 0.0
		_set_reveal(0.0)
		return

	_time_remaining = maxf(0.0, _time_remaining - delta)
	_set_reveal(_peak_strength * _time_remaining / _active_duration)


func _set_reveal(strength: float) -> void:
	var shader_material := material as ShaderMaterial
	shader_material.set_shader_parameter("reveal_radius", _radius)
	shader_material.set_shader_parameter("reveal_strength", strength)
