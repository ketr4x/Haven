shader_type canvas_item;
render_mode unshaded;

uniform float inner_radius : hint_range(0.05, 0.8) = 0.165;
uniform float outer_radius : hint_range(0.1, 1.4) = 0.465;
uniform float darkness_alpha : hint_range(0.0, 1.0) = 0.68;
uniform float aspect_ratio = 3.5754;
uniform float block_size : hint_range(2.0, 32.0) = 3.0;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

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
	vec2 viewport_size = 1.0 / TEXTURE_PIXEL_SIZE;
	if (viewport_size.x <= 4.0) {
		viewport_size = vec2(1280.0, 358.0);
	}
	ivec2 cell = ivec2(floor(UV * viewport_size / block_size));
	vec2 cell_uv = (vec2(cell) + vec2(0.5)) * block_size / viewport_size;

	vec2 centered = cell_uv - vec2(0.5, 0.5);
	centered.x *= aspect_ratio * 0.48;
	float dist = length(centered);

	float raw_vignette = clamp((dist - inner_radius) / max(0.001, outer_radius - inner_radius), 0.0, 1.0);
	float quantized_vignette = floor(raw_vignette * 5.0) / 5.0;
	float dither = bayer4x4(cell);

	float pixel_mask = step(dither, raw_vignette);
	float alpha = mix(quantized_vignette, pixel_mask, 0.55) * darkness_alpha;
	if (dist >= outer_radius) {
		alpha = darkness_alpha;
	} else if (dist <= inner_radius) {
		alpha = 0.0;
	}

	COLOR = vec4(vignette_color.rgb, clamp(alpha, 0.0, 1.0));
}
