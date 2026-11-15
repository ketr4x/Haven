extends SceneTree

const LOCAL_MATCH_SERVICE := preload("res://scripts/online/local_match_service.gd")
const ONLINE_MATCH := preload("res://scripts/online/online_match.gd")


func _initialize() -> void:
	var empty_service := LOCAL_MATCH_SERVICE.new() as LocalMatchService
	root.add_child(empty_service)
	var host_match := ONLINE_MATCH.new() as OnlineMatch
	host_match.online_service = empty_service
	root.add_child(host_match)
	await process_frame

	host_match.queue_quick_match()
	assert(host_match.state == OnlineMatch.MatchState.WAITING_FOR_OPPONENT)
	assert(empty_service.lobbies.size() == 1)
	var created_lobby: Dictionary = empty_service.lobbies[0]
	assert(bool(created_lobby["Public"]))
	assert((created_lobby["Tags"] as Dictionary).get("mode", "") == "quick_race")

	var candidate_service := LOCAL_MATCH_SERVICE.new() as LocalMatchService
	candidate_service.lobbies.append({
		"Name": "QUICK-OPEN",
		"Open": true,
		"PlayerCount": 1,
		"PlayerLimit": 2,
		"Public": true,
		"Tags": {
			"mode": "quick_race",
			"protocol": OnlineProtocol.PROTOCOL_VERSION,
		},
	})
	root.add_child(candidate_service)
	var guest_match := ONLINE_MATCH.new() as OnlineMatch
	guest_match.online_service = candidate_service
	root.add_child(guest_match)
	await process_frame

	guest_match.queue_quick_match()
	assert(guest_match.state == OnlineMatch.MatchState.WAITING_FOR_OPPONENT)
	assert(guest_match.room_code == "QUICK-OPEN")
	assert(int((candidate_service.lobbies[0] as Dictionary)["PlayerCount"]) == 2)

	host_match.queue_free()
	empty_service.queue_free()
	guest_match.queue_free()
	candidate_service.queue_free()
	await process_frame
	print("Quick match discovery check passed.")
	quit()
