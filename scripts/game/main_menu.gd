class_name MainMenu
extends Control

signal option_selected(index: int)
signal quit_requested
signal outro_finished
signal room_code_submitted(room_code: String)

const FRAME_SIZE := Vector2(144.0, 96.0)
const ANIM_IDLE := &"idle"
const ANIM_OUTRO := &"outro"
const SELECTED_COLOR := Color(0.960784, 0.960784, 0.960784, 1.0)
const UNSELECTED_COLOR := Color(0.74902, 0.74902, 0.74902, 0.92)
const DEFAULT_OPTIONS: Array[String] = ["GRAJ", "GRA ONLINE", "WYJDŹ"]
const DEFAULT_PROMPT: String = "STRZAŁKI / W S  WYBÓR      ENTER / SPACJA  ZATWIERDŹ"
const DEFAULT_HINT: String = "WYŚCIG ECHA"

@onready var _background_sprite: AnimatedSprite2D = $BackgroundSprite
@onready var _moon_halo: Sprite2D = get_node_or_null("BackgroundSprite/MoonHalo") as Sprite2D
@onready var _moon_light: PointLight2D = get_node_or_null("BackgroundSprite/MoonLight") as PointLight2D
@onready var _wind_streaks: CPUParticles2D = $WindStreaks
@onready var _wind_dust: CPUParticles2D = $WindDust
@onready var _menu_overlay: Control = $MenuOverlay
@onready var _prompt_label: Label = $MenuOverlay/Prompt
@onready var _hint_label: Label = $MenuOverlay/Hint
@onready var _room_code_input: LineEdit = $MenuOverlay/RoomCodeInput
@onready var _option_rows: Array[Control] = [
	$MenuOverlay/MenuItems/PlayOption,
	$MenuOverlay/MenuItems/OnlineOption,
	$MenuOverlay/MenuItems/QuitOption,
]
@onready var _cursor_labels: Array[Label] = [
	$MenuOverlay/MenuItems/PlayOption/Cursor,
	$MenuOverlay/MenuItems/OnlineOption/Cursor,
	$MenuOverlay/MenuItems/QuitOption/Cursor,
]
@onready var _option_labels: Array[Label] = [
	$MenuOverlay/MenuItems/PlayOption/Text,
	$MenuOverlay/MenuItems/OnlineOption/Text,
	$MenuOverlay/MenuItems/QuitOption/Text,
]
@onready var _ui_move: AudioStreamPlayer = get_node_or_null("UIMove") as AudioStreamPlayer
@onready var _ui_select: AudioStreamPlayer = get_node_or_null("UISelect") as AudioStreamPlayer

var _selected_index: int = 0
var _is_playing_outro: bool = false
var _option_texts: Array[String] = DEFAULT_OPTIONS.duplicate()
var _moon_pulse_time: float = 0.0


func _ready() -> void:
	resized.connect(_update_background_layout)
	_background_sprite.animation_finished.connect(_on_background_animation_finished)
	_room_code_input.text_submitted.connect(_on_room_code_text_submitted)
	for index in _option_rows.size():
		var row := _option_rows[index]
		row.mouse_entered.connect(_on_option_mouse_entered.bind(index))
		row.gui_input.connect(_on_option_gui_input.bind(index))
	_setup_wind_particles()
	_setup_moon_light()
	_update_background_layout()
	reset_to_idle()


func _process(delta: float) -> void:
	_moon_pulse_time += delta
	var wave := sin(_moon_pulse_time * 1.4)
	if _moon_light != null:
		_moon_light.energy = 0.88 + wave * 0.12
	if _moon_halo != null:
		_moon_halo.modulate.a = 0.38 + wave * 0.08
		var s := 0.38 + wave * 0.025
		_moon_halo.scale = Vector2(s, s)


func _setup_wind_particles() -> void:
	if _wind_streaks == null:
		return
	var img := Image.create(10, 1, false, Image.FORMAT_RGBA8)
	for x in 10:
		var edge_fade := sin(PI * float(x + 1) / 11.0) * 0.75
		img.set_pixel(x, 0, Color(1.0, 1.0, 1.0, edge_fade))
	_wind_streaks.texture = ImageTexture.create_from_image(img)


func _setup_moon_light() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 0.65, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(0.96, 0.98, 1.0, 0.65),
		Color(0.88, 0.94, 1.0, 0.18),
		Color(0.85, 0.92, 1.0, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)

	if _moon_light != null:
		_moon_light.texture = tex
	if _moon_halo != null:
		_moon_halo.texture = tex
		var add_mat := CanvasItemMaterial.new()
		add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_moon_halo.material = add_mat


func reset_to_idle() -> void:
	_is_playing_outro = false
	_selected_index = 0
	_set_options(DEFAULT_OPTIONS)
	_set_room_code_visible(false)
	_set_footer(DEFAULT_PROMPT, DEFAULT_HINT)
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


func get_option_text(index: int) -> String:
	if index < 0 or index >= _option_texts.size():
		return ""
	return _option_texts[index]


func show_options(options: Array[String], prompt: String, hint: String) -> void:
	_set_options(options)
	_set_room_code_visible(false)
	_set_footer(prompt, hint)
	_menu_overlay.visible = true


func show_room_code_entry(prompt: String, hint: String) -> void:
	_set_options([])
	_set_footer(prompt, hint)
	_set_room_code_visible(true)
	_room_code_input.clear()
	_room_code_input.grab_focus()
	_menu_overlay.visible = true


func show_waiting(prompt: String, hint: String) -> void:
	_set_options([])
	_set_room_code_visible(false)
	_set_footer(prompt, hint)
	_menu_overlay.visible = true


func handle_menu_input(event: InputEvent) -> bool:
	if _is_playing_outro or _option_texts.is_empty() or _room_code_input.visible:
		return false

	if event.is_action_pressed(&"ui_accept"):
		_play_ui_select()
		option_selected.emit(_selected_index)
		return true

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

	return false


func _set_options(options: Array[String]) -> void:
	_option_texts = options.duplicate()
	_selected_index = 0
	for index in _option_rows.size():
		_option_rows[index].visible = index < _option_texts.size()
	_update_option_visuals()


func _set_footer(prompt: String, hint: String) -> void:
	_prompt_label.text = prompt
	_hint_label.text = hint


func _set_room_code_visible(is_visible: bool) -> void:
	_room_code_input.visible = is_visible


func _move_selection(delta: int) -> void:
	_selected_index = posmod(_selected_index + delta, _option_texts.size())
	_update_option_visuals()
	_play_ui_move()


func _update_option_visuals() -> void:
	for index in _option_rows.size():
		if index >= _option_texts.size():
			continue
		var is_selected := index == _selected_index
		var color := SELECTED_COLOR if is_selected else UNSELECTED_COLOR
		_cursor_labels[index].text = ">" if is_selected else ""
		_cursor_labels[index].add_theme_color_override(&"font_color", color)
		_option_labels[index].text = _option_texts[index]
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
	var center := size * 0.5
	var extents := Vector2(size.x * 0.6, size.y * 0.55)
	if _wind_streaks != null:
		_wind_streaks.position = center
		_wind_streaks.emission_rect_extents = extents
	if _wind_dust != null:
		_wind_dust.position = center
		_wind_dust.emission_rect_extents = extents


func _play_ui_move() -> void:
	if _ui_move != null:
		_ui_move.pitch_scale = randf_range(0.96, 1.04)
		_ui_move.play()


func _play_ui_select() -> void:
	if _ui_select != null:
		_ui_select.play()


func _on_option_mouse_entered(index: int) -> void:
	if _is_playing_outro or index >= _option_texts.size():
		return
	if _selected_index != index:
		_selected_index = index
		_update_option_visuals()
		_play_ui_move()


func _on_option_gui_input(event: InputEvent, index: int) -> void:
	if _is_playing_outro or index >= _option_texts.size():
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_selected_index = index
			_update_option_visuals()
			_play_ui_select()
			option_selected.emit(index)


func _on_room_code_text_submitted(room_code: String) -> void:
	_play_ui_select()
	room_code_submitted.emit(room_code)



func _on_background_animation_finished() -> void:
	if _is_playing_outro and _background_sprite.animation == ANIM_OUTRO:
		_is_playing_outro = false
		outro_finished.emit()
