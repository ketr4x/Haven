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
