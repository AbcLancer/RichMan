// Interpolate frames within a clip, then blend the previous pose into the new clip.
uniform int previous_a = 0;
uniform int previous_b = 0;
uniform float previous_mix = 0.0;
uniform float pose_mix = 1.0;

vec3 animated_position(int id) {
	vec3 current = mix(texelFetch(position_frames, ivec2(id, frame_a), 0).rgb,
		texelFetch(position_frames, ivec2(id, frame_b), 0).rgb, frame_mix);
	if (pose_mix < 1.0) {
		vec3 previous = mix(texelFetch(position_frames, ivec2(id, previous_a), 0).rgb,
			texelFetch(position_frames, ivec2(id, previous_b), 0).rgb, previous_mix);
		current = mix(previous, current, pose_mix);
	}
	return current - pivot;
}

vec3 animated_normal(int id) {
	vec3 current = mix(texelFetch(normal_frames, ivec2(id, frame_a), 0).rgb,
		texelFetch(normal_frames, ivec2(id, frame_b), 0).rgb, frame_mix);
	if (pose_mix < 1.0) {
		vec3 previous = mix(texelFetch(normal_frames, ivec2(id, previous_a), 0).rgb,
			texelFetch(normal_frames, ivec2(id, previous_b), 0).rgb, previous_mix);
		current = mix(previous, current, pose_mix);
	}
	return normalize(current);
}
