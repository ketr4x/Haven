extends SceneTree

const GENERATOR_LAB := preload("res://scenes/game/generator_lab.tscn")

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
	_assert_collision_geometry_is_visible(chunks)

	var signatures: Dictionary = {}
	for seed in range(1, 31):
		generator.generate_course(seed)
		assert(chunks.get_child_count() == 7)
		assert((chunks.get_child(0) as CourseChunk).chunk_id == &"start")
		assert((chunks.get_child(chunks.get_child_count() - 1) as CourseChunk).chunk_id == &"finish")
		_assert_collision_geometry_is_visible(chunks)
		signatures[generator.course_signature] = true

	assert(signatures.size() > 1)
	print("Seeded generator check passed for 30 seeds.")
	quit()


func _assert_collision_geometry_is_visible(chunks: Node) -> void:
	for body in chunks.find_children("*", "StaticBody2D", true, false):
		assert(body.get_node_or_null("CollisionShape2D") is CollisionShape2D)
		assert(body.get_node_or_null("Visual") is CanvasItem)
