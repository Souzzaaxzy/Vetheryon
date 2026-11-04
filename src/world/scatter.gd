extends Node3D
class_name Scatter

## Espalha assets 3D (árvores, rochas, cristais, muros/ruínas) pelo terreno de
## forma determinística, usando o mesmo campo de altura do Terrain para apoiá-los
## no solo. Também monta um vilarejo simples de ruínas de pedra.

@export var terrain_path: NodePath = NodePath("../Terrain")
@export var seed: int = 4242
@export var tree_count: int = 260
@export var rock_count: int = 140
@export var crystal_count: int = 40
@export var ruins_count: int = 14
@export var area_radius: float = 150.0
@export var center_clear_radius: float = 8.0

var _terrain: Terrain
var _rng := RandomNumberGenerator.new()

var _tree_scene: PackedScene
var _rock_scene: PackedScene
var _crystal_scene: PackedScene
var _wall_scene: PackedScene


func _ready() -> void:
	_terrain = get_node_or_null(terrain_path)
	if _terrain == null:
		push_warning("Scatter: terreno não encontrado em " + str(terrain_path))
		return
	_rng.seed = seed
	_load_assets()
	_scatter_trees()
	_scatter_rocks()
	_scatter_crystals()
	_build_ruins()


func _load_assets() -> void:
	_tree_scene = _try_load("res://assets/models/tree.glb")
	_rock_scene = _try_load("res://assets/models/rock.glb")
	_crystal_scene = _try_load("res://assets/models/crystal.glb")
	_wall_scene = _try_load("res://assets/models/wall.glb")


func _try_load(path: String) -> PackedScene:
	if ResourceLoader.exists(path):
		return load(path)
	push_warning("Scatter: asset ausente " + path)
	return null


func _random_point() -> Vector3:
	# Distribuição uniforme em disco, evitando a área inicial do jogador.
	for _i in range(32):
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * area_radius
		if r < center_clear_radius:
			continue
		var x := cos(a) * r
		var z := sin(a) * r
		return Vector3(x, _terrain.height_at(x, z), z)
	return Vector3.ZERO


func _place(scene: PackedScene, pos: Vector3, scale_range: Vector2, yaw_random: bool = true) -> Node3D:
	if scene == null:
		return null
	var inst: Node3D = scene.instantiate()
	var s := _rng.randf_range(scale_range.x, scale_range.y)
	inst.scale = Vector3(s, s, s)
	inst.position = pos
	if yaw_random:
		inst.rotation.y = _rng.randf() * TAU
	add_child(inst)
	return inst


func _scatter_trees() -> void:
	for _i in range(tree_count):
		_place(_tree_scene, _random_point(), Vector2(0.8, 1.6))


func _scatter_rocks() -> void:
	for _i in range(rock_count):
		_place(_rock_scene, _random_point(), Vector2(0.5, 1.8))


func _scatter_crystals() -> void:
	for _i in range(crystal_count):
		var p := _random_point()
		var inst := _place(_crystal_scene, p, Vector2(0.7, 1.4))
		if inst and inst is Node3D:
			_add_light(inst, p)


func _add_light(parent: Node3D, pos: Vector3) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(0.45, 0.75, 1.0)
	light.light_energy = 1.6
	light.omni_range = 6.0
	light.position = Vector3(0, 1.0, 0)
	parent.add_child(light)


func _build_ruins() -> void:
	# Pequenos conjuntos de muros formando ruínas espalhadas pelo mapa.
	for _i in range(ruins_count):
		var origin := _random_point()
		var walls := _rng.randi_range(3, 6)
		for _w in range(walls):
			var off := Vector3(_rng.randf_range(-2.5, 2.5), 0, _rng.randf_range(-2.5, 2.5))
			var p := origin + off
			p.y = _terrain.height_at(p.x, p.z)
			_place(_wall_scene, p, Vector2(0.9, 1.3))
