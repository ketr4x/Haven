shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D palette_lut : source_color, repeat_disable, filter_nearest;

const int LUT_SIZE = 32;
const int LUT_WIDTH = LUT_SIZE * LUT_SIZE;

void fragment() {
	vec4 source = texture(screen_texture, SCREEN_UV);
	ivec3 color_index = ivec3(round(clamp(source.rgb, 0.0, 1.0) * float(LUT_SIZE - 1)));

	// Red and blue share the horizontal axis; green selects the LUT row.
	int lookup_x = color_index.r + color_index.b * LUT_SIZE;
	vec2 lookup_uv = vec2(
		(float(lookup_x) + 0.5) / float(LUT_WIDTH),
		(float(color_index.g) + 0.5) / float(LUT_SIZE)
	);

	COLOR = vec4(texture(palette_lut, lookup_uv).rgb, source.a);
}
