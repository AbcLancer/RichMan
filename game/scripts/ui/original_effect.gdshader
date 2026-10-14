shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform sampler2D position_frames : filter_nearest, repeat_disable;
uniform sampler2D skin : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_frames : filter_nearest, repeat_disable;
uniform bool has_skin = false;
uniform float effect_opacity = 0.45;
uniform int frame_a = 0;
uniform int frame_b = 0;
uniform float frame_mix = 0.0;
uniform vec3 pivot = vec3(0.0);
#include "res://scripts/ui/animation_pose.gdshaderinc"
void vertex() { VERTEX = animated_position(VERTEX_ID); }
void fragment() {
	vec4 color = has_skin ? texture(skin, UV) : vec4(1.0);
	ALBEDO = color.rgb * effect_opacity;
	ALPHA = color.a;
}
