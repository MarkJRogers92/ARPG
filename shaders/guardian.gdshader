shader_type spatial;
// Vertex-colored, low-poly models built by MeshKit (hero, items, props).
// COLOR is the linear color (times the instance color in a MultiMesh) and
// UV.x is how strongly that part glows.

uniform float glow_strength = 2.5;
uniform vec3 rim_color : source_color = vec3(0.55, 0.65, 1.0);
uniform float rim_strength = 0.2;
uniform float roughness = 0.8;
// Glow = UV.x * uv_glow + flat_glow. The defaults are MeshKit's convention;
// imported art (AssetProps) sets uv_glow = 0 and glows per surface instead.
uniform float uv_glow = 1.0;
uniform float flat_glow = 0.0;

uniform vec4 status_tint : source_color = vec4(1.0);
uniform float hit_flash = 0.0;
uniform float hit_strength = 1.0;
varying float v_glow;

void vertex() {
	v_glow = UV.x * uv_glow + flat_glow;
}

void fragment() {
	// Preserve armor/value separation under continuous fire; the rim carries the hit.
	float hit = pow(clamp(hit_flash, 0.0, 1.0), 2.0) * hit_strength;
	ALBEDO = mix(COLOR.rgb * status_tint.rgb, vec3(0.85, 0.75, 0.55), hit * 0.12);
	ROUGHNESS = roughness;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = COLOR.rgb * v_glow * glow_strength + rim_color * rim * rim_strength
		+ vec3(0.9, 0.65, 0.3) * rim * hit * 0.8;
}
