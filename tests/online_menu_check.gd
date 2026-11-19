extends SceneTree

const RACE_SCENE := preload("res://scenes/game/race.tscn")


func _initialize() -> void:
	var race := RACE_SCENE.instantiate()
	root.add_child(race)
	await process_frame

	var menu := race.get_node("GlobalUi/TitlePanel") as MainMenu
	var room_code_input := menu.get_node("MenuOverlay/RoomCodeInput") as LineEdit
	assert(menu.get_option_text(0) == "GRAJ")
	assert(menu.get_option_text(1) == "GRA ONLINE")
	assert(menu.get_option_text(2) == "WYJDŹ")
	assert(not room_code_input.visible)

	_send_key(race, KEY_DOWN)
	_send_key(race, KEY_ENTER)
	assert(menu.get_option_text(0) == "SZYBKI MECZ")
	assert(menu.get_option_text(1) == "ZE ZNAJOMYM")

	_send_key(race, KEY_DOWN)
	_send_key(race, KEY_ENTER)
	assert(menu.get_option_text(0) == "STWÓRZ POKÓJ")
	assert(menu.get_option_text(1) == "DOŁĄCZ KODEM")

	_send_key(race, KEY_DOWN)
	_send_key(race, KEY_ENTER)
	assert(room_code_input.visible)
	assert(room_code_input.has_focus())

	_send_key(race, KEY_ESCAPE)
	assert(not room_code_input.visible)
	assert(menu.get_option_text(0) == "STWÓRZ POKÓJ")

	# ESC back to online screen
	_send_key(race, KEY_ESCAPE)
	assert(menu.get_option_text(0) == "SZYBKI MECZ")
	assert(menu.get_option_text(1) == "ZE ZNAJOMYM")

	# ESC back to main menu
	_send_key(race, KEY_ESCAPE)
	assert(menu.get_option_text(0) == "GRAJ")
	assert(menu.get_option_text(1) == "GRA ONLINE")
	assert(menu.get_option_text(2) == "WYJDŹ")

	# Test post-match finished state and return to normal main menu on ESC
	race._race_state = race.RaceState.RACING
	race._race_elapsed = 12.34
	race._on_player_finished(1)
	race._race_elapsed = 13.45
	race._on_player_finished(2)
	assert(race._race_state == race.RaceState.FINISHED)
	_send_key(race, KEY_ESCAPE)
	assert(race._race_state == race.RaceState.TITLE)
	assert(menu.get_option_text(0) == "GRAJ")
	assert(menu.get_option_text(1) == "GRA ONLINE")
	assert(menu.get_option_text(2) == "WYJDŹ")

	# Test _restart_course returns to normal main menu
	race._restart_course()
	assert(race._race_state == race.RaceState.TITLE)
	assert(menu.get_option_text(0) == "GRAJ")
	assert(menu.get_option_text(1) == "GRA ONLINE")
	assert(menu.get_option_text(2) == "WYJDŹ")

	# Test local rematch with R key starts countdown immediately on same seed
	race._race_state = race.RaceState.RACING
	var current_seed := int(race._seed)
	race._race_elapsed = 10.0
	race._on_player_finished(1)
	race._on_player_finished(2)
	assert(race._race_state == race.RaceState.FINISHED)
	var result_panel := race.get_node("GlobalUi/ResultPanel") as Control
	assert(result_panel.visible)
	var r_event := InputEventAction.new()
	r_event.action = &"restart"
	r_event.pressed = true
	race._input(r_event)
	assert(race._race_state == race.RaceState.COUNTDOWN)
	assert(not result_panel.visible)
	assert(int(race._seed) == current_seed)

	# Test local new course with N key starts countdown immediately on new seed
	race._race_state = race.RaceState.RACING
	race._race_elapsed = 11.0
	race._on_player_finished(1)
	race._on_player_finished(2)
	assert(race._race_state == race.RaceState.FINISHED)
	assert(result_panel.visible)
	var n_event := InputEventAction.new()
	n_event.action = &"new_seed"
	n_event.pressed = true
	race._input(n_event)
	assert(race._race_state == race.RaceState.COUNTDOWN)
	assert(not result_panel.visible)
	assert(int(race._seed) != current_seed)

	race.queue_free()
	await process_frame
	print("Online menu flow check passed.")
	quit()


func _send_key(race: Control, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	race._input(event)
