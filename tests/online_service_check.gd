extends SceneTree

const LOCAL_MATCH_SERVICE := preload("res://scripts/online/local_match_service.gd")

var _connection_events: int = 0
var _listed_lobbies: Array = []
var _received_messages: Array = []
var _rejections: Array = []


func _initialize() -> void:
	var service := LOCAL_MATCH_SERVICE.new() as LocalMatchService
	root.add_child(service)
	service.online_connected.connect(_on_online_connected)
	service.lobbies_listed.connect(_on_lobbies_listed)
	service.message_received.connect(_on_message_received)
	service.operation_rejected.connect(_on_operation_rejected)

	assert(not service.is_online())
	assert(not service.send_message(_valid_message()))
	assert(_rejections.size() == 1)

	service.connect_online()
	assert(service.is_online())
	assert(_connection_events == 1)

	service.create_lobby("ECHO-TEST", "", true, 2, {"mode": "race"})
	assert(service.has_active_lobby())
	service.list_public_lobbies()
	assert(_listed_lobbies.size() == 1)
	assert((_listed_lobbies[0] as Dictionary).get("Tags", {}).get("mode", "") == "race")

	assert(service.send_message(_valid_message()))
	service.receive_message(2, _valid_message())
	assert(_received_messages.size() == 1)
	assert(int((_received_messages[0] as Dictionary).get("sender_id", -1)) == 2)

	var wrong_protocol := _valid_message()
	wrong_protocol["protocol_version"] = OnlineProtocol.PROTOCOL_VERSION + 1
	service.receive_message(2, wrong_protocol)
	assert(_received_messages.size() == 1)
	assert(_rejections.size() == 2)

	service.leave_lobby()
	assert(not service.has_active_lobby())
	assert(not service.send_message(_valid_message()))
	assert(_rejections.size() == 3)

	service.disconnect_online()
	assert(not service.is_online())
	service.queue_free()
	await process_frame
	print("Online service protocol check passed.")
	quit()


func _valid_message() -> Dictionary:
	return OnlineProtocol.make_message("hello", "match-123", 0, {"name": "Test"})


func _on_online_connected(_client_id: int) -> void:
	_connection_events += 1


func _on_lobbies_listed(lobbies: Array) -> void:
	_listed_lobbies = lobbies


func _on_message_received(sender_id: int, message: Dictionary) -> void:
	_received_messages.append({
		"message": message,
		"sender_id": sender_id,
	})


func _on_operation_rejected(_operation: String, _reason: String) -> void:
	_rejections.append(true)
