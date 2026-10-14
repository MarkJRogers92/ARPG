shader_type spatial;
// The light pillar over good loot: a soft volumetric-looking column. The core
// is bright and fades smoothly upward and toward the silhouette, slow bands
// drift up it and sparse motes rise inside. `flourish` (legendary) warms the
// motes into embers and adds a second, faster set.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.8, 0.3, 0.6);
uniform float height = 6.0;
uniform float flourish = 0.0;
uniform vec3 hot_color : source_color = vec3(1.0, 0.6, 0.2);

varying float v_h;
varying float v_y;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float motes(vec2 uv, float cols, float rows, float speed, float seed) {
	vec2 g = vec2(uv.x * cols, uv.y * rows - TIME * speed);
	vec2 id = floor(g);
	vec2 f = fract(g);
	float h = hash21(id + seed);
	vec2 pos = vec2(0.25 + 0.5 * hash21(id + seed + 4.0), 0.25 + 0.5 * hash21(id + seed + 9.0));
	float dm = length((f - pos) * vec2(1.0, 0.8));
	float tw = 0.6 + 0.4 * sin(TIME * 3.0 + h * 20.0);
	return smoothstep(0.16, 0.0, dm) * step(0.62, h) * tw;
}

void vertex() {
	v_h = clamp(VERTEX.y / height + 0.5, 0.0, 1.0);
	v_y = VERTEX.y + height * 0.5;
}

void fragment() {
	float facing = abs(dot(NORMAL, VIEW));
	float profile = pow(facing, 2.4);
	// Bright at the foot, long soft fade, nothing hard at the top.
	float vert = pow(1.0 - v_h, 1.5) * smoothstep(1.0, 0.8, v_h);
	float band = 0.82 + 0.18 * sin(v_y * 2.2 - TIME * 1.6 + UV.x * 6.2831853 * 2.0);
	float shaft = profile * vert * band;
	vec2 uv = vec2(UV.x, v_y);
	float m = motes(uv, 9.0, 1.1, 0.55, 0.0) * (0.4 + 0.6 * profile);
	vec3 rgb = color.rgb * 1.5 + vec3(0.35) * shaft * shaft;
	float a = shaft * 0.85 + m * 1.3 * (1.0 - v_h * 0.7);
	if (flourish > 0.0) {
		float e = motes(uv, 13.0, 1.6, 1.1, 5.0) * (0.5 + 0.5 * profile);
		rgb = mix(rgb, hot_color * 1.6, clamp(e * flourish * 1.5, 0.0, 1.0));
		a += e * flourish * 1.6 * (1.0 - v_h * 0.5);
		a += flourish * shaft * 0.25;
	}
	ALBEDO = rgb;
	ALPHA = clamp(color.a * a, 0.0, 1.0);
}
