shader_type spatial;
// kit.gdshader for big imported set pieces (AssetProps landmarks), plus a
// see-through window: the part of the landmark between the camera and the
// hero is dithered away, so the hero never vanishes behind a mausoleum.
// Glow is per surface (flat_glow), not from UV.x (see AssetProps).

uniform float glow_strength = 2.5;
uniform vec3 rim_color : source_color = vec3(0.55, 0.65, 1.0);
uniform float rim_strength = 0.2;
uniform float roughness = 0.8;
uniform float flat_glow = 0.0;
// Set every frame by WorldDecor: the hero's chest, in world space.
uniform vec3 hero_position = vec3(0.0, -1000.0, 0.0);
// Radius of the window around the camera-to-hero line, in meters.
uniform float window_radius = 1.5;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Directional shadows render with an orthographic camera; keep shadows whole.
	bool shadow_pass = PROJECTION_MATRIX[3][3] > 0.5;
	if (!shadow_pass) {
		vec3 cam = CAMERA_POSITION_WORLD;
		vec3 to_hero = hero_position - cam;
		float hero_t = length(to_hero);
		vec3 d = to_hero / max(hero_t, 0.001);
		vec3 rel = v_world - cam;
		float t = dot(rel, d);
		float off_axis = length(rel - d * t);
		// 0 inside the window, 1 outside; only in front of the hero.
		float keep = smoothstep(window_radius * 0.6, window_radius, off_axis);
		if (t < hero_t - 0.4) {
			// 4x4 ordered dither, so the window has a soft, cheap edge.
			int x = int(FRAGCOORD.x) % 4;
			int y = int(FRAGCOORD.y) % 4;
			float bayer[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
			if (keep < (bayer[y * 4 + x] + 0.5) / 16.0) {
				discard;
			}
		}
	}
	ALBEDO = COLOR.rgb;
	ROUGHNESS = roughness;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = COLOR.rgb * flat_glow * glow_strength + rim_color * rim * rim_strength;
}
