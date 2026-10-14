shader_type spatial;
// Souls on the ground: a wispy teardrop flame, deliberately unlike the faceted
// XP shards. Additive and unshaded; the tip sways and flickers, the base is a
// hot pale bulb. Per instance: COLOR = tint, custom.x = pull (0 -> 1).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

varying float v_h;
varying float v_pull;
varying float v_phase;

void vertex() {
	vec3 wp = MODEL_MATRIX[3].xyz;
	float phase = wp.x * 1.3 + wp.z * 1.9;
	v_h = clamp(VERTEX.y / 0.55, 0.0, 1.0);
	v_pull = INSTANCE_CUSTOM.x;
	v_phase = phase;
	float tip = v_h * v_h;
	VERTEX.x += sin(TIME * 5.0 + phase + v_h * 4.0) * 0.07 * tip;
	VERTEX.z += cos(TIME * 4.3 + phase * 1.3 + v_h * 3.0) * 0.07 * tip;
	VERTEX.y *= 1.0 + 0.12 * sin(TIME * 7.0 + phase);
	VERTEX *= 1.0 + v_pull * 0.3;
}

void fragment() {
	float facing = abs(dot(NORMAL, VIEW));
	float soft = pow(facing, 1.3);
	vec3 hot = vec3(0.75, 0.93, 1.0);
	vec3 col = mix(hot, COLOR.rgb, smoothstep(0.05, 0.85, v_h));
	float a = soft * (1.0 - v_h * 0.75) * (0.36 + 0.64 * v_pull);
	ALBEDO = col * (0.85 + 0.9 * v_pull);
	ALPHA = a;
}
