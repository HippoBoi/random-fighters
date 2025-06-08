extends Node3D

@onready var spawnTimer = $spawnTimer;
@onready var laserModel = $laserStuff/laser;
@onready var laserHitbox = $laserStuff/laser/MeshInstance3D/Area3D;
@onready var hitbox = $laserStuff/hitbox;

var alreadyHit = [];

var dmg = 0;
var team;

func setup(_team, _dmg):
	team = _team;
	dmg = _dmg;
	alreadyHit = [];

func _ready() -> void:
	laserModel.visible = false;
	laserHitbox.monitoring = false;
	hitbox.get_node("MeshInstance3D").get_node("Area3D").monitoring = false;

func _on_spawn_timer():
	laserModel.visible = true;
	laserHitbox.monitoring = true;
	hitbox.get_node("MeshInstance3D").get_node("Area3D").monitoring = true;
	$AnimationPlayer.play("attack");

func _on_timer_timeout() -> void:
	hitbox.get_node("MeshInstance3D").get_node("Area3D").monitoring = false;
	laserHitbox.monitoring = false;
	
	await get_tree().create_timer(0.75).timeout;
	queue_free();

func _onTouch(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		var wasHitBefore = alreadyHit.has(other);
		if (wasHitBefore):
			return;
		
		var totalDmg = dmg * 2.55;
		if (other.team != team):
			alreadyHit.insert(len(alreadyHit), other);
			PlayerFunc.dealDamage(other, totalDmg);
