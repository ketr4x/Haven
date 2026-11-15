class_name MainMenu
extends Control

signal start_requested
signal quit_requested
signal outro_finished

const FRAME_SIZE := Vector2(144.0, 96.0)
const ANIM_IDLE := &"idle"
const ANIM_OUTRO := &"outro"
const SELECTED_COLOR := Color(0.960784, 0.960784, 0.960784, 1.0)
const UNSELECTED_COLOR := Color(0.74902, 0.74902, 0.74902, 0.92)
const OPTION_TEXTS: Array[String] = ["GRAJ", "WYJDŹ"]

@onready var _background_sprite: AnimatedSprite2D = $BackgroundSprite
@onready var _menu_overlay: Control = $MenuOverlay
@onready var _option_rows: Array[Control] = [
	$MenuOverlay/MenuItems/PlayOption,
	$MenuOverlay/MenuItems/QuitOption,
]
@onready var _cursor_labels: Array[Label] = [
	$MenuOverlay/MenuItems/PlayOption/Cursor,
	$MenuOverlay/MenuItems/QuitOption/Cursor,
]
@onready var _option_labels: Array[Label] = [
	$MenuOverlay/MenuItems/PlayOption/Text,
	$MenuOverlay/MenuItems/QuitOption/Text,
]

var _selected_index: int = 0
var _is_playing_outro: bool = false


func _ready() -> void:
	resized.connect(_update_background_layout)
	_background_sprite.animation_finished.connect(_on_background_animation_finished)
	for index in _option_rows.size():
		var row := _option_rows[index]
		row.mouse_entered.connect(_on_option_mouse_entered.bind(index))
		row.gui_input.connect(_on_option_gui_input.bind(index))
	_update_background_layout()
	reset_to_idle()


func reset_to_idle() -> void:
	_is_playing_outro = false
	_selected_index = 0
	_update_option_visuals()
	_menu_overlay.visible = true
	_background_sprite.play(ANIM_IDLE)


func play_outro() -> void:
	if _is_playing_outro:
		return
	_is_playing_outro = true
	_menu_overlay.visible = false
	_background_sprite.play(ANIM_OUTRO)


func is_playing_outro() -> bool:
	return _is_playing_outro


func get_selected_index() -> int:
	return _selected_index


func handle_menu_input(event: InputEvent) -> bool:
	if _is_playing_outro:
		return false

	if event.is_action_pressed(&"ui_up") \
		or event.is_action_pressed(&"p1_jump") \
		or event.is_action_pressed(&"p2_jump"):
		_move_selection(-1)
		return true

	if event.is_action_pressed(&"ui_down") \
		or event.is_action_pressed(&"p1_shout") \
		or event.is_action_pressed(&"p2_shout"):
		_move_selection(1)
		return true

	if event.is_action_pressed(&"ui_accept"):
		_activate_selected_option()
		return true

	return false


func _move_selection(delta: int) -> void:
	_selected_index = posmod(_selected_index + delta, _option_rows.size())
	_update_option_visuals()


func _activate_selected_option() -> void:
	if _selected_index == 0:
		start_requested.emit()
	elif _selected_index == 1:
		quit_requested.emit()


func _update_option_visuals() -> void:
	for index in _option_rows.size():
		var is_selected := index == _selected_index
		var color := SELECTED_COLOR if is_selected else UNSELECTED_COLOR
		_cursor_labels[index].text = ">" if is_selected else ""
		_cursor_labels[index].add_theme_color_override(&"font_color", color)
		_option_labels[index].text = OPTION_TEXTS[index]
		_option_labels[index].add_theme_color_override(&"font_color", color)


func _update_background_layout() -> void:
	if _background_sprite == null:
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return

	# Top-aligned cover scaling fills the screen without cropping the upper logo or character.
	var cover_scale := maxf(size.x / FRAME_SIZE.x, size.y / FRAME_SIZE.y)
	_background_sprite.scale = Vector2(cover_scale, cover_scale)
	var scaled_width := FRAME_SIZE.x * cover_scale
	_background_sprite.position = Vector2((size.x - scaled_width) * 0.5, 0.0)


func _on_option_mouse_entered(index: int) -> void:
	if _is_playing_outro:
		return
	_selected_index = index
	_update_option_visuals()


func _on_option_gui_input(event: InputEvent, index: int) -> void:
	if _is_playing_outro:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_selected_index = index
			_update_option_visuals()
			_activate_selected_option()


func _on_background_animation_finished() -> void:
	if _is_playing_outro and _background_sprite.animation == ANIM_OUTRO:
		_is_playing_outro = false
		outro_finished.emit()
