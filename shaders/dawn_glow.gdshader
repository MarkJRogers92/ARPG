shader_type canvas_item;
render_mode blend_add, unshaded;
// Light from the rising sun, over the whole screen: a warm glow from the
// corner the sunlight comes from, with slow god rays. `first_light` is the
// pre-dawn hint, `dawn` the sunrise itself.

uniform float first_light = 0.0;
uniform float dawn = 0.0;
uniform float aspect = 1.777;
uniform vec2 source = vec2(1.1, 1.2);
uniform vec3 warm : source_color = vec3(1.0, 0.7, 0.42);

void fragment() {
	vec2 p = (UV - source) * vec2(aspect, 1.0);
	float d = length(p);
	float glow = exp(-d * 1.5);
	float ang = atan(p.y, p.x);
	float rays = (0.5 + 0.5 * sin(ang * 23.0 + TIME * 0.25)) * (0.5 + 0.5 * sin(ang * 37.0 - TIME * 0.17));
	rays = pow(rays, 3.0) * smoothstep(0.05, 0.6, d) * exp(-d * 0.9);
	float a = (glow * 0.32 + rays * 0.22) * first_light + (glow * 0.45 + rays * 0.5 + 0.06) * dawn;
	COLOR = vec4(warm, clamp(a, 0.0, 0.9));
}
