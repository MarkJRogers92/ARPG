shader_type canvas_item;
// Cheap full-screen grade, drawn under the HUD: split-toning (cool shadows,
// warm highlights), a soft painterly edge falloff in the realm's air colour,
// and a whisper of film grain. One screen-texture read, no loops.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform vec3 shadow_tint : source_color = vec3(0.5, 0.6, 0.8);
uniform vec3 highlight_tint : source_color = vec3(1.0, 0.9, 0.8);
uniform float split = 0.5;
uniform vec3 edge_color : source_color = vec3(0.02, 0.03, 0.05);
uniform float edge = 0.35;
uniform float grain = 0.025;
uniform float lift = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(443.897, 441.423));
	p += dot(p, p.yx + 19.19);
	return fract((p.x + p.y) * p.x);
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	// Split-toning: push shadows toward the cool tint, highlights toward the warm.
	vec3 sh = mix(vec3(1.0), shadow_tint * 1.6, split * (1.0 - smoothstep(0.0, 0.45, l)));
	vec3 hi = mix(vec3(1.0), highlight_tint * 1.15, split * smoothstep(0.35, 0.95, l));
	c *= sh * hi;
	c += shadow_tint * lift * (1.0 - l);
	// Soft, uneven edge falloff into the air colour (painted, not a hard oval).
	vec2 p = (SCREEN_UV - 0.5) * vec2(1.25, 1.0);
	float d = length(p);
	float v = smoothstep(0.38, 0.98, d);
	v *= v * (3.0 - 2.0 * v) * 0.5 + 0.5 * v;
	c = mix(c, edge_color + c * 0.35, v * edge);
	// Grain, strongest in the mid-tones, animated slowly.
	float g = hash(floor(FRAGCOORD.xy) + floor(TIME * 12.0) * 7.31) - 0.5;
	c += g * grain * (1.0 - abs(l - 0.4));
	COLOR = vec4(c, 1.0);
}
