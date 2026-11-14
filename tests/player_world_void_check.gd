extends SceneTree

const PLAYER_WORLD := preload("res://scenes/game/player_world.tscn")

var _death_count: int = 0

func _initialize() -> void:
	var world := PLAYER_WORLD.instantiate() as PlayerWorld
	root.add_child(world)
	await process_frame
	world.generate_course(12_345)
	await process_frame

	var generator := world.get_node("CourseGenerator") as CourseGenerator
	var player := world.get_node("Player") as RezonansPlayer
	world.player_died.connect(_on_player_died)
	world.set_race_active(true)
	player.global_position.y = world.death_height + 1.0

	await process_frame
	assert(_death_count == 1)
	assert(not player.is_physics_processing())
	await create_timer(world.respawn_delay + 0.1).timeout

	var spawn_position := generator.to_global(generator.player_spawn)
	assert(player.global_position.distance_to(spawn_position) < 48.0)
	assert(player.is_physics_processing())
	world.queue_free()
	for frame in 60:
		await process_frame
	print("Player world void reset check passed.")
	quit()


func _on_player_died(_player_number: int) -> void:
	_death_count += 1
