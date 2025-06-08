shader_type canvas_item;

uniform vec4 initial_color : source_color = vec4(1);
uniform vec4 final_color : source_color = vec4(0);
uniform bool vertical = false;

void fragment() {
	if (!vertical) {
		COLOR = mix(initial_color, final_color, UV.x);
	}
	else {
		COLOR = mix(initial_color, final_color, UV.y);
	}
}