extends SceneTree

const MOVEMENT_LAB := preload("res://scenes/game/movement_lab.tscn")
const SOUND_WAVE := preload("res://scenes/effects/sound_wave.tscn")

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
	var beam_trail := wave.get_node("BeamTrail") as Line2D
	var starting_alpha := beam_trail.default_color.a

	for frame in 20:
		await physics_frame

	assert(_bounce_count == 1)
	assert(wave.bounce_count == 1)
	assert(wave.velocity.x < 0.0)
	assert(beam_trail.points.size() > 2)
	assert(beam_trail.default_color.a < starting_alpha)
	print("Sound wave check passed.")
	quit()


func _on_wave_bounced(_position: Vector2, _normal: Vector2, _count: int) -> void:
	_bounce_count += 1
