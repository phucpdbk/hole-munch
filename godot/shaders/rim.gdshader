shader_type spatial;
render_mode unshaded;
uniform vec4 color_a : source_color = vec4(0.7,0.6,0.9,1.0);
uniform vec4 color_b : source_color = vec4(0.9,0.8,1.0,1.0);
uniform int style = 0;
uniform float clock = 0.0;
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
	float angle = atan(local_position.z, local_position.x);
	float t = angle * 5.0 + clock;
	float band = 0.22;
	if (style == 1) band = smoothstep(-0.15, 0.15, sin(t*2.0));
	if (style == 2) band = pow(0.5+0.5*sin(t*1.7+sin(t*3.0)), 2.0);
	if (style == 3) band = step(0.55, sin(t*3.0))*0.7;
	if (style == 4) band = pow(0.5+0.5*sin(t*4.0), 10.0);
	if (style == 12) band = smoothstep(0.55, 0.95, sin(angle*10.0+sin(clock+angle*3.0)*0.6))*0.9;
	if (style == 6) band = 0.5+0.5*sin(angle*2.0-clock);
	if (style == 8) band = step(0.0, sin(t*3.0))*0.85;
	if (style == 9) band = step(0.92, fract(angle*12.0/6.2831853))*0.9;
	if (style == 10) band = 0.35+0.35*sin(angle*8.0)+0.3*pow(0.5+0.5*sin(angle*3.0+clock*2.0), 8.0);
	if (style == 11) band = pow(0.5+0.5*cos(angle+clock*2.2), 6.0);
	vec3 color = mix(color_a.rgb, color_b.rgb, band);
	if (style == 7) color = 0.65+0.35*cos(angle+clock*0.4+vec3(0.0,2.1,4.2));
	// Neon rainbow: saturated hue segments sweeping round the rim, as in the 2D skin.
	if (style == 5) color = 0.5+0.5*cos(floor(angle*36.0/6.2831853)/36.0*6.2831853+clock*2.4+vec3(0.0,2.1,4.2));
	ALBEDO = color;
}
