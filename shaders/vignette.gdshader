shader_type canvas_item;
// Darkens the screen edges and adds a red pulse when the hero is hurt.

uniform float strength = 0.55;
uniform float hurt = 0.0;

void fragment() {
	vec2 p = UV - 0.5;
	p.x *= 1.4;
	float d = length(p);
	float v = smoothstep(0.35, 0.85, d);
	vec3 tint = mix(vec3(0.0, 0.01, 0.03), vec3(0.5, 0.0, 0.0), hurt);
	COLOR = vec4(tint, v * strength + hurt * smoothstep(0.25, 0.8, d) * 0.6);
}
