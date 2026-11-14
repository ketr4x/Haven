class_name EchoOverlay
extends ColorRect

const SHADER_ECHO_LIMIT: int = 48

@export_range(8, 48) var maximum_echoes: int = 48
@export_range(0.5, 6.0, 0.05) var afterglow_duration: float = 3.0
@export_range(16.0, 100.0, 1.0) var minimum_echo_radius: float = 42.0
@export_range(32.0, 160.0, 1.0) var maximum_echo_radius: float = 116.0
@export_range(8.0, 32.0, 1.0) var floor_band_offset: float = 18.0
@export_range(2.0, 16.0, 1.0) var floor_band_half_height: float = 7.0
@export_range(0.005, 0.1, 0.001) var edge_threshold: float = 0.02

var _reveal_source: Node2D
var _echoes: Array[Dictionary] = []
var _hit_data: PackedVector4Array = PackedVector4Array()
var _hit_normals: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	# Player worlds instance this overlay twice; uniforms must not cross viewport boundaries.
	material = material.duplicate()
	_hit_data.resize(SHADER_ECHO_LIMIT)
	_hit_normals.resize(SHADER_ECHO_LIMIT)
	_set_empty_echoes()


func set_player_color(color: Color) -> void:
	var shader_material := material as ShaderMaterial
	shader_material.set_shader_parameter("player_color", color)


func set_reveal_source(source: Node2D) -> void:
	_reveal_source = source


func register_hit(
		world_position: Vector2,
		normal: Vector2,
		intensity: float,
		tile_size: float = 0.0,
) -> void:
	var loudness_ratio := clampf(intensity, 0.0, 100.0) / 100.0
	if loudness_ratio < 0.005:
		return

	# Negative radius encodes an exact square tile mask for the shader.
	var reveal_radius := -tile_size if tile_size > 0.0 \
		else lerpf(minimum_echo_radius, maximum_echo_radius, sqrt(loudness_ratio))
	var echo := {
		"position": world_position,
		"normal": normal.normalized(),
		"time": afterglow_duration,
		"duration": afterglow_duration,
		"radius": reveal_radius,
		"strength": 1.0,
	}
	_merge_or_append_echo(echo)
	_upload_shader_state()


func get_active_echo_count() -> int:
	return _echoes.size()


func _merge_or_append_echo(new_echo: Dictionary) -> void:
	for echo in _echoes:
		var same_surface := (echo["normal"] as Vector2).dot(new_echo["normal"] as Vector2) > 0.72
		var same_shape := signf(float(echo["radius"])) == signf(float(new_echo["radius"]))
		var nearby := (echo["position"] as Vector2).distance_to(new_echo["position"] as Vector2) \
			<= minimum_echo_radius * 0.85
		if same_surface and same_shape and nearby:
			echo["position"] = (echo["position"] as Vector2).lerp(new_echo["position"] as Vector2, 0.35)
			echo["time"] = afterglow_duration
			echo["duration"] = afterglow_duration
			echo["radius"] = minf(float(echo["radius"]), float(new_echo["radius"])) \
				if float(new_echo["radius"]) < 0.0 else maxf(float(echo["radius"]), float(new_echo["radius"]))
			echo["strength"] = 1.0
			return

	_echoes.append(new_echo)
	var echo_limit := mini(maximum_echoes, SHADER_ECHO_LIMIT)
	if _echoes.size() > echo_limit:
		_echoes.remove_at(0)


func _process(delta: float) -> void:
	for index in range(_echoes.size() - 1, -1, -1):
		var echo := _echoes[index]
		echo["time"] = float(echo["time"]) - delta
		if float(echo["time"]) <= 0.0:
			_echoes.remove_at(index)
	_upload_shader_state()


func _upload_shader_state() -> void:
	var shader_material := material as ShaderMaterial
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var canvas_transform := get_viewport().get_canvas_transform()
	var echo_index := 0
	for echo in _echoes:
		var screen_position: Vector2 = canvas_transform * (echo["position"] as Vector2)
		var screen_normal := (
			canvas_transform.x * (echo["normal"] as Vector2).x
			+ canvas_transform.y * (echo["normal"] as Vector2).y
		).normalized()
		var fade := clampf(float(echo["time"]) / float(echo["duration"]), 0.0, 1.0)
		_hit_data[echo_index] = Vector4(
			screen_position.x / viewport_size.x,
			screen_position.y / viewport_size.y,
			float(echo["radius"]),
			float(echo["strength"]) * fade,
		)
		_hit_normals[echo_index] = screen_normal
		echo_index += 1

	var source_uv := Vector2(0.5, 0.5)
	if is_instance_valid(_reveal_source):
		var source_screen_position: Vector2 = canvas_transform * _reveal_source.global_position
		source_uv = source_screen_position / viewport_size

	shader_material.set_shader_parameter("viewport_size", viewport_size)
	shader_material.set_shader_parameter("source_uv", source_uv)
	shader_material.set_shader_parameter("floor_band_offset", floor_band_offset)
	shader_material.set_shader_parameter("floor_band_half_height", floor_band_half_height)
	shader_material.set_shader_parameter("edge_threshold", edge_threshold)
	shader_material.set_shader_parameter("echo_hit_count", echo_index)
	shader_material.set_shader_parameter("echo_hits", _hit_data)
	shader_material.set_shader_parameter("echo_normals", _hit_normals)


func _set_empty_echoes() -> void:
	var shader_material := material as ShaderMaterial
	shader_material.set_shader_parameter("echo_hit_count", 0)
	shader_material.set_shader_parameter("echo_hits", _hit_data)
	shader_material.set_shader_parameter("echo_normals", _hit_normals)
