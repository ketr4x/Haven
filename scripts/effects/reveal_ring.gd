class_name RevealRing
extends Node2D

@export var duration: float = 0.35
@export var end_scale: float = 3.2

var _elapsed: float = 0.0

func _process(delta: float) -> void:
	_elapsed += delta
	var progress := clampf(_elapsed / duration, 0.0, 1.0)
	var scale_value := lerpf(0.4, end_scale, progress)
	scale = Vector2.ONE * scale_value
	modulate.a = 1.0 - progress
	if progress >= 1.0:
		queue_free()
