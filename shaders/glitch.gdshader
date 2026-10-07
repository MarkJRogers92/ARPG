shader_type canvas_item;
// The Glitch Rift: the world through an old game's eyes. Chunky pixels, a
// small palette, scanlines and the odd torn row. Drawn over the 3D view, under
// the HUD. `strength` fades it in and out.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float pixel_size = 5.0;
uniform float levels = 5.0;
uniform float strength = 1.0;
uniform float time = 0.0;

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 cell = floor(FRAGCOORD.xy / pixel_size) * pixel_size + pixel_size * 0.5;
	// Now and then a band of rows slips sideways.
	float band = floor(cell.y / (pixel_size * 6.0));
	float tear = step(0.985, fract(sin(band * 12.9898 + floor(time * 8.0) * 78.233) * 43758.5453));
	cell.x += tear * pixel_size * 6.0;
	vec3 c = texture(screen_texture, cell / res).rgb;
	vec3 q = floor(c * levels + 0.5) / levels;
	float scan = 0.88 + 0.12 * step(0.5, fract(FRAGCOORD.y / (pixel_size * 2.0)));
	q *= scan;
	q = mix(q, q * vec3(1.05, 0.95, 1.15), 0.5);
	vec3 base = texture(screen_texture, SCREEN_UV).rgb;
	COLOR = vec4(mix(base, q, strength), 1.0);
}
