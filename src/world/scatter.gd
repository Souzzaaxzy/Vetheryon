extends Node3D
class_name Scatter

## Constrói o vilarejo medieval do Vetheryon e espalha natureza pelo resto do mapa.
##
## Layout do vilarejo (inspirado em vilas medievais europeias):
##  - uma praça central com poço, igreja de um lado e bancas de mercado ao redor
##  - casas de enxaimel enfileiradas ao longo de ruas de terra
##  - estradas de terra batida conectando tudo
##  - muralha de pedra leve no perímetro (opcional)
##
## TUDO tem colisão, exceto o visual das estradas (que ficam no chão).

@export var terrain_path: NodePath = NodePath("../Terrain")
@export var seed: int = 4242
@export var tree_count: int = 320
@export var rock_count: int = 150
@export var crystal_count: int = 40
@export var ruins_count: int = 18
@export var area_radius: float = 168.0
@export var center_clear_radius: float = 14.0
@export var house_count: int = 20
@export var market_count: int = 5

var _terrain: Terrain
var _rng := RandomNumberGenerator.new()

var _tree: PackedScene
var _rock: PackedScene
var _crystal: PackedScene
var _wall: PackedScene
var _houses: Array[PackedScene] = []
var _markets: Array[PackedScene] = []
var _church: PackedScene
var _well: PackedScene


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
	for m in ["res://assets/models/market.glb", "res://assets/models/market1.glb"]:
		var s := _try_load(m)
		if s:
			_markets.append(s)
	_church = _try_load("res://assets/models/church.glb")
	_well = _try_load("res://assets/models/well.glb")


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
		var p := Vector2(cos(a) * r, sin(a) * r)
		if p.distance_to(_terrain.village_center) < _terrain.village_radius + 8.0:
			continue
		return Vector3(p.x, _ground(p.x, p.y), p.y)
	return Vector3.ZERO


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


# ----------------------------------------------------------------------------
# vilarejo
# ----------------------------------------------------------------------------

func _build_village() -> void:
	var c := _terrain.village_center
	print("VILLAGE center=", c)

	# 1. Praça central: poço no meio.
	if _well:
		var wp := Vector3(c.x, _ground(c.x, c.y), c.y)
		_place(_well, wp, Vector2(1.0, 1.0), 0.0)

	# 2. Igreja: num lado da praça, virada para o centro.
	if _church:
		var cx := c.x + 0.0
		var cz := c.y - 24.0
		_place(_church, Vector3(cx, _ground(cx, cz), cz), Vector2(1.0, 1.0), 0.0)

	# 3. Casas ao longo das ruas (em fileiras, formando quarteirões).
	var placed := 0
	var row_spacing := 12.0
	var col_spacing := 13.0
	var street_half := 3.4  # largura da rua / 2
	# Duas fileiras principais ao longo do eixo X, uma de cada lado da rua central.
	for side in [-1, 1]:
		for i in range(5):
			var x := c.x - 26.0 + i * col_spacing
			var z: float = c.y + float(side) * (street_half + 6.0)
			var p := Vector3(x, _ground(x, z), z)
			var yaw := 0.0 if side > 0 else PI
			_place(_houses[placed % _houses.size()], p, Vector2(1.0, 1.12), yaw)
			placed += 1
	# Mais duas fileiras paralelas (segunda rua).
	for side in [-1, 1]:
		for i in range(5):
			var x := c.x - 26.0 + i * col_spacing
			var z: float = c.y + float(side) * (street_half + 6.0 + row_spacing)
			var p := Vector3(x, _ground(x, z), z)
			var yaw := 0.0 if side > 0 else PI
			_place(_houses[placed % _houses.size()], p, Vector2(1.0, 1.12), yaw)
			placed += 1

	# 4. Mercados ao redor da praça.
	for i in range(market_count):
		var ang := (float(i) / float(market_count)) * TAU + 0.4
		var rad := 11.0
		var x := c.x + cos(ang) * rad
		var z := c.y + sin(ang) * rad
		var yaw := atan2(c.x - x, c.y - z)
		_place(_markets[i % _markets.size()], Vector3(x, _ground(x, z), z), Vector2(1.0, 1.0), yaw)

	print("VILLAGE houses=", placed, " markets=", market_count, " church=", _church != null)

	# 5. Estradas de terra batida (visual, deitadas sobre o terreno).
	_build_roads(c)


func _build_roads(c: Vector2) -> void:
	# Rua principal ao longo de X, cruzando a praça.
	_add_road(c + Vector2(-34, 0), c + Vector2(34, 0))
	# Rua transversal ao longo de Z.
	_add_road(c + Vector2(0, -34), c + Vector2(0, 34))
	# Duas ruas paralelas (onde ficam as fileiras de casas).
	_add_road(c + Vector2(-34, -13.4), c + Vector2(34, -13.4))
	_add_road(c + Vector2(-34, 13.4), c + Vector2(34, 13.4))
	# Praça central (disco de terra).
	_add_road_disc(c, 9.0)


func _road_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.42, 0.34, 0.24)
	m.roughness = 1.0
	return m


func _add_road(a: Vector2, b: Vector2) -> void:
	var seg := 26
	var width := 3.2
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in range(seg + 1):
		var t := float(i) / float(seg)
		var p := a.lerp(b, t)
		var dir := (b - a).normalized()
		var n := Vector2(-dir.y, dir.x) * (width * 0.5)
		var l := p + n
		var r := p - n
		verts.append(Vector3(l.x, _ground(l.x, l.y) + 0.06, l.y))
		verts.append(Vector3(r.x, _ground(r.x, r.y) + 0.06, r.y))
	for i in range(seg):
		var k := i * 2
		indices.append_array([k, k + 2, k + 1, k + 1, k + 2, k + 3])
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _road_material())
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)


func _add_road_disc(center: Vector2, radius: float) -> void:
	var seg := 32
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	verts.append(Vector3(center.x, _ground(center.x, center.y) + 0.06, center.y))
	for i in range(seg + 1):
		var ang := (float(i) / float(seg)) * TAU
		var x := center.x + cos(ang) * radius
		var z := center.y + sin(ang) * radius
		verts.append(Vector3(x, _ground(x, z) + 0.06, z))
	for i in range(seg):
		indices.append_array([0, i + 1, i + 2])
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _road_material())
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)
