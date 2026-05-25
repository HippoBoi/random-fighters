shader_type spatial;
render_mode cull_disabled;

uniform vec3 color : source_color;
uniform vec3 secondaryColor : source_color;

uniform sampler2D noise;
uniform float noiseScale = 20.0;
uniform vec2 windDirection = vec2(1.0, 0.25);
uniform float windStrength = 0.12;
uniform float windSpeed = 1.5;
uniform float windScale = 3.0;
uniform float tipInfluence = 1.0;

varying vec3 worldPos;

void vertex() {
	worldPos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	float directionLength = length(windDirection);
	vec2 direction = directionLength > 0.001 ? windDirection / directionLength : vec2(1.0, 0.0);

	vec2 windUv = worldPos.xz / max(noiseScale, 0.001);
	float windNoise = texture(noise, windUv + direction * TIME * windSpeed * 0.08).r;
	float wave = sin(dot(worldPos.xz, direction) / max(windScale, 0.001) + TIME * windSpeed + windNoise * TAU);

	float tipMask = pow(clamp(1.0 - UV.y, 0.0, 1.0), max(tipInfluence, 0.001));
	float sway = (wave * 0.5 + windNoise - 0.5) * windStrength * tipMask;

	VERTEX.xz += direction * sway;
	worldPos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = mix(color, secondaryColor, UV.y);

	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
