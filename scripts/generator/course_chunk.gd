@tool
class_name CourseChunk
extends Node2D

@export var chunk_id: StringName
@export_range(1, 3) var difficulty: int = 1
@export var min_width: float = 384.0
@export var max_width: float = 384.0
@export var allows_wall_jump: bool = false
@export var requires_shout: bool = false
@export var terrain_features: Array[StringName] = []
@export_range(1, 4) var floor_depth_cells: int = 1
@export_range(0, 4) var dead_end_paths: int = 0
@export var has_safe_landing: bool = true
@export var mirror_horizontally: bool = false
@export var grid_size: Vector2i = Vector2i(48, 48)
@export var terrain_cells: Array[Vector2i] = []
@export_file("*.tmj") var tmj_map_path: String = ""

const ATLAS_MOSS_TOP_LEFT := Vector2i(0, 1)
const ATLAS_MOSS_TOP := Vector2i(1, 1)
const ATLAS_MOSS_TOP_RIGHT := Vector2i(2, 1)
const ATLAS_MOSS_LEFT := Vector2i(0, 2)
const ATLAS_MOSS_CENTER := Vector2i(1, 2)
const ATLAS_MOSS_RIGHT := Vector2i(2, 2)
const ATLAS_MOSS_BOTTOM_LEFT := Vector2i(0, 3)
const ATLAS_MOSS_BOTTOM := Vector2i(1, 3)
const ATLAS_MOSS_BOTTOM_RIGHT := Vector2i(2, 3)

const ATLAS_FRAME_TOP_LEFT := Vector2i(3, 1)
const ATLAS_FRAME_TOP := Vector2i(4, 1)
const ATLAS_FRAME_LEFT := Vector2i(3, 2)
const ATLAS_FRAME_PLATFORM := Vector2i(4, 2)
const ATLAS_FRAME_BOTTOM_LEFT := Vector2i(3, 3)
const ATLAS_FRAME_BOTTOM := Vector2i(4, 3)

const ATLAS_STONE_TOP := Vector2i(1, 4)
const ATLAS_STONE_TOP_RIGHT := Vector2i(2, 4)
const ATLAS_STONE_LEFT := Vector2i(0, 5)
const ATLAS_STONE_RIGHT := Vector2i(2, 5)
const ATLAS_STONE_BOTTOM_RIGHT := Vector2i(2, 6)

const ATLAS_EARTH_TOP_LEFT := Vector2i(3, 4)
const ATLAS_EARTH_TOP := Vector2i(4, 4)
const ATLAS_EARTH_TOP_RIGHT := Vector2i(5, 4)
const ATLAS_EARTH_WALL := Vector2i(3, 5)
const ATLAS_EARTH_CENTER := Vector2i(4, 5)
const ATLAS_EARTH_BOTTOM_LEFT := Vector2i(3, 6)
const ATLAS_EARTH_BOTTOM := Vector2i(4, 6)

const ATLAS_WOOD_PLANK := Vector2i(6, 1)
const ATLAS_WOOD_RIGHT_STRUT := Vector2i(7, 1)
const ATLAS_WOOD_LEFT_STRUT := Vector2i(6, 2)

@onready var _terrain: TileMapLayer = $Terrain

func _ready() -> void:
	if mirror_horizontally:
		_mirror_markers_and_decorations()
	if terrain_cells.is_empty() and not tmj_map_path.is_empty():
		terrain_cells = extract_tmj_cells(tmj_map_path)
	_terrain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_terrain.clear()
	var occupied: Dictionary = {}
	for cell in terrain_cells:
		var target_cell: Vector2i = Vector2i(-cell.x, cell.y) if mirror_horizontally else cell
		occupied[target_cell] = true
	for cell in terrain_cells:
		var target_cell: Vector2i = Vector2i(-cell.x, cell.y) if mirror_horizontally else cell
		var atlas_coords := _select_atlas_coords(target_cell, occupied, target_cell.y)
		_terrain.set_cell(target_cell, 0, atlas_coords)


func apply_world_autotiling(chunk_offset: Vector2i, world_occupied: Dictionary) -> void:
	if _terrain == null:
		return
	_terrain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_terrain.clear()
	for cell in terrain_cells:
		var target_cell: Vector2i = Vector2i(-cell.x, cell.y) if mirror_horizontally else cell
		var world_cell := chunk_offset + target_cell
		var atlas_coords := _select_atlas_coords(world_cell, world_occupied, target_cell.y)
		_terrain.set_cell(target_cell, 0, atlas_coords)


func _select_atlas_coords(cell: Vector2i, occupied: Dictionary, local_y: int = 0) -> Vector2i:
	var has_up := occupied.has(cell + Vector2i.UP)
	var has_down := occupied.has(cell + Vector2i.DOWN)
	var has_left := occupied.has(cell + Vector2i.LEFT)
	var has_right := occupied.has(cell + Vector2i.RIGHT)

	var is_earth_theme := allows_wall_jump \
		or terrain_features.has(&"wall_climb") \
		or chunk_id in [&"dead_end_well", &"dead_end_balcony", &"stacked_switchback", &"stacked_overlook", &"bounce_reward"]
	var is_wood_bridge := chunk_id == &"bridge" \
		or (local_y < 0 and not has_up and not has_down and chunk_id in [&"stacked_ladders", &"bounce_reward"])
	var is_stone_structure := local_y < 0 and chunk_id in [&"double_floor_arcade", &"double_floor_gap", &"stacked_gallery", &"stacked_crossing"]

	# Vertical columns / walls
	if (has_up or has_down) and not has_left and not has_right:
		if not has_up:
			return ATLAS_EARTH_TOP_LEFT if is_earth_theme else ATLAS_FRAME_TOP_LEFT
		if not has_down:
			return ATLAS_EARTH_BOTTOM_LEFT if is_earth_theme else ATLAS_FRAME_BOTTOM_LEFT
		return ATLAS_EARTH_WALL if is_earth_theme else ATLAS_FRAME_LEFT

	# Top surface tiles
	if not has_up:
		if is_wood_bridge:
			if not has_left and has_right:
				return ATLAS_WOOD_LEFT_STRUT
			if has_left and not has_right:
				return ATLAS_WOOD_RIGHT_STRUT
			if has_left and has_right:
				return ATLAS_WOOD_PLANK
			return ATLAS_STONE_TOP

		if is_stone_structure:
			if not has_left and has_right:
				return ATLAS_FRAME_TOP_LEFT
			if has_left and not has_right:
				return ATLAS_STONE_TOP_RIGHT
			if has_left and has_right:
				return ATLAS_STONE_TOP if absi(cell.x + cell.y) % 2 == 0 else ATLAS_FRAME_TOP
			return ATLAS_STONE_TOP

		if is_earth_theme:
			if not has_left and has_right:
				return ATLAS_EARTH_TOP_LEFT
			if has_left and not has_right:
				return ATLAS_EARTH_TOP_RIGHT
			if has_left and has_right:
				return ATLAS_EARTH_TOP
			return ATLAS_STONE_TOP

		if not has_left and has_right:
			return ATLAS_MOSS_TOP_LEFT
		if has_left and not has_right:
			return ATLAS_MOSS_TOP_RIGHT
		if has_left and has_right:
			return ATLAS_MOSS_TOP
		return ATLAS_STONE_TOP

	# Interior tiles (both above and below)
	if has_down:
		if not has_left:
			return ATLAS_EARTH_WALL if is_earth_theme else ATLAS_MOSS_LEFT
		if not has_right:
			return ATLAS_STONE_RIGHT if is_earth_theme else ATLAS_MOSS_RIGHT
		return ATLAS_EARTH_CENTER if is_earth_theme else ATLAS_MOSS_CENTER

	# Bottom / under-surface tiles (has_up and not has_down)
	if is_earth_theme:
		if not has_left and has_right:
			return ATLAS_EARTH_BOTTOM_LEFT
		if has_left and not has_right:
			return ATLAS_STONE_BOTTOM_RIGHT
		return ATLAS_EARTH_BOTTOM

	if not has_left and has_right:
		return ATLAS_MOSS_BOTTOM_LEFT
	if has_left and not has_right:
		return ATLAS_MOSS_BOTTOM_RIGHT
	return ATLAS_MOSS_BOTTOM


static func extract_tmj_cells(tmj_path: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not FileAccess.file_exists(tmj_path):
		return result
	var raw_json := FileAccess.get_file_as_string(tmj_path)
	var parsed: Variant = JSON.parse_string(raw_json)
	if not (parsed is Dictionary):
		return result
	var map_dict: Dictionary = parsed
	var layers: Array = map_dict.get("layers", [])
	if layers.is_empty() or not (layers[0] is Dictionary):
		return result
	var layer: Dictionary = layers[0]
	var width := int(layer.get("width", map_dict.get("width", 0)))
	var data: Array = layer.get("data", [])
	if width <= 0 or data.is_empty():
		return result

	var raw_cells: Array[Vector2i] = []
	var min_x := INF
	var min_y := INF
	for index in data.size():
		var gid := int(data[index])
		if gid <= 0:
			continue
		var cx := index % width
		var cy := index / width
		raw_cells.append(Vector2i(cx, cy))
		min_x = minf(min_x, float(cx))
		min_y = minf(min_y, float(cy))

	for raw_cell in raw_cells:
		result.append(Vector2i(raw_cell.x - int(min_x), raw_cell.y - int(min_y)))
	return result


static func map_tmj_gid_to_atlas(gid: int, firstgid: int = 1, columns: int = 8) -> Vector2i:
	if gid < firstgid:
		return Vector2i.ZERO
	var local_id := gid - firstgid
	var safe_cols := maxi(1, columns)
	var col := (local_id % safe_cols) % 8
	var row := (local_id / safe_cols) % 12
	return Vector2i(col, row)



func _mirror_markers_and_decorations() -> void:
	for child in get_children():
		if child is Marker2D:
			child.position.x = -child.position.x
		elif child.has_method("apply_horizontal_mirror"):
			child.call("apply_horizontal_mirror", true)
		elif child is Polygon2D:
			child.position.x = -child.position.x
			child.scale.x = -child.scale.x
		elif child is Label:
			child.position.x = -child.position.x - child.size.x


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
	return absf(exit_position().x - entry_position().x)


func has_valid_grid_geometry() -> bool:
	if terrain_cells.is_empty() or grid_size.x <= 0 or grid_size.y <= 0:
		return false
	if not _is_grid_position(entry_position()) or not _is_grid_position(exit_position()):
		return false
	if not _is_grid_position(player_spawn_position()) or not _is_grid_position(finish_marker_position()):
		return false
	var max_cell_x := int(path_width() / grid_size.x) - 1
	var max_cell_y := floor_depth_cells - 1
	for cell in terrain_cells:
		if cell.x < 0 or cell.x > max_cell_x or cell.y > max_cell_y:
			return false
	return true


func has_traversable_path() -> bool:
	if not has_valid_grid_geometry():
		return false
	var occupied: Dictionary = {}
	var min_y := 0
	var max_y := 0
	for cell in terrain_cells:
		occupied[cell] = true
		min_y = mini(min_y, cell.y)
		max_y = maxi(max_y, cell.y)
	var cols := int(path_width() / grid_size.x)
	var entry_row := roundi(entry_position().y / float(grid_size.y))
	var exit_row := roundi(exit_position().y / float(grid_size.y))
	# Entry column (x = 0) and exit column (x = cols - 1) must have standable floor at marker rows
	if not occupied.has(Vector2i(0, entry_row)) or occupied.has(Vector2i(0, entry_row - 1)):
		return false
	if not occupied.has(Vector2i(cols - 1, exit_row)) or occupied.has(Vector2i(cols - 1, exit_row - 1)):
		return false
	# Double-floor / stacked chunks must keep boundary columns open on upper tiers and avoid 1-tile ceiling pinches
	if terrain_features.has(&"branching_paths") and not terrain_features.has(&"wall_climb"):
		if occupied.has(Vector2i(0, -2)) or occupied.has(Vector2i(1, -2)):
			return false
		if occupied.has(Vector2i(cols - 1, -2)) or occupied.has(Vector2i(cols - 2, -2)):
			return false
		for cx in range(1, cols - 1):
			if not occupied.has(Vector2i(cx, -2)) and occupied.has(Vector2i(cx - 1, -2)) and occupied.has(Vector2i(cx + 1, -2)):
				return false
	# Verify 4-connected air reachability from entry air cell to exit air cell within chunk bounds
	var top_air_y := min_y - 3
	var start_air := Vector2i(0, entry_row - 1)
	var goal_air := Vector2i(cols - 1, exit_row - 1)
	var visited: Dictionary = {start_air: true}
	var queue: Array[Vector2i] = [start_air]
	var dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == goal_air:
			return true
		for d in dirs:
			var nxt := cur + d
			if nxt.x < 0 or nxt.x >= cols or nxt.y < top_air_y or nxt.y > max_y:
				continue
			if occupied.has(nxt) or visited.has(nxt):
				continue
			visited[nxt] = true
			queue.append(nxt)
	return false


func _is_grid_position(value: Vector2) -> bool:
	return is_equal_approx(value.x, snappedf(value.x, grid_size.x)) \
		and is_equal_approx(value.y, snappedf(value.y, grid_size.y))

