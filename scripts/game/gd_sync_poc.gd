extends Control

const POC_PROTOCOL_VERSION: int = 1
const ROOM_CODE_ALPHABET: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const ROOM_CODE_LENGTH: int = 8
const POC_TAGS: Dictionary = {
	"build": "poc",
	"mode": "gd_sync_poc",
	"protocol": POC_PROTOCOL_VERSION,
}

@onready var _title_label: Label = $Panel/Margin/VBox/Title
@onready var _status_label: Label = $Panel/Margin/VBox/Status
@onready var _room_code_label: Label = $Panel/Margin/VBox/RoomCode
@onready var _details_label: Label = $Panel/Margin/VBox/Details
@onready var _online_service: OnlineServiceBase = get_node("/root/OnlineService") as OnlineServiceBase

var _mode: String = ""
var _room_code: String = ""
var _is_public_lobby: bool = false
var _next_sequence: int = 0
var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_random.randomize()
	_mode = _command_line_value("--poc-mode")
	_room_code = _command_line_value("--poc-room").to_upper()
	_is_public_lobby = _command_line_value("--poc-public") == "true"
	if _title_label != null:
		_title_label.text = tr("POC_TITLE")
	_status_label.text = tr("POC_CONNECTING")
	_room_code_label.text = ""
	_details_label.text = _instructions_for_mode()

	_online_service.online_connected.connect(_on_connected)
	_online_service.connection_failed.connect(_on_connection_failed)
	_online_service.online_disconnected.connect(_on_disconnected)
	_online_service.lobby_created.connect(_on_lobby_created)
	_online_service.lobby_joined.connect(_on_lobby_joined)
	_online_service.lobby_join_failed.connect(_on_lobby_join_failed)
	_online_service.lobbies_listed.connect(_on_lobbies_listed)
	_online_service.peer_joined.connect(_on_peer_joined)
	_online_service.peer_left.connect(_on_peer_left)
	_online_service.message_received.connect(_on_message_received)
	_online_service.operation_rejected.connect(_on_operation_rejected)
	_online_service.connect_online()
	_schedule_automatic_exit()


func _exit_tree() -> void:
	_online_service.leave_lobby()


func _on_connected(client_id: int) -> void:
	_print_event("connected=%d" % client_id)
	match _mode:
		"host":
			_create_private_lobby()
		"join":
			_join_private_lobby()
		"browse":
			_status_label.text = tr("POC_LISTING_PUBLIC")
			_online_service.list_public_lobbies()
		_:
			_status_label.text = tr("POC_NO_MODE")
			_details_label.text = tr("POC_NO_MODE_HINT")


func _create_private_lobby() -> void:
	if _room_code.is_empty():
		_room_code = _create_room_code()
	_status_label.text = tr("POC_CREATING_ROOM")
	_room_code_label.text = tr("MENU_ROOM_CODE_DISPLAY") % _room_code
	_online_service.create_lobby(_room_code, "", _is_public_lobby, 2, POC_TAGS)


func _join_private_lobby() -> void:
	if _room_code.is_empty():
		_status_label.text = tr("POC_NO_ROOM_CODE")
		_details_label.text = tr("POC_NO_ROOM_CODE_HINT")
		return
	_status_label.text = tr("POC_JOINING_ROOM")
	_room_code_label.text = tr("MENU_ROOM_CODE_DISPLAY") % _room_code
	_online_service.join_lobby(_room_code)


func _on_lobby_created(lobby_name: String) -> void:
	_print_event("lobby_created=%s" % lobby_name)
	_status_label.text = tr("POC_ROOM_CREATED")
	_online_service.join_lobby(lobby_name)


func _on_lobby_joined(lobby_name: String) -> void:
	_print_event("lobby_joined=%s" % lobby_name)
	_room_code = lobby_name
	_status_label.text = tr("POC_ROOM_JOINED")
	_room_code_label.text = tr("MENU_ROOM_CODE_DISPLAY") % _room_code
	_details_label.text = tr("POC_WAITING_PEER")
	_schedule_test_leave()


func _on_lobby_join_failed(lobby_name: String, reason: String) -> void:
	_print_event("lobby_join_failed=%s reason=%s" % [lobby_name, reason])
	_status_label.text = tr("POC_JOIN_FAILED")
	_details_label.text = tr("POC_JOIN_REJECTED") % lobby_name


func _on_lobbies_listed(lobbies: Array) -> void:
	_print_event("public_lobbies=%d" % lobbies.size())
	var matching_lobbies: int = 0
	for lobby_value in lobbies:
		if not lobby_value is Dictionary:
			continue
		var lobby: Dictionary = lobby_value
		var tags_value: Variant = lobby.get("Tags", {})
		if tags_value is Dictionary and (tags_value as Dictionary).get("mode", "") == POC_TAGS["mode"]:
			matching_lobbies += 1
	_status_label.text = tr("POC_PUBLIC_ROOMS") % matching_lobbies
	_details_label.text = tr("POC_PUBLIC_ROOMS_DETAILS") % lobbies.size()


func _on_peer_joined(client_id: int) -> void:
	_print_event("peer_joined=%d" % client_id)
	_status_label.text = tr("POC_PEER_JOINED")
	_details_label.text = tr("POC_SENDING_PROBE") % client_id
	_send_probe("echo-poc")


func _on_peer_left(client_id: int) -> void:
	_print_event("peer_left=%d" % client_id)
	_status_label.text = tr("POC_PEER_LEFT")
	_details_label.text = tr("POC_PEER_DISCONNECTED") % client_id


func _on_message_received(sender_id: int, message: Dictionary) -> void:
	var payload: Dictionary = message["payload"] as Dictionary
	var probe: String = str(payload.get("probe", ""))
	_print_event("probe_received_from=%d payload=%s" % [sender_id, probe])
	_status_label.text = tr("POC_PROBE_RECEIVED")
	_details_label.text = tr("POC_PROBE_DETAILS") % [sender_id, probe]
	if probe == "echo-poc":
		_send_probe("echo-ack")


func _on_operation_rejected(operation: String, reason: String) -> void:
	_print_event("operation_rejected=%s reason=%s" % [operation, reason])
	_status_label.text = tr("POC_OP_REJECTED")
	_details_label.text = reason


func _on_connection_failed(reason: String) -> void:
	_print_event("connection_failed=%s" % reason)
	_status_label.text = tr("POC_CONNECT_FAILED")
	_details_label.text = reason


func _on_disconnected() -> void:
	_print_event("disconnected")
	_status_label.text = tr("POC_DISCONNECTED")
	_details_label.text = tr("POC_DISCONNECTED_HINT")


func _send_probe(probe: String) -> void:
	_next_sequence += 1
	_online_service.send_message(OnlineProtocol.make_message(
		"hello",
		_room_code,
		_next_sequence,
		{"probe": probe},
	))


func _command_line_value(flag: String) -> String:
	var prefix := "%s=" % flag
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _create_room_code() -> String:
	var room_code := ""
	for index in ROOM_CODE_LENGTH:
		room_code += ROOM_CODE_ALPHABET[_random.randi_range(0, ROOM_CODE_ALPHABET.length() - 1)]
	return room_code


func _instructions_for_mode() -> String:
	match _mode:
		"host":
			return tr("POC_MODE_HOST_HINT")
		"join":
			return tr("POC_MODE_JOIN_HINT")
		"browse":
			return tr("POC_MODE_BROWSE_HINT")
		_:
			return tr("POC_MODE_DEFAULT_HINT")


func _schedule_automatic_exit() -> void:
	var timeout_seconds := _command_line_value("--poc-quit-after").to_float()
	if timeout_seconds <= 0.0:
		return
	get_tree().create_timer(timeout_seconds).timeout.connect(_quit_after_timeout.bind(timeout_seconds))


func _schedule_test_leave() -> void:
	var leave_after_seconds := _command_line_value("--poc-leave-after").to_float()
	if leave_after_seconds <= 0.0:
		return
	get_tree().create_timer(leave_after_seconds).timeout.connect(_leave_lobby_for_test.bind(leave_after_seconds))


func _leave_lobby_for_test(leave_after_seconds: float) -> void:
	if not _online_service.has_active_lobby():
		return
	_print_event("leaving_lobby_after=%.1f" % leave_after_seconds)
	_status_label.text = tr("POC_LEAVING_ROOM")
	_online_service.leave_lobby()


func _quit_after_timeout(timeout_seconds: float) -> void:
	_print_event("timeout_after=%.1f" % timeout_seconds)
	get_tree().quit()


func _print_event(event: String) -> void:
	print("GD_SYNC_POC %s" % event)
