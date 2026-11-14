extends SceneTree

const NOISE_FOAM := preload("res://scenes/terrain/noise_foam.tscn")
const SOUND_WAVE := preload("res://scenes/effects/sound_wave.tscn")
const MOVEMENT_LAB := preload("res://scenes/game/movement_lab.tscn")

var _wave_absorbed: bool = false

func _initialize() -> void:
	var lab := MOVEMENT_LAB.instantiate()
	root.add_child(lab)
	await physics_frame

	var player := lab.get_node("PlayerOne") as RezonansPlayer
	var foam := NOISE_FOAM.instantiate() as NoiseFoam
	lab.add_child(foam)
	foam.global_position = Vector2(500, 546)
	await physics_frame
	assert(foam.is_in_group(&"sound_absorber"))

	var wave := SOUND_WAVE.instantiate() as SoundWave
	lab.add_child(wave)
	wave.absorbed.connect(_on_wave_absorbed)
	wave.setup(player, Vector2(400, 546), Vector2.RIGHT, 60.0, 1)
	for frame in 20:
		await physics_frame
	assert(_wave_absorbed)
	assert(not is_instance_valid(wave))

	print("Terrain feature check passed.")
	quit()


func _on_wave_absorbed(_position: Vector2) -> void:
	_wave_absorbed = true
