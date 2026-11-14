class_name EchoOverlay
extends ColorRect

@export var reveal_duration: float = 1.5

var _time_remaining: float = 0.0
var _radius: float = 0.0

func trigger(captured_loudness: float) -> void:
	_radius = lerpf(0.14, 0.78, clampf(captured_loudness, 0.0, 100.0) / 100.0)
	_time_remaining = reveal_duration
	_set_reveal(1.0)


func _process(delta: float) -> void:
	if is_zero_approx(_time_remaining):
		return

	_time_remaining = maxf(0.0, _time_remaining - delta)
	_set_reveal(_time_remaining / reveal_duration)


func _set_reveal(strength: float) -> void:
	var shader_material := material as ShaderMaterial
	shader_material.set_shader_parameter("reveal_radius", _radius)
	shader_material.set_shader_parameter("reveal_strength", strength)
