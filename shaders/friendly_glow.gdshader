shader_type spatial;
// Friendly-only copy of glow.gdshader for the hero's bolts (ProjectileSwarm)
// that carries the "Friendly spell opacity" uniform. A separate shader and
// material instance keep the shared hostile/hazard glow (Models.material("glow"))
// completely untouched: only the hero's own additive glows fade.
// COLOR is the mesh color times the instance color; its alpha scales the glow,
// and edges fade out softly.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float intensity = 1.6;
uniform float edge_softness = 1.5;
// Set by Juice (never below FRIENDLY_OPACITY_MIN). 1.0 is the untouched look.
uniform float friendly_opacity = 1.0;

void fragment() {
	float facing = abs(dot(NORMAL, VIEW));
	ALBEDO = COLOR.rgb * intensity;
	ALPHA = COLOR.a * pow(facing, edge_softness) * friendly_opacity;
}
