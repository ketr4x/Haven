extends Node2D

@onready var _course_generator: CourseGenerator = $CourseGenerator
@onready var _player: RezonansPlayer = $PlayerOne
@onready var _seed_label: Label = $Interface/Seed
@onready var _signature_label: Label = $Interface/Signature

func _ready() -> void:
	_course_generator.course_generated.connect(_on_course_generated)
	_course_generator.generate_course()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		_course_generator.generate_course()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"new_seed"):
		_course_generator.generate_course(_course_generator.seed_value + 1)
		get_viewport().set_input_as_handled()


func _on_course_generated(seed: int, signature: String) -> void:
	_player.global_position = _course_generator.player_spawn
	_player.velocity = Vector2.ZERO
	_seed_label.text = "Seed: %d   R repeats this course   N makes a new course" % seed
	_signature_label.text = signature
