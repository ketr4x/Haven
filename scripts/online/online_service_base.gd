class_name OnlineServiceBase
extends Node

signal connection_failed(reason: String)
signal lobby_created(lobby_name: String)
signal lobby_join_failed(lobby_name: String, reason: String)
signal lobby_joined(lobby_name: String)
signal lobbies_listed(lobbies: Array)
signal message_received(sender_id: int, message: Dictionary)
signal online_connected(client_id: int)
signal online_disconnected
signal operation_rejected(operation: String, reason: String)
signal peer_joined(client_id: int)
signal peer_left(client_id: int)
signal leaderboard_score_submitted(leaderboard_name: String, username: String, score_ms: int)
signal leaderboard_submission_failed(leaderboard_name: String, reason: String)
signal leaderboard_scores_loaded(leaderboard_name: String, entries: Array)
signal leaderboard_load_failed(leaderboard_name: String, reason: String)

const DEFAULT_LEADERBOARD_NAME: String = "global_times"
const DEFAULT_LEADERBOARD_PAGE_SIZE: int = 15

enum ConnectionState {
	OFFLINE,
	CONNECTING,
	ONLINE,
}

var active_lobby_name: String = ""
var connection_state: ConnectionState = ConnectionState.OFFLINE


func is_online() -> bool:
	return connection_state == ConnectionState.ONLINE


func is_connecting() -> bool:
	return connection_state == ConnectionState.CONNECTING


func has_active_lobby() -> bool:
	return not active_lobby_name.is_empty()


func connect_online() -> void:
	_reject("connect_online", "The configured online service does not implement connections.")


func disconnect_online() -> void:
	connection_state = ConnectionState.OFFLINE
	active_lobby_name = ""


func create_lobby(
	lobby_name: String,
	password: String = "",
	is_public: bool = false,
	player_limit: int = 2,
	tags: Dictionary = {}
) -> void:
	_reject("create_lobby", "The configured online service does not implement lobbies.")


func join_lobby(lobby_name: String, password: String = "") -> void:
	_reject("join_lobby", "The configured online service does not implement lobbies.")


func leave_lobby() -> void:
	active_lobby_name = ""


func list_public_lobbies() -> void:
	_reject("list_public_lobbies", "The configured online service does not implement lobby browsing.")


func send_message(message: Dictionary) -> bool:
	_reject("send_message", "The configured online service does not implement messages.")
	return false


func submit_leaderboard_time(
	username: String,
	elapsed_seconds: float,
	leaderboard_name: String = DEFAULT_LEADERBOARD_NAME,
	extra_data: Dictionary = {}
) -> void:
	_reject("submit_leaderboard_time", "The configured online service does not implement leaderboards.")


func browse_leaderboard_times(
	leaderboard_name: String = DEFAULT_LEADERBOARD_NAME,
	page_size: int = DEFAULT_LEADERBOARD_PAGE_SIZE,
	page: int = 1
) -> void:
	_reject("browse_leaderboard_times", "The configured online service does not implement leaderboards.")


func get_client_id() -> int:
	return -1


func get_synchronized_time() -> float:
	return 0.0


func _reject(operation: String, reason: String) -> void:
	operation_rejected.emit(operation, reason)


func _is_valid_lobby_name(lobby_name: String) -> bool:
	return lobby_name.length() >= 3 and lobby_name.length() <= 32


func _is_valid_password(password: String) -> bool:
	return password.length() <= 16


func _sanitize_leaderboard_username(username: String) -> String:
	var cleaned := username.strip_edges()
	var valid_chars := ""
	for i in cleaned.length():
		var ch := cleaned[i]
		var code := ch.unicode_at(0)
		var is_alnum := (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		if is_alnum or ch == "_" or ch == "-":
			valid_chars += ch
		elif ch == " ":
			valid_chars += "_"
	if valid_chars.length() > 15:
		valid_chars = valid_chars.substr(0, 15)
	return valid_chars

