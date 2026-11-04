extends Node3D
class_name Scatter

## Constrói o vilarejo medieval (kit profissional CC0) e espalha a natureza.
##
## OTIMIZAÇÃO (FPS): a natureza (320 árvores + 150 rochas + 40 cristais) usa
## MultiMeshInstance3D — 1 draw call por tipo em vez de 1 por objeto. E a colisão
## desses objetos usa cilindros/boxes simples (baratos) em vez de trimesh, que é
## caríssimo com centenas de objetos.
##
## Só os prédios/muros (poucos) usam colisão trimesh fiel.

@export var terrain_path: NodePath = NodePath("../Terrain")
@export var seed: int = 4242
@export var tree_count: int = 110
@export var bush_count: int = 90
@export var rock_count: int = 70
@export var flower_count: int = 120
@export var mushroom_count: int = 35
@export var crystal_count: int = 25
@export var area_radius: float = 168.0
@export var center_clear_radius: float = 14.0
@export var market_count: int = 5
@export var wall_height_scale: float = 1.9

var _terrain: Terrain
var _rng := RandomNumberGenerator.new()

var _tree: PackedScene
var _tree2: PackedScene
var _bush: PackedScene
var _flower: PackedScene
var _mushroom: PackedScene
var _rock: PackedScene
var _crystal: PackedScene
var _houses: Array[PackedScene] = []
var _buildings: Array[PackedScene] = []
var _walls: Array[PackedScene] = []
var _towers: Array[PackedScene] = []
var _wall_entrance: PackedScene
var _well: PackedScene
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
	# Natureza texturizada (kit Quaternius) - MultiMesh.
	_tree = _try("res://assets/nature/BigTree.glb")
	_tree2 = _try("res://assets/nature/Tree.glb")
	_bush = _try("res://assets/nature/Bush.glb")
	_flower = _try("res://assets/nature/Flower.glb")
	_mushroom = _try("res://assets/nature/Mushroom.glb")
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
	for n in ["Wall", "WallBricks"]:
		var s := _try("res://assets/kit/%s.glb" % n)
		if s:
			_walls.append(s)
	for n in ["SmallTower", "LargeTower", "PointyTower", "WatchTowerWRoof"]:
		var s := _try("res://assets/kit/%s.glb" % n)
		if s:
			_towers.append(s)
	_wall_entrance = _try("res://assets/kit/WallEntrance.glb")
	_well = _try("res://assets/kit/Well.glb")
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


# ----------------------------------------------------------------------------
# natureza: MultiMesh (1 draw call por tipo) + colisão simples
# ----------------------------------------------------------------------------

func _nature_multimesh(scene: PackedScene, count: int, s_min: float, s_max: float, coll_radius: float, coll_height: float) -> void:
	if scene == null or count <= 0:
		return
	var model: Node3D = scene.instantiate()
	var mesh_inst := _first_mesh(model)
	if mesh_inst == null:
		model.queue_free()
		return

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh_inst.mesh
	mm.instance_count = count
	for i in range(count):
		var p := _random_point()
		var s := _rng.randf_range(s_min, s_max)
		var yaw := _rng.randf() * TAU
		var t := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s)), p)
		mm.set_instance_transform(i, t)

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

	# Colisão barata: um cilindro por objeto (não trimesh).
	var body := StaticBody3D.new()
	add_child(body)
	for i in range(count):
		var t := mm.get_instance_transform(i)
		var col := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = coll_radius
		cyl.height = coll_height
		col.shape = cyl
		col.position = t.origin + Vector3(0, coll_height * 0.5, 0)
		body.add_child(col)
	model.queue_free()


func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for c in node.get_children():
		var m := _first_mesh(c)
		if m:
			return m
	return null


func _scatter_nature() -> void:
	_nature_multimesh(_tree, tree_count, 0.9, 1.6, 0.4, 2.6)
	_nature_multimesh(_tree2, tree_count / 2, 0.9, 1.5, 0.35, 2.2)
	_nature_multimesh(_bush, bush_count, 0.8, 1.5, 0.5, 0.8)
	_nature_multimesh(_rock, rock_count, 0.6, 1.6, 0.7, 1.0)
	_nature_multimesh(_flower, flower_count, 0.9, 1.4, 0.25, 0.4)
	_nature_multimesh(_mushroom, mushroom_count, 0.9, 1.4, 0.25, 0.4)
	_nature_multimesh(_crystal, crystal_count, 0.8, 1.4, 0.35, 1.2)


# ----------------------------------------------------------------------------
# prédios (poucos): colisão trimesh fiel
# ----------------------------------------------------------------------------

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
	# Sombras: só os prédios grandes projetam (economiza muito).
	_set_shadow(model, false)
	add_child(holder)
	return holder


func _set_shadow(node: Node, on: bool) -> void:
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in node.get_children():
		_set_shadow(c, on)


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


func _build_village() -> void:
	var c := _terrain.village_center
	print("VILLAGE center=", c)

	_place(_well, Vector3(c.x, _ground(c.x, c.y), c.y), 1.8, 0.0)
	for i in range(4):
		var a := float(i) / 4.0 * TAU
		var bx := c.x + cos(a) * 8.0
		var bz := c.y + sin(a) * 8.0
		_place(_banner, Vector3(bx, _ground(bx, bz), bz), 3.0, a)

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

	for i in range(market_count):
		var a := float(i) / float(market_count) * TAU + 0.4
		var mx := c.x + cos(a) * 12.0
		var mz := c.y + sin(a) * 12.0
		_place(_market, Vector3(mx, _ground(mx, mz), mz), 1.0, atan2(c.x - mx, c.y - mz))

	var half := 42.0
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var tx: float = c.x + float(sx) * half
			var tz: float = c.y + float(sz) * half
			_place(_towers[0], Vector3(tx, _ground(tx, tz), tz), 2.2, 0.0)

	_build_wall(c, half)
	print("VILLAGE houses=", placed, " markets=", market_count)


func _build_wall(c: Vector2, half: float) -> void:
	if _walls.is_empty():
		return
	var seg := 1.55
	var gate_side := 1
	var hs := wall_height_scale
	# MultiMesh: 1 draw call para TODOS os segmentos de muralha (em vez de 212).
	var scene: PackedScene = _walls[0]
	var model: Node3D = scene.instantiate()
	var mi := _first_mesh(model)
	if mi == null:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mi.mesh
	var transforms: Array[Transform3D] = []

	for sx in [-1, 1]:
		var x: float = c.x + float(sx) * half
		var n := int((2.0 * half) / seg)
		for k in range(n):
			var z: float = c.y - half + k * seg + seg * 0.5
			if sx == gate_side and abs(z - c.y) < 3.0:
				continue
			transforms.append(Transform3D(Basis(Vector3.UP, PI / 2).scaled(Vector3(1, hs, 1)), Vector3(x, _ground(x, z), z)))
	for sz in [-1, 1]:
		var z: float = c.y + float(sz) * half
		var n := int((2.0 * half) / seg)
		for k in range(n):
			var x: float = c.x - half + k * seg + seg * 0.5
			transforms.append(Transform3D(Basis(Vector3.UP, 0.0).scaled(Vector3(1, hs, 1)), Vector3(x, _ground(x, z), z)))

	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

	# Colisão: caixas simples ao longo da muralha (baratas).
	var body := StaticBody3D.new()
	add_child(body)
	for t in transforms:
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.55, 1.5 * hs, 0.4)
		col.shape = box
		col.position = t.origin + Vector3(0, 0.75 * hs, 0)
		col.rotation.y = t.basis.get_euler().y
		body.add_child(col)

	if _wall_entrance:
		_place_scaled(_wall_entrance, Vector3(c.x + half, _ground(c.x + half, c.y), c.y), hs, PI / 2)
	model.queue_free()
	print("VILLAGE wall_segments=", transforms.size())


func _place_scaled(scene: PackedScene, pos: Vector3, height_scale: float, yaw: float) -> Node3D:
	if scene == null:
		return null
	var holder := Node3D.new()
	holder.scale = Vector3(1.0, height_scale, 1.0)
	holder.position = pos
	holder.rotation.y = yaw
	var model: Node3D = scene.instantiate()
	holder.add_child(model)
	var body := StaticBody3D.new()
	holder.add_child(body)
	_add_collisions(model, body)
	add_child(holder)
	return holder
