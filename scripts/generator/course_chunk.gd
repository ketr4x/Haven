class_name CourseChunk
extends Node2D

@export var chunk_id: StringName
@export_range(1, 3) var difficulty: int = 1
@export var min_width: float = 192.0
@export var max_width: float = 640.0
@export var allows_wall_jump: bool = false
@export var requires_shout: bool = false
@export var has_safe_landing: bool = true

func entry_position() -> Vector2:
	return get_node("EntryMarker").position


func exit_position() -> Vector2:
	return get_node("ExitMarker").position


func player_spawn_position() -> Vector2:
	var spawn_marker := get_node_or_null("PlayerSpawn") as Marker2D
	return spawn_marker.position if spawn_marker else entry_position()


func path_width() -> float:
	return exit_position().x - entry_position().x
