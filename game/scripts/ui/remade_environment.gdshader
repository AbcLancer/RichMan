shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D skin : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wood_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec4 base = texture(skin, UV);
    if (base.a < 0.3) { discard; }
    vec3 n = abs(normalize(cross(dFdx(world_position), dFdy(world_position))));
    n = pow(n, vec3(4.0));
    n /= max(n.x + n.y + n.z, 0.001);
    vec2 detail_uv = world_position.yz * n.x + world_position.xz * n.y + world_position.xy * n.z;
    detail_uv *= 0.12;
    vec3 c = base.rgb;
    float green = smoothstep(0.015, 0.10, c.g - max(c.r, c.b));
    float warm = smoothstep(0.035, 0.15, c.r - c.b) * (1.0 - green);
    float wood = warm * (1.0 - smoothstep(0.14, 0.30, dot(c, vec3(0.333)))) * smoothstep(0.1, 0.4, c.g / max(c.r, 0.001));
    float sand = warm - wood;
    float stone = max(0.0, 1.0 - green - warm);
    // Preserve source road markings, baked shadows and architecture. Only fine
    // material variation comes from the new artwork; no map coordinates change.
    vec3 detail = texture(grass_detail, detail_uv).rgb * green * vec3(3.05, 2.50, 5.60)
        + texture(sand_detail, detail_uv).rgb * sand * vec3(1.34, 1.98, 4.4)
        + texture(stone_detail, detail_uv).rgb * stone * vec3(1.78, 1.86, 2.00)
        + texture(wood_detail, detail_uv).rgb * wood * vec3(1.50, 3.10, 10.0);
    detail = clamp(detail, vec3(0.65), vec3(1.35));
    ALBEDO = c * mix(vec3(1.0), detail, 0.30);
}
