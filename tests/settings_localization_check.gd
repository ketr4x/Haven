extends SceneTree

const RACE_SCENE := preload("res://scenes/game/race.tscn")
const TEMP_SETTINGS_PATH := "user://test_settings_localization.cfg"


func _initialize() -> void:
	var settings := root.get_node_or_null("GameSettings") as GameSettingsNode
	assert(settings != null, "GameSettings autoload must be registered")
	settings.reset_to_defaults(false)

	# Default language must be English
	assert(settings.language == "en")
	assert(TranslationServer.get_locale() == "en")

	var race := RACE_SCENE.instantiate()
	root.add_child(race)
	await process_frame

	var menu := race.get_node("GlobalUi/TitlePanel") as MainMenu
	var crt_overlay := race.get_node("CrtOverlay") as CrtOverlay
	var p1_label := race.get_node("GlobalUi/PlayerOneLabel") as Label
	var p2_label := race.get_node("GlobalUi/PlayerTwoLabel") as Label
	var p1_timer := race.get_node("GlobalUi/PlayerOneTimer") as Label
	var pause_title := race.get_node("GlobalUi/PausePanel/Title") as Label
	var pause_resume := race.get_node("GlobalUi/PausePanel/MenuItems/ResumeOption/Text") as Label
	var pause_settings := race.get_node("GlobalUi/PausePanel/MenuItems/SettingsOption/Text") as Label
	var pause_menu := race.get_node("GlobalUi/PausePanel/MenuItems/MenuOption/Text") as Label

	# Verify English defaults on Main Menu, HUD, Pause, and Finish gate
	assert(menu.get_option_text(0) == "PLAY")
	assert(menu.get_option_text(1) == "ONLINE")
	assert(menu.get_option_text(2) == "SETTINGS")
	assert(menu.get_option_text(3) == "QUIT")
	assert(p1_label.text == "PLAYER 1")
	assert(p2_label.text == "PLAYER 2")
	assert(p1_timer.text == "TIME  00:00.000")
	assert(pause_title.text == "PAUSE")
	assert(pause_resume.text == "RESUME")
	assert(pause_settings.text == "SETTINGS")
	assert(pause_menu.text == "MAIN MENU")
	assert(crt_overlay.visible)

	var p1_chunks := race.get_node("Presentation/SplitScreen/TopContainer/TopViewport/PlayerOneWorld/CourseGenerator/GeneratedChunks")
	var finish_chunk := p1_chunks.get_child(p1_chunks.get_child_count() - 1)
	var finish_label := finish_chunk.get_node("Label") as Label
	assert(finish_label.text == "FINISH")

	# Open Settings from Main Menu (index 2)
	_send_action(race, &"ui_down")
	_send_action(race, &"ui_down")
	assert(menu.get_selected_index() == 2)
	_send_action(race, &"ui_accept")
	assert(menu.get_option_text(0) == "LANGUAGE:  < ENGLISH >")
	assert(menu.get_option_text(1) == "VOLUME:  < 100% >")
	assert(menu.get_option_text(2) == "CRT FILTER:  < ON >")
	assert(menu.get_option_text(3) == "FULLSCREEN:  < OFF >")
	assert(menu.get_option_text(4) == "BACK")

	# Switch Language to Polish via right arrow
	_send_action(race, &"ui_right")
	await process_frame
	assert(settings.language == "pl")
	assert(TranslationServer.get_locale() == "pl")
	assert(menu.get_selected_index() == 0)
	assert(menu.get_option_text(0) == "JĘZYK:  < POLSKI >")
	assert(menu.get_option_text(1) == "GŁOŚNOŚĆ:  < 100% >")
	assert(menu.get_option_text(2) == "FILTR CRT:  < WŁ. >")
	assert(menu.get_option_text(3) == "PEŁNY EKRAN:  < WYŁ. >")
	assert(menu.get_option_text(4) == "POWRÓT")
	assert(p1_label.text == "GRACZ 1")
	assert(p2_label.text == "GRACZ 2")
	assert(p1_timer.text == "CZAS  00:00.000")
	assert(finish_label.text == "META")
	assert(pause_title.text == "PAUZA")
	assert(pause_resume.text == "WRÓĆ DO GRY")
	assert(pause_settings.text == "USTAWIENIA")
	assert(pause_menu.text == "WYJDŹ DO MENU")

	# Adjust Volume down to 80% via left arrow
	_send_action(race, &"ui_down")
	assert(menu.get_selected_index() == 1)
	_send_action(race, &"ui_left")
	_send_action(race, &"ui_left")
	assert(settings.master_volume == 80)
	assert(menu.get_option_text(1) == "GŁOŚNOŚĆ:  < 80% >")
	var master_bus := AudioServer.get_bus_index(&"Master")
	assert(not AudioServer.is_bus_mute(master_bus))

	# Toggle CRT filter OFF via Enter
	_send_action(race, &"ui_down")
	assert(menu.get_selected_index() == 2)
	_send_action(race, &"ui_accept")
	assert(not settings.crt_enabled)
	assert(not crt_overlay.visible)
	assert(menu.get_option_text(2) == "FILTR CRT:  < WYŁ. >")

	# Toggle Fullscreen ON via right arrow
	_send_action(race, &"ui_down")
	assert(menu.get_selected_index() == 3)
	_send_action(race, &"ui_right")
	assert(settings.fullscreen)
	assert(menu.get_option_text(3) == "PEŁNY EKRAN:  < WŁ. >")

	# Select BACK -> returns to Polish Main Menu
	_send_action(race, &"ui_down")
	assert(menu.get_selected_index() == 4)
	_send_action(race, &"ui_accept")
	assert(menu.get_option_text(0) == "GRAJ")
	assert(menu.get_option_text(1) == "GRA ONLINE")
	assert(menu.get_option_text(2) == "USTAWIENIA")
	assert(menu.get_option_text(3) == "WYJDŹ")

	# Test Settings from Pause Menu during a race
	race._set_race_state(race.RaceState.RACING)
	race._toggle_pause()
	assert(paused)
	assert(race._pause_selected_index == 0)
	_send_action(race, &"ui_down")
	assert(race._pause_selected_index == 1)
	_send_action(race, &"ui_accept")
	assert(race._pause_in_settings)
	assert(pause_title.text == "USTAWIENIA")

	# Switch back to English inside Pause Settings
	_send_action(race, &"ui_accept")
	await process_frame
	assert(settings.language == "en")
	assert(pause_title.text == "SETTINGS")
	assert(p1_label.text == "PLAYER 1")
	assert(finish_label.text == "FINISH")

	# Turn CRT back ON inside Pause Settings
	_send_action(race, &"ui_down")
	_send_action(race, &"ui_down")
	assert(race._pause_settings_selected_index == 2)
	_send_action(race, &"ui_accept")
	assert(settings.crt_enabled)
	assert(crt_overlay.visible)

	# ESC from Pause Settings returns to Pause Menu (stays paused)
	_send_action(race, &"ui_cancel")
	assert(not race._pause_in_settings)
	assert(paused)
	assert(pause_title.text == "PAUSE")

	# ESC from Pause Menu resumes race
	_send_action(race, &"pause")
	assert(not paused)

	# Test ConfigFile save / load persistence
	settings.set_language("pl", false)
	settings.set_master_volume(40, false)
	settings.set_crt_enabled(false, false)
	settings.set_fullscreen(true, false)
	assert(settings.save_settings(TEMP_SETTINGS_PATH) == OK)

	settings.reset_to_defaults(false)
	assert(settings.language == "en")
	assert(settings.master_volume == 100)
	assert(settings.crt_enabled)
	assert(not settings.fullscreen)

	assert(settings.load_settings(TEMP_SETTINGS_PATH) == OK)
	assert(settings.language == "pl")
	assert(settings.master_volume == 40)
	assert(not settings.crt_enabled)
	assert(settings.fullscreen)

	# Test muting at 0% volume
	settings.set_master_volume(0, false)
	assert(AudioServer.is_bus_mute(master_bus))

	# Clean up temp settings file and restore defaults
	var abs_temp := ProjectSettings.globalize_path(TEMP_SETTINGS_PATH)
	if FileAccess.file_exists(TEMP_SETTINGS_PATH):
		DirAccess.remove_absolute(abs_temp)
	settings.reset_to_defaults(false)

	race.queue_free()
	await process_frame
	print("Settings and localization check passed.")
	quit()


func _send_action(target: Control, action_name: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	target._input(event)
