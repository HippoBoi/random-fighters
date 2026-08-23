extends Node

## load shaders that cause lag for OpenGL before starting a match
signal warmup_completed;
const ENABLED := true;
const SCENES := [
	# maps
	"res://assets/maps/battlefield.tscn",
	"res://assets/maps/dark_forest.tscn",
	"res://assets/maps/lake.tscn",
	"res://assets/maps/electric_central.tscn",
	"res://assets/maps/snowmen.tscn",
	"res://assets/maps/arena.tscn",
	"res://assets/maps/trainwreck.tscn",
	"res://assets/maps/heaven.tscn",
	"res://assets/maps/seaweeds.tscn",
	# characters
	"res://assets/characters/ale/ale.tscn",
	"res://assets/characters/clean/clean.tscn",
	"res://assets/characters/mystery/mystery.tscn",
	"res://assets/characters/nephi/nephi.tscn",
	"res://assets/characters/ramon/ramon.tscn",
	"res://assets/characters/rhay/rhay.tscn",
	"res://assets/characters/rio/rio.tscn",
	"res://assets/characters/shugo/shugo.tscn",
	# character abilities
	"res://assets/characters/clean/cleanBasic.tscn",
	"res://assets/characters/clean/cleanSpecialBasic.tscn",
	"res://assets/characters/clean/clean_r_laser.tscn",
	"res://assets/characters/mystery/mysteryBasic.tscn",
	"res://assets/characters/mystery/mystery_q_projectile.tscn",
	"res://assets/characters/mystery/mystery_r_projectile.tscn",
	"res://assets/characters/mystery/mystery_shield.tscn",
	"res://assets/characters/mystery/w_storm_shadow.tscn",
	"res://assets/characters/nephi/nephi_thunder.tscn",
	"res://assets/characters/ramon/ramonBasic.tscn",
	"res://assets/characters/ramon/ramon_q_ability.tscn",
	"res://assets/characters/ramon/ramon_w_teacup.tscn",
	"res://assets/characters/ramon/ramon_e_ability.tscn",
	"res://assets/characters/ramon/ramon_r_ability.tscn",
	"res://assets/characters/ramon/paper_hitbox.tscn",
	"res://assets/characters/rhay/slash_hitbox.tscn",
	"res://assets/characters/rio/r_particles.tscn",
	"res://assets/characters/rio/rio_e_web.tscn",
	"res://assets/characters/shugo/shugo_w_ability.tscn",
	"res://assets/characters/shugo/shugo_k_e_ability.tscn",
	# shared character nodes
	"res://assets/characters/dead_particles.tscn",
	"res://assets/characters/auto_basic_area.tscn",
	"res://assets/characters/character_ui.tscn",
	"res://assets/characters/structure_ui.tscn",
	# particles
	"res://assets/particles/fire_circle.tscn",
	"res://assets/particles/big_fire_circle.tscn",
	"res://assets/particles/click_particles.tscn",
	"res://assets/particles/fog_area.tscn",
	"res://assets/particles/slash.tscn",
	"res://assets/particles/stunned_particles.tscn",
	# effects
	"res://assets/effects/train_warning.tscn",
	"res://assets/effects/thunder.tscn",
	"res://assets/effects/slow_effect_02.tscn",
	"res://assets/effects/slash.tscn",
	"res://assets/effects/slash_2.tscn",
	"res://assets/effects/hit_bullet_01.tscn",
	"res://assets/effects/hit_01.tscn",
	"res://assets/effects/hit_02.tscn",
	"res://assets/effects/hippo_buff_particles.tscn",
	"res://assets/effects/heal_01.tscn",
	"res://assets/effects/grabbedEffect.tscn",
	"res://assets/effects/fire_hit_01.tscn",
	"res://assets/effects/fire_hit_02.tscn",
	# npcs
	"res://assets/npcs/hippo/hippo.tscn",
	"res://assets/npcs/snowman/snowman.tscn",
	"res://assets/npcs/snowman/snowball.tscn",
	"res://assets/npcs/snowman/snowball_shadow.tscn",
	"res://assets/npcs/big_train/big_train.tscn",
	"res://assets/npcs/small_train/small_train.tscn",
	"res://assets/npcs/will_bot/will_bot.tscn",
	"res://assets/npcs/will_bot/will_thunder.tscn",
	"res://assets/npcs/seaweeds/seaweed.tscn",
	# in-game UI
	"res://assets/scenes/gameScene.tscn",
	"res://assets/scenes/shop_ui.tscn",
	"res://assets/scenes/choosing_mode.tscn",
	"res://assets/scenes/end_game.tscn",
]
const RUNTIME_MATERIALS := [
	"res://assets/materials/outlineMaterial.tres",
	"res://assets/characters/clean/hacker_material.tres",
	"res://assets/materials/electric_material.tres",
	"res://assets/characters/rio/invis_material.tres",
]
const FRAMES_PER_SCENE := 3;

var _started := false;
var _completed := false;
var _warmup_viewport: SubViewport = null;
var _warmup_camera: Camera3D = null;

func warm_up() -> void:
	if not ENABLED:
		_completed = true
		return

	if _completed:
		return
	if _started:
		await warmup_completed
		return

	_started = true
	var start_ticks := Time.get_ticks_msec()
	await _warm_scenes()
	await _warm_runtime_materials()
	_completed = true
	print("[ShaderWarmup] Finished in %.2f s" % ((Time.get_ticks_msec() - start_ticks) / 1000.0))
	warmup_completed.emit()

## Returns true once the warm-up has finished (or was disabled).
func is_done() -> bool:
	return _completed

func _setup_viewports() -> void:
	_warmup_viewport = SubViewport.new()
	_warmup_viewport.world_3d = World3D.new()
	_warmup_viewport.size = Vector2i(640, 360)
	_warmup_viewport.transparent_bg = true
	_warmup_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_warmup_viewport)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -35, 0)
	light.shadow_enabled = true
	_warmup_viewport.add_child(light)

	_warmup_camera = Camera3D.new()
	_warmup_camera.position = Vector3(0, 25, 45)
	_warmup_camera.far = 2000.0
	_warmup_camera.look_at(Vector3.ZERO, Vector3.UP)
	_warmup_viewport.add_child(_warmup_camera)
	_warmup_camera.make_current()

func _teardown_viewports() -> void:
	if _warmup_viewport:
		_warmup_viewport.queue_free()
	_warmup_viewport = null
	_warmup_camera = null

func _warm_scenes() -> void:
	_setup_viewports()

	for path in SCENES:
		var scene: Resource = load(path)
		if scene == null or not (scene is PackedScene):
			print("FAILED to load %s" % path)
			continue

		var instance: Node = (scene as PackedScene).instantiate()
		if instance == null:
			push_warning("FAILED not instantiate %s" % path)
			continue

		instance.set_script(null)
		_warmup_viewport.add_child(instance)

		if instance is Node3D:
			(instance as Node3D).global_position = Vector3.ZERO
		elif instance is Control:
			(instance as Control).position = Vector2.ZERO

		_unhide_all(instance)
		_force_emit_particles(instance)
		if path.ends_with("gameScene.tscn"):
			_reposition_underwater_plane(instance)

		for i in FRAMES_PER_SCENE:
			await get_tree().process_frame

		instance.queue_free()
		await get_tree().process_frame

	_teardown_viewports()

func _warm_runtime_materials() -> void:
	if _warmup_viewport == null:
		_setup_viewports()

	for path in RUNTIME_MATERIALS:
		var mat: Material = load(path)
		if mat == null:
			push_warning("could not load material %s" % path)
			continue

		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = BoxMesh.new()
		mesh_instance.position = Vector3(0, 2, 0)

		if path.ends_with("outlineMaterial.tres"):
			mesh_instance.material_overlay = mat
		else:
			mesh_instance.set_surface_override_material(0, mat)

		_warmup_viewport.add_child(mesh_instance)

		for i in FRAMES_PER_SCENE:
			await get_tree().process_frame

		mesh_instance.queue_free()
		await get_tree().process_frame

	_teardown_viewports()

func _unhide_all(node: Node) -> void:
	if node is CanvasItem or node is Node3D:
		node.visible = true
	for child in node.get_children():
		_unhide_all(child)

func _force_emit_particles(node: Node) -> void:
	for child in node.find_children("*", "GPUParticles3D", true, false):
		if child is GPUParticles3D:
			(child as GPUParticles3D).emitting = true
			(child as GPUParticles3D).restart()
	for child in node.find_children("*", "CPUParticles3D", true, false):
		if child is CPUParticles3D:
			(child as CPUParticles3D).emitting = true
			(child as CPUParticles3D).restart()
	for child in node.find_children("*", "GPUParticles2D", true, false):
		if child is GPUParticles2D:
			(child as GPUParticles2D).emitting = true
			(child as GPUParticles2D).restart()
	for child in node.find_children("*", "CPUParticles2D", true, false):
		if child is CPUParticles2D:
			(child as CPUParticles2D).emitting = true
			(child as CPUParticles2D).restart()

func _reposition_underwater_plane(instance: Node) -> void:
	var plane := instance.find_child("UnderwaterCameraPlane", true, false) as Node3D
	if plane:
		plane.global_position = Vector3(0, 2, 8)
		plane.global_rotation = Vector3.ZERO
		plane.visible = true
