shader_type canvas_item;

const int MAX_ECHO_HITS = 48;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 viewport_size = vec2(1280.0, 360.0);
uniform vec2 source_uv = vec2(0.5);
uniform float floor_band_offset = 18.0;
uniform float floor_band_half_height = 7.0;
uniform float edge_threshold : hint_range(0.001, 0.2) = 0.02;
uniform int echo_hit_count = 0;
uniform vec4 echo_hits[MAX_ECHO_HITS];
uniform vec2 echo_normals[MAX_ECHO_HITS];
uniform vec4 player_color : source_color = vec4(1.0);
uniform vec4 background_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 dim_floor_color : source_color = vec4(0.32, 0.32, 0.32, 1.0);
uniform vec4 echo_edge_color : source_color = vec4(0.95, 0.95, 0.95, 1.0);

float brightness(vec3 color) {
	return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	vec2 pixel = 1.0 / viewport_size;
	float source_brightness = brightness(source);
	float horizontal_delta = brightness(texture(screen_texture, SCREEN_UV + vec2(pixel.x, 0.0)).rgb)
		- source_brightness;
	float vertical_delta = brightness(texture(screen_texture, SCREEN_UV + vec2(0.0, pixel.y)).rgb)
		- source_brightness;
	float edge = step(edge_threshold, length(vec2(horizontal_delta, vertical_delta)));

	// Reveal top walkable floor surfaces across the viewport while keeping walls and seams hidden.
	float above_1 = brightness(texture(screen_texture, SCREEN_UV - vec2(0.0, pixel.y)).rgb);
	float above_2 = brightness(texture(screen_texture, SCREEN_UV - vec2(0.0, pixel.y * 2.0)).rgb);
	float above_3 = brightness(texture(screen_texture, SCREEN_UV - vec2(0.0, pixel.y * 3.0)).rgb);
	float floor_surface = step(0.09, source_brightness) * (1.0 - step(0.09, min(above_1, min(above_2, above_3))));
	float echo_reveal = 0.0;

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
		echo_reveal = max(echo_reveal, reached_area * hit.w);
	}

	vec3 base_color = mix(background_color.rgb, dim_floor_color.rgb, floor_surface);
	float visible_edge = max(edge, floor_surface);
	vec3 lit_color = mix(base_color, echo_edge_color.rgb, echo_reveal);
	vec3 result = mix(base_color, lit_color, visible_edge * step(0.01, echo_reveal));
	float player_pixel = 1.0 - step(0.14, distance(source, player_color.rgb));
	result = mix(result, source, player_pixel);
	COLOR = vec4(result, 1.0);
}
