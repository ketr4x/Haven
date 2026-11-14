class_name CourseGenerator
extends Node2D

signal course_generated(seed: int, signature: String)

@export var start_chunk: PackedScene
@export var traversal_chunks: Array[PackedScene]
@export var finish_chunk: PackedScene
@export_range(1, 8) var traversal_count: int = 5
@export var seed_value: int = 12_345

@onready var _generated_chunks: Node2D = $GeneratedChunks

var course_signature: String = ""
var player_spawn: Vector2 = Vector2.ZERO

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

	for index in traversal_count:
		var chunk_scene := traversal_chunks[random.randi_range(0, traversal_chunks.size() - 1)]
		var chunk := _place_chunk(chunk_scene, next_entry)
		next_entry = chunk.position + chunk.exit_position()
		sequence.append(String(chunk.chunk_id))

	var finish := _place_chunk(finish_chunk, next_entry)
	sequence.append(String(finish.chunk_id))
	course_signature = " > ".join(sequence)
	course_generated.emit(seed_value, course_signature)


func _place_chunk(chunk_scene: PackedScene, entry_position: Vector2) -> CourseChunk:
	var chunk := chunk_scene.instantiate() as CourseChunk
	_generated_chunks.add_child(chunk)
	chunk.position = entry_position - chunk.entry_position()
	return chunk


func _clear_generated_chunks() -> void:
	for chunk in _generated_chunks.get_children():
		_generated_chunks.remove_child(chunk)
		chunk.queue_free()
