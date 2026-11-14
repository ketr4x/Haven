extends SceneTree

const PLAYER_WORLD := preload("res://scenes/game/player_world.tscn")

var _boost_started: bool = false

func _initialize() -> void:
	var world := PLAYER_WORLD.instantiate() as PlayerWorld
	root.add_child(world)
	await process_frame
	world.generate_course(12_345)
	await physics_frame

	var generator := world.get_node("CourseGenerator") as CourseGenerator
	var player := world.get_node("Player") as RezonansPlayer
	assert(player.global_position == generator.global_position + generator.player_spawn)
	world._on_footstep_emitted(player.global_position, Vector2.RIGHT, 100.0)
	var footstep_ring := world.get_node("Waves").get_child(0) as RevealRing
	assert(footstep_ring.end_scale < 4.0)
	assert(footstep_ring.duration < 0.25)
	world._clear_waves()
	player.rebound_boost_started.connect(_on_boost_started)

	world._on_player_pulsed(player.global_position, Vector2.RIGHT, 60.0, 16)
	for frame in 120:
		await physics_frame
		if _boost_started:
			break

	assert(_boost_started)
	var overlay := world.get_node("EchoCanvas/EchoOverlay") as EchoOverlay
	var overlay_material := overlay.material as ShaderMaterial
	assert(float(overlay_material.get_shader_parameter("reveal_strength")) > 0.0)
	print("Player world echo check passed.")
	quit()


func _on_boost_started() -> void:
	_boost_started = true
