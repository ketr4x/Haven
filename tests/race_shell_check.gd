extends SceneTree

const RACE_SCENE := preload("res://scenes/game/race.tscn")

var _player_two_boost_started: bool = false

func _initialize() -> void:
	var race := RACE_SCENE.instantiate()
	race.countdown_duration = 3.0
	root.add_child(race)
	await physics_frame

	var player_one_world := race.get_node("Presentation/SplitScreen/TopContainer/TopViewport/PlayerOneWorld") as PlayerWorld
	var player_two_world := race.get_node("Presentation/SplitScreen/BottomContainer/BottomViewport/PlayerTwoWorld") as PlayerWorld
	var player_one_generator := player_one_world.get_node("CourseGenerator") as CourseGenerator
	var player_two_generator := player_two_world.get_node("CourseGenerator") as CourseGenerator
	var player_one_finish_area := player_one_world.get_node("FinishArea") as FinishArea
	var player_two_finish_area := player_two_world.get_node("FinishArea") as FinishArea
	var player_one := player_one_world.get_node("Player") as RezonansPlayer

	assert((race.get_node("GlobalUi/TitlePanel") as Control).visible)
	assert(not player_one.is_physics_processing())
	assert(player_one_world != player_two_world)
	assert(player_one_generator != player_two_generator)
	assert(player_one_generator.seed_value == player_two_generator.seed_value)
	assert(player_one_generator.course_signature == player_two_generator.course_signature)
	assert(player_one_generator.get_node("GeneratedChunks").get_child_count() == 17)
	assert(player_two_generator.get_node("GeneratedChunks").get_child_count() == 17)
	assert(not player_one_generator.mirror_horizontally)
	assert(player_two_generator.mirror_horizontally)
	var player_two_start_chunk := player_two_generator.get_node("GeneratedChunks").get_child(0) as CourseChunk
	var player_two_start_terrain := player_two_start_chunk.get_node("Terrain") as TileMapLayer
	for cell in player_two_start_chunk.terrain_cells:
		assert(player_two_start_terrain.get_cell_source_id(Vector2i(-cell.x, cell.y)) == 0)
	var player_two := player_two_world.get_node("Player") as RezonansPlayer
	var player_one_overlay := player_one_world.get_node("EchoCanvas/EchoOverlay") as EchoOverlay
	var player_two_overlay := player_two_world.get_node("EchoCanvas/EchoOverlay") as EchoOverlay
	assert(player_one.global_position == player_one_generator.to_global(player_one_generator.player_spawn))
	assert(player_two.global_position == player_two_generator.to_global(player_two_generator.player_spawn))
	var player_one_distance := player_one_finish_area.global_position.x - player_one.global_position.x
	var player_two_distance := player_two_finish_area.global_position.x - player_two.global_position.x
	assert(player_one_distance > 0.0)
	assert(player_two_distance < 0.0)
	assert(is_equal_approx(player_one_distance, -player_two_distance))
	assert(player_one.facing_direction == 1.0)
	assert(player_two.facing_direction == -1.0)
	assert((player_two.get_node("FacingMarker") as Polygon2D).scale.x == -1.0)
	assert(player_one_overlay.material != player_two_overlay.material)
	assert((player_one_overlay.material as ShaderMaterial).get_shader_parameter("player_color") == player_one.modulate)
	assert((player_two_overlay.material as ShaderMaterial).get_shader_parameter("player_color") == player_two.modulate)
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

	var player_one_start_x := player_one.global_position.x
	var player_two_start_x := player_two.global_position.x
	Input.action_press(&"p1_right")
	Input.action_press(&"p2_left")
	for frame in 20:
		await physics_frame
	Input.action_release(&"p1_right")
	Input.action_release(&"p2_left")
	assert(player_one.global_position.x > player_one_start_x)
	assert(player_two.global_position.x < player_two_start_x)

	player_two.rebound_boost_started.connect(_on_player_two_boost_started)
	player_two_world._on_player_pulsed(player_two.global_position, Vector2.LEFT, 60.0, 16)
	for frame in 120:
		await physics_frame
		if _player_two_boost_started:
			break
	assert(_player_two_boost_started)
	assert(float((player_two_overlay.material as ShaderMaterial).get_shader_parameter("reveal_strength")) > 0.0)

	race._toggle_pause()
	assert(paused)
	assert((race.get_node("GlobalUi/PausePanel") as Control).visible)
	race._toggle_pause()
	assert(not paused)
	assert(player_one.is_physics_processing())

	player_one_finish_area._on_body_entered(player_one)
	var winner_label := race.get_node("GlobalUi/ResultPanel/Winner") as Label
	assert((race.get_node("GlobalUi/ResultPanel") as Control).visible)
	assert(winner_label.text == "WYGRYWA GRACZ 1")
	assert(not player_one.is_physics_processing())
	print("Race shell and start flow check passed.")
	quit()


func _on_player_two_boost_started() -> void:
	_player_two_boost_started = true
