extends Control

@onready var _course_generator: CourseGenerator = $SharedSimulation/CourseGenerator
@onready var _player_one: RezonansPlayer = $SharedSimulation/PlayerOne
@onready var _player_two: RezonansPlayer = $SharedSimulation/PlayerTwo
@onready var _finish_area: FinishArea = $SharedSimulation/FinishArea
@onready var _top_viewport: SubViewport = $SplitScreen/TopContainer/TopViewport
@onready var _bottom_viewport: SubViewport = $SplitScreen/BottomContainer/BottomViewport
@onready var _seed_label: Label = $GlobalUi/Seed
@onready var _winner_label: Label = $GlobalUi/Winner

var _race_finished: bool = false

func _ready() -> void:
	var shared_world := get_viewport().world_2d
	_top_viewport.world_2d = shared_world
	_bottom_viewport.world_2d = shared_world
	_assign_cameras()

	_course_generator.course_generated.connect(_on_course_generated)
	_finish_area.player_finished.connect(_on_player_finished)
	_course_generator.generate_course()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		_course_generator.generate_course()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"new_seed"):
		_course_generator.generate_course(_course_generator.seed_value + 1)
		get_viewport().set_input_as_handled()


func _assign_cameras() -> void:
	var player_one_camera := _player_one.get_node("Camera2D") as Camera2D
	var player_two_camera := _player_two.get_node("Camera2D") as Camera2D
	player_one_camera.custom_viewport = _top_viewport
	player_two_camera.custom_viewport = _bottom_viewport
	player_one_camera.make_current()
	player_two_camera.make_current()


func _on_course_generated(seed: int, _signature: String) -> void:
	var spawn_position := _course_generator.global_position + _course_generator.player_spawn
	_player_one.global_position = spawn_position + Vector2(-18, 0)
	_player_two.global_position = spawn_position + Vector2(18, 0)
	_player_one.velocity = Vector2.ZERO
	_player_two.velocity = Vector2.ZERO
	_finish_area.global_position = _course_generator.global_position + _course_generator.finish_position
	_finish_area.monitoring = true
	_race_finished = false
	_seed_label.text = "Course %d   R: rematch   N: new course" % seed
	_winner_label.text = ""


func _on_player_finished(player: RezonansPlayer) -> void:
	if _race_finished:
		return

	_race_finished = true
	_finish_area.set_deferred("monitoring", false)
	var winner_name := "PLAYER 1" if player == _player_one else "PLAYER 2"
	_winner_label.text = "%s WINS!  R: REMATCH  ·  N: NEW COURSE" % winner_name
