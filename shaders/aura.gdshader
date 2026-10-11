shader_type spatial;
// Frost Aura on the ground: a bright rim, slowly turning frost spokes and
// drifting rings. `pulse` is kicked to 1 by the player script on every damage
// tick and decays, so the hits read on screen.
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
	float rim = exp(-pow((d - 0.96) * 22.0, 2.0));
	float spokes = pow(abs(cos(ang * 3.0 + TIME * 0.4)), 60.0) * smoothstep(1.0, 0.25, d) * 0.35;
	float waves = (0.5 + 0.5 * sin(d * 18.0 - TIME * 3.0)) * d * d * 0.18;
	float wash = 0.06 + pulse * 0.35 * (1.0 - d * 0.5);
	ALBEDO = color.rgb;
	ALPHA = color.a * (rim + spokes + waves + wash) * friendly_opacity;
}
