extends SceneTree

const RACE_SCENE := preload("res://scenes/game/race.tscn")


func _initialize() -> void:
	var race := RACE_SCENE.instantiate()
	race.countdown_duration = 3.0
	root.add_child(race)
	await physics_frame

	var player_world := race.get_node("PlayerWorld") as PlayerWorld
	var generator := player_world.get_node("CourseGenerator") as CourseGenerator
	var finish_area := player_world.get_node("FinishArea") as FinishArea
	var player := player_world.get_node("Player") as RezonansPlayer
	var overlay := player_world.get_node("EchoCanvas/EchoOverlay") as EchoOverlay

	assert(not race.has_node("Presentation/SplitScreen"))
	assert(race.get_node("PlayerWorld") == player_world)
	assert((race.get_node("GlobalUi/TitlePanel") as Control).visible)
	assert((race.get_node("GlobalUi/Timer") as Label).text == "CZAS  00:00.000")
	assert((race.get_node("GlobalUi/Seed") as Label).text == "SEED  %d" % generator.seed_value)
	assert(player_world.get_node("BlueprintCanvas/ParallaxGrid") is ParallaxGrid)
	assert(not player.is_physics_processing())
	assert(generator.get_node("GeneratedChunks").get_child_count() == 17)
	assert(not generator.mirror_horizontally)
	assert(player.global_position == generator.to_global(generator.player_spawn))
	assert(player.facing_direction == 1.0)
	assert((overlay.material as ShaderMaterial).get_shader_parameter("afterglow_color") == Color(0.72, 0.96, 1.0, 1.0))
	overlay.register_hit(player.global_position + Vector2.RIGHT * 96.0, Vector2.LEFT, 80.0)
	assert(overlay.get_active_echo_count() == 1)

	var initial_seed := generator.seed_value
	race._restart_course()
	assert(generator.seed_value == initial_seed)
	race._generate_new_course()
	assert(generator.seed_value != initial_seed)

	var start_event := InputEventKey.new()
	start_event.keycode = KEY_D
	start_event.pressed = true
	race._input(start_event)
	assert((race.get_node("GlobalUi/Countdown") as Label).visible)
	race._process(3.0)
	assert(not (race.get_node("GlobalUi/Countdown") as Label).visible)
	assert(player.is_physics_processing())

	var player_start_x := player.global_position.x
	Input.action_press(&"move_right")
	for frame in 20:
		await physics_frame
	Input.action_release(&"move_right")
	assert(player.global_position.x > player_start_x)

	race._toggle_pause()
	assert(paused)
	assert((race.get_node("GlobalUi/PausePanel") as Control).visible)
	race._toggle_pause()
	assert(not paused)
	assert(player.is_physics_processing())

	finish_area._on_body_entered(player)
	var timer_label := race.get_node("GlobalUi/Timer") as Label
	var times_label := race.get_node("GlobalUi/ResultPanel/Times") as Label
	assert((race.get_node("GlobalUi/ResultPanel") as Control).visible)
	assert(not (race.get_node("GlobalUi/FinishStatus") as Label).visible)
	assert((race.get_node("GlobalUi/ResultPanel/Winner") as Label).text == "META!")
	assert(times_label.text == "TWÓJ CZAS  %s" % race._format_time(race._finish_time))
	assert(not player.is_physics_processing())
	var finish_time := timer_label.text
	race._process(1.0)
	assert(timer_label.text == finish_time)

	race.queue_free()
	for frame in 60:
		await process_frame
	print("Race shell and start flow check passed.")
	quit()
