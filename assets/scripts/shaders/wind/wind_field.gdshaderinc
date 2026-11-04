group_uniforms Wind;

uniform sampler3D wind_noise : filter_linear, repeat_enable;

uniform vec2 wind_direction = vec2(1.0, 0.25);
uniform float wind_strength : hint_range(0.0, 4.0, 0.01) = 0.35;
uniform float wind_speed : hint_range(0.0, 10.0, 0.01) = 1.0;

uniform float wind_noise_scale : hint_range(0.001, 1.0, 0.001) = 0.12;
uniform float wind_noise_speed : hint_range(0.0, 10.0, 0.01) = 1.0;

uniform float wind_gust_scale : hint_range(0.001, 0.5, 0.001) = 0.035;
uniform float wind_gust_speed : hint_range(0.0, 10.0, 0.01) = 0.35;
uniform float wind_gust_strength : hint_range(0.0, 2.0, 0.01) = 0.8;

uniform float wind_turbulence : hint_range(0.0, 2.0, 0.01) = 0.3;
uniform float wind_swirl : hint_range(0.0, 3.14, 0.01) = 0.5;
uniform float wind_vertical_strength : hint_range(-1.0, 1.0, 0.01) = 0.12;
uniform float wind_vertical_speed : hint_range(-2.0, 2.0, 0.01) = 0.08;

group_uniforms;

vec2 wind_dir_2d() {
	float len = length(wind_direction);
	return len > 0.0001 ? wind_direction / len : vec2(1.0, 0.0);
}

float wind_hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

float wind_instance_phase(int instance_id) {
	return wind_hash(float(instance_id) * 1.6180339 + 0.37);
}

vec3 wind_rotate_axis(vec3 v, vec3 axis, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

vec3 wind_sample(vec3 world_pos, float phase, out float gust_out) {
	vec2 dir = wind_dir_2d();
	vec3 wind_axis = vec3(dir.x, 0.0, dir.y);
	float t = TIME * wind_speed;

	vec3 detail_pos = world_pos - wind_axis * (t * wind_noise_speed);
	detail_pos.y -= TIME * wind_vertical_speed;

	vec3 gust_pos = vec3(world_pos.x, 0.0, world_pos.z) - wind_axis * (t * wind_gust_speed);

	float detail = textureLod(
		wind_noise,
		detail_pos * wind_noise_scale + vec3(phase * 0.37, phase * 0.19, phase * 0.23),
		0.0
	).r;

	float gust_noise = textureLod(
		wind_noise,
		gust_pos * wind_gust_scale,
		0.0
	).r;

	float swirl_noise = textureLod(
		wind_noise,
		gust_pos * (wind_gust_scale * 0.6) + vec3(17.3, 4.7, 9.1),
		0.0
	).r;

	float gust = smoothstep(0.3, 0.75, gust_noise);
	gust_out = gust;

	float angle = (swirl_noise - 0.5) * wind_swirl;
	float cs = cos(angle);
	float sn = sin(angle);
	vec2 swirl_dir = vec2(
		dir.x * cs - dir.y * sn,
		dir.x * sn + dir.y * cs
	);

	vec2 perpendicular = vec2(-swirl_dir.y, swirl_dir.x);
	vec3 flow = vec3(swirl_dir.x, 0.0, swirl_dir.y) * (1.0 + gust * wind_gust_strength);

	flow.xz += perpendicular * ((detail - 0.5) * 2.0 * wind_turbulence);
	flow.y = (detail - 0.5) * 2.0 * wind_vertical_strength + gust * wind_vertical_strength;

	return flow;
}

vec3 wind_flow(vec3 world_pos, float phase, out float gust_out) {
	return wind_sample(world_pos, phase, gust_out) * wind_strength;
}
