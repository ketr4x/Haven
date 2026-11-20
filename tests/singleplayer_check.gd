extends SceneTree

const LOCAL_MATCH_SERVICE := preload("res://scripts/online/local_match_service.gd")
const RACE_SCENE := preload("res://scenes/game/race.tscn")


func _initialize() -> void:
	var service := LOCAL_MATCH_SERVICE.new() as LocalMatchService
	root.add_child(service)

	var race := RACE_SCENE.instantiate()
	race.online_service = service
	race.countdown_duration = 3.0
	root.add_child(race)
	await physics_frame
	race.set_leaderboard_service(service)

	var title_panel := race.get_node("GlobalUi/TitlePanel") as MainMenu
	var top_container := race.get_node("Presentation/SplitScreen/TopContainer") as SubViewportContainer
	var bottom_container := race.get_node("Presentation/SplitScreen/BottomContainer") as SubViewportContainer
	var divider := race.get_node("Presentation/SplitScreen/Divider") as ColorRect
	var p1_label := race.get_node("GlobalUi/PlayerOneLabel") as Label
	var p2_label := race.get_node("GlobalUi/PlayerTwoLabel") as Label
	var p1_timer := race.get_node("GlobalUi/PlayerOneTimer") as Label
	var p2_timer := race.get_node("GlobalUi/PlayerTwoTimer") as Label
	var result_panel := race.get_node("GlobalUi/ResultPanel") as Control
	var winner_label := race.get_node("GlobalUi/ResultPanel/Winner") as Label
	var times_label := race.get_node("GlobalUi/ResultPanel/Times") as Label
	var result_actions := race.get_node("GlobalUi/ResultPanel/Actions") as Label
	var leaderboard_section := race.get_node("GlobalUi/ResultPanel/LeaderboardSection") as Control
	var username_input := race.get_node("GlobalUi/ResultPanel/LeaderboardSection/UsernameInput") as LineEdit
	var leaderboard_status := race.get_node("GlobalUi/ResultPanel/LeaderboardSection/Status") as Label
	var player_one_world := race.get_node("Presentation/SplitScreen/TopContainer/TopViewport/PlayerOneWorld") as PlayerWorld
	var player_two_world := race.get_node("Presentation/SplitScreen/BottomContainer/BottomViewport/PlayerTwoWorld") as PlayerWorld
	var player_one := player_one_world.get_node("Player") as RezonansPlayer

	# 1. Main menu initial state
	assert(race._race_state == race.RaceState.TITLE)
	assert(title_panel.get_option_text(0) == "GRAJ")
	assert(title_panel.get_option_text(1) == "GRA ONLINE")
	assert(title_panel.get_option_text(2) == "WYJDŹ")

	# 2. Select "GRAJ" -> opens LOCAL_PLAY menu
	_send_action(race, &"ui_accept")
	assert(race._menu_screen == race.MenuScreen.LOCAL_PLAY)
	assert(title_panel.get_option_text(0) == "JEDEN GRACZ")
	assert(title_panel.get_option_text(1) == "DWÓCH GRACZY")

	# 3. Select "JEDEN GRACZ" (index 0)
	_send_action(race, &"ui_accept")
	assert(race._session_mode == race.SessionMode.SINGLEPLAYER)
	assert(race._race_state == race.RaceState.STARTING)
	assert(title_panel.is_playing_outro())

	# Check singleplayer presentation setup
	assert(is_equal_approx(top_container.anchor_bottom, 1.0))
	assert(is_equal_approx(top_container.offset_bottom, 0.0))
	assert(not bottom_container.visible)
	assert(not divider.visible)
	assert(p1_label.visible)
	assert(not p2_label.visible)
	assert(p1_timer.visible)
	assert(not p2_timer.visible)
	assert(not player_two_world.is_physics_processing())

	# 4. Await outro, countdown and transition
	await title_panel.outro_finished
	await race.countdown_started
	assert(race._race_state == race.RaceState.COUNTDOWN)
	await race.transition_finished
	race._process(3.0)
	assert(race._race_state == race.RaceState.RACING)
	assert(player_one.is_physics_processing())
	assert(not player_two_world.is_physics_processing())

	# Verify singleplayer vertical fairness vignette mask matches 2P split-screen visibility
	await process_frame
	var vignette_mat := player_one_world.vignette_rect.material as ShaderMaterial
	assert(vignette_mat != null)
	assert(is_equal_approx(float(vignette_mat.get_shader_parameter("vertical_mask_enabled")), 1.0))
	var sp_vp_size: Vector2 = vignette_mat.get_shader_parameter("viewport_size_px")
	var sp_ref_height: float = float(vignette_mat.get_shader_parameter("reference_height_px"))
	assert(is_equal_approx(sp_ref_height, maxf(1.0, sp_vp_size.y * 0.5 - 2.0)))
	assert(is_equal_approx(float(vignette_mat.get_shader_parameter("vertical_mask_outer")), 0.5))

	# 5. Verify controls: Primary (WASD) and Secondary (Arrow keys)
	var initial_x := player_one.global_position.x
	Input.action_press(&"p1_right")
	for f in 15:
		await physics_frame
	Input.action_release(&"p1_right")
	assert(player_one.global_position.x > initial_x)

	var second_x := player_one.global_position.x
	Input.action_press(&"p2_right") # Arrow key right
	for f in 15:
		await physics_frame
	Input.action_release(&"p2_right")
	assert(player_one.global_position.x > second_x)

	# 6. Test shout / scream
	var pre_shout_boost := player_one.is_rebound_boost_active()
	assert(not pre_shout_boost)
	Input.action_press(&"p1_shout")
	await physics_frame
	Input.action_release(&"p1_shout")
	assert(player_one.is_rebound_boost_active())

	# 7. Test singleplayer finish flow
	race._race_elapsed = 18.425
	race._on_player_finished(1)
	assert(race._race_state == race.RaceState.FINISHED)
	assert(result_panel.visible)
	assert(winner_label.text == "META!")
	assert("18.425" in times_label.text)
	assert("R  POWTÓRZ" in result_actions.text)
	assert(leaderboard_section.visible)
	assert(is_equal_approx(float(race._pending_leaderboard_time), 18.425))

	# 8. Test leaderboard submission in singleplayer mode
	username_input.text = "SoloRunner"
	username_input.text_submitted.emit(username_input.text)
	await process_frame
	assert(race._leaderboard_submitted)
	assert("ZAPISANO: SoloRunner" in leaderboard_status.text)
	var board: Array = service.leaderboards[OnlineServiceBase.DEFAULT_LEADERBOARD_NAME]
	assert(board[0]["data"]["mode"] == "singleplayer")

	# 9. Test rematch with R key: restarts on the same seed in singleplayer
	var current_seed := int(race._seed)
	var r_event := InputEventAction.new()
	r_event.action = &"restart"
	r_event.pressed = true
	race._input(r_event)
	assert(race._race_state == race.RaceState.COUNTDOWN)
	assert(race._session_mode == race.SessionMode.SINGLEPLAYER)
	assert(int(race._seed) == current_seed)
	assert(not bottom_container.visible)
	assert(not divider.visible)

	# 10. Test new course with N key: restarts on a new seed in singleplayer
	race._race_state = race.RaceState.FINISHED
	var n_event := InputEventAction.new()
	n_event.action = &"new_seed"
	n_event.pressed = true
	race._input(n_event)
	assert(race._race_state == race.RaceState.COUNTDOWN)
	assert(race._session_mode == race.SessionMode.SINGLEPLAYER)
	assert(int(race._seed) != current_seed)

	# 11. Test ESC returns to main menu and restores split screen presentation
	race._race_state = race.RaceState.FINISHED
	_send_action(race, &"pause")
	assert(race._race_state == race.RaceState.TITLE)
	assert(race._session_mode == race.SessionMode.LOCAL)
	assert(is_equal_approx(top_container.anchor_bottom, 0.5))
	assert(bottom_container.visible)
	assert(divider.visible)
	assert(p1_label.text == "GRACZ 1")
	assert(p2_label.text == "GRACZ 2")
	assert(p1_label.visible)
	assert(p2_label.visible)
	assert(p1_timer.visible)
	assert(p2_timer.visible)
	assert(title_panel.get_option_text(0) == "GRAJ")
	assert(title_panel.get_option_text(1) == "GRA ONLINE")
	assert(title_panel.get_option_text(2) == "WYJDŹ")
	await process_frame
	assert(is_equal_approx(float(vignette_mat.get_shader_parameter("vertical_mask_enabled")), 0.0))
	var split_vp_size: Vector2 = vignette_mat.get_shader_parameter("viewport_size_px")
	var split_ref_height: float = float(vignette_mat.get_shader_parameter("reference_height_px"))
	assert(is_equal_approx(split_ref_height, maxf(1.0, split_vp_size.y)))

	race.queue_free()
	for frame in 10:
		await process_frame
	quit()


func _send_action(target: Node, action_name: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	target._input(event)
