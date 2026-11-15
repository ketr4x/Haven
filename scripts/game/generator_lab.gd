extends Node2D

@onready var _course_generator: CourseGenerator = $CourseGenerator
@onready var _player: RezonansPlayer = $PlayerOne
@onready var _seed_label: Label = $Interface/Seed
@onready var _signature_label: Label = $Interface/Signature

var _seed_random: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_seed_random.randomize()
	_course_generator.course_generated.connect(_on_course_generated)
	_course_generator.generate_course(_next_random_seed())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart_seed") or event.is_action_pressed(&"next_seed"):
		_course_generator.generate_course(_next_random_seed())
		get_viewport().set_input_as_handled()


func _next_random_seed() -> int:
	var next_seed := _seed_random.randi_range(1, 2_147_483_647)
	while next_seed == _course_generator.seed_value:
		next_seed = _seed_random.randi_range(1, 2_147_483_647)
	return next_seed


func _on_course_generated(seed: int, signature: String) -> void:
	_player.global_position = _course_generator.player_spawn
	_player.velocity = Vector2.ZERO
	_seed_label.text = "Ziarno: %d   R / N losują nową trasę" % seed
	_signature_label.text = signature
