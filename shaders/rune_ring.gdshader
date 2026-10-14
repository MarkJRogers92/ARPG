shader_type spatial;
// A painted rune circle on the ground (loot, power-ups, pickups): a soft wash,
// a bright thin outer ring, an inner ring and a band of carved glyph ticks that
// turns slowly. `flourish` (0..1) adds a counter-turning crown of gold rays
// and drifting embers for legendary drops. Not used by hostile telegraphs.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 0.5);
uniform float flourish = 0.0;
uniform float pulse_speed = 2.0;
uniform float glyphs = 10.0;
uniform vec3 hot_color : source_color = vec3(1.0, 0.82, 0.4);

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	if (d > 1.0) {
		discard;
	}
	float ang = atan(p.y, p.x) / 6.2831853 + 0.5;
	float pulse = 0.85 + 0.15 * sin(TIME * pulse_speed);
	float wash = smoothstep(0.9, 0.0, d);
	wash = wash * wash * 0.22;
	float outer = exp(-pow((d - 0.88) * 38.0, 2.0));
	float inner = exp(-pow((d - 0.66) * 46.0, 2.0)) * 0.55;
	// Glyph ticks between the rings: each sector gets or skips a short carved bar.
	float a = ang * glyphs + TIME * 0.12;
	float id = floor(a);
	float f = fract(a) - 0.5;
	float on = step(0.3, hash(id + 3.0));
	float len = 0.1 + 0.1 * hash(id + 9.0);
	float bar = smoothstep(0.1, 0.03, abs(f)) * smoothstep(len + 0.03, len - 0.03, abs(d - 0.77));
	bar *= on * 0.8;
	// Four cardinal studs on the outer ring.
	float stud = smoothstep(0.06, 0.0, abs(fract(ang * 4.0 + 0.5) - 0.5) * 1.5708 * d) * exp(-pow((d - 0.88) * 14.0, 2.0)) * 0.6;
	float shape = (outer + inner + bar + stud) * pulse + wash;
	vec3 rgb = color.rgb * (1.0 + outer * 0.5);
	float alpha = color.a;
	if (flourish > 0.0) {
		float b = ang * 16.0 - TIME * 0.2;
		float ray = pow(abs(cos(b * 3.14159)), 18.0) * smoothstep(0.52, 0.98, d) * smoothstep(1.0, 0.9, d);
		float ember = step(0.7, hash(floor(ang * 40.0) + floor(TIME * 1.5 + hash(floor(ang * 40.0)) * 4.0) * 3.0))
				* exp(-pow((d - (0.4 + 0.5 * fract(TIME * 0.4 + hash(floor(ang * 40.0))))) * 14.0, 2.0)) * 0.7;
		shape += flourish * (ray * 0.9 + ember);
		rgb = mix(rgb, hot_color * 1.3, flourish * clamp(ray + ember + outer * 0.4, 0.0, 1.0));
	}
	ALBEDO = rgb;
	ALPHA = clamp(alpha * shape, 0.0, 1.0);
}
