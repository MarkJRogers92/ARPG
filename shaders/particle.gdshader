shader_type spatial;
// Camera-facing soft dots for hit and death bursts (FxSwarm).
// Instance custom data: x = life left (1 -> 0), y = size.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float intensity = 1.8;

varying float v_life;

void vertex() {
	float size = INSTANCE_CUSTOM.y;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(size, 0.0, 0.0, 0.0), vec4(0.0, size, 0.0, 0.0),
			vec4(0.0, 0.0, size, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	v_life = INSTANCE_CUSTOM.x;
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = smoothstep(1.0, 0.0, d);
	ALBEDO = COLOR.rgb * intensity * (0.6 + 0.4 * v_life);
	ALPHA = a * a * COLOR.a * min(1.0, v_life * 2.0);
}
