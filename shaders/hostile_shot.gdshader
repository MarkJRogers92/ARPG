shader_type spatial;
// Opaque, depth-tested threats with a pale core and dark rim. Hero bolts
// retain their existing translucent tapered trails and elemental colours.
render_mode unshaded;

varying float core;

void vertex() {
	core = UV.x;
}

void fragment() {
	float face = smoothstep(0.18, 0.7, max(dot(normalize(NORMAL), normalize(VIEW)), 0.0));
	vec3 tint = mix(COLOR.rgb, vec3(1.0, 0.94, 0.8), 0.4);
	ALBEDO = mix(vec3(0.018, 0.02, 0.03), tint, face * mix(0.45, 1.0, core));
	EMISSION = COLOR.rgb * face * core * 0.35;
}
