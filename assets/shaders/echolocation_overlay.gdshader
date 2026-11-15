shader_type canvas_item;

const int MAX_ECHO_HITS = 48;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform int echo_hit_count = 0;
uniform vec4 echo_hits[MAX_ECHO_HITS];
uniform vec2 echo_normals[MAX_ECHO_HITS];
uniform vec4 afterglow_color : source_color = vec4(0.72, 0.96, 1.0, 1.0);

void fragment() {
	// Terrain is always taken directly from the rendered scene. Echoes only add light.
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	vec3 glow = vec3(0.0);

	for (int index = 0; index < MAX_ECHO_HITS; index++) {
		if (index >= echo_hit_count) {
			break;
		}
		vec4 hit = echo_hits[index];
		vec2 normal = normalize(echo_normals[index] + vec2(0.0001));
		vec2 tangent = vec2(-normal.y, normal.x);
		vec2 delta_pixels = (UV - hit.xy) * viewport_size;
		float reached_area = 0.0;
		if (hit.z < 0.0) {
			float tile_extent = abs(hit.z) * 0.5 + 4.0;
			float tile_distance = max(abs(delta_pixels.x), abs(delta_pixels.y));
			reached_area = 1.0 - step(tile_extent, tile_distance);
		} else {
			float tangent_distance = dot(delta_pixels, tangent) / max(hit.z * 1.85, 1.0);
			float normal_distance = dot(delta_pixels, normal) / max(hit.z * 0.62, 1.0);
			float ellipse = length(vec2(tangent_distance, normal_distance));
			reached_area = 1.0 - step(1.0, ellipse);
		}
		glow = max(glow, afterglow_color.rgb * reached_area * hit.w);
	}

	COLOR = vec4(min(source + glow, vec3(1.0)), 1.0);
}
