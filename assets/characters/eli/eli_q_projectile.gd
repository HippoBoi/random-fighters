extends Node3D

var character: CharacterBody3D;
var dmg: float = 0.0;
var team: int = 0;
var timer: float = 0.55;
var deathTimer: float = 0.6;
var realDeathTimer: float = 0.95;
var die: bool = false;
var chargeLevel: float = 0.0;

var dealtInitial = false;
var dealtExplosion = false;

@onready var fireShaderMaterial: ShaderMaterial = $FireCircle/fire_circle/fireCircle.get_surface_override_material(0).next_pass as ShaderMaterial;
@onready var fireBaseMaterial: StandardMaterial3D = $FireCircle/fire_circle/fireCircle.get_surface_override_material(0) as StandardMaterial3D;
@onready var chargeMaterial: StandardMaterial3D = $Charge/projectile.material_override as StandardMaterial3D;
@onready var explosionMaterial: ShaderMaterial = $Explosion.get_surface_override_material(0) as ShaderMaterial;

func fire(_character, _team: int, _dmg: float, _targetPos: Vector3, _chargeLevel: float = 0.0):
	_targetPos.y = 0;
	
	character = _character;
	dmg = _dmg;
	team = _team;
	chargeLevel = _chargeLevel;
	
	$initialHitbox.global_position = _targetPos;
	$explosionHitbox.global_position = _targetPos;
	$FireCircle.global_position = _targetPos;
	$FireCircleSmall.global_position = _targetPos;
	$Charge.global_position = Vector3(_targetPos.x - 0.1, _targetPos.y, _targetPos.z + 0.25);
	$Explosion.global_position = _targetPos;
	$ExplosionParticles.global_position = _targetPos;
	$Ball.global_position = _character.global_position;

	$FireCircle.scale = Vector3(0.01, 0.01, 0.01);
	$Charge.scale = Vector3(0.01, 0.01, 0.01);
	
	fireShaderMaterial.set_shader_parameter("transparency", 1.0);
	explosionMaterial.set_shader_parameter("intensity_2", 0.0);
	explosionMaterial.set_shader_parameter("shader_parameter/color1", Color("b3829f29"));
	
	var opaqueFireColor = fireBaseMaterial.albedo_color;
	opaqueFireColor.a = 1.0;
	fireBaseMaterial.albedo_color = opaqueFireColor;
	
	chargeMaterial = ($Charge/projectile.material_override as StandardMaterial3D).duplicate();
	$Charge/projectile.material_override = chargeMaterial;
	var opaqueChargeColor = chargeMaterial.albedo_color;
	opaqueChargeColor.a = 1.0;
	chargeMaterial.albedo_color = opaqueChargeColor;
	
	var hitboxScale = 0.65 + chargeLevel * 0.5;
	
	$initialHitbox.scale = Vector3(hitboxScale, hitboxScale, hitboxScale);
	$explosionHitbox.scale = Vector3(hitboxScale, hitboxScale, hitboxScale);
	
	_playFireAnimation(hitboxScale, _targetPos);
	
func _initialDamage():
	dealtInitial = true;
	$initialHitbox/MeshInstance3D/Area3D.monitoring = true;

func _explode():
	dealtExplosion = true;
	die = true;
	$explosionHitbox/MeshInstance3D/Area3D.monitoring = true;

func _process(delta: float) -> void:
	timer -= delta;
	
	if (die):
		deathTimer -= delta;
	
	if (timer <= 0.25 and not dealtInitial):
		_initialDamage();
	
	if (timer <= 0 and not dealtExplosion):
		_explode();
	
	if (deathTimer <= 0):
		realDeathTimer -= delta;
		
		$initialHitbox/MeshInstance3D/Area3D.monitoring = false;
		$explosionHitbox/MeshInstance3D/Area3D.monitoring = false;
	
	if (realDeathTimer <= 0):
		queue_free();

func _onTouch(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		var totalDmg = dmg * 0.85;
		if (other.team != team):
			PlayerFunc.dealDamage(character, other, totalDmg);

func _onTouchSlow(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		var totalDmg = dmg * 0.25;
		if (other.team != team):
			PlayerFunc.dealDamage(character, other, totalDmg);
			PlayerFunc.slowTarget(other, 0.35);

# aaaweesome animation (tweens)
func _playFireAnimation(_hitboxScale, _targetPos):
	var ballTween = get_tree().create_tween().set_parallel();
	ballTween.tween_property($Ball, "global_position", _targetPos, 0.2);
	ballTween.tween_property($Ball, "scale", Vector3(0.45, 0.45, 0.45), 0.4);

	var circleTween = get_tree().create_tween();
	circleTween.tween_property($FireCircle, "scale", Vector3(0.72 * _hitboxScale, 1.9, 0.7 * _hitboxScale), 0.1);
	circleTween.tween_property($Charge, "scale", Vector3(0.001 * _hitboxScale, 0.1, 0.001 * _hitboxScale), 0.25);
	
	await get_tree().create_timer(0.1).timeout;
	
	var fireTween = get_tree().create_tween();
	var transparentFireColor = fireBaseMaterial.albedo_color;
	transparentFireColor.a = 0.0;
	fireTween.set_parallel(true);
	fireTween.tween_property(fireBaseMaterial, "albedo_color", transparentFireColor, 0.65);
	fireTween.tween_property(fireShaderMaterial, "shader_parameter/transparency", 0.0, 0.65);
	$ExplosionParticles.scale = Vector3(1.25 * _hitboxScale, 1.25 * _hitboxScale, 1.25 * _hitboxScale);
	
	await get_tree().create_timer(0.2).timeout;
	
	$Ball.queue_free();
	
	var circleTween2 = get_tree().create_tween().set_parallel().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT);
	circleTween2.tween_property($FireCircleSmall, "scale", Vector3(0.74 * _hitboxScale, 1.95, 0.74 * _hitboxScale), 0.3);
	circleTween2.tween_property($Charge, "scale", Vector3(5.5 * _hitboxScale, 0.7, 5.5 * _hitboxScale), 0.5);
	
	await get_tree().create_timer(0.15).timeout;
	
	var fadeOutTween = get_tree().create_tween().set_parallel();
	var transparentChargeColor = chargeMaterial.albedo_color;
	transparentChargeColor.a = 0.0;
	fadeOutTween.tween_property(chargeMaterial, "albedo_color", transparentChargeColor, 0.15);
	
	var explosionScale = 7.0 * _hitboxScale;
	$Explosion.scale = Vector3(explosionScale * 0.75, explosionScale * 0.75, explosionScale * 0.75);
	explosionMaterial.set_shader_parameter("fresnel_sharpness", 10.0);
	explosionMaterial.set_shader_parameter("intensity_2", 0.0);
	
	var intensityTweem = get_tree().create_tween().set_parallel();
	intensityTweem.tween_property(explosionMaterial, "shader_parameter/intensity_2", 1.0, 0.15);
	intensityTweem.tween_property(explosionMaterial, "shader_parameter/color1", Color("ff787850"), 0.55);
	$ExplosionParticles.emitting = true;
	
	await get_tree().create_timer(0.025).timeout;
	
	var explosionTween = get_tree().create_tween().set_parallel().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT);
	explosionTween.tween_property(explosionMaterial, "shader_parameter/fresnel_sharpness", -0.2, 0.5);
	explosionTween.tween_property($Explosion, "scale", Vector3(explosionScale, explosionScale, explosionScale), 0.4);
	
	await get_tree().create_timer(0.58).timeout;
	
	var explosionTween2 = get_tree().create_tween().set_parallel().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN);
	explosionTween2.tween_property($Explosion, "scale", Vector3(0.1, 0.1, 0.1), 0.8);
	explosionTween2.tween_property(explosionMaterial, "shader_parameter/intensity_2", 0.0, 0.7);
