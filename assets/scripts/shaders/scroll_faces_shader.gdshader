shader_type canvas_item;

uniform float MOVE_SPEED = 0.2;

void vertex() {
	UV.x += TIME * MOVE_SPEED;
	UV.y += TIME * MOVE_SPEED;
}