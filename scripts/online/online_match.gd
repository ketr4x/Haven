class_name OnlineMatch
extends Node

signal countdown_started(duration: float)
signal match_configured(player_slot: int, seed: int)
signal match_failed(reason: String)
signal match_finished(finish_times: Dictionary, winner_slot: int)
signal opponent_finished(player_slot: int, elapsed: float)
signal opponent_left(client_id: int)
signal opponent_named(display_name: String)
signal opponent_status_received(progress: float, loudness: float, boost_active: bool)
signal opponent_snapshot_received(position: Vector2, velocity: Vector2, facing: float, on_floor: bool, loudness: float, boost_active: bool, events: Array)
signal rematch_waiting
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
	REMATCH_WAITING,
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
var local_display_name: String = ""
var opponent_display_name: String = ""

var _course_signatures: Dictionary = {}
var _rematch_votes: Dictionary = {}
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
		_fail(tr("ONLINE_ERR_ROOM_CODE"))
		return
	room_code_ready.emit(room_code)
	online_service.connect_online()


func join_friend_room(requested_room_code: String) -> void:
	if not _begin(MatchRole.GUEST):
		return
	_kind = MatchKind.FRIEND
	room_code = requested_room_code.to_upper()
	if not _is_valid_room_code(room_code):
		_fail(tr("ONLINE_ERR_ROOM_CODE"))
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


func submit_local_status(
	progress: float,
	loudness: float,
	boost_active: bool,
	position: Vector2 = Vector2.ZERO,
	velocity: Vector2 = Vector2.ZERO,
	facing: float = 1.0,
	on_floor: bool = false,
	events: Array = []
) -> void:
	if state != MatchState.RACING:
		return
	var payload: Dictionary = {
		"boost_active": boost_active,
		"loudness": clampf(loudness, 0.0, 100.0),
		"progress": clampf(progress, 0.0, 1.0),
	}
	if position != Vector2.ZERO or velocity != Vector2.ZERO or not events.is_empty() or not is_equal_approx(facing, 1.0) or on_floor:
		payload["pos"] = [position.x, position.y]
		payload["vel"] = [velocity.x, velocity.y]
		payload["facing"] = facing
		payload["on_floor"] = on_floor
		payload["events"] = events
	_send("player_status", payload)


func request_rematch() -> void:
	if state not in [MatchState.FINISHED, MatchState.REMATCH_WAITING] or player_slot == 0:
		return
	if _rematch_votes.has(player_slot):
		return
	state = MatchState.REMATCH_WAITING
	_rematch_votes[player_slot] = true
	_send("rematch_vote", {"accepted": true, "slot": player_slot})
	rematch_waiting.emit()
	_try_start_rematch()


func has_local_rematch_vote() -> bool:
	return _rematch_votes.has(player_slot)


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


func _on_online_connected(client_id: int) -> void:
	if state != MatchState.CONNECTING:
		return
	local_display_name = "ECHO-%04d" % posmod(client_id, 10_000)
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
	_send_hello()
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
		_send_hello()
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
		"hello":
			_receive_hello(payload)
		"race_setup":
			_receive_race_setup(payload)
		"course_ready":
			_receive_course_ready(payload)
		"race_start":
			_receive_race_start(payload)
		"player_finished":
			_receive_player_finished(payload)
		"player_status":
			_receive_player_status(payload)
		"match_result":
			_receive_match_result(payload)
		"rematch_vote":
			_receive_rematch_vote(payload)


func _send_hello() -> void:
	if local_display_name.is_empty():
		return
	_send("hello", {"display_name": local_display_name})


func _receive_hello(payload: Dictionary) -> void:
	var name_value: Variant = payload.get("display_name")
	if not name_value is String:
		return
	var display_name := str(name_value).strip_edges().left(20)
	if display_name.is_empty():
		return
	opponent_display_name = display_name
	opponent_named.emit(opponent_display_name)


func _receive_race_setup(payload: Dictionary) -> void:
	if _role != MatchRole.GUEST or state not in [MatchState.WAITING_FOR_OPPONENT, MatchState.REMATCH_WAITING]:
		return
	var seed_value: Variant = payload.get("seed")
	if not seed_value is int or int(seed_value) <= 0:
		_fail(tr("ONLINE_ERR_INVALID_SEED"))
		return
	finish_times.clear()
	_course_signatures.clear()
	_rematch_votes.clear()
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
		_fail(tr("ONLINE_ERR_INVALID_SIGNATURE"))
		return
	_course_signatures[2] = signature_value
	_try_start_race()


func _try_start_race() -> void:
	if not _course_signatures.has(1) or not _course_signatures.has(2):
		return
	if str(_course_signatures[1]) != str(_course_signatures[2]):
		_fail(tr("ONLINE_ERR_COURSE_MISMATCH"))
		return
	state = MatchState.COUNTDOWN
	_send("race_start", {"duration": countdown_duration})
	countdown_started.emit(countdown_duration)


func _receive_race_start(payload: Dictionary) -> void:
	if _role != MatchRole.GUEST or state != MatchState.CONFIGURING:
		return
	var duration_value: Variant = payload.get("duration")
	if not duration_value is float and not duration_value is int:
		_fail(tr("ONLINE_ERR_INVALID_COUNTDOWN"))
		return
	var duration := float(duration_value)
	if duration <= 0.0 or duration > 5.0:
		_fail(tr("ONLINE_ERR_INVALID_COUNTDOWN"))
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
		_fail(tr("ONLINE_ERR_INVALID_SLOT"))
		return
	if not elapsed_value is float and not elapsed_value is int or float(elapsed_value) < 0.0:
		_fail(tr("ONLINE_ERR_INVALID_FINISH_TIME"))
		return
	finish_times[expected_slot] = float(elapsed_value)
	opponent_finished.emit(expected_slot, float(elapsed_value))
	if _role == MatchRole.HOST:
		_try_finish_match()


func _receive_player_status(payload: Dictionary) -> void:
	if state != MatchState.RACING:
		return
	var progress_value: Variant = payload.get("progress")
	var loudness_value: Variant = payload.get("loudness")
	var boost_value: Variant = payload.get("boost_active")
	if not (progress_value is float or progress_value is int):
		return
	if not (loudness_value is float or loudness_value is int) or not boost_value is bool:
		return
	var progress := clampf(float(progress_value), 0.0, 1.0)
	var loudness := clampf(float(loudness_value), 0.0, 100.0)
	var boost_active := bool(boost_value)
	opponent_status_received.emit(progress, loudness, boost_active)

	var pos_value: Variant = payload.get("pos")
	var vel_value: Variant = payload.get("vel")
	var facing_value: Variant = payload.get("facing", 1.0)
	var on_floor_value: Variant = payload.get("on_floor", false)
	var events_value: Variant = payload.get("events", [])
	if pos_value is Array and (pos_value as Array).size() >= 2:
		var pos := Vector2(float((pos_value as Array)[0]), float((pos_value as Array)[1]))
		var vel := Vector2.ZERO
		if vel_value is Array and (vel_value as Array).size() >= 2:
			vel = Vector2(float((vel_value as Array)[0]), float((vel_value as Array)[1]))
		var facing := float(facing_value)
		var on_floor := bool(on_floor_value) or (vel != Vector2.ZERO and absf(vel.y) < 60.0)
		var events: Array = events_value if events_value is Array else []
		opponent_snapshot_received.emit(pos, vel, facing, on_floor, loudness, boost_active, events)


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
		_fail(tr("ONLINE_ERR_INVALID_RESULT"))
		return
	var times: Dictionary = times_value
	if not times.has(1) or not times.has(2) or not [1, 2].has(int(winner_value)):
		_fail(tr("ONLINE_ERR_INCOMPLETE_RESULT"))
		return
	finish_times = times.duplicate(true)
	state = MatchState.FINISHED
	match_finished.emit(finish_times.duplicate(true), int(winner_value))


func _receive_rematch_vote(payload: Dictionary) -> void:
	if state not in [MatchState.FINISHED, MatchState.REMATCH_WAITING]:
		return
	var slot_value: Variant = payload.get("slot")
	if not slot_value is int or int(slot_value) == player_slot or not bool(payload.get("accepted", false)):
		return
	_rematch_votes[int(slot_value)] = true
	if state == MatchState.FINISHED:
		state = MatchState.REMATCH_WAITING
	rematch_waiting.emit()
	_try_start_rematch()


func _try_start_rematch() -> void:
	if _role != MatchRole.HOST or not _rematch_votes.has(1) or not _rematch_votes.has(2):
		return
	finish_times.clear()
	_course_signatures.clear()
	_rematch_votes.clear()
	_start_setup_as_host()


func _on_peer_left(client_id: int) -> void:
	if state in [MatchState.IDLE, MatchState.FINISHED, MatchState.FAILED]:
		return
	opponent_left.emit(client_id)
	state = MatchState.FINISHED


func _on_connection_failed(reason: String) -> void:
	if state in [MatchState.IDLE, MatchState.FINISHED, MatchState.FAILED]:
		return
	_fail(reason)


func _on_online_disconnected() -> void:
	if state not in [MatchState.IDLE, MatchState.FINISHED, MatchState.FAILED]:
		_fail(tr("ONLINE_ERR_CONNECTION_LOST"))


func _send(kind: String, payload: Dictionary) -> void:
	_next_sequence += 1
	if not online_service.send_message(OnlineProtocol.make_message(kind, room_code, _next_sequence, payload)):
		_fail(tr("ONLINE_ERR_SEND_FAILED"))


func _fail(reason: String) -> void:
	state = MatchState.FAILED
	match_failed.emit(reason)


func _reset() -> void:
	finish_times.clear()
	_course_signatures.clear()
	_rematch_votes.clear()
	player_slot = 0
	race_seed = 0
	room_code = ""
	local_display_name = ""
	opponent_display_name = ""
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
