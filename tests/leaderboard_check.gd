extends SceneTree

const LOCAL_MATCH_SERVICE := preload("res://scripts/online/local_match_service.gd")
const GD_SYNC_ONLINE_SERVICE := preload("res://scripts/online/gd_sync_online_service.gd")
const RACE_SCENE := preload("res://scenes/game/race.tscn")


class FakeGdSyncClient extends Node:
	var descending: bool = true
	var records: Array = [] # [{ "Username": account_id, "Score": score_ms, "Data": dict }]
	var logged_in_account: String = ""
	var display_username: String = ""
	var fail_first_create_as_collision: bool = false
	var create_attempts: int = 0
	var browse_calls: Array = []
	var accounts: Dictionary = {}

	func account_is_logged_in() -> bool:
		return not logged_in_account.is_empty()

	func account_logout() -> int:
		logged_in_account = ""
		return 0

	func account_create(email: String, username: String, password: String) -> int:
		create_attempts += 1
		if fail_first_create_as_collision and create_attempts == 1:
			return ENUMS.ACCOUNT_CREATION_RESPONSE_CODE.USERNAME_ALREADY_EXISTS
		if accounts.has(email):
			return ENUMS.ACCOUNT_CREATION_RESPONSE_CODE.EMAIL_ALREADY_EXISTS
		accounts[email] = {"username": username, "password": password}
		return ENUMS.ACCOUNT_CREATION_RESPONSE_CODE.SUCCESS

	func account_login(email: String, password: String, _valid_time: float) -> Dictionary:
		if not accounts.has(email):
			return {"Code": ENUMS.ACCOUNT_LOGIN_RESPONSE_CODE.EMAIL_OR_PASSWORD_INCORRECT}
		var acct: Dictionary = accounts[email]
		if str(acct.get("password", "")) != password:
			return {"Code": ENUMS.ACCOUNT_LOGIN_RESPONSE_CODE.EMAIL_OR_PASSWORD_INCORRECT}
		logged_in_account = str(acct["username"])
		return {"Code": ENUMS.ACCOUNT_LOGIN_RESPONSE_CODE.SUCCESS, "Username": logged_in_account}

	func player_set_username(username: String) -> void:
		display_username = username

	func leaderboard_submit_score(_leaderboard: String, score: int, data: Dictionary) -> int:
		if logged_in_account.is_empty():
			return ENUMS.LEADERBOARD_SUBMIT_SCORE_RESPONSE_CODE.NOT_LOGGED_IN
		for i in records.size():
			if str((records[i] as Dictionary).get("Username", "")) == logged_in_account:
				records[i] = {"Username": logged_in_account, "Score": score, "Data": data.duplicate(true)}
				return ENUMS.LEADERBOARD_SUBMIT_SCORE_RESPONSE_CODE.SUCCESS
		records.append({"Username": logged_in_account, "Score": score, "Data": data.duplicate(true)})
		return ENUMS.LEADERBOARD_SUBMIT_SCORE_RESPONSE_CODE.SUCCESS

	func leaderboard_browse_scores(_leaderboard: String, page_size: int, page: int) -> Dictionary:
		browse_calls.append({"page_size": page_size, "page": page})
		if logged_in_account.is_empty():
			return {"Code": ENUMS.LEADERBOARD_BROWSE_SCORES_RESPONSE_CODE.NOT_LOGGED_IN, "FinalPage": 0, "Result": []}
		var ordered := records.duplicate(true)
		ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var sa := int(a.get("Score", 0))
			var sb := int(b.get("Score", 0))
			if sa != sb:
				return sa > sb if descending else sa < sb
			return str(a.get("Username", "")) < str(b.get("Username", ""))
		)
		var total := ordered.size()
		var final_page := maxi(1, ceili(float(total) / float(page_size))) if total > 0 else 0
		var start_idx := (page - 1) * page_size
		var slice: Array = []
		for i in range(start_idx, mini(total, start_idx + page_size)):
			var entry: Dictionary = (ordered[i] as Dictionary).duplicate(true)
			entry["Rank"] = i + 1
			slice.append(entry)
		return {
			"Code": ENUMS.LEADERBOARD_BROWSE_SCORES_RESPONSE_CODE.SUCCESS,
			"FinalPage": final_page,
			"Result": slice,
		}

	func stop_multiplayer() -> void:
		pass

	func lobby_leave() -> void:
		pass


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

	# Submit 16 additional runs under the same nickname ("miska") to confirm unlimited runs
	# under one nickname can fill all 15 displayed leaderboard slots without deduplication.
	for run_idx in 16:
		var run_time := 5.0 + float(run_idx) * 0.25
		race._on_online_match_finished({1: 20.0, 2: run_time}, 2)
		await process_frame
		username_input.text = "miska"
		username_input.text_submitted.emit("miska")
		await process_frame
		assert(race._leaderboard_submitted)

	var rendered_lines := entries_label.text.split("\n")
	assert(rendered_lines.size() == 15)
	for i in 15:
		assert(("%d. miska" % (i + 1)) in rendered_lines[i])
	assert(entries_label.get_minimum_size().y <= entries_label.size.y)

	# Verify GdSyncOnlineService multi-page descending leaderboard browsing & collision-safe submission
	await _verify_gd_sync_multi_page_duplicate_runs()

	race.queue_free()
	service.queue_free()
	for frame in 10:
		await process_frame
	print("Leaderboard flow check passed.")
	quit()


func _verify_gd_sync_multi_page_duplicate_runs() -> void:
	# 1. Descending GD-Sync leaderboard spanning 3 pages (205 runs total), where the fastest
	# runs sit on FinalPage (page 3, only 5 entries) and Page 2, with many duplicate "miska" runs.
	var gd_service := GD_SYNC_ONLINE_SERVICE.new() as GdSyncOnlineService
	root.add_child(gd_service)
	var fake_client := FakeGdSyncClient.new()
	fake_client.descending = true
	fake_client.fail_first_create_as_collision = true
	root.add_child(fake_client)
	gd_service._client = fake_client
	gd_service.connection_state = OnlineServiceBase.ConnectionState.ONLINE

	# Seed 202 slow runs (40.000s .. 241.000s) across pages 1..3
	for i in 202:
		fake_client.records.append({
			"Username": "r_seed_%04d" % i,
			"Score": 40000 + i * 1000,
			"Data": {"username": "slow_%d" % i, "time_sec": 40.0 + float(i)},
		})

	# Submit 3 fast runs under the exact same nickname "miska" (first hits collision retry)
	var submitted_events: Array = []
	gd_service.leaderboard_score_submitted.connect(func(lb: String, uname: String, score_ms: int) -> void:
		submitted_events.append({"lb": lb, "username": uname, "score_ms": score_ms})
	)
	var loaded_batches: Array = []
	gd_service.leaderboard_scores_loaded.connect(func(_lb: String, entries: Array) -> void:
		loaded_batches.append(entries)
	)

	await gd_service.submit_leaderboard_time("miska", 22.849, "global_times", {"mode": "singleplayer"})
	await gd_service.submit_leaderboard_time("miska", 21.038, "global_times", {"mode": "singleplayer"})
	await gd_service.submit_leaderboard_time("miska", 20.306, "global_times", {"mode": "singleplayer"})
	assert(submitted_events.size() == 3)
	assert(fake_client.create_attempts == 4) # 1 collision retried + 3 successful unique accounts
	assert(fake_client.records.size() == 205)

	# Also add 4 more fast runs by "miska" and "ketr4x" so page 3 alone has 5 entries (< 10),
	# forcing backwards pagination into page 2 as well.
	fake_client.records.append({"Username": "r_fast_a", "Score": 25527, "Data": {"username": "miska"}})
	fake_client.records.append({"Username": "r_fast_b", "Score": 26035, "Data": {"username": "miska"}})
	fake_client.records.append({"Username": "r_fast_c", "Score": 28490, "Data": {"username": "miska"}})
	fake_client.records.append({"Username": "r_fast_d", "Score": 21295, "Data": {"username": "ketr4x"}})
	# Total = 209 entries -> FinalPage = 3 (page 3 has 9 entries, page 2 has 100, page 1 has 100)

	await gd_service.browse_leaderboard_times("global_times")
	assert(loaded_batches.size() == 1)
	var top15: Array = loaded_batches[0]
	assert(top15.size() == 15)
	assert(top15[0]["username"] == "miska" and int(top15[0]["score_ms"]) == 20306 and int(top15[0]["rank"]) == 1)
	assert(top15[1]["username"] == "miska" and int(top15[1]["score_ms"]) == 21038 and int(top15[1]["rank"]) == 2)
	assert(top15[2]["username"] == "ketr4x" and int(top15[2]["score_ms"]) == 21295 and int(top15[2]["rank"]) == 3)
	assert(top15[3]["username"] == "miska" and int(top15[3]["score_ms"]) == 22849 and int(top15[3]["rank"]) == 4)
	assert(top15[4]["username"] == "miska" and int(top15[4]["score_ms"]) == 25527 and int(top15[4]["rank"]) == 5)
	assert(top15[5]["username"] == "miska" and int(top15[5]["score_ms"]) == 26035 and int(top15[5]["rank"]) == 6)
	assert(top15[6]["username"] == "miska" and int(top15[6]["score_ms"]) == 28490 and int(top15[6]["rank"]) == 7)
	assert(top15[7]["username"] == "slow_0" and int(top15[7]["score_ms"]) == 40000 and int(top15[7]["rank"]) == 8)
	assert(top15[14]["username"] == "slow_7" and int(top15[14]["score_ms"]) == 47000 and int(top15[14]["rank"]) == 15)

	# 2. Verify ascending GD-Sync leaderboard spanning multiple pages works equally well.
	fake_client.descending = false
	fake_client.browse_calls.clear()
	await gd_service.browse_leaderboard_times("global_times")
	assert(loaded_batches.size() == 2)
	var asc_top15: Array = loaded_batches[1]
	assert(asc_top15.size() == 15)
	assert(asc_top15[0]["username"] == "miska" and int(asc_top15[0]["score_ms"]) == 20306)
	assert(asc_top15[1]["username"] == "miska" and int(asc_top15[1]["score_ms"]) == 21038)
	assert(asc_top15[2]["username"] == "ketr4x" and int(asc_top15[2]["score_ms"]) == 21295)
	assert(asc_top15[14]["username"] == "slow_7" and int(asc_top15[14]["score_ms"]) == 47000)
	assert(fake_client.browse_calls.size() == 1) # Ascending only needs page 1 for top 15

	gd_service._client = null
	gd_service.connection_state = OnlineServiceBase.ConnectionState.OFFLINE
	gd_service.queue_free()
	fake_client.queue_free()
