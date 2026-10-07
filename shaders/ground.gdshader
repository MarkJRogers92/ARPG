shader_type spatial;
// The infinite ground, painted in world space so the plane can follow the
// hero: mossy grass and dirt patches, with old flagstone plazas breaking
// through here and there. Everything is procedural (no textures).

uniform vec3 grass_dark : source_color = vec3(0.10, 0.13, 0.085);
uniform vec3 grass_light : source_color = vec3(0.17, 0.21, 0.12);
uniform vec3 dirt : source_color = vec3(0.21, 0.17, 0.13);
uniform vec3 stone : source_color = vec3(0.24, 0.235, 0.25);
uniform vec3 grout : source_color = vec3(0.09, 0.095, 0.09);
// Realm features: snow cover (Frozen Wastes) and glowing lava cracks (Ember Rift).
uniform float snow = 0.0;
uniform vec3 snow_color : source_color = vec3(0.86, 0.9, 0.97);
uniform float lava = 0.0;

varying vec3 world_pos;

// Sine-free hash, so it stays stable far from the origin.
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}

// x: distance to the nearest cell edge, y: a random value for that cell.
vec2 voronoi(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 id = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash2(n + g) * 0.8 + 0.1;
			float d = length(g + o - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = n + g;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec2(d2 - d1, hash(id));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float detail = fbm(p * 0.7);
	float blades = noise(p * 5.0) * 0.5 + noise(p * 11.0) * 0.5;

	vec3 grass = mix(grass_dark, grass_light, smoothstep(0.3, 0.75, fbm(p * 0.12) * 0.6 + detail * 0.4));
	grass *= 0.85 + 0.3 * blades;

	float dirt_mask = smoothstep(0.5, 0.6, fbm(p * 0.045 + vec2(7.0, 3.0)) + detail * 0.12);
	vec3 col = mix(grass, dirt * (0.75 + 0.5 * detail), dirt_mask);

	// Flagstone plazas.
	float plaza = smoothstep(0.64, 0.69, fbm(p * 0.035 + vec2(31.0, -12.0)));
	if (plaza > 0.0) {
		vec2 v = voronoi(p * 1.15);
		float missing = step(0.86, v.y); // the odd stone is gone
		vec3 slab = stone * (0.75 + 0.4 * v.y) * (0.8 + 0.35 * detail);
		float edge = smoothstep(0.015, 0.07, v.x);
		slab = mix(grout, slab, edge);
		// Moss creeps in from the edges of the plaza.
		float moss = smoothstep(0.35, 0.75, (1.0 - plaza) + detail * 0.6 - 0.3);
		slab = mix(slab, grass, moss * 0.8);
		col = mix(col, slab, plaza * (1.0 - missing));
	}

	// Pebbles and specks.
	vec2 cell = floor(p * 3.0);
	float pebble = step(0.985, hash(cell)) * smoothstep(0.35, 0.15, length(fract(p * 3.0) - 0.5));
	col = mix(col, vec3(0.25, 0.23, 0.21) * (0.7 + 0.5 * hash(cell + 3.0)), pebble * 0.7);

	if (snow > 0.0) {
		float drift = smoothstep(0.3, 0.65, fbm(p * 0.09 + vec2(5.0, 1.0)) * 0.7 + detail * 0.45);
		float cover = clamp(snow * (0.55 + drift * 0.8), 0.0, 1.0);
		col = mix(col, snow_color * (0.88 + 0.12 * blades), cover);
	}
	if (lava > 0.0) {
		vec2 cv = voronoi(p * 0.32 + vec2(11.0, 4.0));
		float region = smoothstep(0.48, 0.62, fbm(p * 0.05 + vec2(3.0, 9.0)));
		float crack = (1.0 - smoothstep(0.0, 0.07, cv.x)) * region * lava;
		float pulse = 0.75 + 0.25 * sin(TIME * 1.7 + cv.y * 6.28);
		col = mix(col, vec3(0.05, 0.015, 0.01), crack);
		EMISSION = vec3(1.0, 0.32, 0.05) * crack * pulse * 1.4
				+ vec3(0.6, 0.12, 0.02) * region * lava * (1.0 - smoothstep(0.0, 0.2, cv.x)) * 0.25;
	}

	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
