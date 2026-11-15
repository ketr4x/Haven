class_name OnlineProtocol
extends RefCounted

const PROTOCOL_VERSION: int = 1
const MAX_MATCH_ID_LENGTH: int = 64
const MESSAGE_KINDS: PackedStringArray = [
	"hello",
	"race_setup",
	"course_ready",
	"race_start",
	"player_status",
	"player_died",
	"player_finished",
	"match_result",
	"rematch_vote",
]


static func make_message(kind: String, match_id: String, sequence: int, payload: Dictionary = {}) -> Dictionary:
	return {
		"kind": kind,
		"match_id": match_id,
		"payload": payload.duplicate(true),
		"protocol_version": PROTOCOL_VERSION,
		"sequence": sequence,
	}


static func validate_message(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return _invalid("Message must be a dictionary.")

	var message: Dictionary = value
	var protocol_value: Variant = message.get("protocol_version")
	if not protocol_value is int or int(protocol_value) != PROTOCOL_VERSION:
		return _invalid("Protocol version does not match.")

	var kind_value: Variant = message.get("kind")
	if not kind_value is String or not MESSAGE_KINDS.has(kind_value):
		return _invalid("Message kind is not supported.")

	var match_id_value: Variant = message.get("match_id")
	if not match_id_value is String or not _is_valid_match_id(match_id_value):
		return _invalid("Match ID is not valid.")

	var sequence_value: Variant = message.get("sequence")
	if not sequence_value is int or int(sequence_value) < 0:
		return _invalid("Sequence must be a non-negative integer.")

	var payload_value: Variant = message.get("payload")
	if not payload_value is Dictionary:
		return _invalid("Payload must be a dictionary.")

	return {
		"error": "",
		"message": message.duplicate(true),
		"valid": true,
	}


static func _is_valid_match_id(match_id: String) -> bool:
	return not match_id.is_empty() and match_id.length() <= MAX_MATCH_ID_LENGTH


static func _invalid(error: String) -> Dictionary:
	return {
		"error": error,
		"message": {},
		"valid": false,
	}
