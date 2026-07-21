shader_type spatial;

render_mode blend_add, depth_draw_opaque, unshaded, cull_disabled;

uniform sampler2D noise_texture : repeat_enable, filter_nearest;
uniform vec4 color_bottom : source_color = vec4(1.0, 0.9, 0.0, 1.0);
uniform vec4 color_mid : source_color = vec4(1.0, 0.4, 0.0, 1.0);
uniform vec4 color_top : source_color = vec4(0.8, 0.1, 0.0, 1.0);
uniform float speed = 1.5;
uniform float distortion_strength = 0.2;
uniform float pixelation = 32.0;
uniform float emission_energy = 2.0;
uniform float transparency : hint_range(0.0, 1.0) = 1.0;

void vertex() {
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
        vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
        vec4(0.0, 1.0, 0.0, 0.0),
        vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
        MODEL_MATRIX[3]
    );
    MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
    vec2 pixelated_uv = floor(UV * pixelation) / pixelation;

    vec2 scroll = pixelated_uv + vec2(0.0, -TIME * speed * -1.0);
    float noise_val = texture(noise_texture, scroll).r;

    float offset = (noise_val - 0.5) * distortion_strength;
    vec2 distorted_uv = pixelated_uv + vec2(offset, 0.0);
    
    float dist_x = abs(distorted_uv.x - 0.5);
    float mask_x = 1.0 - smoothstep(0.0, 0.5, dist_x);
    
    float mask_y = smoothstep(0.1, 0.5, distorted_uv.y); 

    float shape = mask_x * mask_y * 2.0;
    shape = clamp(shape, 0.0, 1.0);

    vec4 fire_color = mix(color_bottom, color_mid, smoothstep(0.0, 0.55, distorted_uv.y));
    fire_color = mix(fire_color, color_top, smoothstep(0.45, 1.0, distorted_uv.y));

    float flame = shape * smoothstep(0.15, 0.95, noise_val);

    ALBEDO = fire_color.rgb;
    EMISSION = fire_color.rgb * flame * emission_energy;
    ALPHA = flame * fire_color.a * transparency;
}
