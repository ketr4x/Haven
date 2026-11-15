class_name CourseGenerator
extends Node2D

const TERRAIN_GRID_SIZE: float = 48.0

signal course_generated(seed: int, signature: String)

@export var start_chunk: PackedScene
@export var traversal_chunks: Array[PackedScene]
@export var safe_fallback_chunk: PackedScene
@export var finish_chunk: PackedScene
@export var mirror_horizontally: bool = false
@export_range(1, 24) var traversal_count: int = 5
@export_range(0, 3) var max_noise_foam_chunks: int = 1
@export_range(0, 4) var max_breakable_wall_chunks: int = 2
@export_range(0, 6) var max_branching_path_chunks: int = 4
@export_range(0, 3) var min_wall_climb_chunks: int = 1
@export_range(0, 6) var max_dead_end_paths: int = 3
@export_range(2, 8) var roof_clearance_rows: int = 3
@export_range(48.0, 480.0, 24.0) var fall_death_margin: float = 144.0
@export var seed_value: int = 12_345

@onready var _generated_chunks: Node2D = $GeneratedChunks
@onready var _roof: TileMapLayer = $Roof

var course_signature: String = ""
var player_spawn: Vector2 = Vector2.ZERO
var finish_position: Vector2 = Vector2.ZERO
var fall_death_y: float = 0.0

func generate_course(seed: int = seed_value) -> void:
	seed_value = seed
	_clear_generated_chunks()

	var random := RandomNumberGenerator.new()
	random.seed = seed_value

	var next_entry := Vector2.ZERO
	var sequence: Array[String] = []
	var start := _place_chunk(start_chunk, next_entry)
	player_spawn = start.position + start.player_spawn_position()
	next_entry = start.position + start.exit_position()
	sequence.append(String(start.chunk_id))
	var previous_difficulty := start.difficulty
	var feature_counts: Dictionary = {}

	for index in traversal_count:
		var remaining_slots := traversal_count - index
		var required_feature := _required_feature(feature_counts, remaining_slots)
		var chunk_scene := _choose_compatible_chunk(random, previous_difficulty, feature_counts, required_feature)
		var chunk := _place_chunk(chunk_scene, next_entry)
		next_entry = chunk.position + chunk.exit_position()
		previous_difficulty = chunk.difficulty
		_record_terrain_features(chunk, feature_counts)
		sequence.append(String(chunk.chunk_id))

	var finish := _place_chunk(finish_chunk, next_entry)
	finish_position = finish.position + finish.finish_marker_position()
	sequence.append(String(finish.chunk_id))
	_rebuild_roof_and_fall_boundary()
	course_signature = " > ".join(sequence)
	course_generated.emit(seed_value, course_signature)


func _required_feature(feature_counts: Dictionary, remaining_slots: int) -> StringName:
	var wall_climbs_remaining := min_wall_climb_chunks - int(feature_counts.get(&"wall_climb", 0))
	var force_window := maxi(wall_climbs_remaining, traversal_count / 2)
	if wall_climbs_remaining > 0 and remaining_slots <= force_window:
		return &"wall_climb"
	return &""


func _choose_compatible_chunk(random: RandomNumberGenerator, previous_difficulty: int, feature_counts: Dictionary, required_feature: StringName = &"") -> PackedScene:
	var compatible_chunks: Array[PackedScene] = []
	for chunk_scene in traversal_chunks:
		if _scene_is_compatible(chunk_scene, previous_difficulty, feature_counts, required_feature):
			compatible_chunks.append(chunk_scene)

	if compatible_chunks.is_empty():
		return safe_fallback_chunk
	return compatible_chunks[random.randi_range(0, compatible_chunks.size() - 1)]


func _scene_is_compatible(chunk_scene: PackedScene, previous_difficulty: int, feature_counts: Dictionary, required_feature: StringName) -> bool:
	var candidate := chunk_scene.instantiate() as CourseChunk
	var width := candidate.path_width()
	var matches_required_feature := required_feature == &"" or candidate.terrain_features.has(required_feature)
	var is_valid: bool = candidate.has_safe_landing \
		and matches_required_feature \
		and candidate.has_valid_grid_geometry() \
		and width >= candidate.min_width \
		and width <= candidate.max_width \
		and width > 0.0 \
		and abs(candidate.difficulty - previous_difficulty) <= 1 \
		and _fits_feature_budget(candidate, feature_counts)
	candidate.free()
	return is_valid


func _fits_feature_budget(candidate: CourseChunk, feature_counts: Dictionary) -> bool:
	for feature in candidate.terrain_features:
		var count := int(feature_counts.get(feature, 0))
		if feature == &"noise_foam" and count >= max_noise_foam_chunks:
			return false
		if feature == &"breakable_wall" and count >= max_breakable_wall_chunks:
			return false
		if feature == &"branching_paths":
			var pending_wall_climbs := maxi(0, min_wall_climb_chunks - int(feature_counts.get(&"wall_climb", 0)))
			if count >= max_branching_path_chunks:
				return false
			if not candidate.terrain_features.has(&"wall_climb") and count >= max_branching_path_chunks - pending_wall_climbs:
				return false
	if int(feature_counts.get(&"dead_end_paths", 0)) + candidate.dead_end_paths > max_dead_end_paths:
		return false
	return true


func _record_terrain_features(chunk: CourseChunk, feature_counts: Dictionary) -> void:
	for feature in chunk.terrain_features:
		feature_counts[feature] = int(feature_counts.get(feature, 0)) + 1
	feature_counts[&"dead_end_paths"] = int(feature_counts.get(&"dead_end_paths", 0)) + chunk.dead_end_paths


func _place_chunk(chunk_scene: PackedScene, entry_position: Vector2) -> CourseChunk:
	var chunk := chunk_scene.instantiate() as CourseChunk
	chunk.mirror_horizontally = mirror_horizontally
	_generated_chunks.add_child(chunk)
	chunk.position = entry_position - chunk.entry_position()
	return chunk


func _rebuild_roof_and_fall_boundary() -> void:
	_roof.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_roof.clear()
	var min_column := 0
	var max_column := 0
	var highest_row := 0
	var lowest_row := 0
	var has_terrain := false
	var chunk_cells: Dictionary = {}
	var col_top_y: Dictionary = {}
	var col_bottom_y: Dictionary = {}
	var col_floor_y: Dictionary = {}

	for chunk_node in _generated_chunks.get_children():
		var chunk := chunk_node as CourseChunk
		var grid := chunk.grid_size
		var chunk_offset := Vector2i(
			roundi(chunk.position.x / float(grid.x)),
			roundi(chunk.position.y / float(grid.y)),
		)
		var entry_column := roundi((chunk.position.x + chunk.entry_position().x) / float(grid.x))
		var exit_column := roundi((chunk.position.x + chunk.exit_position().x) / float(grid.x))
		var entry_row := roundi((chunk.position.y + chunk.entry_position().y) / float(grid.y))
		min_column = mini(min_column, mini(entry_column, exit_column))
		max_column = maxi(max_column, maxi(entry_column, exit_column))

		var c_min := mini(entry_column, exit_column)
		var c_max := maxi(entry_column, exit_column)
		for col in range(c_min, c_max):
			if not col_floor_y.has(col):
				col_floor_y[col] = entry_row

		for cell in chunk.terrain_cells:
			var mirrored_cell := Vector2i(-cell.x, cell.y) if chunk.mirror_horizontally else cell
			var world_cell := chunk_offset + mirrored_cell
			chunk_cells[world_cell] = true
			if not col_top_y.has(world_cell.x) or world_cell.y < int(col_top_y[world_cell.x]):
				col_top_y[world_cell.x] = world_cell.y
			if not col_bottom_y.has(world_cell.x) or world_cell.y > int(col_bottom_y[world_cell.x]):
				col_bottom_y[world_cell.x] = world_cell.y
			if not has_terrain:
				highest_row = world_cell.y
				lowest_row = world_cell.y
				has_terrain = true
			else:
				highest_row = mini(highest_row, world_cell.y)
				lowest_row = maxi(lowest_row, world_cell.y)

	if not has_terrain:
		return

	var roof_cells: Dictionary = {}
	var local_roof_rows: Dictionary = {}

	# 1. Seal any missing floor columns & vertical floor steps so falling down is impossible.
	var prev_bottom := int(col_bottom_y.get(min_column, 0))
	for column in range(min_column, max_column):
		var bottom_y := int(col_bottom_y.get(column, col_floor_y.get(column, prev_bottom)))
		if not col_bottom_y.has(column):
			roof_cells[Vector2i(column, bottom_y)] = true
			col_bottom_y[column] = bottom_y
			if not col_top_y.has(column):
				col_top_y[column] = bottom_y
		# Connect vertical floor steps between adjacent columns so no seam can be fallen through
		if column > min_column and absi(bottom_y - prev_bottom) > 1:
			var step_from := mini(bottom_y, prev_bottom)
			var step_to := maxi(bottom_y, prev_bottom)
			for sy in range(step_from, step_to + 1):
				var step_cell := Vector2i(column, sy)
				if not chunk_cells.has(step_cell):
					roof_cells[step_cell] = true
		lowest_row = maxi(lowest_row, bottom_y)
		prev_bottom = bottom_y

	# 2. Build a single low, contour-hugging cave ceiling row per column (short floor-to-ceiling distance).
	for column in range(min_column, max_column):
		var local_top := int(col_top_y.get(column, 0))
		for neighbor_col in range(maxi(min_column, column - 1), mini(max_column - 1, column + 1) + 1):
			local_top = mini(local_top, int(col_top_y.get(neighbor_col, local_top)))
		var roof_row := local_top - roof_clearance_rows
		local_roof_rows[column] = roof_row
		roof_cells[Vector2i(column, roof_row)] = true

	# Connect vertical steps in the contour-hugging ceiling so the roof is completely sealed
	for column in range(min_column + 1, max_column):
		var r_prev := int(local_roof_rows[column - 1])
		var r_curr := int(local_roof_rows[column])
		if r_prev != r_curr:
			var r_min := mini(r_prev, r_curr)
			var r_max := maxi(r_prev, r_curr)
			for ry in range(r_min, r_max + 1):
				var step_roof_cell := Vector2i(column if r_curr < r_prev else column - 1, ry)
				if not chunk_cells.has(step_roof_cell):
					roof_cells[step_roof_cell] = true

	# 3. Enclose left start boundary and right finish boundary with solid cave walls.
	var start_top := int(local_roof_rows.get(min_column, highest_row - roof_clearance_rows))
	var start_bottom := int(col_bottom_y.get(min_column, 0))
	for wy in range(start_top, start_bottom + 1):
		roof_cells[Vector2i(min_column - 1, wy)] = true

	var end_col := max_column - 1
	var end_top := int(local_roof_rows.get(end_col, highest_row - roof_clearance_rows))
	var end_bottom := int(col_bottom_y.get(end_col, 0))
	for wy in range(end_top, end_bottom + 1):
		roof_cells[Vector2i(max_column, wy)] = true

	# 4. Combine world occupancy across all chunks + roof and autotile everything seamlessly.
	var world_occupied: Dictionary = chunk_cells.duplicate()
	for r_cell_variant in roof_cells.keys():
		world_occupied[r_cell_variant] = true

	for chunk_node in _generated_chunks.get_children():
		var chunk := chunk_node as CourseChunk
		var grid := chunk.grid_size
		var chunk_offset := Vector2i(
			roundi(chunk.position.x / float(grid.x)),
			roundi(chunk.position.y / float(grid.y)),
		)
		chunk.apply_world_autotiling(chunk_offset, world_occupied)

	for r_cell_variant in roof_cells.keys():
		var r_cell: Vector2i = r_cell_variant
		if chunk_cells.has(r_cell):
			continue
		var atlas := _select_roof_or_bedrock_atlas(r_cell, world_occupied, min_column, max_column)
		_roof.set_cell(r_cell, 0, atlas)

	# Every authored chunk uses the shared 48-pixel terrain grid.
	fall_death_y = float(lowest_row + 1) * TERRAIN_GRID_SIZE + fall_death_margin


func _select_roof_or_bedrock_atlas(cell: Vector2i, occupied: Dictionary, min_column: int, max_column: int) -> Vector2i:
	var has_up := occupied.has(cell + Vector2i.UP)
	var has_down := occupied.has(cell + Vector2i.DOWN)
	var has_left := occupied.has(cell + Vector2i.LEFT)
	var has_right := occupied.has(cell + Vector2i.RIGHT)
	var use_earth := absi(cell.x) % 5 >= 3

	# Left boundary wall: playable area is to the RIGHT, so grass/surface faces RIGHT (ATLAS_MOSS_RIGHT)
	if cell.x < min_column:
		if not has_down:
			return CourseChunk.ATLAS_MOSS_CENTER
		return CourseChunk.ATLAS_MOSS_RIGHT

	# Right boundary wall: playable area is to the LEFT, so grass/surface faces LEFT (ATLAS_MOSS_LEFT)
	if cell.x >= max_column:
		if not has_down:
			return CourseChunk.ATLAS_MOSS_CENTER
		return CourseChunk.ATLAS_MOSS_LEFT

	# Ceiling tiles: playable area is BELOW, so moss/stone faces DOWN and fades into #21263f at the top
	if cell.y < 0 and not has_down:
		if absi(cell.x) % 4 == 0:
			return CourseChunk.ATLAS_STONE_TOP
		return CourseChunk.ATLAS_EARTH_BOTTOM if use_earth else CourseChunk.ATLAS_MOSS_BOTTOM

	# Floor seal tiles: playable area is ABOVE, so grass faces UP and fades into #21263f at the bottom
	if not has_up:
		return CourseChunk.ATLAS_EARTH_TOP if use_earth else CourseChunk.ATLAS_MOSS_TOP

	# Vertical step connectors inside ceiling or floor steps
	if not has_left and has_right:
		return CourseChunk.ATLAS_EARTH_WALL if use_earth else CourseChunk.ATLAS_MOSS_LEFT
	if has_left and not has_right:
		return CourseChunk.ATLAS_STONE_RIGHT if use_earth else CourseChunk.ATLAS_MOSS_RIGHT

	return CourseChunk.ATLAS_EARTH_CENTER if use_earth else CourseChunk.ATLAS_MOSS_CENTER




func _clear_generated_chunks() -> void:
	_roof.clear()
	for chunk in _generated_chunks.get_children():
		_generated_chunks.remove_child(chunk)
		chunk.queue_free()
