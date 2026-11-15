extends SceneTree

const PLAYER_WORLD := preload("res://scenes/game/player_world.tscn")

var _boost_started: bool = false
var _blind_slowed: bool = false


func _initialize() -> void:
	var world := PLAYER_WORLD.instantiate() as PlayerWorld
	root.add_child(world)
	await process_frame
	world.generate_course(12_345)
	await physics_frame

	var generator := world.get_node("CourseGenerator") as CourseGenerator
	var player := world.get_node("Player") as RezonansPlayer
	var sonar := world.sonar_grid
	assert(player.global_position == generator.to_global(generator.player_spawn))

	# 1. Running loudness caps strictly at 8.0 and footsteps emit capped local waves.
	player.velocity = Vector2(300.0, 0.0)
	player._update_loudness(2.0)
	assert(is_equal_approx(player.loudness, player.step_loudness_cap))
	assert(is_equal_approx(player.step_loudness_cap, 8.0))
	player._update_loudness(5.0)
	assert(is_equal_approx(player.loudness, 8.0))

	sonar.clear_waves()
	world._on_player_slide_started(player.global_position, Vector2.RIGHT)
	assert(sonar.active_rays.is_empty())

	world._on_footstep_emitted(player.global_position, Vector2.RIGHT, 50.0)
	assert(sonar.active_rays.size() == world.footstep_ray_count)
	var step_forward_ray: Dictionary = sonar.active_rays[0]
	var step_max_life := float(step_forward_ray["max_lifetime"])
	assert(int(step_forward_ray["max_bounces"]) <= 2)
	sonar.clear_waves()

	# 2. Jump and Landing emit 120-ray pulses (stronger than walking footsteps).
	world._on_player_jumped(player.global_position)
	assert(sonar.active_rays.size() == 120)
	var jump_forward_ray: Dictionary = sonar.active_rays[0]
	var jump_max_life := float(jump_forward_ray["max_lifetime"])
	assert(step_max_life < jump_max_life)
	sonar.clear_waves()
	world._on_player_landed(player.global_position)
	assert(sonar.active_rays.size() == 120)
	sonar.clear_waves()

	# 3. Scream (E / p1_shout) maxes loudness to 100.0, triggers boost advantage, and emits far-reaching waves.
	player.rebound_boost_started.connect(_on_boost_started)
	player.loudness = player.max_loudness
	world._on_player_sonic_shouted(player.global_position, Vector2.RIGHT, player.loudness)
	assert(_boost_started)
	assert(is_equal_approx(player.loudness, 100.0))
	assert(sonar.active_rays.size() == 90)
	var scream_forward_ray: Dictionary = sonar.active_rays[0]
	assert(float(scream_forward_ray["max_lifetime"]) > jump_max_life * 2.0)
	sonar.clear_waves()

	# 4. Hitting an unlit airborne block significantly slows down the player and triggers flash.
	player.blind_impact_slowed.connect(_on_blind_slowed)
	player.velocity = Vector2(300.0, 0.0)
	player.apply_blind_obstacle_slowdown()
	assert(_blind_slowed)
	assert(player.is_blind_slowed())
	assert(player.is_stunned())
	assert(player.velocity.x < 160.0)

	# 5. Silence darkens outer vignette gently while keeping inner play area clear.
	world._race_active = true
	world._vignette_pulse_strength = 0.0
	sonar.clear_waves()
	world._update_vignette_overlay(1.5)
	var vignette_mat := world.vignette_rect.material as ShaderMaterial
	assert(float(vignette_mat.get_shader_parameter("silence_dim")) > 0.5)

	world.queue_free()
	for frame in 30:
		await process_frame
	print("Player world echo check passed.")
	quit()


func _on_boost_started() -> void:
	_boost_started = true


func _on_blind_slowed(_pos: Vector2) -> void:
	_blind_slowed = true
