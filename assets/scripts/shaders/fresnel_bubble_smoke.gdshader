shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

// Screen texture for refraction
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Fresnel & depth colors
uniform sampler2D depth_texture : source_color, hint_depth_texture;
uniform vec4 color1 : source_color = vec4(1,1,1,0.1);
uniform vec4 color2 : source_color = vec4(1,1,1,1.0);
uniform float threshold = 0.2;
uniform float fresnel_sharpness = 1.0;

// Master control
group_uniforms master;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform float intensity_2 : hint_range(0.0, 1.0) = 1.0;

// Black hole distortion
group_uniforms blackhole;
uniform bool distortion_enabled = true;
uniform float distortion_strength : hint_range(0.0, 2.0) = 0.6;
uniform float edge_distortion_power : hint_range(1.0, 5.0) = 2.5;
uniform float chromatic_aberration : hint_range(0.0, 0.1) = 0.03;
uniform float event_horizon_radius : hint_range(0.0, 1.0) = 0.3;
uniform float event_horizon_darkness : hint_range(0.0, 1.0) = 0.85;

// Blur effect
group_uniforms blur;
uniform bool blur_enabled = true;
uniform float blur_amount : hint_range(0.0, 10.0) = 3.0;
uniform int blur_samples : hint_range(4, 16) = 8;

// Accretion disk glow
group_uniforms accretion;
uniform vec3 accretion_color : source_color = vec3(1.0, 0.6, 0.2);
uniform float accretion_intensity : hint_range(0.0, 3.0) = 1.2;
uniform float accretion_width : hint_range(1.0, 10.0) = 3.0;

// SDF Noise dissolve effect
group_uniforms dissolve;
uniform int noise_detail : hint_range(1, 8) = 4;
uniform float noise_inflate : hint_range(0.0, 1.0) = 0.1;
uniform float noise_speed : hint_range(0.0, 1.0) = 0.1;
uniform bool invert_dissolve = false;
// Base values (will be interpolated by intensity_2)
uniform float noise_scale_min : hint_range(0.1, 10.0) = 2.0;
uniform float noise_scale_max : hint_range(0.1, 10.0) = 4.0;
uniform float noise_roughness_min : hint_range(0.0, 1.0) = 0.5;
uniform float noise_roughness_max : hint_range(0.0, 1.0) = 0.3;

// Collision ripple effect
group_uniforms ripple;
uniform bool ripple_enabled = true;
uniform float ripple_time = 0.0;
uniform float ripple_frequency : hint_range(1.0, 30.0) = 12.0;
uniform float ripple_speed : hint_range(0.0, 10.0) = 3.0;
uniform float ripple_amplitude : hint_range(0.0, 0.3) = 0.08;
uniform float ripple_fade_distance : hint_range(0.1, 5.0) = 1.5;
uniform vec3 ripple_center = vec3(0.0, -1.0, 0.0);

varying vec3 world_position;
varying vec3 world_normal;
varying vec3 object_position;

// SDF noise functions
float smin(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0);
    return min(a, b) - h * h * 0.25 / k;
}

float smax(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0);
    return max(a, b) + h * h * 0.25 / k;
}

float sph(vec3 i, vec3 f, vec3 c) {
    vec3 p = 17.0 * fract((i + c) * 0.3183099 + vec3(0.11, 0.17, 0.13));
    float w = fract(p.x * p.y * p.z * (p.x + p.y + p.z));
    float r = 0.7 * w * w;
    return length(f - c) - r;
}

float sdBase(in vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    return min(min(min(sph(i, f, vec3(0,0,0)),
                       sph(i, f, vec3(0,0,1))),
                   min(sph(i, f, vec3(0,1,0)),
                       sph(i, f, vec3(0,1,1)))),
               min(min(sph(i, f, vec3(1,0,0)),
                       sph(i, f, vec3(1,0,1))),
                   min(sph(i, f, vec3(1,1,0)),
                       sph(i, f, vec3(1,1,1)))));
}

mat3 y_rot(float angle) {
    return mat3(
        vec3(cos(angle), 0.0, -sin(angle)),
        vec3(0.0, 1.0, 0.0),
        vec3(sin(angle), 0.0, cos(angle))
    );
}

float sdFbm(in vec3 p, in int detail, in float rough, in float inflate, in float smooth_fac, in float d) {
    float s = 1.0;
    for(int i = 0; i < min(detail, 8); i++) {
        float n = s * sdBase(p);
        n = smax(n, d - inflate * s, smooth_fac * s);
        d = smin(n, d, smooth_fac * s);
        p = mat3(vec3(0.00, 1.60, 1.20),
                 vec3(-1.60, 0.72, -0.96),
                 vec3(-1.20, -0.96, 1.280)) * p;
        s = rough * s;
    }
    return d;
}

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
    object_position = VERTEX;
}

void fragment() {
    // Calculate edge factor (0 at center, 1 at edges)
    float view_dot = abs(dot(normalize(VIEW), NORMAL));
    float edge_factor = 1.0 - view_dot;
    float edge_power = pow(edge_factor, edge_distortion_power);

    // --- Ripple calculation ---
    float ripple_offset = 0.0;
    float ripple_glow = 0.0;

    if (ripple_enabled && ripple_time > 0.0) {
        float dist = distance(world_position, ripple_center);
        float wave_phase = dist * ripple_frequency - ripple_time * ripple_speed;
        float wave = sin(wave_phase) * 0.5 + 0.5;
        float fade = exp(-dist * ripple_fade_distance) * (1.0 - ripple_time);
        ripple_offset = wave * ripple_amplitude * fade;
        ripple_glow = wave * fade * 0.5;
    }

    // --- Black hole screen distortion with blur ---
    vec3 final_color = vec3(0.0);

    if (distortion_enabled) {
        float distortion = (distortion_strength * edge_power * intensity) + ripple_offset;
        vec2 distort_vec = NORMAL.xy * distortion;

        float angle = edge_factor * 0.5;
        mat2 rotation = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle)));
        distort_vec = rotation * distort_vec;

        vec2 base_uv = SCREEN_UV + distort_vec;

        if (blur_enabled && intensity > 0.0) {
            vec3 blur_sum = vec3(0.0);
            float blur_size = blur_amount * 0.001 * intensity;

            for (int i = 0; i < blur_samples; i++) {
                float angle_offset = float(i) * 6.28318 / float(blur_samples);
                vec2 offset = vec2(cos(angle_offset), sin(angle_offset)) * blur_size;
                float chroma = chromatic_aberration * edge_power * intensity;

                blur_sum.r += texture(SCREEN_TEXTURE, base_uv + offset + vec2(chroma, 0.0)).r;
                blur_sum.g += texture(SCREEN_TEXTURE, base_uv + offset).g;
                blur_sum.b += texture(SCREEN_TEXTURE, base_uv + offset - vec2(chroma, 0.0)).b;
            }

            final_color = blur_sum / float(blur_samples);
        } else {
            float chroma = chromatic_aberration * edge_power * intensity;
            final_color.r = texture(SCREEN_TEXTURE, base_uv + vec2(chroma, 0.0)).r;
            final_color.g = texture(SCREEN_TEXTURE, base_uv).g;
            final_color.b = texture(SCREEN_TEXTURE, base_uv - vec2(chroma, 0.0)).b;
        }

        float event_horizon_mask = smoothstep(event_horizon_radius, 1.0, edge_factor);
        final_color *= mix(1.0 - event_horizon_darkness * intensity, 1.0, event_horizon_mask);

        float accretion_mask = pow(edge_factor, accretion_width) * accretion_intensity * intensity;
        final_color += accretion_color * accretion_mask;

    } else {
        final_color = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
    }

    // --- Depth comparison for collision effect ---
    float depth = texture(depth_texture, SCREEN_UV).x;
    vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
    vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
    view.xyz /= view.w;
    float linear_depth = -view.z;

    float object_depth = FRAGCOORD.z;
    vec3 object_ndc = vec3(SCREEN_UV * 2.0 - 1.0, object_depth);
    vec4 object_view = INV_PROJECTION_MATRIX * vec4(object_ndc, 1.0);
    object_view.xyz /= object_view.w;
    float linear_object_depth = -object_view.z;

    // Fresnel
    float fresnel = pow(1.0 - view_dot, fresnel_sharpness) * intensity;

    vec4 base_col;
    if (linear_depth - linear_object_depth > threshold) {
        base_col = color1;
    } else {
        base_col = color2;
    }

    base_col.a *= intensity;

    if (ripple_enabled && ripple_time > 0.0 && linear_depth - linear_object_depth <= threshold) {
        base_col.rgb += vec3(0.4, 0.7, 1.0) * ripple_glow * 2.0;
    }

    // --- SDF Noise dissolve effect (controlled by intensity_2) ---
    float dissolve_alpha = 1.0;

    // Interpolate parameters based on intensity_2
    // intensity_2 = 0: smooth, sharp dissolve
    // intensity_2 = 1: rough, soft dissolve
    float noise_smoothness = mix(0.6, 0.01, intensity_2);
    float dissolve_sharpness = mix(50.0, 1.0, intensity_2);
    float noise_scale = mix(noise_scale_min, noise_scale_max, intensity_2);
    float noise_roughness = mix(noise_roughness_min, noise_roughness_max, intensity_2);

    vec3 noise_pos = object_position;
    vec3 noise_offset = vec3(0.0, -TIME * noise_speed, 0.0);
    noise_pos = y_rot(noise_pos.y * 10.0) * noise_pos;
    noise_pos = noise_pos * noise_scale + noise_offset;

    float sphere_dist = length(object_position) - 0.5;
    float noise_dist = sdFbm(noise_pos, noise_detail, noise_roughness,
                              noise_inflate, noise_smoothness, sphere_dist);

    // Convert to alpha with sharp cutoff
    float noise_alpha_raw = 1.0 - clamp(-noise_dist * dissolve_sharpness, 0.0, 1.0);
    noise_alpha_raw = pow(noise_alpha_raw, 2.0);

    // Invert if needed
    if (invert_dissolve) {
        noise_alpha_raw = 1.0 - noise_alpha_raw;
    }

    // Apply dissolve effect
    dissolve_alpha = noise_alpha_raw;

    // Blend distorted background with base color
    float distortion_blend = edge_factor * 0.7;
    if (linear_depth - linear_object_depth <= threshold) {
        distortion_blend *= 0.3;
    }

    ALBEDO = mix(base_col.rgb, final_color, distortion_blend);
    // intensity controls overall transparency, dissolve_alpha controls the noise pattern
    ALPHA = (base_col.a + fresnel) * dissolve_alpha * intensity;
}
