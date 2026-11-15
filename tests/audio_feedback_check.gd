extends SceneTree

const AUDIO_FEEDBACK_SCENE := preload("res://scenes/effects/audio_feedback.tscn")
const RACE_SCENE := preload("res://scenes/game/race.tscn")
const MAIN_MENU_SCENE := preload("res://scenes/game/main_menu.tscn")

func _initialize() -> void:
	# 1. Test AudioFeedback standalone scene and methods
	var audio_feedback := AUDIO_FEEDBACK_SCENE.instantiate() as AudioFeedback
	root.add_child(audio_feedback)
	await process_frame

	var required_nodes := [
		"Footstep", "Land", "Jump", "WallJump", "Shout",
		"WaveBounce", "EchoReturn", "Finish", "WallBreak",
		"Slide", "Boost", "ImpactStun", "Death"
	]
	for node_name in required_nodes:
		var player := audio_feedback.get_node_or_null(node_name) as AudioStreamPlayer
		assert(player != null, "Missing AudioStreamPlayer: %s" % node_name)
		assert(player.stream != null, "Missing stream for player: %s" % node_name)

	audio_feedback.play_footstep()
	audio_feedback.play_landing()
	audio_feedback.play_jump()
	audio_feedback.play_wall_jump()
	audio_feedback.play_shout()
	audio_feedback.play_wave_bounce(Vector2.ZERO, Vector2.UP, 1)
	audio_feedback.play_echo_return()
	audio_feedback.play_finish()
	audio_feedback.play_wall_break()
	audio_feedback.play_slide()
	audio_feedback.play_boost()
	audio_feedback.play_impact()
	audio_feedback.play_death()
	audio_feedback.queue_free()

	# 2. Test MainMenu UI audio nodes and methods
	var menu := MAIN_MENU_SCENE.instantiate() as MainMenu
	root.add_child(menu)
	await process_frame

	var ui_move := menu.get_node_or_null("UIMove") as AudioStreamPlayer
	var ui_select := menu.get_node_or_null("UISelect") as AudioStreamPlayer
	assert(ui_move != null and ui_move.stream != null, "MainMenu missing UIMove player")
	assert(ui_select != null and ui_select.stream != null, "MainMenu missing UISelect player")

	menu._play_ui_move()
	menu._play_ui_select()
	menu._move_selection(1)
	assert(menu.get_selected_index() == 1, "Menu move selection failed")
	menu.queue_free()

	# 3. Test Race audio nodes, countdown, and victory
	var race := RACE_SCENE.instantiate()
	race.countdown_duration = 2.0
	root.add_child(race)
	await physics_frame

	var countdown_tick := race.get_node_or_null("CountdownTick") as AudioStreamPlayer
	var countdown_go := race.get_node_or_null("CountdownGo") as AudioStreamPlayer
	var match_victory := race.get_node_or_null("MatchVictory") as AudioStreamPlayer
	assert(countdown_tick != null and countdown_tick.stream != null, "Race missing CountdownTick")
	assert(countdown_go != null and countdown_go.stream != null, "Race missing CountdownGo")
	assert(match_victory != null and match_victory.stream != null, "Race missing MatchVictory")

	# Test player world audio signal hooks
	var player_one_world := race.get_node("Presentation/SplitScreen/TopContainer/TopViewport/PlayerOneWorld") as PlayerWorld
	var p1_audio := player_one_world.get_node("AudioFeedback") as AudioFeedback
	assert(p1_audio != null, "PlayerOneWorld missing AudioFeedback")
	assert(p1_audio.get_node_or_null("Slide") != null, "PlayerOneWorld missing Slide audio")
	assert(p1_audio.get_node_or_null("Boost") != null, "PlayerOneWorld missing Boost audio")
	assert(p1_audio.get_node_or_null("ImpactStun") != null, "PlayerOneWorld missing ImpactStun audio")
	assert(p1_audio.get_node_or_null("Death") != null, "PlayerOneWorld missing Death audio")

	var player_one := player_one_world.get_node("Player") as RezonansPlayer
	player_one.slide_started.emit(Vector2.ZERO, Vector2.RIGHT)
	player_one.rebound_boost_started.emit()
	player_one.impact_stunned.emit(Vector2.ZERO)
	player_one.blind_impact_slowed.emit(Vector2.ZERO)
	player_one_world.player_died.emit(1)

	# Test countdown progression triggers tick and go
	race._start_countdown(2.0)
	assert(race._race_state == 2, "Expected RaceState.COUNTDOWN") # 2 = COUNTDOWN
	race._process(1.1)
	assert(race._countdown_label.text == "1", "Expected countdown label 1")
	race._process(1.1)
	assert(race._race_state == 3, "Expected RaceState.RACING") # 3 = RACING

	# Test match victory playback on finish
	race._set_race_state(5) # 5 = FINISHED
	assert(race._result_panel.visible, "Result panel should be visible")

	race.queue_free()
	for frame in 5:
		await process_frame

	print("All audio feedback checks passed successfully.")
	quit()
