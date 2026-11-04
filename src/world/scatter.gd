extends Node3D
class_name Scatter

## Constrói o vilarejo medieval do Vetheryon com um KIT PROFISSIONAL (CC0,
## Quaternius/Kenney): casas texturizadas, torres, muralha com portão, poço,
## ponte, estandartes. Também espalha natureza pelo resto do mapa.
##
## Tudo tem colisão (trimesh) exceto as estradas (visual, no chão).

@export var terrain_path: NodePath = NodePath("../Terrain")
@export var seed: int = 4242
@export var tree_count: int = 320
@export var rock_count: int = 150
@export var crystal_count: int = 40
@export var ruins_count: int = 14
@export var area_radius: float = 168.0
@export var center_clear_radius: float = 14.0
@export var house_count: int = 20
@export var market_count: int = 5

var _terrain: Terrain
var _rng := RandomNumberGenerator.new()

# Natureza (modelos próprios)
var _tree: PackedScene
var _rock: PackedScene
var _crystal: PackedScene

# Kit profissional
var _houses: Array[PackedScene] = []
var _buildings: Array[PackedScene] = []
var _walls: Array[PackedScene] = []
var _towers: Array[PackedScene] = []
var _wall_entrance: PackedScene
var _well: PackedScene
var _bridge: PackedScene
var _banner: PackedScene
var _market: PackedScene


func _ready() -> void:
	_terrain = get_node_or_null(terrain_path)
	if _terrain == null:
		push_warning("Scatter: terreno não encontrado")
		return
	_rng.seed = seed
	_load_assets()
	_scatter_nature()
	_build_village()


func _try(path: String) -> PackedScene:
	return load(path) if ResourceLoader.exists(path) else null


func _load_assets() -> void:
	_tree = _try("res://assets/models/tree.glb")
	_rock = _try("res://assets/models/rock.glb")
	_crystal = _try("res://assets/models/crystal.glb")
	_market = _try("res://assets/models/market.glb")

	for n in ["q_House1", "q_House2"]:
		var s := _try("res://assets/kit/%s.glb" % n)
		if s:
			_houses.append(s)
	for n in ["q_Building1_Small", "q_Building1_Large", "q_Building2_Small", "q_Building2_Large",
			"q_Building3_Small", "q_Building3_Big", "q_Building4"]:
		var s := _try("res://assets/kit/%s.glb" % n)
		if s:
			_buildings.append(s)
	for n in ["Wall", "WallBricks", "TallWall", "TallWallBricks"]:
		var s := _try("res://assets/kit/%s.glb" % n)
		if s:
			_walls.append(s)
	for n in ["SmallTower", "LargeTower", "PointyTower", "WatchTowerWRoof", "Simpletower"]:
		var s := _try("res://assets/kit/%s.glb" % n)
		if s:
			_towers.append(s)
	_wall_entrance = _try("res://assets/kit/WallEntrance.glb")
	_well = _try("res://assets/kit/Well.glb")
	_bridge = _try("res://assets/kit/Bridge.glb")
	_banner = _try("res://assets/kit/Banner.glb")


func _ground(x: float, z: float) -> float:
	return _terrain.height_at(x, z)


func _random_point() -> Vector3:
	for _i in range(32):
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * area_radius
		if r < center_clear_radius:
			continue
		var p := Vector2(cos(a) * r, sin(a) * r)
		if p.distance_to(_terrain.village_center) < _terrain.village_radius + 8.0:
			continue
		return Vector3(p.x, _ground(p.x, p.y), p.y)
	return Vector3.ZERO


func _place(scene: PackedScene, pos: Vector3, scale: float = 1.0, yaw: float = NAN, coll := true) -> Node3D:
	if scene == null:
		return null
	var holder := Node3D.new()
	holder.scale = Vector3(scale, scale, scale)
	holder.position = pos
	holder.rotation.y = _rng.randf() * TAU if is_nan(yaw) else yaw
	var model: Node3D = scene.instantiate()
	holder.add_child(model)
	if coll:
		var body := StaticBody3D.new()
		holder.add_child(body)
		_add_collisions(model, body)
	add_child(holder)
	return holder


func _add_collisions(node: Node, body: StaticBody3D) -> void:
	if node is MeshInstance3D and node.mesh:
		var shape: ConcavePolygonShape3D = node.mesh.create_trimesh_shape()
		if shape:
			var col := CollisionShape3D.new()
			col.shape = shape
			col.transform = node.transform
			body.add_child(col)
	for c in node.get_children():
		_add_collisions(c, body)


func _scatter_nature() -> void:
	for _i in range(tree_count):
		_place(_tree, _random_point(), _rng.randf_range(0.8, 1.7))
	for _i in range(rock_count):
		_place(_rock, _random_point(), _rng.randf_range(0.5, 1.9))
	for _i in range(crystal_count):
		var inst := _place(_crystal, _random_point(), _rng.randf_range(0.7, 1.4))
		if inst:
			var light := OmniLight3D.new()
			light.light_color = Color(0.45, 0.75, 1.0)
			light.light_energy = 1.6
			light.omni_range = 6.0
			light.position = Vector3(0, 1.0, 0)
			inst.add_child(light)


# ----------------------------------------------------------------------------
# vilarejo com o kit profissional
# ----------------------------------------------------------------------------

func _build_village() -> void:
	var c := _terrain.village_center
	print("VILLAGE center=", c)

	# Praça central: poço + estandartes.
	_place(_well, Vector3(c.x, _ground(c.x, c.y), c.y), 1.6, 0.0)
	for i in range(4):
		var a := float(i) / 4.0 * TAU
		var bx := c.x + cos(a) * 8.0
		var bz := c.y + sin(a) * 8.0
		_place(_banner, Vector3(bx, _ground(bx, bz), bz), 3.0, a)

	# Casas em quarteirões (fileiras ao longo de ruas), viradas para a rua.
	var placed := 0
	var spacing := 11.0
	for side in [-1, 1]:
		for row in range(2):
			for i in range(5):
				var x := c.x - 26.0 + i * spacing
				var z := c.y + float(side) * (6.0 + row * 13.0)
				var yaw := 0.0 if side < 0 else PI
				var scn: PackedScene = _houses[placed % _houses.size()] if placed % 3 == 0 else _buildings[placed % _buildings.size()]
				_place(scn, Vector3(x, _ground(x, z), z), _rng.randf_range(0.95, 1.1), yaw)
				placed += 1

	# Mercados na praça.
	for i in range(market_count):
		var a := float(i) / float(market_count) * TAU + 0.4
		var mx := c.x + cos(a) * 12.0
		var mz := c.y + sin(a) * 12.0
		_place(_market, Vector3(mx, _ground(mx, mz), mz), 1.0, atan2(c.x - mx, c.y - mz))

	# Torres nos cantos da muralha.
	var half := 42.0
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var tx: float = c.x + float(sx) * half
			var tz: float = c.y + float(sz) * half
			_place(_towers[0], Vector3(tx, _ground(tx, tz), tz), 1.6, 0.0)

	# Muralha contínua.
	_build_wall(c, half)

	print("VILLAGE houses=", placed, " markets=", market_count)


func _build_wall(c: Vector2, half: float) -> void:
	if _walls.is_empty():
		return
	var seg := 1.6   # largura real do modelo Wall (~1.54)
	var gate_side := 1
	var i := 0
	for sx in [-1, 1]:
		var x := c.x + float(sx) * half
		var n := int((2.0 * half) / seg)
		for k in range(n):
			var z: float = c.y - half + k * seg + seg * 0.5
			if sx == gate_side and abs(z - c.y) < 3.0:
				continue
			_place(_walls[i % _walls.size()], Vector3(x, _ground(x, z), z), 1.0, PI / 2)
			i += 1
	for sz in [-1, 1]:
		var z := c.y + float(sz) * half
		var n := int((2.0 * half) / seg)
		for k in range(n):
			var x: float = c.x - half + k * seg + seg * 0.5
			_place(_walls[i % _walls.size()], Vector3(x, _ground(x, z), z), 1.0, 0.0)
			i += 1
	if _wall_entrance:
		_place(_wall_entrance, Vector3(c.x + half, _ground(c.x + half, c.y), c.y), 1.0, PI / 2)
	print("VILLAGE wall_segments=", i)
