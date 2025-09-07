extends CharacterBody3D

var speed: float = 0.1;
var accel: float = 6.0;

var isBig: bool = false;
var dmg: int = 20;
var hitbox: Node3D = null;

func _ready() -> void:
	hitbox = get_node("hitbox");
	
	var area3D: Area3D = hitbox.get_child(0).get_child(0);
	area3D.body_entered.connect(_onHitboxTouched);

func _process(delta: float) -> void:
	var forwardDirection: Vector3 = global_transform.basis.z;
	global_position += (forwardDirection * 0.05) * speed * delta;
	
	speed += accel;

func _onHitboxTouched(other: Node3D):
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		if (isBig):
			var forwardDirection: Vector3 = global_transform.basis.x;
			var pushPosition: Vector3 = (global_position + forwardDirection) * -1;
			dmg = 40;
			PlayerFunc.moveTarget(other, 1.5, pushPosition, 20);
		else:
			PlayerFunc.stunTarget(other, 1.0);
		
		PlayerFunc.dealDamage(self, other, dmg, "", true);
