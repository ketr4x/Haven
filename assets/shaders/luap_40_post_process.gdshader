shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D palette_texture : source_color, repeat_disable, filter_nearest;

const int PALETTE_SIZE = 40;

void fragment() {
	vec4 source = texture(screen_texture, SCREEN_UV);
	vec3 nearest_color = texture(palette_texture, vec2(0.5 / float(PALETTE_SIZE), 0.5)).rgb;
	vec3 difference = source.rgb - nearest_color;
	float nearest_distance = dot(difference, difference);

	for (int index = 1; index < PALETTE_SIZE; index++) {
		vec2 palette_uv = vec2((float(index) + 0.5) / float(PALETTE_SIZE), 0.5);
		vec3 candidate = texture(palette_texture, palette_uv).rgb;
		difference = source.rgb - candidate;
		float candidate_distance = dot(difference, difference);
		if (candidate_distance < nearest_distance) {
			nearest_color = candidate;
			nearest_distance = candidate_distance;
		}
	}

	COLOR = vec4(nearest_color, source.a);
}
