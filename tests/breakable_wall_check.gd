extends SceneTree

const BREAKABLE_WALL := preload("res://scripts/terrain/breakable_wall.gd")
const BREAKABLE_WALL_SCENE := preload("res://scenes/terrain/breakable_wall.tscn")
const SOUND_WAVE_SCENE := preload("res://scenes/effects/sound_wave.tscn")
const PLAYER_WORLD_SCENE := preload("res://scenes/game/player_world.tscn")
const CHUNK_BREAK_THROUGH := preload("res://scenes/levels/chunks/chunk_break_through.tscn")

var _wall_broken_events: int = 0
var _wall_signal_fired: bool = false


func _initialize() -> void:
	var container := Node2D.new()
	root.add_child(container)

	# 1. Test basic BreakableWall node properties
	var wall = BREAKABLE_WALL_SCENE.instantiate()
	container.add_child(wall)
	wall.global_position = Vector2(400, 300)
	await process_frame
	assert(wall.is_in_group(&"breakable_wall"))
	assert(not wall.is_broken)
	assert(wall.get_node_or_null("Cracks") == null)
	var body_poly := wall.get_node("Body") as Polygon2D
	assert(body_poly != null and body_poly.material is ShaderMaterial)
	assert(body_poly.uv.size() == 4)
	var field_col := (body_poly.material as ShaderMaterial).get_shader_parameter(&"field_color") as Color
	assert(field_col.b > field_col.r and field_col.a < 0.5)
	var field_light := wall.get_node_or_null("FieldLight") as PointLight2D
	assert(field_light != null and field_light.enabled)
	var col_shape := wall.get_node("CollisionShape2D") as CollisionShape2D
	assert(col_shape != null and not col_shape.disabled)
	var rect := col_shape.shape as RectangleShape2D
	assert(rect != null and rect.size == Vector2(48, 96))

	# 2. Test SonarGrid static body registration and non-scream wave bounce
	var sonar := SonarGrid.new()
	container.add_child(sonar)
	sonar.wall_broken.connect(_on_sonar_wall_broken)
	wall.broken.connect(_on_wall_broken)
	sonar.rebuild_from_static_bodies(container, 800.0)

	var wall_cell_top := sonar.world_to_grid(Vector2(400, 276))
	var wall_cell_bottom := sonar.world_to_grid(Vector2(400, 324))
	assert(sonar.tiles.has(wall_cell_top))
	assert(sonar.tiles.has(wall_cell_bottom))
	assert(sonar.get_tile_kind(wall_cell_top) == SonarGrid.TileKind.BREAKABLE)
	assert(sonar.get_tile_kind(wall_cell_bottom) == SonarGrid.TileKind.BREAKABLE)

	# Footstep / run wave pulse (not scream) -> Wall must NOT break
	sonar.emit_pulse(Vector2(300, 300), Vector2.RIGHT, 16, 1.0, 0, SonarGrid.PulseKind.RUN)
	for frame in 15:
		await process_frame
	assert(not wall.is_broken)
	assert(not col_shape.disabled)
	assert(_wall_broken_events == 0)
	assert(sonar.get_tile_light_level(wall_cell_top) > 0.0 or sonar.get_tile_light_level(wall_cell_bottom) > 0.0)

	# Jump wave pulse -> Wall must NOT break
	sonar.emit_pulse(Vector2(300, 300), Vector2.RIGHT, 16, 1.0, 0, SonarGrid.PulseKind.JUMP)
	for frame in 15:
		await process_frame
	assert(not wall.is_broken)
	assert(_wall_broken_events == 0)

	# 3. Scream wave pulse (at E) -> Wall MUST break!
	sonar.emit_pulse(Vector2(300, 300), Vector2.RIGHT, 32, 1.5, 1, SonarGrid.PulseKind.SCREAM)
	for frame in 20:
		await process_frame
	assert(wall.is_broken)
	assert(not field_light.enabled)
	assert(_wall_signal_fired)
	assert(_wall_broken_events > 0)
	# After breaking, cells must be removed from SonarGrid so subsequent rays pass through
	assert(not sonar.tiles.has(wall_cell_top))
	assert(not sonar.tiles.has(wall_cell_bottom))

	# Clean up initial standalone test nodes
	container.queue_free()
	await process_frame

	# 4. Test physics SoundWave interaction with BreakableWall
	var wall2 = BREAKABLE_WALL_SCENE.instantiate()
	root.add_child(wall2)
	wall2.global_position = Vector2(500, 400)
	await physics_frame

	# Low loudness wave bounces off wall2
	var wave_low := SOUND_WAVE_SCENE.instantiate() as SoundWave
	root.add_child(wave_low)
	wave_low.setup(null, Vector2(420, 400), Vector2.RIGHT, 50.0, 1)
	for frame in 15:
		await physics_frame
	assert(not wall2.is_broken)
	if is_instance_valid(wave_low):
		wave_low.queue_free()

	# High loudness wave (Scream wave, 100 loudness) breaks wall2
	var wave_scream := SOUND_WAVE_SCENE.instantiate() as SoundWave
	root.add_child(wave_scream)
	wave_scream.setup(null, Vector2(420, 400), Vector2.RIGHT, 100.0, 2)
	for frame in 15:
		await physics_frame
	assert(wall2.is_broken)
	wall2.queue_free()
	await process_frame

	# 5. Test PlayerWorld integration & CourseChunk generation with breakable walls
	var world := PLAYER_WORLD_SCENE.instantiate() as PlayerWorld
	root.add_child(world)
	await process_frame
	world.generate_course(12_345)
	await physics_frame
	assert(world.sonar_grid != null)

	# Verify ChunkBreakThrough geometry and metadata
	var chunk_instance := CHUNK_BREAK_THROUGH.instantiate() as CourseChunk
	root.add_child(chunk_instance)
	await physics_frame
	assert(chunk_instance.has_valid_grid_geometry())
	assert(chunk_instance.requires_shout)
	assert(chunk_instance.terrain_features.has(&"breakable_wall"))
	var chunk_wall := chunk_instance.get_node_or_null("BreakableWall")
	assert(chunk_wall != null)
	assert(chunk_wall.is_in_group(&"breakable_wall"))
	chunk_instance.queue_free()
	world.queue_free()
	await process_frame

	print("Breakable wall check passed successfully.")
	quit()


func _on_sonar_wall_broken(_pos: Vector2, _cell: Vector2i) -> void:
	_wall_broken_events += 1


func _on_wall_broken(_pos: Vector2) -> void:
	_wall_signal_fired = true
