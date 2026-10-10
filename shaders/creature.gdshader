shader_type spatial;
// Authored rigid-joint articulation. COLOR.a carries cosmetic state only:
// 0..1 locomotion; 2..3 charge anticipation; 4 charging; 5..6 recovery;
// 7 continuous-contact attack; 8..9 bounded noninteractive death remnants.
uniform vec3 joint_pivots[32];
uniform vec3 joint_axes[32];
uniform vec4 joint_params[32]; // idle, walk, attack, phase
uniform vec2 joint_bends[32]; // foot return bend, death fold
uniform int joint_parents[32];
uniform float hover_height = 0.0;
uniform float cycle_speed = 1.7;
uniform float glow_strength = 3.0;
uniform vec3 rim_color : source_color = vec3(0.55,0.65,0.72);
uniform float rim_strength = 0.45;
uniform bool spectral = false;
// Army-only: custom w is an actual swing envelope, COLOR.a remains travel.
// Enemy appearances/death/charge codes retain their original interpretation.
uniform bool allied_attack = false;
uniform vec3 spectral_color : source_color = vec3(0.25,0.7,1.0);
// Negative uses real time; nonnegative supports deterministic visual QA.
uniform float preview_time = -1.0;
varying float v_glow;
varying float v_flash;
varying float v_elite;
varying float v_burn;
varying float v_phase;
vec3 joint_rotate(vec3 p, vec3 axis, float angle) {
 float c=cos(angle);float s=sin(angle);
 return p*c + cross(axis,p)*s + axis*dot(axis,p)*(1.0-c);
}
void vertex() {
 float clock = preview_time >= 0.0 ? preview_time : TIME;
 float t=clock*cycle_speed*6.2831853+INSTANCE_CUSTOM.y*6.2831853;
 float state=COLOR.a;
 float death=state>=8.0 ? clamp(state-8.0,0.0,1.0) : 0.0;
 float motion=state<=1.01 ? clamp(state,0.0,1.0) : (state>=4.0 && state<4.99 ? 1.0 : 0.0);
 float attack=0.0;
 if(state>=2.0 && state<4.0) attack=clamp(state-2.0,0.0,1.0);
 if(state>=4.0 && state<5.0) attack=1.0;
 if(state>=5.0 && state<7.0) attack=1.0-clamp(state-5.0,0.0,1.0);
  if(state>=7.0 && state<8.0) attack=pow(max(0.0,sin(t*0.65)),2.0);
  if(allied_attack) attack=clamp(INSTANCE_CUSTOM.w,0.0,1.0);
 int joint=clamp(int(UV2.x+0.5),0,31);
 // Maximum authored chain is seven bones (scorpion tail + root).
 for(int depth=0;depth<8;depth++) {
  if(joint<0) break;
  vec4 q=joint_params[joint];vec2 b=joint_bends[joint];float phase=t+q.w;
  float angle=sin(phase)*mix(q.x,q.y,motion)+max(0.0,-cos(phase))*b.x*motion+q.z*attack;
  angle=mix(angle,b.y,clamp(death*1.8,0.0,1.0));
  VERTEX=joint_pivots[joint]+joint_rotate(VERTEX-joint_pivots[joint],joint_axes[joint],angle);
  NORMAL=joint_rotate(NORMAL,joint_axes[joint],angle);
  joint=joint_parents[joint];
 }
 VERTEX.y=max(VERTEX.y,0.0)+hover_height*(1.0-death)+abs(sin(t*2.0))*0.045*motion;
 // Hit recoil is visual and leaves simulation/collision untouched.
 v_flash=INSTANCE_CUSTOM.x;
 VERTEX.z+=v_flash*0.10;
 VERTEX.xz*=1.0+v_flash*0.06;
 VERTEX*=1.0-death*0.9;
  v_glow=UV.x;v_elite=INSTANCE_CUSTOM.z;v_burn=allied_attack ? 0.0 : INSTANCE_CUSTOM.w;v_phase=INSTANCE_CUSTOM.y;
}
void fragment() {
	vec3 base = COLOR.rgb;
	ALBEDO = mix(base, vec3(1.0), v_flash * 0.3);
	ROUGHNESS = 0.8;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	if (spectral) {
		float lum = dot(base, vec3(0.3, 0.55, 0.15));
		ALBEDO = vec3(0.1, 0.25, 0.35) * (0.5 + lum);
		EMISSION = spectral_color * (0.35 + lum * 0.6 + rim * 2.5 + v_glow * 1.5)
				* (0.85 + 0.15 * sin(TIME * 4.0 + v_phase * 6.28))
				+ vec3(0.8, 0.95, 1.0) * v_flash * 0.5;
		if (allied_attack) {
			EMISSION = spectral_color * (0.15 + rim * 1.2 + min(v_glow, 0.8) * 0.5)
					+ vec3(0.72, 0.95, 1.0) * rim * rim * 0.35;
		}
		// Veterans (custom z = rank / 3): a golden rim, brighter with rank.
		EMISSION = mix(EMISSION, EMISSION * vec3(1.5, 1.05, 0.45) + vec3(1.0, 0.7, 0.25) * rim * 2.0, clamp(v_elite * 1.5, 0.0, 1.0));
	} else {
		EMISSION = base * v_glow * glow_strength
				+ rim_color * rim * rim_strength
				+ vec3(1.0, 0.9, 0.85) * v_flash * 0.35
				+ vec3(1.0, 0.72, 0.25) * (rim * 2.2 + 0.1 + 0.08 * sin(TIME * 5.0)) * v_elite
				+ vec3(1.0, 0.4, 0.08) * (0.35 + rim * 1.8) * v_burn * (0.75 + 0.25 * sin(TIME * 23.0 + VERTEX.y * 9.0));
	}
}
