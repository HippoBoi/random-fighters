shader_type canvas_item;

uniform float height: hint_range(0.0, 0.5, 0.01) = 0.0;//Rectangle height
uniform float width: hint_range(0.0, 0.5, 0.01) = 0.0;//Rectangle width
uniform float radius: hint_range(0.0, 0.5, 0.01) = 0.0;//Rectangle corner radius
uniform float speed: hint_range(0.0, 1.0, 0.01) = 0.0;//Distortion speed
uniform float edge_source: hint_range(0.0, 1.0, 0.01) = 0.0;//Distortion strength
uniform vec4 edge_color : source_color;//Edge color
uniform vec4 inner_color : source_color;//Inner color


uniform sampler2D noise;


//Signed distance function for rounded rectangle
float sd_round_rect(vec2 p, vec2 s, float r)
{
    vec2 q = abs(p) - s + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void fragment() {
	vec2 uv = UV;
	float noise_r = texture(noise, fract(TIME * speed + uv)).r;
	//Animate noise texture over time
	float d = sd_round_rect(uv - 0.5, vec2(width, height) ,radius); 

	//Get SDF UV map of the rectangle
	float m = step(d - noise_r * 0.1, 0.0);
	float m2 = step(d - noise_r * 0.1 - 0.05, 0.0);
	float m3 = m2 - m;

	vec4 edge = m3 * edge_color;
	vec4 inner = m * inner_color; 
	//Blend both, reduce distortion intensity by *0.1
	COLOR = mix(edge, inner, inner.a);
}