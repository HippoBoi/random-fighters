extends Node3D

const DEFAULT_GRASS_MATERIAL := preload("res://assets/materials/wind_foliage_grass_material.tres")
const STREAK_MATERIAL := preload("res://assets/materials/wind_streak_material.tres")
const PARTICLE_SHADER := preload("res://assets/scripts/shaders/wind/wind_particles.gdshader")
const EMISSION_EXTENTS := Vector3(18.7, 2.6, 18.7)
const WIND_DIR := Vector2(1.0, 0.35)
const WIND_PARAMETERS := [
	"wind_noise", "wind_direction", "wind_strength", "wind_speed",
	"wind_noise_scale", "wind_noise_speed", "wind_gust_scale", "wind_gust_speed",
	"wind_gust_strength", "wind_turbulence", "wind_swirl",
	"wind_vertical_strength", "wind_vertical_speed",
]

@export_group("Shared wind")
@export var wind_direction := WIND_DIR
@export_range(0.0, 2.0, 0.01) var wind_strength := 0.6
@export_range(0.0, 5.0, 0.01) var wind_speed := 1.0
@export_range(0.0, 2.0, 0.01) var gust_strength := 1.1
@export_range(0.0, 10.0, 0.1) var gust_speed := 3.2

@export_group("Wind ribbons")
@export_range(1, 150, 1) var streak_count := 64
@export_range(1, 50, 1) var long_streak_count := 14
@export_range(0.0, 10.0, 0.1) var streak_speed := 3.4
@export_range(0.01, 0.3, 0.01) var streak_width := 0.14
@export_range(0.0, 2.0, 0.01) var streak_sway := 0.6

@export_group("Drifting motes")
@export_range(1, 200, 1) var mote_count := 90
@export_range(0.0, 10.0, 0.1) var mote_speed := 1.4

@export_group("Scene foliage")
@export var grass: MultiMeshInstance3D
@export var grass_material: ShaderMaterial = DEFAULT_GRASS_MATERIAL

var _foliage_material: ShaderMaterial
var _process_materials: Array[ShaderMaterial] = []
var _draw_materials: Array[ShaderMaterial] = []
var _last_wind_settings: Array = []

func _ready() -> void:
	var material := grass_material if grass_material != null else DEFAULT_GRASS_MATERIAL
	_foliage_material = material.duplicate() as ShaderMaterial
	if grass:
		grass.material_override = _foliage_material
	_setup_streaks()
	_sync_wind()

func _process(_delta: float) -> void:
	_sync_wind()

func _sync_wind() -> void:
	var settings := [wind_direction, wind_strength, wind_speed, gust_strength, gust_speed,
		streak_speed, streak_width, streak_sway, mote_speed]
	if settings == _last_wind_settings:
		return
	_last_wind_settings = settings
	_foliage_material.set_shader_parameter("wind_direction", wind_direction)
	_foliage_material.set_shader_parameter("wind_strength", wind_strength)
	_foliage_material.set_shader_parameter("wind_speed", wind_speed)
	_foliage_material.set_shader_parameter("wind_gust_strength", gust_strength)
	_foliage_material.set_shader_parameter("wind_gust_speed", gust_speed)
	
	for material in _process_materials:
		for parameter in WIND_PARAMETERS:
			material.set_shader_parameter(parameter, _foliage_material.get_shader_parameter(parameter))
	
	for material in _draw_materials:
		material.set_shader_parameter("wind_animation_speed", wind_speed)
		material.set_shader_parameter("wind_amplitude", wind_strength * 2.0)
		
	_process_materials[0].set_shader_parameter("travel_speed", streak_speed)
	_process_materials[1].set_shader_parameter("travel_speed", streak_speed * 0.85)
	_process_materials[2].set_shader_parameter("travel_speed", mote_speed)
	_draw_materials[0].set_shader_parameter("ribbon_width", streak_width)
	_draw_materials[0].set_shader_parameter("sway_strength", streak_sway)
	_draw_materials[1].set_shader_parameter("ribbon_width", streak_width * 1.3)
	_draw_materials[1].set_shader_parameter("sway_strength", streak_sway * 1.8)
	
	for node_name in ["WindStreaks", "GustRibbons", "DriftingMotes"]:
		var layer := get_node(node_name) as GPUParticles3D
		var process_material := layer.process_material as ShaderMaterial
		var speed: float = process_material.get_shader_parameter("travel_speed")
		var turbulence: float = _foliage_material.get_shader_parameter("wind_turbulence")
		var vertical: float = _foliage_material.get_shader_parameter("wind_vertical_strength")
		var wander: float = process_material.get_shader_parameter("wandering")
		var max_flow := 1.0 + gust_strength + turbulence + absf(vertical) * 2.0 + wander * 1.6
		var travel := speed * layer.lifetime * maxf(wind_strength * 2.0, 1.0) * max_flow * 1.2
		var reach := EMISSION_EXTENTS.length() + travel * 1.5 + 10.0
		layer.visibility_aabb = AABB(Vector3.ONE * -reach, Vector3.ONE * reach * 2.0)

func _setup_streaks() -> void:
	var material := STREAK_MATERIAL
	var short_material := material.duplicate() as ShaderMaterial
	short_material.set_shader_parameter("ribbon_width", streak_width)
	short_material.set_shader_parameter("sway_strength", streak_sway)
	_add_wind_layer("WindStreaks", short_material, streak_count, 5.0, streak_speed, 0.25, false)

	var long_material := material.duplicate() as ShaderMaterial
	long_material.set_shader_parameter("ribbon_length", 6.5)
	long_material.set_shader_parameter("ribbon_width", streak_width * 1.3)
	long_material.set_shader_parameter("sway_strength", streak_sway * 1.8)
	long_material.set_shader_parameter("streak_color", Color(0.88, 0.94, 0.98, 0.48))
	_add_wind_layer("GustRibbons", long_material, long_streak_count, 6.0, streak_speed * 0.85, 0.06, false)

	var mote_material := material.duplicate() as ShaderMaterial
	mote_material.set_shader_parameter("mote_mode", true)
	mote_material.set_shader_parameter("ribbon_length", 0.09)
	mote_material.set_shader_parameter("ribbon_width", 0.07)
	mote_material.set_shader_parameter("streak_color", Color(0.9, 0.93, 0.82, 0.42))
	_add_wind_layer("DriftingMotes", mote_material, mote_count, 8.0, mote_speed, 0.65, true)

func _add_wind_layer(layer_name: String, material: ShaderMaterial, count: int,
		life: float, speed: float, calm_visibility: float, motes: bool) -> void:
	var mesh := PlaneMesh.new()
	mesh.orientation = PlaneMesh.FACE_Z
	mesh.size = Vector2.ONE
	mesh.subdivide_depth = 0 if motes else 23
	mesh.material = material
	
	var process_material := ShaderMaterial.new()
	process_material.shader = PARTICLE_SHADER
	process_material.set_shader_parameter("emission_extents", EMISSION_EXTENTS)
	process_material.set_shader_parameter("travel_speed", speed)
	process_material.set_shader_parameter("calm_visibility", calm_visibility)
	process_material.set_shader_parameter("wandering", 0.45 if motes else 0.28)
	_process_materials.append(process_material)
	_draw_materials.append(material)
	
	var particles := GPUParticles3D.new()
	particles.name = layer_name
	particles.amount = count
	particles.lifetime = life
	particles.preprocess = life
	particles.fixed_fps = 60
	particles.local_coords = false
	particles.process_material = process_material
	particles.draw_pass_1 = mesh
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.position = Vector3(0.0, 3.6, 0.0)
	particles.emitting = true
	
	add_child(particles)
