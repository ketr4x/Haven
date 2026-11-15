extends SceneTree

const LOCAL_MATCH_SERVICE := preload("res://scripts/online/local_match_service.gd")
const ONLINE_MATCH := preload("res://scripts/online/online_match.gd")

var _configured_slots: Array = []
var _countdown_duration: float = 0.0
var _finished_winner: int = 0
var _finished_times: Dictionary = {}


func _initialize() -> void:
	var service := LOCAL_MATCH_SERVICE.new() as LocalMatchService
	root.add_child(service)
	var online_match := ONLINE_MATCH.new() as OnlineMatch
	online_match.online_service = service
	root.add_child(online_match)
	online_match.match_configured.connect(_on_online_match_configured)
	online_match.countdown_started.connect(_on_countdown_started)
	online_match.match_finished.connect(_on_online_match_finished)
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
