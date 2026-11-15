extends SceneTree

const LOCAL_MATCH_SERVICE := preload("res://scripts/online/local_match_service.gd")
const ONLINE_MATCH := preload("res://scripts/online/online_match.gd")

var _configured_slots: Array = []
var _countdown_duration: float = 0.0
var _finished_winner: int = 0
var _finished_times: Dictionary = {}
var _opponent_progress: float = 0.0
var _opponent_loudness: float = 0.0
var _opponent_boost_active: bool = false
var _opponent_snapshot: Dictionary = {}


func _initialize() -> void:
	var service := LOCAL_MATCH_SERVICE.new() as LocalMatchService
	root.add_child(service)
	var online_match := ONLINE_MATCH.new() as OnlineMatch
	online_match.online_service = service
	root.add_child(online_match)
	online_match.match_configured.connect(_on_online_match_configured)
	online_match.countdown_started.connect(_on_countdown_started)
	online_match.match_finished.connect(_on_online_match_finished)
	online_match.opponent_status_received.connect(_on_opponent_status_received)
	online_match.opponent_snapshot_received.connect(func(pos: Vector2, vel: Vector2, facing: float, on_floor: bool, _loud: float, _boost: bool, events: Array) -> void:
		_opponent_snapshot = {"events": events, "facing": facing, "on_floor": on_floor, "pos": pos, "vel": vel}
	)
	await process_frame

	online_match.host_friend_room("ECHO-TEST")
	assert(online_match.state == OnlineMatch.MatchState.WAITING_FOR_OPPONENT)
	assert(online_match.room_code == "ECHO-TEST")

	service.peer_joined.emit(2)
	assert(online_match.state == OnlineMatch.MatchState.CONFIGURING)
	assert(online_match.player_slot == 1)
	assert(_configured_slots == [1])
	assert(online_match.race_seed > 0)

	online_match.submit_course_signature("same-course")
	service.receive_message(2, OnlineProtocol.make_message(
		"course_ready",
		"ECHO-TEST",
		1,
		{"signature": "same-course", "slot": 2},
	))
	assert(online_match.state == OnlineMatch.MatchState.COUNTDOWN)
	assert(is_equal_approx(_countdown_duration, online_match.countdown_duration))

	online_match.begin_race()
	online_match.submit_local_status(0.4, 55.0, true, Vector2(100.0, 50.0), Vector2(200.0, 0.0), 1.0, true, ["shout"])
	service.receive_message(2, OnlineProtocol.make_message(
		"player_status",
		"ECHO-TEST",
		2,
		{
			"boost_active": false,
			"events": ["shout"],
			"facing": 1.0,
			"loudness": 63.0,
			"on_floor": true,
			"pos": [150.0, 200.0],
			"progress": 0.7,
			"vel": [300.0, -10.0],
		},
	))
	assert(is_equal_approx(_opponent_progress, 0.7))
	assert(is_equal_approx(_opponent_loudness, 63.0))
	assert(not _opponent_boost_active)
	assert(_opponent_snapshot.get("pos") == Vector2(150.0, 200.0))
	assert(_opponent_snapshot.get("vel") == Vector2(300.0, -10.0))
	assert(_opponent_snapshot.get("facing") == 1.0)
	assert(_opponent_snapshot.get("on_floor") == true)
	assert(_opponent_snapshot.get("events") == ["shout"])

	online_match.submit_local_finish(12.5)
	service.receive_message(2, OnlineProtocol.make_message(
		"player_finished",
		"ECHO-TEST",
		2,
		{"elapsed": 13.0, "slot": 2},
	))
	assert(online_match.state == OnlineMatch.MatchState.FINISHED)
	assert(_finished_winner == 1)
	assert(is_equal_approx(float(_finished_times[1]), 12.5))
	assert(is_equal_approx(float(_finished_times[2]), 13.0))

	online_match.request_rematch()
	assert(online_match.state == OnlineMatch.MatchState.REMATCH_WAITING)
	service.receive_message(2, OnlineProtocol.make_message(
		"rematch_vote",
		"ECHO-TEST",
		3,
		{"accepted": true, "slot": 2},
	))
	assert(online_match.state == OnlineMatch.MatchState.CONFIGURING)
	assert(_configured_slots == [1, 1])
	assert(online_match.finish_times.is_empty())

	online_match.queue_free()
	service.queue_free()
	await process_frame
	print("Online friend online_match flow check passed.")
	quit()


func _on_online_match_configured(player_slot: int, _seed: int) -> void:
	_configured_slots.append(player_slot)


func _on_countdown_started(duration: float) -> void:
	_countdown_duration = duration


func _on_online_match_finished(finish_times: Dictionary, winner_slot: int) -> void:
	_finished_times = finish_times
	_finished_winner = winner_slot


func _on_opponent_status_received(progress: float, loudness: float, boost_active: bool) -> void:
	_opponent_progress = progress
	_opponent_loudness = loudness
	_opponent_boost_active = boost_active
