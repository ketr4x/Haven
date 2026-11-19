class_name LocalMatchService
extends OnlineServiceBase

var client_id: int = 1
var lobbies: Array = []
var sent_messages: Array = []
var leaderboards: Dictionary = {}


func connect_online() -> void:
	if is_online() or is_connecting():
		return
	connection_state = ConnectionState.ONLINE
	online_connected.emit(client_id)


func disconnect_online() -> void:
	if connection_state == ConnectionState.OFFLINE:
		return
	connection_state = ConnectionState.OFFLINE
	active_lobby_name = ""
	online_disconnected.emit()


func create_lobby(
	lobby_name: String,
	password: String = "",
	is_public: bool = false,
	player_limit: int = 2,
	tags: Dictionary = {}
) -> void:
	if not _require_online("create_lobby"):
		return
	if not _is_valid_lobby_name(lobby_name):
		_reject("create_lobby", "Lobby names must contain 3 to 32 characters.")
		return
	if not _is_valid_password(password):
		_reject("create_lobby", "Lobby passwords may contain at most 16 characters.")
		return
	if player_limit < 2:
		_reject("create_lobby", "A race lobby needs space for two players.")
		return

	lobbies.append({
		"Name": lobby_name,
		"Open": true,
		"PlayerCount": 0,
		"PlayerLimit": player_limit,
		"Public": is_public,
		"Tags": tags.duplicate(true),
	})
	lobby_created.emit(lobby_name)
	lobby_joined.emit(lobby_name)


func join_lobby(lobby_name: String, _password: String = "") -> void:
	if not _require_online("join_lobby"):
		return
	for lobby_value in lobbies:
		if not lobby_value is Dictionary:
			continue
		var lobby: Dictionary = lobby_value
		if lobby.get("Name", "") != lobby_name:
			continue
		if not bool(lobby.get("Open", false)):
			lobby_join_failed.emit(lobby_name, "Lobby is closed.")
			return
		if int(lobby.get("PlayerCount", 0)) >= int(lobby.get("PlayerLimit", 0)):
			lobby_join_failed.emit(lobby_name, "Lobby is full.")
			return
		lobby["PlayerCount"] = int(lobby["PlayerCount"]) + 1
		active_lobby_name = lobby_name
		lobby_joined.emit(lobby_name)
		return
	lobby_join_failed.emit(lobby_name, "Lobby does not exist.")


func leave_lobby() -> void:
	active_lobby_name = ""


func list_public_lobbies() -> void:
	if not _require_online("list_public_lobbies"):
		return
	var public_lobbies: Array = []
	for lobby_value in lobbies:
		if lobby_value is Dictionary and bool((lobby_value as Dictionary).get("Public", false)):
			public_lobbies.append((lobby_value as Dictionary).duplicate(true))
	lobbies_listed.emit(public_lobbies)


func send_message(message: Dictionary) -> bool:
	if not _require_online("send_message"):
		return false
	if not has_active_lobby():
		_reject("send_message", "Join a lobby before sending messages.")
		return false
	var result := OnlineProtocol.validate_message(message)
	if not bool(result["valid"]):
		_reject("send_message", str(result["error"]))
		return false
	sent_messages.append(result["message"])
	return true


func get_client_id() -> int:
	return client_id


func submit_leaderboard_time(
	username: String,
	elapsed_seconds: float,
	leaderboard_name: String = DEFAULT_LEADERBOARD_NAME,
	extra_data: Dictionary = {}
) -> void:
	var raw_name := username.strip_edges()
	var sanitized_name := _sanitize_leaderboard_username(raw_name)
	if sanitized_name.length() < 3:
		leaderboard_submission_failed.emit(leaderboard_name, "NAZWA MUSI MIEĆ MIN. 3 ZNAKI (A-Z, 0-9).")
		return
	if elapsed_seconds <= 0.0:
		leaderboard_submission_failed.emit(leaderboard_name, "NIEPRAWIDŁOWY CZAS WYŚCIGU.")
		return

	if not is_online():
		connect_online()

	var score_ms := maxi(1, roundi(elapsed_seconds * 1000.0))
	var payload := extra_data.duplicate(true)
	payload["username"] = raw_name
	payload["time_sec"] = snappedf(elapsed_seconds, 0.001)

	if not leaderboards.has(leaderboard_name):
		leaderboards[leaderboard_name] = []
	var board: Array = leaderboards[leaderboard_name]
	var replaced := false
	for i in board.size():
		var item: Dictionary = board[i]
		if str(item.get("username", "")).to_lower() == raw_name.to_lower():
			var prev_score := int(item.get("score_ms", 0))
			if prev_score <= 0 or score_ms < prev_score:
				board[i] = {
					"username": raw_name,
					"score_ms": score_ms,
					"elapsed_seconds": float(score_ms) / 1000.0,
					"data": payload,
				}
			else:
				score_ms = prev_score
			replaced = true
			break
	if not replaced:
		board.append({
			"username": raw_name,
			"score_ms": score_ms,
			"elapsed_seconds": float(score_ms) / 1000.0,
			"data": payload,
		})
	board.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("score_ms", 0)) < int(b.get("score_ms", 0))
	)
	for i in board.size():
		(board[i] as Dictionary)["rank"] = i + 1

	leaderboard_score_submitted.emit(leaderboard_name, raw_name, score_ms)


func browse_leaderboard_times(
	leaderboard_name: String = DEFAULT_LEADERBOARD_NAME,
	page_size: int = 10,
	page: int = 1
) -> void:
	if not is_online():
		connect_online()
	var board: Array = leaderboards.get(leaderboard_name, [])
	var clamped_size := clampi(page_size, 1, 100)
	var start_idx := maxi(0, (page - 1) * clamped_size)
	var entries: Array = []
	for i in range(start_idx, mini(board.size(), start_idx + clamped_size)):
		entries.append((board[i] as Dictionary).duplicate(true))
	leaderboard_scores_loaded.emit(leaderboard_name, entries)


func receive_message(sender_id: int, message: Dictionary) -> void:
	var result := OnlineProtocol.validate_message(message)
	if not bool(result["valid"]):
		_reject("receive_message", str(result["error"]))
		return
	message_received.emit(sender_id, result["message"])


func _require_online(operation: String) -> bool:
	if is_online():
		return true
	_reject(operation, "Connect before using online features.")
	return false
