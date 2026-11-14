extends SceneTree

const RACE_SCENE := preload("res://scenes/game/race.tscn")

func _initialize() -> void:
	var race := RACE_SCENE.instantiate()
	root.add_child(race)
	await physics_frame

	var player_one_world := race.get_node("Presentation/SplitScreen/TopContainer/TopViewport/PlayerOneWorld") as PlayerWorld
	var player_two_world := race.get_node("Presentation/SplitScreen/BottomContainer/BottomViewport/PlayerTwoWorld") as PlayerWorld
	var player_one_generator := player_one_world.get_node("CourseGenerator") as CourseGenerator
	var player_two_generator := player_two_world.get_node("CourseGenerator") as CourseGenerator
	var finish_area := player_one_world.get_node("FinishArea") as FinishArea
	var player_one := player_one_world.get_node("Player") as RezonansPlayer

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

	finish_area._on_body_entered(player_one)
	var winner_label := race.get_node("GlobalUi/Winner") as Label
	assert(winner_label.text.begins_with("PLAYER 1 WINS!"))
	print("Race shell check passed.")
	quit()
