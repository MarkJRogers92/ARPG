shader_type spatial;
// The Arcane Nova's expanding shockwave: a bright leading edge with a soft
// glow trailing inward, a thin echo ring and faint runic dashes riding the
// front. Friendly only (the hero's nova).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.45, 0.9, 0.9);
uniform float ring = 1.0;
uniform float pulse_speed = 0.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	if (d > 1.0) {
		discard;
	}
	float ang = atan(p.y, p.x);
	float edge = exp(-pow((d - 0.93) * 34.0, 2.0));
	float trail = smoothstep(0.55, 0.93, d) * smoothstep(1.0, 0.93, d) * 0.35;
	float echo = exp(-pow((d - 0.8) * 60.0, 2.0)) * 0.4;
	float dash = smoothstep(0.3, 0.9, sin(ang * 18.0)) * exp(-pow((d - 0.86) * 40.0, 2.0)) * 0.5;
	float shape = edge + trail * trail * 2.0 + echo + dash;
	ALBEDO = mix(color.rgb, vec3(1.0), edge * 0.45);
	ALPHA = clamp(color.a * shape, 0.0, 1.0);
}
