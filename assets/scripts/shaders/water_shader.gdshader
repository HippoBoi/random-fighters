shader_type spatial;

uniform vec4 waterColor : source_color;
uniform vec4 secondaryColor : source_color;

uniform float roughness = 0.2;
uniform sampler2D normalmap_a : hint_normal;
uniform sampler2D normalmap_b : hint_normal;
uniform float normalmap_a_strength = 0.3;
uniform float normalmap_b_strength = 0.4;

uniform vec2 moveDirection = vec2(0.1, 0.1);
uniform float moveStrength = 0.5;
uniform float uvScale = 1.0;

uniform float fresnelValue = 3.0;

uniform sampler2D screenTexture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depthTexture : hint_depth_texture, repeat_disable, filter_nearest;

uniform float depthDistance : hint_range(0.0, 20.0, 0.1) = 4.0;
uniform float beersLaw : hint_range(0.0, 20.0, 0.1) = 12.0;
uniform float waterTransparency : hint_range(0.0, 1.0, 0.01) = 0.05;

uniform sampler2D depth_texture : hint_depth_texture;
uniform sampler2D screen_texture : hint_screen_texture;

float fresnel(float amount, vec3 normal, vec3 view) {
	return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0)), amount);
}

void fragment() {
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec3 screen = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	
	float newFresnel = fresnel(fresnelValue, NORMAL, VIEW);
	vec2 uv = UV * uvScale;
	vec2 uvMovement = moveDirection * TIME * moveStrength;

	vec3 normalMap = texture(normalmap_a, uv + uvMovement).rgb * normalmap_a_strength;
	normalMap += texture(normalmap_b, uv - uvMovement).rgb * normalmap_b_strength;

	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	
	float depthTextureY = world.y / world.w;
	float vertexY = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y;

	float depthBlend = clamp((vertexY - depthTextureY) / depthDistance, 0.0, 1.0);
	depthBlend = exp(-depthBlend * beersLaw);

	vec3 depthColor = mix(secondaryColor, waterColor, depthBlend).rgb;
	vec3 finalColor = mix(depthColor.rgb, screen, waterTransparency);

	ALBEDO = mix(finalColor, screen, depthBlend * (1.0 - newFresnel));
	ROUGHNESS = roughness * (1.0 - newFresnel);
	NORMAL_MAP = normalMap;
}
