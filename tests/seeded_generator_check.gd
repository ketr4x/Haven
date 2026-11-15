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
		for cell in chunk.terrain_cells:
			assert(terrain.get_cell_source_id(cell) == 0)
		for body in chunk.find_children("*", "StaticBody2D", true, false):
			assert(body.is_in_group(&"sound_absorber") or body.is_in_group(&"breakable_wall"))
	assert(int(feature_counts.get(&"noise_foam", 0)) <= generator.max_noise_foam_chunks)
	assert(int(feature_counts.get(&"breakable_wall", 0)) <= generator.max_breakable_wall_chunks)
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
