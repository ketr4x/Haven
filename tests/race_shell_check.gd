extends SceneTree

const RACE_SCENE := preload("res://scenes/game/race.tscn")

func _initialize() -> void:
	var race := RACE_SCENE.instantiate()
	root.add_child(race)
	await physics_frame

	var player_one := race.get_node("SharedSimulation/PlayerOne") as RezonansPlayer
	var player_two := race.get_node("SharedSimulation/PlayerTwo") as RezonansPlayer
	var finish_area := race.get_node("SharedSimulation/FinishArea") as FinishArea
	var top_viewport := race.get_node("Presentation/SplitScreen/TopContainer/TopViewport") as SubViewport
	var bottom_viewport := race.get_node("Presentation/SplitScreen/BottomContainer/BottomViewport") as SubViewport

	assert(top_viewport.world_2d == root.get_viewport().world_2d)
	assert(bottom_viewport.world_2d == root.get_viewport().world_2d)
	assert(player_one.collision_layer == player_two.collision_layer)
	assert((player_one.collision_mask & player_two.collision_layer) == 0)

	finish_area._on_body_entered(player_one)

	var winner_label := race.get_node("GlobalUi/Winner") as Label
	assert(winner_label.text.begins_with("PLAYER 1 WINS!"))
	print("Race shell check passed.")
	quit()
