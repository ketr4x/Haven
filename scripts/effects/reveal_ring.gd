class_name RevealRing
extends Node2D

@export var duration: float = 0.35
@export var end_scale: float = 3.2

var _elapsed: float = 0.0

func configure(captured_loudness: float, expansion_multiplier: float = 1.0) -> void:
	var loudness_ratio := clampf(captured_loudness, 0.0, 100.0) / 100.0
	var visual_scale := clampf(expansion_multiplier, 0.1, 1.0)
	duration = lerpf(0.4, 0.8, loudness_ratio) * visual_scale
	end_scale = lerpf(5.0, 16.0, loudness_ratio) * visual_scale


func _process(delta: float) -> void:
	_elapsed += delta
	var progress := clampf(_elapsed / duration, 0.0, 1.0)
	var scale_value := lerpf(0.4, end_scale, progress)
	scale = Vector2.ONE * scale_value
	modulate.a = 1.0 - progress
	if progress >= 1.0:
		queue_free()
