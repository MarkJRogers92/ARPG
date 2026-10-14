shader_type spatial;
// Frost Aura on the ground: a subtle swirling frost ring. A bright thin rim,
// an inner ring of slowly turning dashes and two soft spiral arms of frost
// drifting inward; the middle stays almost clear so the horde reads through
// it. `pulse` is kicked to 1 by the player script on every damage tick and
// decays, so the hits read on screen.
//
// Friendly-only by construction (the hero's AuraVisual is the only user), so
// it carries `friendly_opacity` for the "Friendly spell opacity" setting.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(0.45, 0.8, 1.0, 0.6);
uniform float pulse = 0.0;
// Set by Juice (never below FRIENDLY_OPACITY_MIN). 1.0 is the untouched look.
uniform float friendly_opacity = 1.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	if (d > 1.0) {
		discard;
	}
	float ang = atan(p.y, p.x);
	// Rim: crisp core with a soft halo inside it.
	float rim = exp(-pow((d - 0.96) * 30.0, 2.0)) + exp(-pow((d - 0.92) * 14.0, 2.0)) * 0.1;
	// Frost spirals: two arms winding inward, brighter toward the edge.
	float arm = 0.5 + 0.5 * sin(ang * 2.0 - d * 7.0 + TIME * 0.55);
	arm = pow(arm, 3.0) * smoothstep(0.3, 0.95, d) * 0.2;
	// Turning dashes on an inner ring.
	float dash = smoothstep(0.55, 0.9, sin(ang * 14.0 - TIME * 0.7)) * exp(-pow((d - 0.8) * 26.0, 2.0)) * 0.75;
	// Fine crystalline sparkle riding the arms.
	float sp = pow(max(0.0, sin(ang * 23.0 + d * 41.0 - TIME * 1.3)), 24.0) * smoothstep(0.35, 0.9, d) * 0.3;
	float wash = 0.0 + pulse * 0.05 * (1.0 - d * 0.6);
	float shape = rim + arm + dash + sp + wash;
	ALBEDO = mix(color.rgb, vec3(0.85, 0.97, 1.0), rim * 0.5);
	ALPHA = clamp(color.a * shape, 0.0, 1.0) * friendly_opacity;
}
