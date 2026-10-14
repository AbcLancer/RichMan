shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
uniform sampler2D position_frames : filter_nearest, repeat_disable;
uniform sampler2D normal_frames : filter_nearest, repeat_disable;
uniform sampler2D skin : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_skin = false;
uniform bool has_normals = false;
uniform int frame_a = 0;
uniform int frame_b = 0;
uniform float frame_mix = 0.0;
uniform vec3 pivot = vec3(0.0);
#include "res://scripts/ui/animation_pose.gdshaderinc"
void vertex() {
	VERTEX = animated_position(VERTEX_ID);
	if (has_normals) { NORMAL = animated_normal(VERTEX_ID); }
}
void fragment() {
	vec4 color = has_skin ? texture(skin, UV) : vec4(1.0);
	ALBEDO = color.rgb * 0.24;
	EMISSION = color.rgb * 0.76;
	ROUGHNESS = 0.62;
	SPECULAR = 0.22;
	if (color.a < 0.3) { discard; }
}
