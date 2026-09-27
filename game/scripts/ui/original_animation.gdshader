shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D position_frames : filter_nearest, repeat_disable;
uniform sampler2D skin : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_frames : filter_nearest, repeat_disable;
uniform bool has_normals = false;
uniform bool has_skin = false;
uniform int frame_a = 0;
uniform int frame_b = 0;
uniform float frame_mix = 0.0;
uniform vec3 pivot = vec3(0.0);
void vertex() {
	vec3 a = texelFetch(position_frames, ivec2(VERTEX_ID, frame_a), 0).rgb;
	vec3 b = texelFetch(position_frames, ivec2(VERTEX_ID, frame_b), 0).rgb;
	VERTEX = mix(a, b, frame_mix) - pivot;
	if (has_normals) {
		vec3 na = texelFetch(normal_frames, ivec2(VERTEX_ID, frame_a), 0).rgb;
		vec3 nb = texelFetch(normal_frames, ivec2(VERTEX_ID, frame_b), 0).rgb;
		NORMAL = normalize(mix(na, nb, frame_mix));
	}
}
void fragment() {
	vec4 color = has_skin ? texture(skin, UV) : vec4(1.0);
	ALBEDO = color.rgb;
	// Original skin already contains painted lighting. A gentle fixed fill gives
	// refined curves volume without washing out the original colors.
	if (has_normals) {
		float fill = max(dot(normalize(NORMAL), normalize(vec3(-0.35, 0.65, 0.68))), 0.0);
		ALBEDO *= 0.85 + 0.15 * fill;
	}
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = 0.3;
}
