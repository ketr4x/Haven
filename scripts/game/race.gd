extends Control

enum RaceState {
	TITLE,
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
@onready var _winner_label: Label = $GlobalUi/ResultPanel/Winner
@onready var _times_label: Label = $GlobalUi/ResultPanel/Times
@onready var _title_panel: Control = $GlobalUi/TitlePanel
@onready var _title_tagline: Label = $GlobalUi/TitlePanel/Tagline
@onready var _player_one_controls: Label = $GlobalUi/TitlePanel/PlayerOneControls
@onready var _player_two_controls: Label = $GlobalUi/TitlePanel/PlayerTwoControls
@onready var _menu_prompt: Label = $GlobalUi/TitlePanel/Prompt
@onready var _menu_hint: Label = $GlobalUi/TitlePanel/Hint
@onready var _room_code_input: LineEdit = $GlobalUi/TitlePanel/RoomCodeInput
@onready var _countdown_label: Label = $GlobalUi/Countdown
@onready var _pause_panel: Control = $GlobalUi/PausePanel
@onready var _result_panel: Control = $GlobalUi/ResultPanel
@onready var _result_actions: Label = $GlobalUi/ResultPanel/Actions
@onready var _result_reminder: Label = $GlobalUi/ResultPanel/Reminder

var _seed: int = 0
var _seed_random: RandomNumberGenerator = RandomNumberGenerator.new()
var _race_state: RaceState = RaceState.TITLE
var _countdown_remaining: float = 0.0
var _race_elapsed: float = 0.0
var _player_finish_times: Dictionary = {}
var _online_match: OnlineMatch
var _session_mode: SessionMode = SessionMode.LOCAL
var _menu_index: int = 0
var _menu_screen: MenuScreen = MenuScreen.MAIN
var _status_send_remaining: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player_one_world.player_finished.connect(_on_player_finished)
	_player_two_world.player_finished.connect(_on_player_finished)
	_room_code_input.text_submitted.connect(_on_room_code_submitted)
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
	_online_match.rematch_waiting.connect(_on_online_rematch_waiting)
	_online_match.match_failed.connect(_on_online_match_failed)
	_seed_random.randomize()
	_generate_race(_next_random_seed())
	_set_race_state(RaceState.TITLE)
	_show_menu(MenuScreen.MAIN)
	call_deferred("_start_online_match_from_command_line")


func _process(delta: float) -> void:
	if _race_state == RaceState.COUNTDOWN:
		_countdown_remaining = maxf(0.0, _countdown_remaining - delta)
		_countdown_label.text = str(maxi(1, ceili(_countdown_remaining)))
		if is_zero_approx(_countdown_remaining):
			if _session_mode == SessionMode.ONLINE:
				_online_match.begin_race()
			_set_race_state(RaceState.RACING)
		return

	if _race_state == RaceState.RACING:
		_race_elapsed += delta
		if _session_mode == SessionMode.ONLINE:
			_status_send_remaining = maxf(0.0, _status_send_remaining - delta)
			if is_zero_approx(_status_send_remaining):
				_status_send_remaining = 0.1
				_online_match.submit_local_status(
					_player_one_world.progress_fraction(),
					_player_one_world.current_loudness(),
					_player_one_world.has_rebound_boost(),
				)
		_update_timer_labels()


func _input(event: InputEvent) -> void:
	if _race_state == RaceState.TITLE:
		if _handle_menu_input(event):
			get_viewport().set_input_as_handled()
		return

	if _session_mode == SessionMode.ONLINE and _race_state == RaceState.FINISHED:
		if event.is_action_pressed(&"ui_accept"):
			_online_match.request_rematch()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
			_return_to_main_menu()
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed(&"pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return

	if _session_mode == SessionMode.LOCAL and _race_state in [RaceState.RACING, RaceState.PAUSED, RaceState.FINISHED]:
		if event.is_action_pressed(&"restart"):
			_restart_course()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(&"new_seed"):
			_restart_course()
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
	if _session_mode == SessionMode.LOCAL:
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


func _start_countdown(duration: float = countdown_duration) -> void:
	_countdown_remaining = duration
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
	if _session_mode == SessionMode.ONLINE:
		_player_one_world.set_race_active(is_racing and not _player_finish_times.has(_online_match.player_slot))
		_player_two_world.set_race_active(false)
	else:
		_player_one_world.set_race_active(is_racing and not _player_finish_times.has(1))
		_player_two_world.set_race_active(is_racing and not _player_finish_times.has(2))
	if previous_state == RaceState.COUNTDOWN and next_state == RaceState.RACING:
		_player_one_world.emit_intro_pulse()
		if _session_mode == SessionMode.LOCAL:
			_player_two_world.emit_intro_pulse()


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
	if _race_state != RaceState.RACING or _player_finish_times.has(player_number):
		return

	if _session_mode == SessionMode.ONLINE:
		_player_finish_times[player_number] = _race_elapsed
		_player_one_world.set_race_active(false)
		_online_match.submit_local_finish(_race_elapsed)
		_finish_status_label.text = "JESTEŚ NA MECIE. PRZECIWNIK JEDZIE DALEJ."
		_finish_status_label.visible = true
		_update_timer_labels()
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


func start_quick_match() -> void:
	_begin_online_session()
	if _menu_screen == MenuScreen.WAITING:
		_menu_prompt.text = "SZUKANIE PRZECIWNIKA…"
		_menu_hint.text = "ESC  ANULUJ"
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
	_top_container.anchor_bottom = 1.0
	_top_container.offset_bottom = 0.0
	_bottom_container.visible = false
	_divider.visible = false
	_player_one_label.text = "TY"
	_player_two_label.text = "PRZECIWNIK"
	_player_two_label.position.y = 88.0
	_player_two_timer_label.position.y = 118.0
	_network_status_label.visible = true
	_network_status_label.text = "ŁĄCZENIE…"
	_opponent_progress_label.visible = true
	_opponent_progress_label.text = "POSTĘP  0%"
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
		_menu_prompt.text = "KOD POKOJU\n%s" % room_code
		_menu_hint.text = "PRZEKAŻ KOD ZNAJOMEMU.    ESC  ANULUJ"


func _on_online_match_configured(player_slot: int, seed: int) -> void:
	_title_panel.visible = false
	_player_one_label.text = _online_match.local_display_name
	_player_two_label.text = _online_match.opponent_display_name if not _online_match.opponent_display_name.is_empty() else "PRZECIWNIK"
	_network_status_label.text = "POŁĄCZONO"
	_player_one_world.configure_for_online_slot(player_slot)
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


func _on_online_opponent_status_received(progress: float, loudness: float, boost_active: bool) -> void:
	var boost_text := "  ZRYW" if boost_active else ""
	_opponent_progress_label.text = "POSTĘP  %d%%  GŁOŚNOŚĆ  %d%%%s" % [
		roundi(progress * 100.0),
		roundi(loudness),
		boost_text,
	]


func _on_online_rematch_waiting() -> void:
	_winner_label.text = "CZEKA NA REWANŻ"
	_result_reminder.text = "DRUGI GRACZ MUSI POTWIERDZIĆ."


func _on_online_opponent_finished(player_slot: int, elapsed: float) -> void:
	_player_finish_times[player_slot] = elapsed
	_finish_status_label.text = "PRZECIWNIK JEST NA MECIE. JEDŹ DALEJ."
	_finish_status_label.visible = true
	_update_timer_labels()


func _on_online_match_finished(finish_times: Dictionary, winner_slot: int) -> void:
	_player_finish_times = finish_times.duplicate(true)
	_finish_status_label.visible = false
	_winner_label.text = "WYGRYWASZ" if winner_slot == _online_match.player_slot else "WYGRYWA PRZECIWNIK"
	_result_actions.text = "ENTER  REWANŻ        ESC  MENU"
	_result_reminder.text = "WYNIK MECZU ONLINE"
	_times_label.text = "GRACZ 1  %s\nGRACZ 2  %s" % [
		_format_time(float(_player_finish_times[1])),
		_format_time(float(_player_finish_times[2])),
	]
	_set_race_state(RaceState.FINISHED)


func _on_online_opponent_left(_client_id: int) -> void:
	_finish_status_label.visible = false
	_winner_label.text = "PRZECIWNIK OPUŚCIŁ MECZ"
	_times_label.text = ""
	_result_actions.text = "ENTER  REWANŻ        ESC  MENU"
	_result_reminder.text = "MECZ ONLINE ZAKOŃCZONY"
	_set_race_state(RaceState.FINISHED)


func _on_online_match_failed(reason: String) -> void:
	_finish_status_label.visible = false
	_winner_label.text = "NIE UDAŁO SIĘ ROZPOCZĄĆ MECZU"
	_times_label.text = reason
	_result_actions.text = "ENTER  REWANŻ        ESC  MENU"
	_result_reminder.text = "SPRAWDŹ POŁĄCZENIE I KOD POKOJU"
	_set_race_state(RaceState.FINISHED)


func _show_menu(next_screen: MenuScreen) -> void:
	_menu_screen = next_screen
	_menu_index = 0
	_title_panel.visible = true
	_room_code_input.visible = next_screen == MenuScreen.JOIN_CODE
	_player_one_controls.visible = false
	_player_two_controls.visible = false
	_title_tagline.text = "WYŚCIG ECHA"

	match next_screen:
		MenuScreen.MAIN:
			_menu_prompt.text = _menu_options(["GRA LOKALNA", "GRA ONLINE"])
			_menu_hint.text = "STRZAŁKI + ENTER  WYBIERZ"
		MenuScreen.ONLINE:
			_title_tagline.text = "GRA ONLINE"
			_menu_prompt.text = _menu_options(["SZYBKI MECZ", "ZE ZNAJOMYM", "POWRÓT"])
			_menu_hint.text = "STRZAŁKI + ENTER  WYBIERZ    ESC  POWRÓT"
		MenuScreen.FRIENDS:
			_title_tagline.text = "ZE ZNAJOMYM"
			_menu_prompt.text = _menu_options(["STWÓRZ POKÓJ", "DOŁĄCZ KODEM", "POWRÓT"])
			_menu_hint.text = "STRZAŁKI + ENTER  WYBIERZ    ESC  POWRÓT"
		MenuScreen.JOIN_CODE:
			_title_tagline.text = "DOŁĄCZ DO POKOJU"
			_menu_prompt.text = "WPISZ KOD POKOJU"
			_menu_hint.text = "ENTER  DOŁĄCZ    ESC  POWRÓT"
			_room_code_input.clear()
			_room_code_input.grab_focus()
		MenuScreen.WAITING:
			_title_tagline.text = "GRA ONLINE"
			_menu_prompt.text = "ŁĄCZENIE…"
			_menu_hint.text = "ESC  ANULUJ"


func _handle_menu_input(event: InputEvent) -> bool:
	if _menu_screen == MenuScreen.JOIN_CODE:
		if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
			_show_menu(MenuScreen.FRIENDS)
			return true
		if event.is_action_pressed(&"ui_accept"):
			_submit_room_code()
			return true
		return false

	if _menu_screen == MenuScreen.WAITING:
		if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
			_return_to_main_menu()
			return true
		return false

	if event.is_action_pressed(&"ui_up"):
		_menu_index = posmod(_menu_index - 1, _menu_option_count())
		_refresh_menu_options()
		return true
	if event.is_action_pressed(&"ui_down"):
		_menu_index = posmod(_menu_index + 1, _menu_option_count())
		_refresh_menu_options()
		return true
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		_show_menu(MenuScreen.MAIN if _menu_screen == MenuScreen.ONLINE else MenuScreen.ONLINE)
		return true
	if event.is_action_pressed(&"ui_accept"):
		_activate_menu_option()
		return true
	return false


func _activate_menu_option() -> void:
	match _menu_screen:
		MenuScreen.MAIN:
			if _menu_index == 0:
				_title_panel.visible = false
				_start_countdown()
			else:
				_show_menu(MenuScreen.ONLINE)
		MenuScreen.ONLINE:
			if _menu_index == 0:
				_show_menu(MenuScreen.WAITING)
				start_quick_match()
			elif _menu_index == 1:
				_show_menu(MenuScreen.FRIENDS)
			else:
				_show_menu(MenuScreen.MAIN)
		MenuScreen.FRIENDS:
			if _menu_index == 0:
				_show_menu(MenuScreen.WAITING)
				host_friend_room()
			elif _menu_index == 1:
				_show_menu(MenuScreen.JOIN_CODE)
			else:
				_show_menu(MenuScreen.ONLINE)


func _submit_room_code() -> void:
	var room_code := _room_code_input.text.strip_edges().to_upper()
	if room_code.is_empty():
		_menu_hint.text = "WPISZ KOD OTRZYMANY OD GOSPODARZA."
		return
	_show_menu(MenuScreen.WAITING)
	join_friend_room(room_code)


func _on_room_code_submitted(_room_code: String) -> void:
	if _menu_screen == MenuScreen.JOIN_CODE:
		_submit_room_code()


func _refresh_menu_options() -> void:
	match _menu_screen:
		MenuScreen.MAIN:
			_menu_prompt.text = _menu_options(["GRA LOKALNA", "GRA ONLINE"])
		MenuScreen.ONLINE:
			_menu_prompt.text = _menu_options(["SZYBKI MECZ", "ZE ZNAJOMYM", "POWRÓT"])
		MenuScreen.FRIENDS:
			_menu_prompt.text = _menu_options(["STWÓRZ POKÓJ", "DOŁĄCZ KODEM", "POWRÓT"])


func _menu_options(options: Array[String]) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for index in options.size():
		lines.append((">  " if index == _menu_index else "   ") + options[index])
	return "\n".join(lines)


func _menu_option_count() -> int:
	match _menu_screen:
		MenuScreen.MAIN:
			return 2
		MenuScreen.ONLINE, MenuScreen.FRIENDS:
			return 3
	return 1


func _return_to_main_menu() -> void:
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
	_result_actions.text = "R  REWANŻ        N  NOWA TRASA"
	_result_reminder.text = "ZŁAP ODBITĄ FALĘ, ABY PRZYSPIESZYĆ"
	_generate_race(_next_random_seed())
	_set_race_state(RaceState.TITLE)
	_show_menu(MenuScreen.MAIN)


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
