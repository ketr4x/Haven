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
