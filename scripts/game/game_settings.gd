class_name GameSettingsNode
extends Node

signal language_changed(locale: String)
signal master_volume_changed(volume: int)
signal crt_enabled_changed(enabled: bool)
signal fullscreen_changed(enabled: bool)
signal settings_changed

const DEFAULT_SETTINGS_PATH: String = "user://settings.cfg"
const DEFAULT_LANGUAGE: String = "en"
const SUPPORTED_LANGUAGES: Array[String] = ["en", "pl"]
const VOLUME_STEP: int = 10

const TRANSLATIONS_EN: Dictionary = {
	# Main menu & navigation
	"MENU_PLAY": "PLAY",
	"MENU_ONLINE": "ONLINE",
	"MENU_SETTINGS": "SETTINGS",
	"MENU_QUIT": "QUIT",
	"MENU_MAIN_PROMPT": "ARROWS / W S  SELECT      ENTER / SPACE  CONFIRM",
	"MENU_MAIN_HINT": "ECHO RACE",
	"MENU_QUICK_MATCH": "QUICK MATCH",
	"MENU_WITH_FRIEND": "WITH FRIEND",
	"MENU_ONLINE_PROMPT": "CHOOSE ONLINE MODE      ESC  BACK",
	"MENU_ONLINE_HINT": "MATCHMAKING WILL FIND OR CREATE A ROOM.",
	"MENU_CREATE_ROOM": "CREATE ROOM",
	"MENU_JOIN_BY_CODE": "JOIN BY CODE",
	"MENU_FRIENDS_PROMPT": "CHOOSE AN OPTION      ESC  BACK",
	"MENU_FRIENDS_HINT": "PRIVATE TWO-PLAYER RACE.",
	"MENU_JOIN_ROOM_TITLE": "JOIN ROOM",
	"MENU_JOIN_ROOM_HINT": "ENTER CODE AND PRESS ENTER.  ESC  BACK",
	"MENU_JOIN_ROOM_EMPTY_HINT": "ENTER THE CODE SHARED BY THE HOST.",
	"MENU_ROOM_CODE_PLACEHOLDER": "ROOM CODE",
	"MENU_CONNECTING": "CONNECTING…",
	"MENU_ESC_CANCEL": "ESC  CANCEL",
	"MENU_FINDING_OPPONENT": "FINDING OPPONENT…",
	"MENU_ROOM_CODE_DISPLAY": "ROOM CODE: %s",
	"MENU_SHARE_CODE_HINT": "SHARE THE CODE WITH A FRIEND.  ESC  CANCEL",

	# Settings menu
	"SETTINGS_TITLE": "SETTINGS",
	"SETTINGS_LANGUAGE": "LANGUAGE",
	"SETTINGS_LANG_EN": "ENGLISH",
	"SETTINGS_LANG_PL": "POLSKI",
	"SETTINGS_VOLUME": "VOLUME",
	"SETTINGS_CRT": "CRT FILTER",
	"SETTINGS_FULLSCREEN": "FULLSCREEN",
	"SETTINGS_ON": "ON",
	"SETTINGS_OFF": "OFF",
	"SETTINGS_BACK": "BACK",
	"SETTINGS_PROMPT": "ARROWS / WASD  ADJUST      ENTER  TOGGLE      ESC  BACK",
	"SETTINGS_HINT": "SETTINGS ARE SAVED AUTOMATICALLY.",

	# HUD & banners
	"HUD_PLAYER_1": "PLAYER 1",
	"HUD_PLAYER_2": "PLAYER 2",
	"HUD_YOU": "YOU",
	"HUD_OPPONENT": "OPPONENT",
	"HUD_TIME": "TIME  %s",
	"HUD_PLACE_1": "1ST PLACE",
	"HUD_PLACE_2": "2ND PLACE",
	"HUD_FINISH_GATE": "FINISH",
	"HUD_ROOM_CODE": "ROOM CODE  %s",
	"HUD_ROOM": "ROOM  %s",
	"HUD_CONNECTING": "CONNECTING…",
	"HUD_CONNECTED": "CONNECTED",
	"HUD_CONNECTING_OPPONENT": "CONNECTING TO OPPONENT…",
	"HUD_WAITING_PLAYER_2": "WAITING FOR SECOND PLAYER…",
	"HUD_VERIFYING_COURSE": "VERIFYING COURSE…",
	"HUD_YOU_FINISHED_WAIT": "YOU FINISHED. OPPONENT IS STILL RACING.",
	"HUD_PLAYER_FINISHED_WAIT": "PLAYER %d FINISHED. OTHER PLAYER IS STILL RACING.",
	"HUD_OPPONENT_FINISHED_GO": "OPPONENT FINISHED. KEEP RACING.",

	# Pause menu
	"PAUSE_TITLE": "PAUSE",
	"PAUSE_RESUME": "RESUME",
	"PAUSE_SETTINGS": "SETTINGS",
	"PAUSE_MENU": "MAIN MENU",
	"PAUSE_HINT": "ESC / ENTER  RESUME        M  MAIN MENU",
	"PAUSE_SETTINGS_HINT": "LEFT / RIGHT  ADJUST        ENTER  TOGGLE        ESC  BACK",

	# Result panel & online states
	"RESULT_PLAYER_WINS": "PLAYER %d WINS",
	"RESULT_YOU_WIN": "YOU WIN",
	"RESULT_OPPONENT_WINS": "OPPONENT WINS",
	"RESULT_TIMES": "PLAYER 1  %s\nPLAYER 2  %s",
	"RESULT_REMATCH_WAITING": "WAITING FOR REMATCH",
	"RESULT_REMATCH_WAIT_OTHER": "WAITING FOR THE OTHER PLAYER TO CONFIRM.",
	"RESULT_REMATCH_OPPONENT_WANTS": "OPPONENT WANTS A REMATCH. PRESS ENTER / R.",
	"RESULT_ONLINE_ACTIONS": "ENTER  REMATCH        ESC  MENU",
	"RESULT_ONLINE_SUMMARY": "ONLINE MATCH RESULT",
	"RESULT_LOCAL_ACTIONS": "R  REMATCH        N  NEW COURSE        ESC  MENU",
	"RESULT_LOCAL_REMINDER": "SHOUT (E / RSHIFT) TO LIGHT OBSTACLES AND BOOST",
	"RESULT_OPPONENT_LEFT": "OPPONENT LEFT THE MATCH",
	"RESULT_ONLINE_ENDED": "ONLINE MATCH ENDED",
	"RESULT_MATCH_FAILED": "COULD NOT START MATCH",
	"RESULT_CHECK_CONNECTION": "CHECK CONNECTION AND ROOM CODE",
	"RESULT_ESC_MENU": "ESC  MENU",

	# Leaderboard
	"LB_TITLE": "GLOBAL LEADERBOARD",
	"LB_PROMPT_DEFAULT": "ENTER NICKNAME FOR GLOBAL LEADERBOARD",
	"LB_PROMPT_WINNER": "ENTER WINNER NICKNAME (PLAYER %d) — %s",
	"LB_PROMPT_ONLINE": "ENTER NICKNAME FOR LEADERBOARD — YOUR TIME %s",
	"LB_PLACEHOLDER": "YOUR NAME (ENTER)",
	"LB_STATUS_READY": "ENTER  SUBMIT TIME TO GLOBAL LEADERBOARD",
	"LB_STATUS_EMPTY_NAME": "ENTER A PLAYER NAME BEFORE SUBMITTING.",
	"LB_STATUS_SAVING": "SAVING TIME TO GD-SYNC…",
	"LB_STATUS_SAVED": "SAVED: %s — %s",
	"LB_STATUS_NO_SERVICE": "ONLINE SERVICE UNAVAILABLE.",
	"LB_LOADING": "LOADING LEADERBOARD…",
	"LB_EMPTY": "NO SCORES YET.\nBE THE FIRST!",
	"LB_DEFAULT_PLAYER": "PLAYER",
	"LB_ERR_SHORT_NAME": "NAME MUST HAVE AT LEAST 3 CHARS (A-Z, 0-9).",
	"LB_ERR_INVALID_TIME": "INVALID RACE TIME.",
	"LB_ERR_NO_CONNECTION": "NO CONNECTION TO GD-SYNC.",
	"LB_ERR_SESSION": "FAILED TO CREATE GD-SYNC RUN SESSION.",
	"LB_ERR_NO_DB": "GD-SYNC DATABASE IS NOT INITIALIZED.",
	"LB_ERR_NO_BOARD": "LEADERBOARD '%s' DOES NOT EXIST IN GD-SYNC.",
	"LB_ERR_NOT_LOGGED_IN": "GD-SYNC DATABASE LOGIN REQUIRED.",
	"LB_ERR_NO_RESPONSE": "NO RESPONSE FROM GD-SYNC SERVER.",
	"LB_ERR_RATE_LIMIT": "GD-SYNC RATE LIMIT EXCEEDED.",
	"LB_ERR_STORAGE_FULL": "GD-SYNC DATA LIMIT REACHED.",
	"LB_ERR_SUBMIT": "LEADERBOARD SUBMIT ERROR (CODE %d).",
	"LB_ERR_BROWSE": "LEADERBOARD LOAD ERROR (CODE %d).",

	# Online match errors
	"ONLINE_ERR_ROOM_CODE": "Room code must contain 3 to 32 characters.",
	"ONLINE_ERR_INVALID_SEED": "Host sent an invalid course seed.",
	"ONLINE_ERR_INVALID_SIGNATURE": "Guest sent an invalid course signature.",
	"ONLINE_ERR_COURSE_MISMATCH": "The generated courses do not match.",
	"ONLINE_ERR_INVALID_COUNTDOWN": "Host sent an invalid countdown.",
	"ONLINE_ERR_INVALID_SLOT": "Opponent sent an invalid player slot.",
	"ONLINE_ERR_INVALID_FINISH_TIME": "Opponent sent an invalid finish time.",
	"ONLINE_ERR_INVALID_RESULT": "Host sent an invalid match result.",
	"ONLINE_ERR_INCOMPLETE_RESULT": "Host sent an incomplete match result.",
	"ONLINE_ERR_CONNECTION_LOST": "The online connection was lost.",
	"ONLINE_ERR_SEND_FAILED": "The online message could not be sent.",

	# Dev / lab scenes
	"LAB_SEED_STATUS": "Seed: %d   R / N generate a new course",
	"POC_TITLE": "REZONANS: NETWORK TEST",
	"POC_CONNECTING": "CONNECTING TO GD-SYNC…",
	"POC_LISTING_PUBLIC": "FETCHING PUBLIC ROOMS…",
	"POC_NO_MODE": "NO TEST MODE",
	"POC_NO_MODE_HINT": "Launch with --poc-mode=host, join, or browse.",
	"POC_CREATING_ROOM": "CREATING PRIVATE ROOM…",
	"POC_NO_ROOM_CODE": "MISSING ROOM CODE",
	"POC_NO_ROOM_CODE_HINT": "Launch with --poc-mode=join --poc-room=CODE.",
	"POC_JOINING_ROOM": "JOINING ROOM…",
	"POC_ROOM_CREATED": "ROOM CREATED. JOINING AS HOST…",
	"POC_ROOM_JOINED": "CONNECTED TO ROOM",
	"POC_WAITING_PEER": "Waiting for the second client and test message.",
	"POC_JOIN_FAILED": "COULD NOT JOIN",
	"POC_JOIN_REJECTED": "Room %s rejected the connection.",
	"POC_PUBLIC_ROOMS": "PUBLIC ROOMS: %d",
	"POC_PUBLIC_ROOMS_DETAILS": "Detected %d rooms total. Browse test finished.",
	"POC_PEER_JOINED": "SECOND CLIENT JOINED",
	"POC_SENDING_PROBE": "Sending test message to client %d…",
	"POC_PEER_LEFT": "SECOND CLIENT LEFT THE ROOM",
	"POC_PEER_DISCONNECTED": "Client %d disconnected.",
	"POC_PROBE_RECEIVED": "TEST MESSAGE RECEIVED",
	"POC_PROBE_DETAILS": "Client %d sent: %s",
	"POC_OP_REJECTED": "OPERATION REJECTED",
	"POC_CONNECT_FAILED": "FAILED TO CONNECT TO GD-SYNC",
	"POC_DISCONNECTED": "CONNECTION INTERRUPTED",
	"POC_DISCONNECTED_HINT": "Close the test and launch it again.",
	"POC_MODE_HOST_HINT": "Launch a second copy with the room code shown above.",
	"POC_MODE_JOIN_HINT": "Joining the room provided by the host.",
	"POC_MODE_BROWSE_HINT": "Checking the public test room directory.",
	"POC_MODE_DEFAULT_HINT": "Modes: host, join, browse.",
	"POC_LEAVING_ROOM": "LEAVING ROOM…",
}

const TRANSLATIONS_PL: Dictionary = {
	# Main menu & navigation
	"MENU_PLAY": "GRAJ",
	"MENU_ONLINE": "GRA ONLINE",
	"MENU_SETTINGS": "USTAWIENIA",
	"MENU_QUIT": "WYJDŹ",
	"MENU_MAIN_PROMPT": "STRZAŁKI / W S  WYBÓR      ENTER / SPACJA  ZATWIERDŹ",
	"MENU_MAIN_HINT": "WYŚCIG ECHA",
	"MENU_QUICK_MATCH": "SZYBKI MECZ",
	"MENU_WITH_FRIEND": "ZE ZNAJOMYM",
	"MENU_ONLINE_PROMPT": "WYBIERZ TRYB ONLINE      ESC  POWRÓT",
	"MENU_ONLINE_HINT": "POŁĄCZENIE ZNAJDZIE LUB UTWORZY POKÓJ.",
	"MENU_CREATE_ROOM": "STWÓRZ POKÓJ",
	"MENU_JOIN_BY_CODE": "DOŁĄCZ KODEM",
	"MENU_FRIENDS_PROMPT": "WYBIERZ OPCJĘ      ESC  POWRÓT",
	"MENU_FRIENDS_HINT": "PRYWATNY WYŚCIG DLA DWÓCH GRACZY.",
	"MENU_JOIN_ROOM_TITLE": "DOŁĄCZ DO POKOJU",
	"MENU_JOIN_ROOM_HINT": "WPISZ KOD I NACIŚNIJ ENTER.  ESC  POWRÓT",
	"MENU_JOIN_ROOM_EMPTY_HINT": "WPISZ KOD OTRZYMANY OD GOSPODARZA.",
	"MENU_ROOM_CODE_PLACEHOLDER": "KOD POKOJU",
	"MENU_CONNECTING": "ŁĄCZENIE…",
	"MENU_ESC_CANCEL": "ESC  ANULUJ",
	"MENU_FINDING_OPPONENT": "SZUKANIE PRZECIWNIKA…",
	"MENU_ROOM_CODE_DISPLAY": "KOD POKOJU: %s",
	"MENU_SHARE_CODE_HINT": "PRZEKAŻ KOD ZNAJOMEMU.  ESC  ANULUJ",

	# Settings menu
	"SETTINGS_TITLE": "USTAWIENIA",
	"SETTINGS_LANGUAGE": "JĘZYK",
	"SETTINGS_LANG_EN": "ENGLISH",
	"SETTINGS_LANG_PL": "POLSKI",
	"SETTINGS_VOLUME": "GŁOŚNOŚĆ",
	"SETTINGS_CRT": "FILTR CRT",
	"SETTINGS_FULLSCREEN": "PEŁNY EKRAN",
	"SETTINGS_ON": "WŁ.",
	"SETTINGS_OFF": "WYŁ.",
	"SETTINGS_BACK": "POWRÓT",
	"SETTINGS_PROMPT": "STRZAŁKI / WASD  ZMIEŃ      ENTER  PRZEŁĄCZ      ESC  POWRÓT",
	"SETTINGS_HINT": "USTAWIENIA ZAPISUJĄ SIĘ AUTOMATYCZNIE.",

	# HUD & banners
	"HUD_PLAYER_1": "GRACZ 1",
	"HUD_PLAYER_2": "GRACZ 2",
	"HUD_YOU": "TY",
	"HUD_OPPONENT": "PRZECIWNIK",
	"HUD_TIME": "CZAS  %s",
	"HUD_PLACE_1": "1. MIEJSCE",
	"HUD_PLACE_2": "2. MIEJSCE",
	"HUD_FINISH_GATE": "META",
	"HUD_ROOM_CODE": "KOD POKOJU  %s",
	"HUD_ROOM": "POKÓJ  %s",
	"HUD_CONNECTING": "ŁĄCZENIE…",
	"HUD_CONNECTED": "POŁĄCZONO",
	"HUD_CONNECTING_OPPONENT": "ŁĄCZENIE Z PRZECIWNIKIEM…",
	"HUD_WAITING_PLAYER_2": "CZEKA NA DRUGIEGO GRACZA…",
	"HUD_VERIFYING_COURSE": "SPRAWDZANIE TRASY…",
	"HUD_YOU_FINISHED_WAIT": "JESTEŚ NA MECIE. PRZECIWNIK JEDZIE DALEJ.",
	"HUD_PLAYER_FINISHED_WAIT": "GRACZ %d NA MECIE. DRUGI GRACZ JEDZIE DALEJ.",
	"HUD_OPPONENT_FINISHED_GO": "PRZECIWNIK JEST NA MECIE. JEDŹ DALEJ.",

	# Pause menu
	"PAUSE_TITLE": "PAUZA",
	"PAUSE_RESUME": "WRÓĆ DO GRY",
	"PAUSE_SETTINGS": "USTAWIENIA",
	"PAUSE_MENU": "WYJDŹ DO MENU",
	"PAUSE_HINT": "ESC / ENTER  WRÓĆ DO GRY        M  WYJŚCIE DO MENU",
	"PAUSE_SETTINGS_HINT": "LEWO / PRAWO  ZMIEŃ        ENTER  PRZEŁĄCZ        ESC  POWRÓT",

	# Result panel & online states
	"RESULT_PLAYER_WINS": "WYGRYWA GRACZ %d",
	"RESULT_YOU_WIN": "WYGRYWASZ",
	"RESULT_OPPONENT_WINS": "WYGRYWA PRZECIWNIK",
	"RESULT_TIMES": "GRACZ 1  %s\nGRACZ 2  %s",
	"RESULT_REMATCH_WAITING": "CZEKA NA REWANŻ",
	"RESULT_REMATCH_WAIT_OTHER": "DRUGI GRACZ MUSI POTWIERDZIĆ.",
	"RESULT_REMATCH_OPPONENT_WANTS": "PRZECIWNIK CHCE REWANŻU. WCIŚNIJ ENTER / R.",
	"RESULT_ONLINE_ACTIONS": "ENTER  REWANŻ        ESC  MENU",
	"RESULT_ONLINE_SUMMARY": "WYNIK MECZU ONLINE",
	"RESULT_LOCAL_ACTIONS": "R  REWANŻ        N  NOWA TRASA        ESC  MENU",
	"RESULT_LOCAL_REMINDER": "KRZYKNIJ (E / RSHIFT), ABY OŚWIETLIĆ PRZESZKODY I PRZYSPIESZYĆ",
	"RESULT_OPPONENT_LEFT": "PRZECIWNIK OPUŚCIŁ MECZ",
	"RESULT_ONLINE_ENDED": "MECZ ONLINE ZAKOŃCZONY",
	"RESULT_MATCH_FAILED": "NIE UDAŁO SIĘ ROZPOCZĄĆ MECZU",
	"RESULT_CHECK_CONNECTION": "SPRAWDŹ POŁĄCZENIE I KOD POKOJU",
	"RESULT_ESC_MENU": "ESC  MENU",

	# Leaderboard
	"LB_TITLE": "GLOBALNY RANKING",
	"LB_PROMPT_DEFAULT": "WPISZ NICK DO GLOBALNEGO RANKINGU",
	"LB_PROMPT_WINNER": "WPISZ NICK ZWYCIĘZCY (GRACZ %d) — %s",
	"LB_PROMPT_ONLINE": "WPISZ NICK DO RANKINGU — TWÓJ CZAS %s",
	"LB_PLACEHOLDER": "TWOJA NAZWA (ENTER)",
	"LB_STATUS_READY": "ENTER  ZAPISZ CZAS DO GLOBALNEGO RANKINGU",
	"LB_STATUS_EMPTY_NAME": "WPISZ NAZWĘ GRACZA PRZED ZATWIERDZENIEM.",
	"LB_STATUS_SAVING": "ZAPISYWANIE CZASU W GD-SYNC…",
	"LB_STATUS_SAVED": "ZAPISANO: %s — %s",
	"LB_STATUS_NO_SERVICE": "BRAK USŁUGI ONLINE.",
	"LB_LOADING": "WCZYTYWANIE RANKINGU…",
	"LB_EMPTY": "BRAK WYNIKÓW.\nBĄDŹ PIERWSZY!",
	"LB_DEFAULT_PLAYER": "GRACZ",
	"LB_ERR_SHORT_NAME": "NAZWA MUSI MIEĆ MIN. 3 ZNAKI (A-Z, 0-9).",
	"LB_ERR_INVALID_TIME": "NIEPRAWIDŁOWY CZAS WYŚCIGU.",
	"LB_ERR_NO_CONNECTION": "BRAK POŁĄCZENIA Z GD-SYNC.",
	"LB_ERR_SESSION": "BŁĄD TWORZENIA SESJI RUNU W GD-SYNC.",
	"LB_ERR_NO_DB": "BAZA GD-SYNC NIE JEST ZAINICJALIZOWANA.",
	"LB_ERR_NO_BOARD": "BRAK TABELI '%s' W GD-SYNC.",
	"LB_ERR_NOT_LOGGED_IN": "WYMAGANE LOGOWANIE W BAZIE GD-SYNC.",
	"LB_ERR_NO_RESPONSE": "BRAK ODPOWIEDZI SERWERA GD-SYNC.",
	"LB_ERR_RATE_LIMIT": "PRZEKROCZONO LIMIT ZAPYTAŃ GD-SYNC.",
	"LB_ERR_STORAGE_FULL": "LIMIT DANYCH GD-SYNC ZOSTAŁ WYCZERPANY.",
	"LB_ERR_SUBMIT": "BŁĄD ZAPISU DO RANKINGU (KOD %d).",
	"LB_ERR_BROWSE": "BŁĄD POBIERANIA RANKINGU (KOD %d).",

	# Online match errors
	"ONLINE_ERR_ROOM_CODE": "Kod pokoju musi mieć od 3 do 32 znaków.",
	"ONLINE_ERR_INVALID_SEED": "Gospodarz wysłał nieprawidłowe ziarno trasy.",
	"ONLINE_ERR_INVALID_SIGNATURE": "Gość wysłał nieprawidłową sygnaturę trasy.",
	"ONLINE_ERR_COURSE_MISMATCH": "Wygenerowane trasy nie są zgodne.",
	"ONLINE_ERR_INVALID_COUNTDOWN": "Gospodarz wysłał nieprawidłowe odliczanie.",
	"ONLINE_ERR_INVALID_SLOT": "Przeciwnik wysłał nieprawidłowy numer gracza.",
	"ONLINE_ERR_INVALID_FINISH_TIME": "Przeciwnik wysłał nieprawidłowy czas mety.",
	"ONLINE_ERR_INVALID_RESULT": "Gospodarz wysłał nieprawidłowy wynik meczu.",
	"ONLINE_ERR_INCOMPLETE_RESULT": "Gospodarz wysłał niekompletny wynik meczu.",
	"ONLINE_ERR_CONNECTION_LOST": "Połączenie online zostało przerwane.",
	"ONLINE_ERR_SEND_FAILED": "Nie udało się wysłać wiadomości online.",

	# Dev / lab scenes
	"LAB_SEED_STATUS": "Ziarno: %d   R / N losują nową trasę",
	"POC_TITLE": "REZONANS: TEST SIECI",
	"POC_CONNECTING": "ŁĄCZENIE Z GD-SYNC…",
	"POC_LISTING_PUBLIC": "POBIERANIE PUBLICZNYCH POKOI…",
	"POC_NO_MODE": "BRAK TRYBU TESTOWEGO",
	"POC_NO_MODE_HINT": "Uruchom z --poc-mode=host, join albo browse.",
	"POC_CREATING_ROOM": "TWORZENIE PRYWATNEGO POKOJU…",
	"POC_NO_ROOM_CODE": "BRAK KODU POKOJU",
	"POC_NO_ROOM_CODE_HINT": "Uruchom z --poc-mode=join --poc-room=KOD.",
	"POC_JOINING_ROOM": "DOŁĄCZANIE DO POKOJU…",
	"POC_ROOM_CREATED": "POKÓJ UTWORZONY. DOŁĄCZANIE GOSPODARZA…",
	"POC_ROOM_JOINED": "POŁĄCZONO Z POKOJEM",
	"POC_WAITING_PEER": "Czeka na drugiego klienta i wiadomość testową.",
	"POC_JOIN_FAILED": "NIE UDAŁO SIĘ DOŁĄCZYĆ",
	"POC_JOIN_REJECTED": "Pokój %s odrzucił połączenie.",
	"POC_PUBLIC_ROOMS": "PUBLICZNE POKOJE: %d",
	"POC_PUBLIC_ROOMS_DETAILS": "Wykryto %d pokoi ogółem. Test przeglądania zakończony.",
	"POC_PEER_JOINED": "DRUGI KLIENT DOŁĄCZYŁ",
	"POC_SENDING_PROBE": "Wysyłanie wiadomości testowej do klienta %d…",
	"POC_PEER_LEFT": "DRUGI KLIENT OPUŚCIŁ POKÓJ",
	"POC_PEER_DISCONNECTED": "Klient %d rozłączył się.",
	"POC_PROBE_RECEIVED": "WIADOMOŚĆ TESTOWA ODEBRANA",
	"POC_PROBE_DETAILS": "Klient %d wysłał: %s",
	"POC_OP_REJECTED": "OPERACJA ZOSTAŁA ODRZUCONA",
	"POC_CONNECT_FAILED": "NIE UDAŁO SIĘ POŁĄCZYĆ Z GD-SYNC",
	"POC_DISCONNECTED": "POŁĄCZENIE ZOSTAŁO PRZERWANE",
	"POC_DISCONNECTED_HINT": "Zamknij test i uruchom go ponownie.",
	"POC_MODE_HOST_HINT": "Uruchom drugą kopię z kodem widocznym powyżej.",
	"POC_MODE_JOIN_HINT": "Dołączanie do pokoju wskazanego przez gospodarza.",
	"POC_MODE_BROWSE_HINT": "Sprawdzanie publicznego katalogu pokoi testowych.",
	"POC_MODE_DEFAULT_HINT": "Tryby: host, join, browse.",
	"POC_LEAVING_ROOM": "OPUSZCZANIE POKOJU…",
}

static var _translations_registered: bool = false

var settings_path: String = DEFAULT_SETTINGS_PATH
var language: String = DEFAULT_LANGUAGE
var master_volume: int = 100
var crt_enabled: bool = true
var fullscreen: bool = false


static func ensure_translations_registered() -> void:
	if _translations_registered:
		return
	_translations_registered = true
	_register_locale_dictionary("en", TRANSLATIONS_EN)
	_register_locale_dictionary("pl", TRANSLATIONS_PL)
	TranslationServer.set_locale(DEFAULT_LANGUAGE)


static func _register_locale_dictionary(locale: String, messages: Dictionary) -> void:
	var translation := Translation.new()
	translation.locale = locale
	for key_variant in messages.keys():
		var key := StringName(str(key_variant))
		translation.add_message(key, StringName(str(messages[key_variant])))
	TranslationServer.add_translation(translation)


func _init() -> void:
	ensure_translations_registered()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_translations_registered()
	# Skip machine-local config loading in headless test runs so checks stay deterministic.
	if DisplayServer.get_name() != "headless":
		load_settings()
	_apply_all()


func set_language(next_language: String, persist: bool = true) -> void:
	var normalized := _normalize_language(next_language)
	var changed := language != normalized or TranslationServer.get_locale() != normalized
	language = normalized
	_apply_language()
	if persist:
		save_settings()
	if changed:
		language_changed.emit(language)
		settings_changed.emit()


func cycle_language(step: int = 1, persist: bool = true) -> void:
	var current_idx := SUPPORTED_LANGUAGES.find(language)
	if current_idx < 0:
		current_idx = 0
	var next_idx := posmod(current_idx + step, SUPPORTED_LANGUAGES.size())
	set_language(SUPPORTED_LANGUAGES[next_idx], persist)


func set_master_volume(volume: int, persist: bool = true) -> void:
	var clamped := clampi(volume, 0, 100)
	var changed := master_volume != clamped
	master_volume = clamped
	_apply_audio()
	if persist:
		save_settings()
	if changed:
		master_volume_changed.emit(master_volume)
		settings_changed.emit()


func adjust_master_volume(step_delta: int, wrap: bool = false, persist: bool = true) -> void:
	var next_volume := master_volume + step_delta * VOLUME_STEP
	if wrap:
		if next_volume > 100:
			next_volume = 0
		elif next_volume < 0:
			next_volume = 100
	set_master_volume(next_volume, persist)


func set_crt_enabled(enabled: bool, persist: bool = true) -> void:
	var changed := crt_enabled != enabled
	crt_enabled = enabled
	if persist:
		save_settings()
	if changed:
		crt_enabled_changed.emit(crt_enabled)
		settings_changed.emit()


func toggle_crt_enabled(persist: bool = true) -> void:
	set_crt_enabled(not crt_enabled, persist)


func set_fullscreen(enabled: bool, persist: bool = true) -> void:
	var changed := fullscreen != enabled
	fullscreen = enabled
	_apply_window_mode()
	if persist:
		save_settings()
	if changed:
		fullscreen_changed.emit(fullscreen)
		settings_changed.emit()


func toggle_fullscreen(persist: bool = true) -> void:
	set_fullscreen(not fullscreen, persist)


func get_language_display_name(locale: String = "") -> String:
	var target := language if locale.is_empty() else _normalize_language(locale)
	return TranslationServer.translate(&"SETTINGS_LANG_PL") if target == "pl" else TranslationServer.translate(&"SETTINGS_LANG_EN")


func reset_to_defaults(persist: bool = false) -> void:
	language = DEFAULT_LANGUAGE
	master_volume = 100
	crt_enabled = true
	fullscreen = false
	_apply_all()
	if persist:
		save_settings()
	language_changed.emit(language)
	master_volume_changed.emit(master_volume)
	crt_enabled_changed.emit(crt_enabled)
	fullscreen_changed.emit(fullscreen)
	settings_changed.emit()


func save_settings(path: String = "") -> Error:
	var target_path := settings_path if path.is_empty() else path
	if target_path.is_empty():
		return OK
	# Avoid polluting user settings when running automated headless checks with default path.
	if DisplayServer.get_name() == "headless" and path.is_empty() and target_path == DEFAULT_SETTINGS_PATH:
		return OK
	var config := ConfigFile.new()
	config.set_value("localization", "language", language)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("video", "crt_enabled", crt_enabled)
	config.set_value("video", "fullscreen", fullscreen)
	return config.save(target_path)


func load_settings(path: String = "") -> Error:
	var target_path := settings_path if path.is_empty() else path
	var config := ConfigFile.new()
	var err := config.load(target_path)
	if err != OK:
		return err
	language = _normalize_language(str(config.get_value("localization", "language", DEFAULT_LANGUAGE)))
	master_volume = clampi(int(config.get_value("audio", "master_volume", 100)), 0, 100)
	crt_enabled = bool(config.get_value("video", "crt_enabled", true))
	fullscreen = bool(config.get_value("video", "fullscreen", false))
	_apply_all()
	language_changed.emit(language)
	master_volume_changed.emit(master_volume)
	crt_enabled_changed.emit(crt_enabled)
	fullscreen_changed.emit(fullscreen)
	settings_changed.emit()
	return OK


func _normalize_language(raw: String) -> String:
	var lower := raw.strip_edges().to_lower()
	if lower.begins_with("pl"):
		return "pl"
	return "en"


func _apply_all() -> void:
	_apply_language()
	_apply_audio()
	_apply_window_mode()


func _apply_language() -> void:
	TranslationServer.set_locale(language)


func _apply_audio() -> void:
	var bus_index := AudioServer.get_bus_index(&"Master")
	if bus_index < 0:
		return
	var is_muted := master_volume <= 0
	AudioServer.set_bus_mute(bus_index, is_muted)
	if not is_muted:
		var linear := clampf(float(master_volume) / 100.0, 0.0, 1.0)
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear))


func _apply_window_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var target_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != target_mode:
		DisplayServer.window_set_mode(target_mode)
