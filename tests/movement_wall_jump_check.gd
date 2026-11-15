extends SceneTree

const MOVEMENT_LAB := preload("res://scenes/game/movement_lab.tscn")

var _wall_jump_count: int = 0
var _slide_count: int = 0

func _initialize() -> void:
	var lab := MOVEMENT_LAB.instantiate()
	root.add_child(lab)
	await physics_frame

	var player := lab.get_node("PlayerOne") as RezonansPlayer
	var player_sprite := player.get_node("PlayerSprite") as AnimatedSprite2D
	assert(player_sprite != null)
	assert(player_sprite.scale.is_equal_approx(Vector2(3.0, 3.0)))
	var outline_mat := player_sprite.material as ShaderMaterial
	assert(outline_mat != null)
	assert((outline_mat.get_shader_parameter(&"outline_color") as Color).is_equal_approx(Color(0.27451, 0.290196, 0.45098, 1.0)))
	assert(player.get_node_or_null("GroundShadow") != null)
	assert(player.get_node_or_null("RunDust") != null)
	assert(player.get_node_or_null("SpeedWind") != null)
	assert(player.get_node_or_null("PlayerLight") != null)
	assert(player.get_node_or_null("BoostAura") == null)
	assert(player.get_node_or_null("ShoutSparks") == null)
	assert(player.get_node_or_null("BoostTrail") == null)

	var camera := player.get_node("Camera2D") as Camera2D
	assert(camera != null)
	assert(camera.zoom.x > 1.15 and camera.zoom.x < 1.35)
	assert(camera.offset.x > 100.0)

	assert(player_sprite.sprite_frames.get_frame_count(&"idle") == 9)
	assert(player_sprite.sprite_frames.get_frame_count(&"run") == 10)
	assert(player_sprite.sprite_frames.get_frame_count(&"slide_enter") == 2)
	assert(player_sprite.sprite_frames.get_frame_count(&"slide_loop") == 4)
	assert(player_sprite.sprite_frames.get_frame_count(&"slide_exit") == 2)
	assert(player_sprite.sprite_frames.get_frame_count(&"flip_start") == 2)
	assert(player_sprite.sprite_frames.get_frame_count(&"flip_loop") == 6)
	assert(player_sprite.sprite_frames.get_frame_count(&"jump") == 4)
	assert(player_sprite.sprite_frames.get_frame_count(&"fall") == 4)
	assert(player_sprite.sprite_frames.get_frame_count(&"land") == 1)

	# Test ground slide mechanic (longer & faster advantage) and animation
	player.slide_started.connect(_on_slide_started)
	for frame in 20:
		await physics_frame
		if player.is_on_floor():
			break
	assert(player.is_on_floor())
	assert(player.slide_duration >= 0.65)
	assert(player.slide_speed_multiplier >= 1.5)
	var standing_rect := (player.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	var standing_height := standing_rect.size.y
	Input.action_press(&"p1_slide")
	await physics_frame
	Input.action_release(&"p1_slide")
	assert(_slide_count == 1)
	assert(player.is_sliding())
	assert(standing_rect.size.y < standing_height)
	assert(player.velocity.x > player.run_speed * 1.4)
	assert((player.get_node("SpeedWind") as CPUParticles2D).emitting)
	assert(player_sprite.animation == &"slide_enter" or player_sprite.animation == &"slide_loop")
	player._end_slide(false)
	assert(not player.is_sliding())
	assert(is_equal_approx(standing_rect.size.y, standing_height))

	# Test impact stun and white-normal-white flash sequence
	player.apply_impact_stun(Vector2.LEFT, 0.22)
	assert(player.is_stunned())
	assert(is_equal_approx(float(outline_mat.get_shader_parameter(&"flash_amount")), 1.0))
	for frame in 4:
		await physics_frame
	assert(is_equal_approx(float(outline_mat.get_shader_parameter(&"flash_amount")), 0.0))
	for frame in 3:
		await physics_frame
	assert(is_equal_approx(float(outline_mat.get_shader_parameter(&"flash_amount")), 1.0))
	for frame in 12:
		await physics_frame
	assert(not player.is_stunned())
	assert(is_equal_approx(float(outline_mat.get_shader_parameter(&"flash_amount")), 0.0))

	# Test wall slide and wall jump
	player.global_position = Vector2(580.0, 500.0)
	player.velocity = Vector2(300.0, 100.0)
	player.wall_jumped.connect(_on_wall_jumped)
	Input.action_press(&"p1_right")
	for frame in 10:
		await physics_frame
		if player.is_on_wall_only():
			break
	Input.action_release(&"p1_right")

	assert(player.is_on_wall_only())
	player._jump_buffer_remaining = player.jump_buffer_time
	await physics_frame
	assert(_wall_jump_count == 1)
	assert(player.velocity.x < 0.0)
	assert(player.velocity.y < 0.0)
	assert(player_sprite.animation == &"flip_start" or player_sprite.animation == &"flip_loop")
	assert(player_sprite.flip_h)

	# Test shout zoom-in then quick zoom-out punch on E
	var base_zoom_x := player.camera_zoom.x
	Input.action_press(&"p1_shout")
	await physics_frame
	Input.action_release(&"p1_shout")
	for frame in 5:
		await physics_frame
	assert(camera.zoom.x > base_zoom_x + 0.04)
	for frame in 18:
		await physics_frame
	assert(is_equal_approx(camera.zoom.x, base_zoom_x))

	print("Movement wall-jump and slide check passed.")
	quit()


func _on_wall_jumped(_position: Vector2, _normal: Vector2) -> void:
	_wall_jump_count += 1


func _on_slide_started(_position: Vector2, _direction: Vector2) -> void:
	_slide_count += 1
