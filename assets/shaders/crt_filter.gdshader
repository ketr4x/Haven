shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

// 1. Curvature (Barrel Distortion)
group_uniforms curvature;
uniform float curvature_x : hint_range(0.0, 0.6, 0.005) = 0.11;
uniform float curvature_y : hint_range(0.0, 0.6, 0.005) = 0.14;
uniform float screen_scale : hint_range(0.85, 1.15, 0.005) = 0.995;
uniform float glass_bulge : hint_range(0.0, 0.4, 0.005) = 0.04;

// 2. Vignette & Rounded Corners
group_uniforms vignette_and_corners;
uniform float corner_radius : hint_range(0.0, 0.4, 0.005) = 0.085;
uniform float corner_smoothness : hint_range(0.001, 0.08, 0.001) = 0.012;
uniform float vignette_intensity : hint_range(0.0, 2.0, 0.01) = 0.36;
uniform float vignette_opacity : hint_range(0.0, 1.0, 0.01) = 0.82;
uniform float vignette_roundness : hint_range(0.0, 1.0, 0.01) = 0.30;
uniform float bezel_reflection : hint_range(0.0, 0.3, 0.005) = 0.05;
uniform vec4 bezel_color : source_color = vec4(0.012, 0.012, 0.018, 1.0);

// 3. Scanlines
group_uniforms scanlines;
uniform float scanline_count : hint_range(60.0, 1080.0, 1.0) = 240.0;
uniform float scanline_density : hint_range(0.25, 3.0, 0.05) = 1.0;
uniform float scanline_opacity : hint_range(0.0, 1.0, 0.01) = 0.44;
uniform float scanline_sharpness : hint_range(0.5, 4.0, 0.05) = 1.5;
uniform float scanline_brightness_boost : hint_range(0.0, 0.6, 0.01) = 0.20;
uniform float scanline_scroll_speed : hint_range(-10.0, 10.0, 0.1) = 0.0;
uniform float scanline_curvature_follow : hint_range(0.0, 1.0, 0.05) = 1.0;

// 4. Shadow Mask / CRT Grid
group_uniforms shadow_mask;
uniform float mask_intensity : hint_range(0.0, 1.0, 0.01) = 0.45;
uniform float mask_scale : hint_range(0.5, 4.0, 0.1) = 1.5;
uniform float mask_grid_strength : hint_range(0.0, 1.0, 0.01) = 0.55;
uniform float mask_bright_boost : hint_range(0.0, 1.0, 0.01) = 0.75;

// 5. Chromatic Aberration (Color Bleeding / Fringing)
group_uniforms chromatic_aberration;
uniform float aberration_offset : hint_range(0.0, 12.0, 0.1) = 2.8;
uniform float aberration_edge_power : hint_range(0.5, 4.0, 0.05) = 1.55;
uniform float aberration_center_weight : hint_range(0.0, 1.0, 0.01) = 0.25;
uniform float color_bleed_strength : hint_range(0.0, 1.0, 0.01) = 0.58;
uniform float edge_blur_radius : hint_range(0.0, 6.0, 0.1) = 2.0;

// 6. Bloom / Glow
group_uniforms bloom;
uniform float bloom_intensity : hint_range(0.0, 2.0, 0.01) = 0.55;
uniform float bloom_threshold : hint_range(0.0, 1.0, 0.01) = 0.34;
uniform float bloom_soft_knee : hint_range(0.01, 0.5, 0.01) = 0.20;
uniform float bloom_radius : hint_range(0.5, 8.0, 0.1) = 3.2;
uniform float brightness_boost : hint_range(0.8, 1.6, 0.01) = 1.15;

float crt_luma(vec3 color) {
	return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

vec2 warp_crt_uv(vec2 uv) {
	vec2 centered = (uv * 2.0 - 1.0) * screen_scale;
	vec2 axial = centered.yx * centered.yx;
	centered += centered * axial * vec2(curvature_x, curvature_y);
	float r2 = dot(centered, centered);
	centered *= 1.0 + r2 * glass_bulge;
	return centered * 0.5 + 0.5;
}

float compute_rounded_bezel_sdf(vec2 curved_uv, float aspect) {
	vec2 p = abs(curved_uv * 2.0 - 1.0);
	vec2 half_extents = vec2(aspect, 1.0);
	vec2 sp = p * half_extents;
	float r = clamp(corner_radius, 0.001, 0.85);
	vec2 q = sp - (half_extents - vec2(r));
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

float compute_vignette(vec2 curved_uv) {
	vec2 u = clamp(curved_uv, 0.0, 1.0);
	float rect_vig = max(0.0, 16.0 * u.x * u.y * (1.0 - u.x) * (1.0 - u.y));
	float tube_vig = pow(rect_vig, max(0.01, vignette_intensity));

	vec2 centered = (u - vec2(0.5)) * 2.0;
	float radial_dist = length(centered);
	float radial_vig = 1.0 - smoothstep(0.68, 1.45, radial_dist);
	radial_vig = pow(clamp(radial_vig, 0.0, 1.0), max(0.01, vignette_intensity * 1.35));

	float combined = mix(tube_vig, radial_vig, vignette_roundness);
	return mix(1.0, combined, vignette_opacity);
}

vec3 sample_chromatic_bleed(vec2 uv, vec2 pixel_size) {
	vec2 centered = uv * 2.0 - 1.0;
	float dist_sq = dot(centered * vec2(1.15, 0.9), centered * vec2(1.15, 0.9));
	float edge_dist = sqrt(dist_sq);
	float edge_factor = mix(
		aberration_center_weight,
		1.0,
		pow(clamp(edge_dist, 0.0, 1.35), aberration_edge_power)
	);

	// Horizontal convergence shift + outward radial fringing toward screen edges
	float base_shift_px = aberration_offset * edge_factor;
	float radial_dir = centered.x * 0.65 + (centered.x >= 0.0 ? 0.35 : -0.35);
	vec2 shift = vec2(base_shift_px * radial_dir * pixel_size.x, centered.y * base_shift_px * 0.14 * pixel_size.y);

	// Edge blur & horizontal color bleeding that intensifies toward the screen edges
	float blur_px = edge_blur_radius * color_bleed_strength * edge_factor;
	vec2 bleed_step = vec2(blur_px * pixel_size.x, 0.0);

	vec2 uv_r = clamp(uv + shift, vec2(0.001), vec2(0.999));
	vec2 uv_g = clamp(uv, vec2(0.001), vec2(0.999));
	vec2 uv_b = clamp(uv - shift, vec2(0.001), vec2(0.999));

	float r_center = texture(screen_texture, uv_r).r;
	float r_left = texture(screen_texture, clamp(uv_r - bleed_step, vec2(0.001), vec2(0.999))).r;
	float r_right = texture(screen_texture, clamp(uv_r + bleed_step * 1.3, vec2(0.001), vec2(0.999))).r;
	float r = mix(r_center, 0.44 * r_center + 0.24 * r_left + 0.32 * r_right, color_bleed_strength);

	float g_center = texture(screen_texture, uv_g).g;
	float g_left = texture(screen_texture, clamp(uv_g - bleed_step * 0.55, vec2(0.001), vec2(0.999))).g;
	float g_right = texture(screen_texture, clamp(uv_g + bleed_step * 0.55, vec2(0.001), vec2(0.999))).g;
	float g = mix(g_center, 0.62 * g_center + 0.19 * g_left + 0.19 * g_right, color_bleed_strength * 0.7);

	float b_center = texture(screen_texture, uv_b).b;
	float b_left = texture(screen_texture, clamp(uv_b - bleed_step * 1.3, vec2(0.001), vec2(0.999))).b;
	float b_right = texture(screen_texture, clamp(uv_b + bleed_step, vec2(0.001), vec2(0.999))).b;
	float b = mix(b_center, 0.44 * b_center + 0.32 * b_left + 0.24 * b_right, color_bleed_strength);

	return vec3(r, g, b);
}

vec3 compute_bloom(vec2 uv, vec2 pixel_size) {
	if (bloom_intensity <= 0.001) {
		return vec3(0.0);
	}

	vec2 step_uv = pixel_size * bloom_radius;
	vec2 offsets[12] = vec2[12](
		vec2(-1.0,  0.0),
		vec2( 1.0,  0.0),
		vec2( 0.0, -1.0),
		vec2( 0.0,  1.0),
		vec2(-0.75, -0.75),
		vec2( 0.75, -0.75),
		vec2(-0.75,  0.75),
		vec2( 0.75,  0.75),
		vec2(-2.2,  0.0),
		vec2( 2.2,  0.0),
		vec2( 0.0, -2.0),
		vec2( 0.0,  2.0)
	);
	float weights[12] = float[12](
		0.13, 0.13, 0.11, 0.11,
		0.08, 0.08, 0.08, 0.08,
		0.06, 0.06, 0.04, 0.04
	);

	vec3 accum = vec3(0.0);
	float low = bloom_threshold - bloom_soft_knee;
	float high = bloom_threshold + bloom_soft_knee;

	for (int i = 0; i < 12; i++) {
		vec2 sample_uv = clamp(uv + offsets[i] * step_uv, vec2(0.001), vec2(0.999));
		vec3 sample_col = texture(screen_texture, sample_uv).rgb;
		float peak = max(crt_luma(sample_col), max(sample_col.r, max(sample_col.g, sample_col.b)));
		float extract = smoothstep(low, high, peak);
		accum += sample_col * extract * weights[i];
	}

	return accum * bloom_intensity;
}

float compute_scanline_wave(vec2 curved_uv, vec2 frag_coord, vec2 screen_size) {
	float y_norm = mix(frag_coord.y / max(1.0, screen_size.y), curved_uv.y, scanline_curvature_follow);
	float lines = max(16.0, scanline_count * scanline_density);
	float phase = (y_norm * lines + TIME * scanline_scroll_speed) * PI * 2.0;
	float wave = 0.5 + 0.5 * cos(phase);
	return pow(clamp(wave, 0.0, 1.0), scanline_sharpness);
}

vec3 compute_shadow_mask(vec2 frag_coord, float luma) {
	if (mask_intensity <= 0.001) {
		return vec3(1.0);
	}

	vec2 scaled = frag_coord / max(0.25, mask_scale);
	// Staggered slot offset on alternate cell rows when shadow-mask grid is active
	float cell_row = floor(scaled.y / 2.0);
	float stagger = mod(cell_row, 2.0) * 1.5 * mask_grid_strength;
	float subpixel = mod(floor(scaled.x + stagger), 3.0);

	// Subpixel RGB phosphor triad weights that stay <= 1.0 on non-active channels
	// so bright white/cyan areas clearly display the RGB mask without clipping to flat white
	vec3 aperture_grille;
	if (subpixel < 1.0) {
		aperture_grille = vec3(1.08, 0.72, 0.62);
	} else if (subpixel < 2.0) {
		aperture_grille = vec3(0.62, 1.08, 0.72);
	} else {
		aperture_grille = vec3(0.72, 0.62, 1.08);
	}

	// Horizontal slot mask grid modulation
	float slot_wave = 0.5 + 0.5 * cos(scaled.y * PI);
	float grid_factor = mix(1.0, mix(0.68, 1.04, slot_wave), mask_grid_strength);
	vec3 mask_pattern = aperture_grille * grid_factor;

	// Subtle on dark areas, distinctly visible on bright areas
	float luma_curve = smoothstep(0.08, 0.78, luma);
	float luma_weight = mix(1.0 - mask_bright_boost * 0.75, 1.0, luma_curve);
	float effective_strength = clamp(mask_intensity * luma_weight, 0.0, 1.0);
	return mix(vec3(1.0), mask_pattern, effective_strength);
}

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = screen_size.x / max(1.0, screen_size.y);

	// 1. Barrel distortion (Curvature)
	vec2 curved_uv = warp_crt_uv(SCREEN_UV);

	// 2. Rounded corners & bezel SDF
	float bezel_sdf = compute_rounded_bezel_sdf(curved_uv, aspect);
	float tube_mask = 1.0 - smoothstep(-corner_smoothness, corner_smoothness, bezel_sdf);

	if (tube_mask <= 0.001) {
		COLOR = vec4(bezel_color.rgb, 1.0);
	} else {
		// 5. Chromatic Aberration + edge color bleeding
		vec3 base_color = sample_chromatic_bleed(curved_uv, SCREEN_PIXEL_SIZE);

		// 6. Bloom / Glow
		vec3 bloom_glow = compute_bloom(curved_uv, SCREEN_PIXEL_SIZE);

		// Combine base color, brightness boost, and pre-scanline bloom, then clamp shoulder
		// so scanlines and RGB shadow mask remain crisp even on pure white areas
		vec3 lit_color = clamp(base_color * brightness_boost + bloom_glow * 0.65, 0.0, 1.0);
		float luma = crt_luma(lit_color);

		// 3. Scanlines (alternating dark inter-line gaps and bright phosphor lines)
		float scan_wave = compute_scanline_wave(curved_uv, FRAGCOORD.xy, screen_size);
		float scan_min = 1.0 - scanline_opacity;
		float scan_max = 1.0 + scanline_brightness_boost * scanline_opacity;
		float scanline_factor = mix(scan_min, scan_max, scan_wave);
		vec3 color = lit_color * scanline_factor;

		// Add soft post-scanline phosphor halation glow
		color = clamp(color + bloom_glow * 0.30, 0.0, 1.0);

		// 4. Shadow Mask / Trinitron RGB Grid (subtle in darks, distinct on bright areas)
		vec3 mask = compute_shadow_mask(FRAGCOORD.xy, luma);
		color *= mask;

		// 2. Smooth CRT edge vignette
		float vignette = compute_vignette(curved_uv);
		color *= vignette;

		// Subtle glass bezel inner rim highlight
		float rim = exp(-abs(bezel_sdf) * 85.0) * bezel_reflection;
		color += vec3(rim * 0.75, rim * 0.82, rim * 0.95);

		vec3 final_rgb = mix(bezel_color.rgb, color, tube_mask);
		COLOR = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
	}
}
