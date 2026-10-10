shader_type spatial;
// Enemies: a MeshKit model (feet at y = 0, facing -Z) drawn by EnemySwarm.
// Instance custom data: x = hit flash (1 on hit, fading to 0), y = animation
// phase, z = elite glow (0 or 1), w = burning (0 or 1). The instance color
// tints the model (elites, chill, shock). With `spectral` on, the model is
// drawn as a glowing ghost: the hero's raised minions (custom z then marks a
// veteran's rank, gilding it). The walk is done here: legs swing, the body bobs and rocks, so the
// CPU only ever writes positions and facing.

uniform float glow_strength = 3.0;
// Model height in world units; animation amounts are relative to it.
uniform float height = 1.4;
uniform float stride_speed = 9.0;
// Vertices below this fraction of the height count as legs.
uniform float leg_height = 0.32;
uniform float stride = 0.18;
uniform float bob = 0.05;
uniform float sway = 0.08;
// Four-legged gait: diagonal legs move together.
uniform bool quadruped = false;
// Authored specialist shields and staff bases stay rigid. The procedural
// models retain their existing gait; only low vertices under the hips swing.
uniform bool rigid_accessories = false;
uniform float leg_width = 0.2;
// Only imported specialists use instance color alpha as movement intensity.
// They remain opaque; this shader never writes ALPHA.
uniform bool travel_gait = false;
uniform vec3 rim_color : source_color = vec3(1.0, 0.55, 0.45);
uniform float rim_strength = 0.35;
uniform bool spectral = false;
// Only the hero's army opts in. Rival thralls keep their original presentation.
uniform bool ally_readability = false;
// The ghost's glow: the hero's minions are blue, a rival's thralls red.
uniform vec3 spectral_color : source_color = vec3(0.25, 0.7, 1.0);

varying float v_glow;
varying float v_flash;
varying float v_elite;
varying float v_burn;
varying float v_phase;

void vertex() {
	float t = TIME * stride_speed + INSTANCE_CUSTOM.y * 6.2831853;
	float h = VERTEX.y / height;
	float swing = sin(t);
	float motion = travel_gait ? COLOR.a : 1.0;

	// Legs: swing forward / back around the hip, opposite sides out of phase.
	float leg = clamp(1.0 - h / leg_height, 0.0, 1.0);
	if (rigid_accessories) {
		leg *= (abs(VERTEX.x) < height * leg_width && VERTEX.z > -height * 0.1) ? 1.0 : 0.0;
	}
	float side = sign(VERTEX.x);
	if (quadruped) {
		side *= sign(VERTEX.z);
	}
	VERTEX.z += swing * side * leg * stride * height * motion;
	// Forward is -Z: lift the foot while it returns forward, plant it
	// during the backward stroke. Keep the procedural cycle unchanged.
	float lift = travel_gait ? max(0.0, -cos(t) * side) : max(0.0, swing * side);
	VERTEX.y += lift * leg * 0.08 * height * motion;

	// Body: rock side to side around the feet and bob on every step.
	float rock = swing * sway * motion;
	float c = cos(rock);
	float s = sin(rock);
	VERTEX.xy = vec2(VERTEX.x * c - VERTEX.y * s, VERTEX.x * s + VERTEX.y * c);
	VERTEX.y += abs(cos(t)) * bob * height * motion;
	if (travel_gait) {
		VERTEX.z -= VERTEX.y * 0.07 * motion; // slight forward travel lean
	}

	// Hit: a quick swell and a white flash.
	v_flash = INSTANCE_CUSTOM.x;
	VERTEX.xz *= 1.0 + v_flash * 0.15;
	VERTEX.y *= 1.0 - v_flash * 0.08;
	v_glow = UV.x;
	v_elite = INSTANCE_CUSTOM.z;
	v_burn = INSTANCE_CUSTOM.w;
	v_phase = INSTANCE_CUSTOM.y;
}

void fragment() {
	vec3 base = COLOR.rgb;
	ALBEDO = mix(base, vec3(1.0), v_flash * 0.3);
	ROUGHNESS = 0.8;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	if (spectral) {
		float lum = dot(base, vec3(0.3, 0.55, 0.15));
		ALBEDO = vec3(0.1, 0.25, 0.35) * (0.5 + lum);
		EMISSION = spectral_color * (0.35 + lum * 0.6 + rim * 2.5 + v_glow * 1.5)
				* (0.85 + 0.15 * sin(TIME * 4.0 + v_phase * 6.28))
				+ vec3(0.8, 0.95, 1.0) * v_flash * 0.5;
		if (ally_readability) {
			// A defined dark-blue body and narrow pale rim, not a blue light blob.
			EMISSION = spectral_color * (0.15 + rim * 1.2 + min(v_glow, 0.8) * 0.5)
					+ vec3(0.72, 0.95, 1.0) * rim * rim * 0.35;
		}
		// Veterans (custom z = rank / 3): a golden rim, brighter with rank.
		EMISSION = mix(EMISSION, EMISSION * vec3(1.5, 1.05, 0.45) + vec3(1.0, 0.7, 0.25) * rim * 2.0, clamp(v_elite * 1.5, 0.0, 1.0));
	} else {
		EMISSION = base * v_glow * glow_strength
				+ rim_color * rim * rim_strength
				+ vec3(1.0, 0.9, 0.85) * v_flash * 0.35
				+ vec3(1.0, 0.72, 0.25) * (rim * 2.2 + 0.1 + 0.08 * sin(TIME * 5.0)) * v_elite
				+ vec3(1.0, 0.4, 0.08) * (0.35 + rim * 1.8) * v_burn * (0.75 + 0.25 * sin(TIME * 23.0 + VERTEX.y * 9.0));
	}
}
