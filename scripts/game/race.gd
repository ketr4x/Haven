extends Control

enum RaceState {
	TITLE,
	COUNTDOWN,
	RACING,
	PAUSED,
	FINISHED,
}

@export_range(1.0, 5.0, 0.1) var countdown_duration: float = 3.0

@onready var _player_world: PlayerWorld = $PlayerWorld
@onready var _seed_label: Label = $GlobalUi/Seed
@onready var _timer_label: Label = $GlobalUi/Timer
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
var _finish_time: float = -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player_world.player_finished.connect(_on_player_finished)
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
		_update_timer_label()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return

	if _race_state in [RaceState.RACING, RaceState.PAUSED, RaceState.FINISHED]:
		if event.is_action_pressed(&"restart_seed"):
			_restart_course()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(&"next_seed"):
			_generate_new_course()
			get_viewport().set_input_as_handled()
			return

	if _race_state == RaceState.TITLE and _is_start_input(event):
		_start_countdown()
		get_viewport().set_input_as_handled()


func _generate_race(seed: int) -> void:
	_seed = seed
	_race_elapsed = 0.0
	_finish_time = -1.0
	_seed_label.text = "SEED  %d" % _seed
	_winner_label.text = "META!"
	_times_label.text = ""
	_finish_status_label.text = ""
	_finish_status_label.visible = false
	_update_timer_label()
	_player_world.generate_course(_seed)


func _restart_course() -> void:
	get_tree().paused = false
	_generate_race(_seed)
	_set_race_state(RaceState.TITLE)


func _generate_new_course() -> void:
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
	_player_world.set_race_active(next_state == RaceState.RACING)
	if previous_state == RaceState.COUNTDOWN and next_state == RaceState.RACING:
		_player_world.emit_intro_pulse()


func _is_start_input(event: InputEvent) -> bool:
	return event.is_action_pressed(&"move_left") \
		or event.is_action_pressed(&"move_right") \
		or event.is_action_pressed(&"jump") \
		or event.is_action_pressed(&"fire_wave")


func _on_player_finished(_player_number: int) -> void:
	if _race_state != RaceState.RACING or _finish_time >= 0.0:
		return
	_finish_time = _race_elapsed
	_player_world.set_race_active(false)
	_finish_status_label.visible = false
	_winner_label.text = "META!"
	_times_label.text = "TWÓJ CZAS  %s" % _format_time(_finish_time)
	_set_race_state(RaceState.FINISHED)


func _update_timer_label() -> void:
	var displayed_time := _finish_time if _finish_time >= 0.0 else _race_elapsed
	_timer_label.text = "CZAS  %s" % _format_time(displayed_time)


func _format_time(seconds: float) -> String:
	var total_milliseconds := roundi(seconds * 1000.0)
	var minutes := floori(float(total_milliseconds) / 60_000.0)
	var seconds_component := floori(float(total_milliseconds) / 1_000.0) % 60
	var milliseconds := total_milliseconds % 1_000
	return "%02d:%02d.%03d" % [minutes, seconds_component, milliseconds]
