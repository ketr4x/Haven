extends SceneTree

const RACE_SCENE := preload("res://scenes/game/race.tscn")

func _initialize() -> void:
	var race := RACE_SCENE.instantiate()
	race.countdown_duration = 3.0
	root.add_child(race)
	await physics_frame

	var player_one_world := race.get_node("Presentation/SplitScreen/TopContainer/TopViewport/PlayerOneWorld") as PlayerWorld
	var player_two_world := race.get_node("Presentation/SplitScreen/BottomContainer/BottomViewport/PlayerTwoWorld") as PlayerWorld
	var player_one_generator := player_one_world.get_node("CourseGenerator") as CourseGenerator
	var player_two_generator := player_two_world.get_node("CourseGenerator") as CourseGenerator
	var finish_area := player_one_world.get_node("FinishArea") as FinishArea
	var player_one := player_one_world.get_node("Player") as RezonansPlayer

	assert((race.get_node("GlobalUi/TitlePanel") as Control).visible)
	assert(not player_one.is_physics_processing())
	assert(player_one_world != player_two_world)
	assert(player_one_generator != player_two_generator)
	assert(player_one_generator.seed_value == player_two_generator.seed_value)
	assert(player_one_generator.course_signature == player_two_generator.course_signature)
	var player_two := player_two_world.get_node("Player") as RezonansPlayer
	var player_one_overlay := player_one_world.get_node("EchoCanvas/EchoOverlay") as EchoOverlay
	var player_two_overlay := player_two_world.get_node("EchoCanvas/EchoOverlay") as EchoOverlay
	assert(player_one.global_position == player_one_generator.global_position + player_one_generator.player_spawn)
	assert(player_two.global_position == player_two_generator.global_position + player_two_generator.player_spawn)
	assert(player_one_overlay.material != player_two_overlay.material)
	player_one_overlay.trigger(60.0)
	assert(float((player_one_overlay.material as ShaderMaterial).get_shader_parameter("reveal_strength")) > 0.0)
	assert(is_zero_approx(float((player_two_overlay.material as ShaderMaterial).get_shader_parameter("reveal_strength"))))

	var start_event := InputEventAction.new()
	start_event.action = &"p1_shout"
	start_event.pressed = true
	race._unhandled_input(start_event)
	assert((race.get_node("GlobalUi/Countdown") as Label).visible)
	race._process(3.0)
	assert(not (race.get_node("GlobalUi/Countdown") as Label).visible)
	assert(player_one.is_physics_processing())

	race._toggle_pause()
	assert(paused)
	assert((race.get_node("GlobalUi/PausePanel") as Control).visible)
	race._toggle_pause()
	assert(not paused)
	assert(player_one.is_physics_processing())

	finish_area._on_body_entered(player_one)
	var winner_label := race.get_node("GlobalUi/ResultPanel/Winner") as Label
	assert((race.get_node("GlobalUi/ResultPanel") as Control).visible)
	assert(winner_label.text == "WYGRYWA GRACZ 1")
	assert(not player_one.is_physics_processing())
	print("Race shell and start flow check passed.")
	quit()
