extends Control

enum RaceState {
	TITLE,
	COUNTDOWN,
	RACING,
	PAUSED,
	FINISHED,
}

@export_range(1.0, 5.0, 0.1) var countdown_duration: float = 3.0

@onready var _player_one_world: PlayerWorld = $Presentation/SplitScreen/TopContainer/TopViewport/PlayerOneWorld
@onready var _player_two_world: PlayerWorld = $Presentation/SplitScreen/BottomContainer/BottomViewport/PlayerTwoWorld
@onready var _seed_label: Label = $GlobalUi/Seed
@onready var _player_one_timer_label: Label = $GlobalUi/PlayerOneTimer
@onready var _player_two_timer_label: Label = $GlobalUi/PlayerTwoTimer
@onready var _finish_status_label: Label = $GlobalUi/FinishStatus
@onready var _winner_label: Label = $GlobalUi/ResultPanel/Winner
@onready var _times_label: Label = $GlobalUi/ResultPanel/Times
@onready var _title_panel: Control = $GlobalUi/TitlePanel
@onready var _countdown_label: Label = $GlobalUi/Countdown
@onready var _pause_panel: Control = $GlobalUi/PausePanel
@onready var _result_panel: Control = $GlobalUi/ResultPanel

var _seed: int = 0
var _seed_random: RandomNumberGenerator = RandomNumberGenerator.new()
var _race_state: RaceState = RaceState.TITLE
var _countdown_remaining: float = 0.0
var _race_elapsed: float = 0.0
var _player_finish_times: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player_one_world.player_finished.connect(_on_player_finished)
	_player_two_world.player_finished.connect(_on_player_finished)
	_seed_random.randomize()
	_generate_race(_next_random_seed())
	_set_race_state(RaceState.TITLE)


func _process(delta: float) -> void:
	if _race_state == RaceState.COUNTDOWN:
		_countdown_remaining = maxf(0.0, _countdown_remaining - delta)
		_countdown_label.text = str(maxi(1, ceili(_countdown_remaining)))
		if is_zero_approx(_countdown_remaining):
			_set_race_state(RaceState.RACING)
		return

	if _race_state == RaceState.RACING:
		_race_elapsed += delta
		_update_timer_labels()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return

	if _race_state in [RaceState.RACING, RaceState.PAUSED, RaceState.FINISHED]:
		if event.is_action_pressed(&"restart"):
			_restart_course()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(&"new_seed"):
			_restart_course()
			get_viewport().set_input_as_handled()
			return

	if _race_state == RaceState.TITLE and _is_start_input(event):
		_start_countdown()
		get_viewport().set_input_as_handled()
		return


func _generate_race(seed: int) -> void:
	_seed = seed
	_race_elapsed = 0.0
	_player_finish_times.clear()
	_seed_label.text = ""
	_winner_label.text = ""
	_times_label.text = ""
	_finish_status_label.text = ""
	_finish_status_label.visible = false
	_update_timer_labels()
	_player_one_world.generate_course(_seed)
	_player_two_world.generate_course(_seed)


func _restart_course() -> void:
	get_tree().paused = false
	_generate_race(_next_random_seed())
	_set_race_state(RaceState.TITLE)


func _next_random_seed() -> int:
	var next_seed := _seed_random.randi_range(1, 2_147_483_647)
	while next_seed == _seed:
		next_seed = _seed_random.randi_range(1, 2_147_483_647)
	return next_seed


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
	var previous_state := _race_state
	_race_state = next_state
	_title_panel.visible = next_state == RaceState.TITLE
	_countdown_label.visible = next_state == RaceState.COUNTDOWN
	_pause_panel.visible = next_state == RaceState.PAUSED
	_result_panel.visible = next_state == RaceState.FINISHED

	var is_racing := next_state == RaceState.RACING
	_player_one_world.set_race_active(is_racing and not _player_finish_times.has(1))
	_player_two_world.set_race_active(is_racing and not _player_finish_times.has(2))
	if previous_state == RaceState.COUNTDOWN and next_state == RaceState.RACING:
		_player_one_world.emit_intro_pulse()
		_player_two_world.emit_intro_pulse()


func _is_start_input(event: InputEvent) -> bool:
	return event.is_action_pressed(&"p1_left") \
		or event.is_action_pressed(&"p1_right") \
		or event.is_action_pressed(&"p1_jump") \
		or event.is_action_pressed(&"p1_shout") \
		or event.is_action_pressed(&"p1_big_scream_minus") \
		or event.is_action_pressed(&"p1_big_scream_plus") \
		or event.is_action_pressed(&"p2_left") \
		or event.is_action_pressed(&"p2_right") \
		or event.is_action_pressed(&"p2_jump") \
		or event.is_action_pressed(&"p2_shout") \
		or event.is_action_pressed(&"p2_big_scream_minus") \
		or event.is_action_pressed(&"p2_big_scream_plus")


func _on_player_finished(player_number: int) -> void:
	if _race_state != RaceState.RACING or _player_finish_times.has(player_number):
		return

	_player_finish_times[player_number] = _race_elapsed
	_get_player_world(player_number).set_race_active(false)
	_update_timer_labels()
	if _player_finish_times.size() < 2:
		_finish_status_label.text = "GRACZ %d NA MECIE. DRUGI GRACZ JEDZIE DALEJ." % player_number
		_finish_status_label.visible = true
		return

	_finish_status_label.visible = false
	var winner_number := _winner_number()
	_winner_label.text = "WYGRYWA GRACZ %d" % winner_number
	_times_label.text = "GRACZ 1  %s\nGRACZ 2  %s" % [
		_format_time(float(_player_finish_times[1])),
		_format_time(float(_player_finish_times[2])),
	]
	_set_race_state(RaceState.FINISHED)


func _get_player_world(player_number: int) -> PlayerWorld:
	return _player_one_world if player_number == 1 else _player_two_world


func _winner_number() -> int:
	return 1 if float(_player_finish_times[1]) <= float(_player_finish_times[2]) else 2


func _update_timer_labels() -> void:
	_player_one_timer_label.text = "CZAS  %s" % _format_time(_time_for_player(1))
	_player_two_timer_label.text = "CZAS  %s" % _format_time(_time_for_player(2))


func _time_for_player(player_number: int) -> float:
	return float(_player_finish_times.get(player_number, _race_elapsed))


func _format_time(seconds: float) -> String:
	var total_milliseconds := roundi(seconds * 1000.0)
	var minutes := floori(float(total_milliseconds) / 60_000.0)
	var seconds_component := floori(float(total_milliseconds) / 1_000.0) % 60
	var milliseconds := total_milliseconds % 1_000
	return "%02d:%02d.%03d" % [minutes, seconds_component, milliseconds]
