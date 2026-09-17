shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_toon, specular_toon;

uniform vec4 albedo: source_color;
uniform sampler2D color_gradient;
uniform sampler2D fresnel_gradient;
uniform float color_flow_speed: hint_range(0.0, 10.0, 0.05) = 2.0;
uniform float color_flow_scale: hint_range(0.0, 20.0, 0.1) = 4.0;
uniform float color_flow_strength: hint_range(0.0, 1.0, 0.01) = 0.2;

varying float color_flow_position;

float fresnel(float amount, vec3 normal, vec3 view) {
	return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0)), amount);
}

void vertex() {
	color_flow_position = VERTEX.y;
}

void fragment() {
	float basic_fresnel = fresnel(4.0, NORMAL, VIEW);
	ALBEDO = albedo.rgb + (basic_fresnel * texture(fresnel_gradient, vec2(basic_fresnel, 0.0)).rgb * 1.0);
}

void light() {
	float dot_product = clamp(dot(NORMAL, LIGHT), -0.9, 0.9);
	float color_flow = sin((color_flow_position * color_flow_scale) - (TIME * color_flow_speed));
	float sample = clamp(
		((dot_product + 1.0) * ATTENUATION / 2.1) + (color_flow * color_flow_strength),
		0.05,
		0.95
	);
	vec4 shaded = texture(color_gradient, vec2(sample, 0.0));

	DIFFUSE_LIGHT += clamp((shaded.rgb * LIGHT_COLOR), 0.0, 1.0);
}
