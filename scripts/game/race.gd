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
	SINGLEPLAYER,
}

enum MenuScreen {
	MAIN,
	LOCAL_PLAY,
	ONLINE,
	FRIENDS,
	SETTINGS,
	JOIN_CODE,
	WAITING,
}

const PAUSE_SELECTED_COLOR := Color(0.96, 0.96, 0.96, 1.0)
const PAUSE_UNSELECTED_COLOR := Color(0.75, 0.75, 0.75, 0.92)

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
@onready var _leaderboard_board_title: Label = get_node_or_null("GlobalUi/ResultPanel/LeaderboardSection/BoardPanel/BoardTitle") as Label
@onready var _leaderboard_entries: Label = $GlobalUi/ResultPanel/LeaderboardSection/BoardPanel/BoardEntries
@onready var _title_panel: MainMenu = $GlobalUi/TitlePanel
@onready var _countdown_label: Label = $GlobalUi/Countdown
@onready var _pause_panel: Control = $GlobalUi/PausePanel
@onready var _pause_title: Label = get_node_or_null("GlobalUi/PausePanel/Title") as Label
@onready var _pause_menu_items: Control = get_node_or_null("GlobalUi/PausePanel/MenuItems") as Control
@onready var _pause_settings_items: Control = get_node_or_null("GlobalUi/PausePanel/SettingsItems") as Control
@onready var _pause_hint: Label = get_node_or_null("GlobalUi/PausePanel/Hint") as Label
@onready var _pause_resume_option: Control = get_node_or_null("GlobalUi/PausePanel/MenuItems/ResumeOption") as Control
@onready var _pause_resume_cursor: Label = get_node_or_null("GlobalUi/PausePanel/MenuItems/ResumeOption/Cursor") as Label
@onready var _pause_resume_text: Label = get_node_or_null("GlobalUi/PausePanel/MenuItems/ResumeOption/Text") as Label
@onready var _pause_settings_option: Control = get_node_or_null("GlobalUi/PausePanel/MenuItems/SettingsOption") as Control
@onready var _pause_settings_cursor: Label = get_node_or_null("GlobalUi/PausePanel/MenuItems/SettingsOption/Cursor") as Label
@onready var _pause_settings_text: Label = get_node_or_null("GlobalUi/PausePanel/MenuItems/SettingsOption/Text") as Label
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
var _pause_in_settings: bool = false
var _pause_settings_selected_index: int = 0
var _pause_settings_rows: Array[Control] = []
var _pause_settings_cursors: Array[Label] = []
var _pause_settings_texts: Array[Label] = []

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
var _waiting_room_code: String = ""
var _waiting_is_quick_match: bool = false
var _finish_banner_places: Dictionary = {}
var _finish_banner_times: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if online_service == null:
		online_service = get_node_or_null("/root/OnlineService") as OnlineServiceBase
	_bind_game_settings_signals()
	_bind_leaderboard_service_signals()
	_player_one_world.player_finished.connect(_on_player_finished)
	_player_two_world.player_finished.connect(_on_player_finished)
	_title_panel.option_selected.connect(_on_menu_option_selected)
	_title_panel.option_adjusted.connect(_on_menu_option_adjusted)
	_title_panel.room_code_submitted.connect(_on_room_code_submitted)
	_title_panel.outro_finished.connect(_on_title_panel_outro_finished)
	if _username_input != null:
		_username_input.text_submitted.connect(_on_username_submitted)
	_setup_pause_controls()
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
	_refresh_localized_ui()
	call_deferred("_start_online_match_from_command_line")


func _setup_pause_controls() -> void:
	if _pause_resume_option != null:
		_pause_resume_option.mouse_entered.connect(_set_pause_selection.bind(0))
		_pause_resume_option.gui_input.connect(_on_pause_option_gui_input.bind(0))
	if _pause_settings_option != null:
		_pause_settings_option.mouse_entered.connect(_set_pause_selection.bind(1))
		_pause_settings_option.gui_input.connect(_on_pause_option_gui_input.bind(1))
	if _pause_menu_option != null:
		_pause_menu_option.mouse_entered.connect(_set_pause_selection.bind(2))
		_pause_menu_option.gui_input.connect(_on_pause_option_gui_input.bind(2))

	_pause_settings_rows.clear()
	_pause_settings_cursors.clear()
	_pause_settings_texts.clear()
	var settings_node_names: Array[String] = [
		"LanguageOption",
		"VolumeOption",
		"CrtOption",
		"FullscreenOption",
		"BackOption",
	]
	if _pause_settings_items != null:
		for index in settings_node_names.size():
			var row := _pause_settings_items.get_node_or_null(settings_node_names[index]) as Control
			if row == null:
				continue
			var cursor := row.get_node_or_null("Cursor") as Label
			var label := row.get_node_or_null("Text") as Label
			_pause_settings_rows.append(row)
			_pause_settings_cursors.append(cursor)
			_pause_settings_texts.append(label)
			row.mouse_entered.connect(_set_pause_settings_selection.bind(index))
			row.gui_input.connect(_on_pause_settings_option_gui_input.bind(index))


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
			if _menu_screen == MenuScreen.LOCAL_PLAY or _menu_screen == MenuScreen.ONLINE or _menu_screen == MenuScreen.SETTINGS:
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
		if _pause_in_settings:
			if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
				_close_pause_settings()
				get_viewport().set_input_as_handled()
				return
			if event.is_action_pressed(&"ui_accept"):
				_activate_pause_settings_option()
				get_viewport().set_input_as_handled()
				return
			if event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"p1_left") or event.is_action_pressed(&"p2_left"):
				_adjust_pause_settings_option(-1)
				get_viewport().set_input_as_handled()
				return
			if event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"p1_right") or event.is_action_pressed(&"p2_right"):
				_adjust_pause_settings_option(1)
				get_viewport().set_input_as_handled()
				return
			if event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"p1_jump") or event.is_action_pressed(&"p2_jump"):
				_move_pause_settings_selection(-1)
				get_viewport().set_input_as_handled()
				return
			if event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"p1_slide") or event.is_action_pressed(&"p2_slide") or event.is_action_pressed(&"p1_shout") or event.is_action_pressed(&"p2_shout"):
				_move_pause_settings_selection(1)
				get_viewport().set_input_as_handled()
				return
			return

		if event.is_action_pressed(&"pause"):
			_toggle_pause()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
			_activate_pause_menu_exit()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(&"ui_accept"):
			_activate_pause_option()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"p1_jump") or event.is_action_pressed(&"p2_jump"):
			_move_pause_selection(-1)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"p1_slide") or event.is_action_pressed(&"p2_slide") or event.is_action_pressed(&"p1_shout") or event.is_action_pressed(&"p2_shout"):
			_move_pause_selection(1)
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed(&"pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return

	if (_session_mode == SessionMode.LOCAL or _session_mode == SessionMode.SINGLEPLAYER) and _race_state in [RaceState.RACING, RaceState.PAUSED]:
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
	_finish_banner_places.clear()
	_finish_banner_times.clear()
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
	if _session_mode != SessionMode.SINGLEPLAYER:
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
		_pause_in_settings = false
		get_tree().paused = false
		_set_race_state(RaceState.RACING)
	elif _race_state == RaceState.RACING:
		_pause_in_settings = false
		_pause_selected_index = 0
		_pause_settings_selected_index = 0
		_update_pause_visuals()
		get_tree().paused = true
		_set_race_state(RaceState.PAUSED)


func _set_pause_selection(index: int) -> void:
	if _pause_in_settings:
		return
	if _pause_selected_index != index:
		_pause_selected_index = index
		_play_ui_move()
		_update_pause_visuals()


func _move_pause_selection(delta: int) -> void:
	var next_idx := posmod(_pause_selected_index + delta, 3)
	_set_pause_selection(next_idx)


func _open_pause_settings() -> void:
	_pause_in_settings = true
	_pause_settings_selected_index = 0
	_update_pause_visuals()


func _close_pause_settings() -> void:
	_play_ui_move()
	_pause_in_settings = false
	_update_pause_visuals()


func _set_pause_settings_selection(index: int) -> void:
	if not _pause_in_settings:
		return
	if _pause_settings_selected_index != index:
		_pause_settings_selected_index = index
		_play_ui_move()
		_update_pause_visuals()


func _move_pause_settings_selection(delta: int) -> void:
	var option_count := maxi(1, _pause_settings_rows.size())
	var next_idx := posmod(_pause_settings_selected_index + delta, option_count)
	_set_pause_settings_selection(next_idx)


func _activate_pause_settings_option() -> void:
	_play_ui_select()
	if _pause_settings_selected_index == 4:
		_pause_in_settings = false
		_update_pause_visuals()
		return
	_apply_settings_option(_pause_settings_selected_index, 1, true)
	_update_pause_visuals()


func _adjust_pause_settings_option(direction: int) -> void:
	if _pause_settings_selected_index == 4:
		return
	_play_ui_move()
	_apply_settings_option(_pause_settings_selected_index, direction, false)
	_update_pause_visuals()


func _update_pause_visuals() -> void:
	if _pause_title != null:
		_pause_title.text = tr("SETTINGS_TITLE") if _pause_in_settings else tr("PAUSE_TITLE")
	if _pause_menu_items != null:
		_pause_menu_items.visible = not _pause_in_settings
	if _pause_settings_items != null:
		_pause_settings_items.visible = _pause_in_settings
	if _pause_hint != null:
		_pause_hint.text = tr("PAUSE_SETTINGS_HINT") if _pause_in_settings else tr("PAUSE_HINT")

	var pause_cursors: Array[Label] = [_pause_resume_cursor, _pause_settings_cursor, _pause_menu_cursor]
	var pause_texts: Array[Label] = [_pause_resume_text, _pause_settings_text, _pause_menu_text]
	var pause_labels: Array[String] = [tr("PAUSE_RESUME"), tr("PAUSE_SETTINGS"), tr("PAUSE_MENU")]
	for index in pause_texts.size():
		var is_selected := index == _pause_selected_index
		var color := PAUSE_SELECTED_COLOR if is_selected else PAUSE_UNSELECTED_COLOR
		if pause_cursors[index] != null:
			pause_cursors[index].text = ">" if is_selected else " "
			pause_cursors[index].add_theme_color_override(&"font_color", color)
		if pause_texts[index] != null:
			pause_texts[index].text = pause_labels[index]
			pause_texts[index].add_theme_color_override(&"font_color", color)

	var settings_labels := _build_settings_options()
	for index in _pause_settings_rows.size():
		var is_selected := index == _pause_settings_selected_index
		var color := PAUSE_SELECTED_COLOR if is_selected else PAUSE_UNSELECTED_COLOR
		if index < _pause_settings_cursors.size() and _pause_settings_cursors[index] != null:
			_pause_settings_cursors[index].text = ">" if is_selected else " "
			_pause_settings_cursors[index].add_theme_color_override(&"font_color", color)
		if index < _pause_settings_texts.size() and _pause_settings_texts[index] != null and index < settings_labels.size():
			_pause_settings_texts[index].text = settings_labels[index]
			_pause_settings_texts[index].add_theme_color_override(&"font_color", color)


func _activate_pause_option() -> void:
	_play_ui_select()
	if _pause_selected_index == 0:
		_toggle_pause()
	elif _pause_selected_index == 1:
		_open_pause_settings()
	else:
		_return_to_main_menu()


func _activate_pause_menu_exit() -> void:
	_play_ui_select()
	_return_to_main_menu()


func _on_pause_option_gui_input(event: InputEvent, index: int) -> void:
	if _pause_in_settings:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pause_selected_index = index
		_activate_pause_option()


func _on_pause_settings_option_gui_input(event: InputEvent, index: int) -> void:
	if not _pause_in_settings:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pause_settings_selected_index = index
		_activate_pause_settings_option()


func _play_ui_move() -> void:
	if _ui_move != null:
		_ui_move.pitch_scale = randf_range(0.96, 1.04)
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
	elif _session_mode == SessionMode.SINGLEPLAYER:
		_player_one_world.set_race_active(is_racing and not _player_finish_times.has(1))
		_player_two_world.set_race_active(false)
	else:
		_player_one_world.set_race_active(is_racing and not _player_finish_times.has(1))
		_player_two_world.set_race_active(is_racing and not _player_finish_times.has(2))
	if previous_state == RaceState.COUNTDOWN and next_state == RaceState.RACING:
		_player_one_world.emit_intro_pulse()
		if _session_mode != SessionMode.SINGLEPLAYER:
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
		_finish_status_label.text = tr("HUD_YOU_FINISHED_WAIT")
		_finish_status_label.visible = true
		_update_timer_labels()
		return

	if _session_mode == SessionMode.SINGLEPLAYER:
		_player_finish_times[1] = _race_elapsed
		_player_one_world.set_race_active(false)
		_update_timer_labels()
		_finish_status_label.visible = false
		_hide_finish_banners()
		_winner_label.text = tr("RESULT_SINGLEPLAYER_FINISH")
		_placement_summary_label.text = tr("RESULT_SINGLEPLAYER_RUN_TIME") % _format_time(_race_elapsed)
		_times_label.text = tr("RESULT_SINGLEPLAYER_YOUR_TIME") % _format_time(_race_elapsed)
		_result_actions.text = tr("RESULT_SINGLEPLAYER_ACTIONS")
		_result_reminder.text = tr("RESULT_LOCAL_REMINDER")
		_prepare_leaderboard_prompt(
			_race_elapsed,
			tr("LB_PROMPT_SINGLEPLAYER") % _format_time(_race_elapsed)
		)
		_set_race_state(RaceState.FINISHED)
		return

	_player_finish_times[player_number] = _race_elapsed
	_get_player_world(player_number).set_race_active(false)
	_update_timer_labels()
	var placement := 1 if _player_finish_times.size() == 1 else 2
	_show_player_finish_banner(player_number, placement, _race_elapsed)
	if _player_finish_times.size() < 2:
		_finish_status_label.text = tr("HUD_PLAYER_FINISHED_WAIT") % player_number
		_finish_status_label.visible = true
		return

	_finish_status_label.visible = false
	_hide_finish_banners()
	var winner_number := _winner_number()
	_winner_label.text = tr("RESULT_PLAYER_WINS") % winner_number
	_update_placement_summary(tr("HUD_PLAYER_1"), tr("HUD_PLAYER_2"))
	_result_actions.text = tr("RESULT_LOCAL_ACTIONS")
	_result_reminder.text = tr("RESULT_LOCAL_REMINDER")
	_times_label.text = tr("RESULT_TIMES") % [
		_format_time(float(_player_finish_times[1])),
		_format_time(float(_player_finish_times[2])),
	]
	_prepare_leaderboard_prompt(
		float(_player_finish_times[winner_number]),
		tr("LB_PROMPT_WINNER") % [winner_number, _format_time(float(_player_finish_times[winner_number]))]
	)
	_set_race_state(RaceState.FINISHED)


func start_singleplayer_match() -> void:
	_session_mode = SessionMode.SINGLEPLAYER
	_setup_singleplayer_presentation()
	_generate_race(_next_random_seed())
	_begin_match_start()


func start_local_match() -> void:
	_session_mode = SessionMode.LOCAL
	_setup_local_two_player_presentation()
	_generate_race(_next_random_seed())
	_begin_match_start()


func _setup_singleplayer_presentation() -> void:
	get_tree().paused = false
	_top_container.anchor_top = 0.0
	_top_container.anchor_bottom = 1.0
	_top_container.offset_top = 0.0
	_top_container.offset_bottom = 0.0
	_bottom_container.visible = false
	_divider.visible = false
	_player_one_label.text = tr("HUD_SINGLEPLAYER")
	_player_one_label.visible = true
	_player_two_label.visible = false
	_player_one_timer_label.visible = true
	_player_two_timer_label.visible = false
	_network_status_label.visible = false
	_opponent_progress_label.visible = false
	_finish_status_label.visible = false
	_player_one_world.configure_for_singleplayer()
	_player_two_world.set_physics_process(false)
	_player_two_world.set_process(false)
	_player_two_world.set_race_active(false)


func _setup_local_two_player_presentation() -> void:
	get_tree().paused = false
	_top_container.anchor_top = 0.0
	_top_container.anchor_bottom = 0.5
	_top_container.offset_top = 0.0
	_top_container.offset_bottom = -2.0
	_bottom_container.visible = true
	_divider.visible = true
	_player_one_label.text = tr("HUD_PLAYER_1")
	_player_two_label.text = tr("HUD_PLAYER_2")
	_player_one_label.visible = true
	_player_two_label.visible = true
	_player_two_label.position.y = 382.0
	_player_one_timer_label.visible = true
	_player_two_timer_label.visible = true
	_player_two_timer_label.position.y = 412.0
	_network_status_label.visible = false
	_opponent_progress_label.visible = false
	_finish_status_label.visible = false
	_player_two_world.set_physics_process(true)
	_player_two_world.set_process(true)
	_player_one_world.configure_for_local_slot(1)
	_player_two_world.configure_for_local_slot(2)


func start_quick_match() -> void:
	_waiting_room_code = ""
	_waiting_is_quick_match = true
	_begin_online_session()
	if _menu_screen == MenuScreen.WAITING:
		_title_panel.show_waiting(tr("MENU_FINDING_OPPONENT"), tr("MENU_ESC_CANCEL"))
	_online_match.queue_quick_match()


func host_friend_room(room_code: String = "") -> void:
	_waiting_room_code = room_code.strip_edges().to_upper()
	_waiting_is_quick_match = false
	_begin_online_session()
	_online_match.host_friend_room(room_code)


func join_friend_room(room_code: String) -> void:
	_waiting_room_code = room_code.strip_edges().to_upper()
	_waiting_is_quick_match = false
	_begin_online_session()
	_online_match.join_friend_room(room_code)


func _begin_online_session() -> void:
	_session_mode = SessionMode.ONLINE
	get_tree().paused = false
	_top_container.anchor_bottom = 0.5
	_top_container.offset_bottom = -2.0
	_bottom_container.visible = true
	_divider.visible = true
	_player_one_label.text = tr("HUD_YOU")
	_player_two_label.text = tr("HUD_OPPONENT")
	_player_two_label.position.y = 382.0
	_player_two_timer_label.position.y = 412.0
	_network_status_label.visible = true
	_network_status_label.text = tr("HUD_CONNECTING")
	_opponent_progress_label.visible = false
	_opponent_progress_label.text = ""
	if _menu_screen != MenuScreen.WAITING:
		_title_panel.visible = false
	_finish_status_label.text = tr("HUD_CONNECTING_OPPONENT")
	_finish_status_label.visible = true
	_player_one_world.set_race_active(false)
	_player_two_world.set_race_active(false)


func _start_online_match_from_command_line() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--singleplayer":
			start_singleplayer_match()
			return
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
	_waiting_room_code = room_code
	_seed_label.text = tr("HUD_ROOM_CODE") % room_code
	_finish_status_label.text = tr("HUD_WAITING_PLAYER_2")
	if _menu_screen == MenuScreen.WAITING:
		_title_panel.show_waiting(tr("MENU_ROOM_CODE_DISPLAY") % room_code, tr("MENU_SHARE_CODE_HINT"))


func _on_online_match_configured(player_slot: int, seed: int) -> void:
	_set_race_state(RaceState.STARTING)
	_title_panel.visible = false
	_result_panel.visible = false
	_player_one_label.text = _online_match.local_display_name
	_player_two_label.text = _online_match.opponent_display_name if not _online_match.opponent_display_name.is_empty() else tr("HUD_OPPONENT")
	_network_status_label.text = tr("HUD_CONNECTED")
	_player_one_world.configure_for_online_slot(player_slot)
	_player_two_world.configure_as_remote_opponent(2 if player_slot == 1 else 1)
	_status_send_remaining = 0.0
	_generate_race(seed)
	_seed_label.text = tr("HUD_ROOM") % _online_match.room_code
	_finish_status_label.text = tr("HUD_VERIFYING_COURSE")
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
	_winner_label.text = tr("RESULT_REMATCH_WAITING")
	if _online_match != null and _online_match.has_local_rematch_vote():
		_result_reminder.text = tr("RESULT_REMATCH_WAIT_OTHER")
	else:
		_result_reminder.text = tr("RESULT_REMATCH_OPPONENT_WANTS")


func _on_online_opponent_finished(player_slot: int, elapsed: float) -> void:
	_player_finish_times[player_slot] = elapsed
	_player_two_world.set_race_active(false)
	var place := 1 if _player_finish_times.size() == 1 else 2
	_show_player_finish_banner(2, place, elapsed)
	_finish_status_label.text = tr("HUD_OPPONENT_FINISHED_GO")
	_finish_status_label.visible = true
	_update_timer_labels()


func _on_online_opponent_snapshot_received(pos: Vector2, vel: Vector2, facing: float, on_floor: bool, loudness: float, boost_active: bool, events: Array) -> void:
	if _session_mode == SessionMode.ONLINE and _player_two_world != null:
		_player_two_world.apply_remote_snapshot(pos, vel, facing, on_floor, loudness, boost_active, events)


func _on_online_match_finished(finish_times: Dictionary, winner_slot: int) -> void:
	_player_finish_times = finish_times.duplicate(true)
	_finish_status_label.visible = false
	_hide_finish_banners()
	_winner_label.text = tr("RESULT_YOU_WIN") if winner_slot == _online_match.player_slot else tr("RESULT_OPPONENT_WINS")
	var opponent_fallback := tr("HUD_OPPONENT")
	var p1_label := _online_match.local_display_name if _online_match.player_slot == 1 else (_online_match.opponent_display_name if not _online_match.opponent_display_name.is_empty() else opponent_fallback)
	var p2_label := _online_match.local_display_name if _online_match.player_slot == 2 else (_online_match.opponent_display_name if not _online_match.opponent_display_name.is_empty() else opponent_fallback)
	_update_placement_summary(p1_label, p2_label)
	_result_actions.text = tr("RESULT_ONLINE_ACTIONS")
	_result_reminder.text = tr("RESULT_ONLINE_SUMMARY")
	_times_label.text = tr("RESULT_TIMES") % [
		_format_time(float(_player_finish_times[1])),
		_format_time(float(_player_finish_times[2])),
	]
	var local_slot := _online_match.player_slot if _online_match.player_slot in [1, 2] else 1
	var local_time := float(_player_finish_times.get(local_slot, _player_finish_times.get(1, 0.0)))
	_prepare_leaderboard_prompt(
		local_time,
		tr("LB_PROMPT_ONLINE") % _format_time(local_time)
	)
	_set_race_state(RaceState.FINISHED)


func _on_online_opponent_left(_client_id: int) -> void:
	if _session_mode != SessionMode.ONLINE:
		return
	_finish_status_label.visible = false
	_hide_finish_banners()
	_placement_summary_label.text = ""
	_winner_label.text = tr("RESULT_OPPONENT_LEFT")
	_times_label.text = ""
	_result_actions.text = tr("RESULT_ESC_MENU")
	_result_reminder.text = tr("RESULT_ONLINE_ENDED")
	if _leaderboard_section != null:
		_leaderboard_section.visible = false
	_set_race_state(RaceState.FINISHED)


func _on_online_match_failed(reason: String) -> void:
	if _session_mode != SessionMode.ONLINE:
		return
	_finish_status_label.visible = false
	_hide_finish_banners()
	_placement_summary_label.text = ""
	_winner_label.text = tr("RESULT_MATCH_FAILED")
	_times_label.text = reason
	_result_actions.text = tr("RESULT_ESC_MENU")
	_result_reminder.text = tr("RESULT_CHECK_CONNECTION")
	if _leaderboard_section != null:
		_leaderboard_section.visible = false
	_set_race_state(RaceState.FINISHED)


func _show_menu(next_screen: MenuScreen, preserve_selection: bool = false) -> void:
	_menu_screen = next_screen
	_title_panel.visible = true
	match next_screen:
		MenuScreen.MAIN:
			if not preserve_selection:
				_title_panel.reset_to_idle()
			_title_panel.show_options(
				[tr("MENU_PLAY"), tr("MENU_ONLINE"), tr("MENU_SETTINGS"), tr("MENU_QUIT")],
				tr("MENU_MAIN_PROMPT"),
				tr("MENU_MAIN_HINT"),
				false,
				preserve_selection,
			)
		MenuScreen.LOCAL_PLAY:
			_title_panel.show_options(
				[tr("MENU_SINGLEPLAYER"), tr("MENU_TWO_PLAYERS")],
				tr("MENU_MAIN_PROMPT"),
				tr("MENU_LOCAL_PLAY_HINT"),
				false,
				preserve_selection,
			)
		MenuScreen.ONLINE:
			_title_panel.show_options(
				[tr("MENU_QUICK_MATCH"), tr("MENU_WITH_FRIEND")],
				tr("MENU_ONLINE_PROMPT"),
				tr("MENU_ONLINE_HINT"),
				false,
				preserve_selection,
			)
		MenuScreen.FRIENDS:
			_title_panel.show_options(
				[tr("MENU_CREATE_ROOM"), tr("MENU_JOIN_BY_CODE")],
				tr("MENU_FRIENDS_PROMPT"),
				tr("MENU_FRIENDS_HINT"),
				false,
				preserve_selection,
			)
		MenuScreen.SETTINGS:
			_title_panel.show_options(
				_build_settings_options(),
				tr("SETTINGS_PROMPT"),
				tr("SETTINGS_HINT"),
				true,
				preserve_selection,
			)
		MenuScreen.JOIN_CODE:
			_title_panel.show_room_code_entry(tr("MENU_JOIN_ROOM_TITLE"), tr("MENU_JOIN_ROOM_HINT"))
		MenuScreen.WAITING:
			if not _waiting_room_code.is_empty():
				_title_panel.show_waiting(tr("MENU_ROOM_CODE_DISPLAY") % _waiting_room_code, tr("MENU_SHARE_CODE_HINT"))
			elif _waiting_is_quick_match:
				_title_panel.show_waiting(tr("MENU_FINDING_OPPONENT"), tr("MENU_ESC_CANCEL"))
			else:
				_title_panel.show_waiting(tr("MENU_CONNECTING"), tr("MENU_ESC_CANCEL"))


func _on_menu_option_selected(index: int) -> void:
	match _menu_screen:
		MenuScreen.MAIN:
			if index == 0:
				_show_menu(MenuScreen.LOCAL_PLAY)
			elif index == 1:
				_show_menu(MenuScreen.ONLINE)
			elif index == 2:
				_show_menu(MenuScreen.SETTINGS)
			else:
				get_tree().quit()
		MenuScreen.LOCAL_PLAY:
			if index == 0:
				start_singleplayer_match()
			else:
				start_local_match()
		MenuScreen.ONLINE:
			if index == 0:
				_show_menu(MenuScreen.WAITING)
				start_quick_match()
			else:
				_show_menu(MenuScreen.FRIENDS)
		MenuScreen.FRIENDS:
			if index == 0:
				_show_menu(MenuScreen.WAITING)
				host_friend_room()
			else:
				_show_menu(MenuScreen.JOIN_CODE)
		MenuScreen.SETTINGS:
			if index == 4:
				_show_menu(MenuScreen.MAIN)
			else:
				_apply_settings_option(index, 1, true)
				_show_menu(MenuScreen.SETTINGS, true)


func _on_menu_option_adjusted(index: int, direction: int) -> void:
	if _menu_screen != MenuScreen.SETTINGS or index == 4:
		return
	_apply_settings_option(index, direction, false)
	_show_menu(MenuScreen.SETTINGS, true)


func _on_room_code_submitted(room_code: String) -> void:
	if _menu_screen == MenuScreen.JOIN_CODE:
		_submit_room_code(room_code)


func _submit_room_code(room_code: String) -> void:
	var normalized_code := room_code.strip_edges().to_upper()
	if normalized_code.is_empty():
		_title_panel.show_room_code_entry(tr("MENU_JOIN_ROOM_TITLE"), tr("MENU_JOIN_ROOM_EMPTY_HINT"))
		return
	_show_menu(MenuScreen.WAITING)
	join_friend_room(normalized_code)


func _return_to_main_menu() -> void:
	get_tree().paused = false
	_pause_in_settings = false
	_waiting_room_code = ""
	_waiting_is_quick_match = false
	_cancel_transition()
	_cancel_invert_flash()
	_online_match.leave_match()
	_session_mode = SessionMode.LOCAL
	_setup_local_two_player_presentation()
	_result_actions.text = tr("RESULT_LOCAL_ACTIONS")
	_result_reminder.text = tr("RESULT_LOCAL_REMINDER")
	_generate_race(_next_random_seed())
	_set_race_state(RaceState.TITLE)
	_show_menu(MenuScreen.MAIN)


func _get_game_settings() -> GameSettingsNode:
	return get_node_or_null("/root/GameSettings") as GameSettingsNode


func _bind_game_settings_signals() -> void:
	var settings := _get_game_settings()
	if settings == null:
		return
	if not settings.settings_changed.is_connected(_on_game_settings_changed):
		settings.settings_changed.connect(_on_game_settings_changed)


func _on_game_settings_changed() -> void:
	_refresh_localized_ui()


func _build_settings_options() -> Array[String]:
	var settings := _get_game_settings()
	var lang_display := settings.get_language_display_name() if settings != null else tr("SETTINGS_LANG_EN")
	var volume := settings.master_volume if settings != null else 100
	var crt_state := tr("SETTINGS_ON") if (settings == null or settings.crt_enabled) else tr("SETTINGS_OFF")
	var fullscreen_state := tr("SETTINGS_ON") if (settings != null and settings.fullscreen) else tr("SETTINGS_OFF")
	return [
		"%s:  < %s >" % [tr("SETTINGS_LANGUAGE"), lang_display],
		"%s:  < %d%% >" % [tr("SETTINGS_VOLUME"), volume],
		"%s:  < %s >" % [tr("SETTINGS_CRT"), crt_state],
		"%s:  < %s >" % [tr("SETTINGS_FULLSCREEN"), fullscreen_state],
		tr("SETTINGS_BACK"),
	]


func _apply_settings_option(index: int, direction: int, wrap_volume: bool) -> void:
	var settings := _get_game_settings()
	if settings == null:
		return
	match index:
		0:
			settings.cycle_language(direction)
		1:
			settings.adjust_master_volume(direction, wrap_volume)
		2:
			settings.toggle_crt_enabled()
		3:
			settings.toggle_fullscreen()


func _refresh_localized_ui() -> void:
	if _title_panel != null:
		_title_panel.set_room_code_placeholder(tr("MENU_ROOM_CODE_PLACEHOLDER"))
	if _race_state == RaceState.TITLE:
		_show_menu(_menu_screen, true)

	if _session_mode == SessionMode.SINGLEPLAYER:
		_player_one_label.text = tr("HUD_SINGLEPLAYER")
	elif _session_mode == SessionMode.LOCAL:
		_player_one_label.text = tr("HUD_PLAYER_1")
		_player_two_label.text = tr("HUD_PLAYER_2")
	else:
		if _online_match != null and not _online_match.local_display_name.is_empty():
			_player_one_label.text = _online_match.local_display_name
		else:
			_player_one_label.text = tr("HUD_YOU")
		if _online_match != null and not _online_match.opponent_display_name.is_empty():
			_player_two_label.text = _online_match.opponent_display_name
		else:
			_player_two_label.text = tr("HUD_OPPONENT")

	_update_timer_labels()
	_update_pause_visuals()

	if _leaderboard_board_title != null:
		_leaderboard_board_title.text = tr("LB_TITLE")
	if _username_input != null:
		_username_input.placeholder_text = tr("LB_PLACEHOLDER")

	if _player_one_finish_banner != null and _player_one_finish_banner.visible and _finish_banner_places.has(1):
		_update_finish_banner_text(_player_one_finish_banner, int(_finish_banner_places[1]), float(_finish_banner_times[1]))
	if _player_two_finish_banner != null and _player_two_finish_banner.visible and _finish_banner_places.has(2):
		_update_finish_banner_text(_player_two_finish_banner, int(_finish_banner_places[2]), float(_finish_banner_times[2]))

	if _finish_status_label.visible and _session_mode == SessionMode.LOCAL and _player_finish_times.size() == 1:
		var finished_player := int(_player_finish_times.keys()[0])
		_finish_status_label.text = tr("HUD_PLAYER_FINISHED_WAIT") % finished_player


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


func _place_label_text(place: int) -> String:
	return tr("HUD_PLACE_1") if place == 1 else tr("HUD_PLACE_2")


func _update_finish_banner_text(banner: Control, place: int, elapsed: float) -> void:
	var place_label := banner.get_node_or_null("Place") as Label
	var time_label := banner.get_node_or_null("Time") as Label
	var border := banner.get_node_or_null("Border") as ReferenceRect
	var accent := Color(0.941176, 0.921569, 0.752941, 1.0) if place == 1 else Color(0.760784, 0.94902, 0.94902, 1.0)
	if place_label != null:
		place_label.text = _place_label_text(place)
		place_label.add_theme_color_override(&"font_color", accent)
	if time_label != null:
		time_label.text = tr("HUD_TIME") % _format_time(elapsed)
	if border != null:
		border.border_color = accent


func _show_player_finish_banner(viewport_slot: int, place: int, elapsed: float) -> void:
	var banner := _player_one_finish_banner if viewport_slot == 1 else _player_two_finish_banner
	if banner == null:
		return
	_finish_banner_places[viewport_slot] = place
	_finish_banner_times[viewport_slot] = elapsed
	_update_finish_banner_text(banner, place, elapsed)
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
	var first_place := tr("HUD_PLACE_1")
	var second_place := tr("HUD_PLACE_2")
	if t1 <= t2:
		_placement_summary_label.text = "%s   %s   —   %s\n%s   %s   —   %s" % [
			first_place, p1_name, _format_time(t1), second_place, p2_name, _format_time(t2)
		]
	else:
		_placement_summary_label.text = "%s   %s   —   %s\n%s   %s   —   %s" % [
			first_place, p2_name, _format_time(t2), second_place, p1_name, _format_time(t1)
		]


func _update_timer_labels() -> void:
	_player_one_timer_label.text = tr("HUD_TIME") % _format_time(_time_for_player(1))
	if _session_mode != SessionMode.SINGLEPLAYER:
		_player_two_timer_label.text = tr("HUD_TIME") % _format_time(_time_for_player(2))


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
	if _leaderboard_board_title != null:
		_leaderboard_board_title.text = tr("LB_TITLE")
	if _leaderboard_prompt != null:
		_leaderboard_prompt.text = prompt_text
	if _leaderboard_status != null:
		_leaderboard_status.text = tr("LB_STATUS_READY")
		_leaderboard_status.add_theme_color_override(&"font_color", Color(0.760784, 0.94902, 0.94902, 1.0))
	if _username_input != null:
		_username_input.visible = true
		_username_input.editable = true
		_username_input.placeholder_text = tr("LB_PLACEHOLDER")
		_username_input.text = _last_username
		_username_input.grab_focus()
		_username_input.caret_column = _username_input.text.length()
	if _leaderboard_entries != null:
		_leaderboard_entries.add_theme_font_size_override(&"font_size", 18)
		_leaderboard_entries.text = tr("LB_LOADING")
	if online_service != null:
		online_service.browse_leaderboard_times(
			OnlineServiceBase.DEFAULT_LEADERBOARD_NAME,
			OnlineServiceBase.DEFAULT_LEADERBOARD_PAGE_SIZE
		)


func _on_username_submitted(username_text: String) -> void:
	if _leaderboard_submitted or _leaderboard_submitting or _pending_leaderboard_time <= 0.0:
		return
	var trimmed := username_text.strip_edges()
	if trimmed.is_empty():
		if _leaderboard_status != null:
			_leaderboard_status.text = tr("LB_STATUS_EMPTY_NAME")
			_leaderboard_status.add_theme_color_override(&"font_color", Color(0.95, 0.45, 0.45, 1.0))
		return
	_last_username = trimmed
	_leaderboard_submitting = true
	if _username_input != null:
		_username_input.editable = false
	if _leaderboard_status != null:
		_leaderboard_status.text = tr("LB_STATUS_SAVING")
		_leaderboard_status.add_theme_color_override(&"font_color", Color(0.941176, 0.921569, 0.752941, 1.0))
	if online_service == null:
		online_service = get_node_or_null("/root/OnlineService") as OnlineServiceBase
		_bind_leaderboard_service_signals()
	if online_service == null:
		_on_leaderboard_submission_failed(OnlineServiceBase.DEFAULT_LEADERBOARD_NAME, tr("LB_STATUS_NO_SERVICE"))
		return
	online_service.submit_leaderboard_time(
		trimmed,
		_pending_leaderboard_time,
		OnlineServiceBase.DEFAULT_LEADERBOARD_NAME,
		{
			"mode": "online" if _session_mode == SessionMode.ONLINE else ("singleplayer" if _session_mode == SessionMode.SINGLEPLAYER else "offline"),
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
		_leaderboard_status.text = tr("LB_STATUS_SAVED") % [username, _format_time(float(score_ms) / 1000.0)]
		_leaderboard_status.add_theme_color_override(&"font_color", Color(0.6, 0.98, 0.65, 1.0))
	if online_service != null:
		online_service.browse_leaderboard_times(
			_leaderboard_name,
			OnlineServiceBase.DEFAULT_LEADERBOARD_PAGE_SIZE
		)


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
		_leaderboard_entries.text = tr("LB_EMPTY")
		return
	var sorted_entries := entries.duplicate()
	sorted_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var time_a := float(a.get("elapsed_seconds", float(a.get("score_ms", 0)) / 1000.0))
		var time_b := float(b.get("elapsed_seconds", float(b.get("score_ms", 0)) / 1000.0))
		return time_a < time_b
	)
	var lines: PackedStringArray = PackedStringArray()
	var count := mini(sorted_entries.size(), OnlineServiceBase.DEFAULT_LEADERBOARD_PAGE_SIZE)
	for i in count:
		var item: Dictionary = sorted_entries[i] if sorted_entries[i] is Dictionary else {}
		var uname := str(item.get("username", tr("LB_DEFAULT_PLAYER"))).strip_edges()
		if uname.is_empty():
			uname = tr("LB_DEFAULT_PLAYER")
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
