class_name VillagePlanner
extends RefCounted

## Planeja vilas e estruturas soltas sobre o mundo do LowLand Forge.
##
## Escolhe centros de vila a partir da seed, achata o terreno sob cada vila (via
## `gen.stamps`), marca o chão como pisado (para não nascer mato dentro da vila) e
## distribui as construções do kit medieval (CC0) em volta da praça. Também espalha
## estruturas isoladas (torres, moinhos, acampamentos) pelo mapa.
##
## O mundo lê `villages` e `scattered` e monta cada construção no chunk certo.

const STRUCT_DIR := "res://assets/village_kit/structures/"
const LANDMARK_DIR := "res://assets/village_kit/pack1/"
## Marcos maiores (pack 1, Literock Studios — uso permitido em jogos), espalhados raros.
const LANDMARKS: Array[String] = [
	"Wolfhold_Barracks_II", "Granite_Legion_Watchtower_III", "Avonmere_House_II",
]

## Prédios que podem aparecer numa vila.
const VILLAGE_STRUCTS: Array[String] = [
	"Barn", "Bakery", "Brewery", "Chapel", "Inn", "Smithy", "Stable", "Granary",
	"Storehouse", "MerchantHouse", "CornerHouse", "TownhouseGablefront",
	"Hovel_Hip", "Hovel_LeanTo", "LogCabin", "Longhouse", "Lavoir", "Shack_Planks",
]
## Prédios maiores, que ficam no centro da vila.
const CENTER_STRUCTS: Array[String] = ["TownHall", "Chapel", "Inn", "Watermill", "Windmill"]
## Estruturas isoladas, longe das vilas.
const SCATTER_STRUCTS: Array[String] = [
	"GuardTower", "Windmill", "Watermill", "Camp", "Shack_Planks", "Lavoir", "Granary",
]


## Achata o terreno num disco: dentro de `r` fica em `level`, e volta ao relevo
## original ao longo de `blend` metros. Formato que o `LFTerrainGenerator.stamps` espera.
class FlatStamp extends RefCounted:
	var center: Vector2
	var radius: float
	var level: float
	var blend: float

	func _init(c: Vector2, r: float, lv: float, b: float) -> void:
		center = c
		radius = r
		level = lv
		blend = b

	func height(x: float, z: float, h: float) -> float:
		var d := Vector2(x, z).distance_to(center)
		if d >= radius + blend:
			return h
		if d <= radius:
			return level
		return lerpf(level, h, smoothstep(0.0, 1.0, (d - radius) / blend))


## Um "site" (o gerador mantém props longe de `footprint` + margem).
class SitePlan extends RefCounted:
	var footprint: float

	func _init(f: float) -> void:
		footprint = f


var villages: Array = []   # [{center: Vector2, radius: float, level: float, buildings: Array}]
var scattered: Array = []  # [{scene: String, pos: Vector3, yaw: float}]

var _footprints := {}      # scene path -> radius (m) no plano xz
var _rng := RandomNumberGenerator.new()


## Planeja tudo. Deve ser chamado DEPOIS de `gen.setup()` e ANTES de gerar chunks:
## os stamps e o ground_mask passam a valer para todo `get_height`/`compute_props`.
func plan(gen: LFTerrainGenerator, seed_value: int) -> void:
	_rng.seed = seed_value * 2654435761 + 1013904223
	villages.clear()
	scattered.clear()
	_load_footprints()
	_plan_villages(gen)
	_plan_scattered(gen)


func _load_footprints() -> void:
	if not _footprints.is_empty():
		return
	_scan_dir(STRUCT_DIR, ".tscn")
	_scan_dir(LANDMARK_DIR, ".glb")


func _scan_dir(dir_path: String, ext: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for f in dir.get_files():
		if not f.ends_with(ext):
			continue
		var path := dir_path + f
		var ps: PackedScene = load(path)
		if ps == null:
			continue
		var n: Node3D = ps.instantiate()
		var aabb := _scene_aabb(n)
		n.free()
		var r := maxf(aabb.size.x, aabb.size.z) * 0.5 + 1.0
		_footprints[path] = maxf(r, 2.0)


func _plan_villages(gen: LFTerrainGenerator) -> void:
	var center: Vector2 = gen.region_center
	var want := 7
	var placed: Array = []
	for _try in 120:
		if placed.size() >= want:
			break
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(260.0, 1500.0)
		var c := center + Vector2(cos(a), sin(a)) * r
		if not _spot_ok(gen, c, placed, 430.0):
			continue
		var level: float = gen.get_height(c.x, c.y)
		var radius := 44.0
		gen.stamps.append(FlatStamp.new(c, radius, level, 16.0))
		gen.ground_mask.add_circle(c, radius + 3.0)
		gen.add_site("village_%d" % placed.size(), SitePlan.new(radius), [Vector3(c.x, level, c.y), 0.0], 14.0)
		placed.append(c)
		villages.append({
			"center": c,
			"radius": radius,
			"level": level,
			"buildings": _layout_buildings(c, level, radius),
		})


func _layout_buildings(center: Vector2, level: float, radius: float) -> Array:
	var out: Array = []
	var taken: Array = []   # [{pos: Vector2, r: float}]
	# Uma construção grande no centro (prefeitura/capela/etc).
	var mid: String = CENTER_STRUCTS[_rng.randi() % CENTER_STRUCTS.size()]
	_try_place(STRUCT_DIR + mid + ".tscn", center, 0.0, taken, out, level)
	# Depois 7 a 12 casas em volta, em anéis.
	var count := _rng.randi_range(7, 12)
	for _i in count:
		var scene: String = VILLAGE_STRUCTS[_rng.randi() % VILLAGE_STRUCTS.size()]
		var ok := false
		for _attempt in 24:
			var ang := _rng.randf() * TAU
			var dist := _rng.randf_range(radius * 0.30, radius * 0.86)
			var p := center + Vector2(cos(ang), sin(ang)) * dist
			if _try_place(STRUCT_DIR + scene + ".tscn", p, _rng.randf() * TAU, taken, out, level):
				ok = true
				break
		if not ok:
			pass
	return out


func _try_place(scene: String, pos: Vector2, yaw: float, taken: Array, out: Array, level: float) -> bool:
	var r: float = _footprints.get(scene, 4.0)
	for t: Dictionary in taken:
		var need: float = float(t["r"]) + r + 3.0
		if (t["pos"] as Vector2).distance_squared_to(pos) < need * need:
			return false
	taken.append({"pos": pos, "r": r})
	out.append({"scene": scene, "pos": Vector3(pos.x, level, pos.y), "yaw": yaw})
	return true


func _plan_scattered(gen: LFTerrainGenerator) -> void:
	var center: Vector2 = gen.region_center
	var want := 16
	var placed: Array = []
	for _try in 200:
		if scattered.size() >= want:
			break
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(180.0, 1700.0)
		var c := center + Vector2(cos(a), sin(a)) * r
		if not _spot_ok(gen, c, placed, 130.0):
			continue
		# longe de qualquer vila
		var near_village := false
		for v: Dictionary in villages:
			if (v["center"] as Vector2).distance_to(c) < float(v["radius"]) + 60.0:
				near_village = true
				break
		if near_village:
			continue
		var path: String
		if _rng.randf() < 0.22:
			path = LANDMARK_DIR + LANDMARKS[_rng.randi() % LANDMARKS.size()] + ".glb"
		else:
			var scene: String = SCATTER_STRUCTS[_rng.randi() % SCATTER_STRUCTS.size()]
			path = STRUCT_DIR + scene + ".tscn"
		var level: float = gen.get_height(c.x, c.y)
		gen.stamps.append(FlatStamp.new(c, 16.0, level, 8.0))
		gen.ground_mask.add_circle(c, 15.0)
		gen.add_site("scatter_%d" % placed.size(), SitePlan.new(16.0), [Vector3(c.x, level, c.y), 0.0], 8.0)
		placed.append(c)
		scattered.append({"scene": path, "pos": Vector3(c.x, level, c.y), "yaw": _rng.randf() * TAU})


## Um ponto bom para uma vila/estrutura: em terra, plano e longe dos outros.
func _spot_ok(gen: LFTerrainGenerator, c: Vector2, placed: Array, min_dist: float) -> bool:
	for p: Vector2 in placed:
		if p.distance_to(c) < min_dist:
			return false
	var h: float = gen.get_height(c.x, c.y)
	if h < 1.5:
		return false   # perto da água / no mar
	if gen.water_level_at(c.x, c.y) > h - 0.6:
		return false
	var e := 5.0
	var dh := absf(gen.get_height(c.x + e, c.y) - h)
	dh = maxf(dh, absf(gen.get_height(c.x - e, c.y) - h))
	dh = maxf(dh, absf(gen.get_height(c.x, c.y + e) - h))
	dh = maxf(dh, absf(gen.get_height(c.x, c.y - e) - h))
	if dh > 1.6:
		return false   # muito inclinado
	return true


func _scene_aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for m in _meshes(n):
		var a: AABB = (m as VisualInstance3D).get_aabb()
		var gt: Transform3D = (m as Node3D).transform
		a = gt * a
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	return out


func _meshes(n: Node) -> Array:
	var o: Array = []
	if n is MeshInstance3D:
		o.append(n)
	for c in n.get_children():
		o.append_array(_meshes(c))
	return o
