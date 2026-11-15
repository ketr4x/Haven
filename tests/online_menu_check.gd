extends SceneTree

const RACE_SCENE := preload("res://scenes/game/race.tscn")


func _initialize() -> void:
	var race := RACE_SCENE.instantiate()
	root.add_child(race)
	await process_frame

	var prompt := race.get_node("GlobalUi/TitlePanel/Prompt") as Label
	var room_code_input := race.get_node("GlobalUi/TitlePanel/RoomCodeInput") as LineEdit
	assert(prompt.text.contains("GRA LOKALNA"))
	assert(prompt.text.contains("GRA ONLINE"))
	assert(not room_code_input.visible)

	_send_key(race, KEY_DOWN)
	_send_key(race, KEY_ENTER)
	assert(prompt.text.contains("SZYBKI MECZ"))
	assert(prompt.text.contains("ZE ZNAJOMYM"))

	_send_key(race, KEY_DOWN)
	_send_key(race, KEY_ENTER)
	assert(prompt.text.contains("STWÓRZ POKÓJ"))
	assert(prompt.text.contains("DOŁĄCZ KODEM"))

	_send_key(race, KEY_DOWN)
	_send_key(race, KEY_ENTER)
	assert(room_code_input.visible)
	assert(room_code_input.has_focus())

	_send_key(race, KEY_ESCAPE)
	assert(not room_code_input.visible)
	assert(prompt.text.contains("STWÓRZ POKÓJ"))

	race.queue_free()
	await process_frame
	print("Online menu flow check passed.")
	quit()


func _send_key(race: Control, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	race._input(event)
