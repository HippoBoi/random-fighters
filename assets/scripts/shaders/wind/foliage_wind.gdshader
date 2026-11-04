shader_type spatial;
render_mode world_vertex_coords, cull_disabled, depth_prepass_alpha, diffuse_lambert_wrap, specular_disabled;


#include "wind_field.gdshaderinc"

group_uniforms Foliage;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
uniform float alpha_scissor : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform bool use_vertex_color = false;

uniform vec3 root_tint : source_color = vec3(1.0);
uniform vec3 tip_tint : source_color = vec3(1.0);
uniform float tint_power : hint_range(0.1, 4.0, 0.01) = 1.0;

uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.85;
uniform float backlight_strength : hint_range(0.0, 2.0, 0.01) = 0.25;
uniform vec3 backlight_color : source_color = vec3(0.45, 0.85, 0.3);

group_uniforms;

group_uniforms Wind_Mask;

uniform int wind_mask_mode : hint_enum("UV (0 = tip)", "UV (1 = tip)", "Vertex Color R", "World Height") = 0;

uniform float bend_power : hint_range(0.5, 8.0, 0.01) = 2.0;
uniform float bend_strength : hint_range(0.0, 3.0, 0.01) = 1.0;
uniform float flutter_strength : hint_range(0.0, 1.0, 0.01) = 0.05;
uniform float flutter_speed : hint_range(0.0, 20.0, 0.01) = 3.0;
uniform float pivot_height = 0.0;
uniform float normal_follow : hint_range(0.0, 1.0, 0.01) = 0.65;

uniform float wind_base_height = 0.0;
uniform float wind_height_range = 2.0;

group_uniforms;

varying float v_height;

float foliage_height(vec3 world_pos, vec2 uv, vec4 vertex_color) {
	if (wind_mask_mode == 0) {
		return clamp(1.0 - uv.y, 0.0, 1.0);
	}
	if (wind_mask_mode == 1) {
		return clamp(uv.y, 0.0, 1.0);
	}
	if (wind_mask_mode == 2) {
		return clamp(vertex_color.r, 0.0, 1.0);
	}
	return clamp((world_pos.y - wind_base_height) / max(wind_height_range, 0.001), 0.0, 1.0);
}

void vertex() {
	vec3 world_pos = VERTEX;

	float height01 = foliage_height(world_pos, UV, COLOR);
	float bend_mask = pow(height01, bend_power);

	float phase = wind_instance_phase(INSTANCE_ID);
	float gust;
	vec3 flow = wind_flow(world_pos, phase, gust);

	vec2 dir = wind_dir_2d();
	vec2 perpendicular = vec2(-dir.y, dir.x);
	float flutter = sin(
		TIME * flutter_speed
		+ phase * TAU
		+ dot(world_pos.xz, vec2(0.73, 1.27)) * 0.4
	) * flutter_strength;
	flow.xz += perpendicular * flutter * wind_strength;

	vec3 pivot = MODEL_MATRIX[3].xyz + vec3(0.0, pivot_height, 0.0);
	vec3 relative = world_pos - pivot;

	vec2 flow_xz = flow.xz;
	float flow_length = length(flow_xz);
	if (flow_length > 0.00001) {
		vec2 bend_dir = flow_xz / flow_length;
		vec3 bend_axis = vec3(bend_dir.y, 0.0, -bend_dir.x);
		float angle = clamp(flow_length * bend_strength * bend_mask, -1.5, 1.5);

		relative = wind_rotate_axis(relative, bend_axis, angle);
		NORMAL = normalize(wind_rotate_axis(NORMAL, bend_axis, angle * normal_follow));
	}

	relative.y += flow.y * bend_mask * bend_strength;
	VERTEX = pivot + relative;

	v_height = height01;
}

void fragment() {
	vec2 uv = UV * uv_scale + uv_offset;
	vec4 tex = texture(albedo_texture, uv);

	vec3 base = tex.rgb * albedo_color.rgb;
	if (use_vertex_color) {
		base *= COLOR.rgb;
	}

	float tint_mix = pow(clamp(v_height, 0.0, 1.0), tint_power);
	ALBEDO = base * mix(root_tint, tip_tint, tint_mix);

	ALPHA = tex.a * albedo_color.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	ROUGHNESS = roughness;

	BACKLIGHT = backlight_color * backlight_strength;

	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
