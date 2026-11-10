shader_type spatial;
render_mode cull_disabled, specular_disabled;

group_uniforms Base;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap;

group_uniforms Soft_Toon;
uniform vec3 shadow_tint : source_color = vec3(0.48, 0.53, 0.66);
uniform vec3 midtone_tint : source_color = vec3(0.78, 0.80, 0.86);
uniform vec3 light_tint : source_color = vec3(1.0, 0.97, 0.91);
uniform float shadow_threshold : hint_range(0.0, 1.0, 0.01) = 0.18;
uniform float light_threshold : hint_range(0.0, 1.0, 0.01) = 0.70;
uniform float band_softness : hint_range(0.01, 0.3, 0.01) = 0.16;
uniform float light_wrap : hint_range(0.0, 0.5, 0.01) = 0.12;

group_uniforms Highlights;
uniform vec3 highlight_color : source_color = vec3(1.0, 0.96, 0.88);
uniform float highlight_strength : hint_range(0.0, 0.5, 0.01) = 0.06;
uniform float highlight_power : hint_range(4.0, 128.0, 1.0) = 32.0;
uniform vec3 rim_color : source_color = vec3(0.78, 0.86, 1.0);
uniform float rim_strength : hint_range(0.0, 0.5, 0.01) = 0.08;
uniform float rim_power : hint_range(1.0, 8.0, 0.1) = 4.0;

void fragment() {
	ALBEDO = albedo_color.rgb * texture(albedo_texture, UV).rgb;
	ROUGHNESS = 0.85;
	SPECULAR = 0.0;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}

void light() {
	float facing = dot(NORMAL, LIGHT);
	float diffuse = clamp((facing + light_wrap) / (1.0 + light_wrap), 0.0, 1.0);
	float midtone = smoothstep(shadow_threshold - band_softness, shadow_threshold + band_softness, diffuse);
	float lit = smoothstep(light_threshold - band_softness, light_threshold + band_softness, diffuse);
	vec3 shading = mix(shadow_tint, midtone_tint, midtone);
	shading = mix(shading, light_tint, lit);
	vec3 radiance = LIGHT_COLOR * ATTENUATION / PI;
	DIFFUSE_LIGHT += shading * radiance;

	float light_mask = smoothstep(0.0, 0.3, facing);
	vec3 half_direction = normalize(LIGHT + VIEW);
	float specular = pow(max(dot(NORMAL, half_direction), 0.0), highlight_power);
	float highlight = smoothstep(0.25, 0.75, specular) * highlight_strength;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power) * rim_strength;
	SPECULAR_LIGHT += (highlight_color * highlight + rim_color * rim) * radiance * light_mask;
}
