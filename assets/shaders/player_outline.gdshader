shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.27451, 0.290196, 0.45098, 1.0);
uniform float outline_width : hint_range(0.0, 4.0) = 1.0;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (base.a > 0.1) {
		vec4 sprite_col = base * COLOR;
		COLOR = mix(sprite_col, vec4(1.0, 1.0, 1.0, sprite_col.a), flash_amount);
	} else {
		vec2 px = TEXTURE_PIXEL_SIZE * outline_width;
		float neighbor_alpha = 0.0;
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(-px.x, 0.0)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(0.0, -px.y)).a);
		if (neighbor_alpha > 0.1) {
			COLOR = outline_color;
		} else {
			COLOR = vec4(0.0);
		}
	}
}
