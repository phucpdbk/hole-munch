shader_type spatial;
render_mode cull_back;
uniform vec2 hole_center = vec2(0.0, 9.0);
uniform float hole_radius = 0.85;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    if (distance(world_position.xz, hole_center) < hole_radius) discard;
    ALBEDO = COLOR.rgb;
    ROUGHNESS = 0.95;
}
