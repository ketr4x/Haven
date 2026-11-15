extends SceneTree

const MOVEMENT_LAB := preload("res://scenes/game/movement_lab.tscn")

var _wall_jump_count: int = 0

func _initialize() -> void:
	var lab := MOVEMENT_LAB.instantiate()
	root.add_child(lab)
	await physics_frame

	var player := lab.get_node("PlayerOne") as RezonansPlayer
	player.global_position = Vector2(596.0, 500.0)
	player.velocity = Vector2(300.0, 100.0)
	player.wall_jumped.connect(_on_wall_jumped)
	Input.action_press(&"p1_right")
	for frame in 10:
		await physics_frame
		if player.is_on_wall_only():
			break
	Input.action_release(&"p1_right")

	assert(player.is_on_wall_only())
	var player_sprite := player.get_node("PlayerSprite") as AnimatedSprite2D
	assert(player_sprite != null)
	assert(player_sprite.sprite_frames.get_frame_count(&"idle") == 9)
	assert(player_sprite.sprite_frames.get_frame_count(&"run") == 10)
	assert(player_sprite.sprite_frames.get_frame_count(&"flip_start") == 2)
	assert(player_sprite.sprite_frames.get_frame_count(&"flip_loop") == 6)
	assert(player_sprite.sprite_frames.get_frame_count(&"jump") == 4)
	assert(player_sprite.sprite_frames.get_frame_count(&"fall") == 4)
	assert(player_sprite.sprite_frames.get_frame_count(&"land") == 1)
	player._jump_buffer_remaining = player.jump_buffer_time
	await physics_frame
	assert(_wall_jump_count == 1)
	assert(player.velocity.x < 0.0)
	assert(player.velocity.y < 0.0)
	assert(player_sprite.animation == &"flip_start" or player_sprite.animation == &"flip_loop")
	assert(player_sprite.flip_h)
	print("Movement wall-jump check passed.")
	quit()


func _on_wall_jumped(_position: Vector2, _normal: Vector2) -> void:
	_wall_jump_count += 1
