shader_type spatial;
// XP crystals: spin and bob in place. The phase comes from the gem's world
// position so neighbors don't move in lockstep.

uniform float spin = 2.2;
uniform float glow_strength = 0.9;

varying float v_glow;

void vertex() {
	vec3 wp = MODEL_MATRIX[3].xyz;
	float phase = wp.x * 1.7 + wp.z * 2.3;
	float a = TIME * spin + phase;
	mat2 r = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a)));
	VERTEX.xz = r * VERTEX.xz;
	NORMAL.xz = r * NORMAL.xz;
	VERTEX.y += sin(TIME * 3.0 + phase) * 0.06;
	v_glow = UV.x;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	METALLIC = 0.3;
	ROUGHNESS = 0.2;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	EMISSION = COLOR.rgb * (glow_strength + v_glow) + vec3(1.0) * rim * 0.4;
}
