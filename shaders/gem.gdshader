shader_type spatial;
// XP "soul-glass" shards: a faceted crystal with a pale core, a thin bright
// rim and a slow twinkle. Resting gems are small and a little desaturated so
// a field of hundreds stays calm; as the hero's magnet takes hold (instance
// custom x, 0 -> 1) they swell, saturate and brighten, so the pickup streak
// reads as the brightest thing on the ground.
// Per instance: COLOR = tier tint (cyan-teal, up to violet / gold),
// custom.x = pull amount, custom.y = a random phase.

uniform float spin = 1.6;
uniform float glow_strength = 0.3;

varying float v_h;
varying float v_pull;
varying float v_phase;

void vertex() {
	vec3 wp = MODEL_MATRIX[3].xyz;
	float phase = wp.x * 1.7 + wp.z * 2.3 + INSTANCE_CUSTOM.y * 6.283;
	float a = TIME * spin + phase;
	mat2 r = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a)));
	float pull = INSTANCE_CUSTOM.x;
	VERTEX *= 1.0 + pull * 0.4;
	VERTEX.xz = r * VERTEX.xz;
	NORMAL.xz = r * NORMAL.xz;
	VERTEX.y += sin(TIME * 2.4 + phase) * 0.05;
	v_h = clamp(VERTEX.y * 2.6, -1.0, 1.0);
	v_pull = pull;
	v_phase = phase;
}

void fragment() {
	vec3 tint = COLOR.rgb;
	float luma = dot(tint, vec3(0.3, 0.55, 0.15));
	// At rest: pastel; pulled in: full tint.
	vec3 body = mix(vec3(luma) * 1.1 + tint * 0.3, tint, 0.6 + 0.4 * v_pull);
	float n_dot_v = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - n_dot_v, 2.2);
	// Inner glow: bright pale core in the waist, tint toward the tips.
	float core = exp(-v_h * v_h * 3.0) * n_dot_v;
	vec3 pale = mix(body, vec3(0.92, 1.0, 1.0), 0.4);
	vec3 albedo = mix(body * 0.55, pale, core);
	// Twinkle: a short spike a few times a second, offset per gem.
	float tw = pow(max(0.0, sin(TIME * 2.1 + v_phase * 3.0)), 24.0);
	ALBEDO = albedo * 0.5;
	METALLIC = 0.15;
	ROUGHNESS = 0.25;
	EMISSION = albedo * (glow_strength + 1.1 * v_pull) + core * pale * 0.28
			+ mix(vec3(1.0), body, 0.4) * rim * (0.28 + 0.6 * v_pull)
			+ vec3(1.0) * tw * (0.2 + 0.6 * v_pull);
}
