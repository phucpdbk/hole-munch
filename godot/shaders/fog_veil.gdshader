shader_type canvas_item;
// Thick fog over the whole screen with a soft clear window around the saucer.
// One full-screen quad, a few noise taps; no screen texture reads.
uniform vec2 rect_size = vec2(486.0, 864.0);
uniform vec2 center = vec2(243.0, 432.0);
uniform float clear_radius = 120.0;
uniform vec4 tint : source_color = vec4(0.82, 0.86, 0.88, 1.0);
uniform float strength = 0.97;
uniform float clock = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * rect_size;
	// Two drifting layers of wisps, scaled to the screen so phones and tablets match.
	vec2 q = p / max(rect_size.y, 1.0) * 6.0;
	float wisps = noise(q + vec2(clock * 0.11, clock * 0.04)) * 0.6 + noise(q * 2.3 - vec2(clock * 0.07, -clock * 0.05)) * 0.4;
	float d = length(p - center) / max(clear_radius, 1.0);
	float veil = smoothstep(0.55, 1.1, d + (wisps - 0.5) * 0.35);
	COLOR = vec4(tint.rgb * (0.9 + wisps * 0.14), veil * strength * (0.88 + wisps * 0.12));
}
