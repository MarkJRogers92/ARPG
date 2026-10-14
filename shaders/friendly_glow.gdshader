shader_type spatial;
// Friendly-only glow for the hero's bolts (ProjectileSwarm) that carries the
// "Friendly spell opacity" uniform. A separate shader and material instance
// keep the shared hostile/hazard glow (Models.material("glow")) completely
// untouched: only the hero's own additive glows fade.
// COLOR is the mesh color times the instance color; its alpha scales the glow.
// The bolt points down -Z and trails toward +Z: the trail tapers to nothing,
// the head is white-hot, and edges fade out softly.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float intensity = 1.6;
uniform float edge_softness = 1.5;
// Set by Juice (never below FRIENDLY_OPACITY_MIN). 1.0 is the untouched look.
uniform float friendly_opacity = 1.0;

varying float v_z;

void vertex() {
	v_z = VERTEX.z;
}

void fragment() {
	float facing = abs(dot(NORMAL, VIEW));
	float tail = clamp((v_z - 0.1) / 1.1, 0.0, 1.0);
	float taper = 1.0 - tail * tail;
	// The opaque head part (alpha ~1) is pushed toward white.
	float head = smoothstep(0.6, 1.0, COLOR.a);
	vec3 rgb = mix(COLOR.rgb, vec3(1.0), head * 0.5) * intensity;
	ALBEDO = rgb * (1.0 + 0.5 * (1.0 - tail));
	ALPHA = COLOR.a * pow(facing, edge_softness) * mix(1.0, taper, step(0.0, v_z - 0.1)) * friendly_opacity;
}
