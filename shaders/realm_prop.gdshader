shader_type spatial;
// Textured scenery models (RealmProps): one albedo atlas per kind, lit by the
// moon like the kit shader, with a see-through window where the prop would hide
// the hero (same dither as kit_landmark), a per-instance tint, and an emission
// mask derived from the albedo (magma veins, crystals, mushroom caps).

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float brightness = 1.0;
uniform float roughness = 0.85;
uniform float specular = 0.35;
// Glow: 0 none, 1 warm-hued texels (even dark ones), 2 cool texels (blue/cyan over
// red), 3 any bright texel, 4 procedural cracks in object space (for rock and
// bark whose albedo has no glowing texels). The mask is smoothstep(emit_lo, emit_hi, key).
uniform int emit_mode = 0;
uniform vec3 emit_color : source_color = vec3(1.0, 0.45, 0.1);
uniform float emit_strength = 0.0;
uniform float emit_lo = 0.1;
uniform float emit_hi = 0.4;
uniform float crack_scale = 3.5;
uniform float crack_width = 0.06;
// Slow breathing of the glow, +-pulse around 1.
uniform float pulse = 0.0;
uniform float pulse_speed = 1.2;
// Fresnel sheen (ice, glassy obsidian), picked up by bloom at the edges.
uniform vec3 rim_color : source_color = vec3(0.55, 0.65, 1.0);
uniform float rim_strength = 0.15;
// Set every frame by RealmProps.set_hero: the hero's chest, in world space.
uniform vec3 hero_position = vec3(0.0, -1000.0, 0.0);
uniform float window_radius = 1.3;

varying vec3 v_world;
varying float v_rand;
varying vec3 v_local;

float hash31(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash31(i), hash31(i + vec3(1, 0, 0)), f.x), mix(hash31(i + vec3(0, 1, 0)), hash31(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash31(i + vec3(0, 0, 1)), hash31(i + vec3(1, 0, 1)), f.x), mix(hash31(i + vec3(0, 1, 1)), hash31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	v_local = VERTEX;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_rand = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	bool shadow_pass = PROJECTION_MATRIX[3][3] > 0.5;
	if (!shadow_pass) {
		vec3 cam = CAMERA_POSITION_WORLD;
		vec3 to_hero = hero_position - cam;
		float hero_t = length(to_hero);
		vec3 d = to_hero / max(hero_t, 0.001);
		vec3 rel = v_world - cam;
		float t = dot(rel, d);
		float off_axis = length(rel - d * t);
		float keep = smoothstep(window_radius * 0.6, window_radius, off_axis);
		if (t < hero_t - 0.4) {
			int x = int(FRAGCOORD.x) % 4;
			int y = int(FRAGCOORD.y) % 4;
			float bayer[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
			if (keep < (bayer[y * 4 + x] + 0.5) / 16.0) {
				discard;
			}
		}
	}
	vec3 tex = texture(albedo_tex, UV).rgb;
	// Slight warm/cool drift per instance, on top of the instance shade (COLOR).
	vec3 jitter = vec3(1.0) + (v_rand - 0.5) * vec3(0.14, 0.0, -0.14);
	ALBEDO = tex * tint * jitter * COLOR.rgb * brightness;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 glow = rim_color * rim * rim_strength;
	if (emit_mode > 0 && emit_strength > 0.0) {
		float key;
		if (emit_mode == 4) {
			vec3 p = v_local * crack_scale;
			float n = vnoise(p);
			float line = 1.0 - smoothstep(0.0, crack_width, abs(n - 0.5));
			// Broken, drifting seams rather than a net.
			float gate = smoothstep(0.35, 0.65, vnoise(p * 0.6 + vec3(7.0, TIME * 0.05, 3.0)));
			key = line * gate;
		} else if (emit_mode == 1) {
			float r = tex.r;
			key = (r - tex.b) / (r + tex.g + tex.b + 0.002) * smoothstep(0.003, 0.02, r);
		} else if (emit_mode == 2) {
			key = max(tex.b, tex.g) - tex.r * 0.7;
		} else {
			key = max(max(tex.r, tex.g), tex.b);
		}
		float mask = smoothstep(emit_lo, emit_hi, key);
		float breathe = 1.0 + pulse * sin(TIME * pulse_speed + v_rand * 6.2831);
		glow += emit_color * mask * emit_strength * breathe;
	}
	EMISSION = glow;
}
