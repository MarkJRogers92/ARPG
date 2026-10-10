shader_type spatial;
// Depth-tested, steady danger ink. Unlike additive loot/ally glows, a dark
// keyline is readable on snow, pale paving and bright lava. No strobing.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.35, 0.12, 0.85);
uniform float ring = 1.0;
uniform bool strip = false;

void fragment() {
	float ink;
	float stroke;
	if (strip) {
		float edge = min(UV.x, 1.0 - UV.x);
		ink = 1.0;
		stroke = smoothstep(0.025, 0.075, edge);
		// Repeated transverse notches communicate danger without relying on hue.
		float notch = step(0.78, fract(UV.y * 8.0));
		stroke *= mix(1.0, 0.35, notch);
	} else {
		float d = length(UV - 0.5) * 2.0;
		// Keep the established 0.82 outline radius and all caller sizes intact.
		float outline = 1.0 - smoothstep(0.075, 0.11, abs(d - 0.82));
		float core = 1.0 - smoothstep(0.025, 0.05, abs(d - 0.82));
		float disc = smoothstep(1.0, 0.0, d);
		ink = mix(disc * disc, outline, ring);
		stroke = mix(0.7, core, ring);
	}
	ALBEDO = mix(vec3(0.018, 0.022, 0.03), color.rgb, stroke);
	ALPHA = color.a * ink;
}
