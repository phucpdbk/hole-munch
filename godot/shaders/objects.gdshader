shader_type spatial;
// Objects are hidden below ground except inside the hole opening, where they
// keep falling into the dark shaft and fade into its depth.
uniform vec2 hole_center = vec2(0.0, 9.0);
uniform float hole_radius = 0.85;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    bool inside_hole = distance(world_position.xz, hole_center) < hole_radius * 0.98;
    if (world_position.y < 0.07 && !inside_hole) discard;
    float depth = clamp(-world_position.y * 0.55, 0.0, 0.85);
    ALBEDO = mix(COLOR.rgb, vec3(0.03, 0.05, 0.1), depth);
    ROUGHNESS = 0.85;
}
