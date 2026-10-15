shader_type spatial;
// The Reaping Scythe's motion trail: a crescent glow that fades out behind the
// spinning blade. The plane turns with the blade; the trail sits on the side
// the blade came from. Friendly only.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(0.65, 0.95, 0.85, 0.7);

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	if (d > 1.0) {
		discard;
	}
	// Angle measured from the blade's middle; the blade spans about -70..64 degrees
	// and the wake trails behind it (increasing angle as the blade turns).
	float ang = degrees(atan(p.y, p.x));
	float wake = clamp((ang - 40.0) / 140.0, 0.0, 1.0);
	float in_blade = step(-75.0, ang) * step(ang, 70.0);
	float fade = in_blade * mix(0.35, 1.0, smoothstep(-70.0, 40.0, ang)) + (1.0 - in_blade) * (1.0 - wake) * step(40.0, ang);
	float band = smoothstep(0.5, 0.72, d) * smoothstep(1.0, 0.8, d);
	float edge = exp(-pow((d - 0.78) * 12.0, 2.0));
	float a = fade * (band * 0.5 + edge * 0.5);
	ALBEDO = mix(color.rgb, vec3(1.0), edge * fade * 0.5) * 1.4;
	ALPHA = clamp(a * color.a, 0.0, 1.0);
}
