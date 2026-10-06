shader_type spatial;
// The light pillar over good loot: bright at the bottom, fading upward,
// softly shimmering.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.8, 0.3, 0.6);
uniform float height = 6.0;

varying float v_h;

void vertex() {
	v_h = clamp(VERTEX.y / height + 0.5, 0.0, 1.0);
}

void fragment() {
	float facing = abs(dot(NORMAL, VIEW));
	float shimmer = 0.85 + 0.15 * sin(TIME * 4.0 - v_h * 12.0);
	ALBEDO = color.rgb * 1.6;
	ALPHA = color.a * pow(1.0 - v_h, 1.6) * facing * facing * shimmer;
}
