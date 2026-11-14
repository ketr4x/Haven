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
	var first_signature := generator.course_signature

	generator.generate_course(12_345)
	assert(generator.course_signature == first_signature)
	assert(chunks.get_child_count() == 7)
	assert((chunks.get_child(0) as CourseChunk).chunk_id == &"start")
	assert((chunks.get_child(chunks.get_child_count() - 1) as CourseChunk).chunk_id == &"finish")
	_assert_chunk_terrain_uses_common_grid(chunks)

	var signatures: Dictionary = {}
	for seed in range(1, 31):
		generator.generate_course(seed)
		assert(chunks.get_child_count() == 7)
		assert((chunks.get_child(0) as CourseChunk).chunk_id == &"start")
		assert((chunks.get_child(chunks.get_child_count() - 1) as CourseChunk).chunk_id == &"finish")
		_assert_chunk_terrain_uses_common_grid(chunks)
		signatures[generator.course_signature] = true

	assert(signatures.size() > 1)
	print("Seeded tilemap generator check passed for 30 seeds.")
	quit()


func _assert_chunk_terrain_uses_common_grid(chunks: Node) -> void:
	for chunk_node in chunks.get_children():
		var chunk := chunk_node as CourseChunk
		assert(chunk.has_valid_grid_geometry())
		var terrain := chunk.get_node_or_null("Terrain") as TileMapLayer
		assert(terrain != null)
		assert(terrain.tile_set.resource_path == TERRAIN_TILESET)
		assert(terrain.tile_set.tile_size == chunk.grid_size)
		assert(terrain.position == TERRAIN_GRID_OFFSET)
		assert(terrain.get_used_cells().size() == chunk.terrain_cells.size())
		for cell in chunk.terrain_cells:
			assert(terrain.get_cell_source_id(cell) == 0)
		assert(chunk.find_children("*", "StaticBody2D", true, false).is_empty())
