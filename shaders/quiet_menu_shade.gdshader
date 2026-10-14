shader_type canvas_item;
render_mode unshaded;
void fragment() {
	float left = 1.0 - smoothstep(0.28, 0.83, UV.x);
	float edge = smoothstep(0.55, 1.0, abs(UV.y - 0.5) * 2.0);
	COLOR = vec4(vec3(0.023, 0.039, 0.059), 0.40 + left * 0.55 + edge * 0.08);
}
