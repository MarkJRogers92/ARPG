shader_type spatial;
// Procedural grid in world space, so the ground reads as moving while the
// plane itself just follows the player.

uniform vec3 base_color : source_color = vec3(0.11, 0.12, 0.15);
uniform vec3 line_color : source_color = vec3(0.2, 0.22, 0.28);
uniform float cell_size = 4.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz / cell_size;
	vec2 grid = abs(fract(uv - 0.5) - 0.5) / fwidth(uv);
	float line = 1.0 - min(min(grid.x, grid.y), 1.0);
	ALBEDO = mix(base_color, line_color, line);
	ROUGHNESS = 1.0;
}
