shader_type canvas_item;
render_mode unshaded;

uniform vec4 field_color : source_color = vec4(0.42, 0.86, 1.0, 0.22);
uniform vec4 edge_color : source_color = vec4(0.78, 0.96, 1.0, 0.92);
uniform vec2 field_size = vec2(48.0, 96.0);
uniform float resonance_pulse : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 px = UV * field_size;
	float dist_x = min(px.x, field_size.x - px.x);
	float dist_y = min(px.y, field_size.y - px.y);
	float edge_dist = min(dist_x, dist_y);

	float hard_border = 1.0 - smoothstep(1.2, 2.8, edge_dist);
	float inner_glow = 1.0 - smoothstep(0.0, 10.0, edge_dist);

	float scan_band = 0.5 + 0.5 * sin(px.y * 0.55 - TIME * 5.4);
	float diag_shimmer = 0.5 + 0.5 * sin((px.x + px.y) * 0.28 + TIME * 3.6);
	float lattice = step(0.82, sin(px.x * 0.45) * sin(px.y * 0.45 - TIME * 1.8));
	float pulse_wave = 0.5 + 0.5 * sin(px.y * 0.42 - TIME * 18.0);

	float energy = 0.50 + 0.25 * scan_band + 0.20 * diag_shimmer + 0.16 * lattice;
	energy += resonance_pulse * (0.75 + 0.45 * pulse_wave);

	vec3 rgb = mix(
		field_color.rgb,
		edge_color.rgb,
		clamp(inner_glow * 0.65 + hard_border * 0.95 + resonance_pulse * 0.55, 0.0, 1.0)
	);
	float alpha = field_color.a * energy + inner_glow * 0.20 + hard_border * 0.60 + resonance_pulse * 0.30;
	COLOR = vec4(rgb, clamp(alpha, 0.0, 0.95));
}
