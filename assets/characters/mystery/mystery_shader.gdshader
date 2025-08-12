shader_type spatial;

uniform sampler2D texture_albedo;
uniform float scale = 1.0;

void fragment() {
    vec2 screen_uv = SCREEN_UV * scale;
    vec4 tex = texture(texture_albedo, screen_uv);
    ALBEDO = tex.rgb - vec3(.45, .45, .45);
}
