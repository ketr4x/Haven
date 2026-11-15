extends SceneTree

const GENERATOR_LAB := preload("res://scenes/game/generator_lab.tscn")
const TERRAIN_TILESET := "res://resources/tiles/terrain_tileset.tres"
const TERRAIN_GRID_OFFSET := Vector2(-24, -24)

func _initialize() -> void:
	var lab := GENERATOR_LAB.instantiate()
	root.add_child(lab)
	await process_frame

	var generator := lab.get_node("CourseGenerator") as CourseGenerator
	var chunks := generator.get_node("GeneratedChunks")
	var roof := generator.get_node("Roof") as TileMapLayer
	assert(roof.tile_set.resource_path == TERRAIN_TILESET)
	assert(not roof.get_used_cells().is_empty())
	assert(generator.fall_death_y > 0.0)
	generator.generate_course(12_345)
	var first_signature := generator.course_signature

	generator.generate_course(12_345)
	assert(generator.course_signature == first_signature)
	assert(chunks.get_child_count() == 7)
	assert((chunks.get_child(0) as CourseChunk).chunk_id == &"start")
	assert((chunks.get_child(chunks.get_child_count() - 1) as CourseChunk).chunk_id == &"finish")
	_assert_chunk_terrain_uses_common_grid(chunks, generator)

	var signatures: Dictionary = {}
	for seed in range(1, 31):
		generator.generate_course(seed)
		assert(chunks.get_child_count() == 7)
		assert((chunks.get_child(0) as CourseChunk).chunk_id == &"start")
		assert((chunks.get_child(chunks.get_child_count() - 1) as CourseChunk).chunk_id == &"finish")
		_assert_chunk_terrain_uses_common_grid(chunks, generator)
		signatures[generator.course_signature] = true

	await physics_frame
	await physics_frame
	await physics_frame
	_assert_tile_collision_matches_cell(chunks.get_child(0) as CourseChunk)

	assert(signatures.size() > 1)
	print("Seeded tilemap generator check passed for 30 seeds.")
	quit()


func _assert_chunk_terrain_uses_common_grid(chunks: Node, generator: CourseGenerator) -> void:
	var tmj_cells := CourseChunk.extract_tmj_cells("res://resources/tiles/gametilemap.tmj")
	assert(tmj_cells.size() == 17)
	assert(generator.roof_clearance_rows == 3)
	var roof := generator.get_node("Roof") as TileMapLayer
	var world_cells: Dictionary = {}
	var min_col := 0
	var max_col := 0
	var feature_counts: Dictionary = {}
	for chunk_node in chunks.get_children():
		var chunk := chunk_node as CourseChunk
		for feature in chunk.terrain_features:
			feature_counts[feature] = int(feature_counts.get(feature, 0)) + 1
		feature_counts[&"dead_end_paths"] = int(feature_counts.get(&"dead_end_paths", 0)) + chunk.dead_end_paths
		assert(chunk.has_valid_grid_geometry())
		var terrain := chunk.get_node_or_null("Terrain") as TileMapLayer
		assert(terrain != null)
		assert(terrain.tile_set.resource_path == TERRAIN_TILESET)
		assert(terrain.tile_set.tile_size == chunk.grid_size)
		assert(terrain.position == TERRAIN_GRID_OFFSET)
		assert(terrain.get_used_cells().size() == chunk.terrain_cells.size())
		var chunk_offset := Vector2i(
			roundi(chunk.position.x / float(chunk.grid_size.x)),
			roundi(chunk.position.y / float(chunk.grid_size.y)),
		)
		var entry_col := roundi((chunk.position.x + chunk.entry_position().x) / float(chunk.grid_size.x))
		var exit_col := roundi((chunk.position.x + chunk.exit_position().x) / float(chunk.grid_size.x))
		min_col = mini(min_col, mini(entry_col, exit_col))
		max_col = maxi(max_col, maxi(entry_col, exit_col))
		for cell in chunk.terrain_cells:
			assert(terrain.get_cell_source_id(cell) == 0)
			var atlas_coords := terrain.get_cell_atlas_coords(cell)
			assert(atlas_coords.x >= 0 and atlas_coords.x < 8)
			assert(atlas_coords.y >= 0 and atlas_coords.y < 12)
			assert(atlas_coords != Vector2i.ZERO)
			var mirrored := Vector2i(-cell.x, cell.y) if chunk.mirror_horizontally else cell
			world_cells[chunk_offset + mirrored] = true
		for body in chunk.find_children("*", "StaticBody2D", true, false):
			assert(body.is_in_group(&"sound_absorber"))
	for roof_cell in roof.get_used_cells():
		world_cells[roof_cell] = true
	# Every column across the course must have both floor/bedrock support and a ceiling above it
	for col in range(min_col, max_col):
		var col_min_y := 999999
		var col_max_y := -999999
		for cell_variant in world_cells.keys():
			var c: Vector2i = cell_variant
			if c.x == col:
				col_min_y = mini(col_min_y, c.y)
				col_max_y = maxi(col_max_y, c.y)
		assert(col_min_y < col_max_y)
		assert(col_max_y - col_min_y >= generator.roof_clearance_rows)
	assert(int(feature_counts.get(&"noise_foam", 0)) <= generator.max_noise_foam_chunks)
	assert(int(feature_counts.get(&"branching_paths", 0)) <= generator.max_branching_path_chunks)
	assert(int(feature_counts.get(&"wall_climb", 0)) >= generator.min_wall_climb_chunks)
	assert(int(feature_counts.get(&"dead_end_paths", 0)) <= generator.max_dead_end_paths)


func _assert_tile_collision_matches_cell(chunk: CourseChunk) -> void:
	var terrain := chunk.get_node("Terrain") as TileMapLayer
	var cell_center := terrain.to_global(terrain.map_to_local(chunk.terrain_cells[0]))
	var expected_top := cell_center.y - float(chunk.grid_size.y) * 0.5
	var query := PhysicsRayQueryParameters2D.create(
		cell_center - Vector2(0.0, float(chunk.grid_size.y)),
		cell_center + Vector2(0.0, float(chunk.grid_size.y)),
		1,
	)
	var hit := chunk.get_world_2d().direct_space_state.intersect_ray(query)
	assert(not hit.is_empty())
	var hit_position: Vector2 = hit["position"]
	assert(is_equal_approx(hit_position.y, expected_top))
