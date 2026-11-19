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

enum SessionMode {
	LOCAL,
	ONLINE,
}

enum MenuScreen {
	MAIN,
	ONLINE,
	FRIENDS,
	JOIN_CODE,
	WAITING,
}

@export_range(1.0, 5.0, 0.1) var countdown_duration: float = 3.0
@export_range(0.1, 2.0, 0.05) var pixel_transition_half_duration: float = 0.45

@onready var _player_one_world: PlayerWorld = $Presentation/SplitScreen/TopContainer/TopViewport/PlayerOneWorld
@onready var _player_two_world: PlayerWorld = $Presentation/SplitScreen/BottomContainer/BottomViewport/PlayerTwoWorld
@onready var _top_container: SubViewportContainer = $Presentation/SplitScreen/TopContainer
@onready var _bottom_container: SubViewportContainer = $Presentation/SplitScreen/BottomContainer
@onready var _divider: ColorRect = $Presentation/SplitScreen/Divider
@onready var _player_one_label: Label = $GlobalUi/PlayerOneLabel
@onready var _player_two_label: Label = $GlobalUi/PlayerTwoLabel
@onready var _seed_label: Label = $GlobalUi/Seed
@onready var _network_status_label: Label = $GlobalUi/NetworkStatus
@onready var _opponent_progress_label: Label = $GlobalUi/OpponentProgress
@onready var _player_one_timer_label: Label = $GlobalUi/PlayerOneTimer
@onready var _player_two_timer_label: Label = $GlobalUi/PlayerTwoTimer
@onready var _finish_status_label: Label = $GlobalUi/FinishStatus
@onready var _player_one_finish_banner: Control = $GlobalUi/PlayerOneFinishBanner
@onready var _player_two_finish_banner: Control = $GlobalUi/PlayerTwoFinishBanner
@onready var _winner_label: Label = $GlobalUi/ResultPanel/Winner
@onready var _placement_summary_label: Label = $GlobalUi/ResultPanel/PlacementSummary
@onready var _times_label: Label = $GlobalUi/ResultPanel/Times
@onready var _result_reminder: Label = $GlobalUi/ResultPanel/Reminder
@onready var _result_actions: Label = $GlobalUi/ResultPanel/Actions
@onready var _leaderboard_section: Control = $GlobalUi/ResultPanel/LeaderboardSection
@onready var _leaderboard_prompt: Label = $GlobalUi/ResultPanel/LeaderboardSection/Prompt
@onready var _username_input: LineEdit = $GlobalUi/ResultPanel/LeaderboardSection/UsernameInput
@onready var _leaderboard_status: Label = $GlobalUi/ResultPanel/LeaderboardSection/Status
@onready var _leaderboard_entries: Label = $GlobalUi/ResultPanel/LeaderboardSection/BoardPanel/BoardEntries
@onready var _title_panel: MainMenu = $GlobalUi/TitlePanel
@onready var _countdown_label: Label = $GlobalUi/Countdown
@onready var _pause_panel: Control = $GlobalUi/PausePanel
@onready var _pause_resume_option: Control = get_node_or_null("GlobalUi/PausePanel/MenuItems/ResumeOption") as Control
@onready var _pause_resume_cursor: Label = get_node_or_null("GlobalUi/PausePanel/MenuItems/ResumeOption/Cursor") as Label
@onready var _pause_resume_text: Label = get_node_or_null("GlobalUi/PausePanel/MenuItems/ResumeOption/Text") as Label
@onready var _pause_menu_option: Control = get_node_or_null("GlobalUi/PausePanel/MenuItems/MenuOption") as Control
@onready var _pause_menu_cursor: Label = get_node_or_null("GlobalUi/PausePanel/MenuItems/MenuOption/Cursor") as Label
@onready var _pause_menu_text: Label = get_node_or_null("GlobalUi/PausePanel/MenuItems/MenuOption/Text") as Label
@onready var _result_panel: Control = $GlobalUi/ResultPanel
@onready var _invert_flash_rect: ColorRect = $InvertLayer/InvertFlashRect
@onready var _transition_rect: ColorRect = $TransitionLayer/TransitionRect
@onready var _countdown_tick: AudioStreamPlayer = get_node_or_null("CountdownTick") as AudioStreamPlayer
@onready var _countdown_go: AudioStreamPlayer = get_node_or_null("CountdownGo") as AudioStreamPlayer
@onready var _match_victory: AudioStreamPlayer = get_node_or_null("MatchVictory") as AudioStreamPlayer
@onready var _ui_move: AudioStreamPlayer = get_node_or_null("UIMove") as AudioStreamPlayer
@onready var _ui_select: AudioStreamPlayer = get_node_or_null("UISelect") as AudioStreamPlayer

var _pause_selected_index: int = 0


var online_service: OnlineServiceBase

var _seed: int = 0
var _seed_random: RandomNumberGenerator = RandomNumberGenerator.new()
var _race_state: RaceState = RaceState.TITLE
var _countdown_remaining: float = 0.0
var _race_elapsed: float = 0.0
var _player_finish_times: Dictionary = {}
var _online_match: OnlineMatch
var _session_mode: SessionMode = SessionMode.LOCAL
var _menu_screen: MenuScreen = MenuScreen.MAIN
var _status_send_remaining: float = 0.0
var _transition_tween: Tween
var _invert_tween: Tween
var _pending_leaderboard_time: float = 0.0
var _leaderboard_submitted: bool = false
var _leaderboard_submitting: bool = false
var _last_username: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if online_service == null:
		online_service = get_node_or_null("/root/OnlineService") as OnlineServiceBase
	_bind_leaderboard_service_signals()
	_player_one_world.player_finished.connect(_on_player_finished)
	_player_two_world.player_finished.connect(_on_player_finished)
	_title_panel.option_selected.connect(_on_menu_option_selected)
	_title_panel.room_code_submitted.connect(_on_room_code_submitted)
	_title_panel.outro_finished.connect(_on_title_panel_outro_finished)
	if _username_input != null:
		_username_input.text_submitted.connect(_on_username_submitted)
	if _pause_resume_option != null:
		_pause_resume_option.mouse_entered.connect(_set_pause_selection.bind(0))
		_pause_resume_option.gui_input.connect(_on_pause_option_gui_input.bind(0))
	if _pause_menu_option != null:
		_pause_menu_option.mouse_entered.connect(_set_pause_selection.bind(1))
		_pause_menu_option.gui_input.connect(_on_pause_option_gui_input.bind(1))
	_online_match = OnlineMatch.new()
	add_child(_online_match)
	_online_match.room_code_ready.connect(_on_room_code_ready)
	_online_match.match_configured.connect(_on_online_match_configured)
	_online_match.countdown_started.connect(_on_online_countdown_started)
	_online_match.opponent_finished.connect(_on_online_opponent_finished)
	_online_match.match_finished.connect(_on_online_match_finished)
	_online_match.opponent_left.connect(_on_online_opponent_left)
	_online_match.opponent_named.connect(_on_online_opponent_named)
	_online_match.opponent_status_received.connect(_on_online_opponent_status_received)
	_online_match.opponent_snapshot_received.connect(_on_online_opponent_snapshot_received)
	_online_match.rematch_waiting.connect(_on_online_rematch_waiting)
	_online_match.match_failed.connect(_on_online_match_failed)
	_seed_random.randomize()
	_generate_race(_next_random_seed())
	_set_race_state(RaceState.TITLE)
	_show_menu(MenuScreen.MAIN)
	call_deferred("_start_online_match_from_command_line")


func _process(delta: float) -> void:
	if _race_state == RaceState.COUNTDOWN:
		var prev_sec := maxi(1, ceili(_countdown_remaining))
		_countdown_remaining = maxf(0.0, _countdown_remaining - delta)
		var current_sec := maxi(1, ceili(_countdown_remaining))
		_countdown_label.text = str(current_sec)
		if current_sec != prev_sec and not is_zero_approx(_countdown_remaining):
			_play_countdown_tick()
		if is_zero_approx(_countdown_remaining):
			_play_countdown_go()
			if _session_mode == SessionMode.ONLINE:
				_online_match.begin_race()
			_set_race_state(RaceState.RACING)
		return

	if _race_state == RaceState.RACING:
		_race_elapsed += delta
		if _session_mode == SessionMode.ONLINE:
			_status_send_remaining = maxf(0.0, _status_send_remaining - delta)
			if is_zero_approx(_status_send_remaining):
				_status_send_remaining = 0.05
				_online_match.submit_local_status(
					_player_one_world.progress_fraction(),
					_player_one_world.current_loudness(),
					_player_one_world.has_rebound_boost(),
					_player_one_world.player_global_position(),
					_player_one_world.player_velocity(),
					_player_one_world.player_facing_direction(),
					_player_one_world.player_is_on_floor(),
					_player_one_world.consume_pending_events(),
				)
		_update_timer_labels()


func _input(event: InputEvent) -> void:
	if _race_state == RaceState.TITLE:
		if _menu_screen == MenuScreen.JOIN_CODE:
			if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
				_show_menu(MenuScreen.FRIENDS)
				get_viewport().set_input_as_handled()
				return
			if event.is_action_pressed(&"ui_accept"):
				_submit_room_code("")
				get_viewport().set_input_as_handled()
				return
		elif _menu_screen == MenuScreen.WAITING:
			if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
				_return_to_main_menu()
				get_viewport().set_input_as_handled()
				return
		elif event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
			if _menu_screen == MenuScreen.ONLINE:
				_show_menu(MenuScreen.MAIN)
			elif _menu_screen == MenuScreen.FRIENDS:
				_show_menu(MenuScreen.ONLINE)
			get_viewport().set_input_as_handled()
			return
		elif _title_panel.handle_menu_input(event):
			get_viewport().set_input_as_handled()
			return

	if _race_state == RaceState.FINISHED:
		if _is_username_input_capturing(event):
			if event.is_action_pressed(&"ui_accept"):
				_on_username_submitted(_username_input.text)
				get_viewport().set_input_as_handled()
			return

		if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
			_return_to_main_menu()
			get_viewport().set_input_as_handled()
			return

		if _session_mode == SessionMode.ONLINE:
			if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"restart"):
				if event.is_action_pressed(&"ui_accept") and _username_input != null and _username_input.visible and not _leaderboard_submitted and not _username_input.text.strip_edges().is_empty():
					_on_username_submitted(_username_input.text)
				else:
					_online_match.request_rematch()
				get_viewport().set_input_as_handled()
				return
		else:
			if event.is_action_pressed(&"restart"):
				_start_local_rematch(false)
				get_viewport().set_input_as_handled()
				return
			if event.is_action_pressed(&"new_seed"):
				_start_local_rematch(true)
				get_viewport().set_input_as_handled()
				return
			if event.is_action_pressed(&"ui_accept"):
				if _username_input != null and _username_input.visible and not _leaderboard_submitted and not _username_input.text.strip_edges().is_empty():
					_on_username_submitted(_username_input.text)
				else:
					_start_local_rematch(false)
				get_viewport().set_input_as_handled()
				return

	if _race_state == RaceState.PAUSED:
		if event.is_action_pressed(&"pause"):
			_toggle_pause()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
			_activate_pause_menu_exit()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"p1_jump") or event.is_action_pressed(&"p2_jump"):
			_move_pause_selection(-1)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"p1_shout") or event.is_action_pressed(&"p2_shout"):
			_move_pause_selection(1)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(&"ui_accept"):
			_activate_pause_option()
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed(&"pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return

	if _session_mode == SessionMode.LOCAL and _race_state in [RaceState.RACING, RaceState.PAUSED]:
		if event.is_action_pressed(&"restart"):
			_start_local_rematch(false)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(&"new_seed"):
			_start_local_rematch(true)
			get_viewport().set_input_as_handled()
			return


func _generate_race(seed: int) -> void:
	_seed = seed
	_race_elapsed = 0.0
	_player_finish_times.clear()
	_pending_leaderboard_time = 0.0
	_leaderboard_submitted = false
	_leaderboard_submitting = false
	_seed_label.text = ""
	_winner_label.text = ""
	_placement_summary_label.text = ""
	_times_label.text = ""
	_finish_status_label.text = ""
	_finish_status_label.visible = false
	if _leaderboard_section != null:
		_leaderboard_section.visible = false
	_hide_finish_banners()
	_cancel_invert_flash()
	_update_timer_labels()
	_player_one_world.generate_course(_seed)
	_player_two_world.generate_course(_seed)


func _start_local_rematch(use_new_seed: bool = false) -> void:
	_cancel_transition()
	_cancel_invert_flash()
	get_tree().paused = false
	var next_seed := _next_random_seed() if use_new_seed else _seed
	_generate_race(next_seed)
	_start_countdown()


func _restart_course() -> void:
	_cancel_transition()
	_cancel_invert_flash()
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


func _start_countdown(duration: float = countdown_duration) -> void:
	_countdown_remaining = duration
	_countdown_label.text = str(ceili(_countdown_remaining))
	_play_countdown_tick()
	_set_race_state(RaceState.COUNTDOWN)


func _toggle_pause() -> void:
	if _race_state == RaceState.PAUSED:
		get_tree().paused = false
		_set_race_state(RaceState.RACING)
	elif _race_state == RaceState.RACING:
		_pause_selected_index = 0
		_update_pause_visuals()
		get_tree().paused = true
		_set_race_state(RaceState.PAUSED)


func _set_pause_selection(index: int) -> void:
	if _pause_selected_index != index:
		_pause_selected_index = index
		_play_ui_move()
		_update_pause_visuals()


func _move_pause_selection(delta: int) -> void:
	var next_idx := (_pause_selected_index + delta) % 2
	if next_idx < 0:
		next_idx += 2
	_set_pause_selection(next_idx)


func _update_pause_visuals() -> void:
	var is_resume := _pause_selected_index == 0
	if _pause_resume_cursor != null:
		_pause_resume_cursor.text = ">" if is_resume else " "
	if _pause_resume_text != null:
		_pause_resume_text.modulate = Color(0.96, 0.96, 0.96, 1.0) if is_resume else Color(0.75, 0.75, 0.75, 0.92)
	if _pause_menu_cursor != null:
		_pause_menu_cursor.text = " " if is_resume else ">"
	if _pause_menu_text != null:
		_pause_menu_text.modulate = Color(0.75, 0.75, 0.75, 0.92) if is_resume else Color(0.96, 0.96, 0.96, 1.0)


func _activate_pause_option() -> void:
	_play_ui_select()
	if _pause_selected_index == 0:
		_toggle_pause()
	else:
		_return_to_main_menu()


func _activate_pause_menu_exit() -> void:
	_play_ui_select()
	_return_to_main_menu()


func _on_pause_option_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pause_selected_index = index
		_activate_pause_option()


func _play_ui_move() -> void:
	if _ui_move != null:
		_ui_move.play()


func _play_ui_select() -> void:
	if _ui_select != null:
		_ui_select.play()


func _set_race_state(next_state: RaceState) -> void:
	var previous_state := _race_state
	_race_state = next_state
	_title_panel.visible = next_state == RaceState.TITLE or next_state == RaceState.STARTING
	if next_state == RaceState.TITLE:
		_show_menu(MenuScreen.MAIN)
	_countdown_label.visible = next_state == RaceState.COUNTDOWN
	_pause_panel.visible = next_state == RaceState.PAUSED
	_result_panel.visible = next_state == RaceState.FINISHED
	if next_state == RaceState.FINISHED:
		_play_match_victory()

	var is_racing := next_state == RaceState.RACING
	if _session_mode == SessionMode.ONLINE:
		var opponent_slot := 2 if _online_match.player_slot == 1 else 1
		_player_one_world.set_race_active(is_racing and not _player_finish_times.has(_online_match.player_slot))
		_player_two_world.set_race_active(is_racing and not _player_finish_times.has(opponent_slot))
	else:
		_player_one_world.set_race_active(is_racing and not _player_finish_times.has(1))
		_player_two_world.set_race_active(is_racing and not _player_finish_times.has(2))
	if previous_state == RaceState.COUNTDOWN and next_state == RaceState.RACING:
		_player_one_world.emit_intro_pulse()
		_player_two_world.emit_intro_pulse()


func _on_player_finished(player_number: int) -> void:
	if _race_state != RaceState.RACING or _player_finish_times.has(player_number):
		return

	_play_finish_invert_flash()

	if _session_mode == SessionMode.ONLINE:
		_player_finish_times[player_number] = _race_elapsed
		_player_one_world.set_race_active(false)
		_online_match.submit_local_finish(_race_elapsed)
		var place := 1 if _player_finish_times.size() == 1 else 2
		_show_player_finish_banner(1, place, _race_elapsed)
		_finish_status_label.text = "JESTEŚ NA MECIE. PRZECIWNIK JEDZIE DALEJ."
		_finish_status_label.visible = true
		_update_timer_labels()
		return

	_player_finish_times[player_number] = _race_elapsed
	_get_player_world(player_number).set_race_active(false)
	_update_timer_labels()
	var placement := 1 if _player_finish_times.size() == 1 else 2
	_show_player_finish_banner(player_number, placement, _race_elapsed)
	if _player_finish_times.size() < 2:
		_finish_status_label.text = "GRACZ %d NA MECIE. DRUGI GRACZ JEDZIE DALEJ." % player_number
		_finish_status_label.visible = true
		return

	_finish_status_label.visible = false
	_hide_finish_banners()
	var winner_number := _winner_number()
	_winner_label.text = "WYGRYWA GRACZ %d" % winner_number
	_update_placement_summary("GRACZ 1", "GRACZ 2")
	_times_label.text = "GRACZ 1  %s\nGRACZ 2  %s" % [
		_format_time(float(_player_finish_times[1])),
		_format_time(float(_player_finish_times[2])),
	]
	_prepare_leaderboard_prompt(
		float(_player_finish_times[winner_number]),
		"WPISZ NICK ZWYCIĘZCY (GRACZ %d) — %s" % [winner_number, _format_time(float(_player_finish_times[winner_number]))]
	)
	_set_race_state(RaceState.FINISHED)


func start_quick_match() -> void:
	_begin_online_session()
	if _menu_screen == MenuScreen.WAITING:
		_title_panel.show_waiting("SZUKANIE PRZECIWNIKA…", "ESC  ANULUJ")
	_online_match.queue_quick_match()


func host_friend_room(room_code: String = "") -> void:
	_begin_online_session()
	_online_match.host_friend_room(room_code)


func join_friend_room(room_code: String) -> void:
	_begin_online_session()
	_online_match.join_friend_room(room_code)


func _begin_online_session() -> void:
	_session_mode = SessionMode.ONLINE
	get_tree().paused = false
	_top_container.anchor_bottom = 0.5
	_top_container.offset_bottom = -2.0
	_bottom_container.visible = true
	_divider.visible = true
	_player_one_label.text = "TY"
	_player_two_label.text = "PRZECIWNIK"
	_player_two_label.position.y = 382.0
	_player_two_timer_label.position.y = 412.0
	_network_status_label.visible = true
	_network_status_label.text = "ŁĄCZENIE…"
	_opponent_progress_label.visible = false
	_opponent_progress_label.text = ""
	if _menu_screen != MenuScreen.WAITING:
		_title_panel.visible = false
	_finish_status_label.text = "ŁĄCZENIE Z PRZECIWNIKIEM…"
	_finish_status_label.visible = true
	_player_one_world.set_race_active(false)
	_player_two_world.set_race_active(false)


func _start_online_match_from_command_line() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--online-host":
			host_friend_room()
			return
		if argument.begins_with("--online-host="):
			host_friend_room(argument.trim_prefix("--online-host="))
			return
		if argument.begins_with("--online-join="):
			join_friend_room(argument.trim_prefix("--online-join="))
			return


func _on_room_code_ready(room_code: String) -> void:
	_seed_label.text = "KOD POKOJU  %s" % room_code
	_finish_status_label.text = "CZEKA NA DRUGIEGO GRACZA…"
	if _menu_screen == MenuScreen.WAITING:
		_title_panel.show_waiting("KOD POKOJU: %s" % room_code, "PRZEKAŻ KOD ZNAJOMEMU.  ESC  ANULUJ")


func _on_online_match_configured(player_slot: int, seed: int) -> void:
	_set_race_state(RaceState.STARTING)
	_title_panel.visible = false
	_result_panel.visible = false
	_player_one_label.text = _online_match.local_display_name
	_player_two_label.text = _online_match.opponent_display_name if not _online_match.opponent_display_name.is_empty() else "PRZECIWNIK"
	_network_status_label.text = "POŁĄCZONO"
	_player_one_world.configure_for_online_slot(player_slot)
	_player_two_world.configure_as_remote_opponent(2 if player_slot == 1 else 1)
	_status_send_remaining = 0.0
	_generate_race(seed)
	_seed_label.text = "POKÓJ  %s" % _online_match.room_code
	_finish_status_label.text = "SPRAWDZANIE TRASY…"
	_finish_status_label.visible = true
	_online_match.submit_course_signature(_player_one_world.course_signature())


func _on_online_countdown_started(duration: float) -> void:
	_finish_status_label.visible = false
	_start_countdown(duration)


func _on_online_opponent_named(display_name: String) -> void:
	_player_two_label.text = display_name


func _on_online_opponent_status_received(_progress: float, _loudness: float, _boost_active: bool) -> void:
	pass


func _on_online_rematch_waiting() -> void:
	_winner_label.text = "CZEKA NA REWANŻ"
	if _online_match != null and _online_match.has_local_rematch_vote():
		_result_reminder.text = "DRUGI GRACZ MUSI POTWIERDZIĆ."
	else:
		_result_reminder.text = "PRZECIWNIK CHCE REWANŻU. WCIŚNIJ ENTER / R."


func _on_online_opponent_finished(player_slot: int, elapsed: float) -> void:
	_player_finish_times[player_slot] = elapsed
	_player_two_world.set_race_active(false)
	var place := 1 if _player_finish_times.size() == 1 else 2
	_show_player_finish_banner(2, place, elapsed)
	_finish_status_label.text = "PRZECIWNIK JEST NA MECIE. JEDŹ DALEJ."
	_finish_status_label.visible = true
	_update_timer_labels()


func _on_online_opponent_snapshot_received(pos: Vector2, vel: Vector2, facing: float, on_floor: bool, loudness: float, boost_active: bool, events: Array) -> void:
	if _session_mode == SessionMode.ONLINE and _player_two_world != null:
		_player_two_world.apply_remote_snapshot(pos, vel, facing, on_floor, loudness, boost_active, events)


func _on_online_match_finished(finish_times: Dictionary, winner_slot: int) -> void:
	_player_finish_times = finish_times.duplicate(true)
	_finish_status_label.visible = false
	_hide_finish_banners()
	_winner_label.text = "WYGRYWASZ" if winner_slot == _online_match.player_slot else "WYGRYWA PRZECIWNIK"
	var p1_label := _online_match.local_display_name if _online_match.player_slot == 1 else (_online_match.opponent_display_name if not _online_match.opponent_display_name.is_empty() else "PRZECIWNIK")
	var p2_label := _online_match.local_display_name if _online_match.player_slot == 2 else (_online_match.opponent_display_name if not _online_match.opponent_display_name.is_empty() else "PRZECIWNIK")
	_update_placement_summary(p1_label, p2_label)
	_result_actions.text = "ENTER  REWANŻ        ESC  MENU"
	_result_reminder.text = "WYNIK MECZU ONLINE"
	_times_label.text = "GRACZ 1  %s\nGRACZ 2  %s" % [
		_format_time(float(_player_finish_times[1])),
		_format_time(float(_player_finish_times[2])),
	]
	var local_slot := _online_match.player_slot if _online_match.player_slot in [1, 2] else 1
	var local_time := float(_player_finish_times.get(local_slot, _player_finish_times.get(1, 0.0)))
	_prepare_leaderboard_prompt(
		local_time,
		"WPISZ NICK DO RANKINGU — TWÓJ CZAS %s" % _format_time(local_time)
	)
	_set_race_state(RaceState.FINISHED)


func _on_online_opponent_left(_client_id: int) -> void:
	_finish_status_label.visible = false
	_hide_finish_banners()
	_placement_summary_label.text = ""
	_winner_label.text = "PRZECIWNIK OPUŚCIŁ MECZ"
	_times_label.text = ""
	_result_actions.text = "ESC  MENU"
	_result_reminder.text = "MECZ ONLINE ZAKOŃCZONY"
	if _leaderboard_section != null:
		_leaderboard_section.visible = false
	_set_race_state(RaceState.FINISHED)


func _on_online_match_failed(reason: String) -> void:
	_finish_status_label.visible = false
	_hide_finish_banners()
	_placement_summary_label.text = ""
	_winner_label.text = "NIE UDAŁO SIĘ ROZPOCZĄĆ MECZU"
	_times_label.text = reason
	_result_actions.text = "ESC  MENU"
	_result_reminder.text = "SPRAWDŹ POŁĄCZENIE I KOD POKOJU"
	if _leaderboard_section != null:
		_leaderboard_section.visible = false
	_set_race_state(RaceState.FINISHED)


func _show_menu(next_screen: MenuScreen) -> void:
	_menu_screen = next_screen
	_title_panel.visible = true
	match next_screen:
		MenuScreen.MAIN:
			_title_panel.reset_to_idle()
			_title_panel.show_options(
				["GRAJ", "GRA ONLINE", "WYJDŹ"],
				"STRZAŁKI / W S  WYBÓR      ENTER / SPACJA  ZATWIERDŹ",
				"WYŚCIG ECHA",
			)
		MenuScreen.ONLINE:
			_title_panel.show_options(
				["SZYBKI MECZ", "ZE ZNAJOMYM"],
				"WYBIERZ TRYB ONLINE      ESC  POWRÓT",
				"POŁĄCZENIE ZNAJDZIE LUB UTWORZY POKÓJ.",
			)
		MenuScreen.FRIENDS:
			_title_panel.show_options(
				["STWÓRZ POKÓJ", "DOŁĄCZ KODEM"],
				"WYBIERZ OPCJĘ      ESC  POWRÓT",
				"PRYWATNY WYŚCIG DLA DWÓCH GRACZY.",
			)
		MenuScreen.JOIN_CODE:
			_title_panel.show_room_code_entry("DOŁĄCZ DO POKOJU", "WPISZ KOD I NACIŚNIJ ENTER.  ESC  POWRÓT")
		MenuScreen.WAITING:
			_title_panel.show_waiting("ŁĄCZENIE…", "ESC  ANULUJ")


func _on_menu_option_selected(index: int) -> void:
	match _menu_screen:
		MenuScreen.MAIN:
			if index == 0:
				_begin_match_start()
			elif index == 1:
				_show_menu(MenuScreen.ONLINE)
			else:
				get_tree().quit()
		MenuScreen.ONLINE:
			if index == 0:
				_show_menu(MenuScreen.WAITING)
				start_quick_match()
			else:
				_show_menu(MenuScreen.FRIENDS)
		MenuScreen.FRIENDS:
			_show_menu(MenuScreen.WAITING)
			if index == 0:
				host_friend_room()
			else:
				_show_menu(MenuScreen.JOIN_CODE)


func _on_room_code_submitted(room_code: String) -> void:
	if _menu_screen == MenuScreen.JOIN_CODE:
		_submit_room_code(room_code)


func _submit_room_code(room_code: String) -> void:
	var normalized_code := room_code.strip_edges().to_upper()
	if normalized_code.is_empty():
		_title_panel.show_room_code_entry("DOŁĄCZ DO POKOJU", "WPISZ KOD OTRZYMANY OD GOSPODARZA.")
		return
	_show_menu(MenuScreen.WAITING)
	join_friend_room(normalized_code)


func _return_to_main_menu() -> void:
	get_tree().paused = false
	_cancel_transition()
	_cancel_invert_flash()
	_online_match.leave_match()
	_session_mode = SessionMode.LOCAL
	_top_container.anchor_bottom = 0.5
	_top_container.offset_bottom = -2.0
	_bottom_container.visible = true
	_divider.visible = true
	_player_one_world.configure_for_local_slot(1)
	_player_two_world.configure_for_local_slot(2)
	_player_one_label.text = "GRACZ 1"
	_player_two_label.text = "GRACZ 2"
	_player_two_label.position.y = 382.0
	_player_two_timer_label.position.y = 412.0
	_network_status_label.visible = false
	_opponent_progress_label.visible = false
	_result_actions.text = "R  REWANŻ        N  NOWA TRASA        ESC  MENU"
	_result_reminder.text = "ZŁAP ODBITĄ FALĘ, ABY PRZYSPIESZYĆ"
	_generate_race(_next_random_seed())
	_set_race_state(RaceState.TITLE)
	_show_menu(MenuScreen.MAIN)


func _get_player_world(player_number: int) -> PlayerWorld:
	return _player_one_world if player_number == 1 else _player_two_world


func _winner_number() -> int:
	return 1 if float(_player_finish_times[1]) <= float(_player_finish_times[2]) else 2


func _play_finish_invert_flash() -> void:
	if _invert_flash_rect == null:
		return
	_cancel_invert_flash()
	_invert_flash_rect.visible = true
	_set_invert_intensity(1.0)
	_invert_tween = create_tween()
	_invert_tween.tween_interval(0.075)
	_invert_tween.tween_method(_set_invert_intensity, 1.0, 0.0, 0.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_invert_tween.tween_callback(func() -> void:
		_invert_flash_rect.visible = false
		_invert_tween = null
	)


func _cancel_invert_flash() -> void:
	if _invert_tween != null and _invert_tween.is_valid():
		_invert_tween.kill()
	_invert_tween = null
	_set_invert_intensity(0.0)
	if _invert_flash_rect != null:
		_invert_flash_rect.visible = false


func _play_countdown_tick() -> void:
	if _countdown_tick != null:
		_countdown_tick.play()


func _play_countdown_go() -> void:
	if _countdown_go != null:
		_countdown_go.play()


func _play_match_victory() -> void:
	if _match_victory != null:
		_match_victory.play()



func _set_invert_intensity(value: float) -> void:
	if _invert_flash_rect == null:
		return
	var mat := _invert_flash_rect.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter(&"intensity", value)


func _show_player_finish_banner(viewport_slot: int, place: int, elapsed: float) -> void:
	var banner := _player_one_finish_banner if viewport_slot == 1 else _player_two_finish_banner
	if banner == null:
		return
	var place_label := banner.get_node_or_null("Place") as Label
	var time_label := banner.get_node_or_null("Time") as Label
	var border := banner.get_node_or_null("Border") as ReferenceRect
	var accent := Color(0.941176, 0.921569, 0.752941, 1.0) if place == 1 else Color(0.760784, 0.94902, 0.94902, 1.0)
	if place_label != null:
		place_label.text = "%d. MIEJSCE" % place
		place_label.add_theme_color_override(&"font_color", accent)
	if time_label != null:
		time_label.text = "CZAS  %s" % _format_time(elapsed)
	if border != null:
		border.border_color = accent
	banner.visible = true
	banner.pivot_offset = banner.size * 0.5
	banner.scale = Vector2(0.86, 0.86)
	banner.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := banner.create_tween()
	tween.set_parallel(true)
	tween.tween_property(banner, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(banner, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _hide_finish_banners() -> void:
	if _player_one_finish_banner != null:
		_player_one_finish_banner.visible = false
	if _player_two_finish_banner != null:
		_player_two_finish_banner.visible = false


func _update_placement_summary(p1_name: String, p2_name: String) -> void:
	if _placement_summary_label == null:
		return
	if not _player_finish_times.has(1) or not _player_finish_times.has(2):
		_placement_summary_label.text = ""
		return
	var t1 := float(_player_finish_times[1])
	var t2 := float(_player_finish_times[2])
	if t1 <= t2:
		_placement_summary_label.text = "1. MIEJSCE   %s   —   %s\n2. MIEJSCE   %s   —   %s" % [
			p1_name, _format_time(t1), p2_name, _format_time(t2)
		]
	else:
		_placement_summary_label.text = "1. MIEJSCE   %s   —   %s\n2. MIEJSCE   %s   —   %s" % [
			p2_name, _format_time(t2), p1_name, _format_time(t1)
		]


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


func set_leaderboard_service(service: OnlineServiceBase) -> void:
	online_service = service
	_bind_leaderboard_service_signals()


func _bind_leaderboard_service_signals() -> void:
	if online_service == null:
		return
	if not online_service.leaderboard_score_submitted.is_connected(_on_leaderboard_score_submitted):
		online_service.leaderboard_score_submitted.connect(_on_leaderboard_score_submitted)
	if not online_service.leaderboard_submission_failed.is_connected(_on_leaderboard_submission_failed):
		online_service.leaderboard_submission_failed.connect(_on_leaderboard_submission_failed)
	if not online_service.leaderboard_scores_loaded.is_connected(_on_leaderboard_scores_loaded):
		online_service.leaderboard_scores_loaded.connect(_on_leaderboard_scores_loaded)
	if not online_service.leaderboard_load_failed.is_connected(_on_leaderboard_load_failed):
		online_service.leaderboard_load_failed.connect(_on_leaderboard_load_failed)


func _prepare_leaderboard_prompt(elapsed_seconds: float, prompt_text: String) -> void:
	_pending_leaderboard_time = elapsed_seconds
	_leaderboard_submitted = false
	_leaderboard_submitting = false
	if _leaderboard_section == null:
		return
	_leaderboard_section.visible = true
	if _leaderboard_prompt != null:
		_leaderboard_prompt.text = prompt_text
	if _leaderboard_status != null:
		_leaderboard_status.text = "ENTER  ZAPISZ CZAS DO GLOBALNEGO RANKINGU"
		_leaderboard_status.add_theme_color_override(&"font_color", Color(0.760784, 0.94902, 0.94902, 1.0))
	if _username_input != null:
		_username_input.visible = true
		_username_input.editable = true
		_username_input.text = _last_username
		_username_input.grab_focus()
		_username_input.caret_column = _username_input.text.length()
	if _leaderboard_entries != null:
		_leaderboard_entries.text = "WCZYTYWANIE RANKINGU…"
	if online_service != null:
		online_service.browse_leaderboard_times()


func _on_username_submitted(username_text: String) -> void:
	if _leaderboard_submitted or _leaderboard_submitting or _pending_leaderboard_time <= 0.0:
		return
	var trimmed := username_text.strip_edges()
	if trimmed.is_empty():
		if _leaderboard_status != null:
			_leaderboard_status.text = "WPISZ NAZWĘ GRACZA PRZED ZATWIERDZENIEM."
			_leaderboard_status.add_theme_color_override(&"font_color", Color(0.95, 0.45, 0.45, 1.0))
		return
	_last_username = trimmed
	_leaderboard_submitting = true
	if _username_input != null:
		_username_input.editable = false
	if _leaderboard_status != null:
		_leaderboard_status.text = "ZAPISYWANIE CZASU W GD-SYNC…"
		_leaderboard_status.add_theme_color_override(&"font_color", Color(0.941176, 0.921569, 0.752941, 1.0))
	if online_service == null:
		online_service = get_node_or_null("/root/OnlineService") as OnlineServiceBase
		_bind_leaderboard_service_signals()
	if online_service == null:
		_on_leaderboard_submission_failed(OnlineServiceBase.DEFAULT_LEADERBOARD_NAME, "BRAK USŁUGI ONLINE.")
		return
	online_service.submit_leaderboard_time(
		trimmed,
		_pending_leaderboard_time,
		OnlineServiceBase.DEFAULT_LEADERBOARD_NAME,
		{
			"mode": "online" if _session_mode == SessionMode.ONLINE else "offline",
			"seed": _seed,
		}
	)


func _on_leaderboard_score_submitted(_leaderboard_name: String, username: String, score_ms: int) -> void:
	_leaderboard_submitting = false
	_leaderboard_submitted = true
	if _username_input != null:
		_username_input.editable = false
		_username_input.release_focus()
	if _leaderboard_status != null:
		_leaderboard_status.text = "ZAPISANO: %s — %s" % [username, _format_time(float(score_ms) / 1000.0)]
		_leaderboard_status.add_theme_color_override(&"font_color", Color(0.6, 0.98, 0.65, 1.0))
	if online_service != null:
		online_service.browse_leaderboard_times(_leaderboard_name)


func _on_leaderboard_submission_failed(_leaderboard_name: String, reason: String) -> void:
	_leaderboard_submitting = false
	if _username_input != null:
		_username_input.editable = true
		_username_input.grab_focus()
	if _leaderboard_status != null:
		_leaderboard_status.text = reason
		_leaderboard_status.add_theme_color_override(&"font_color", Color(0.95, 0.45, 0.45, 1.0))


func _on_leaderboard_scores_loaded(_leaderboard_name: String, entries: Array) -> void:
	if _leaderboard_entries == null:
		return
	if entries.is_empty():
		_leaderboard_entries.text = "BRAK WYNIKÓW.\nBĄDŹ PIERWSZY!"
		return
	var sorted_entries := entries.duplicate()
	sorted_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var time_a := float(a.get("elapsed_seconds", float(a.get("score_ms", 0)) / 1000.0))
		var time_b := float(b.get("elapsed_seconds", float(b.get("score_ms", 0)) / 1000.0))
		return time_a < time_b
	)
	var lines: PackedStringArray = PackedStringArray()
	var count := mini(sorted_entries.size(), 10)
	for i in count:
		var item: Dictionary = sorted_entries[i] if sorted_entries[i] is Dictionary else {}
		var uname := str(item.get("username", "GRACZ"))
		var elapsed := float(item.get("elapsed_seconds", float(item.get("score_ms", 0)) / 1000.0))
		lines.append("%d. %-14s %s" % [i + 1, uname.substr(0, 14), _format_time(elapsed)])
	_leaderboard_entries.text = "\n".join(lines)


func _on_leaderboard_load_failed(_leaderboard_name: String, reason: String) -> void:
	if _leaderboard_entries != null:
		_leaderboard_entries.text = reason


func _is_username_input_capturing(event: InputEvent) -> bool:
	if _username_input == null or not _username_input.visible or not _username_input.editable or not _username_input.has_focus():
		return false
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_ESCAPE:
			return false
		return true
	return false

