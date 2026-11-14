shader_type canvas_item;

uniform vec4 ring_color : source_color = vec4(0.52, 0.92, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.17, 0.78, 1.0, 0.38);

void fragment() {
	float radius = length(UV - vec2(0.5)) * 2.0;
	float glow = smoothstep(0.52, 0.72, radius) * (1.0 - smoothstep(0.84, 1.0, radius));
	float ring = smoothstep(0.72, 0.82, radius) * (1.0 - smoothstep(0.88, 0.98, radius));
	vec3 color = glow_color.rgb * glow + ring_color.rgb * ring;
	float alpha = max(glow * glow_color.a, ring * ring_color.a);
	COLOR = vec4(color, alpha);
}
