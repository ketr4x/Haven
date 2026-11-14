@tool
class_name CourseChunk
extends Node2D

@export var chunk_id: StringName
@export_range(1, 3) var difficulty: int = 1
@export var min_width: float = 384.0
@export var max_width: float = 384.0
@export var allows_wall_jump: bool = false
@export var requires_shout: bool = false
@export var has_safe_landing: bool = true
@export var grid_size: Vector2i = Vector2i(48, 48)
@export var terrain_cells: Array[Vector2i] = []

@onready var _terrain: TileMapLayer = $Terrain

func _ready() -> void:
	_terrain.clear()
	for cell in terrain_cells:
		_terrain.set_cell(cell, 0, Vector2i.ZERO)


func entry_position() -> Vector2:
	return get_node("EntryMarker").position


func exit_position() -> Vector2:
	return get_node("ExitMarker").position


func player_spawn_position() -> Vector2:
	var spawn_marker := get_node_or_null("PlayerSpawn") as Marker2D
	return spawn_marker.position if spawn_marker else entry_position()


func finish_marker_position() -> Vector2:
	var finish_marker := get_node_or_null("FinishMarker") as Marker2D
	return finish_marker.position if finish_marker else exit_position()


func path_width() -> float:
	return exit_position().x - entry_position().x


func has_valid_grid_geometry() -> bool:
	if terrain_cells.is_empty() or grid_size.x <= 0 or grid_size.y <= 0:
		return false
	if not _is_grid_position(entry_position()) or not _is_grid_position(exit_position()):
		return false
	if not _is_grid_position(player_spawn_position()) or not _is_grid_position(finish_marker_position()):
		return false
	var max_cell_x := int(path_width() / grid_size.x) - 1
	for cell in terrain_cells:
		if cell.x < 0 or cell.x > max_cell_x or cell.y > 0:
			return false
	return true


func _is_grid_position(value: Vector2) -> bool:
	return is_equal_approx(value.x, snappedf(value.x, grid_size.x)) \
		and is_equal_approx(value.y, snappedf(value.y, grid_size.y))
