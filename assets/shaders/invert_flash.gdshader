shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 screen_col = texture(screen_texture, SCREEN_UV);
	vec3 inverted = vec3(1.0) - screen_col.rgb;
	COLOR = vec4(mix(screen_col.rgb, inverted, intensity), 1.0);
}
