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
	var waves := world.get_node("FeedbackCanvas/Waves") as Node2D
	assert(player.global_position == generator.to_global(generator.player_spawn))

	player.loudness = 25.0
	Input.action_press(player.shout_action)
	player._emit_shout_if_requested()
	Input.action_release(player.shout_action)
	assert(is_equal_approx(player.loudness, 25.0))
	assert(waves.get_child_count() == 0)

	player.velocity = Vector2(300.0, 0.0)
	world._on_footstep_emitted(player.global_position, Vector2.RIGHT, 100.0)
	var projectile_count := 0
	var first_wave: SoundWave = null
	for child in waves.get_children():
		if child is SoundWave:
			projectile_count += 1
			if first_wave == null:
				first_wave = child as SoundWave
	assert(projectile_count == world.footstep_wave_count)
	assert(waves.get_child_count() == world.footstep_wave_count + 1)
	var small_step_arc := waves.get_child(0) as RevealRing
	assert(small_step_arc._source_velocity.is_equal_approx(Vector2(300.0, 0.0)))
	assert(small_step_arc.maximum_radius >= 250.0)
	assert(first_wave != null and first_wave.velocity.x > first_wave.speed)
	for frame in 4:
		await physics_frame
	var overlay := world.get_node("EchoCanvas/EchoOverlay") as EchoOverlay
	assert(overlay.get_active_echo_count() > 0)
	overlay._echoes.clear()
	player.velocity = Vector2.ZERO
	world._clear_waves()
	for step in 2:
		world._on_footstep_emitted(player.global_position, Vector2.RIGHT, 100.0)
		world._clear_waves()
	world._on_footstep_emitted(player.global_position, Vector2.RIGHT, 100.0)
	projectile_count = 0
	for child in waves.get_children():
		if child is SoundWave:
			projectile_count += 1
	assert(projectile_count == world.large_footstep_wave_count)
	var large_step_arc := waves.get_child(0) as RevealRing
	assert(large_step_arc.maximum_radius >= 12.0 * 48.0)
	world._clear_waves()

	world._on_player_landed(player.global_position, player.hard_landing_speed)
	projectile_count = 0
	for child in waves.get_children():
		if child is SoundWave:
			projectile_count += 1
	assert(projectile_count == world.hard_landing_wave_count)
	assert(waves.get_child_count() == world.hard_landing_wave_count + 1)
	assert((waves.get_child(0) as RevealRing).maximum_radius >= 15.0 * 48.0)
	world._clear_waves()

	world._on_probe_bounced(
		player.global_position + Vector2(120.0, 0.0),
		Vector2.LEFT,
		1,
		Vector2.RIGHT,
		70.0,
		999,
	)
	assert(waves.get_child_count() == 1)
	assert(waves.get_child(0) is RevealRing)
	var reflected_arc := waves.get_child(0) as RevealRing
	assert(reflected_arc.is_echo())
	assert(reflected_arc.arc_count == 1)
	assert(reflected_arc.get_child_count() == 0)
	assert(reflected_arc.get_current_pixel_count() > 0)
	assert(reflected_arc._base_color.r > reflected_arc._base_color.b)
	world._clear_waves()

	player.big_scream_plus_emitted.emit(player.global_position, Vector2.RIGHT, 100.0)
	var plus_arc := waves.get_child(0) as RevealRing
	assert(is_equal_approx(plus_arc.arc_angle_degrees, 30.0))
	assert(plus_arc.maximum_radius >= 15.0 * 48.0)
	for child in waves.get_children():
		if child is SoundWave:
			assert(absf((child as SoundWave).velocity.angle_to(Vector2.RIGHT)) <= deg_to_rad(15.1))
	var plus_pulse_id := world._next_pulse_id
	assert(int(world._pulse_return_effects[plus_pulse_id]) == PlayerWorld.ReturnEffect.PLUS_BOOST)
	world._on_wave_returned(player, 100.0, plus_pulse_id)
	assert(player._boost_time_remaining > 0.0)
	assert(player._echo_opportunity_remaining > 0.0)
	player._boost_time_remaining = 0.0
	player._echo_opportunity_remaining = 0.0
	player._boost_aura.visible = false
	player._boost_trail.emitting = false
	_boost_started = false
	world._clear_waves()

	player._big_scream_cooldown_remaining = 0.0
	player.big_scream_minus_emitted.emit(player.global_position, Vector2.RIGHT, 100.0)
	var minus_pulse_id := world._next_pulse_id
	assert(int(world._pulse_return_effects[minus_pulse_id]) == PlayerWorld.ReturnEffect.SLOW)
	world._on_wave_returned(player, 100.0, minus_pulse_id)
	assert(is_equal_approx(player._echo_slow_remaining, player.echo_slow_duration))
	player._echo_slow_remaining = 0.0
	world._clear_waves()

	var emission_directions := world._sample_concentrated_directions(Vector2.RIGHT, 20, 70.0)
	for direction in emission_directions:
		assert(absf(direction.angle_to(Vector2.RIGHT)) <= deg_to_rad(35.1))
	assert(emission_directions.size() == 20)

	player.rebound_boost_started.connect(_on_boost_started)
	var overlay_material := overlay.material as ShaderMaterial
	var background_color := overlay_material.get_shader_parameter("background_color") as Color
	var dim_floor_color := overlay_material.get_shader_parameter("dim_floor_color") as Color
	assert(background_color == Color(0.0, 0.0, 0.0, 1.0))
	assert(dim_floor_color.r >= 0.25)
	overlay.register_hit(player.global_position + Vector2(120.0, 0.0), Vector2.LEFT, 80.0)
	assert(is_equal_approx(float(overlay._echoes[0]["time"]), overlay.afterglow_duration))
	await process_frame
	assert(overlay.get_active_echo_count() == 1)
	assert(int(overlay_material.get_shader_parameter("echo_hit_count")) == 1)
	assert(is_equal_approx(
		float(overlay_material.get_shader_parameter("floor_band_offset")),
		overlay.floor_band_offset,
	))

	world._on_player_pulsed(player.global_position, Vector2.RIGHT, 60.0, 20)
	for frame in 240:
		await physics_frame
		if player._echo_opportunity_remaining > 0.0:
			Input.action_press(player.jump_action)
			await physics_frame
			Input.action_release(player.jump_action)
		if _boost_started:
			break

	assert(_boost_started)
	assert(overlay.get_active_echo_count() > 0)
	var exact_tile_was_revealed := false
	for echo_data in overlay._echoes:
		if float(echo_data["radius"]) < 0.0:
			exact_tile_was_revealed = true
			break
	assert(exact_tile_was_revealed)
	world.queue_free()
	for frame in 60:
		await process_frame
	print("Player world echo check passed.")
	quit()


func _on_boost_started() -> void:
	_boost_started = true
