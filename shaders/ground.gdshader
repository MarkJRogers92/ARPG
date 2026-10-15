shader_type spatial;
// The infinite ground, painted in world space so the plane can follow the
// hero. One procedural painter per realm (no textures), picked by the realm
// uniforms: graveyard (snow = lava = 0) is worn flagstone plazas melting into
// packed earth and dark grass; frozen (snow > 0) is wind-carved blue snow with
// dark glassy ice; ember (lava > 0) is cooled basalt plates and ash dunes with
// glowing magma veins. Each paints a height field too, and the screen-space
// derivatives of it tilt the normal so the key light rakes across the surface.

uniform vec3 grass_dark : source_color = vec3(0.10, 0.13, 0.085);
uniform vec3 grass_light : source_color = vec3(0.17, 0.21, 0.12);
uniform vec3 dirt : source_color = vec3(0.21, 0.17, 0.13);
uniform vec3 stone : source_color = vec3(0.24, 0.235, 0.25);
uniform vec3 grout : source_color = vec3(0.09, 0.095, 0.09);
// Realm features: snow cover (Frozen Wastes) and glowing magma veins (Ember Rift).
uniform float snow = 0.0;
uniform vec3 snow_color : source_color = vec3(0.86, 0.9, 0.97);
uniform float lava = 0.0;
uniform vec3 moss_color : source_color = vec3(0.12, 0.24, 0.17);
uniform vec3 wet_color : source_color = vec3(0.04, 0.07, 0.10);
uniform vec3 sheen_color : source_color = vec3(0.35, 0.58, 0.75);
uniform vec3 ice_color : source_color = vec3(0.07, 0.15, 0.26);
uniform vec3 magma_color : source_color = vec3(1.0, 0.33, 0.05);
uniform vec3 magma_hot : source_color = vec3(1.0, 0.8, 0.22);

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

// Cheaper 3-octave version for the broad, low-frequency masks.
float fbm3(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v * 1.07;
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

// x: distance to the nearest cell edge, y and z: random values for that cell.
vec3 voronoi(vec2 p) {
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
	return vec3(d2 - d1, hash(id), hash(id + 41.7));
}

// Fade for pixel-sized speckle: distant cells would only shimmer.
float speck_fade(vec2 p, float scale) {
	return 1.0 - smoothstep(0.25, 0.7, length(fwidth(p)) * scale);
}

// Worn flagstone plazas, packed earth, dark grass, moss, damp and puddles.
void paint_graveyard(vec2 p, float detail, out vec3 col, out float h, out float rough, out float spec, out vec3 emis) {
	float blades = noise(p * 5.0) * 0.5 + noise(p * 11.0) * 0.5;
	float big = fbm3(p * 0.12) * 0.6 + detail * 0.4;
	vec3 grass = mix(grass_dark, grass_light, smoothstep(0.3, 0.75, big));
	grass *= 0.85 + 0.3 * blades;
	float dirt_mask = smoothstep(0.56, 0.66, fbm3(p * 0.045 + vec2(7.0, 3.0)) + detail * 0.12);
	col = mix(grass, dirt * (0.75 + 0.5 * detail), dirt_mask);
	h = detail * 0.05 + blades * 0.01;
	rough = 0.96;
	spec = 0.15;
	emis = vec3(0.0);

	float plaza = smoothstep(0.6, 0.67, fbm3(p * 0.035 + vec2(31.0, -12.0)) + (detail - 0.5) * 0.14);
	if (plaza > 0.0) {
		vec2 warp = vec2(noise(p * 0.9), noise(p * 0.9 + 9.0)) - 0.5;
		vec3 v = voronoi(p * 0.72 + warp * 0.6);
		float e = v.x;
		float stone_mask = plaza * (1.0 - step(0.9, v.y)); // the odd stone is gone
		float bevel = smoothstep(0.0, 0.2, e);
		// Per-stone value and hue: some cool and bluish, some warm and sandy.
		vec3 slab = stone * (0.68 + 0.5 * v.y) * mix(vec3(0.92, 1.0, 1.08), vec3(1.04, 1.0, 0.93), v.z);
		slab *= (0.8 + 0.35 * detail) * (0.92 + 0.16 * noise(p * 16.0));
		// Bevel: dark worn edge, thin pale top-lit lip just inside it.
		slab *= 0.45 + 0.55 * bevel;
		float lip = smoothstep(0.03, 0.09, e) * (1.0 - smoothstep(0.09, 0.2, e));
		slab += stone * 0.2 * lip;
		slab = mix(grout, slab, smoothstep(0.012, 0.05, e));
		// Hairline cracks across some stones.
		float ridge = abs(noise(p * 3.1 + v.z * 20.0) - 0.5);
		float crack = (1.0 - smoothstep(0.0, 0.014, ridge)) * step(0.82, v.z);
		slab *= 1.0 - crack * 0.6;
		// Moss: thick in the seams, creeping in from the plaza rim.
		float seam = 1.0 - smoothstep(0.0, 0.16, e);
		float m = seam * smoothstep(0.45, 0.7, noise(p * 1.1 + 4.0) + detail * 0.25) * 0.85;
		m += smoothstep(0.35, 0.75, (1.0 - plaza) + detail * 0.5 - 0.25) * 0.7;
		m = clamp(m, 0.0, 1.0);
		slab = mix(slab, moss_color * (0.75 + 0.5 * blades), m * 0.85);
		col = mix(col, slab, stone_mask);
		float hs = bevel * 0.07 + (v.y - 0.5) * 0.03 + detail * 0.012 - crack * 0.02 - m * 0.012;
		h = mix(h, hs, stone_mask);
		rough = mix(rough, mix(0.62, 0.86, detail), stone_mask * bevel);
	}

	// Fallen leaves and bone dust, very low contrast.
	vec2 cell = floor(p * 4.0);
	float hh = hash(cell);
	float fleck = step(0.93, hh) * smoothstep(0.32, 0.1, length(fract(p * 4.0) - 0.5)) * speck_fade(p, 4.0);
	vec3 fc = mix(vec3(0.26, 0.17, 0.09), vec3(0.42, 0.42, 0.38), step(0.72, hash(cell + 1.7)));
	col = mix(col, fc * (0.75 + 0.4 * hash(cell + 3.0)), fleck * 0.28);

	// Damp patches that darken the ground, and puddles that catch the moon.
	float wn = fbm3(p * 0.07 + vec2(-5.0, 13.0)) + (detail - 0.5) * 0.1;
	float damp = smoothstep(0.58, 0.7, wn);
	float pud = smoothstep(0.7, 0.75, wn);
	col *= mix(1.0, 0.7, damp);
	col = mix(col, wet_color, pud * 0.6);
	rough = mix(rough, 0.08, damp * 0.6 + pud * 0.4);
	spec = mix(spec, 0.85, pud);
	h = mix(h, h * 0.25, pud);
	emis += sheen_color * pud * (0.03 + 0.07 * noise(p * 2.5 + vec2(TIME * 0.08, 0.0)));

	// Large-scale value drift so the plazas never tile.
	col *= 0.8 + 0.4 * fbm3(p * 0.022 + vec2(2.0, 8.0));
}

// Blue snow with wind-carved ripples, glittering sparkle, glassy ice and rocks.
void paint_frozen(vec2 p, float detail, vec3 view, out vec3 col, out float h, out float rough, out float spec, out vec3 emis) {
	vec2 dir = vec2(0.82, 0.57);
	float along = dot(p, dir);
	float warp = fbm3(p * 0.06 + vec2(3.0, 7.0));
	float ripple = sin(along * 1.1 + warp * 12.0) * (0.55 + 0.7 * fbm3(p * 0.03 + vec2(9.0, 4.0)));
	float fine = sin(along * 4.6 + fbm3(p * 0.4) * 9.0);
	float drift = fbm3(p * 0.05 + vec2(5.0, 1.0));
	float lit = clamp(drift * 0.65 + (0.5 + 0.5 * ripple) * 0.28 + (detail - 0.5) * 0.2, 0.0, 1.0);
	// Hollows go blue-violet (grass_dark), crests catch a paler tone (grass_light).
	col = mix(grass_dark, snow_color, smoothstep(0.22, 0.7, lit));
	col = mix(col, grass_light, smoothstep(0.72, 1.0, lit) * 0.55);
	h = drift * 0.3 + ripple * 0.11 + fine * 0.016 + detail * 0.02;
	rough = 0.85;
	spec = 0.3;
	emis = vec3(0.0);

	// Rocks peeking through the snow.
	vec2 rc = floor(p * 0.22);
	float hr = hash(rc);
	vec2 center = rc + 0.2 + 0.6 * hash2(rc + 5.0);
	float rr = 0.08 + 0.13 * hash(rc + 9.0);
	float rd = length(p * 0.22 - center) + (noise(p * 2.5) - 0.5) * 0.05;
	float rock = step(0.9, hr) * smoothstep(0.42, 0.55, fbm3(p * 0.04 + vec2(13.0, 2.0))) * (1.0 - smoothstep(rr * 0.7, rr, rd));
	vec3 rcol = stone * (0.55 + 0.7 * noise(p * 6.0)) * (0.8 + 0.4 * noise(p * 1.7));
	col = mix(col, rcol, rock);
	h += rock * 0.22 * (1.0 - rd / rr);
	rough = mix(rough, 0.8, rock);

	// Dark glassy ice with cracks, a frosted rim and a moon sheen.
	float im = fbm3(p * 0.045 + vec2(21.0, 5.0)) + (detail - 0.5) * 0.08;
	float ice = smoothstep(0.55, 0.61, im) * (1.0 - rock);
	float frost = smoothstep(0.49, 0.55, im) * (1.0 - ice) * (1.0 - rock);
	col = mix(col, mix(col, grass_light, 0.5), frost * 0.5);
	if (ice > 0.0) {
		vec3 v = voronoi(p * 0.55 + vec2(noise(p * 0.8), noise(p * 0.8 + 3.0)) * 0.5);
		float crack = (1.0 - smoothstep(0.0, 0.035, v.x)) * step(0.35, v.y);
		float deep = fbm3(p * 0.8);
		vec3 icol = ice_color * (0.75 + 0.7 * deep);
		icol = mix(icol, snow_color * 0.85, crack * 0.55);
		col = mix(col, icol, ice);
		h = mix(h, -0.01 - crack * 0.02 + deep * 0.012, ice);
		rough = mix(rough, 0.07, ice);
		spec = mix(spec, 0.9, ice);
		float streak = pow(0.5 + 0.5 * sin(dot(p, vec2(0.6, 0.8)) * 0.7 + noise(p * 0.3) * 4.0), 4.0);
		emis += sheen_color * ice * (0.05 + 0.18 * streak);
	}

	// Glitter that twinkles with view and time.
	vec2 gp = p * 16.0;
	vec2 gc = floor(gp);
	float gh = hash(gc);
	float dotg = step(0.96, gh) * smoothstep(0.3, 0.05, length(fract(gp) - 0.5)) * speck_fade(p, 16.0);
	float tw = pow(0.5 + 0.5 * sin(TIME * 2.2 + gh * 60.0 + view.x * 9.0 + view.y * 7.0), 6.0);
	emis += vec3(0.65, 0.85, 1.0) * dotg * tw * 0.5 * (1.0 - ice * 0.8);

	col *= 0.9 + 0.2 * fbm3(p * 0.025 + vec2(2.0, 8.0));
}

// Cooled basalt plates, ash dunes and glowing magma in the seams.
void paint_ember(vec2 p, float detail, out vec3 col, out float h, out float rough, out float spec, out vec3 emis) {
	float blades = noise(p * 5.0) * 0.5 + noise(p * 11.0) * 0.5;
	float ash = smoothstep(0.54, 0.66, fbm3(p * 0.04 + vec2(3.0, 9.0)) + (detail - 0.5) * 0.15);
	vec2 warp = vec2(noise(p * 0.5), noise(p * 0.5 + 9.0)) - 0.5;
	vec3 v = voronoi(p * 0.42 + warp * 0.6);
	float bevel = smoothstep(0.0, 0.16, v.x);
	vec3 plate = mix(grass_dark, grass_light, v.y) * (0.8 + 0.4 * detail) * (0.9 + 0.2 * noise(p * 9.0));
	plate *= 0.5 + 0.5 * bevel;
	plate += grass_light * 0.12 * smoothstep(0.04, 0.1, v.x) * (1.0 - smoothstep(0.1, 0.22, v.x));
	float dune = sin(dot(p, vec2(0.9, 0.4)) * 0.9 + fbm3(p * 0.07) * 8.0);
	vec3 ashc = dirt * (0.72 + 0.4 * (0.5 + 0.5 * dune)) * (0.85 + 0.3 * blades);
	col = mix(plate, ashc, ash);
	h = mix(bevel * 0.07 + (v.y - 0.5) * 0.03 + detail * 0.012, dune * 0.1 + detail * 0.03, ash);
	rough = mix(0.58, 0.95, ash);
	spec = mix(0.35, 0.1, ash);

	// Magma veins in the seams: orange, hot yellow core, slowly flowing.
	float region = smoothstep(0.38, 0.54, fbm3(p * 0.05 + vec2(-7.0, 2.0))) * (1.0 - ash * 0.9) * lava;
	float width = 0.035 + 0.05 * noise(p * 0.7 + 3.0);
	float vein = (1.0 - smoothstep(0.0, width, v.x)) * region;
	float halo = (1.0 - smoothstep(0.0, 0.5, v.x)) * region;
	float flow = noise(p * 2.4 + vec2(TIME * 0.25, -TIME * 0.17)) * 0.6 + noise(p * 5.0 - vec2(TIME * 0.3, 0.0)) * 0.4;
	float core = smoothstep(0.32, 0.78, flow + (1.0 - smoothstep(0.0, width * 0.5, v.x)) * 0.35);
	float pulse = 0.72 + 0.28 * sin(TIME * 1.3 + v.z * 6.28 + noise(p * 0.4) * 6.0);
	col = mix(col, col * vec3(1.7, 0.9, 0.55) + vec3(0.015, 0.004, 0.0), halo * 0.55);
	col = mix(col, vec3(0.04, 0.012, 0.008), vein);
	emis = mix(magma_color, magma_hot, core) * vein * pulse * (0.65 + 0.5 * core);
	emis += magma_color * halo * halo * 0.12 * pulse;
	h -= vein * 0.02;

	// Faint drifting ember speckle.
	vec2 ep = p * 7.0;
	vec2 ec = floor(ep);
	float eh = hash(ec);
	float es = step(0.975, eh) * smoothstep(0.3, 0.05, length(fract(ep) - 0.5)) * speck_fade(p, 7.0);
	emis += magma_color * es * (0.5 + 0.5 * sin(TIME * 3.0 + eh * 80.0)) * 0.7 * lava;

	col *= 0.85 + 0.3 * fbm3(p * 0.022 + vec2(2.0, 8.0));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float detail = fbm(p * 0.7);
	vec3 col;
	float height;
	float surface_roughness;
	float surface_specular;
	vec3 glow;
	if (snow > 0.0) {
		paint_frozen(p, detail, VIEW, col, height, surface_roughness, surface_specular, glow);
	} else if (lava > 0.0) {
		paint_ember(p, detail, col, height, surface_roughness, surface_specular, glow);
	} else {
		paint_graveyard(p, detail, col, height, surface_roughness, surface_specular, glow);
	}
	EMISSION = glow;

	// Derivatives operate on the painted height field in view space.
	vec3 relief_position = (VIEW_MATRIX * vec4(world_pos + vec3(0.0, height, 0.0), 1.0)).xyz;
	vec3 relief_normal = normalize(cross(dFdx(relief_position), dFdy(relief_position)));
	if (dot(relief_normal, NORMAL) < 0.0) { relief_normal = -relief_normal; }
	NORMAL = normalize(mix(NORMAL, relief_normal, 0.8));
	ALBEDO = col;
	ROUGHNESS = surface_roughness;
	SPECULAR = surface_specular;
}
