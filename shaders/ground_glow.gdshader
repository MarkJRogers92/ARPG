shader_type spatial;
// A glow painted on the ground (under loot, under the hero). `ring` blends
// from a soft disc (0) to a thin ring (1).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 0.5);
uniform float ring = 0.0;
uniform float pulse_speed = 3.0;

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float disc = smoothstep(1.0, 0.0, d);
	float r = smoothstep(0.14, 0.0, abs(d - 0.82)) + disc * disc * 0.25;
	float pulse = 0.82 + 0.18 * sin(TIME * pulse_speed);
	ALBEDO = color.rgb;
	ALPHA = color.a * mix(disc * disc, r, ring) * pulse;
}
