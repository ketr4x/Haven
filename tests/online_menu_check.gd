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

	race.queue_free()
	await process_frame
	print("Online menu flow check passed.")
	quit()


func _send_key(race: Control, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	race._input(event)
