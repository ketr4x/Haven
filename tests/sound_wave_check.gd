extends SceneTree

const MOVEMENT_LAB := preload("res://scenes/game/movement_lab.tscn")
const SOUND_WAVE := preload("res://scenes/effects/sound_wave.tscn")
const REVEAL_RING := preload("res://scenes/effects/reveal_ring.tscn")

var _bounce_count: int = 0

func _initialize() -> void:
	var lab := MOVEMENT_LAB.instantiate()
	root.add_child(lab)
	await physics_frame

	var player := lab.get_node("PlayerOne") as RezonansPlayer
	var wave := SOUND_WAVE.instantiate() as SoundWave
	lab.add_child(wave)
	wave.bounced.connect(_on_wave_bounced)
	wave.setup(player, Vector2(540, 546), Vector2.RIGHT, 50.0, 1)

	for frame in 20:
		await physics_frame

	assert(_bounce_count == 1)
	assert(wave.bounce_count == 1)
	assert(wave.velocity.x < 0.0)

	var ring := REVEAL_RING.instantiate() as RevealRing
	lab.add_child(ring)
	ring.global_position = Vector2(400, 400)
	ring.configure(100.0)
	var wave_front := ring.get_node("WaveFront") as Line2D
	assert(is_equal_approx(wave_front.points[0].length(), wave_front.points[32].length()))
	ring.add_bounce(ring.global_position + Vector2.RIGHT * 100.0, Vector2.LEFT, 1)
	ring._advance_impacts(0.1)
	ring._update_outline(1.0)
	assert(not is_equal_approx(wave_front.points[0].length(), wave_front.points[32].length()))
	print("Sound wave check passed.")
	quit()


func _on_wave_bounced(_position: Vector2, _normal: Vector2, _count: int) -> void:
	_bounce_count += 1
