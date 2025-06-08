shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, unshaded;

uniform vec3 new_color : source_color = vec3(0.5);
uniform float min_height : hint_range(-10.0, 10.0) = 0.0;
uniform float max_height : hint_range(-10.0, 10.0) = 1.0;

void fragment() {
    // Color base del cubo
    ALBEDO = new_color;

    // Obtener la posición mundial del fragmento
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float y = world_pos.y;

    // Mapear altura a opacidad (entre min_height y max_height)
    float alpha = clamp((max_height - min_height) / 1.0 - (y - min_height), 0.0, 1.0);
    ALPHA = alpha;
}