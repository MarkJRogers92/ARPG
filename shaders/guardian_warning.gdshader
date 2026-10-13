shader_type spatial;
// Steady, depth-tested cut countdown. This ink is not the damage collider.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.48, 0.12, 0.78);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float body_scale = 2.154106;
uniform float stroke_width = 0.075;
uniform bool active = false;
varying vec2 ground;

void vertex() {
	ground = VERTEX.xz * body_scale;
}

void fragment() {
	float radius = length(ground);
	float angle = atan(ground.x, ground.y) - radians(20.0);
	float edge = min(min(radius - 1.3, 3.8 - radius), (radians(50.0) - abs(angle)) * radius);
	float aa = max(fwidth(edge), 0.012);
	float mask = smoothstep(0.0, aa, edge);
	float keyline = 1.0 - smoothstep(stroke_width, stroke_width + aa, edge);
	float stroke = smoothstep(stroke_width, stroke_width + aa, edge) * (1.0 - smoothstep(stroke_width * 2.4, stroke_width * 2.4 + aa, edge));
	float fill = 1.0 - smoothstep(1.3 + progress * 2.5, 1.3 + progress * 2.5 + aa, radius);
	vec3 ink = active ? mix(color.rgb, vec3(1.0, 0.82, 0.38), 0.45) : color.rgb;
	ALBEDO = mix(ink, vec3(0.018, 0.022, 0.03), keyline);
	ALPHA = mask * clamp(color.a, 0.0, 1.0) * max(max(keyline * 0.92, stroke), mix(0.12, active ? 0.52 : 0.38, fill));
}
