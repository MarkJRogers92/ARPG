shader_type spatial;
// A circular ivory hero locator versus small hollow cyan ally diamonds.
// Markers respect depth and never show actors through solid scenery.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform bool hero = false;
varying float rank;

void vertex() {
	rank = INSTANCE_CUSTOM.z;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = hero ? length(p) : abs(p.x) + abs(p.y);
	float edge = abs(d - 0.82);
	float ink = 1.0 - smoothstep(0.075, 0.105, edge);
	float core = 1.0 - smoothstep(0.025, 0.05, edge);
	vec3 tint = hero ? vec3(1.0, 0.88, 0.58) : mix(vec3(0.35, 0.9, 1.0), vec3(1.0, 0.76, 0.32), step(0.01, rank));
	ALBEDO = mix(vec3(0.02, 0.035, 0.045), tint, core);
	ALPHA = ink * (hero ? 0.95 : 0.72);
}
