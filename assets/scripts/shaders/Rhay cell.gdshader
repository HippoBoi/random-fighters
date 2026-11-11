shader_type spatial;
render_mode cull_disabled, specular_disabled, ambient_light_disabled;

group_uniforms Base;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap;

#include "character_cell_lighting.gdshaderinc"

void fragment() {
	ALBEDO = albedo_color.rgb * texture(albedo_texture, UV).rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
