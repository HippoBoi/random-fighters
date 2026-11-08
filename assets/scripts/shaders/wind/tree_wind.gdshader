shader_type spatial;
render_mode world_vertex_coords, cull_disabled, depth_prepass_alpha, diffuse_lambert_wrap, specular_disabled;

#include "wind_field.gdshaderinc"

group_uniforms Tree;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
uniform float alpha_scissor : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform bool use_vertex_color = false;

uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.85;
uniform float metallic : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float backlight_strength : hint_range(0.0, 2.0, 0.01) = 0.2;
uniform vec3 backlight_color : source_color = vec3(0.45, 0.85, 0.3);

group_uniforms;

group_uniforms Tree_Motion;

uniform int tree_mode : hint_enum("Trunk (bend)", "Leaves (sway)") = 0;

uniform int pivot_mode : hint_enum("Mesh Origin", "Ground Below Origin") = 0;

uniform float bend_power : hint_range(0.5, 8.0, 0.01) = 2.0;
uniform float bend_strength : hint_range(0.0, 3.0, 0.01) = 0.16;
uniform float flutter_strength : hint_range(0.0, 1.0, 0.01) = 0.04;
uniform float flutter_speed : hint_range(0.0, 20.0, 0.01) = 2.4;

uniform float wind_base_height = -1.0;
uniform float wind_height_range = 7.8;

group_uniforms;

varying float v_height;

float tree_phase(vec3 origin) {
	return fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 up_world = normalize(MODEL_MATRIX[1].xyz);
	float scale_y = max(length(MODEL_MATRIX[1].xyz), 0.0001);

	float local_y = dot(VERTEX - origin, up_world) / scale_y;
	float height01 = clamp((local_y - wind_base_height) / max(wind_height_range, 0.001), 0.0, 1.0);
	v_height = height01;

	float phase = tree_phase(origin);
	float gust;
	vec3 flow_sample_pos = tree_mode == 1 ? origin : VERTEX;
	vec3 flow = wind_flow(flow_sample_pos, phase, gust);

	vec2 dir = wind_dir_2d();
	vec2 perpendicular = vec2(-dir.y, dir.x);
	float flutter = sin(
		TIME * flutter_speed
		+ phase * TAU
		+ dot(VERTEX.xz, vec2(0.73, 1.27)) * 0.4
	) * flutter_strength;
	flow.xz += perpendicular * flutter * wind_strength;

	vec3 pivot = origin;
	if (pivot_mode == 1) {
		pivot = origin + up_world * (wind_base_height * scale_y);
	}

	float bend_mask = 1.0;
	if (tree_mode == 0) {
		bend_mask = pow(height01, bend_power);
	}

	vec3 relative = VERTEX - pivot;
	vec2 flow_xz = flow.xz;
	float flow_length = length(flow_xz);
	if (flow_length > 0.00001) {
		vec2 bend_dir = flow_xz / flow_length;
		vec3 bend_axis = vec3(bend_dir.y, 0.0, -bend_dir.x);
		float angle = clamp(flow_length * bend_strength * bend_mask, -1.5, 1.5);

		relative = wind_rotate_axis(relative, bend_axis, angle);
		NORMAL = normalize(wind_rotate_axis(NORMAL, bend_axis, angle * 0.65));
	}

	relative.y += flow.y * bend_mask * bend_strength;
	VERTEX = pivot + relative;
}

void fragment() {
	vec2 uv = UV * uv_scale + uv_offset;
	vec4 tex = texture(albedo_texture, uv);

	vec3 base = tex.rgb * albedo_color.rgb;
	if (use_vertex_color) {
		base *= COLOR.rgb;
	}

	ALBEDO = base;
	ALPHA = tex.a * albedo_color.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	ROUGHNESS = roughness;
	METALLIC = metallic;

	BACKLIGHT = backlight_color * backlight_strength;

	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
