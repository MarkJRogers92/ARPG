shader_type spatial;
// Vertex-colored, low-poly models built by MeshKit (hero, items, props).
// COLOR is the linear color (times the instance color in a MultiMesh) and
// UV.x is how strongly that part glows.

uniform float glow_strength = 2.5;
uniform vec3 rim_color : source_color = vec3(0.55, 0.65, 1.0);
uniform float rim_strength = 0.2;
uniform float roughness = 0.8;

varying float v_glow;

void vertex() {
	v_glow = UV.x;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = roughness;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = COLOR.rgb * v_glow * glow_strength + rim_color * rim * rim_strength;
}
