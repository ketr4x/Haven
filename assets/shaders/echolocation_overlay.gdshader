shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float reveal_radius : hint_range(0.0, 1.0) = 0.0;
uniform float reveal_strength : hint_range(0.0, 1.0) = 0.0;
uniform float aspect_ratio = 1.7777778;

float brightness(vec3 color) {
	return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec2 point = vec2(UV.x * aspect_ratio, UV.y);
	vec2 center = vec2(0.5 * aspect_ratio, 0.5);
	float distance_to_center = distance(point, center);
	float echo_area = 1.0 - smoothstep(reveal_radius * 0.72, reveal_radius, distance_to_center);

	vec2 pixel = SCREEN_PIXEL_SIZE;
	float horizontal = brightness(texture(screen_texture, SCREEN_UV + vec2(pixel.x, 0.0)).rgb) - brightness(texture(screen_texture, SCREEN_UV - vec2(pixel.x, 0.0)).rgb);
	float vertical = brightness(texture(screen_texture, SCREEN_UV + vec2(0.0, pixel.y)).rgb) - brightness(texture(screen_texture, SCREEN_UV - vec2(0.0, pixel.y)).rgb);
	float edge = smoothstep(0.004, 0.06, length(vec2(horizontal, vertical)));

	vec3 edge_color = mix(vec3(0.15, 0.72, 1.0), vec3(0.9, 0.97, 1.0), edge);
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	float signal_pixel = step(0.72, source.b) * step(0.52, source.g);
	vec3 echo = edge_color * edge * echo_area * reveal_strength;
	echo = max(echo, source * signal_pixel);
	float reveal_alpha = 1.0 - echo_area * reveal_strength * 0.9;
	COLOR = vec4(echo, reveal_alpha);
}
