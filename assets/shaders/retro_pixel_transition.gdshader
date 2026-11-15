shader_type canvas_item;
render_mode unshaded;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float block_size : hint_range(1.0, 64.0) = 8.0;
uniform vec4 transition_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

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
	if (progress <= 0.001) {
		COLOR = vec4(transition_color.rgb, 0.0);
	} else if (progress >= 0.999) {
		COLOR = vec4(transition_color.rgb, 1.0);
	} else {
		vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
		ivec2 cell = ivec2(floor(UV * screen_size / block_size));
		float dither = bayer4x4(cell);

		vec2 centered_uv = abs(UV - vec2(0.5)) * 2.0;
		float edge_bias = max(centered_uv.x, centered_uv.y) * 0.35;
		float cutoff = clamp(dither * 0.65 + (1.0 - edge_bias) * 0.35, 0.0, 1.0);

		float alpha = step(cutoff, progress);
		COLOR = vec4(transition_color.rgb, alpha);
	}
}
