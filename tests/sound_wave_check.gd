extends SceneTree

const MOVEMENT_LAB := preload("res://scenes/game/movement_lab.tscn")
const SOUND_WAVE := preload("res://scenes/effects/sound_wave.tscn")
const REVEAL_RING := preload("res://scenes/effects/reveal_ring.tscn")

var _bounce_count: int = 0
var _surface_reached_count: int = 0

func _initialize() -> void:
	var lab := MOVEMENT_LAB.instantiate()
	root.add_child(lab)
	await physics_frame

	var player := lab.get_node("PlayerOne") as RezonansPlayer
	var wave := SOUND_WAVE.instantiate() as SoundWave
	lab.add_child(wave)
	wave.bounced.connect(_on_wave_bounced)
	wave.surface_reached.connect(_on_surface_reached)
	wave.setup(player, Vector2(540, 546), Vector2.RIGHT, 50.0, 1)
	assert(not wave.visible)
	assert(wave.get_child_count() == 0)

	for frame in 20:
		await physics_frame

	assert(_bounce_count == 1)
	assert(_surface_reached_count == 1)
	assert(wave.bounce_count == 1)
	assert(wave.velocity.x < 0.0)

	var quiet_wave := SOUND_WAVE.instantiate() as SoundWave
	var loud_wave := SOUND_WAVE.instantiate() as SoundWave
	lab.add_child(quiet_wave)
	lab.add_child(loud_wave)
	quiet_wave.setup(player, Vector2(300, 300), Vector2.UP, 10.0, 2)
	loud_wave.setup(player, Vector2(340, 300), Vector2.UP, 100.0, 3, 1.0, false, 1_200.0)
	assert(loud_wave.lifetime > quiet_wave.lifetime)
	assert(loud_wave.lifetime >= 1_200.0 / loud_wave.speed)

	var ring := REVEAL_RING.instantiate() as RevealRing
	lab.add_child(ring)
	ring.global_position = Vector2(400, 546)
	ring.configure(100.0, 1.0, Vector2.RIGHT)
	assert(is_equal_approx(ring.arc_angle_degrees, 70.0))
	assert(is_equal_approx(ring.arc_interval, 0.05))
	assert(ring.arc_count == 7)
	assert(is_equal_approx(ring.propagation_speed, 900.0))
	assert(ring.maximum_radius >= 1_600.0)
	assert(ring.wave_amplitude >= 2.0)
	assert(ring.primary_wave_cycles > 2.5)
	assert(ring.secondary_wave_cycles > 7.0)
	assert(ring.get_child_count() == 0)
	assert(ring.get_active_arc_count() == 1)
	assert(ring.get_current_pixel_count() >= 6)
	for pixel in ring.get_rendered_pixel_positions():
		assert(pixel == pixel.round())
	ring._process(0.051)
	assert(ring.get_active_arc_count() == 2)
	assert(ring.get_arc_alpha(0) < ring.starting_alpha)
	assert(ring.get_occlusion_limit(0.5) < ring.maximum_radius)

	var moving_wave := SOUND_WAVE.instantiate() as SoundWave
	lab.add_child(moving_wave)
	moving_wave.setup(player, Vector2(300, 300), Vector2.RIGHT, 50.0, 4, 1.0, false, 900.0, Vector2(300.0, 0.0))
	assert(moving_wave.velocity.is_equal_approx(Vector2(1200.0, 0.0)))

	var moving_ring := REVEAL_RING.instantiate() as RevealRing
	lab.add_child(moving_ring)
	moving_ring.global_position = Vector2(200, 300)
	moving_ring.configure(50.0, 0.45, Vector2.RIGHT, Vector2(300.0, 0.0))
	moving_ring._process(0.1)
	assert(moving_ring.global_position.x > 225.0)

	print("Sound wave check passed.")
	quit()


func _on_wave_bounced(_position: Vector2, _normal: Vector2, _count: int) -> void:
	_bounce_count += 1


func _on_surface_reached(_position: Vector2, _normal: Vector2, _intensity: float, _tile_size: float) -> void:
	_surface_reached_count += 1
