class_name GdSyncOnlineService
extends OnlineServiceBase

const GD_SYNC_CLIENT: GDScript = preload("res://addons/GD-Sync/MultiplayerClient.gd")

var _client: Variant


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	disconnect_online()


func connect_online() -> void:
	if is_online() or is_connecting():
		return

	connection_state = ConnectionState.CONNECTING
	_client = GD_SYNC_CLIENT.new()
	_client.name = "GDSync"
	get_tree().root.call_deferred("add_child", _client)
	await _client.ready

	if not is_instance_valid(_client):
		connection_state = ConnectionState.OFFLINE
		connection_failed.emit("GD-Sync client initialization failed.")
		return

	_bind_client_signals()
	_client.expose_func(_receive_remote_message)
	_client.start_multiplayer()


func disconnect_online() -> void:
	if not is_instance_valid(_client):
		connection_state = ConnectionState.OFFLINE
		active_lobby_name = ""
		return

	if has_active_lobby():
		_client.lobby_leave()
	_client.stop_multiplayer()
	_client.queue_free()
	_client = null
	var was_online := connection_state != ConnectionState.OFFLINE
	connection_state = ConnectionState.OFFLINE
	active_lobby_name = ""
	if was_online:
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

	var lobby_tags := tags.duplicate(true)
	lobby_tags["protocol"] = OnlineProtocol.PROTOCOL_VERSION
	_client.lobby_create(lobby_name, password, is_public, player_limit, lobby_tags)


func join_lobby(lobby_name: String, password: String = "") -> void:
	if not _require_online("join_lobby"):
		return
	if not _is_valid_lobby_name(lobby_name):
		_reject("join_lobby", "Lobby names must contain 3 to 32 characters.")
		return
	if not _is_valid_password(password):
		_reject("join_lobby", "Lobby passwords may contain at most 16 characters.")
		return
	_client.lobby_join(lobby_name, password)


func leave_lobby() -> void:
	if not has_active_lobby() or not is_instance_valid(_client):
		return
	_client.lobby_leave()
	active_lobby_name = ""


func list_public_lobbies() -> void:
	if not _require_online("list_public_lobbies"):
		return
	_client.get_public_lobbies()


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
	_client.call_func(_receive_remote_message, result["message"])
	return true


func get_client_id() -> int:
	return int(_client.get_client_id()) if is_instance_valid(_client) else -1


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

	var connected_ok := await _ensure_online_connection()
	if not connected_ok or not is_instance_valid(_client):
		leaderboard_submission_failed.emit(leaderboard_name, "BRAK POŁĄCZENIA Z GD-SYNC.")
		return

	_client.player_set_username(sanitized_name)

	var score_ms := maxi(1, roundi(elapsed_seconds * 1000.0))
	var payload := extra_data.duplicate(true)
	payload["username"] = raw_name
	payload["time_sec"] = snappedf(elapsed_seconds, 0.001)

	var submit_code := int(await _client.leaderboard_submit_score(leaderboard_name, score_ms, payload))
	if submit_code == ENUMS.LEADERBOARD_SUBMIT_SCORE_RESPONSE_CODE.NOT_LOGGED_IN:
		var auth_ok := await _ensure_silent_leaderboard_session(sanitized_name)
		if auth_ok and is_instance_valid(_client):
			submit_code = int(await _client.leaderboard_submit_score(leaderboard_name, score_ms, payload))

	if submit_code == ENUMS.LEADERBOARD_SUBMIT_SCORE_RESPONSE_CODE.SUCCESS:
		leaderboard_score_submitted.emit(leaderboard_name, raw_name, score_ms)
	else:
		leaderboard_submission_failed.emit(leaderboard_name, _format_submit_error(submit_code, leaderboard_name))


func browse_leaderboard_times(
	leaderboard_name: String = DEFAULT_LEADERBOARD_NAME,
	page_size: int = 10,
	page: int = 1
) -> void:
	var connected_ok := await _ensure_online_connection()
	if not connected_ok or not is_instance_valid(_client):
		leaderboard_load_failed.emit(leaderboard_name, "BRAK POŁĄCZENIA Z GD-SYNC.")
		return

	var clamped_size := clampi(page_size, 1, 100)
	var clamped_page := maxi(1, page)
	var response: Dictionary = await _client.leaderboard_browse_scores(leaderboard_name, clamped_size, clamped_page)
	var code := int(response.get("Code", -1))
	if code == ENUMS.LEADERBOARD_BROWSE_SCORES_RESPONSE_CODE.NOT_LOGGED_IN:
		var auth_ok := await _ensure_silent_leaderboard_session("ReaderGuest")
		if auth_ok and is_instance_valid(_client):
			response = await _client.leaderboard_browse_scores(leaderboard_name, clamped_size, clamped_page)
			code = int(response.get("Code", -1))

	if code != ENUMS.LEADERBOARD_BROWSE_SCORES_RESPONSE_CODE.SUCCESS:
		leaderboard_load_failed.emit(leaderboard_name, _format_browse_error(code, leaderboard_name))
		return

	var raw_entries: Array = response.get("Result", []) if response.get("Result") is Array else []
	var normalized: Array = []
	for item in raw_entries:
		if not item is Dictionary:
			continue
		var entry: Dictionary = item
		var data_dict: Dictionary = entry.get("Data", {}) if entry.get("Data") is Dictionary else {}
		var entry_username := str(data_dict.get("username", entry.get("Username", entry.get("Name", "GRACZ"))))
		var score_ms := int(entry.get("Score", 0))
		var rank := int(entry.get("Rank", normalized.size() + 1))
		normalized.append({
			"rank": rank,
			"username": entry_username,
			"score_ms": score_ms,
			"elapsed_seconds": float(score_ms) / 1000.0,
			"data": data_dict,
		})
	leaderboard_scores_loaded.emit(leaderboard_name, normalized)


func _ensure_online_connection() -> bool:
	if is_online() and is_instance_valid(_client):
		return true
	if not is_connecting():
		connect_online()
	var deadline_ms := Time.get_ticks_msec() + 8000
	while is_connecting() and Time.get_ticks_msec() < deadline_ms:
		await get_tree().process_frame
	return is_online() and is_instance_valid(_client)


func _ensure_silent_leaderboard_session(desired_username: String) -> bool:
	if not is_instance_valid(_client):
		return false
	var clean := _sanitize_leaderboard_username(desired_username)
	if clean.length() < 3:
		clean = "Player"

	if _client.account_is_logged_in():
		_client.account_change_username(clean)
		_client.player_set_username(clean)
		return true

	var session_code := int(await _client.account_login_from_session(86400))
	if session_code == ENUMS.ACCOUNT_LOGIN_RESPONSE_CODE.SUCCESS:
		await _client.account_change_username(clean)
		_client.player_set_username(clean)
		return true

	for attempt in 3:
		var candidate_name := clean if attempt == 0 else "%s%d" % [clean.substr(0, 11), RandomNumberGenerator.new().randi_range(100, 9999)]
		var email := "%s@rezonans.local" % candidate_name.to_lower()
		var secret := ("Rz#%s!9xK2" % candidate_name.to_lower()).substr(0, 20)
		var create_code := int(await _client.account_create(email, candidate_name, secret))
		if create_code in [
			ENUMS.ACCOUNT_CREATION_RESPONSE_CODE.SUCCESS,
			ENUMS.ACCOUNT_CREATION_RESPONSE_CODE.EMAIL_ALREADY_EXISTS,
			ENUMS.ACCOUNT_CREATION_RESPONSE_CODE.USERNAME_ALREADY_EXISTS,
		]:
			var login_res: Dictionary = await _client.account_login(email, secret, 86400)
			if int(login_res.get("Code", -1)) == ENUMS.ACCOUNT_LOGIN_RESPONSE_CODE.SUCCESS:
				_client.player_set_username(candidate_name)
				return true
		if create_code == ENUMS.ACCOUNT_CREATION_RESPONSE_CODE.NO_DATABASE:
			return false
	return false


func _format_submit_error(code: int, leaderboard_name: String) -> String:
	match code:
		ENUMS.LEADERBOARD_SUBMIT_SCORE_RESPONSE_CODE.NO_DATABASE:
			return "BAZA GD-SYNC NIE JEST ZAINICJALIZOWANA."
		ENUMS.LEADERBOARD_SUBMIT_SCORE_RESPONSE_CODE.LEADERBOARD_DOESNT_EXIST:
			return "BRAK TABELI '%s' W GD-SYNC." % leaderboard_name
		ENUMS.LEADERBOARD_SUBMIT_SCORE_RESPONSE_CODE.NOT_LOGGED_IN:
			return "WYMAGANE LOGOWANIE W BAZIE GD-SYNC."
		ENUMS.LEADERBOARD_SUBMIT_SCORE_RESPONSE_CODE.NO_RESPONSE_FROM_SERVER:
			return "BRAK ODPOWIEDZI SERWERA GD-SYNC."
		ENUMS.LEADERBOARD_SUBMIT_SCORE_RESPONSE_CODE.RATE_LIMIT_EXCEEDED:
			return "PRZEKROCZONO LIMIT ZAPYTAŃ GD-SYNC."
		ENUMS.LEADERBOARD_SUBMIT_SCORE_RESPONSE_CODE.STORAGE_FULL, ENUMS.LEADERBOARD_SUBMIT_SCORE_RESPONSE_CODE.DATA_CAP_REACHED:
			return "LIMIT DANYCH GD-SYNC ZOSTAŁ WYCZERPANY."
		_:
			return "BŁĄD ZAPISU DO RANKINGU (KOD %d)." % code


func _format_browse_error(code: int, leaderboard_name: String) -> String:
	match code:
		ENUMS.LEADERBOARD_BROWSE_SCORES_RESPONSE_CODE.NO_DATABASE:
			return "BAZA GD-SYNC NIE JEST ZAINICJALIZOWANA."
		ENUMS.LEADERBOARD_BROWSE_SCORES_RESPONSE_CODE.LEADERBOARD_DOESNT_EXIST:
			return "BRAK TABELI '%s' W GD-SYNC." % leaderboard_name
		ENUMS.LEADERBOARD_BROWSE_SCORES_RESPONSE_CODE.NO_RESPONSE_FROM_SERVER:
			return "BRAK ODPOWIEDZI SERWERA GD-SYNC."
		_:
			return "BŁĄD POBIERANIA RANKINGU (KOD %d)." % code


func _bind_client_signals() -> void:
	_client.connected.connect(_on_client_connected)
	_client.connection_failed.connect(_on_client_connection_failed)
	_client.disconnected.connect(_on_client_disconnected)
	_client.lobby_created.connect(_on_client_lobby_created)
	_client.lobby_creation_failed.connect(_on_client_lobby_creation_failed)
	_client.lobby_joined.connect(_on_client_lobby_joined)
	_client.lobby_join_failed.connect(_on_client_lobby_join_failed)
	_client.lobbies_received.connect(_on_client_lobbies_received)
	_client.client_joined.connect(_on_client_peer_joined)
	_client.client_left.connect(_on_client_peer_left)


func _on_client_connected() -> void:
	connection_state = ConnectionState.ONLINE
	online_connected.emit(get_client_id())


func _on_client_connection_failed(error: int) -> void:
	connection_state = ConnectionState.OFFLINE
	connection_failed.emit("GD-Sync connection failed with error %d." % error)


func _on_client_disconnected() -> void:
	var was_online := connection_state != ConnectionState.OFFLINE
	connection_state = ConnectionState.OFFLINE
	active_lobby_name = ""
	if was_online:
		online_disconnected.emit()


func _on_client_lobby_created(lobby_name: String) -> void:
	lobby_created.emit(lobby_name)


func _on_client_lobby_creation_failed(lobby_name: String, error: int) -> void:
	operation_rejected.emit("create_lobby", "GD-Sync rejected %s with error %d." % [lobby_name, error])


func _on_client_lobby_joined(lobby_name: String) -> void:
	active_lobby_name = lobby_name
	lobby_joined.emit(lobby_name)


func _on_client_lobby_join_failed(lobby_name: String, error: int) -> void:
	lobby_join_failed.emit(lobby_name, "GD-Sync rejected the join with error %d." % error)


func _on_client_lobbies_received(lobbies: Array) -> void:
	lobbies_listed.emit(lobbies)


func _on_client_peer_joined(client_id: int) -> void:
	if client_id != get_client_id():
		peer_joined.emit(client_id)


func _on_client_peer_left(client_id: int) -> void:
	peer_left.emit(client_id)


func _receive_remote_message(message: Dictionary) -> void:
	var result := OnlineProtocol.validate_message(message)
	if not bool(result["valid"]):
		_reject("receive_message", str(result["error"]))
		return
	var sender_id := int(_client.get_sender_id()) if is_instance_valid(_client) else -1
	if sender_id < 0:
		_reject("receive_message", "GD-Sync did not identify the message sender.")
		return
	message_received.emit(sender_id, result["message"])


func _require_online(operation: String) -> bool:
	if is_online() and is_instance_valid(_client):
		return true
	_reject(operation, "Connect before using online features.")
	return false
