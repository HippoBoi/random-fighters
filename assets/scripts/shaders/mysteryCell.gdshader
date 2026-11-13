shader_type spatial;
render_mode cull_disabled, specular_disabled, ambient_light_disabled;

group_uniforms Base;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap;
uniform sampler2D cloth_texture : hint_default_white, filter_linear_mipmap;
uniform float cloth_scale = 1.0;
uniform float cloth_offset = 0.0;

#include "characterCellLighting.gdshaderinc"

void fragment() {
	vec3 cloth = texture(cloth_texture, SCREEN_UV * cloth_scale).rgb - vec3(cloth_offset);
	ALBEDO = albedo_color.rgb * texture(albedo_texture, UV).rgb * cloth;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
