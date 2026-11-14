class_name EchoOverlay
extends ColorRect

@export var reveal_duration: float = 4.0

var _time_remaining: float = 0.0
var _radius: float = 0.0

func _ready() -> void:
	# Player worlds instance this overlay twice; uniforms must not cross viewport boundaries.
	material = material.duplicate()


func trigger(captured_loudness: float) -> void:
	var reveal_radius := lerpf(0.55, 1.35, clampf(captured_loudness, 0.0, 100.0) / 100.0)
	_radius = maxf(_radius, reveal_radius)
	_time_remaining = maxf(_time_remaining, reveal_duration)
	_set_reveal(1.0)


func _process(delta: float) -> void:
	if is_zero_approx(_time_remaining):
		_radius = 0.0
		_set_reveal(0.0)
		return

	_time_remaining = maxf(0.0, _time_remaining - delta)
	_set_reveal(_time_remaining / reveal_duration)


func _set_reveal(strength: float) -> void:
	var shader_material := material as ShaderMaterial
	shader_material.set_shader_parameter("reveal_radius", _radius)
	shader_material.set_shader_parameter("reveal_strength", strength)
