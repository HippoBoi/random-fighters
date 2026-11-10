shader_type spatial;
render_mode cull_disabled, specular_disabled, ambient_light_disabled;

group_uniforms Base;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap;

group_uniforms Cel_Lighting;
uniform vec3 shadow_tint : source_color = vec3(0.48, 0.52, 0.64);
uniform vec3 midtone_tint : source_color = vec3(0.80, 0.82, 0.88);
uniform vec3 light_tint : source_color = vec3(1.0, 0.98, 0.94);
uniform float shadow_threshold : hint_range(0.0, 1.0, 0.01) = 0.32;
uniform float light_threshold : hint_range(0.0, 1.0, 0.01) = 0.72;
uniform float band_softness : hint_range(0.01, 0.3, 0.01) = 0.06;

group_uniforms Highlights;
uniform vec3 rim_color : source_color = vec3(0.72, 0.80, 1.0);
uniform float rim_strength : hint_range(0.0, 0.5, 0.01) = 0.05;
uniform float rim_power : hint_range(1.0, 8.0, 0.1) = 4.0;

void fragment() {
	ALBEDO = albedo_color.rgb * texture(albedo_texture, UV).rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}

void light() {
	float facing = dot(NORMAL, LIGHT);
	float illumination = clamp(facing * 0.5 + 0.5, 0.0, 1.0) * ATTENUATION;
	float midtone = smoothstep(shadow_threshold - band_softness, shadow_threshold + band_softness, illumination);
	float lit = smoothstep(light_threshold - band_softness, light_threshold + band_softness, illumination);
	vec3 shading = mix(shadow_tint, midtone_tint, midtone);
	shading = mix(shading, light_tint, lit);

	float falloff = LIGHT_IS_DIRECTIONAL ? 1.0 : ATTENUATION;
	vec3 radiance = LIGHT_COLOR * falloff / PI;
	DIFFUSE_LIGHT += shading * radiance;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	SPECULAR_LIGHT += rim_color * rim * rim_strength * max(facing, 0.0) * ATTENUATION * LIGHT_COLOR / PI;
}
