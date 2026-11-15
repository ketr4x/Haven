extends SceneTree

const PLAYER_WORLD := preload("res://scenes/game/player_world.tscn")

var _bounce_events: int = 0
var _illuminated_events: int = 0


func _initialize() -> void:
	var world := PLAYER_WORLD.instantiate() as PlayerWorld
	root.add_child(world)
	await process_frame
	world.generate_course(12_345)
	await physics_frame

	var sonar := world.sonar_grid
	assert(sonar != null)
	assert(not sonar.tiles.is_empty())

	# Floor tiles must always be visible (>= floor_min_light_level), while airborne tiles start at 0.0 (pitch black).
	var found_lit_floor := false
	var found_unlit_airborne := false
	var sample_airborne_cell := Vector2i.ZERO
	for cell_variant in sonar.tiles.keys():
		var cell: Vector2i = cell_variant
		var tile: Dictionary = sonar.tiles[cell]
		if bool(tile["is_floor"]):
			assert(float(tile["light_level"]) >= sonar.floor_min_light_level)
			found_lit_floor = true
		else:
			assert(is_zero_approx(float(tile["light_level"])))
			found_unlit_airborne = true
			sample_airborne_cell = cell

	assert(found_lit_floor)
	assert(found_unlit_airborne)

	# Emitting an asymmetric 90-ray pulse creates stronger/faster forward rays than peripheral rays.
	sonar.wave_bounced.connect(_on_wave_bounced)
	sonar.tile_illuminated.connect(_on_tile_illuminated)
	var player := world.get_node("Player") as RezonansPlayer
	var spawned := sonar.emit_pulse(player.global_position, Vector2.RIGHT, 90, 1.5, 1, SonarGrid.PulseKind.SCREAM)
	assert(spawned == 90)
	assert(sonar.active_rays.size() == 90)

	var forward_ray: Dictionary = sonar.active_rays[0]
	var backward_ray: Dictionary = sonar.active_rays[45]
	assert(bool(forward_ray["is_forward"]))
	assert(not bool(backward_ray["is_forward"]))
	assert(int(forward_ray["pulse_id"]) > 0)
	assert(int(forward_ray["ray_index"]) == 0)
	assert(SonarGrid.ARC_BAND_OFFSETS.size() == 3)
	assert(Vector2(forward_ray["velocity"]).length() > Vector2(backward_ray["velocity"]).length())
	assert(int(forward_ray["max_bounces"]) == 5)
	assert(int(backward_ray["max_bounces"]) < int(forward_ray["max_bounces"]))

	# Vignette overlay around the player starts very dark and tight, and opens up when Scream is used.
	assert(world.vignette_rect != null)
	var vignette_mat := world.vignette_rect.material as ShaderMaterial
	assert(vignette_mat != null)
	var base_inner := float(vignette_mat.get_shader_parameter("inner_radius"))
	assert(is_equal_approx(base_inner, world.base_vignette_inner_radius))
	world._on_player_sonic_shouted(player.global_position, Vector2.RIGHT, 80.0)
	var scream_inner := float(vignette_mat.get_shader_parameter("inner_radius"))
	assert(scream_inner > base_inner)

	for frame in 35:
		await process_frame

	assert(_bounce_events > 0)
	assert(_illuminated_events > 0)
	assert(not sonar.active_ripples.is_empty())
	assert(not sonar.active_rays.is_empty())

	# Waves stay present and keep bouncing continuously for the entire visibility duration (fade_duration = 4.0s).
	sonar.clear_waves()
	sonar.emit_pulse(player.global_position, Vector2.RIGHT, 90, 1.5, 1, SonarGrid.PulseKind.SCREAM)
	assert(is_equal_approx(float(sonar.active_rays[0]["max_lifetime"]), sonar.fade_duration))
	for step in 25:
		sonar._update_rays_and_ripples(0.1)
	assert(not sonar.active_rays.is_empty())
	var max_observed_bounces := 0
	for ray_variant in sonar.active_rays:
		var r: Dictionary = ray_variant
		max_observed_bounces = maxi(max_observed_bounces, int(r["bounce_count"]))
		var ratio := float(r["remaining_lifetime"]) / float(r["max_lifetime"])
		assert(ratio > 0.3 and ratio < 0.5)
	assert(max_observed_bounces >= 5)
	for step in 16:
		sonar._update_rays_and_ripples(0.1)
	assert(sonar.active_rays.is_empty())

	# Alpha decay curve loses 80% in the first 2 seconds and fades down to very low alpha before vanishing.
	assert(is_equal_approx(sonar.compute_wave_alpha_factor(4.0, 4.0), 1.0))
	assert(is_equal_approx(sonar.compute_wave_alpha_factor(2.0, 4.0), 0.2))
	var late_alpha := sonar.compute_wave_alpha_factor(1.0, 4.0)
	var tail_alpha := sonar.compute_wave_alpha_factor(0.5, 4.0)
	assert(late_alpha > 0.0 and late_alpha < 0.05)
	assert(tail_alpha > 0.0 and tail_alpha < 0.01)
	assert(is_zero_approx(sonar.compute_wave_alpha_factor(0.0, 4.0)))

	# Active ray cap trims oldest rays safely when emitting many concurrent pulses.
	sonar.clear_waves()
	for _pulse in 8:
		sonar.emit_pulse(player.global_position, Vector2.RIGHT, 90, 1.5, 1, SonarGrid.PulseKind.SCREAM)
	assert(sonar.active_rays.size() <= sonar.max_active_rays)
	sonar.clear_waves()

	# Direct illumination sets light_level to 1.0 and boosts neighbors by 0.35, then fades over 4 seconds.
	sonar.illuminate_cell(sample_airborne_cell, 1.0, 2)
	assert(is_equal_approx(sonar.get_tile_light_level(sample_airborne_cell), 1.0))
	sonar._update_tile_fade(2.0)
	var mid_light := sonar.get_tile_light_level(sample_airborne_cell)
	assert(mid_light > 0.35 and mid_light < 0.65)
	sonar._update_tile_fade(2.5)
	assert(is_zero_approx(sonar.get_tile_light_level(sample_airborne_cell)))
	sonar._update_tile_fade(4.5)
	assert(sonar._lit_tiles.is_empty())

	world.queue_free()
	for frame in 10:
		await process_frame
	print("Sound wave check passed.")
	quit()


func _on_wave_bounced(_pos: Vector2, _normal: Vector2, _count: int) -> void:
	_bounce_events += 1


func _on_tile_illuminated(_cell: Vector2i, _kind: int, _light: float) -> void:
	_illuminated_events += 1
