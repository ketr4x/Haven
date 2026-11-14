extends Control

enum RaceState {
	TITLE,
	COUNTDOWN,
	RACING,
	PAUSED,
	FINISHED,
}

@export var initial_seed: int = 12_345
@export_range(1.0, 5.0, 0.1) var countdown_duration: float = 3.0

@onready var _player_one_world: PlayerWorld = $Presentation/SplitScreen/TopContainer/TopViewport/PlayerOneWorld
@onready var _player_two_world: PlayerWorld = $Presentation/SplitScreen/BottomContainer/BottomViewport/PlayerTwoWorld
@onready var _seed_label: Label = $GlobalUi/Seed
@onready var _winner_label: Label = $GlobalUi/ResultPanel/Winner
@onready var _title_panel: Control = $GlobalUi/TitlePanel
@onready var _countdown_label: Label = $GlobalUi/Countdown
@onready var _pause_panel: Control = $GlobalUi/PausePanel
@onready var _result_panel: Control = $GlobalUi/ResultPanel

var _seed: int = 0
var _race_state: RaceState = RaceState.TITLE
var _countdown_remaining: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player_one_world.player_finished.connect(_on_player_finished)
	_player_two_world.player_finished.connect(_on_player_finished)
	_seed = initial_seed
	_generate_race(_seed)
	_set_race_state(RaceState.TITLE)


func _process(delta: float) -> void:
	if _race_state != RaceState.COUNTDOWN:
		return

	_countdown_remaining = maxf(0.0, _countdown_remaining - delta)
	_countdown_label.text = str(maxi(1, ceili(_countdown_remaining)))
	if is_zero_approx(_countdown_remaining):
		_set_race_state(RaceState.RACING)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return

	if _race_state in [RaceState.RACING, RaceState.PAUSED, RaceState.FINISHED]:
		if event.is_action_pressed(&"restart"):
			_restart_course(false)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(&"new_seed"):
			_restart_course(true)
			get_viewport().set_input_as_handled()
			return

	if _race_state == RaceState.TITLE and _is_start_input(event):
		_start_countdown()
		get_viewport().set_input_as_handled()
		return


func _generate_race(seed: int) -> void:
	_seed = seed
	_seed_label.text = ""
	_winner_label.text = ""
	_player_one_world.generate_course(_seed)
	_player_two_world.generate_course(_seed)


func _restart_course(use_new_seed: bool) -> void:
	get_tree().paused = false
	var next_seed := _seed + 1 if use_new_seed else _seed
	_generate_race(next_seed)
	_set_race_state(RaceState.TITLE)


func _start_countdown() -> void:
	_countdown_remaining = countdown_duration
	_countdown_label.text = str(ceili(_countdown_remaining))
	_set_race_state(RaceState.COUNTDOWN)


func _toggle_pause() -> void:
	if _race_state == RaceState.PAUSED:
		get_tree().paused = false
		_set_race_state(RaceState.RACING)
	elif _race_state == RaceState.RACING:
		get_tree().paused = true
		_set_race_state(RaceState.PAUSED)


func _set_race_state(next_state: RaceState) -> void:
	_race_state = next_state
	_title_panel.visible = next_state == RaceState.TITLE
	_countdown_label.visible = next_state == RaceState.COUNTDOWN
	_pause_panel.visible = next_state == RaceState.PAUSED
	_result_panel.visible = next_state == RaceState.FINISHED

	var is_racing := next_state == RaceState.RACING
	_player_one_world.set_race_active(is_racing)
	_player_two_world.set_race_active(is_racing)


func _is_start_input(event: InputEvent) -> bool:
	return event.is_action_pressed(&"p1_left") \
		or event.is_action_pressed(&"p1_right") \
		or event.is_action_pressed(&"p1_jump") \
		or event.is_action_pressed(&"p1_shout") \
		or event.is_action_pressed(&"p2_left") \
		or event.is_action_pressed(&"p2_right") \
		or event.is_action_pressed(&"p2_jump") \
		or event.is_action_pressed(&"p2_shout")


func _on_player_finished(player_number: int) -> void:
	if _race_state != RaceState.RACING:
		return

	_winner_label.text = "WYGRYWA GRACZ %d" % player_number
	_set_race_state(RaceState.FINISHED)
