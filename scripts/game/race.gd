extends Control

signal countdown_started
signal transition_finished

enum RaceState {
	TITLE,
	STARTING,
	COUNTDOWN,
	RACING,
	PAUSED,
	FINISHED,
}

@export_range(1.0, 5.0, 0.1) var countdown_duration: float = 3.0
@export_range(0.1, 2.0, 0.05) var pixel_transition_half_duration: float = 0.45

@onready var _player_one_world: PlayerWorld = $Presentation/SplitScreen/TopContainer/TopViewport/PlayerOneWorld
@onready var _player_two_world: PlayerWorld = $Presentation/SplitScreen/BottomContainer/BottomViewport/PlayerTwoWorld
@onready var _seed_label: Label = $GlobalUi/Seed
@onready var _player_one_timer_label: Label = $GlobalUi/PlayerOneTimer
@onready var _player_two_timer_label: Label = $GlobalUi/PlayerTwoTimer
@onready var _finish_status_label: Label = $GlobalUi/FinishStatus
@onready var _winner_label: Label = $GlobalUi/ResultPanel/Winner
@onready var _times_label: Label = $GlobalUi/ResultPanel/Times
@onready var _title_panel: MainMenu = $GlobalUi/TitlePanel
@onready var _countdown_label: Label = $GlobalUi/Countdown
@onready var _pause_panel: Control = $GlobalUi/PausePanel
@onready var _result_panel: Control = $GlobalUi/ResultPanel
@onready var _palette_post_process: CanvasLayer = $Luap40PostProcess
@onready var _transition_rect: ColorRect = $TransitionLayer/TransitionRect

var _seed: int = 0
var _seed_random: RandomNumberGenerator = RandomNumberGenerator.new()
var _race_state: RaceState = RaceState.TITLE
var _countdown_remaining: float = 0.0
var _race_elapsed: float = 0.0
var _player_finish_times: Dictionary = {}
var _transition_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player_one_world.player_finished.connect(_on_player_finished)
	_player_two_world.player_finished.connect(_on_player_finished)
	_title_panel.start_requested.connect(_begin_match_start)
	_title_panel.quit_requested.connect(_on_title_panel_quit_requested)
	_title_panel.outro_finished.connect(_on_title_panel_outro_finished)
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

	if _race_state == RaceState.TITLE:
		if _title_panel.handle_menu_input(event):
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
	_cancel_transition()
	get_tree().paused = false
	_generate_race(_next_random_seed())
	_set_race_state(RaceState.TITLE)


func _next_random_seed() -> int:
	var next_seed := _seed_random.randi_range(1, 2_147_483_647)
	while next_seed == _seed:
		next_seed = _seed_random.randi_range(1, 2_147_483_647)
	return next_seed


func _begin_match_start() -> void:
	if _race_state != RaceState.TITLE:
		return
	_set_race_state(RaceState.STARTING)
	_title_panel.play_outro()


func _on_title_panel_outro_finished() -> void:
	if _race_state == RaceState.STARTING:
		_play_pixel_transition_to_countdown()


func _on_title_panel_quit_requested() -> void:
	get_tree().quit()


func _play_pixel_transition_to_countdown() -> void:
	_cancel_transition()
	_transition_rect.visible = true
	_set_transition_progress(0.0)
	_transition_tween = create_tween()
	_transition_tween.tween_method(
		_set_transition_progress,
		0.0,
		1.0,
		pixel_transition_half_duration,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_transition_tween.tween_callback(_on_transition_midpoint)
	_transition_tween.tween_interval(0.08)
	_transition_tween.tween_method(
		_set_transition_progress,
		1.0,
		0.0,
		pixel_transition_half_duration,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_callback(_on_transition_completed)


func _on_transition_midpoint() -> void:
	if _race_state == RaceState.STARTING:
		_start_countdown()
		countdown_started.emit()


func _on_transition_completed() -> void:
	_transition_rect.visible = false
	_transition_tween = null
	transition_finished.emit()


func _cancel_transition() -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null
	_set_transition_progress(0.0)
	_transition_rect.visible = false


func _set_transition_progress(value: float) -> void:
	var transition_material := _transition_rect.material as ShaderMaterial
	if transition_material != null:
		transition_material.set_shader_parameter(&"progress", value)


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
	_title_panel.visible = next_state == RaceState.TITLE or next_state == RaceState.STARTING
	if next_state == RaceState.TITLE:
		_title_panel.reset_to_idle()
	_palette_post_process.visible = next_state != RaceState.TITLE and next_state != RaceState.STARTING
	_countdown_label.visible = next_state == RaceState.COUNTDOWN
	_pause_panel.visible = next_state == RaceState.PAUSED
	_result_panel.visible = next_state == RaceState.FINISHED

	var is_racing := next_state == RaceState.RACING
	_player_one_world.set_race_active(is_racing and not _player_finish_times.has(1))
	_player_two_world.set_race_active(is_racing and not _player_finish_times.has(2))
	if previous_state == RaceState.COUNTDOWN and next_state == RaceState.RACING:
		_player_one_world.emit_intro_pulse()
		_player_two_world.emit_intro_pulse()


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
