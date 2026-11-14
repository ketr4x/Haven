extends SceneTree

const MOVEMENT_LAB := preload("res://scenes/game/movement_lab.tscn")

var _wall_jump_count: int = 0
var _obstacle_hit_count: int = 0

func _initialize() -> void:
	var lab := MOVEMENT_LAB.instantiate()
	root.add_child(lab)
	await physics_frame

	var player := lab.get_node("PlayerOne") as RezonansPlayer
	var player_two := lab.get_node("PlayerTwo") as RezonansPlayer
	player.global_position = Vector2(596.0, 500.0)
	player.velocity = Vector2(300.0, 100.0)
	player.wall_jumped.connect(_on_wall_jumped)
	player.obstacle_hit.connect(_on_obstacle_hit)
	Input.action_press(&"p1_right")
	for frame in 10:
		await physics_frame
		if player.is_on_wall_only():
			break
	Input.action_release(&"p1_right")

	assert(player.is_on_wall_only())
	assert(_obstacle_hit_count == 1)
	assert(player._impact_hitstop_remaining <= 0.04)
	assert(player._camera_shake_remaining > 0.0)
	assert((player_two.get_node("Camera2D") as Camera2D).offset == Vector2.ZERO)
	assert((player.get_node("ImpactDebris") as CPUParticles2D).emitting)
	player._jump_buffer_remaining = player.jump_buffer_time
	for frame in 5:
		await physics_frame
		if _wall_jump_count == 1:
			break
	assert(_wall_jump_count == 1)
	assert(player.velocity.x < 0.0)
	assert(player.velocity.y < 0.0)
	player.set_facing_direction(1.0)
	player.velocity = Vector2.ZERO
	player._jump_press_age = player.echo_timing_window - 0.01
	player.offer_echo_boost()
	assert(player._boost_time_remaining > 0.0)
	assert(player.velocity.x >= player.run_speed * player.echo_boost_speed_multiplier)
	assert(player.velocity.y <= player.jump_velocity * player.echo_boost_jump_multiplier + 0.1)
	print("Movement wall-jump check passed.")
	quit()


func _on_wall_jumped(_position: Vector2, _normal: Vector2) -> void:
	_wall_jump_count += 1


func _on_obstacle_hit(_position: Vector2, _normal: Vector2, _impact_speed: float) -> void:
	_obstacle_hit_count += 1
