extends Control

@onready var _player_one_world: PlayerWorld = $Presentation/SplitScreen/TopContainer/TopViewport/PlayerOneWorld
@onready var _player_two_world: PlayerWorld = $Presentation/SplitScreen/BottomContainer/BottomViewport/PlayerTwoWorld
@onready var _seed_label: Label = $GlobalUi/Seed
@onready var _winner_label: Label = $GlobalUi/Winner

var _seed: int = 12_345
var _race_finished: bool = false

func _ready() -> void:
	_player_one_world.player_finished.connect(_on_player_finished)
	_player_two_world.player_finished.connect(_on_player_finished)
	_generate_race(_seed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		_generate_race(_seed)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"new_seed"):
		_generate_race(_seed + 1)
		get_viewport().set_input_as_handled()


func _generate_race(seed: int) -> void:
	_seed = seed
	_race_finished = false
	_winner_label.text = ""
	_seed_label.text = "Course %d   R: rematch   N: new course" % _seed
	_player_one_world.generate_course(_seed)
	_player_two_world.generate_course(_seed)


func _on_player_finished(player_number: int) -> void:
	if _race_finished:
		return
	_race_finished = true
	_winner_label.text = "PLAYER %d WINS!  R: REMATCH  ·  N: NEW COURSE" % player_number
