shader_type spatial;

uniform vec3 top_color : source_color = vec3(1.0, 0.1, 0.0);
uniform vec3 bottom_color : source_color = vec3(1.0, 0.8, 0.0);
uniform float scroll_speed : hint_range(0.0, 5.0) = 0.5;
uniform float direction : hint_range(-1.0, 1.0) = -1.0;
uniform float Transparency : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float y = fract(UV.y - TIME * scroll_speed * direction);
	ALBEDO = mix(top_color, bottom_color, y);
	ALPHA = Transparency;
}
