extends SceneTree

const LOCAL_MATCH_SERVICE := preload("res://scripts/online/local_match_service.gd")
const RACE_SCENE := preload("res://scenes/game/race.tscn")


func _initialize() -> void:
	var service := LOCAL_MATCH_SERVICE.new() as LocalMatchService
	root.add_child(service)

	var race := RACE_SCENE.instantiate()
	race.online_service = service
	root.add_child(race)
	await physics_frame

	race.set_leaderboard_service(service)

	var player_one_world := race.get_node("Presentation/SplitScreen/TopContainer/TopViewport/PlayerOneWorld") as PlayerWorld
	var player_two_world := race.get_node("Presentation/SplitScreen/BottomContainer/BottomViewport/PlayerTwoWorld") as PlayerWorld
	var player_one_finish := player_one_world.get_node("FinishArea") as FinishArea
	var player_two_finish := player_two_world.get_node("FinishArea") as FinishArea
	var player_one := player_one_world.get_node("Player") as RezonansPlayer
	var player_two := player_two_world.get_node("Player") as RezonansPlayer

	var leaderboard_section := race.get_node("GlobalUi/ResultPanel/LeaderboardSection") as Control
	var username_input := leaderboard_section.get_node("UsernameInput") as LineEdit
	var status_label := leaderboard_section.get_node("Status") as Label
	var entries_label := leaderboard_section.get_node("BoardPanel/BoardEntries") as Label
	assert(not leaderboard_section.visible)

	# Simulate an offline race completing
	race._set_race_state(race.RaceState.RACING)
	race._race_elapsed = 14.25
	player_one_finish._on_body_entered(player_one)
	race._race_elapsed = 16.50
	player_two_finish._on_body_entered(player_two)

	assert((race.get_node("GlobalUi/ResultPanel") as Control).visible)
	assert(leaderboard_section.visible)
	assert(username_input.visible and username_input.editable)
	assert(username_input.has_focus())

	# A GD-Sync connection failure during leaderboard lookup must never hijack local race results
	service.connection_failed.emit("GD-Sync connection failed with error 0.")
	await process_frame
	assert(race._online_match.state == OnlineMatch.MatchState.IDLE)
	assert((race.get_node("GlobalUi/ResultPanel/Winner") as Label).text == "PLAYER 1 WINS")
	assert(leaderboard_section.visible)

	# While typing in the username field, pressing R should not restart the course
	var seed_before := int(race._seed)
	var r_key := InputEventKey.new()
	r_key.keycode = KEY_R
	r_key.pressed = true
	race._input(r_key)
	assert(int(race._seed) == seed_before)
	assert(race._race_state == race.RaceState.FINISHED)

	# Submit winner's username and time to the global leaderboard
	username_input.text = "EchoRunner"
	username_input.text_submitted.emit(username_input.text)
	await process_frame

	assert(race._leaderboard_submitted)
	assert(not username_input.editable)
	assert("SAVED: EchoRunner" in status_label.text)
	assert("1. EchoRunner" in entries_label.text)
	assert("00:14.250" in entries_label.text)

	# Simulate an online race completing and prompting for username
	race._session_mode = race.SessionMode.ONLINE
	race._online_match.player_slot = 2
	race._on_online_match_finished({1: 15.0, 2: 11.75}, 2)
	await process_frame

	assert(leaderboard_section.visible)
	assert(username_input.editable)
	assert(username_input.text == "EchoRunner")
	assert(is_equal_approx(float(race._pending_leaderboard_time), 11.75))

	username_input.text = "FasterPeer"
	var accept_event := InputEventAction.new()
	accept_event.action = &"ui_accept"
	accept_event.pressed = true
	race._input(accept_event)
	await process_frame

	assert(race._leaderboard_submitted)
	assert("1. FasterPeer" in entries_label.text)
	assert("00:11.750" in entries_label.text)
	assert("2. EchoRunner" in entries_label.text)

	# Simulate another race where FasterPeer submits a second run with a new time
	race._on_online_match_finished({1: 16.0, 2: 9.50}, 2)
	await process_frame
	assert(username_input.editable)
	assert(username_input.text == "FasterPeer")
	username_input.text_submitted.emit("FasterPeer")
	await process_frame

	assert(race._leaderboard_submitted)
	assert("1. FasterPeer" in entries_label.text)
	assert("00:09.500" in entries_label.text)
	assert("2. FasterPeer" in entries_label.text)
	assert("00:11.750" in entries_label.text)
	assert("3. EchoRunner" in entries_label.text)
	assert("00:14.250" in entries_label.text)

	race.queue_free()
	service.queue_free()
	for frame in 10:
		await process_frame
	print("Leaderboard flow check passed.")
	quit()
