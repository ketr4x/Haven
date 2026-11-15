extends Node2D

var sonar_grid: SonarGrid
@onready var _terrain: TileMapLayer = $Terrain


func _ready() -> void:
	sonar_grid = SonarGrid.new()
	sonar_grid.name = "SonarGrid"
	add_child(sonar_grid)
	sonar_grid.rebuild_from_static_bodies(self, 640.0)
	_populate_lab_tilemap()

	var player_one := get_node_or_null("PlayerOne") as RezonansPlayer
	if player_one != null:
		player_one.sonic_shouted.connect(_on_player_shouted)
		player_one.jumped.connect(_on_player_jumped.bind(player_one))
		player_one.landed.connect(_on_player_landed.bind(player_one))
		player_one.trampoline_jumped.connect(_on_player_trampoline_jumped)

	var player_two := get_node_or_null("PlayerTwo") as RezonansPlayer
	if player_two != null:
		player_two.sonic_shouted.connect(_on_player_shouted)
		player_two.jumped.connect(_on_player_jumped.bind(player_two))
		player_two.landed.connect(_on_player_landed.bind(player_two))
		player_two.trampoline_jumped.connect(_on_player_trampoline_jumped)


func _populate_lab_tilemap() -> void:
	if _terrain == null or sonar_grid == null:
		return
	_terrain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_terrain.clear()
	for cell_variant in sonar_grid.tiles.keys():
		var cell: Vector2i = cell_variant
		var has_up := sonar_grid.tiles.has(cell + Vector2i.UP)
		var has_down := sonar_grid.tiles.has(cell + Vector2i.DOWN)
		var has_left := sonar_grid.tiles.has(cell + Vector2i.LEFT)
		var has_right := sonar_grid.tiles.has(cell + Vector2i.RIGHT)
		var atlas := CourseChunk.ATLAS_MOSS_TOP
		if (has_up or has_down) and not has_left and not has_right:
			if not has_up:
				atlas = CourseChunk.ATLAS_EARTH_TOP_LEFT
			elif not has_down:
				atlas = CourseChunk.ATLAS_EARTH_BOTTOM_LEFT
			else:
				atlas = CourseChunk.ATLAS_EARTH_WALL
		elif not has_up and not has_down and cell.y < 14:
			if not has_left and has_right:
				atlas = CourseChunk.ATLAS_WOOD_LEFT_STRUT
			elif has_left and not has_right:
				atlas = CourseChunk.ATLAS_WOOD_RIGHT_STRUT
			else:
				atlas = CourseChunk.ATLAS_WOOD_PLANK
		elif not has_up:
			if not has_left and has_right:
				atlas = CourseChunk.ATLAS_MOSS_TOP_LEFT
			elif has_left and not has_right:
				atlas = CourseChunk.ATLAS_MOSS_TOP_RIGHT
			else:
				atlas = CourseChunk.ATLAS_MOSS_TOP
		_terrain.set_cell(cell, 0, atlas)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		get_tree().reload_current_scene()


func _on_player_shouted(origin: Vector2, direction: Vector2, _loudness: float) -> void:
	if sonar_grid != null:
		sonar_grid.emit_pulse(origin, direction, 90, 1.5, 1, SonarGrid.PulseKind.SCREAM)


var _last_jump_time: float = -999.0


func _on_player_jumped(origin: Vector2, player: RezonansPlayer) -> void:
	var now: float = float(Time.get_ticks_msec()) * 0.001
	if now - _last_jump_time < 0.4:
		return
	_last_jump_time = now
	if sonar_grid != null:
		sonar_grid.emit_pulse(origin, Vector2(player.facing_direction, 0.0), 120, 0.68, 0, SonarGrid.PulseKind.JUMP)


func _on_player_landed(origin: Vector2, player: RezonansPlayer) -> void:
	if sonar_grid != null:
		sonar_grid.emit_pulse(origin, Vector2(player.facing_direction, 0.0), 120, 0.68, 0, SonarGrid.PulseKind.LAND)


func _on_player_trampoline_jumped(origin: Vector2) -> void:
	if sonar_grid != null:
		sonar_grid.emit_downward_pulse(origin, 56)
