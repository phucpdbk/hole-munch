shader_type spatial;
// Ground trails (ground_trail.gd): a ribbon lying on the street behind the hole.
// UV.x runs across the ribbon, UV.y along it in world units; COLOR.a is the
// point's remaining life (1 fresh, 0 gone). Mode 0 is a soft rainbow band,
// mode 1 a fire that flickers and burns out from its ragged edges.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform int mode = 0;
uniform vec2 hole_center = vec2(0.0, 9.0);
uniform float hole_radius = 0.85;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

vec3 rainbow(float t) {
	// Seven bands blended softly: red, orange, yellow, green, cyan, blue, violet.
	return clamp(abs(fract(t * 0.85 + vec3(0.0, 0.667, 0.333)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

void fragment() {
	if (distance(world_position.xz, hole_center) < hole_radius * 1.05) discard;
	float life = COLOR.a;
	float across = abs(UV.x * 2.0 - 1.0);
	if (mode == 0) {
		float edge = 1.0 - smoothstep(0.75, 1.0, across);
		ALBEDO = mix(rainbow(UV.x), vec3(1.0), 0.18);
		ALPHA = edge * life * 0.62;
	} else {
		vec2 p = world_position.xz * 1.6 + vec2(0.0, -TIME * 2.2);
		float flicker = noise(p) * 0.65 + noise(p * 2.7 + TIME) * 0.35;
		// Hot along the middle, ragged at the edges, and thinner as it burns out.
		float heat = (1.0 - across) * 1.15 + flicker * 0.55 - (1.0 - life) * 0.7;
		if (heat < 0.35) discard;
		vec3 ember = vec3(0.85, 0.12, 0.02);
		vec3 flame = vec3(1.0, 0.52, 0.05);
		vec3 core = vec3(1.0, 0.92, 0.45);
		ALBEDO = mix(mix(ember, flame, smoothstep(0.35, 0.75, heat)), core, smoothstep(0.85, 1.25, heat));
		ALPHA = smoothstep(0.35, 0.55, heat) * clamp(life * 1.6, 0.0, 1.0) * 0.92;
	}
}
