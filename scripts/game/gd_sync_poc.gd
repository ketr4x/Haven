extends Control

const POC_PROTOCOL_VERSION: int = 1
const ROOM_CODE_ALPHABET: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const ROOM_CODE_LENGTH: int = 8
const POC_TAGS: Dictionary = {
	"build": "poc",
	"mode": "gd_sync_poc",
	"protocol": POC_PROTOCOL_VERSION,
}
const GD_SYNC_CLIENT: GDScript = preload("res://addons/GD-Sync/MultiplayerClient.gd")

@onready var _status_label: Label = $Panel/Margin/VBox/Status
@onready var _room_code_label: Label = $Panel/Margin/VBox/RoomCode
@onready var _details_label: Label = $Panel/Margin/VBox/Details

var _mode: String = ""
var _room_code: String = ""
var _is_public_lobby: bool = false
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _gd_sync: Variant


func _ready() -> void:
	_random.randomize()
	_mode = _command_line_value("--poc-mode")
	_room_code = _command_line_value("--poc-room").to_upper()
	_is_public_lobby = _command_line_value("--poc-public") == "true"
	_status_label.text = "ŁĄCZENIE Z GD-SYNC…"
	_room_code_label.text = ""
	_details_label.text = _instructions_for_mode()

	_gd_sync = GD_SYNC_CLIENT.new()
	_gd_sync.name = "GDSync"
	get_tree().root.call_deferred("add_child", _gd_sync)
	await _gd_sync.ready

	_gd_sync.connected.connect(_on_connected)
	_gd_sync.connection_failed.connect(_on_connection_failed)
	_gd_sync.disconnected.connect(_on_disconnected)
	_gd_sync.lobby_created.connect(_on_lobby_created)
	_gd_sync.lobby_creation_failed.connect(_on_lobby_creation_failed)
	_gd_sync.lobby_joined.connect(_on_lobby_joined)
	_gd_sync.lobby_join_failed.connect(_on_lobby_join_failed)
	_gd_sync.lobbies_received.connect(_on_lobbies_received)
	_gd_sync.client_joined.connect(_on_client_joined)
	_gd_sync.client_left.connect(_on_client_left)
	_gd_sync.expose_func(_receive_probe)
	_gd_sync.start_multiplayer()
	_schedule_test_leave()
	_schedule_automatic_exit()


func _exit_tree() -> void:
	if not is_instance_valid(_gd_sync):
		return
	if _gd_sync.is_active():
		_gd_sync.lobby_leave()
	_gd_sync.queue_free()


func _on_connected() -> void:
	_print_event("connected")
	match _mode:
		"host":
			_create_private_lobby()
		"join":
			_join_private_lobby()
		"browse":
			_status_label.text = "POBIERANIE PUBLICZNYCH POKOI…"
			_gd_sync.get_public_lobbies()
		_:
			_status_label.text = "BRAK TRYBU TESTOWEGO"
			_details_label.text = "Uruchom z --poc-mode=host, join albo browse."


func _create_private_lobby() -> void:
	if _room_code.is_empty():
		_room_code = _create_room_code()
	_status_label.text = "TWORZENIE PRYWATNEGO POKOJU…"
	_room_code_label.text = "KOD POKOJU: %s" % _room_code
	_gd_sync.lobby_create(_room_code, "", _is_public_lobby, 2, POC_TAGS)


func _join_private_lobby() -> void:
	if _room_code.is_empty():
		_status_label.text = "BRAK KODU POKOJU"
		_details_label.text = "Uruchom z --poc-mode=join --poc-room=KOD."
		return
	_status_label.text = "DOŁĄCZANIE DO POKOJU…"
	_room_code_label.text = "KOD POKOJU: %s" % _room_code
	_gd_sync.lobby_join(_room_code)


func _on_lobby_created(lobby_name: String) -> void:
	_print_event("lobby_created=%s" % lobby_name)
	_status_label.text = "POKÓJ UTWORZONY. DOŁĄCZANIE GOSPODARZA…"
	_gd_sync.lobby_join(lobby_name)


func _on_lobby_creation_failed(lobby_name: String, error: int) -> void:
	_print_event("lobby_creation_failed=%s error=%d" % [lobby_name, error])
	_status_label.text = "NIE UDAŁO SIĘ UTWORZYĆ POKOJU"
	_details_label.text = "Kod %s zwrócił błąd %d. Uruchom ponownie hosta." % [lobby_name, error]


func _on_lobby_joined(lobby_name: String) -> void:
	_print_event("lobby_joined=%s" % lobby_name)
	_room_code = lobby_name
	_status_label.text = "POŁĄCZONO Z POKOJEM"
	_room_code_label.text = "KOD POKOJU: %s" % _room_code
	_details_label.text = "Czeka na drugiego klienta i wiadomość testową."


func _on_lobby_join_failed(lobby_name: String, error: int) -> void:
	_print_event("lobby_join_failed=%s error=%d" % [lobby_name, error])
	_status_label.text = "NIE UDAŁO SIĘ DOŁĄCZYĆ"
	_details_label.text = "Pokój %s zwrócił błąd %d." % [lobby_name, error]


func _on_lobbies_received(lobbies: Array) -> void:
	_print_event("public_lobbies=%d" % lobbies.size())
	var matching_lobbies: int = 0
	for lobby_value in lobbies:
		if not lobby_value is Dictionary:
			continue
		var lobby: Dictionary = lobby_value
		var tags_value: Variant = lobby.get("Tags", {})
		if tags_value is Dictionary and (tags_value as Dictionary).get("mode", "") == POC_TAGS["mode"]:
			matching_lobbies += 1
	_status_label.text = "PUBLICZNE POKOJE: %d" % matching_lobbies
	_details_label.text = "Wykryto %d pokoi ogółem. Test przeglądania zakończony." % lobbies.size()


func _on_client_joined(client_id: int) -> void:
	if client_id == _gd_sync.get_client_id():
		return
	_print_event("peer_joined=%d" % client_id)
	_status_label.text = "DRUGI KLIENT DOŁĄCZYŁ"
	_details_label.text = "Wysyłanie wiadomości testowej do klienta %d…" % client_id
	_gd_sync.call_func(_receive_probe, _gd_sync.get_client_id(), "echo-poc")


func _on_client_left(client_id: int) -> void:
	_status_label.text = "DRUGI KLIENT OPUŚCIŁ POKÓJ"
	_details_label.text = "Klient %d rozłączył się." % client_id


func _receive_probe(sender_id: int, payload: String) -> void:
	_print_event("probe_received_from=%d payload=%s" % [sender_id, payload])
	_status_label.text = "WIADOMOŚĆ TESTOWA ODEBRANA"
	_details_label.text = "Klient %d wysłał: %s" % [sender_id, payload]
	if payload == "echo-poc":
		_gd_sync.call_func(_receive_probe, _gd_sync.get_client_id(), "echo-ack")


func _on_connection_failed(error: int) -> void:
	_print_event("connection_failed=%d" % error)
	_status_label.text = "NIE UDAŁO SIĘ POŁĄCZYĆ Z GD-SYNC"
	_details_label.text = "Błąd połączenia: %d." % error


func _on_disconnected() -> void:
	_print_event("disconnected")
	_status_label.text = "POŁĄCZENIE ZOSTAŁO PRZERWANE"
	_details_label.text = "Zamknij test i uruchom go ponownie."


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
			return "Uruchom drugą kopię z kodem widocznym powyżej."
		"join":
			return "Dołączanie do pokoju wskazanego przez gospodarza."
		"browse":
			return "Sprawdzanie publicznego katalogu pokoi testowych."
		_:
			return "Tryby: host, join, browse."


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
	if not _gd_sync.is_active():
		return
	_print_event("leaving_lobby_after=%.1f" % leave_after_seconds)
	_status_label.text = "OPUSZCZANIE POKOJU…"
	_gd_sync.lobby_leave()


func _quit_after_timeout(timeout_seconds: float) -> void:
	_print_event("timeout_after=%.1f" % timeout_seconds)
	get_tree().quit()


func _print_event(event: String) -> void:
	print("GD_SYNC_POC %s" % event)
