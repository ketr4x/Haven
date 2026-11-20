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

	var title_panel := race.get_node("GlobalUi/TitlePanel") as MainMenu
	var menu_sprite := title_panel.get_node("BackgroundSprite") as AnimatedSprite2D
	var moon_light := menu_sprite.get_node_or_null("MoonLight") as PointLight2D
	var moon_halo := menu_sprite.get_node_or_null("MoonHalo") as Sprite2D
	assert(moon_light != null and moon_light.texture != null)
	assert(moon_halo != null and moon_halo.texture != null)
	var wind_streaks := title_panel.get_node("WindStreaks") as CPUParticles2D
	var wind_dust := title_panel.get_node("WindDust") as CPUParticles2D
	assert(wind_streaks != null and wind_streaks.emitting)
	assert(wind_dust != null and wind_dust.emitting)
	var crt_overlay := race.get_node("CrtOverlay") as CrtOverlay
	assert(crt_overlay != null and crt_overlay.visible)
	var crt_rect := crt_overlay.get_node("CrtRect") as ColorRect
	assert(crt_rect != null and crt_rect.visible and crt_rect.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var crt_material := crt_overlay.get_shader_material()
	assert(crt_material != null and crt_material.shader != null)
	assert(is_equal_approx(float(crt_material.get_shader_parameter("curvature_x")), crt_overlay.curvature_x))
	assert(is_equal_approx(float(crt_material.get_shader_parameter("scanline_opacity")), crt_overlay.scanline_opacity))
	assert(is_equal_approx(float(crt_material.get_shader_parameter("mask_intensity")), crt_overlay.mask_intensity))
	assert(is_equal_approx(float(crt_material.get_shader_parameter("aberration_offset")), crt_overlay.aberration_offset))
	assert(is_equal_approx(float(crt_material.get_shader_parameter("bloom_intensity")), crt_overlay.bloom_intensity))
	var bg_one := player_one_world.get_node("Background") as Polygon2D
	var dust_one := player_one_world.get_node("DustParticles") as CPUParticles2D
	assert(bg_one.color.is_equal_approx(Color(0.129412, 0.14902, 0.247059, 1.0)))
	assert(dust_one != null and dust_one.emitting)
	assert(title_panel.visible)
	assert(not title_panel.is_playing_outro())
	assert(title_panel.get_selected_index() == 0)
	assert(menu_sprite.animation == &"idle")
	assert(menu_sprite.sprite_frames.get_frame_count(&"idle") == 11)
	assert(menu_sprite.sprite_frames.get_frame_count(&"outro") == 8)
	assert((title_panel.get_node("MenuOverlay") as Control).visible)
	assert((race.get_node("GlobalUi/PlayerOneTimer") as Label).text == "CZAS  00:00.000")
	assert((race.get_node("GlobalUi/PlayerTwoTimer") as Label).text == "CZAS  00:00.000")
	assert(not player_one.is_physics_processing())
	assert(player_one_world != player_two_world)
	assert(player_one_generator != player_two_generator)
	assert(player_one_generator.seed_value == player_two_generator.seed_value)
	assert(player_one_generator.course_signature == player_two_generator.course_signature)
	var initial_seed := player_one_generator.seed_value
	race._restart_course()
	assert(player_one_generator.seed_value != initial_seed)
	assert(player_one_generator.seed_value == player_two_generator.seed_value)
	assert(player_one_generator.course_signature == player_two_generator.course_signature)
	assert(player_one_generator.get_node("GeneratedChunks").get_child_count() == 17)
	assert(player_two_generator.get_node("GeneratedChunks").get_child_count() == 17)
	assert(not player_one_generator.mirror_horizontally)
	assert(not player_two_generator.mirror_horizontally)
	var player_two_start_chunk := player_two_generator.get_node("GeneratedChunks").get_child(0) as CourseChunk
	var player_two_start_terrain := player_two_start_chunk.get_node("Terrain") as TileMapLayer
	for cell in player_two_start_chunk.terrain_cells:
		assert(player_two_start_terrain.get_cell_source_id(cell) == 0)
	var player_two := player_two_world.get_node("Player") as RezonansPlayer
	var player_one_overlay := player_one_world.get_node("EchoCanvas/EchoOverlay") as EchoOverlay
	var player_two_overlay := player_two_world.get_node("EchoCanvas/EchoOverlay") as EchoOverlay
	assert(player_one.global_position == player_one_generator.to_global(player_one_generator.player_spawn))
	assert(player_two.global_position == player_two_generator.to_global(player_two_generator.player_spawn))
	var player_one_distance := player_one_finish_area.global_position.x - player_one.global_position.x
	var player_two_distance := player_two_finish_area.global_position.x - player_two.global_position.x
	assert(player_one_distance > 0.0)
	assert(player_two_distance > 0.0)
	assert(is_equal_approx(player_one_distance, player_two_distance))
	assert(player_one.facing_direction == 1.0)
	assert(player_two.facing_direction == 1.0)
	assert((player_two.get_node("FacingMarker") as Polygon2D).scale.x == 1.0)
	assert(player_one_overlay.material != player_two_overlay.material)
	assert((player_one_overlay.material as ShaderMaterial).get_shader_parameter("player_color") == player_one.modulate)
	assert((player_two_overlay.material as ShaderMaterial).get_shader_parameter("player_color") == player_two.modulate)
	player_one_overlay.trigger(60.0)
	assert(float((player_one_overlay.material as ShaderMaterial).get_shader_parameter("reveal_strength")) > 0.0)
	assert(is_zero_approx(float((player_two_overlay.material as ShaderMaterial).get_shader_parameter("reveal_strength"))))

	var down_event := InputEventAction.new()
	down_event.action = &"ui_down"
	down_event.pressed = true
	race._input(down_event)
	assert(title_panel.get_selected_index() == 1)

	var up_event := InputEventAction.new()
	up_event.action = &"ui_up"
	up_event.pressed = true
	race._input(up_event)
	assert(title_panel.get_selected_index() == 0)

	var start_event := InputEventAction.new()
	start_event.action = &"ui_accept"
	start_event.pressed = true
	race._input(start_event)
	assert(title_panel.get_option_text(0) == "JEDEN GRACZ")
	assert(title_panel.get_option_text(1) == "DWÓCH GRACZY")

	var mode_down_event := InputEventAction.new()
	mode_down_event.action = &"ui_down"
	mode_down_event.pressed = true
	race._input(mode_down_event)
	assert(title_panel.get_selected_index() == 1)

	var confirm_event := InputEventAction.new()
	confirm_event.action = &"ui_accept"
	confirm_event.pressed = true
	race._input(confirm_event)
	assert(title_panel.visible)
	assert(title_panel.is_playing_outro())
	assert(menu_sprite.animation == &"outro")
	assert(not (title_panel.get_node("MenuOverlay") as Control).visible)
	assert(not (race.get_node("GlobalUi/Countdown") as Label).visible)
	await title_panel.outro_finished
	var transition_rect := race.get_node("TransitionLayer/TransitionRect") as ColorRect
	assert(transition_rect.visible)
	assert(title_panel.visible)
	assert(not (race.get_node("GlobalUi/Countdown") as Label).visible)
	await race.countdown_started
	assert(not title_panel.visible)
	assert(not title_panel.is_playing_outro())
	assert((race.get_node("GlobalUi/Countdown") as Label).visible)
	await race.transition_finished
	assert(not transition_rect.visible)
	race._process(3.0)
	assert(not (race.get_node("GlobalUi/Countdown") as Label).visible)
	assert(player_one.is_physics_processing())

	var player_one_start_x := player_one.global_position.x
	var player_two_start_x := player_two.global_position.x
	Input.action_press(&"p1_right")
	Input.action_press(&"p2_right")
	for frame in 20:
		await physics_frame
	Input.action_release(&"p1_right")
	Input.action_release(&"p2_right")
	assert(player_one.global_position.x > player_one_start_x)
	assert(player_two.global_position.x > player_two_start_x)

	player_two.rebound_boost_started.connect(_on_player_two_boost_started)
	player_two_world._on_player_pulsed(player_two.global_position, Vector2.RIGHT, 60.0, 16)
	for frame in 120:
		await physics_frame
		if _player_two_boost_started:
			break
	assert(_player_two_boost_started)
	assert(float((player_two_overlay.material as ShaderMaterial).get_shader_parameter("reveal_strength")) > 0.0)

	race._toggle_pause()
	assert(paused)
	assert((race.get_node("GlobalUi/PausePanel") as Control).visible)
	assert(race._pause_selected_index == 0)
	var pause_down := InputEventAction.new()
	pause_down.action = &"ui_down"
	pause_down.pressed = true
	race._input(pause_down)
	assert(race._pause_selected_index == 1)
	var pause_up := InputEventAction.new()
	pause_up.action = &"ui_up"
	pause_up.pressed = true
	race._input(pause_up)
	assert(race._pause_selected_index == 0)
	race._toggle_pause()
	assert(not paused)
	assert(player_one.is_physics_processing())

	var invert_rect := race.get_node("InvertLayer/InvertFlashRect") as ColorRect
	assert(invert_rect != null and not invert_rect.visible)
	player_one_finish_area._on_body_entered(player_one)
	assert(invert_rect.visible)
	assert(is_equal_approx(float((invert_rect.material as ShaderMaterial).get_shader_parameter(&"intensity")), 1.0))
	var p1_banner := race.get_node("GlobalUi/PlayerOneFinishBanner") as Control
	assert(p1_banner != null and p1_banner.visible)
	assert((p1_banner.get_node("Place") as Label).text == "1. MIEJSCE")
	assert((p1_banner.get_node("Time") as Label).text.begins_with("CZAS  "))
	var player_one_timer_label := race.get_node("GlobalUi/PlayerOneTimer") as Label
	var player_two_timer_label := race.get_node("GlobalUi/PlayerTwoTimer") as Label
	var finish_status_label := race.get_node("GlobalUi/FinishStatus") as Label
	assert(not (race.get_node("GlobalUi/ResultPanel") as Control).visible)
	assert(finish_status_label.visible)
	assert(finish_status_label.text == "GRACZ 1 NA MECIE. DRUGI GRACZ JEDZIE DALEJ.")
	assert(not player_one.is_physics_processing())
	assert(player_two.is_physics_processing())
	var player_one_time := player_one_timer_label.text
	race._process(1.0)
	assert(player_one_timer_label.text == player_one_time)
	assert(player_two_timer_label.text != player_one_time)

	player_two_finish_area._on_body_entered(player_two)
	var winner_label := race.get_node("GlobalUi/ResultPanel/Winner") as Label
	var placement_label := race.get_node("GlobalUi/ResultPanel/PlacementSummary") as Label
	var times_label := race.get_node("GlobalUi/ResultPanel/Times") as Label
	assert((race.get_node("GlobalUi/ResultPanel") as Control).visible)
	assert(not finish_status_label.visible)
	assert(not p1_banner.visible)
	assert(winner_label.text == "WYGRYWA GRACZ 1")
	assert("1. MIEJSCE" in placement_label.text and "2. MIEJSCE" in placement_label.text)
	assert(times_label.text == "GRACZ 1  %s\nGRACZ 2  %s" % [
		race._format_time(float(race._player_finish_times[1])),
		race._format_time(float(race._player_finish_times[2])),
	])
	assert(not player_two.is_physics_processing())
	await create_timer(0.35).timeout
	assert(not invert_rect.visible)
	race.queue_free()
	for frame in 60:
		await process_frame
	print("Race shell and start flow check passed.")
	quit()


func _on_player_two_boost_started() -> void:
	_player_two_boost_started = true
