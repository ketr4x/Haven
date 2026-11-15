class_name FinishArea
extends Area2D

signal player_finished(player: RezonansPlayer)

@onready var _finish_light: PointLight2D = get_node_or_null("FinishLight") as PointLight2D
var _pulse_time: float = 0.0


func _ready() -> void:
	if _finish_light == null:
		return
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.98, 0.86, 1.0),
		Color(0.76, 0.95, 0.95, 0.35),
		Color(0.76, 0.95, 0.95, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	_finish_light.texture = tex


func _process(delta: float) -> void:
	if _finish_light == null:
		return
	_pulse_time += delta
	_finish_light.energy = 0.70 + sin(_pulse_time * 2.2) * 0.14


func _on_body_entered(body: Node2D) -> void:
	if body is RezonansPlayer:
		player_finished.emit(body)
