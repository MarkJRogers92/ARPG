shader_type spatial;
// Additive glow volumes (bolts, sparks). COLOR is the mesh color times the
// instance color; its alpha scales the glow, and edges fade out softly.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float intensity = 1.6;
uniform float edge_softness = 1.5;

void fragment() {
	float facing = abs(dot(NORMAL, VIEW));
	ALBEDO = COLOR.rgb * intensity;
	ALPHA = COLOR.a * pow(facing, edge_softness);
}
