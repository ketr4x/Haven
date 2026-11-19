class_name CourseGenerator
extends Node2D

const TERRAIN_GRID_SIZE: float = 48.0
const YELLOW_BLOCK_SCENE := preload("res://scenes/terrain/yellow_block.tscn")

signal course_generated(seed: int, signature: String)

@export var start_chunk: PackedScene
@export var traversal_chunks: Array[PackedScene]
@export var safe_fallback_chunk: PackedScene
@export var finish_chunk: PackedScene
@export var mirror_horizontally: bool = false
@export_range(1, 24) var traversal_count: int = 5
@export_range(0, 3) var max_noise_foam_chunks: int = 1
@export_range(0, 3) var min_breakable_wall_chunks: int = 1
@export_range(0, 4) var max_breakable_wall_chunks: int = 2
@export_range(0, 12) var max_branching_path_chunks: int = 4
@export_range(0, 3) var min_wall_climb_chunks: int = 1
@export_range(0, 6) var max_dead_end_paths: int = 3
@export_range(0, 12) var yellow_blocks_per_course: int = 6
@export_range(2, 8) var roof_clearance_rows: int = 3
@export_range(48.0, 480.0, 24.0) var fall_death_margin: float = 144.0
@export var seed_value: int = 12_345

@onready var _generated_chunks: Node2D = $GeneratedChunks
@onready var _roof: TileMapLayer = $Roof

var course_signature: String = ""
var player_spawn: Vector2 = Vector2.ZERO
var finish_position: Vector2 = Vector2.ZERO
var fall_death_y: float = 0.0
var _dynamic_features: Node2D

func generate_course(seed: int = seed_value) -> void:
	seed_value = seed
	_ensure_dynamic_features_node()
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
	var previous_chunk_id := start.chunk_id
	var feature_counts: Dictionary = {}

	for index in traversal_count:
		var remaining_slots := traversal_count - index
		var required_feature := _required_feature(feature_counts, remaining_slots)
		var chunk_scene := _choose_compatible_chunk(random, previous_difficulty, feature_counts, required_feature, previous_chunk_id)
		var chunk := _place_chunk(chunk_scene, next_entry)
		next_entry = chunk.position + chunk.exit_position()
		previous_difficulty = chunk.difficulty
		previous_chunk_id = chunk.chunk_id
		_record_terrain_features(chunk, feature_counts)
		sequence.append(String(chunk.chunk_id))

	var finish := _place_chunk(finish_chunk, next_entry)
	finish_position = finish.position + finish.finish_marker_position()
	sequence.append(String(finish.chunk_id))
	var layout_data := _rebuild_roof_and_fall_boundary()
	_spawn_dynamic_course_features(random, layout_data)
	course_signature = " > ".join(sequence)
	course_generated.emit(seed_value, course_signature)


func _required_feature(feature_counts: Dictionary, remaining_slots: int) -> StringName:
	var wall_climbs_remaining := maxi(0, min_wall_climb_chunks - int(feature_counts.get(&"wall_climb", 0)))
	var breakables_remaining := maxi(0, min_breakable_wall_chunks - int(feature_counts.get(&"breakable_wall", 0)))
	var total_required := wall_climbs_remaining + breakables_remaining
	var force_window := maxi(total_required, (traversal_count + 1) / 2)
	if wall_climbs_remaining > 0 and remaining_slots <= force_window:
		return &"wall_climb"
	if breakables_remaining > 0 and remaining_slots <= force_window:
		return &"breakable_wall"
	return &""


func _choose_compatible_chunk(
	random: RandomNumberGenerator,
	previous_difficulty: int,
	feature_counts: Dictionary,
	required_feature: StringName = &"",
	previous_chunk_id: StringName = &""
) -> PackedScene:
	var compatible_chunks: Array[PackedScene] = []
	for chunk_scene in traversal_chunks:
		if _scene_is_compatible(chunk_scene, previous_difficulty, feature_counts, required_feature, previous_chunk_id):
			compatible_chunks.append(chunk_scene)

	if compatible_chunks.is_empty() and previous_chunk_id != &"":
		for chunk_scene in traversal_chunks:
			if _scene_is_compatible(chunk_scene, previous_difficulty, feature_counts, required_feature, &""):
				compatible_chunks.append(chunk_scene)

	# If a required feature was blocked only by a 2-step difficulty jump (e.g. difficulty 3 -> 1), relax difficulty delta
	if compatible_chunks.is_empty() and required_feature != &"":
		for chunk_scene in traversal_chunks:
			if _scene_is_compatible(chunk_scene, previous_difficulty, feature_counts, required_feature, &"", true):
				compatible_chunks.append(chunk_scene)

	if compatible_chunks.is_empty():
		return safe_fallback_chunk
	return compatible_chunks[random.randi_range(0, compatible_chunks.size() - 1)]


func _scene_is_compatible(
	chunk_scene: PackedScene,
	previous_difficulty: int,
	feature_counts: Dictionary,
	required_feature: StringName,
	previous_chunk_id: StringName = &"",
	relax_difficulty: bool = false
) -> bool:
	var candidate := chunk_scene.instantiate() as CourseChunk
	var width := candidate.path_width()
	var matches_required_feature := required_feature == &"" or candidate.terrain_features.has(required_feature)
	var valid_wall_climb_flag := not candidate.terrain_features.has(&"wall_climb") or candidate.allows_wall_jump
	var valid_breakable_flag := not candidate.terrain_features.has(&"breakable_wall") or candidate.requires_shout
	var not_repeated_vertical_climb := not (candidate.chunk_id == &"wall_jump" and previous_chunk_id == &"wall_jump")
	var difficulty_ok: bool = relax_difficulty or absi(candidate.difficulty - previous_difficulty) <= 1
	var is_valid: bool = candidate.has_safe_landing \
		and matches_required_feature \
		and valid_wall_climb_flag \
		and valid_breakable_flag \
		and not_repeated_vertical_climb \
		and candidate.has_valid_grid_geometry() \
		and candidate.has_traversable_path() \
		and width >= candidate.min_width \
		and width <= candidate.max_width \
		and width > 0.0 \
		and difficulty_ok \
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
	if chunk.allows_wall_jump:
		feature_counts[&"allows_wall_jump"] = int(feature_counts.get(&"allows_wall_jump", 0)) + 1
	if chunk.requires_shout:
		feature_counts[&"requires_shout"] = int(feature_counts.get(&"requires_shout", 0)) + 1


func _place_chunk(chunk_scene: PackedScene, entry_position: Vector2) -> CourseChunk:
	var chunk := chunk_scene.instantiate() as CourseChunk
	chunk.mirror_horizontally = mirror_horizontally
	_generated_chunks.add_child(chunk)
	chunk.position = entry_position - chunk.entry_position()
	return chunk


func _rebuild_roof_and_fall_boundary() -> Dictionary:
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
	var traversal_min_col := 0
	var traversal_max_col := 0

	var all_chunks := _generated_chunks.get_children()
	for chunk_idx in all_chunks.size():
		var chunk := all_chunks[chunk_idx] as CourseChunk
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
		if chunk_idx == 0:
			traversal_min_col = maxi(entry_column, exit_column)
		if chunk_idx == all_chunks.size() - 1:
			traversal_max_col = mini(entry_column, exit_column)

		var c_min := mini(entry_column, exit_column)
		var c_max := maxi(entry_column, exit_column)
		for col in range(c_min, c_max):
			if not col_floor_y.has(col):
				col_floor_y[col] = entry_row

		var chunk_highest_y := entry_row
		for cell in chunk.terrain_cells:
			var mirrored_cell := Vector2i(-cell.x, cell.y) if chunk.mirror_horizontally else cell
			var world_cell := chunk_offset + mirrored_cell
			chunk_cells[world_cell] = true
			chunk_highest_y = mini(chunk_highest_y, world_cell.y)
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

		# Wall-climb chunks need uniform overhead clearance across the entire chunk so ceiling steps never cap the climb
		if chunk.allows_wall_jump or chunk.terrain_features.has(&"wall_climb"):
			for col in range(c_min, c_max):
				col_top_y[col] = mini(int(col_top_y.get(col, chunk_highest_y)), chunk_highest_y)

	if not has_terrain:
		return {}

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
		# Connect vertical floor steps under the higher floor column so playable air above the lower floor stays open
		if column > min_column and absi(bottom_y - prev_bottom) > 1:
			var step_from := mini(bottom_y, prev_bottom)
			var step_to := maxi(bottom_y, prev_bottom)
			var step_col := column if bottom_y < prev_bottom else column - 1
			for sy in range(step_from, step_to + 1):
				var step_cell := Vector2i(step_col, sy)
				if not chunk_cells.has(step_cell):
					roof_cells[step_cell] = true
		lowest_row = maxi(lowest_row, bottom_y)
		prev_bottom = bottom_y

	# 2. Build a single low, contour-hugging cave ceiling row per column with horizontal jump clearance around upper ledges.
	for column in range(min_column, max_column):
		var local_top := int(col_top_y.get(column, col_floor_y.get(column, 0)))
		for neighbor_col in range(maxi(min_column, column - 3), mini(max_column - 1, column + 3) + 1):
			local_top = mini(local_top, int(col_top_y.get(neighbor_col, local_top)))
		var roof_row := local_top - roof_clearance_rows
		local_roof_rows[column] = roof_row
		roof_cells[Vector2i(column, roof_row)] = true

	# Connect vertical steps in the contour-hugging ceiling on the outer (low-ceiling) column so steps never hang into playable air
	for column in range(min_column + 1, max_column):
		var r_prev := int(local_roof_rows[column - 1])
		var r_curr := int(local_roof_rows[column])
		if r_prev != r_curr:
			var r_min := mini(r_prev, r_curr)
			var r_max := maxi(r_prev, r_curr)
			var step_col := column - 1 if r_curr < r_prev else column
			for ry in range(r_min, r_max + 1):
				var step_roof_cell := Vector2i(step_col, ry)
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
		var atlas := _select_roof_or_bedrock_atlas(r_cell, world_occupied, min_column, max_column, local_roof_rows)
		_roof.set_cell(r_cell, 0, atlas)

	# Every authored chunk uses the shared 48-pixel terrain grid.
	fall_death_y = float(lowest_row + 1) * TERRAIN_GRID_SIZE + fall_death_margin

	return {
		"world_occupied": world_occupied,
		"chunk_cells": chunk_cells,
		"col_floor_y": col_floor_y,
		"min_column": min_column,
		"max_column": max_column,
		"traversal_min_col": traversal_min_col,
		"traversal_max_col": traversal_max_col,
	}


func _select_roof_or_bedrock_atlas(
	cell: Vector2i,
	occupied: Dictionary,
	min_column: int,
	max_column: int,
	local_roof_rows: Dictionary = {}
) -> Vector2i:
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

	var is_ceiling_tile := local_roof_rows.has(cell.x) and cell.y <= int(local_roof_rows[cell.x])
	# Ceiling tiles: playable area is BELOW, so moss/stone faces DOWN and fades into #21263f at the top
	if (is_ceiling_tile or (local_roof_rows.is_empty() and cell.y < 0)) and not has_down:
		if absi(cell.x) % 4 == 0:
			return CourseChunk.ATLAS_STONE_TOP
		return CourseChunk.ATLAS_EARTH_BOTTOM if use_earth else CourseChunk.ATLAS_MOSS_BOTTOM

	# Floor seal tiles: playable area is ABOVE, so grass faces UP and fades into #21263f at the bottom
	if not has_up and not is_ceiling_tile:
		return CourseChunk.ATLAS_EARTH_TOP if use_earth else CourseChunk.ATLAS_MOSS_TOP

	# Vertical step connectors inside ceiling or floor steps
	if not has_left and has_right:
		return CourseChunk.ATLAS_EARTH_WALL if use_earth else CourseChunk.ATLAS_MOSS_LEFT
	if has_left and not has_right:
		return CourseChunk.ATLAS_STONE_RIGHT if use_earth else CourseChunk.ATLAS_MOSS_RIGHT

	return CourseChunk.ATLAS_EARTH_CENTER if use_earth else CourseChunk.ATLAS_MOSS_CENTER


func _ensure_dynamic_features_node() -> void:
	if _dynamic_features != null and is_instance_valid(_dynamic_features):
		return
	var existing := get_node_or_null("DynamicFeatures") as Node2D
	if existing != null:
		_dynamic_features = existing
		return
	_dynamic_features = Node2D.new()
	_dynamic_features.name = "DynamicFeatures"
	add_child(_dynamic_features)


func _spawn_dynamic_course_features(random: RandomNumberGenerator, layout_data: Dictionary) -> void:
	if layout_data.is_empty() or _dynamic_features == null:
		return
	var world_occupied: Dictionary = layout_data["world_occupied"]
	var chunk_cells: Dictionary = layout_data.get("chunk_cells", {})
	var col_floor_y: Dictionary = layout_data["col_floor_y"]
	var traversal_min_col := int(layout_data["traversal_min_col"])
	var traversal_max_col := int(layout_data["traversal_max_col"])

	var blocked_cells: Dictionary = world_occupied.duplicate()
	for chunk_node in _generated_chunks.get_children():
		for child in chunk_node.get_children():
			if child is StaticBody2D:
				_mark_static_body_cells_blocked(child as StaticBody2D, blocked_cells)

	var unsafe_cols := _build_unsafe_yellow_block_columns()

	# 1. Spawn indestructible E-revealed yellow blocks only on flat, open single-floor runways
	var yellow_candidates: Array[int] = []
	for col in range(traversal_min_col + 3, traversal_max_col - 3):
		if unsafe_cols.has(col):
			continue
		if not col_floor_y.has(col):
			continue
		var fy := int(col_floor_y[col])

		# Flat runway check across [col - 2, col + 2]
		var is_flat_runway := true
		for dx in range(-2, 3):
			var c := col + dx
			if unsafe_cols.has(c):
				is_flat_runway = false
				break
			if not col_floor_y.has(c) or int(col_floor_y[c]) != fy:
				is_flat_runway = false
				break
			if not world_occupied.has(Vector2i(c, fy)):
				is_flat_runway = false
				break
		if not is_flat_runway:
			continue

		# Air clearance check across [col - 2, col + 2]
		var is_air_clear := true
		for dx in range(-2, 3):
			var c := col + dx
			if blocked_cells.has(Vector2i(c, fy - 1)) or blocked_cells.has(Vector2i(c, fy - 2)):
				is_air_clear = false
				break
			# No chunk cells above the floor anywhere in the runway (e.g. low platforms, bridges overhead)
			for y in range(fy - 8, fy):
				if chunk_cells.has(Vector2i(c, y)):
					is_air_clear = false
					break
			if not is_air_clear:
				break
		if not is_air_clear:
			continue

		yellow_candidates.append(col)

	_shuffle_ints(yellow_candidates, random)
	var placed_yellow_cols: Array[int] = []
	for col in yellow_candidates:
		if placed_yellow_cols.size() >= yellow_blocks_per_course:
			break
		var too_close := false
		for prev_col in placed_yellow_cols:
			if absi(col - prev_col) < 5:
				too_close = true
				break
		if too_close:
			continue
		var fy := int(col_floor_y[col])
		var yellow := YELLOW_BLOCK_SCENE.instantiate() as Node2D
		yellow.position = Vector2(float(col) * TERRAIN_GRID_SIZE, float(fy - 1) * TERRAIN_GRID_SIZE)
		_dynamic_features.add_child(yellow)
		blocked_cells[Vector2i(col, fy - 1)] = true
		blocked_cells[Vector2i(col, fy - 2)] = true
		placed_yellow_cols.append(col)


func _build_unsafe_yellow_block_columns() -> Dictionary:
	var unsafe_cols: Dictionary = {}
	for chunk_node in _generated_chunks.get_children():
		var chunk := chunk_node as CourseChunk
		if chunk == null:
			continue
		var is_complex := false
		if chunk.terrain_features.has(&"double_floor") \
			or chunk.terrain_features.has(&"branching_paths") \
			or chunk.terrain_features.has(&"wall_climb") \
			or chunk.terrain_features.has(&"breakable_wall") \
			or chunk.terrain_features.has(&"noise_foam") \
			or chunk.dead_end_paths > 0:
			is_complex = true

		var chunk_id_str := String(chunk.chunk_id)
		if "stacked" in chunk_id_str \
			or "maze" in chunk_id_str \
			or "double_floor" in chunk_id_str \
			or "dead_end" in chunk_id_str \
			or "wall_jump" in chunk_id_str \
			or "wall_blast" in chunk_id_str \
			or "break_through" in chunk_id_str \
			or "foam" in chunk_id_str:
			is_complex = true

		if is_complex:
			var grid := chunk.grid_size
			var c_entry := roundi((chunk.position.x + chunk.entry_position().x) / float(grid.x))
			var c_exit := roundi((chunk.position.x + chunk.exit_position().x) / float(grid.x))
			var c_start := mini(c_entry, c_exit)
			var c_end := maxi(c_entry, c_exit)
			for c in range(c_start - 3, c_end + 4):
				unsafe_cols[c] = true
	return unsafe_cols


func _mark_static_body_cells_blocked(body: StaticBody2D, blocked: Dictionary) -> void:
	var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		return
	var rect_shape := shape_node.shape as RectangleShape2D
	if rect_shape == null:
		return
	var extents := rect_shape.size * 0.5
	var parent_node := body.get_parent() as Node2D
	var parent_pos := parent_node.position if parent_node != null else Vector2.ZERO
	var center: Vector2 = parent_pos + body.position + shape_node.position
	var half := TERRAIN_GRID_SIZE * 0.5
	var min_pos: Vector2 = center - extents
	var max_pos: Vector2 = center + extents
	var min_cx := floori((min_pos.x + half) / TERRAIN_GRID_SIZE)
	var max_cx := floori((max_pos.x + half - 0.01) / TERRAIN_GRID_SIZE)
	var min_cy := floori((min_pos.y + half) / TERRAIN_GRID_SIZE)
	var max_cy := floori((max_pos.y + half - 0.01) / TERRAIN_GRID_SIZE)
	for cx in range(min_cx, max_cx + 1):
		for cy in range(min_cy, max_cy + 1):
			blocked[Vector2i(cx, cy)] = true


func _shuffle_ints(arr: Array[int], random: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := random.randi_range(0, i)
		var tmp := arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _clear_generated_chunks() -> void:
	_roof.clear()
	for chunk in _generated_chunks.get_children():
		_generated_chunks.remove_child(chunk)
		chunk.queue_free()
	if _dynamic_features != null and is_instance_valid(_dynamic_features):
		for feat in _dynamic_features.get_children():
			_dynamic_features.remove_child(feat)
			feat.queue_free()
