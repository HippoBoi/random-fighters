shader_type spatial;

uniform vec4 waterColor : source_color;
uniform float roughness = 0.2;
uniform sampler2D normalmap_a : hint_normal;
uniform sampler2D normalmap_b : hint_normal;
uniform float normalmap_a_strength = 0.3;
uniform float normalmap_b_strength = 0.4;

uniform vec2 moveDirection = vec2(0.1, 0.1);
uniform float moveStrength = 0.5;
uniform float uvScale = 1.0;

uniform float fresnelValue = 3.0;

float fresnel(float amount, vec3 normal, vec3 view) {
	return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0)), amount);
}

void fragment() {
	float newFresnel = fresnel(fresnelValue, NORMAL, VIEW);
	vec2 uv = UV * uvScale;
	vec2 uvMovement = moveDirection * TIME * moveStrength;

	vec3 normalMap = texture(normalmap_a, uv + uvMovement).rgb * normalmap_a_strength;
	normalMap += texture(normalmap_b, uv - uvMovement).rgb * normalmap_b_strength;

	ROUGHNESS = roughness * (1.0 - newFresnel);
	ALBEDO = waterColor.rgb + (0.2 * newFresnel);
	NORMAL_MAP = normalMap;
}
