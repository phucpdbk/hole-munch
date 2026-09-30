shader_type spatial;
// Objects are hidden below ground except inside the hole opening, where they
// keep falling into the dark shaft and fade into its depth.
uniform vec2 hole_center = vec2(0.0, 9.0);
uniform float hole_radius = 0.85;
// Second opening for the rival hole; radius 0 disables it.
uniform vec2 rival_center = vec2(0.0, 0.0);
uniform float rival_radius = 0.0;
uniform float snow_amount = 0.0;
// Journey map: 1 greys out a landmark that is still locked.
uniform float grey = 0.0;
// Only the Meshy landmarks bind a texture; everything else samples plain white.
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap;
varying vec3 world_position;
varying float snow_mask;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float upward = normalize(mat3(MODEL_MATRIX) * NORMAL).y;
    snow_mask = smoothstep(0.35,0.8,upward) * smoothstep(0.65,1.2,VERTEX.y);
}
void fragment() {
    bool inside_hole = distance(world_position.xz, hole_center) < hole_radius * 0.98;
    bool inside_rival = distance(world_position.xz, rival_center) < rival_radius * 0.98;
    if (world_position.y < 0.07 && !inside_hole && !inside_rival) discard;
    // Tall buildings between the camera and the hole turn into a see-through
    // screen door, so towers never hide the player.
    vec3 toward_camera = INV_VIEW_MATRIX[2].xyz;
    if (world_position.y > 0.9 && !inside_hole && toward_camera.y > 0.2) {
        vec2 ground = world_position.xz - toward_camera.xz * (world_position.y / toward_camera.y);
        float reach = distance(ground, hole_center);
        ivec2 cell = ivec2(FRAGCOORD.xy) % 2;
        bool keep = cell.x == 0 && (cell.y == 0 || reach > hole_radius);
        if (reach < hole_radius + 0.8 && !keep) discard;
    }
    float depth = clamp(-world_position.y * 0.55, 0.0, 0.85);
    ALBEDO = mix(COLOR.rgb * texture(albedo_tex, UV).rgb, vec3(0.03, 0.05, 0.1), depth);
    ALBEDO = mix(ALBEDO, vec3(0.88,0.94,1.0), snow_mask*snow_amount*(1.0-depth));
    ALBEDO = mix(ALBEDO, vec3(dot(ALBEDO, vec3(0.3, 0.59, 0.11)) * 0.7 + 0.12), grey);
    ROUGHNESS = 0.85;
}
