shader_type spatial;
render_mode unshaded, cull_disabled;
// Black-hole shaft: spiral bands swirl down the wall into a dark vortex floor,
// lit from the rim in the skin colour so the hole reads as deep, not flat.
uniform vec4 glow : source_color = vec4(0.68, 0.6, 0.93, 1.0);
uniform float clock = 0.0;
varying vec3 local_position;
varying float is_floor;
void vertex() {
	local_position = VERTEX;
	is_floor = step(0.5, -NORMAL.y);
}
void fragment() {
	float angle = atan(local_position.z, local_position.x);
	float r = length(local_position.xz);
	vec3 void_colour = vec3(0.015, 0.02, 0.05);
	vec3 colour;
	if (is_floor > 0.5) {
		// Vortex: three arms wind into the centre, which is pure darkness.
		float arms = sin(angle*3.0 + log(max(r, 0.02))*6.0 - clock*3.0);
		float light = smoothstep(0.35, 1.0, arms) * smoothstep(0.05, 0.75, r) * 0.45;
		colour = void_colour + glow.rgb*light;
	} else {
		// depth: 0 at the rim, 1 at the bottom of the 1.8-tall cylinder.
		float depth = clamp((0.9 - local_position.y)/1.8, 0.0, 1.0);
		float spiral = smoothstep(0.25, 1.0, sin(angle*4.0 + depth*9.0 - clock*2.4));
		float rim_light = pow(1.0 - depth, 3.0);
		colour = void_colour + glow.rgb*(rim_light*0.55 + spiral*(1.0 - depth)*0.3);
	}
	ALBEDO = colour;
}
