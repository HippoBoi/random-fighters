shader_type spatial;
render_mode unshaded, cull_back;

uniform float bladeHeight = 0.5;
uniform float bladeWidth = 0.05;
uniform float density = 0.1;

uniform vec3 baseColor : source_color = vec3(0.0, 0.0, 0.0);
uniform vec3 tipColor : source_color = vec3(0.0, 0.0, 0.0);

varying float heightRatio;

uniform float windStrength = 0.2;
uniform float randomMultiplier = 10.0;

float rand(vec2 coordinate) {
	return fract(sin(dot(coordinate.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	float rnd = rand(VERTEX.xz * randomMultiplier);

	if (rnd > 1.0 - density) {
		float height = bladeHeight * (0.5 + rand(vec2(VERTEX.z, VERTEX.x)) * 0.5);
		float sway = sin(TIME * VERTEX.x * 2.0 + rnd * 10.0) * windStrength;

		VERTEX.y += height;
		VERTEX.x += sin(rnd * randomMultiplier) * bladeWidth + sway;
		VERTEX.z += cos(rnd * randomMultiplier) * bladeWidth;

		heightRatio = clamp(VERTEX.y / (bladeHeight * 2.0), 0.2, 1.0);
	}
	else {
		heightRatio = 0.0;
	}
}

void fragment() {
	ALBEDO = mix(baseColor, tipColor, heightRatio);
}
