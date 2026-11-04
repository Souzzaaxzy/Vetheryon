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
## Escala dos edifícios. Medido: a porta do Building4 tem 0,91 m (menos que a
## metade do personagem, de 1,85 m). 2.64x deixa a porta com ~2,4 m — bem maior
## que o personagem, dando a sensação de edifício imponente.
@export var building_scale: float = 2.64
@export var tower_scale: float = 2.2
@export var wall_height_scale: float = 3.9

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
var _road_dirt: PackedScene
var _road_stone: PackedScene
var _church: PackedScene
var _barrel: PackedScene
var _chest: PackedScene
var _column: PackedScene
var _candelabrum: PackedScene


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
	_road_dirt = _try("res://assets/roads/road_dirt_straight.glb")
	_road_stone = _try("res://assets/roads/road_stone_straight.glb")
	_church = _try("res://assets/models/church.glb")
	_barrel = _try("res://assets/props/Barrel.glb")
	_chest = _try("res://assets/props/Chest.glb")
	_column = _try("res://assets/props/Column.glb")
	_candelabrum = _try("res://assets/props/Candelabrum.glb")


func _ground(x: float, z: float) -> float:
	return _terrain.height_at(x, z)


func _random_point() -> Vector3:
	for _i in range(32):
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * area_radius
		if r < center_clear_radius:
			continue
		var p := Vector2(cos(a) * r, sin(a) * r)
		# Não nascer natureza dentro da muralha (quadrada, com folga).
		var dx: float = abs(p.x - _terrain.village_center.x)
		var dz: float = abs(p.y - _terrain.village_center.y)
		if maxf(dx, dz) < _terrain.village_half + 6.0:
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
	_nature_multimesh(_tree, tree_count, 1.3, 2.2, 0.55, 3.8)
	_nature_multimesh(_tree2, tree_count / 2, 1.3, 2.0, 0.5, 3.2)
	_nature_multimesh(_bush, bush_count, 1.2, 2.0, 0.6, 1.0)
	_nature_multimesh(_rock, rock_count, 1.0, 2.4, 0.8, 1.2)
	_nature_multimesh(_flower, flower_count, 1.2, 1.8, 0.3, 0.5)
	_nature_multimesh(_mushroom, mushroom_count, 1.2, 1.8, 0.3, 0.5)
	_nature_multimesh(_crystal, crystal_count, 1.2, 2.0, 0.4, 1.4)


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

	# Muralha quadrada. Portão no lado +X. Tudo é posicionado em relação a isto.
	var half := 90.0
	var gate := Vector3(c.x + half, 0, c.y)

	# --- Praça central: poço + estandartes ---
	_place(_well, Vector3(c.x, _ground(c.x, c.y), c.y), 2.6, 0.0)
	for i in range(4):
		var a := float(i) / 4.0 * TAU + 0.4
		var bx := c.x + cos(a) * 11.0
		var bz := c.y + sin(a) * 11.0
		_place(_banner, Vector3(bx, _ground(bx, bz), bz), 4.2, a)

	# --- Grade SIMÉTRICA de edifícios dentro da muralha ---
	# 5 colunas x 4 fileiras (2 ao norte da rua, 2 ao sul) = 20 edifícios.
	var cols := [-64.0, -32.0, 0.0, 32.0, 64.0]
	var rows := [-58.0, -26.0, 26.0, 58.0]
	var house_positions: Array[Vector3] = []
	var placed := 0
	for rz in rows:
		for cx in cols:
			var x: float = c.x + cx
			var z: float = c.y + rz
			# A fileira do centro (x=0) deixa a praça livre perto do poço.
			if abs(cx) < 1.0 and abs(rz) < 20.0:
				continue
			var yaw := 0.0 if rz < 0.0 else PI  # fachada virada para a rua central
			var scn: PackedScene = _houses[placed % _houses.size()] if placed % 3 == 0 else _buildings[placed % _buildings.size()]
			_place(scn, Vector3(x, _ground(x, z), z), building_scale * _rng.randf_range(0.9, 1.0), yaw)
			house_positions.append(Vector3(x, 0, z))
			placed += 1

	# --- Igreja no fim da rua principal, oposta ao portão ---
	if _church:
		var gx := c.x - 66.0
		_place(_church, Vector3(gx, _ground(gx, c.y), c.y), 2.4, -PI / 2)

	# --- Mercados ao redor da praça ---
	for i in range(market_count):
		var a := float(i) / float(market_count) * TAU + 0.4
		var mx := c.x + cos(a) * 18.0
		var mz := c.y + sin(a) * 18.0
		_place(_market, Vector3(mx, _ground(mx, mz), mz), building_scale * 0.55, atan2(c.x - mx, c.y - mz))

	# --- Torres nos 4 cantos ---
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var tx: float = c.x + float(sx) * half
			var tz: float = c.y + float(sz) * half
			_place(_towers[0], Vector3(tx, _ground(tx, tz), tz), tower_scale, 0.0)

	_build_wall(c, half)
	# Rede de caminhos: pedra de cada edifício até a praça; terra da praça ao portão.
	_build_roads(c, house_positions, gate)
	# Detalhes que dão vida: barris, baús, candelabros e colunas.
	_dress_village(c, house_positions)
	print("VILLAGE houses=", placed, " markets=", market_count, " half=", half)


## Enfeites: barris/baús junto das casas, colunas no caminho e candelabros na praça.
func _dress_village(c: Vector2, houses: Array[Vector3]) -> void:
	var n := 0
	for h in houses:
		# Barril e baú ao lado de cada edifício.
		for _k in range(_rng.randi_range(1, 2)):
			var a := _rng.randf() * TAU
			var p := h + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(4.0, 6.5)
			p.y = _ground(p.x, p.z)
			_place(_barrel, p, building_scale * 0.5, _rng.randf() * TAU)
			n += 1
		if _rng.randf() < 0.5:
			var p2 := h + Vector3(_rng.randf_range(-5, 5), 0, _rng.randf_range(-5, 5))
			p2.y = _ground(p2.x, p2.z)
			_place(_chest, p2, building_scale * 0.5, _rng.randf() * TAU)
			n += 1

	# Colunas ladeando a rua principal (do portão à praça).
	for k in range(3):
		for side in [-1, 1]:
			var p := Vector3(c.x + 22.0 + k * 14.0, 0, c.y + float(side) * 5.5)
			p.y = _ground(p.x, p.z)
			_place(_column, p, building_scale * 0.7, 0.0)
			n += 1

	# Candelabros na praça.
	for i in range(6):
		var a := float(i) / 6.0 * TAU
		var p := Vector3(c.x + cos(a) * 7.5, 0, c.y + sin(a) * 7.5)
		p.y = _ground(p.x, p.z)
		_place(_candelabrum, p, building_scale * 0.7, a)
		n += 1
	print("VILLAGE props=", n)


func _tile_multimesh(scene: PackedScene, transforms: Array[Transform3D]) -> void:
	if scene == null or transforms.is_empty():
		return
	var model: Node3D = scene.instantiate()
	var mi := _first_mesh(model)
	if mi == null:
		model.queue_free()
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mi.mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	model.queue_free()


## Laying tiles de 2 m ao longo de uma linha (leve desvio para parecer orgânico).
func _lay_line(scene: PackedScene, out: Array[Transform3D], a: Vector3, b: Vector3) -> void:
	if scene == null:
		return
	var tile := 2.0
	var dist := a.distance_to(b)
	var n := maxi(1, int(dist / tile))
	var dir := (b - a).normalized()
	var yaw := atan2(dir.x, dir.z)
	for i in range(n):
		var t := a + dir * ((i + 0.5) * tile)
		var jitter := Vector3(_rng.randf_range(-0.15, 0.15), 0, _rng.randf_range(-0.15, 0.15))
		var p := t + jitter
		p.y = _ground(p.x, p.z) + 0.04
		out.append(Transform3D(Basis(Vector3.UP, yaw), p))


func _build_roads(c: Vector2, houses: Array[Vector3], gate: Vector3) -> void:
	var stone_tiles: Array[Transform3D] = []
	var dirt_tiles: Array[Transform3D] = []
	var center := Vector3(c.x, 0, c.y)

	# 1. Caminho de PEDRA de cada casa até o centro (a praça).
	for h in houses:
		_lay_line(_road_stone, stone_tiles, h, center)
	# Praça central pavimentada (alguns tiles ao redor do poço).
	for i in range(8):
		var a := float(i) / 8.0 * TAU
		var p := center + Vector3(cos(a), 0, sin(a)) * 3.0
		p.y = _ground(p.x, p.z) + 0.04
		stone_tiles.append(Transform3D(Basis(Vector3.UP, a), p))

	# 2. Estrada de TERRA do centro até o portão principal.
	_lay_line(_road_dirt, dirt_tiles, center, gate)

	_tile_multimesh(_road_stone, stone_tiles)
	_tile_multimesh(_road_dirt, dirt_tiles)
	print("VILLAGE road_stone=", stone_tiles.size(), " road_dirt=", dirt_tiles.size())


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
