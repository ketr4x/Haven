extends Node2D

var sonar_grid: SonarGrid


func _ready() -> void:
	sonar_grid = SonarGrid.new()
	sonar_grid.name = "SonarGrid"
	add_child(sonar_grid)
	sonar_grid.rebuild_from_static_bodies(self, 640.0)

	var player_one := get_node_or_null("PlayerOne") as RezonansPlayer
	if player_one != null:
		player_one.sonic_shouted.connect(_on_player_shouted)
		player_one.jumped.connect(_on_player_jumped.bind(player_one))
		player_one.landed.connect(_on_player_landed.bind(player_one))

	var player_two := get_node_or_null("PlayerTwo") as RezonansPlayer
	if player_two != null:
		player_two.sonic_shouted.connect(_on_player_shouted)
		player_two.jumped.connect(_on_player_jumped.bind(player_two))
		player_two.landed.connect(_on_player_landed.bind(player_two))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		get_tree().reload_current_scene()


func _on_player_shouted(origin: Vector2, direction: Vector2, _loudness: float) -> void:
	if sonar_grid != null:
		sonar_grid.emit_pulse(origin, direction, 90, 1.5, 1, SonarGrid.PulseKind.SCREAM)


func _on_player_jumped(origin: Vector2, player: RezonansPlayer) -> void:
	if sonar_grid != null:
		sonar_grid.emit_pulse(origin, Vector2(player.facing_direction, 0.0), 120, 0.68, 0, SonarGrid.PulseKind.JUMP)


func _on_player_landed(origin: Vector2, player: RezonansPlayer) -> void:
	if sonar_grid != null:
		sonar_grid.emit_pulse(origin, Vector2(player.facing_direction, 0.0), 120, 0.68, 0, SonarGrid.PulseKind.LAND)
