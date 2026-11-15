class_name OnlineMatch
extends Node

signal countdown_started(duration: float)
signal match_configured(player_slot: int, seed: int)
signal match_failed(reason: String)
signal match_finished(finish_times: Dictionary, winner_slot: int)
signal opponent_finished(player_slot: int, elapsed: float)
signal opponent_left(client_id: int)
signal room_code_ready(room_code: String)

enum MatchState {
	IDLE,
	CONNECTING,
	JOINING,
	WAITING_FOR_OPPONENT,
	CONFIGURING,
	COUNTDOWN,
	RACING,
	FINISHED,
	FAILED,
}

enum MatchRole {
	HOST,
	GUEST,
}

enum MatchKind {
	FRIEND,
	QUICK,
}

const ROOM_CODE_ALPHABET: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const ROOM_CODE_LENGTH: int = 8
const RACE_TAGS: Dictionary = {
	"mode": "friend_race",
}
const QUICK_MATCH_TAGS: Dictionary = {
	"mode": "quick_race",
}
const MAX_QUICK_MATCH_JOIN_RETRIES: int = 1

@export_range(1.0, 5.0, 0.1) var countdown_duration: float = 3.0

var online_service: OnlineServiceBase
var finish_times: Dictionary = {}
var player_slot: int = 0
var race_seed: int = 0
var room_code: String = ""
var state: MatchState = MatchState.IDLE

var _course_signatures: Dictionary = {}
var _next_sequence: int = 0
var _quick_match_join_retries: int = 0
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _kind: MatchKind
var _role: MatchRole


func _ready() -> void:
	_random.randomize()
	if online_service == null:
		online_service = get_node("/root/OnlineService") as OnlineServiceBase
	online_service.online_connected.connect(_on_online_connected)
	online_service.connection_failed.connect(_on_connection_failed)
	online_service.online_disconnected.connect(_on_online_disconnected)
	online_service.lobby_created.connect(_on_lobby_created)
	online_service.lobby_joined.connect(_on_lobby_joined)
	online_service.lobby_join_failed.connect(_on_lobby_join_failed)
	online_service.lobbies_listed.connect(_on_lobbies_listed)
	online_service.peer_joined.connect(_on_peer_joined)
	online_service.peer_left.connect(_on_peer_left)
	online_service.message_received.connect(_on_message_received)


func host_friend_room(requested_room_code: String = "") -> void:
	if not _begin(MatchRole.HOST):
		return
	_kind = MatchKind.FRIEND
	room_code = requested_room_code.to_upper()
	if room_code.is_empty():
		room_code = _create_room_code()
	if not _is_valid_room_code(room_code):
		_fail("Room code must contain 3 to 32 characters.")
		return
	room_code_ready.emit(room_code)
	online_service.connect_online()


func join_friend_room(requested_room_code: String) -> void:
	if not _begin(MatchRole.GUEST):
		return
	_kind = MatchKind.FRIEND
	room_code = requested_room_code.to_upper()
	if not _is_valid_room_code(room_code):
		_fail("Room code must contain 3 to 32 characters.")
		return
	online_service.connect_online()


func queue_quick_match() -> void:
	if state != MatchState.IDLE:
		return
	_kind = MatchKind.QUICK
	state = MatchState.CONNECTING
	online_service.connect_online()


func submit_course_signature(signature: String) -> void:
	if state != MatchState.CONFIGURING or signature.is_empty():
		return
	_course_signatures[player_slot] = signature
	_send("course_ready", {"signature": signature, "slot": player_slot})
	if _role == MatchRole.HOST:
		_try_start_race()


func begin_race() -> void:
	if state == MatchState.COUNTDOWN:
		state = MatchState.RACING


func submit_local_finish(elapsed: float) -> void:
	if state != MatchState.RACING or player_slot == 0 or finish_times.has(player_slot):
		return
	finish_times[player_slot] = elapsed
	_send("player_finished", {"elapsed": elapsed, "slot": player_slot})
	if _role == MatchRole.HOST:
		_try_finish_match()


func leave_match() -> void:
	if online_service != null:
		online_service.leave_lobby()
	_reset()


func _begin(next_role: MatchRole) -> bool:
	if state != MatchState.IDLE:
		return false
	_role = next_role
	state = MatchState.CONNECTING
	return true


func _on_online_connected(_client_id: int) -> void:
	if state != MatchState.CONNECTING:
		return
	state = MatchState.JOINING
	if _kind == MatchKind.QUICK:
		online_service.list_public_lobbies()
		return
	if _role == MatchRole.HOST:
		online_service.create_lobby(room_code, "", false, 2, RACE_TAGS)
	else:
		online_service.join_lobby(room_code)


func _on_lobbies_listed(lobbies: Array) -> void:
	if _kind != MatchKind.QUICK or state != MatchState.JOINING:
		return
	var candidates: Array[Dictionary] = []
	for lobby_value in lobbies:
		if not lobby_value is Dictionary:
			continue
		var lobby: Dictionary = lobby_value
		if _is_joinable_quick_lobby(lobby):
			candidates.append(lobby)
	if candidates.is_empty():
		_create_quick_lobby()
		return
	candidates.shuffle()
	room_code = str(candidates[0].get("Name", ""))
	_role = MatchRole.GUEST
	online_service.join_lobby(room_code)


func _create_quick_lobby() -> void:
	_role = MatchRole.HOST
	room_code = _create_room_code()
	online_service.create_lobby(room_code, "", true, 2, QUICK_MATCH_TAGS)


func _is_joinable_quick_lobby(lobby: Dictionary) -> bool:
	var tags_value: Variant = lobby.get("Tags", {})
	if not tags_value is Dictionary:
		return false
	var tags: Dictionary = tags_value
	return bool(lobby.get("Open", false)) \
		and int(lobby.get("PlayerCount", 0)) == 1 \
		and int(lobby.get("PlayerLimit", 0)) == 2 \
		and str(tags.get("mode", "")) == QUICK_MATCH_TAGS["mode"] \
		and int(tags.get("protocol", -1)) == OnlineProtocol.PROTOCOL_VERSION


func _on_lobby_created(lobby_name: String) -> void:
	if _role != MatchRole.HOST or state != MatchState.JOINING or lobby_name != room_code:
		return
	online_service.join_lobby(lobby_name)


func _on_lobby_joined(lobby_name: String) -> void:
	if state != MatchState.JOINING or lobby_name != room_code:
		return
	state = MatchState.WAITING_FOR_OPPONENT
	if _kind == MatchKind.FRIEND and _role == MatchRole.HOST:
		room_code_ready.emit(room_code)


func _on_lobby_join_failed(lobby_name: String, reason: String) -> void:
	if lobby_name != room_code:
		return
	if _kind == MatchKind.QUICK and _quick_match_join_retries < MAX_QUICK_MATCH_JOIN_RETRIES:
		_quick_match_join_retries += 1
		room_code = ""
		online_service.list_public_lobbies()
		return
	_fail(reason)


func _on_peer_joined(_client_id: int) -> void:
	if _role == MatchRole.HOST and state == MatchState.WAITING_FOR_OPPONENT:
		_start_setup_as_host()


func _start_setup_as_host() -> void:
	player_slot = 1
	race_seed = _random.randi_range(1, 2_147_483_647)
	state = MatchState.CONFIGURING
	match_configured.emit(player_slot, race_seed)
	_send("race_setup", {"seed": race_seed})


func _on_message_received(_sender_id: int, message: Dictionary) -> void:
	if str(message.get("match_id", "")) != room_code:
		return
	var payload: Dictionary = message["payload"] as Dictionary
	match str(message["kind"]):
		"race_setup":
			_receive_race_setup(payload)
		"course_ready":
			_receive_course_ready(payload)
		"race_start":
			_receive_race_start(payload)
		"player_finished":
			_receive_player_finished(payload)
		"match_result":
			_receive_match_result(payload)


func _receive_race_setup(payload: Dictionary) -> void:
	if _role != MatchRole.GUEST or state != MatchState.WAITING_FOR_OPPONENT:
		return
	var seed_value: Variant = payload.get("seed")
	if not seed_value is int or int(seed_value) <= 0:
		_fail("Host sent an invalid course seed.")
		return
	player_slot = 2
	race_seed = int(seed_value)
	state = MatchState.CONFIGURING
	match_configured.emit(player_slot, race_seed)


func _receive_course_ready(payload: Dictionary) -> void:
	if _role != MatchRole.HOST or state != MatchState.CONFIGURING:
		return
	var slot_value: Variant = payload.get("slot")
	var signature_value: Variant = payload.get("signature")
	if not slot_value is int or int(slot_value) != 2 or not signature_value is String or signature_value.is_empty():
		_fail("Guest sent an invalid course signature.")
		return
	_course_signatures[2] = signature_value
	_try_start_race()


func _try_start_race() -> void:
	if not _course_signatures.has(1) or not _course_signatures.has(2):
		return
	if str(_course_signatures[1]) != str(_course_signatures[2]):
		_fail("The generated courses do not match.")
		return
	state = MatchState.COUNTDOWN
	_send("race_start", {"duration": countdown_duration})
	countdown_started.emit(countdown_duration)


func _receive_race_start(payload: Dictionary) -> void:
	if _role != MatchRole.GUEST or state != MatchState.CONFIGURING:
		return
	var duration_value: Variant = payload.get("duration")
	if not duration_value is float and not duration_value is int:
		_fail("Host sent an invalid countdown.")
		return
	var duration := float(duration_value)
	if duration <= 0.0 or duration > 5.0:
		_fail("Host sent an invalid countdown.")
		return
	state = MatchState.COUNTDOWN
	countdown_started.emit(duration)


func _receive_player_finished(payload: Dictionary) -> void:
	if state != MatchState.RACING:
		return
	var slot_value: Variant = payload.get("slot")
	var elapsed_value: Variant = payload.get("elapsed")
	var expected_slot := 2 if player_slot == 1 else 1
	if not slot_value is int or int(slot_value) != expected_slot:
		_fail("Opponent sent an invalid player slot.")
		return
	if not elapsed_value is float and not elapsed_value is int or float(elapsed_value) < 0.0:
		_fail("Opponent sent an invalid finish time.")
		return
	finish_times[expected_slot] = float(elapsed_value)
	opponent_finished.emit(expected_slot, float(elapsed_value))
	if _role == MatchRole.HOST:
		_try_finish_match()


func _try_finish_match() -> void:
	if not finish_times.has(1) or not finish_times.has(2):
		return
	var winner_slot := 1 if float(finish_times[1]) <= float(finish_times[2]) else 2
	state = MatchState.FINISHED
	_send("match_result", {"finish_times": finish_times.duplicate(true), "winner_slot": winner_slot})
	match_finished.emit(finish_times.duplicate(true), winner_slot)


func _receive_match_result(payload: Dictionary) -> void:
	if state != MatchState.RACING:
		return
	var times_value: Variant = payload.get("finish_times")
	var winner_value: Variant = payload.get("winner_slot")
	if not times_value is Dictionary or not winner_value is int:
		_fail("Host sent an invalid match result.")
		return
	var times: Dictionary = times_value
	if not times.has(1) or not times.has(2) or not [1, 2].has(int(winner_value)):
		_fail("Host sent an incomplete match result.")
		return
	finish_times = times.duplicate(true)
	state = MatchState.FINISHED
	match_finished.emit(finish_times.duplicate(true), int(winner_value))


func _on_peer_left(client_id: int) -> void:
	if state in [MatchState.IDLE, MatchState.FINISHED, MatchState.FAILED]:
		return
	opponent_left.emit(client_id)
	state = MatchState.FINISHED


func _on_connection_failed(reason: String) -> void:
	_fail(reason)


func _on_online_disconnected() -> void:
	if state not in [MatchState.IDLE, MatchState.FINISHED, MatchState.FAILED]:
		_fail("The online connection was lost.")


func _send(kind: String, payload: Dictionary) -> void:
	_next_sequence += 1
	if not online_service.send_message(OnlineProtocol.make_message(kind, room_code, _next_sequence, payload)):
		_fail("The online message could not be sent.")


func _fail(reason: String) -> void:
	state = MatchState.FAILED
	match_failed.emit(reason)


func _reset() -> void:
	finish_times.clear()
	_course_signatures.clear()
	player_slot = 0
	race_seed = 0
	room_code = ""
	_next_sequence = 0
	_quick_match_join_retries = 0
	state = MatchState.IDLE


func _create_room_code() -> String:
	var result := ""
	for index in ROOM_CODE_LENGTH:
		result += ROOM_CODE_ALPHABET[_random.randi_range(0, ROOM_CODE_ALPHABET.length() - 1)]
	return result


func _is_valid_room_code(value: String) -> bool:
	return value.length() >= 3 and value.length() <= 32
