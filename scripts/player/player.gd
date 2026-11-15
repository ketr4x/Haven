class_name RezonansPlayer
extends CharacterBody2D

signal landed(position: Vector2, impact_speed: float)
signal jumped(position: Vector2)
signal wall_jumped(position: Vector2, normal: Vector2)
signal wave_fired(origin: Vector2, direction: Vector2)
signal freeze_requested
signal obstacle_hit(position: Vector2, normal: Vector2, impact_speed: float)
signal grapple_attached(anchor: Vector2)
signal grapple_released(velocity: Vector2)

@export_category("Input")
@export var left_action: StringName = &"move_left"
@export var right_action: StringName = &"move_right"
@export var jump_action: StringName = &"jump"
@export var slam_action: StringName = &"slam"
@export var fire_wave_action: StringName = &"fire_wave"
@export var freeze_and_grapple_action: StringName = &"freeze_and_grapple"

@export_category("Movement")
@export var run_speed: float = 300.0
@export var ground_acceleration: float = 2_400.0
@export var air_acceleration: float = 1_500.0
@export var ground_deceleration: float = 2_800.0
@export var gravity: float = 1_600.0
@export var jump_velocity: float = -560.0
@export var slam_speed: float = 1_000.0
@export var wall_slide_speed: float = 120.0
@export var wall_jump_horizontal_speed: float = 340.0
@export_range(0.05, 0.3, 0.01) var wall_jump_coyote_time: float = 0.16
@export_range(0.05, 0.3, 0.01) var coyote_time: float = 0.12
@export_range(0.05, 0.3, 0.01) var jump_buffer_time: float = 0.12

@export_category("Focus")
@export_range(0.1, 2.0, 0.05) var maximum_focus_duration: float = 1.2
@export_range(0.05, 0.8, 0.05) var focus_time_scale: float = 0.25
@export_range(400.0, 2_000.0, 10.0) var aim_distance: float = 1_680.0

@export_category("Petrified Echo")
@export var echo_slide_speed_bonus: float = 350.0
@export var echo_bounce_velocity: float = -840.0
@export_range(0.0, 0.04, 0.005) var echo_bounce_hitstop: float = 0.025

@export_category("Grapple")
@export_range(96.0, 480.0, 1.0) var minimum_rope_length: float = 96.0
@export_range(96.0, 480.0, 1.0) var maximum_rope_length: float = 480.0
@export_range(100.0, 1_200.0, 10.0) var swing_angular_boost: float = 520.0
@export_range(0.5, 2.0, 0.05) var sling_speed_multiplier: float = 1.2
@export var sling_upward_impulse: float = 280.0
@export var supersonic_speed: float = 700.0

@export_category("Obstacle Impact")
@export var obstacle_impact_speed: float = 235.0
@export_range(0.0, 0.04, 0.005) var impact_hitstop_duration: float = 0.035
@export var obstacle_rebound_speed: float = 190.0
@export var obstacle_rebound_upward_speed: float = 72.0
@export_range(0.05, 0.5, 0.01) var obstacle_impact_cooldown: float = 0.2
@export_range(0.05, 0.4, 0.01) var wall_ricochet_window: float = 0.25
@export_range(0.05, 0.4, 0.01) var camera_shake_duration: float = 0.16
@export_range(1.0, 12.0, 1.0) var camera_shake_strength: float = 5.0

@export_category("Presentation")
@export var camera_enabled: bool = false

@onready var _camera: Camera2D = $Camera2D
@onready var _facing_marker: Polygon2D = $FacingMarker
@onready var _landing_dust: CPUParticles2D = $LandingDust
@onready var _wall_dust: CPUParticles2D = $WallDust
@onready var _impact_debris: CPUParticles2D = $ImpactDebris

var facing_direction: float = 1.0
var focus_stamina: float = 1.0
var is_aiming: bool = false
var _coyote_time_remaining: float = 0.0
var _wall_jump_time_remaining: float = 0.0
var _last_wall_normal: Vector2 = Vector2.ZERO
var _jump_buffer_remaining: float = 0.0
var _was_on_floor: bool = false
var _impact_hitstop_remaining: float = 0.0
var _impact_cooldown_remaining: float = 0.0
var _wall_ricochet_remaining: float = 0.0
var _queued_rebound_velocity: Vector2 = Vector2.ZERO
var _camera_shake_remaining: float = 0.0
var _camera_shake_phase: float = 0.0
var _camera_base_offset: Vector2 = Vector2.ZERO
var _focus_started_at_ms: int = 0
var _aim_segments: Array[Dictionary] = []
var _aim_absorbed: bool = false
var _grapple_anchor: FrozenEcho
var _rope_length: float = 0.0
var _is_grappling: bool = false
var is_supersonic: bool = false
var _camera_base_zoom: Vector2 = Vector2.ONE


func _ready() -> void:
	_camera.enabled = camera_enabled
	_camera_base_offset = _camera.offset
	_camera_base_zoom = _camera.zoom
	set_facing_direction(facing_direction)
	_landing_dust.emitting = false
	_wall_dust.emitting = false
	_impact_debris.emitting = false


func _exit_tree() -> void:
	if is_aiming:
		Engine.time_scale = 1.0


func set_facing_direction(direction: float) -> void:
	if not is_zero_approx(direction):
		facing_direction = signf(direction)
		_facing_marker.scale.x = facing_direction


func _physics_process(delta: float) -> void:
	_update_focus()
	_update_impact_feedback(delta)
	_update_aim_preview()
	if _impact_hitstop_remaining > 0.0:
		return

	if _is_grappling:
		_update_grapple(delta)
		_update_aim_preview()
		return
	if Input.is_action_just_pressed(freeze_and_grapple_action):
		freeze_requested.emit()
		if not is_on_floor():
			_try_attach_nearest_echo()
	_update_jump_buffer(delta)
	_update_horizontal_velocity(delta)
	_apply_gravity(delta)
	_apply_slam()
	_try_jump()
	_apply_wall_slide()

	var velocity_before_move := velocity
	move_and_slide()
	_handle_frozen_echo_surface(velocity_before_move)
	_handle_blue_resonance_blocks()
	_handle_obstacle_impact(velocity_before_move)
	_update_supersonic_visuals(delta)
	_update_ground_state(delta, maxf(0.0, velocity_before_move.y))
	_update_wall_jump_state(delta)
	if is_on_floor():
		focus_stamina = 1.0


func attach_grapple(anchor: FrozenEcho) -> void:
	if is_on_floor() or not is_instance_valid(anchor):
		return
	_grapple_anchor = anchor
	_rope_length = clampf(global_position.distance_to(anchor.global_position), minimum_rope_length, maximum_rope_length)
	_is_grappling = true
	var radial := (global_position - anchor.global_position).normalized()
	velocity = velocity.slide(radial)
	grapple_attached.emit(anchor.global_position)


func _try_attach_nearest_echo() -> void:
	var nearest: FrozenEcho
	var nearest_distance := maximum_rope_length
	for node in get_tree().get_nodes_in_group(&"frozen_echo"):
		var echo := node as FrozenEcho
		if echo == null:
			continue
		var distance := global_position.distance_to(echo.global_position)
		if distance <= nearest_distance:
			nearest = echo
			nearest_distance = distance
	if nearest != null:
		attach_grapple(nearest)


func _update_grapple(delta: float) -> void:
	if not is_instance_valid(_grapple_anchor):
		_release_grapple()
		return
	if Input.is_action_just_released(freeze_and_grapple_action) or Input.is_action_just_pressed(jump_action):
		_release_grapple()
		return
	var anchor := _grapple_anchor.global_position
	var radial := global_position - anchor
	if radial.length() < 1.0:
		radial = Vector2.DOWN
	var radial_direction := radial.normalized()
	var tangent := Vector2(-radial_direction.y, radial_direction.x)
	var input_axis := Input.get_axis(left_action, right_action)
	velocity += Vector2.DOWN * gravity * delta
	velocity += tangent * input_axis * swing_angular_boost * delta
	velocity = velocity.slide(radial_direction)
	move_and_slide()
	var corrected_radial := global_position - anchor
	if corrected_radial.length() > _rope_length:
		global_position = anchor + corrected_radial.normalized() * _rope_length
	queue_redraw()


func _release_grapple() -> void:
	if not _is_grappling:
		return
	velocity = velocity * sling_speed_multiplier + Vector2.UP * sling_upward_impulse
	_is_grappling = false
	_grapple_anchor = null
	grapple_released.emit(velocity)


func _update_focus() -> void:
	var now := Time.get_ticks_msec()
	if Input.is_action_just_pressed(fire_wave_action):
		is_aiming = focus_stamina > 0.0
		_focus_started_at_ms = now
		if is_aiming:
			Engine.time_scale = focus_time_scale
	if is_aiming:
		var elapsed := float(now - _focus_started_at_ms) * 0.001
		focus_stamina = clampf(1.0 - elapsed / maximum_focus_duration, 0.0, 1.0)
		if is_zero_approx(focus_stamina):
			Engine.time_scale = 1.0
	if Input.is_action_just_released(fire_wave_action):
		var direction := (get_global_mouse_position() - global_position).normalized()
		if direction.is_zero_approx():
			direction = Vector2(facing_direction, 0.0)
		Engine.time_scale = 1.0
		is_aiming = false
		wave_fired.emit(global_position + direction * 18.0, direction)


func _update_aim_preview() -> void:
	_aim_segments.clear()
	_aim_absorbed = false
	if not Input.is_action_pressed(fire_wave_action):
		queue_redraw()
		return
	var origin := global_position
	var direction := (get_global_mouse_position() - origin).normalized()
	if direction.is_zero_approx():
		direction = Vector2(facing_direction, 0.0)
	var first_hit := _raycast_terrain(origin, origin + direction * aim_distance)
	if first_hit.is_empty():
		_aim_segments.append({"from": origin, "to": origin + direction * aim_distance})
		queue_redraw()
		return
	var hit_position: Vector2 = first_hit["position"]
	_aim_segments.append({"from": origin, "to": hit_position})
	var collider := first_hit.get("collider") as Node
	if collider != null and collider.is_in_group(&"sound_absorber"):
		_aim_absorbed = true
		queue_redraw()
		return
	var reflected := direction.bounce(first_hit["normal"] as Vector2)
	_aim_segments.append({"from": hit_position, "to": hit_position + reflected * aim_distance * 0.55})
	queue_redraw()


func _raycast_terrain(from: Vector2, to: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_2d().direct_space_state.intersect_ray(query)


func _draw() -> void:
	for segment in _aim_segments:
		var start := to_local(segment["from"] as Vector2)
		var end := to_local(segment["to"] as Vector2)
		var distance := start.distance_to(end)
		var direction := (end - start).normalized()
		for offset in range(0, int(distance), 14):
			var dash_end := minf(float(offset + 8), distance)
			draw_line(start + direction * float(offset), start + direction * dash_end, Color(0.76, 0.95, 0.95, 0.9), 2.0)
	if _aim_absorbed and not _aim_segments.is_empty():
		var end := to_local(_aim_segments.back()["to"] as Vector2)
		draw_line(end + Vector2(-8, -8), end + Vector2(8, 8), Color(1.0, 0.25, 0.3), 3.0)
		draw_line(end + Vector2(-8, 8), end + Vector2(8, -8), Color(1.0, 0.25, 0.3), 3.0)
	if _is_grappling and is_instance_valid(_grapple_anchor):
		var anchor := to_local(_grapple_anchor.global_position)
		var rope_points := PackedVector2Array()
		for index in range(17):
			var progress := float(index) / 16.0
			var point := Vector2.ZERO.lerp(anchor, progress)
			point += Vector2(0.0, sin(progress * TAU * 5.0 + Time.get_ticks_msec() * 0.012) * 3.0)
			rope_points.append(point)
		draw_polyline(rope_points, Color(0.95, 0.76, 0.25, 0.95), 2.0, true)
		draw_arc(anchor, 10.0, 0.0, TAU, 16, Color.WHITE, 2.0, true)
	if is_supersonic:
		var cone := PackedVector2Array([Vector2(-36.0 * facing_direction, -18.0), Vector2(48.0 * facing_direction, 0.0), Vector2(-36.0 * facing_direction, 18.0)])
		draw_polyline(cone + PackedVector2Array([cone[0]]), Color(0.76, 0.95, 0.95, 0.9), 2.0, true)


func _update_jump_buffer(delta: float) -> void:
	if Input.is_action_just_pressed(jump_action):
		_jump_buffer_remaining = jump_buffer_time
	else:
		_jump_buffer_remaining = maxf(0.0, _jump_buffer_remaining - delta)


func _update_horizontal_velocity(delta: float) -> void:
	var input_axis := Input.get_axis(left_action, right_action)
	if not is_zero_approx(input_axis):
		set_facing_direction(input_axis)
		var acceleration := ground_acceleration if is_on_floor() else air_acceleration
		velocity.x = move_toward(velocity.x, input_axis * run_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, ground_deceleration * delta)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta


func _apply_slam() -> void:
	if not is_on_floor() and Input.is_action_pressed(slam_action):
		velocity.y = maxf(velocity.y, slam_speed)


func _try_jump() -> void:
	if is_zero_approx(_jump_buffer_remaining):
		return
	if _wall_ricochet_remaining > 0.0:
		velocity = Vector2(_last_wall_normal.x * wall_jump_horizontal_speed * 1.35, jump_velocity * 1.2)
		_jump_buffer_remaining = 0.0
		_wall_ricochet_remaining = 0.0
		jumped.emit(global_position)
		return
	if _wall_jump_time_remaining > 0.0:
		velocity = Vector2(_last_wall_normal.x * wall_jump_horizontal_speed, jump_velocity)
		set_facing_direction(_last_wall_normal.x)
		_jump_buffer_remaining = 0.0
		_wall_jump_time_remaining = 0.0
		_wall_dust.position = Vector2(-_last_wall_normal.x * 12.0, 6.0)
		_play_particle_burst(_wall_dust)
		wall_jumped.emit(global_position, _last_wall_normal)
		return
	if is_on_floor() or _coyote_time_remaining > 0.0:
		velocity.y = jump_velocity
		_coyote_time_remaining = 0.0
		_jump_buffer_remaining = 0.0
		jumped.emit(global_position)


func _apply_wall_slide() -> void:
	if is_on_wall_only() and not is_on_floor() and velocity.y > wall_slide_speed:
		velocity.y = wall_slide_speed


func _update_ground_state(delta: float, impact_speed: float) -> void:
	if is_on_floor():
		_coyote_time_remaining = coyote_time
		if not _was_on_floor:
			_play_particle_burst(_landing_dust)
			landed.emit(global_position, impact_speed)
	else:
		_coyote_time_remaining = maxf(0.0, _coyote_time_remaining - delta)
	_was_on_floor = is_on_floor()


func _update_wall_jump_state(delta: float) -> void:
	_wall_ricochet_remaining = maxf(0.0, _wall_ricochet_remaining - delta)
	if is_on_wall_only():
		_last_wall_normal = get_wall_normal()
		_wall_jump_time_remaining = wall_jump_coyote_time
	else:
		_wall_jump_time_remaining = maxf(0.0, _wall_jump_time_remaining - delta)


func _handle_frozen_echo_surface(velocity_before_move: Vector2) -> void:
	for index in get_slide_collision_count():
		var collider := get_slide_collision(index).get_collider() as Node
		if collider == null or not collider.is_in_group(&"frozen_echo"):
			continue
		velocity.x = facing_direction * maxf(absf(velocity.x), run_speed + echo_slide_speed_bonus)
		if velocity_before_move.y > 180.0 or Input.is_action_just_pressed(jump_action):
			velocity.y = echo_bounce_velocity
			_impact_hitstop_remaining = echo_bounce_hitstop
			_camera_shake_remaining = camera_shake_duration * 0.5
			landed.emit(global_position, velocity_before_move.y)
		return


func _handle_blue_resonance_blocks() -> void:
	if not is_supersonic:
		return
	for index in get_slide_collision_count():
		var collider := get_slide_collision(index).get_collider() as Node
		if collider != null and collider.is_in_group(&"blue_resonance_block"):
			collider.call("shatter")


func _update_supersonic_visuals(delta: float) -> void:
	is_supersonic = velocity.length() >= supersonic_speed
	var target_zoom := Vector2(0.78, 0.78) if is_supersonic else _camera_base_zoom
	_camera.zoom = _camera.zoom.lerp(target_zoom, minf(delta * 8.0, 1.0))
	queue_redraw()


func _handle_obstacle_impact(velocity_before_move: Vector2) -> void:
	if _impact_cooldown_remaining > 0.0:
		return
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var normal := collision.get_normal()
		if absf(normal.x) >= 0.72:
			var impact_speed := velocity_before_move.dot(-normal)
			if impact_speed >= obstacle_impact_speed:
				_trigger_obstacle_impact(collision.get_position(), normal, impact_speed, velocity_before_move)
				return


func _trigger_obstacle_impact(position: Vector2, normal: Vector2, impact_speed: float, velocity_before_move: Vector2) -> void:
	_impact_cooldown_remaining = obstacle_impact_cooldown
	_impact_hitstop_remaining = minf(impact_hitstop_duration, 0.04)
	_wall_ricochet_remaining = wall_ricochet_window
	_last_wall_normal = normal
	_queued_rebound_velocity = Vector2(normal.x * obstacle_rebound_speed, minf(velocity_before_move.y, -obstacle_rebound_upward_speed))
	velocity = Vector2.ZERO
	_camera_shake_remaining = camera_shake_duration
	_impact_debris.position = to_local(position)
	_impact_debris.direction = Vector2(normal.x, -0.25).normalized()
	_play_particle_burst(_impact_debris)
	obstacle_hit.emit(position, normal, impact_speed)


func _update_impact_feedback(delta: float) -> void:
	_impact_cooldown_remaining = maxf(0.0, _impact_cooldown_remaining - delta)
	if _impact_hitstop_remaining > 0.0:
		_impact_hitstop_remaining = maxf(0.0, _impact_hitstop_remaining - delta)
		if is_zero_approx(_impact_hitstop_remaining):
			velocity = _queued_rebound_velocity
	if _camera_shake_remaining <= 0.0:
		_camera.offset = _camera_base_offset
		return
	_camera_shake_remaining = maxf(0.0, _camera_shake_remaining - delta)
	_camera_shake_phase += delta * 58.0
	var strength := camera_shake_strength * _camera_shake_remaining / camera_shake_duration
	_camera.offset = _camera_base_offset + Vector2(roundf(sin(_camera_shake_phase) * strength), roundf(cos(_camera_shake_phase * 1.7) * strength * 0.65))


func _play_particle_burst(particles: CPUParticles2D) -> void:
	particles.restart()
	particles.emitting = true
