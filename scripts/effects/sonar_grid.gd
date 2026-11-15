class_name SonarGrid
extends Node2D

signal tile_illuminated(world_cell: Vector2i, tile_kind: int, light_level: float)
signal wave_bounced(world_position: Vector2, normal: Vector2, bounce_count: int)
signal wave_absorbed(world_position: Vector2)
signal wall_broken(world_position: Vector2, world_cell: Vector2i)

enum TileKind {
	SAFE = 0,
	HAZARD = 1,
	BOUNCE_PAD = 2,
	ABSORBER = 3,
	BREAKABLE = 4,
}

enum PulseKind {
	RUN = 0,
	JUMP = 1,
	LAND = 2,
	SCREAM = 3,
	INTRO = 4,
}

const GRID_SIZE: float = 48.0
const HALF_GRID: float = 24.0
const TILE_PIXEL_RESOLUTION: int = 16
const ART_PIXEL_SIZE: float = GRID_SIZE / float(TILE_PIXEL_RESOLUTION)
const WAVE_PIXEL_SIZE: float = 2.0
const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, -1),
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
	Vector2i(1, 1),
]
const ARC_BAND_OFFSETS: Array[float] = [-4.0, 0.0, 4.0]
const ARC_SUBDIVISIONS: int = 2

@export_category("Illumination")
@export_range(0.5, 8.0, 0.1) var fade_duration: float = 4.0
@export_range(0.0, 1.0, 0.05) var floor_min_light_level: float = 0.26
@export_range(0.0, 1.0, 0.05) var neighbor_light_boost: float = 0.35

@export_category("Wave Profile")
@export var forward_cone_half_angle_degrees: float = 45.0
@export var forward_speed: float = 920.0
@export var forward_range_tiles: float = 11.5
@export var forward_max_bounces: int = 4
@export var peripheral_speed: float = 440.0
@export var peripheral_range_tiles: float = 3.5
@export var peripheral_max_bounces: int = 2
@export_range(0.05, 0.5, 0.05) var bounce_energy_loss: float = 0.2
@export_range(0.2, 4.0, 0.1) var alpha_drop_window: float = 2.0
@export_range(0.1, 0.98, 0.01) var alpha_loss_after_window: float = 0.80
@export var max_active_rays: int = 540
@export var ripple_duration: float = 0.28
@export var wave_undulation_cycles: float = 8.0
@export var wave_undulation_speed: float = 3.5
@export var wave_undulation_amplitude: float = 1.2

@export_category("Palette")
@export var safe_tile_color: Color = Color(0.51, 0.71, 0.85, 1.0)
@export var hazard_tile_color: Color = Color(0.75, 0.41, 0.47, 1.0)
@export var bounce_pad_tile_color: Color = Color(0.94, 0.92, 0.75, 1.0)
@export var absorber_tile_color: Color = Color(0.28, 0.29, 0.45, 1.0)
@export var breakable_tile_color: Color = Color(0.55, 0.90, 1.0, 1.0)
@export var player_accent_color: Color = Color(0.76, 0.95, 0.95, 1.0)

var grid_origin: Vector2 = Vector2.ZERO
var tiles: Dictionary = {}
var active_rays: Array[Dictionary] = []
var active_ripples: Array[Dictionary] = []

var _next_pulse_group_id: int = 0
var _wave_time: float = 0.0
var silence_dim: float = 0.0
var _sim_tick: int = 0
var _lit_tiles: Dictionary = {}
var _arc_points: PackedVector2Array = PackedVector2Array()
var _arc_colors: PackedColorArray = PackedColorArray()
var _connected_flags: PackedByteArray = PackedByteArray()


func _ready() -> void:
	z_index = 5
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func set_player_accent_color(color: Color) -> void:
	player_accent_color = color
	queue_redraw()


func set_silence_dim(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if not is_equal_approx(silence_dim, clamped):
		silence_dim = clamped
		queue_redraw()


func clear_waves() -> void:
	active_rays.clear()
	active_ripples.clear()
	queue_redraw()


func rebuild_from_generator(generator: CourseGenerator) -> void:
	tiles.clear()
	_lit_tiles.clear()
	clear_waves()
	grid_origin = generator.global_position

	var chunks_root := generator.get_node_or_null("GeneratedChunks")
	if chunks_root != null:
		for chunk_node in chunks_root.get_children():
			var chunk := chunk_node as CourseChunk
			if chunk == null:
				continue
			var terrain := chunk.get_node_or_null("Terrain") as TileMapLayer
			if terrain != null:
				terrain.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
				terrain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

			var grid := chunk.grid_size
			var chunk_offset := Vector2i(
				roundi(chunk.position.x / float(grid.x)),
				roundi(chunk.position.y / float(grid.y)),
			)
			for cell in chunk.terrain_cells:
				var mirrored_cell := Vector2i(-cell.x, cell.y) if chunk.mirror_horizontally else cell
				var world_cell := chunk_offset + mirrored_cell
				var is_floor := _is_chunk_floor_cell(chunk, cell)
				var tile_kind := _classify_chunk_cell(chunk, cell, is_floor)
				_register_cell(world_cell, tile_kind, is_floor)

			for child in chunk.get_children():
				if child is StaticBody2D and child.is_in_group(&"sound_absorber"):
					_register_static_body_cells(generator, child as StaticBody2D, TileKind.ABSORBER, false)
				elif child is StaticBody2D and child.is_in_group(&"breakable_wall"):
					_register_static_body_cells(generator, child as StaticBody2D, TileKind.BREAKABLE, false, child)

	var roof := generator.get_node_or_null("Roof") as TileMapLayer
	if roof != null:
		roof.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
		roof.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var roof_used := roof.get_used_cells()
		var col_min_roof_y: Dictionary = {}
		for rc in roof_used:
			if not col_min_roof_y.has(rc.x) or rc.y < int(col_min_roof_y[rc.x]):
				col_min_roof_y[rc.x] = rc.y
		for roof_cell in roof_used:
			if tiles.has(roof_cell):
				continue
			var min_ry := int(col_min_roof_y.get(roof_cell.x, roof_cell.y))
			var is_sub_floor := roof_cell.y >= 0 or (roof_cell.y > min_ry + 2)
			_register_cell(roof_cell, TileKind.SAFE, is_sub_floor)

	queue_redraw()


func rebuild_from_static_bodies(root_node: Node2D, floor_y_threshold: float = 640.0) -> void:
	tiles.clear()
	_lit_tiles.clear()
	clear_waves()
	grid_origin = Vector2.ZERO
	for body_variant in root_node.find_children("*", "StaticBody2D", true, false):
		var body := body_variant as StaticBody2D
		if body == null:
			continue
		var kind := TileKind.SAFE
		if body.is_in_group(&"sound_absorber"):
			kind = TileKind.ABSORBER
		elif body.is_in_group(&"breakable_wall"):
			kind = TileKind.BREAKABLE
		var is_floor := body.global_position.y >= floor_y_threshold
		_register_static_body_cells(null, body, kind, is_floor, body if kind == TileKind.BREAKABLE else null)
	queue_redraw()


func compute_decay_power(max_lifetime: float) -> float:
	if max_lifetime <= 0.002:
		return 1.0
	var drop_time := minf(alpha_drop_window, max_lifetime * 0.5)
	var ratio_at_drop := clampf(1.0 - drop_time / max_lifetime, 0.01, 0.99)
	var remaining_ratio_at_drop := clampf(1.0 - alpha_loss_after_window, 0.001, 0.99)
	return log(remaining_ratio_at_drop) / log(ratio_at_drop)


func compute_wave_alpha_factor(remaining_lifetime: float, max_lifetime: float) -> float:
	if remaining_lifetime <= 0.0 or max_lifetime <= 0.001:
		return 0.0
	var life_ratio := clampf(remaining_lifetime / max_lifetime, 0.0, 1.0)
	return pow(life_ratio, compute_decay_power(max_lifetime))


func emit_pulse(
	origin: Vector2,
	facing_direction: Vector2,
	ray_count: int = 90,
	range_multiplier: float = 1.0,
	extra_bounces: int = 0,
	pulse_kind: int = PulseKind.RUN
) -> int:
	_next_pulse_group_id += 1
	var pulse_id := _next_pulse_group_id
	var forward_dir := facing_direction.normalized()
	if forward_dir.is_zero_approx():
		forward_dir = Vector2.RIGHT

	var visibility_scale := pow(clampf(range_multiplier / 1.5, 0.15, 1.0), 1.15)
	var ray_lifetime := maxf(0.35, fade_duration * visibility_scale)
	var decay_power := compute_decay_power(ray_lifetime)

	if max_active_rays > 0 and active_rays.size() + ray_count > max_active_rays:
		var overflow := active_rays.size() + ray_count - max_active_rays
		if overflow >= active_rays.size():
			active_rays.clear()
		else:
			active_rays.assign(active_rays.slice(overflow))

	var cone_cos := cos(deg_to_rad(forward_cone_half_angle_degrees))
	var spawned := 0
	for index in ray_count:
		var angle := TAU * float(index) / float(maxi(1, ray_count))
		var direction := Vector2.from_angle(angle)
		var alignment := direction.dot(forward_dir)
		var is_forward := alignment >= cone_cos

		var ray_speed := forward_speed if is_forward else peripheral_speed
		var allowed_bounces := maxi(0, (forward_max_bounces if is_forward else peripheral_max_bounces) + extra_bounces)

		var start_pos := origin + direction * 6.0
		active_rays.append({
			"pulse_id": pulse_id,
			"ray_index": index,
			"ray_count": ray_count,
			"position": start_pos,
			"velocity": direction * ray_speed,
			"remaining_lifetime": ray_lifetime,
			"max_lifetime": ray_lifetime,
			"decay_power": decay_power,
			"bounce_count": 0,
			"max_bounces": allowed_bounces,
			"is_forward": is_forward,
			"pulse_kind": pulse_kind,
		})
		spawned += 1

	queue_redraw()
	return spawned


func get_tile_light_level(world_cell: Vector2i) -> float:
	if not tiles.has(world_cell):
		return 0.0
	var tile: Dictionary = tiles[world_cell]
	return float(tile["light_level"])


func get_tile_kind(world_cell: Vector2i) -> int:
	if not tiles.has(world_cell):
		return -1
	var tile: Dictionary = tiles[world_cell]
	return int(tile["kind"])


func is_unlit_airborne_obstacle_at_world_pos(world_position: Vector2, light_threshold: float = 0.15) -> bool:
	var cell := world_to_grid(world_position)
	if not tiles.has(cell):
		return false
	var tile: Dictionary = tiles[cell]
	if bool(tile["is_floor"]):
		return false
	return float(tile["light_level"]) < light_threshold


func illuminate_cell(world_cell: Vector2i, level: float = 1.0, bounce_count: int = 0, hit_normal: Vector2 = Vector2.ZERO) -> void:
	if not tiles.has(world_cell):
		return
	var tile: Dictionary = tiles[world_cell]
	var min_light := floor_min_light_level if bool(tile["is_floor"]) else 0.0
	var clamped_level := clampf(level, min_light, 1.0)
	var prev_level := float(tile["light_level"])
	if int(tile.get("lit_tick", -1)) == _sim_tick and prev_level >= clamped_level - 0.001:
		return

	tile["lit_tick"] = _sim_tick
	tile["light_level"] = maxf(prev_level, clamped_level)
	tile["last_hit_color"] = _resolve_tile_hit_color(int(tile["kind"]), bounce_count)
	if not hit_normal.is_zero_approx():
		tile["hit_normal"] = hit_normal
	if float(tile["light_level"]) > min_light:
		_lit_tiles[world_cell] = true
	tile_illuminated.emit(world_cell, int(tile["kind"]), float(tile["light_level"]))

	if clamped_level <= min_light + 0.01:
		return

	for offset in NEIGHBOR_OFFSETS:
		var neighbor_cell := world_cell + offset
		if not tiles.has(neighbor_cell):
			continue
		var neighbor: Dictionary = tiles[neighbor_cell]
		var neighbor_min := floor_min_light_level if bool(neighbor["is_floor"]) else 0.0
		var boosted := clampf(float(neighbor["light_level"]) + neighbor_light_boost, neighbor_min, 1.0)
		neighbor["light_level"] = boosted
		neighbor["last_hit_color"] = _resolve_tile_hit_color(int(neighbor["kind"]), bounce_count)
		if boosted > neighbor_min:
			_lit_tiles[neighbor_cell] = true
		if not hit_normal.is_zero_approx() and Vector2(neighbor.get("hit_normal", Vector2.ZERO)).is_zero_approx():
			neighbor["hit_normal"] = hit_normal


func world_to_grid(world_position: Vector2) -> Vector2i:
	var local_pos := world_position - grid_origin
	return Vector2i(
		floori((local_pos.x + HALF_GRID) / GRID_SIZE),
		floori((local_pos.y + HALF_GRID) / GRID_SIZE),
	)


func grid_to_world_center(world_cell: Vector2i) -> Vector2:
	return grid_origin + Vector2(float(world_cell.x) * GRID_SIZE, float(world_cell.y) * GRID_SIZE)


func grid_to_world_rect(world_cell: Vector2i) -> Rect2:
	var center := grid_to_world_center(world_cell)
	return Rect2(center - Vector2(HALF_GRID, HALF_GRID), Vector2(GRID_SIZE, GRID_SIZE))


func _process(delta: float) -> void:
	_wave_time += delta
	var needs_tile_redraw := _update_tile_fade(delta)
	var needs_wave_redraw := _update_rays_and_ripples(delta)
	if needs_tile_redraw or needs_wave_redraw:
		queue_redraw()


func _update_tile_fade(delta: float) -> bool:
	if _lit_tiles.is_empty():
		return false
	var decay := delta / maxf(0.05, fade_duration)
	var changed := false
	var faded_cells: Array[Vector2i] = []
	for cell_variant in _lit_tiles.keys():
		var cell: Vector2i = cell_variant
		var tile: Dictionary = tiles[cell]
		var min_light := floor_min_light_level if bool(tile["is_floor"]) else 0.0
		var current := float(tile["light_level"])
		if current > min_light:
			var next_light := maxf(min_light, current - decay)
			tile["light_level"] = next_light
			changed = true
			if next_light <= min_light:
				faded_cells.append(cell)
		else:
			faded_cells.append(cell)
	for cell in faded_cells:
		_lit_tiles.erase(cell)
	return changed


func _update_rays_and_ripples(delta: float) -> bool:
	_sim_tick += 1
	var had_activity := not active_rays.is_empty() or not active_ripples.is_empty()

	var ray_write := 0
	var ray_count := active_rays.size()
	for i in ray_count:
		var ray: Dictionary = active_rays[i]
		if _step_ray(ray, delta):
			if ray_write != i:
				active_rays[ray_write] = ray
			ray_write += 1
	if ray_write != ray_count:
		active_rays.resize(ray_write)

	var ripple_write := 0
	var ripple_count := active_ripples.size()
	for i in ripple_count:
		var ripple: Dictionary = active_ripples[i]
		var age := float(ripple["age"]) + delta
		if age < float(ripple["duration"]):
			ripple["age"] = age
			if ripple_write != i:
				active_ripples[ripple_write] = ripple
			ripple_write += 1
	if ripple_write != ripple_count:
		active_ripples.resize(ripple_write)

	return had_activity or not active_rays.is_empty() or not active_ripples.is_empty()


func _step_ray(ray: Dictionary, delta: float) -> bool:
	var remaining_lifetime := float(ray["remaining_lifetime"]) - delta
	if remaining_lifetime <= 0.0:
		return false
	ray["remaining_lifetime"] = remaining_lifetime

	var velocity: Vector2 = ray["velocity"]
	var displacement_len := velocity.length() * delta
	var substep_count := maxi(1, ceili(displacement_len / 16.0))
	var step_delta := delta / float(substep_count)
	var current_pos: Vector2 = ray["position"]

	for _step in substep_count:
		var next_pos := current_pos + velocity * step_delta
		var current_cell := world_to_grid(current_pos)
		var next_cell := world_to_grid(next_pos)

		if next_cell != current_cell and tiles.has(next_cell):
			var hit_tile: Dictionary = tiles[next_cell]
			var hit_kind := int(hit_tile["kind"])
			var bounce_count := int(ray["bounce_count"]) + 1
			var normal := _compute_grid_normal(current_cell, next_cell, velocity)
			var impact_pos := _compute_impact_point(current_pos, next_pos, next_cell, normal)

			var max_life := maxf(0.001, float(ray["max_lifetime"]))
			var life_ratio := clampf(remaining_lifetime / max_life, 0.0, 1.0)
			var visibility_level := clampf(remaining_lifetime / maxf(0.05, fade_duration), 0.0, 1.0)
			if bounce_count == 1 and life_ratio >= 0.85 and max_life >= fade_duration * 0.9:
				visibility_level = 1.0
			if int(ray.get("pulse_kind", PulseKind.RUN)) == PulseKind.RUN:
				visibility_level *= 0.55
			illuminate_cell(next_cell, visibility_level, bounce_count, normal)

			if hit_kind == TileKind.ABSORBER:
				_spawn_impact_ripple(impact_pos, absorber_tile_color, 6.0, normal)
				wave_absorbed.emit(impact_pos)
				return false

			if hit_kind == TileKind.BREAKABLE:
				var pulse_kind := int(ray.get("pulse_kind", PulseKind.RUN))
				if pulse_kind == PulseKind.SCREAM:
					_break_wall_at_cell(next_cell, impact_pos, velocity.normalized())
					_spawn_impact_ripple(impact_pos, breakable_tile_color, 12.0, normal)
					current_pos = next_pos
					ray["position"] = next_pos
					continue
				else:
					var wall_node = hit_tile.get("wall_node")
					if wall_node != null and is_instance_valid(wall_node) and wall_node.has_method("pulse_resonance"):
						wall_node.pulse_resonance()

			ray["bounce_count"] = bounce_count
			velocity = velocity.bounce(normal)
			var min_ricochet_speed := 240.0 if bool(ray["is_forward"]) else 170.0
			var current_speed := velocity.length()
			if hit_kind == TileKind.BOUNCE_PAD:
				current_speed = minf(forward_speed * 1.15, current_speed * 1.10)
			elif hit_kind == TileKind.BREAKABLE:
				current_speed = maxf(min_ricochet_speed, current_speed * (1.0 - bounce_energy_loss * 0.6))
			else:
				current_speed = maxf(min_ricochet_speed, current_speed * (1.0 - bounce_energy_loss * 0.45))

			velocity = velocity.normalized() * current_speed
			ray["velocity"] = velocity
			current_pos = impact_pos + normal * 2.0
			_spawn_impact_ripple(
				impact_pos,
				_resolve_ray_color(bounce_count, int(ray["pulse_kind"])),
				7.0,
				normal,
			)
			wave_bounced.emit(impact_pos, normal, bounce_count)
		else:
			current_pos = next_pos

	ray["position"] = current_pos
	return true


func _spawn_impact_ripple(world_position: Vector2, color: Color, max_radius: float = 7.0, normal: Vector2 = Vector2.UP) -> void:
	if active_ripples.size() >= 256:
		return
	active_ripples.append({
		"position": world_position,
		"color": color,
		"age": 0.0,
		"duration": ripple_duration,
		"max_radius": max_radius,
		"normal": normal,
	})


func _compute_grid_normal(previous_cell: Vector2i, hit_cell: Vector2i, velocity: Vector2) -> Vector2:
	var delta_cell := hit_cell - previous_cell
	if delta_cell.x != 0 and delta_cell.y == 0:
		return Vector2(-signf(float(delta_cell.x)), 0.0)
	if delta_cell.y != 0 and delta_cell.x == 0:
		return Vector2(0.0, -signf(float(delta_cell.y)))

	var horizontal_cell := Vector2i(hit_cell.x, previous_cell.y)
	var vertical_cell := Vector2i(previous_cell.x, hit_cell.y)
	var horizontal_blocked := tiles.has(horizontal_cell)
	var vertical_blocked := tiles.has(vertical_cell)
	if horizontal_blocked and not vertical_blocked:
		return Vector2(0.0, -signf(velocity.y if not is_zero_approx(velocity.y) else 1.0))
	if vertical_blocked and not horizontal_blocked:
		return Vector2(-signf(velocity.x if not is_zero_approx(velocity.x) else 1.0), 0.0)

	if absf(velocity.x) >= absf(velocity.y):
		return Vector2(-signf(velocity.x if not is_zero_approx(velocity.x) else 1.0), 0.0)
	return Vector2(0.0, -signf(velocity.y if not is_zero_approx(velocity.y) else 1.0))


func _compute_impact_point(from_pos: Vector2, to_pos: Vector2, hit_cell: Vector2i, normal: Vector2) -> Vector2:
	var rect := grid_to_world_rect(hit_cell)
	var impact := from_pos.lerp(to_pos, 0.5)
	if not is_zero_approx(normal.x):
		impact.x = rect.position.x if normal.x < 0.0 else rect.end.x
		impact.y = clampf(impact.y, rect.position.y, rect.end.y)
	elif not is_zero_approx(normal.y):
		impact.y = rect.position.y if normal.y < 0.0 else rect.end.y
		impact.x = clampf(impact.x, rect.position.x, rect.end.x)
	return impact


func _draw() -> void:
	var drawn_with_culling := false
	var viewport := get_viewport()
	if viewport != null and not tiles.is_empty():
		var visible_size := viewport.get_visible_rect().size
		if visible_size.x > 0.0 and visible_size.y > 0.0:
			var inv_xform := get_global_transform_with_canvas().affine_inverse()
			var local_tl := inv_xform * Vector2.ZERO
			var local_br := inv_xform * visible_size
			var world_tl := to_global(Vector2(minf(local_tl.x, local_br.x), minf(local_tl.y, local_br.y))) - Vector2(GRID_SIZE * 2.0, GRID_SIZE * 2.0)
			var world_br := to_global(Vector2(maxf(local_tl.x, local_br.x), maxf(local_tl.y, local_br.y))) + Vector2(GRID_SIZE * 2.0, GRID_SIZE * 2.0)
			var min_cell := world_to_grid(world_tl)
			var max_cell := world_to_grid(world_br)
			var span_x := maxi(0, max_cell.x - min_cell.x + 1)
			var span_y := maxi(0, max_cell.y - min_cell.y + 1)
			if span_x * span_y < tiles.size():
				drawn_with_culling = true
				for cx in range(min_cell.x, max_cell.x + 1):
					for cy in range(min_cell.y, max_cell.y + 1):
						var cell := Vector2i(cx, cy)
						if tiles.has(cell):
							_draw_tile_cell(cell, tiles[cell])

	if not drawn_with_culling:
		for cell_variant in tiles.keys():
			var cell: Vector2i = cell_variant
			_draw_tile_cell(cell, tiles[cell])

	_draw_wave_arcs()


func _draw_tile_cell(cell: Vector2i, tile: Dictionary) -> void:
	var rect := grid_to_world_rect(cell)
	var local_rect := Rect2(to_local(rect.position), rect.size)
	var light_level := clampf(float(tile["light_level"]), 0.0, 1.0)
	var is_floor := bool(tile["is_floor"])
	var kind := int(tile["kind"])
	var visibility := (0.34 + 0.66 * light_level) if is_floor else (0.20 + 0.80 * light_level)

	if kind != TileKind.BREAKABLE:
		# Use #21263f shadow mask so the bottom of tiles blends seamlessly into the background; gently deepens in silence.
		var silence_extra := silence_dim * (0.04 if is_floor else 0.08) * (1.0 - light_level)
		var shadow_alpha := clampf(1.0 - visibility + silence_extra, 0.0, 0.90)
		if shadow_alpha > 0.001:
			draw_rect(local_rect, Color(0.129412, 0.14902, 0.247059, shadow_alpha), true)

	# Only illuminate the top or the specific face that the wave hit (never the bottom of floor blocks or the whole 48x48 box)
	if light_level > floor_min_light_level + 0.02 or (not is_floor and light_level > 0.05):
		var base_color: Color = tile["last_hit_color"]
		var face_alpha := light_level * (0.28 if is_floor else 0.36)
		var face_color := Color(base_color.r, base_color.g, base_color.b, face_alpha)
		var face_normal := _resolve_tile_face_normal(cell, tile)
		_draw_tile_face_highlight(local_rect, face_normal, face_color)


func _resolve_tile_face_normal(cell: Vector2i, tile: Dictionary) -> Vector2:
	var hit_normal: Vector2 = tile.get("hit_normal", Vector2.ZERO)
	var is_floor := bool(tile["is_floor"])
	if is_floor:
		if not is_zero_approx(hit_normal.x) and not tiles.has(cell + Vector2i(roundi(hit_normal.x), 0)):
			return Vector2(signf(hit_normal.x), 0.0)
		return Vector2.UP
	if not hit_normal.is_zero_approx():
		return hit_normal
	if not tiles.has(cell + Vector2i.UP):
		return Vector2.UP
	if not tiles.has(cell + Vector2i.DOWN):
		return Vector2.DOWN
	if not tiles.has(cell + Vector2i.RIGHT):
		return Vector2.RIGHT
	if not tiles.has(cell + Vector2i.LEFT):
		return Vector2.LEFT
	return Vector2.UP


func _draw_tile_face_highlight(local_rect: Rect2, face_normal: Vector2, color: Color) -> void:
	var strip_thickness := ART_PIXEL_SIZE * 2.0
	if face_normal.y < -0.5:
		draw_rect(Rect2(local_rect.position, Vector2(local_rect.size.x, strip_thickness)), color, true)
	elif face_normal.y > 0.5:
		draw_rect(
			Rect2(
				Vector2(local_rect.position.x, local_rect.end.y - strip_thickness),
				Vector2(local_rect.size.x, strip_thickness),
			),
			color,
			true,
		)
	elif face_normal.x < -0.5:
		draw_rect(Rect2(local_rect.position, Vector2(strip_thickness, local_rect.size.y)), color, true)
	elif face_normal.x > 0.5:
		draw_rect(
			Rect2(
				Vector2(local_rect.end.x - strip_thickness, local_rect.position.y),
				Vector2(strip_thickness, local_rect.size.y),
			),
			color,
			true,
		)


func _snap_wave_point(world_pt: Vector2) -> Vector2:
	var local_pt := to_local(world_pt)
	var half_px := WAVE_PIXEL_SIZE * 0.5
	return Vector2(
		floorf(local_pt.x / WAVE_PIXEL_SIZE) * WAVE_PIXEL_SIZE + half_px,
		floorf(local_pt.y / WAVE_PIXEL_SIZE) * WAVE_PIXEL_SIZE + half_px,
	)


func _draw_wave_arcs() -> void:
	var total_rays := active_rays.size()
	if total_rays == 0:
		return

	_arc_points.clear()
	_arc_colors.clear()
	var quantized_time := floorf(_wave_time * 8.0) / 8.0
	var band_count := ARC_BAND_OFFSETS.size()
	var pulse_start := 0

	while pulse_start < total_rays:
		var pid := int(active_rays[pulse_start]["pulse_id"])
		var pulse_end := pulse_start + 1
		while pulse_end < total_rays and int(active_rays[pulse_end]["pulse_id"]) == pid:
			pulse_end += 1

		var slice_len := pulse_end - pulse_start
		if _connected_flags.size() < slice_len:
			_connected_flags.resize(slice_len)
		for f_idx in slice_len:
			_connected_flags[f_idx] = 0

		var ray_count := maxi(1, int(active_rays[pulse_start]["ray_count"]))

		if slice_len > 1:
			for local_a in slice_len:
				var local_b := (local_a + 1) if local_a + 1 < slice_len else 0
				var ray_a: Dictionary = active_rays[pulse_start + local_a]
				var ray_b: Dictionary = active_rays[pulse_start + local_b]
				var idx_a := int(ray_a["ray_index"])
				var idx_b := int(ray_b["ray_index"])
				if (idx_a + 1) % ray_count != idx_b:
					continue

				var bounce_a := int(ray_a["bounce_count"])
				var bounce_b := int(ray_b["bounce_count"])
				if absi(bounce_a - bounce_b) > 1:
					continue

				var pos_a: Vector2 = ray_a["position"]
				var pos_b: Vector2 = ray_b["position"]
				var span_sq := pos_a.distance_squared_to(pos_b)
				var max_span := 54.0 if bounce_a == 0 else 48.0
				if span_sq > max_span * max_span:
					continue

				var dir_a := Vector2(ray_a["velocity"]).normalized()
				var dir_b := Vector2(ray_b["velocity"]).normalized()
				if dir_a.dot(dir_b) < 0.58:
					continue

				_connected_flags[local_a] = 1
				_connected_flags[local_b] = 1

				var life_a := clampf(float(ray_a["remaining_lifetime"]) / maxf(0.001, float(ray_a["max_lifetime"])), 0.0, 1.0)
				var life_b := clampf(float(ray_b["remaining_lifetime"]) / maxf(0.001, float(ray_b["max_lifetime"])), 0.0, 1.0)
				var life_ratio := minf(life_a, life_b)
				var decay_power := float(ray_a["decay_power"])
				var alpha_fade := pow(life_ratio, decay_power)
				var is_forward := bool(ray_a["is_forward"]) or bool(ray_b["is_forward"])
				var raw_alpha := alpha_fade * (0.72 if is_forward else 0.48)
				if raw_alpha < 0.002:
					continue

				var arc_color := _resolve_ray_color(maxi(bounce_a, bounce_b), int(ray_a["pulse_kind"]))
				var amp_scale := (1.0 if is_forward else 0.6) * (0.35 + 0.65 * life_ratio)
				var subdivisions := ARC_SUBDIVISIONS if (bounce_a == 0 and span_sq > 144.0) else 1

				# Waves shrink over their active lifetime: band spread contracts, arc segments narrow, and pixels thin out.
				var band_spread_scale := lerpf(0.15, 1.0, life_ratio)
				var span_shrink := clampf(life_ratio / 0.85, 0.18, 1.0)
				var seg_mid := pos_a.lerp(pos_b, 0.5)
				var shrunk_a := seg_mid.lerp(pos_a, span_shrink)
				var shrunk_b := seg_mid.lerp(pos_b, span_shrink)

				for band_idx in band_count:
					var band_scale := 1.0 if band_idx == 1 else (0.52 * clampf((life_ratio - 0.35) / 0.65, 0.0, 1.0))
					var band_alpha := raw_alpha * band_scale
					if band_alpha < 0.002:
						continue
					var offset_px := ARC_BAND_OFFSETS[band_idx] * band_spread_scale
					var band_amp := wave_undulation_amplitude * (1.0 if band_idx == 1 else 0.65) * amp_scale
					var band_phase := quantized_time * wave_undulation_speed + float(band_idx) * 1.4
					var seg_color := Color(arc_color.r, arc_color.g, arc_color.b, band_alpha)

					var prev_pt := Vector2.ZERO
					for step in range(subdivisions + 1):
						var t := float(step) / float(subdivisions)
						var base_pos := shrunk_a.lerp(shrunk_b, t)
						var interp_dir := dir_a.lerp(dir_b, t).normalized()
						if interp_dir.is_zero_approx():
							interp_dir = dir_a
						var theta := TAU * (float(idx_a) + t) / float(ray_count)
						var ripple := sin(theta * wave_undulation_cycles + band_phase) * band_amp
						var snapped := _snap_wave_point(base_pos + interp_dir * (offset_px + ripple))
						if step > 0:
							_arc_points.append(prev_pt)
							_arc_points.append(snapped)
							_arc_colors.append(seg_color)
						prev_pt = snapped

		# Draw ricocheting wavelet crests for bounced rays that separated from their neighbors
		for local_idx in slice_len:
			if _connected_flags[local_idx] != 0:
				continue
			var ray: Dictionary = active_rays[pulse_start + local_idx]
			var life_ratio := clampf(float(ray["remaining_lifetime"]) / maxf(0.001, float(ray["max_lifetime"])), 0.0, 1.0)
			if life_ratio <= 0.005:
				continue
			var alpha_fade := pow(life_ratio, float(ray["decay_power"]))
			var is_forward := bool(ray["is_forward"])
			var raw_alpha := alpha_fade * (0.68 if is_forward else 0.44)
			if raw_alpha < 0.002:
				continue

			var dir := Vector2(ray["velocity"]).normalized()
			if dir.is_zero_approx():
				dir = Vector2.RIGHT
			var tangent := Vector2(-dir.y, dir.x)
			var pos: Vector2 = ray["position"]
			var arc_color := _resolve_ray_color(int(ray["bounce_count"]), int(ray["pulse_kind"]))
			var half_width := (6.5 if is_forward else 4.5) * (0.55 + 0.45 * life_ratio)
			var band_spread_scale := lerpf(0.15, 1.0, life_ratio)

			for band_idx in band_count:
				var band_scale := 1.0 if band_idx == 1 else (0.48 * clampf((life_ratio - 0.35) / 0.65, 0.0, 1.0))
				var band_alpha := raw_alpha * band_scale
				if band_alpha < 0.002:
					continue
				var offset_px := ARC_BAND_OFFSETS[band_idx] * band_spread_scale
				var seg_color := Color(arc_color.r, arc_color.g, arc_color.b, band_alpha)
				var left_pt := _snap_wave_point(pos - tangent * half_width + dir * (offset_px - 1.5))
				var mid_pt := _snap_wave_point(pos + dir * offset_px)
				var right_pt := _snap_wave_point(pos + tangent * half_width + dir * (offset_px - 1.5))
				_arc_points.append(left_pt)
				_arc_points.append(mid_pt)
				_arc_colors.append(seg_color)
				_arc_points.append(mid_pt)
				_arc_points.append(right_pt)
				_arc_colors.append(seg_color)

		pulse_start = pulse_end

	if not _arc_points.is_empty():
		draw_multiline_colors(_arc_points, _arc_colors, WAVE_PIXEL_SIZE, false)


func _resolve_tile_hit_color(kind: int, bounce_count: int) -> Color:
	var base := _base_color_for_kind(kind)
	if bounce_count >= 2:
		return base.lerp(player_accent_color, 0.55)
	return base


func _resolve_ray_color(bounce_count: int, pulse_kind: int) -> Color:
	var base := safe_tile_color
	if pulse_kind == PulseKind.SCREAM:
		base = Color(0.94, 0.92, 0.75, 1.0).lerp(player_accent_color, 0.45)
	elif pulse_kind == PulseKind.JUMP or pulse_kind == PulseKind.LAND:
		base = Color(0.76, 0.95, 0.95, 1.0)
	if bounce_count >= 2:
		return base.lerp(player_accent_color, 0.72)
	elif bounce_count == 1:
		return base.lerp(player_accent_color, 0.35)
	return base


func _base_color_for_kind(kind: int) -> Color:
	match kind:
		TileKind.HAZARD:
			return hazard_tile_color
		TileKind.BOUNCE_PAD:
			return bounce_pad_tile_color
		TileKind.ABSORBER:
			return absorber_tile_color
		TileKind.BREAKABLE:
			return breakable_tile_color
		_:
			return safe_tile_color


func _is_chunk_floor_cell(chunk: CourseChunk, local_cell: Vector2i) -> bool:
	if local_cell.y >= 0:
		return true
	if chunk.chunk_id == &"step_up" or chunk.chunk_id == &"step_down":
		return true
	if chunk.chunk_id == &"wall_jump" and local_cell.x >= 5 and local_cell.y == -3:
		return true
	return false


func _classify_chunk_cell(chunk: CourseChunk, local_cell: Vector2i, is_floor: bool) -> int:
	if is_floor:
		return TileKind.SAFE
	if chunk.chunk_id == &"bounce_reward" or chunk.allows_wall_jump or chunk.terrain_features.has(&"wall_climb"):
		if local_cell.y <= -2:
			return TileKind.BOUNCE_PAD
	if chunk.dead_end_paths > 0 and local_cell.y <= -2:
		return TileKind.HAZARD
	if local_cell.y <= -1 and not chunk.allows_wall_jump:
		return TileKind.HAZARD
	return TileKind.SAFE


func _register_cell(world_cell: Vector2i, kind: int, is_floor: bool, wall_node: Node = null) -> void:
	var initial_light := floor_min_light_level if is_floor else 0.0
	var base_color := _base_color_for_kind(kind)
	tiles[world_cell] = {
		"light_level": initial_light,
		"last_hit_color": base_color,
		"kind": kind,
		"is_floor": is_floor,
		"wall_node": wall_node,
	}


func _register_static_body_cells(
	generator: CourseGenerator,
	body: StaticBody2D,
	kind: int,
	is_floor: bool,
	wall_node: Node = null
) -> void:
	var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		return
	var rect_shape := shape_node.shape as RectangleShape2D
	if rect_shape == null:
		return
	var extents := rect_shape.size * 0.5
	var center := shape_node.global_position
	var origin := generator.global_position if generator != null else grid_origin
	var min_pos := center - extents - origin
	var max_pos := center + extents - origin
	var min_cell_x := floori((min_pos.x + HALF_GRID) / GRID_SIZE)
	var max_cell_x := floori((max_pos.x + HALF_GRID - 0.01) / GRID_SIZE)
	var min_cell_y := floori((min_pos.y + HALF_GRID) / GRID_SIZE)
	var max_cell_y := floori((max_pos.y + HALF_GRID - 0.01) / GRID_SIZE)
	for cx in range(min_cell_x, max_cell_x + 1):
		for cy in range(min_cell_y, max_cell_y + 1):
			_register_cell(Vector2i(cx, cy), kind, is_floor, wall_node)


func _break_wall_at_cell(world_cell: Vector2i, impact_pos: Vector2, impact_dir: Vector2) -> void:
	if not tiles.has(world_cell):
		return
	var hit_tile: Dictionary = tiles[world_cell]
	var wall_node = hit_tile.get("wall_node")
	if wall_node != null and is_instance_valid(wall_node):
		if wall_node.has_method("break_wall"):
			wall_node.break_wall(impact_dir)
		var to_remove: Array[Vector2i] = []
		for cell in tiles.keys():
			if tiles[cell].get("wall_node") == wall_node:
				to_remove.append(cell)
		for cell in to_remove:
			tiles.erase(cell)
			_lit_tiles.erase(cell)
	else:
		tiles.erase(world_cell)
		_lit_tiles.erase(world_cell)
	wall_broken.emit(impact_pos, world_cell)
	queue_redraw()

