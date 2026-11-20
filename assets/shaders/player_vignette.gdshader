shader_type canvas_item;
render_mode unshaded;

uniform float inner_radius : hint_range(0.05, 0.8) = 0.165;
uniform float outer_radius : hint_range(0.1, 1.4) = 0.465;
uniform float darkness_alpha : hint_range(0.0, 1.0) = 0.68;
uniform float silence_dim : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_glow : hint_range(0.0, 1.0) = 0.0;
uniform vec2 viewport_size_px = vec2(1280.0, 358.0);
uniform float reference_height_px = 358.0;
uniform float vertical_mask_enabled : hint_range(0.0, 1.0) = 0.0;
uniform float vertical_mask_inner : hint_range(0.2, 0.5) = 0.42;
uniform float vertical_mask_outer : hint_range(0.25, 0.5) = 0.5;
uniform float block_size : hint_range(2.0, 32.0) = 3.0;
uniform vec4 vignette_color : source_color = vec4(0.06, 0.075, 0.13, 1.0);

float bayer4x4(ivec2 pos) {
	int x = pos.x & 3;
	int y = pos.y & 3;
	int index = x + y * 4;
	float matrix[16] = float[16](
		 0.0,  8.0,  2.0, 10.0,
		12.0,  4.0, 14.0,  6.0,
		 3.0, 11.0,  1.0,  9.0,
		15.0,  7.0, 13.0,  5.0
	);
	return (matrix[index] + 0.5) / 16.0;
}

void fragment() {
	vec2 viewport_size = viewport_size_px;
	if (viewport_size.x <= 4.0 || viewport_size.y <= 4.0) {
		viewport_size = vec2(1280.0, 358.0);
	}
	float ref_height = max(1.0, reference_height_px);

	ivec2 cell = ivec2(floor(UV * viewport_size / block_size));
	vec2 cell_uv = (vec2(cell) + vec2(0.5)) * block_size / viewport_size;

	// Scale offsets by the split-screen reference height so singleplayer matches 2P radial visibility.
	vec2 px_from_center = (cell_uv - vec2(0.5, 0.5)) * viewport_size;
	vec2 scaled = vec2(px_from_center.x * 0.48, px_from_center.y) / ref_height;
	float dist = length(scaled);

	float raw_vignette = clamp((dist - inner_radius) / max(0.001, outer_radius - inner_radius), 0.0, 1.0);
	float quantized_vignette = floor(raw_vignette * 5.0) / 5.0;
	float dither = bayer4x4(cell);

	float effective_darkness = clamp(darkness_alpha + silence_dim * 0.14, 0.0, 0.86);
	float pixel_mask = step(dither, raw_vignette);
	float alpha = mix(quantized_vignette, pixel_mask, 0.55) * effective_darkness;
	if (dist >= outer_radius) {
		alpha = effective_darkness;
	} else if (dist <= inner_radius) {
		alpha = 0.0;
	}

	vec3 quiet_tint = mix(vignette_color.rgb, vec3(0.032, 0.042, 0.09), silence_dim * 0.65);
	float rim_band = smoothstep(0.0, 0.45, raw_vignette) * (1.0 - smoothstep(0.45, 0.95, raw_vignette));
	vec3 final_rgb = mix(quiet_tint, vec3(0.22, 0.52, 0.68), rim_band * pulse_glow * 0.42);

	if (vertical_mask_enabled > 0.5) {
		// Soft Bayer-dithered curtain reaching 100% opacity at the exact 2P split-screen vertical limit.
		float abs_y = abs(scaled.y);
		float raw_curtain = clamp((abs_y - vertical_mask_inner) / max(0.001, vertical_mask_outer - vertical_mask_inner), 0.0, 1.0);
		float quantized_curtain = floor(raw_curtain * 5.0) / 5.0;
		float curtain_dither = step(dither, raw_curtain);
		float curtain_alpha = mix(quantized_curtain, curtain_dither, 0.55);
		if (abs_y >= vertical_mask_outer) {
			curtain_alpha = 1.0;
		} else if (abs_y <= vertical_mask_inner) {
			curtain_alpha = 0.0;
		}
		alpha = max(alpha, curtain_alpha);
		final_rgb = mix(final_rgb, quiet_tint, curtain_alpha);
	}

	COLOR = vec4(final_rgb, clamp(alpha, 0.0, 1.0));
}
