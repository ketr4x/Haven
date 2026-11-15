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
@export_range(3, 8, 1) var max_trail_points: int = 5
@export var ripple_duration: float = 0.28
@export var wave_undulation_cycles: float = 8.0
@export var wave_undulation_speed: float = 3.5
@export var wave_undulation_amplitude: float = 1.2

@export_category("Palette")
@export var safe_tile_color: Color = Color(0.51, 0.71, 0.85, 1.0)
@export var hazard_tile_color: Color = Color(0.75, 0.41, 0.47, 1.0)
@export var bounce_pad_tile_color: Color = Color(0.94, 0.92, 0.75, 1.0)
@export var absorber_tile_color: Color = Color(0.28, 0.29, 0.45, 1.0)
@export var breakable_tile_color: Color = Color(0.98, 0.62, 0.25, 1.0)
@export var player_accent_color: Color = Color(0.76, 0.95, 0.95, 1.0)

var grid_origin: Vector2 = Vector2.ZERO
var tiles: Dictionary = {}
var active_rays: Array[Dictionary] = []
var active_ripples: Array[Dictionary] = []

var _next_pulse_group_id: int = 0
var _wave_time: float = 0.0


func _ready() -> void:
	z_index = 5


func set_player_accent_color(color: Color) -> void:
	player_accent_color = color
	queue_redraw()


func clear_waves() -> void:
	active_rays.clear()
	active_ripples.clear()
	queue_redraw()


func rebuild_from_generator(generator: CourseGenerator) -> void:
	tiles.clear()
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
		for roof_cell in roof.get_used_cells():
			_register_cell(roof_cell, TileKind.SAFE, false)

	queue_redraw()


func rebuild_from_static_bodies(root_node: Node2D, floor_y_threshold: float = 640.0) -> void:
	tiles.clear()
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

	var cone_cos := cos(deg_to_rad(forward_cone_half_angle_degrees))
	var spawned := 0
	for index in ray_count:
		var angle := TAU * float(index) / float(maxi(1, ray_count))
		var direction := Vector2.from_angle(angle)
		var alignment := direction.dot(forward_dir)
		var is_forward := alignment >= cone_cos

		var ray_speed := forward_speed if is_forward else peripheral_speed
		var range_tiles := (forward_range_tiles if is_forward else peripheral_range_tiles) * range_multiplier
		var max_distance := range_tiles * GRID_SIZE
		var ray_lifetime := max_distance / maxf(1.0, ray_speed)
		var allowed_bounces := maxi(0, (forward_max_bounces if is_forward else peripheral_max_bounces) + extra_bounces)

		var start_pos := origin + direction * 6.0
		var trail := PackedVector2Array([start_pos])
		active_rays.append({
			"pulse_id": pulse_id,
			"ray_index": index,
			"ray_count": ray_count,
			"position": start_pos,
			"velocity": direction * ray_speed,
			"remaining_lifetime": ray_lifetime,
			"max_lifetime": ray_lifetime,
			"bounce_count": 0,
			"max_bounces": allowed_bounces,
			"trail": trail,
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


func illuminate_cell(world_cell: Vector2i, level: float = 1.0, bounce_count: int = 0) -> void:
	if not tiles.has(world_cell):
		return
	var tile: Dictionary = tiles[world_cell]
	var min_light := floor_min_light_level if bool(tile["is_floor"]) else 0.0
	var clamped_level := clampf(level, min_light, 1.0)
	tile["light_level"] = maxf(float(tile["light_level"]), clamped_level)
	tile["last_hit_color"] = _resolve_tile_hit_color(int(tile["kind"]), bounce_count)
	tile_illuminated.emit(world_cell, int(tile["kind"]), float(tile["light_level"]))

	for offset in NEIGHBOR_OFFSETS:
		var neighbor_cell := world_cell + offset
		if not tiles.has(neighbor_cell):
			continue
		var neighbor: Dictionary = tiles[neighbor_cell]
		var neighbor_min := floor_min_light_level if bool(neighbor["is_floor"]) else 0.0
		var boosted := clampf(float(neighbor["light_level"]) + neighbor_light_boost, neighbor_min, 1.0)
		neighbor["light_level"] = boosted
		neighbor["last_hit_color"] = _resolve_tile_hit_color(int(neighbor["kind"]), bounce_count)


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
	if tiles.is_empty():
		return false
	var decay := delta / maxf(0.05, fade_duration)
	var changed := false
	for cell in tiles.keys():
		var tile: Dictionary = tiles[cell]
		var min_light := floor_min_light_level if bool(tile["is_floor"]) else 0.0
		var current := float(tile["light_level"])
		if current > min_light:
			tile["light_level"] = maxf(min_light, current - decay)
			changed = true
	return changed


func _update_rays_and_ripples(delta: float) -> bool:
	var had_activity := not active_rays.is_empty() or not active_ripples.is_empty()

	var surviving_rays: Array[Dictionary] = []
	for ray in active_rays:
		if _step_ray(ray, delta):
			surviving_rays.append(ray)
	active_rays = surviving_rays

	var surviving_ripples: Array[Dictionary] = []
	for ripple in active_ripples:
		var age := float(ripple["age"]) + delta
		if age < float(ripple["duration"]):
			ripple["age"] = age
			surviving_ripples.append(ripple)
	active_ripples = surviving_ripples

	return had_activity or not active_rays.is_empty() or not active_ripples.is_empty()


func _step_ray(ray: Dictionary, delta: float) -> bool:
	var remaining_lifetime := float(ray["remaining_lifetime"]) - delta
	if remaining_lifetime <= 0.0:
		return false
	ray["remaining_lifetime"] = remaining_lifetime

	var velocity: Vector2 = ray["velocity"]
	var total_displacement := velocity * delta
	var substep_count := maxi(1, ceili(total_displacement.length() / 12.0))
	var step_delta := delta / float(substep_count)

	for _step in substep_count:
		var current_pos: Vector2 = ray["position"]
		velocity = ray["velocity"]
		var next_pos := current_pos + velocity * step_delta
		var current_cell := world_to_grid(current_pos)
		var next_cell := world_to_grid(next_pos)

		if next_cell != current_cell and tiles.has(next_cell):
			var hit_tile: Dictionary = tiles[next_cell]
			var hit_kind := int(hit_tile["kind"])
			var bounce_count := int(ray["bounce_count"]) + 1
			var normal := _compute_grid_normal(current_cell, next_cell, velocity)
			var impact_pos := _compute_impact_point(current_pos, next_pos, next_cell, normal)

			illuminate_cell(next_cell, 1.0, bounce_count)

			if hit_kind == TileKind.ABSORBER:
				_spawn_impact_ripple(impact_pos, absorber_tile_color, 6.0, normal)
				wave_absorbed.emit(impact_pos)
				return false

			if hit_kind == TileKind.BREAKABLE:
				var pulse_kind := int(ray.get("pulse_kind", PulseKind.RUN))
				if pulse_kind == PulseKind.SCREAM:
					_break_wall_at_cell(next_cell, impact_pos, velocity.normalized())
					_spawn_impact_ripple(impact_pos, breakable_tile_color, 12.0, normal)
					ray["position"] = next_pos
					continue
				else:
					var wall_node = hit_tile.get("wall_node")
					if wall_node != null and is_instance_valid(wall_node) and wall_node.has_method("pulse_resonance"):
						wall_node.pulse_resonance()

			ray["bounce_count"] = bounce_count
			velocity = velocity.bounce(normal)
			if hit_kind == TileKind.BOUNCE_PAD:
				velocity *= 1.12
				ray["remaining_lifetime"] = float(ray["remaining_lifetime"]) * 0.92
			elif hit_kind == TileKind.BREAKABLE:
				ray["remaining_lifetime"] = float(ray["remaining_lifetime"]) * (1.0 - bounce_energy_loss * 0.8)
			else:
				ray["remaining_lifetime"] = float(ray["remaining_lifetime"]) * (1.0 - bounce_energy_loss)

			ray["velocity"] = velocity
			ray["position"] = impact_pos + normal * 2.0
			_append_trail_point(ray, impact_pos)
			_spawn_impact_ripple(
				impact_pos,
				_resolve_ray_color(bounce_count, int(ray["pulse_kind"])),
				7.0,
				normal,
			)
			wave_bounced.emit(impact_pos, normal, bounce_count)

			if bounce_count >= int(ray["max_bounces"]) or float(ray["remaining_lifetime"]) <= 0.0:
				return false
		else:
			ray["position"] = next_pos

	_append_trail_point(ray, ray["position"])
	return true


func _append_trail_point(ray: Dictionary, point: Vector2) -> void:
	var trail: PackedVector2Array = ray["trail"]
	trail.append(point)
	while trail.size() > max_trail_points:
		trail.remove_at(0)
	ray["trail"] = trail


func _spawn_impact_ripple(world_position: Vector2, color: Color, max_radius: float = 7.0, normal: Vector2 = Vector2.UP) -> void:
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
	for cell_variant in tiles.keys():
		var cell: Vector2i = cell_variant
		var tile: Dictionary = tiles[cell]
		var rect := grid_to_world_rect(cell)
		var local_rect := Rect2(to_local(rect.position), rect.size)
		var light_level := clampf(float(tile["light_level"]), 0.0, 1.0)
		var is_floor := bool(tile["is_floor"])
		var visibility := (0.34 + 0.66 * light_level) if is_floor else (0.20 + 0.80 * light_level)

		# Darken unlit/fading tiles with a transparent shadow mask so underlying pixel-art tile textures show through
		var shadow_alpha := clampf(1.0 - visibility, 0.0, 1.0)
		if shadow_alpha > 0.001:
			draw_rect(local_rect, Color(0.0, 0.0, 0.0, shadow_alpha), true)

		# Subtle 1px pixel-aligned contour tint when illuminated by sonar waves
		if light_level > 0.05:
			var base_color: Color = tile["last_hit_color"]
			var border_alpha := light_level * (0.22 if is_floor else 0.34)
			var border_color := Color(base_color.r, base_color.g, base_color.b, border_alpha)
			draw_rect(local_rect.grow(-1.0), border_color, false, WAVE_PIXEL_SIZE)

	_draw_wave_arcs()


func _draw_wave_arcs() -> void:
	if active_rays.is_empty():
		return

	var pulses: Dictionary = {}
	for ray in active_rays:
		var pid := int(ray.get("pulse_id", 0))
		if not pulses.has(pid):
			pulses[pid] = []
		(pulses[pid] as Array).append(ray)

	var pixel_canvas: Dictionary = {}
	var quantized_time := floorf(_wave_time * 8.0) / 8.0

	for pid in pulses.keys():
		var group: Array = pulses[pid]
		if group.is_empty():
			continue
		var by_index: Dictionary = {}
		var ray_count := maxi(1, int((group[0] as Dictionary).get("ray_count", 90)))
		for ray_variant in group:
			var ray: Dictionary = ray_variant
			by_index[int(ray["ray_index"])] = ray

		for ray_variant in group:
			var ray_a: Dictionary = ray_variant
			var idx_a := int(ray_a["ray_index"])
			var idx_b := (idx_a + 1) % ray_count
			if not by_index.has(idx_b):
				continue
			var ray_b: Dictionary = by_index[idx_b]

			var bounce_a := int(ray_a["bounce_count"])
			var bounce_b := int(ray_b["bounce_count"])
			if bounce_a != bounce_b:
				continue

			var pos_a: Vector2 = ray_a["position"]
			var pos_b: Vector2 = ray_b["position"]
			var max_span := 46.0 if bounce_a == 0 else 38.0
			if pos_a.distance_to(pos_b) > max_span:
				continue

			var dir_a := Vector2(ray_a["velocity"]).normalized()
			var dir_b := Vector2(ray_b["velocity"]).normalized()
			if dir_a.dot(dir_b) < 0.72:
				continue

			var life_a := clampf(float(ray_a["remaining_lifetime"]) / maxf(0.001, float(ray_a["max_lifetime"])), 0.0, 1.0)
			var life_b := clampf(float(ray_b["remaining_lifetime"]) / maxf(0.001, float(ray_b["max_lifetime"])), 0.0, 1.0)
			var life_ratio := minf(life_a, life_b)
			var is_forward := bool(ray_a["is_forward"]) or bool(ray_b["is_forward"])
			var arc_color := _resolve_ray_color(bounce_a, int(ray_a["pulse_kind"]))
			# Subtle, thin pixel-art alpha quantized to 4 steps so it blends gently over textures
			var raw_alpha := life_ratio * (0.54 if is_forward else 0.34)
			var stepped_alpha := ceilf(raw_alpha * 4.0) / 4.0
			var amp_scale := (1.0 if is_forward else 0.6) * (0.5 + 0.5 * life_ratio)

			for band_idx in ARC_BAND_OFFSETS.size():
				var offset_px := ARC_BAND_OFFSETS[band_idx]
				var band_scale := 1.0 if band_idx == 1 else 0.48
				var band_amp := wave_undulation_amplitude * (1.0 if band_idx == 1 else 0.65) * amp_scale
				var band_phase := quantized_time * wave_undulation_speed + float(band_idx) * 1.4
				var pixel_col := Color(arc_color.r, arc_color.g, arc_color.b, stepped_alpha * band_scale)

				var prev_cell := Vector2i.ZERO
				for step in range(ARC_SUBDIVISIONS + 1):
					var t := float(step) / float(ARC_SUBDIVISIONS)
					var base_pos := pos_a.lerp(pos_b, t)
					var interp_dir := dir_a.lerp(dir_b, t).normalized()
					if interp_dir.is_zero_approx():
						interp_dir = dir_a
					var theta := TAU * (float(idx_a) + t) / float(ray_count)
					var ripple := sin(theta * wave_undulation_cycles + band_phase) * band_amp
					var world_pt := base_pos + interp_dir * (offset_px + ripple)
					var local_pt := to_local(world_pt)
					var cur_cell := Vector2i(
						floori(local_pt.x / WAVE_PIXEL_SIZE),
						floori(local_pt.y / WAVE_PIXEL_SIZE),
					)
					if step > 0:
						_rasterize_pixel_line(pixel_canvas, prev_cell, cur_cell, pixel_col)
					else:
						_plot_art_pixel(pixel_canvas, cur_cell, pixel_col)
					prev_cell = cur_cell

	var pixel_size_vec := Vector2(WAVE_PIXEL_SIZE, WAVE_PIXEL_SIZE)
	for pixel_cell_variant in pixel_canvas.keys():
		var pixel_cell: Vector2i = pixel_cell_variant
		var col: Color = pixel_canvas[pixel_cell]
		draw_rect(
			Rect2(Vector2(float(pixel_cell.x) * WAVE_PIXEL_SIZE, float(pixel_cell.y) * WAVE_PIXEL_SIZE), pixel_size_vec),
			col,
			true,
		)


func _rasterize_pixel_line(canvas: Dictionary, from_cell: Vector2i, to_cell: Vector2i, color: Color) -> void:
	var x0 := from_cell.x
	var y0 := from_cell.y
	var x1 := to_cell.x
	var y1 := to_cell.y
	var dx := absi(x1 - x0)
	var sx := 1 if x0 < x1 else -1
	var dy := -absi(y1 - y0)
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	var steps := 0
	while true:
		_plot_art_pixel(canvas, Vector2i(x0, y0), color)
		if x0 == x1 and y0 == y1:
			break
		steps += 1
		if steps > 32:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


func _plot_art_pixel(canvas: Dictionary, cell: Vector2i, color: Color) -> void:
	if not canvas.has(cell):
		canvas[cell] = color
		return
	var existing: Color = canvas[cell]
	if color.a >= existing.a:
		canvas[cell] = color


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
	else:
		tiles.erase(world_cell)
	wall_broken.emit(impact_pos, world_cell)
	queue_redraw()

