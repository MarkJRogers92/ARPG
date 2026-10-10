shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
// Worn forecourts / compacted tracks: low-contrast, feathered ground stamps.
// Three shared materials, not one decal/node per place. No gameplay collision.
uniform int biome = 0;
varying vec3 world_pos;
varying vec4 stamp;

float grain(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	stamp = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 local = (UV - 0.5) * stamp.xy;
	vec2 edge = stamp.xy * 0.5 - abs(local);
	float wear = grain(floor(p * 5.0));
	float feather = smoothstep(0.0, 0.35, min(edge.x, edge.y) - wear * 0.12);
	vec3 col = vec3(0.22, 0.21, 0.18);
	if (biome == 1) {
		col = vec3(0.55, 0.65, 0.74); // compressed, blue-grey snow
	} else if (biome == 2) {
		col = vec3(0.16, 0.12, 0.11); // cooled ash around the workyard
	} else if (stamp.z < 0.5) {
		// Irregular old paving beneath the grave plots, not a perfect grid.
		vec2 tile = fract(p * 1.3);
		float seam = smoothstep(0.025, 0.08, min(min(tile.x, tile.y), min(1.0 - tile.x, 1.0 - tile.y)));
		col = mix(vec3(0.13, 0.13, 0.11), vec3(0.26, 0.255, 0.24), seam);
	}
	ALBEDO = col * (0.88 + 0.2 * wear);
	ALPHA = feather * (stamp.z > 0.5 ? 0.67 : 0.52);
	ROUGHNESS = 1.0;
	SPECULAR = 0.05;
}
