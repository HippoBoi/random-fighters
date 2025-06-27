extends Node

const BLACK_TEAM = 0;
const WHITE_TEAM = 1;
const BASIC_ATTACK_COOLDOWN = 300;

var gameMode = "";
var gameUI;

var gameStarted = false;
var freeCam = false;
var keepBasicAttacking = false;
var shopOpen = false;

var activeBasicArea: MeshInstance3D = null;
var lastHpValue = 0;
var myTeam = -1;
var myCharacter = null;

var maxRespawnTimer = 10;
var blackTeamStocks = 0;
var blackTeamSize = 0;
var whiteTeamStocks = 0;
var whiteTeamSize = 0;

var myFogInstances = [];

func _getMousePos(character):
	var spaceState = character.get_world_3d().direct_space_state;
	var mousePos = get_viewport().get_mouse_position();
	
	var rayOrigin = character.camera.project_ray_origin(mousePos);
	var rayEnd = rayOrigin + character.camera.project_ray_normal(mousePos) * 2000;
	
	var query = PhysicsRayQueryParameters3D.create(rayOrigin, rayEnd);
	var ridArray: Array[RID];
	ridArray.append(character.get_rid());
	query.exclude = ridArray;
	
	var intersection = spaceState.intersect_ray(query);
	return intersection;

func _getMapMargins(_gameMode: String) -> Array:
	var xMargins = [-20, 32];
	var zMargins = [-32, 40];
	
	if (gameMode.to_lower() == "foggy_vision"):
		xMargins = [-19, 22];
		zMargins = [-22, 30];
	
	if (gameMode.to_lower() == "hippo_capture"):
		xMargins = [-24, 32];
		zMargins = [-31, 28];
	
	return [xMargins, zMargins];

func _cameraMovement(character: CharacterBody3D, delta):
	var currentCamera = get_viewport().get_camera_3d();
	var viewportMousePos = get_viewport().get_mouse_position();
	var viewPortSize = get_viewport().get_visible_rect().size;
	
	if (freeCam == false):
		currentCamera.global_position.x = character.global_position.x + 5;
		currentCamera.global_position.z = character.global_position.z + 5;
		return;
	
	var moveMargin = 24;
	var cameraSpeed = 22;
	var moveVector = Vector3();
	
	if (viewportMousePos.x < moveMargin):
		moveVector.x -= 1;
	if (viewportMousePos.y < moveMargin):
		moveVector.z -= 1;
	if (viewportMousePos.x > viewPortSize.x - moveMargin):
		moveVector.x += 1;
	if (viewportMousePos.y > viewPortSize.y - moveMargin):
		moveVector.z += 1;
	
	moveVector = moveVector.rotated(Vector3.UP, currentCamera.rotation.y);
	currentCamera.global_position += moveVector * delta * cameraSpeed;
	
	var margins = _getMapMargins(gameMode);
	
	currentCamera.global_position.x = clamp(currentCamera.global_position.x, margins[0][0], margins[0][1]);
	currentCamera.global_position.z = clamp(currentCamera.global_position.z, margins[1][0], margins[1][1]);

func _playLivesAnimation(character, inGameUI: Control):
	playedLivesAnimation = true;
	
	var livesText = inGameUI.get_node("livesText");
	var livesContainer = inGameUI.get_node("livesContainer");
	
	livesText.visible = true;
	livesText.modulate = Color(1, 1, 1, 0);
	livesContainer.visible = true;
	livesContainer.modulate = Color(1, 1, 1, 0);
	
	for oldLive in livesContainer.get_children():
		if (oldLive.name != "template"):
			oldLive.queue_free();
	
	for live in range(character.lives + 1):
		var newLive = livesContainer.get_node("template").duplicate();
		newLive.name = str(live);
		newLive.visible = true;
		livesContainer.add_child(newLive);
	
	await get_tree().create_timer(0.225).timeout;
	var tween = get_tree().create_tween().set_parallel();
	tween.tween_property(livesText, "modulate", Color(1, 1, 1, 1), 0.25);
	tween.tween_property(livesContainer, "modulate", Color(1, 1, 1, 1), 0.25);
	
	tween = get_tree().create_tween();
	var lastLive = null;
	for live in livesContainer.get_children():
		lastLive = live;
	
	await get_tree().create_timer(2.0).timeout;
	tween = get_tree().create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT);
	tween.tween_property(lastLive, "modulate", Color(1, 1, 1, 0), 0.45);
	
	await get_tree().create_timer(1.75).timeout;
	tween = get_tree().create_tween().set_parallel();
	tween.tween_property(livesText, "modulate", Color(1, 1, 1, 0), 0.75);
	tween.tween_property(livesContainer, "modulate", Color(1, 1, 1, 0), 0.75);
	await get_tree().create_timer(1.0).timeout;
	
	if (livesContainer.get_children().size() > 1):
		lastLive.queue_free();
	else:
		print("this is last life");

func _updateLivesInUI(character: CharacterBody3D, livesContainer: HBoxContainer):
	for oldLive in livesContainer.get_children():
		if (oldLive.name != "template"):
			oldLive.queue_free();
	
	for live in range(character.lives):
		var newLive = livesContainer.get_node("template").duplicate();
		newLive.name = str(live);
		newLive.visible = true;
		livesContainer.add_child(newLive);

var playedLivesAnimation = false;
func _updateGameUI(character: CharacterBody3D):
	var scene = character.get_parent();
	if (scene.name == "Game"):
		var UI = scene.get_node("InGameUI");
		var healthBar: TextureRect = UI.get_node("healthBar").get_node("health");
		var abilityUI = UI.get_node("abilitiesUI");
		var primAbility = abilityUI.get_node("primaryAbility");
		var secondAbility = abilityUI.get_node("secondaryAbility");
		var tertAbility = abilityUI.get_node("tertiaryAbility");
		var ultAbility = abilityUI.get_node("ultiAbility"); 
		var UIlevel = abilityUI.get_node("level");
		var UIxp = abilityUI.get_node("xp");
		var UIrespawningText = abilityUI.get_node("respawningText");
		var UIrespawnTimer = abilityUI.get_node("respawnTimer");
		var UItokens = abilityUI.get_node("tokens");
		var livesContainer = abilityUI.get_node("livesContainer2");
		primAbility.get_node("cooldown").scale.x = character.qTimer / character.Q_COOLDOWN;
		secondAbility.get_node("cooldown").scale.x = character.wTimer / character.W_COOLDOWN;
		tertAbility.get_node("cooldown").scale.x = character.eTimer / character.E_COOLDOWN;
		ultAbility.get_node("cooldown").scale.x = character.rTimer / character.R_COOLDOWN;
		
		UIlevel.text = str(character.level);
		UIxp.text = str(character.xp);
		UIrespawnTimer.text = str(roundf(character.respawnTimer * 100) / 100);
		UItokens.text = str(character.tokens);
		
		_updateLivesInUI(character, livesContainer);
		
		if (character.dead):
			if not (playedLivesAnimation):
				_playLivesAnimation(character, UI);
			
			_updateLivesInUI(character, livesContainer);
		
			if (character.lives > 0):
				UIrespawningText.visible = true;
				UIrespawnTimer.visible = true;
		else:
			playedLivesAnimation = false;
			UIrespawningText.visible = false;
			UIrespawnTimer.visible = false;
		
		healthBar.scale.x = character.hp / character.maxHp;

func _autoBasic(character):
	if (activeBasicArea):
		activeBasicArea.queue_free();
	
	var basicArea: MeshInstance3D = preload("res://assets/characters/auto_basic_area.tscn").instantiate();
	var areaLiveTimer: Timer = Timer.new();
	areaLiveTimer.wait_time = 0.5;
	areaLiveTimer.autostart = true;
	areaLiveTimer.timeout.connect(func():
		basicArea.queue_free();
	);
	
	basicArea.add_child(areaLiveTimer);
	character.get_parent().add_child(basicArea);
	
	var areaSize = character.attackRange * 3;
	areaSize = clamp(areaSize, 10, character.attackRange * 6);
	basicArea.scale.x = areaSize;
	basicArea.scale.z = areaSize;
	basicArea.global_position = character.global_position + Vector3(0, 1, 0);
	
	var hitbox: Area3D = basicArea.get_node("area");
	hitbox.body_entered.connect(func(other: Node3D):
		if (other == self or other.visible == false):
			return;
		
		var isCharacter = "CHARACTER_NAME" in other;
		if (isCharacter):
			if (other.dead):
				return;
			
			if (other.team != character.team):
				character.target = other;
	);
	
	activeBasicArea = basicArea;

func tweenCameraToChar(startingPos: Vector3):
	var character: CharacterBody3D = myCharacter;
	var scene = myCharacter.get_parent();
	if (scene.name == "Game"):
		var camera: Camera3D = scene.get_node("MainCamera");
		camera.global_position = startingPos;
		
		await get_tree().create_timer(3.0).timeout;
		var tween = get_tree().create_tween().set_trans(Tween.TRANS_EXPO);
		var newPosition = Vector3(character.global_position.x + 5, camera.global_position.y, character.global_position.z + 5);
		tween.tween_property(camera, "position", newPosition, 1.55);

func updateState(character: CharacterBody3D, delta):
	myCharacter = character;
	myTeam = character.team;
	myFogInstances = character.fogInstances;
	character.mousePos = _getMousePos(character);
	character.timer += delta;
	
	for fog in myFogInstances:
		if (fog):
			var fogParticles: GPUParticles3D = fog.get_node("FogParticles");
			fogParticles.emitting = false;
		else:
			print("[WARNING]: fog instance not found");
	
	if (gameStarted):
		_cameraMovement(character, delta);
		
		if (Input.is_action_just_pressed("lockCamera")):
			freeCam = not freeCam;
			
		if (Input.is_action_pressed("space")):
			freeCam = false;
		if (Input.is_action_just_released("space")):
			freeCam = true;
		
		if (Input.is_action_just_pressed("autoBasic")):
			_autoBasic(character);
	
		var mousePos = character.mousePos;
		if not (mousePos.is_empty()):
			if ("team" in mousePos.collider and not mousePos.collider.dead):
				var target = mousePos.collider;
				var otherTeam = target.team;
				if (otherTeam != character.team):
					character.hovering = target;
					Cursor.changeCursor(Constants.CursorTypes.cursorAttack);
					setOutline(target, 1.0);
			else:
				if (character.hovering != null):
					setOutline(character.hovering, 0.0, 0.0);
					character.hovering = null;
				Cursor.changeCursor(Constants.CursorTypes.cursor);
		
		# handle target and auto attacking (basic attacking)
		if (not character.dead and character.target and "dead" in character.target and not character.target.dead):
			if (_inBasicRange(character, character.target)):
				basicAttack(character);
			else:
				character.moveTo = character.target.global_position;
				syncMovement(character);
		else:
			character.target = null;
	
		# timers
		if (character.qTimer > 0):
			character.qTimer -= delta;
		if (character.wTimer > 0):
			character.wTimer -= delta;
		if (character.eTimer > 0):
			character.eTimer -= delta;
		if (character.rTimer > 0):
			character.rTimer -= delta;
	
	character.qTimer = max(0, character.qTimer);
	character.wTimer = max(0, character.wTimer);
	character.eTimer = max(0, character.eTimer);
	character.rTimer = max(0, character.rTimer);
	
	if (character.dead and character.lives > 0):
		character.respawnTimer -= delta;
		
		if (character.respawnTimer <= 0):
			respawnCharacter(character);
	
	_updateGameUI(character);
	
	if (character.timer >= 4 and character.showingUIs == false):
		showCharactersUI(character);

func checkTeamLives(character: CharacterBody3D):
	var curTeam = character.team;
	blackTeamSize = 0;
	blackTeamStocks = 0;
	whiteTeamSize = 0;
	whiteTeamStocks = 0;
	
	for playerId in Server.playersInfo:
		var player = Server.playersInfo[playerId];
		
		if (player.team == curTeam and player.charInstance.lives <= 0):
			if (player.team == BLACK_TEAM):
				blackTeamStocks += 1;
			elif (player.team == WHITE_TEAM):
				whiteTeamStocks += 1;
			else:
				print("uhh,,, what's your team?");
			
		if (player.team == BLACK_TEAM):
			blackTeamSize += 1;
		elif (player.team == WHITE_TEAM):
			whiteTeamSize += 1;
		else:
			print("no team dude?");
	
	var winnerTeam = -1;
	if (blackTeamStocks >= blackTeamSize):
		winnerTeam = WHITE_TEAM;
	elif (whiteTeamStocks >= whiteTeamSize):
		winnerTeam = BLACK_TEAM;
	
	if (winnerTeam != -1):
		var scene = character.get_parent();
		if (scene.name == "Game"):
			scene.roundVictory.emit(winnerTeam);

func killCharacter(character: CharacterBody3D):
	if (character.dead):
		return;
	
	character.dead = true;
	character.visible = false;
	character.lives -= 1;
	character.respawnTimer = maxRespawnTimer;
	character.moveTo = character.global_position;
	syncMovement(character);
	
	for playerId in character.assistedInKill:
		var scene = character.get_parent();
		if (scene.name != "Game"):
			print("[WARNING]: game node not found");
			return;
		
		var player: CharacterBody3D = scene.get_character_by_id(playerId);
		if (player):
			player.tokens += 10;
	
	var particles = preload("res://assets/characters/dead_particles.tscn").instantiate();
	character.get_parent().add_child(particles);
	
	particles.global_position = character.global_position + Vector3(0, 2, 0);
	particles.get_node("pointyParts").emitting = true;
	particles.get_node("smokeParts").emitting = true;
	particles.get_node("spiralParts").emitting = true;
	
	checkTeamLives(character);

func spawnCharacter(character: CharacterBody3D):
	character.hp = character.maxHp;
	character.dead = false;
	character.visible = true;
	character.inFog = false;
	character.lives = 1;
	character.fogInstances = [];
	
	character.qTimer = 0;
	character.wTimer = 0;
	character.eTimer = 0;
	character.rTimer = 0;
	
	var scene = character.get_parent();
	if (scene.name == "Game"):
		var mapNode = scene.get_node("Map");
		var map = mapNode.get_child(0);
		var spawns = map.get_node("spawnLocations");
		
		if not (spawns):
			print("[WARNING PLAYER FUNC]: spawn locations not found");
			return;
		
		var whiteTeam: Node3D = spawns.get_node("whiteTeam");
		var blackTeam: Node3D = spawns.get_node("blackTeam");
		if (character.team == 0):
			character.global_position = blackTeam.global_position;
		else:
			character.global_position = whiteTeam.global_position;
	
	character.rpc("syncRespawn", character.hp, character.global_position);
	
func respawnCharacter(character: CharacterBody3D):
	if (character.dead == false):
		return;
	
	character.hp = character.maxHp;
	character.dead = false;
	character.visible = true;
	character.inFog = false;
	character.fogInstances = [];
	
	var scene = character.get_parent();
	if (scene.name == "Game"):
		var mapNode = scene.get_node("Map");
		var map = mapNode.get_child(0);
		var spawns = map.get_node("spawnLocations");
		
		if not (spawns):
			print("[WARNING PLAYER FUNC]: spawn locations not found");
			return;
		
		var whiteTeam: Node3D = spawns.get_node("whiteTeam");
		var blackTeam: Node3D = spawns.get_node("blackTeam");
		if (character.team == 0):
			character.global_position = blackTeam.global_position;
		else:
			character.global_position = whiteTeam.global_position;
	
	character.rpc("syncRespawn", character.hp, character.global_position);

func enterFog(character, fogInstance):
	character.inFog = true;
	
	var instance = character.fogInstances.find(fogInstance);
	if (instance == -1):
		character.fogInstances.append(fogInstance);

func leaveFog(character, _fogInstance):
	character.inFog = false;

func updateGlobally(character: CharacterBody3D, _delta):
	if (character.inFog):
		character.visible = false;
		
		if (character.onAction or character.basicAttacking):
			character.visible = true;
		
		if (character.fogInstances.size() > 0 and myFogInstances.size() > 0 and character.dead == false):
			if (character.fogInstances[0] == myFogInstances[0]):
				character.visible = true;
	else:
		if (character.fogInstances.size() > 0):
			character.visible = true;
			character.fogInstances = [];
	if (character.hp <= 0):
		killCharacter(character);
	
	if (character.forceMoveTo):
		displaceChar(character, _delta, character.forceMoveTo);
		
		if (character.stunTimer <= 0):
			character.rpc("simulateForcedMove", null);
	
	if (character.speedMultiplier < 1.0):
		character.speedMultiplier += _delta * 0.35;
		character.speedMultiplier = clamp(character.speedMultiplier, 0.0, 1.0);
	
	if (character.stunned):
		character.moveTo = character.global_position;
		character.target = null;
		
		if not (character.stunnedParts):
			character.stunnedParts = preload("res://assets/particles/stunned_particles.tscn").instantiate();
			character.stunnedParts.get_node("parts").emitting = true;
			
			var parts = character.stunnedParts;
			character.add_child(parts);
			character.stunnedParts.global_position = character.global_position + Vector3(0, 4, 0);
		
		character.stunTimer -= _delta;
		
		if (character.stunTimer <= 0):
			character.stunned = false;
			character.rpc("syncStun", character.stunned, character.stunTimer);
	else:
		if (character.stunnedParts):
			character.stunnedParts.get_node("parts").emitting = false;
			character.stunnedParts = null;
	
	character.dmg = character.baseDmg + character.dmgOffset;
	character.armor = character.baseArmor + character.armorOffset;
	character.attackRange = character.baseAttackRange + character.attackRangeOffset;
	character.attackSpeed = character.baseAttackSpeed + character.attackSpeedOffset;
	character.speed = (character.baseSpeed + character.speedOffset) * character.speedMultiplier;
	
	if not (character.onAction or character.stunned or character.dead):
		if (character.bufferedInput):
			character.bufferedInput.call();
			character.bufferedInput = null;
		if (character.bufferedTarget):
			character.target = character.bufferedTarget;
			character.bufferedTarget = null;
	
	if (character.basicAttacking):
		character.basicAttackTimer -= character.attackSpeed;
		
		if (character.basicAttackTimer <= 0):
			character.basicAttacking = false;
	
func onRightClick(character: CharacterBody3D):
	if not (gameStarted):
		return;
	
	var mousePos = character.mousePos;
	if (mousePos.is_empty()):
		return;
	
	if not (character.onAction):
		character.target = null;
	
	if (character.hovering and not character.hovering.dead):
		if not (character.onAction or character.stunned):
			character.target = character.hovering;
		else:
			character.bufferedTarget = character.hovering;
			character.rpc("syncBufferedInputs", null, character.bufferedTarget);
		return;
	
	var particles = preload("res://assets/particles/click_particles.tscn").instantiate();
	particles.transform.origin = mousePos.position;
	particles.get_child(0).emitting = true;
	character.get_parent().add_child(particles);
	
	if not (character.onAction or character.stunned):
		character.moveTo = mousePos.position;
		character.moveTo.y = character.global_position.y;
		syncMovement(character);
	else:
		character.bufferedMoveTo = mousePos.position;
		character.bufferedMoveTo.y = character.global_position.y;
		character.rpc("syncBufferedInputs", character.bufferedMoveTo);
	
	if (character.dead):
		character.moveTo = character.global_position;
		syncMovement(character);
	
func syncMovement(character):
	if (character.moveTo != character.lastPos):
		character.lastPos = character.moveTo;
		character.rotateChar(character.moveTo);
		character.rpc("simulateMove", character.moveTo, Vector3.ZERO);

func stopCharacter(character, stopTarget = true):
	character.velocity = Vector3.ZERO;
	character.moveTo = null;
	if (stopTarget):
		character.target = null;
	
	character.rpc("simulateMove", character.moveTo, character.global_position);

func stopKeyPressed(character: CharacterBody3D, animPlayer: AnimationPlayer = null, stopTarget = true):
	if (animPlayer):
		if (animPlayer.is_playing() and (animPlayer.current_animation == "basic_01") or animPlayer.current_animation != "basic_02"):
			animPlayer.stop();
	
	character.basicAttacking = false;
	character.basicAttackTimer = 0;
	stopCharacter(character, stopTarget);

func moveChar(character: CharacterBody3D, delta: float, posToMove: Vector3):
	posToMove = Vector3(posToMove.x, character.global_position.y, posToMove.z);
	
	var displacement = posToMove - character.global_position;
	var distance = displacement.length();
	var direction = displacement / distance;
	var max_speed = (distance / delta);
	character.velocity = direction * minf(character.speed, max_speed);
	
	if (displacement.is_zero_approx()):
		character.moveTo = null;
		character.velocity = Vector3.ZERO;

func displaceChar(character, delta: float, posToMove: Vector3):
	var speed = character.forceMoveSpeed;
	character.global_position = character.global_position.move_toward(posToMove, speed * delta);

func _inBasicRange(character, target):
	var distance = character.global_position.distance_to(target.global_position);
	if (distance < character.attackRange):
		return true;
	
	return false;
	
func dealDamage(character, target, dmg, effect := ""):
	if not (target):
		print("[dealDamage]: no target found");
		return;
	
	var totalDmg = dmg * dmg / (dmg + target.armor);
	var dmgAfterShield = 0;
	
	dmgAfterShield = totalDmg - target.shield;
	target.shield -= totalDmg;
	target.shield = clamp(target.shield, 0, target.maxHp);
	totalDmg = dmgAfterShield;
	
	if (totalDmg > 0):
		target.hp -= totalDmg;
		target.hp = clamp(target.hp, 0, target.maxHp);
	
	target.rpc("syncHealth", target.hp, true, character.name);
	target.rpc("syncShield", target.shield);
	
	if not (effect.is_empty()):
		target.rpc("syncParticles", effect);

func stunTarget(target, duration, effect := ""):
	target.stunned = true;
	target.stunTimer = duration;
	target.rpc("syncStun", target.stunned, target.stunTimer);
	
	if not (effect.is_empty()):
		target.rpc("syncParticles", effect);

func slowTarget(target: CharacterBody3D, slow: float, effect := ""):
	target.speedMultiplier -= slow;
	target.speedMultiplier = clamp(target.speedMultiplier, 0.0, 1.0);
	
	target.rpc("syncSlow", slow);
	
	if not (effect.is_empty()):
		target.rpc("syncParticles", effect);

func moveTarget(target, duration, finalPos, moveSpeed = 20, effect := ""): # bad name, force target to move
	target.stunned = true;
	target.stunTimer = duration;
	target.rpc("syncStun", target.stunned, target.stunTimer);
	target.rpc("simulateForcedMove", finalPos, moveSpeed);
	
	if not (effect.is_empty()):
		target.rpc("syncParticles", effect);

func basicAttack(character):
	stopCharacter(character, false);
	if not (character.onAction or character.basicAttacking) and (character.target):
		character.basicAttacking = true;
		character.basicAttackTimer = BASIC_ATTACK_COOLDOWN;
		character.rpc("syncRotation", character.target.global_position);
		character.rpc("playBasicAttack");
		
		character.basicAttack();

func _closeShop(shop):
	shop.queue_free();
	shopOpen = false;

func shopToggle(character: CharacterBody3D):
	if (shopOpen == false):
		var shopScene = preload("res://assets/scenes/shop_ui.tscn").instantiate();
		shopScene.character = character;
		shopScene.closeShop.connect(_closeShop);
		character.add_child(shopScene);
		
		shopOpen = true;
	else:
		var openedShop = character.has_node("ShopUI");
		if (openedShop):
			character.get_node("ShopUI").queue_free();
			
		shopOpen = false;

func grantItemStats(character: CharacterBody3D, item: Dictionary):
	if (item.stats.has("hp")):
		character.maxHp += item.stats.hp;
		character.hp += item.stats.hp;
		character.hp = clamp(character.hp, 0, character.maxHp);
	if (item.stats.has("armor")):
		character.baseArmor += item.stats.armor;
	if (item.stats.has("dmg")):
		character.baseDmg += item.stats.dmg;
	if (item.stats.has("attackSpeed")):
		character.baseAttackSpeed += item.stats.attackSpeed;
	if (item.stats.has("cooldownReduction")):
		character.cooldownReduction += item.stats.cooldownReduction;
	if (item.stats.has("speed")):
		character.baseSpeed += item.stats.speed;

func playSound(character: CharacterBody3D, sound):
	var newSound = AudioStreamPlayer3D.new();
	character.add_child(newSound);
	
	newSound.global_position = character.global_position;
	newSound.stream = sound;
	newSound.pitch_scale = randf();
	newSound.pitch_scale = clamp(newSound.pitch_scale, 0.75, 1.5);
	newSound.play();
	newSound.finished.connect(func():
		newSound.queue_free();
	);

func setup(character):
	# set shaders
	var model = character.get_child(0).get_child(0);
	var outlineMaterial = preload("res://assets/materials/outlineMaterial.tres").duplicate();
	for child in model.get_children():
		child.material_overlay = outlineMaterial;
	
	if ("MULTIPLE_FORM" in character):
		var secondModel = character.get_child(1).get_child(0).get_child(0);
		for child in secondModel.get_children():
			child.material_overlay = outlineMaterial;
	
	# set variables
	character.dmg = character.baseDmg + character.dmgOffset;
	character.armor = character.baseArmor + character.armorOffset;
	character.attackRange = character.baseAttackRange + character.attackRangeOffset;
	character.attackSpeed = character.baseAttackSpeed + character.attackSpeedOffset;
	character.speed = character.baseSpeed + character.speedOffset;
	
func setOutline(character, enabled: float, strength: float = 4.0) -> void:
	var model = character.get_child(0).get_child(0);
	for child in model.get_children():
		child.material_overlay.set_shader_parameter("enabled", enabled);
		child.material_overlay.set_shader_parameter("outline_width", strength);
	
	if ("MULTIPLE_FORM" in character):
		var secondModel = character.get_child(1).get_child(0).get_child(0);
		for child in secondModel.get_children():
			child.material_overlay.set_shader_parameter("enabled", enabled);
			child.material_overlay.set_shader_parameter("outline_width", strength);

func showCharactersUI(character):
	for playerID in Server.playersInfo:
		var player = Server.playersInfo[playerID];
		var charUI = preload("res://assets/characters/character_ui.tscn").instantiate();
		var healthBar = charUI.get_node("HealthUI/SubViewport/emptyBar/healthBar");
		charUI.get_node("PlayerName/SubViewport/Label").text = player.username;
		healthBar.color = Color(0, 0, 0);
		player.charInstance.add_child(charUI);
	
	character.showingUIs = true;

func _calculateHealthBars(character: CharacterBody3D):
	var charUI = character.get_node("CharacterUI");
	var emptyBar = charUI.get_node("HealthUI/SubViewport/emptyBar");
	var templateBar = emptyBar.get_node("templateBar");
	var barsToDraw = 0;
	
	for child in emptyBar.get_children():
		if (child.name == "bar"):
			child.queue_free();
	
	for i in range(character.maxHp):
		if (i % 25 == 0):
			barsToDraw += 1;
	
	for i in range(barsToDraw):
		var newBar = templateBar.duplicate();
		templateBar.get_parent().add_child(newBar);
		
		newBar.visible = true;
		newBar.size.x = 1.0;
		newBar.scale.y = 0.7;
		newBar.modulate = Color(1, 1, 1, 0.25);
		newBar.position.x = templateBar.size.x / barsToDraw * i;
		newBar.name = "bar";

func updateHealthSize(character: CharacterBody3D, damaged = false):
	var UILoaded = character.has_node("CharacterUI");
	if not (UILoaded):
		return;
	
	var myTeamColor = Color(0.073, 0.509, 0.6);
	var enemyTeamColor = Color(0.769, 0.17, 0.182);
	var charUI = character.get_node("CharacterUI");
	var healthBar = charUI.get_node("HealthUI/SubViewport/emptyBar/healthBar");
	var shieldBar = charUI.get_node("HealthUI/SubViewport/emptyBar/shieldBar");
	var levelText = charUI.get_node("HealthUI/SubViewport/levelPanel/levelText");
	healthBar.scale.x = character.hp / character.maxHp;
	shieldBar.scale.x = character.shield / character.maxHp;
	levelText.text = str(character.level);
	
	_calculateHealthBars(character);
	
	if (healthBar.color == Color(0, 0, 0)):
		healthBar.color = myTeamColor if character.team == myTeam else enemyTeamColor;
	
	# adjust shield position so it moves right to left
	var base_width := 110;
	shieldBar.position.x = base_width * (1.0 - shieldBar.scale.x)
	
	if (damaged):
		var defaultColor = myTeamColor if character.team == myTeam else enemyTeamColor;
		var duration = 0.1;
		var damagedColor = Color(1, 0.65, 0.45);
		if (character.shield > 0):
			damagedColor = Color(0.6, 0.4, 0.71);
		var tween = character.create_tween();
		healthBar.color = damagedColor;
		tween.tween_property(healthBar, "color", defaultColor, duration);
