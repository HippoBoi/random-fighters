shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, skip_vertex_transform;

uniform vec4 streak_color : source_color = vec4(0.88, 0.94, 0.98, 0.65);
uniform sampler2D streak_noise : hint_default_white, filter_linear, repeat_enable;
uniform float noise_scale : hint_range(0.1, 10.0) = 2.0;
uniform float flow_speed : hint_range(0.0, 10.0) = 0.9;
uniform float alpha_power : hint_range(0.1, 4.0) = 1.2;
uniform float core_glow : hint_range(0.0, 4.0) = 1.0;
uniform float sway_strength : hint_range(0.0, 2.0) = 0.6;
uniform float ribbon_length : hint_range(0.1, 12.0) = 3.5;
uniform float ribbon_width : hint_range(0.01, 0.5) = 0.14;
uniform float wind_animation_speed = 1.0;
uniform float wind_amplitude = 1.0;
uniform bool mote_mode = false;
uniform float near_fade_distance : hint_range(0.1, 20.0) = 2.5;
uniform float far_fade_distance : hint_range(1.0, 100.0) = 50.0;

varying vec3 v_world_pos;
varying float v_seed;

float streak_hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void vertex() {
	float seed = INSTANCE_CUSTOM.x;
	v_seed = seed;
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 world_pos;
	float size_variation = mix(0.75, 1.3, streak_hash(seed * 123.4));
	if (mote_mode) {
		world_pos = origin + INV_VIEW_MATRIX[0].xyz * (UV.x - 0.5) * ribbon_width * size_variation
			+ INV_VIEW_MATRIX[1].xyz * (UV.y - 0.5) * ribbon_length * size_variation;
	} else {
		float s = UV.y - 0.5;
		float phase = seed * TAU;
		float t = TIME * wind_animation_speed * flow_speed;
		float wave = mix(4.5, 7.5, streak_hash(seed * 91.7));
		float length_world = ribbon_length * size_variation;
		float amplitude = sway_strength * wind_amplitude * size_variation * (0.7 + INSTANCE_CUSTOM.z * 0.6);
		vec3 forward = normalize(MODEL_MATRIX[1].xyz);
		vec3 side = normalize(MODEL_MATRIX[0].xyz);
		vec3 up = normalize(MODEL_MATRIX[2].xyz);
		float a = s * wave - t + phase;
		float b = s * wave * 1.83 - t * 1.43 + phase * 2.7;
		float c = s * wave * 0.71 - t * 0.73 + phase * 1.3;
		float lateral = sin(a) - sin(-t + phase)
			+ 0.18 * (sin(b) - sin(-t * 1.43 + phase * 2.7));
		float lift = 0.28 * (sin(c) - sin(-t * 0.73 + phase * 1.3));
		vec3 center = origin + forward * s * length_world + amplitude * (side * lateral + up * lift);
		vec3 tangent = forward * length_world + amplitude * (
			side * (wave * cos(a) + 0.18 * wave * 1.83 * cos(b))
			+ up * (0.28 * wave * 0.71 * cos(c))
		);
		vec3 width_axis = cross(tangent, CAMERA_POSITION_WORLD - center);
		width_axis = length(width_axis) > 0.001 ? normalize(width_axis) : INV_VIEW_MATRIX[0].xyz;
		float taper = pow(max(sin(UV.y * PI), 0.001), 0.65);
		world_pos = center + width_axis * (UV.x - 0.5) * ribbon_width * size_variation * taper;
	}
	v_world_pos = world_pos;
	VERTEX = (VIEW_MATRIX * vec4(world_pos, 1.0)).xyz;
}

void fragment() {
	float profile;
	float body = 1.0;
	if (mote_mode) {
		profile = 1.0 - smoothstep(0.1, 1.0, length(UV * 2.0 - 1.0));
	} else {
		float edges = 1.0 - smoothstep(0.1, 1.0, abs(UV.x * 2.0 - 1.0));
		float ends = smoothstep(0.0, 0.12, UV.y) * (1.0 - smoothstep(0.78, 1.0, UV.y));
		profile = edges * ends;
		float noise_value = texture(streak_noise, vec2(
			v_seed * 17.1 + UV.x * 0.25,
			UV.y * noise_scale - TIME * wind_animation_speed * flow_speed * 0.3 + v_seed * 9.7
		)).r;
		body = mix(0.65, 1.0, pow(clamp(noise_value, 0.0, 1.0), alpha_power));
	}
	float distance_to_camera = length(CAMERA_POSITION_WORLD - v_world_pos);
	float distance_fade = smoothstep(0.3, max(near_fade_distance, 0.31), distance_to_camera)
		* (1.0 - smoothstep(far_fade_distance, far_fade_distance + 15.0, distance_to_camera));
	ALBEDO = streak_color.rgb * core_glow;
	ALPHA = profile * body * streak_color.a * COLOR.a * distance_fade;
}
