shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D position_frames : filter_nearest, repeat_disable;
uniform sampler2D skin : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_skin = false;
uniform int frame_a = 0;
uniform int frame_b = 0;
uniform float frame_mix = 0.0;
uniform vec3 pivot = vec3(0.0);
void vertex() {
	vec3 a = texelFetch(position_frames, ivec2(VERTEX_ID, frame_a), 0).rgb;
	vec3 b = texelFetch(position_frames, ivec2(VERTEX_ID, frame_b), 0).rgb;
	VERTEX = mix(a, b, frame_mix) - pivot;
}
void fragment() {
	vec4 color = has_skin ? texture(skin, UV) : vec4(1.0);
	ALBEDO = color.rgb;
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = 0.3;
}
