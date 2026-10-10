shader_type spatial;
// Guardian attack beams (mascot_attacks.gd) on an uncapped unit cylinder that runs
// from the mouth (y = -0.5) to the tip (y = +0.5).
// style 0 = water: a jet widening from the nozzle, foam streaks rushing along it.
// style 1 = fire: a flickering cone, white-hot core to ragged red edges.
// style 2 = lightning: a white core inside a tinted glow, strobing.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform int style = 0;
uniform vec4 core_color : source_color = vec4(1.0);
uniform vec4 edge_color : source_color = vec4(0.3, 0.75, 1.0, 1.0);
// World length of the beam, so the pattern keeps its size as the beam grows.
uniform float beam_length = 6.0;
uniform float opacity = 1.0;

varying float along;
varying float around;

// Sin-free hash (stable at mediump on phones).
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(cell);
	float b = hash(cell + vec2(1.0, 0.0));
	float c = hash(cell + vec2(0.0, 1.0));
	float d = hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	along = VERTEX.y + 0.5;
	around = atan(VERTEX.z, VERTEX.x) / 6.2832 + 0.5;
	float profile = 1.0;
	if (style == 0) {
		profile = mix(0.45, 1.3, sqrt(along));
	} else if (style == 1) {
		profile = mix(0.3, 1.6, along) * (0.88 + 0.16 * sin(TIME * 23.0 + along * 11.0));
	}
	VERTEX.xz *= profile;
	// A travelling wave so the jet snakes a little instead of being a rod.
	if (style < 2) {
		VERTEX.x += sin(along * beam_length * 1.1 - TIME * 13.0) * 0.18 * along;
		VERTEX.z += cos(along * beam_length * 0.8 - TIME * 11.0) * 0.12 * along;
	}
}

void fragment() {
	// 1 where the tube faces the camera, 0 at its silhouette: soft round edges.
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float start_fade = smoothstep(0.0, 0.06, along);
	vec3 color;
	float alpha;
	if (style == 0) {
		float streaks = noise(vec2(around * 7.0, along * beam_length * 0.45 - TIME * 4.5));
		float ripples = noise(vec2(around * 13.0 + 4.1, along * beam_length * 1.3 - TIME * 7.0));
		float foam = smoothstep(0.55, 0.85, streaks * 0.65 + ripples * 0.45);
		color = mix(edge_color.rgb, core_color.rgb, smoothstep(0.35, 1.0, facing) * 0.6);
		color = mix(color, vec3(1.0), foam);
		alpha = smoothstep(0.0, 0.5, facing) * 0.8 + foam * 0.3;
	} else if (style == 1) {
		float lick = noise(vec2(around * 5.0, along * beam_length * 0.6 - TIME * 6.0));
		float flick = noise(vec2(around * 11.0 + 2.7, along * beam_length * 1.4 - TIME * 10.0));
		float heat = facing * 0.95 + (lick * 0.6 + flick * 0.4) * 0.55 - along * 0.4;
		color = mix(edge_color.rgb, vec3(1.0, 0.62, 0.18), smoothstep(0.25, 0.6, heat));
		color = mix(color, core_color.rgb, smoothstep(0.7, 1.0, heat));
		alpha = smoothstep(0.18, 0.42, heat);
	} else {
		float core = smoothstep(0.45, 0.95, facing);
		float strobe = 0.7 + 0.3 * step(0.4, hash(vec2(floor(TIME * 28.0), 3.0)));
		color = mix(edge_color.rgb, core_color.rgb, core);
		alpha = (0.3 + 0.7 * core) * strobe * smoothstep(0.0, 0.25, facing);
	}
	ALBEDO = color;
	ALPHA = clamp(alpha * start_fade * opacity, 0.0, 1.0);
}
