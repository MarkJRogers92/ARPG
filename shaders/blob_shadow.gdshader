shader_type spatial;
// Soft round shadow under each swarm member: far cheaper than real shadow
// maps for thousands of enemies, and it reads well from a top-down camera.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float strength = 0.5;

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	ALBEDO = vec3(0.0);
	ALPHA = strength * smoothstep(1.0, 0.15, d);
}
