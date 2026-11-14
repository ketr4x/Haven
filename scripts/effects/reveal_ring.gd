class_name RevealRing
extends Node2D

@export var duration: float = 0.35
@export var end_scale: float = 3.2
@export var base_radius: float = 32.0
@export_range(24, 128) var segment_count: int = 64
@export var impact_duration: float = 0.55
@export_range(0.0, 0.5) var impact_warp_ratio: float = 0.22

@onready var _glow: Line2D = $Glow
@onready var _wave_front: Line2D = $WaveFront

var _elapsed: float = 0.0
var _impacts: Array[Dictionary] = []

func configure(captured_loudness: float, expansion_multiplier: float = 1.0) -> void:
	var loudness_ratio := clampf(captured_loudness, 0.0, 100.0) / 100.0
	var visual_scale := clampf(expansion_multiplier, 0.1, 1.0)
	duration = lerpf(0.4, 0.8, loudness_ratio) * visual_scale
	end_scale = lerpf(5.0, 16.0, loudness_ratio) * visual_scale
	_update_outline(0.4)


func add_bounce(position: Vector2, _normal: Vector2, _bounce_count: int) -> void:
	_impacts.append({"angle": to_local(position).angle(), "age": 0.0, "strength": 1.0})


func add_absorption(position: Vector2) -> void:
	_impacts.append({"angle": to_local(position).angle(), "age": 0.0, "strength": 1.45})


func _process(delta: float) -> void:
	_elapsed += delta
	_advance_impacts(delta)
	var progress := clampf(_elapsed / duration, 0.0, 1.0)
	_update_outline(lerpf(0.4, end_scale, progress))
	modulate.a = 1.0 - progress
	if progress >= 1.0:
		queue_free()


func _advance_impacts(delta: float) -> void:
	var active_impacts: Array[Dictionary] = []
	for impact in _impacts:
		impact["age"] = float(impact["age"]) + delta
		if float(impact["age"]) < impact_duration:
			active_impacts.append(impact)
	_impacts = active_impacts


func _update_outline(scale_value: float) -> void:
	var radius := base_radius * scale_value
	var points := PackedVector2Array()
	for index in range(segment_count + 1):
		var angle := TAU * float(index) / float(segment_count)
		points.append(Vector2.from_angle(angle) * _warped_radius(angle, radius))
	_glow.points = points
	_wave_front.points = points


func _warped_radius(angle: float, radius: float) -> float:
	var warped_radius := radius
	for impact in _impacts:
		var impact_age := float(impact["age"])
		var angle_delta := absf(wrapf(angle - float(impact["angle"]), -PI, PI))
		var local_weight := exp(-pow(angle_delta / 0.42, 2.0))
		var impact_progress := impact_age / impact_duration
		var impact_strength := float(impact.get("strength", 1.0))
		var dent := -radius * impact_warp_ratio * impact_strength * local_weight * sin(impact_progress * PI)
		var rebound := radius * 0.1 * local_weight * sin(impact_age * 28.0 - angle_delta * 14.0) * exp(-impact_age * 5.0)
		warped_radius += dent + rebound
	return maxf(radius * 0.35, warped_radius)
