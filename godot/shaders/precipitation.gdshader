shader_type canvas_item;
// Dense rain streaks or snowflakes drawn over the 3D city in a few parallax
// layers (near ones bigger and faster), with a light overcast tint.
// mode 1 = rain, 2 = snow. One full-screen quad, hash noise only.
uniform int mode = 1;
uniform vec2 rect_size = vec2(486.0, 864.0);
uniform float clock = 0.0;
uniform float heavy = 0.0;
uniform float slant = 0.12;
uniform vec4 tint : source_color = vec4(0.16, 0.2, 0.27, 0.14);

// Sin-free hash (stable at mediump on phones).
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float rain_layer(vec2 p, float columns, float rows, float speed, float length_share, float width) {
	p.x += p.y * slant;
	float column = floor(p.x * columns);
	float offset = hash(vec2(column, columns));
	float fall = p.y * rows - clock * speed * (0.8 + offset * 0.4) + offset * 17.0;
	float cell = floor(fall);
	float along = fract(fall);
	// Only some cells hold a drop; heavier weather fills more of them.
	float present = step(0.62 - heavy * 0.22, hash(vec2(column, cell)));
	float streak = smoothstep(0.0, length_share, along) * step(along, length_share);
	float across = abs(fract(p.x * columns) - 0.5);
	return present * streak * (1.0 - smoothstep(width * 0.4, width, across));
}

float snow_layer(vec2 p, float scale, float speed, float size) {
	vec2 q = p * scale + vec2(clock * 0.06 * scale, -clock * speed * scale);
	vec2 cell = floor(q);
	vec2 local = fract(q) - 0.5;
	float seed = hash(cell);
	vec2 spot = (vec2(seed, hash(cell + 3.7)) - 0.5) * 0.6;
	spot.x += sin(clock * 1.4 + seed * 6.283) * 0.16;
	float radius = size * (0.6 + hash(cell + 7.1) * 0.6);
	float flake = 1.0 - smoothstep(radius * 0.35, radius, length(local - spot));
	return flake * step(0.3 - heavy * 0.2, hash(cell + 11.3));
}

void fragment() {
	// Screen-height units, so drop size matches on phones and tablets.
	vec2 p = UV * rect_size / max(rect_size.y, 1.0);
	float amount = 0.0;
	vec3 colour = vec3(0.9, 0.94, 1.0);
	if (mode == 1) {
		amount += rain_layer(p, 26.0, 2.2, 4.4, 0.34, 0.12) * 0.55;
		amount += rain_layer(p + 0.37, 48.0, 3.4, 3.6, 0.28, 0.14) * 0.42;
		amount += rain_layer(p + 0.71, 85.0, 5.0, 3.0, 0.22, 0.16) * 0.3;
	} else {
		colour = vec3(1.0);
		amount += snow_layer(p, 8.0, 0.16, 0.13) * 0.9;
		amount += snow_layer(p + 0.31, 12.0, 0.11, 0.18) * 0.8;
		amount += snow_layer(p + 0.67, 20.0, 0.075, 0.16) * 0.62;
		amount += snow_layer(p + 0.13, 32.0, 0.05, 0.14) * 0.45;
	}
	amount = clamp(amount, 0.0, 1.0);
	float alpha = amount + tint.a * (1.0 - amount);
	vec3 rgb = (colour * amount + tint.rgb * tint.a * (1.0 - amount)) / max(alpha, 0.001);
	COLOR = vec4(rgb, alpha);
}
