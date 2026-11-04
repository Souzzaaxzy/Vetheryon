extends Node3D
class_name Scatter

## Espalha estruturas pelo terreno e constrói a vila medieval.
##
## TUDO tem colisão (StaticBody3D + CollisionShape3D gerados a partir da malha
## de cada modelo), então o jogador não atravessa nada. Os objetos são apoiados
## no solo usando o mesmo campo de altura do Terrain.
##
## A vila segue um layout medieval: praça central aberta, casas de enxaimel
## enfileiradas ao longo de ruas, viradas para o centro.

@export var terrain_path: NodePath = NodePath("../Terrain")
@export var seed: int = 4242
@export var tree_count: int = 320
@export var rock_count: int = 150
@export var crystal_count: int = 40
@export var ruins_count: int = 18
@export var area_radius: float = 165.0
@export var center_clear_radius: float = 12.0

var _terrain: Terrain
var _rng := RandomNumberGenerator.new()

var _tree: PackedScene
var _rock: PackedScene
var _crystal: PackedScene
var _wall: PackedScene
var _houses: Array[PackedScene] = []


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
	_build_village()


func _load_assets() -> void:
	_tree = _try_load("res://assets/models/tree.glb")
	_rock = _try_load("res://assets/models/rock.glb")
	_crystal = _try_load("res://assets/models/crystal.glb")
	_wall = _try_load("res://assets/models/wall.glb")
	for h in ["res://assets/models/house.glb", "res://assets/models/house1.glb", "res://assets/models/house2.glb"]:
		var s := _try_load(h)
		if s:
			_houses.append(s)


func _try_load(path: String) -> PackedScene:
	if ResourceLoader.exists(path):
		return load(path)
	push_warning("Scatter: asset ausente " + path)
	return null


func _ground(x: float, z: float) -> float:
	return _terrain.height_at(x, z)


func _random_point() -> Vector3:
	for _i in range(32):
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * area_radius
		if r < center_clear_radius:
			continue
		# Não espalhar natureza em cima da vila.
		var p := Vector2(cos(a) * r, sin(a) * r)
		if p.distance_to(_terrain.village_center) < _terrain.village_radius + 6.0:
			continue
		return Vector3(p.x, _ground(p.x, p.y), p.y)
	return Vector3.ZERO


## Instancia um modelo e cria colisão estática a partir de todas as malhas dele.
func _place(scene: PackedScene, pos: Vector3, scale_range: Vector2, yaw: float = NAN, with_collision: bool = true) -> Node3D:
	if scene == null:
		return null
	var holder := Node3D.new()
	var s := _rng.randf_range(scale_range.x, scale_range.y)
	holder.scale = Vector3(s, s, s)
	holder.position = pos
	holder.rotation.y = _rng.randf() * TAU if is_nan(yaw) else yaw

	var model: Node3D = scene.instantiate()
	holder.add_child(model)

	if with_collision:
		var body := StaticBody3D.new()
		holder.add_child(body)
		_add_mesh_collisions(model, body)

	add_child(holder)
	return holder


func _add_mesh_collisions(node: Node, body: StaticBody3D) -> void:
	if node is MeshInstance3D and node.mesh:
		var shape: ConcavePolygonShape3D = node.mesh.create_trimesh_shape()
		if shape:
			var col := CollisionShape3D.new()
			col.shape = shape
			col.transform = node.transform
			body.add_child(col)
	for child in node.get_children():
		_add_mesh_collisions(child, body)


func _scatter_trees() -> void:
	for _i in range(tree_count):
		_place(_tree, _random_point(), Vector2(0.8, 1.7))


func _scatter_rocks() -> void:
	for _i in range(rock_count):
		_place(_rock, _random_point(), Vector2(0.5, 1.9))


func _scatter_crystals() -> void:
	for _i in range(crystal_count):
		var inst := _place(_crystal, _random_point(), Vector2(0.7, 1.4))
		if inst:
			var light := OmniLight3D.new()
			light.light_color = Color(0.45, 0.75, 1.0)
			light.light_energy = 1.6
			light.omni_range = 6.0
			light.position = Vector3(0, 1.0, 0)
			inst.add_child(light)


func _build_ruins() -> void:
	for _i in range(ruins_count):
		var origin := _random_point()
		for _w in range(_rng.randi_range(3, 6)):
			var p := origin + Vector3(_rng.randf_range(-2.5, 2.5), 0, _rng.randf_range(-2.5, 2.5))
			p.y = _ground(p.x, p.z)
			_place(_wall, p, Vector2(0.9, 1.3))


## Vila medieval: 8-9 casas de enxaimel em anel ao redor da praça central,
## viradas para o centro.
func _build_village() -> void:
	if _houses.is_empty():
		push_warning("Scatter: sem modelos de casa")
		return
	var c := _terrain.village_center
	var plaza := 10.0
	var n := _rng.randi_range(8, 9)
	var ring := plaza + 6.5
	var total := 0
	for i in range(n):
		var ang := (float(i) / float(n)) * TAU + _rng.randf_range(-0.06, 0.06)
		var x := c.x + cos(ang) * ring
		var z := c.y + sin(ang) * ring
		var p := Vector3(x, _ground(x, z), z)
		# Vira a fachada (frente = -Z local) para o centro da vila.
		var yaw := atan2(c.x - x, c.y - z)
		_place(_houses[total % _houses.size()], p, Vector2(1.0, 1.15), yaw)
		total += 1
	print("VILLAGE houses=", total)
