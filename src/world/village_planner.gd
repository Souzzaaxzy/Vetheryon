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
## Estruturas isoladas comuns (aparecem em qualquer bioma).
const SCATTER_STRUCTS: Array[String] = [
	"GuardTower", "Windmill", "Watermill", "Camp", "Shack_Planks", "Lavoir", "Granary",
]
## Estruturas por bioma: quando o ponto cai num bioma, prefere estas.
const BIOME_STRUCTS := {
	"Pine Forest": ["ForesterHut", "SawpitYard", "CharcoalBurner", "Camp", "LogCabin"],
	"Old Growth": ["ForesterHut", "SawpitYard", "Camp", "LogCabin"],
	"Birch Woods": ["ForesterHut", "Apiary", "Camp", "LogCabin"],
	"Meadow": ["Sheepfold", "Apiary", "Barn", "Pigsty", "Windmill", "Stable"],
	"Palm Coast": ["FisherHut", "Camp", "Shack_Planks", "Lavoir"],
	"Desert": ["Camp", "Shack_Planks", "GuardTower", "Mine"],
	"Ash Barrens": ["Mine", "CharcoalBurner", "Camp", "GuardTower"],
	"Frozen Highlands": ["Mine", "GuardTower", "Camp", "ForesterHut"],
	"Drowned Marsh": ["FisherHut", "Camp", "Shack_Planks", "Lavoir"],
}
## Castelos (CC0, Grab3D): peças modulares com interior e exterior. Formam um
## castelo grande (muralha + torres + portão + fortaleza) num lugar aberto.
const CASTLE_DIR := "res://assets/castle/"
const CASTLE_MAIN := ["castle", "neuschwanstein-castle"]

## Construções de vila por bioma (senão usa as genéricas).
const BIOME_VILLAGE := {
	"Palm Coast": ["FisherHut", "Shack_Planks", "Lavoir", "Inn", "Stable", "Storehouse"],
	"Desert": ["Shack_Planks", "Stable", "Storehouse", "Granary", "Inn"],
	"Ash Barrens": ["Shack_Planks", "Smithy", "Storehouse", "GuardTower", "Camp"],
	"Frozen Highlands": ["LogCabin", "Storehouse", "Smithy", "Granary", "Inn"],
	"Drowned Marsh": ["Shack_Planks", "Lavoir", "Storehouse", "Inn", "FisherHut"],
}


## Achata o terreno em vários discos (vilas, estruturas). Guarda os discos num
## índice espacial: `get_height` é chamado milhares de vezes por chunk, então
## testar TODOS os discos a cada chamada era o que travava o carregamento
## (311 discos -> 50x mais lento). Com o índice só testamos os discos da célula.
##
## Formato que o `LFTerrainGenerator.stamps` espera (um objeto com `height(x,z,h)`).
class StampSet extends RefCounted:
	const BUCKET := 64.0
	var _flats: Array = []        # [Vector4(center.x, center.y, radius, level), blend]
	var _buckets: Dictionary = {}  # Vector2i -> PackedInt32Array (índices)

	func add(center: Vector2, radius: float, level: float, blend: float) -> void:
		var idx := _flats.size()
		_flats.append([center, radius, level, blend])
		var reach := radius + blend
		var b0 := Vector2i(floori((center.x - reach) / BUCKET), floori((center.y - reach) / BUCKET))
		var b1 := Vector2i(floori((center.x + reach) / BUCKET), floori((center.y + reach) / BUCKET))
		for by in range(b0.y, b1.y + 1):
			for bx in range(b0.x, b1.x + 1):
				var k := Vector2i(bx, by)
				if not _buckets.has(k):
					_buckets[k] = PackedInt32Array()
				var arr: PackedInt32Array = _buckets[k]
				arr.append(idx)
				_buckets[k] = arr

	func height(x: float, z: float, h: float) -> float:
		var k := Vector2i(floori(x / BUCKET), floori(z / BUCKET))
		var arr: Variant = _buckets.get(k)
		if arr == null:
			return h
		for i: int in (arr as PackedInt32Array):
			var f: Array = _flats[i]
			var center: Vector2 = f[0]
			var radius: float = f[1]
			var level: float = f[2]
			var blend: float = f[3]
			var d := Vector2(x, z).distance_to(center)
			if d <= radius:
				h = level
			elif d < radius + blend:
				h = lerpf(level, h, smoothstep(0.0, 1.0, (d - radius) / blend))
		return h


## Um "site" (o gerador mantém props longe de `footprint` + margem).
class SitePlan extends RefCounted:
	var footprint: float

	func _init(f: float) -> void:
		footprint = f


var villages: Array = []   # [{center: Vector2, radius: float, level: float, buildings: Array}]
var scattered: Array = []  # [{scene: String, pos: Vector3, yaw: float}]
var castles: Array = []    # [{scene: String, pos: Vector3, yaw: float, scale: float}]

var _footprints := {}      # scene path -> radius (m) no plano xz
var _stamps: StampSet       # índice espacial dos achatamentos do terreno
var _rng := RandomNumberGenerator.new()


## Planeja tudo. Deve ser chamado DEPOIS de `gen.setup()` e ANTES de gerar chunks:
## os stamps e o ground_mask passam a valer para todo `get_height`/`compute_props`.
func plan(gen: LFTerrainGenerator, seed_value: int) -> void:
	_rng.seed = seed_value * 2654435761 + 1013904223
	villages.clear()
	scattered.clear()
	_load_footprints()
	# Um único objeto em `gen.stamps`: o índice espacial faz get_height só
	# olhar os discos próximos, em vez de todos.
	_stamps = StampSet.new()
	gen.stamps.append(_stamps)
	_plan_villages(gen)
	_plan_scattered(gen)
	_plan_castles(gen)


## Raio aproximado (m) por tipo de predio. Fixo de propósito: medir instanciando
## cada cena custava caro no inicio (o planejamento travava o jogo).
const FOOTPRINT_BIG := ["TownHall", "Chapel", "Inn", "Storehouse", "Longhouse",
	"MerchantHouse", "Terrace", "Watermill", "Windmill", "Barn", "Brewery", "Stable", "Granary"]
const FOOTPRINT_SMALL := ["Shack_Planks", "Apiary", "Pigsty", "Lavoir", "Camp",
	"FisherHut", "CharcoalBurner", "SawpitYard", "Smokehouse", "Pottery", "DyersYard", "Mine"]


func _load_footprints() -> void:
	if not _footprints.is_empty():
		return
	for n in FOOTPRINT_BIG:
		_footprints[STRUCT_DIR + n + ".tscn"] = 11.0
	for n in FOOTPRINT_SMALL:
		_footprints[STRUCT_DIR + n + ".tscn"] = 5.0
	for n in ["castle", "neuschwanstein-castle"]:
		_footprints[CASTLE_DIR + n + ".glb"] = 18.0
	for n in ["keep", "gatehouse"]:
		_footprints[CASTLE_DIR + n + ".glb"] = 9.0
	for n in ["castle-tower", "castle-wall", "portcullis", "drawbridge"]:
		_footprints[CASTLE_DIR + n + ".glb"] = 5.0


func _plan_villages(gen: LFTerrainGenerator) -> void:
	var center: Vector2 = gen.region_center
	var spawn: Vector2 = gen.spawn_xz
	var placed: Array = []
	# Grade jitterada: garante vilas espalhadas por todo o mapa (não só no centro).
	# Primeiro garante uma vila perto do spawn (o jogador acha logo de cara).
	_place_village(gen, spawn + Vector2(150.0, 40.0), placed, 40.0)
	var spacing := 220.0
	var n := 8
	for gz in range(-n, n + 1):
		for gx in range(-n, n + 1):
			var c := center + Vector2(gx, gz) * spacing
			c += Vector2(_rng.randf_range(-80.0, 80.0), _rng.randf_range(-80.0, 80.0))
			if c.distance_to(spawn) < 120.0:
				continue   # deixa o spawn livre
			if _rng.randf() > 0.78:
				continue   # nem toda célula tem vila
			if not _spot_ok(gen, c, placed, spacing * 0.8):
				continue
			_place_village(gen, c, placed, 40.0)


## Acha um ponto bom perto de `near` e cria a vila ali.
func _place_village(gen: LFTerrainGenerator, near: Vector2, placed: Array, radius: float) -> void:
	var c := near
	var found := false
	for _try in 8:
		if _spot_ok(gen, c, placed, radius * 1.6):
			found = true
			break
		c = near + Vector2(_rng.randf_range(-60.0, 60.0), _rng.randf_range(-60.0, 60.0))
	if not found:
		return
	var level: float = gen.get_height(c.x, c.y)
	_stamps.add(c, radius, level, 14.0)
	gen.ground_mask.add_circle(c, radius + 3.0)
	gen.add_site("village_%d" % placed.size(), SitePlan.new(radius), [Vector3(c.x, level, c.y), 0.0], 14.0)
	placed.append(c)
	villages.append({
		"center": c,
		"radius": radius,
		"level": level,
		"buildings": _layout_buildings(gen, c, level, radius),
	})


func _layout_buildings(gen: LFTerrainGenerator, center: Vector2, level: float, radius: float) -> Array:
	var out: Array = []
	var taken: Array = []
	var biome := _biome_at(gen, center)
	var village_set: Array = BIOME_VILLAGE.get(biome, [])
	# Uma construção grande no centro.
	var mid: String = CENTER_STRUCTS[_rng.randi() % CENTER_STRUCTS.size()]
	_try_place(STRUCT_DIR + mid + ".tscn", center, _rng.randf() * TAU, taken, out, level)
	# 6 a 10 casas em volta.
	var count := _rng.randi_range(9, 16)
	for _i in count:
		var scene: String
		if not village_set.is_empty() and _rng.randf() < 0.6:
			scene = village_set[_rng.randi() % village_set.size()]
		else:
			scene = VILLAGE_STRUCTS[_rng.randi() % VILLAGE_STRUCTS.size()]
		var path := STRUCT_DIR + scene + ".tscn"
		if not _footprints.has(path):
			continue
		for _attempt in 24:
			var ang := _rng.randf() * TAU
			var dist := _rng.randf_range(radius * 0.30, radius * 0.86)
			var p := center + Vector2(cos(ang), sin(ang)) * dist
			if _try_place(path, p, _rng.randf() * TAU, taken, out, level):
				break
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
	var spawn: Vector2 = gen.spawn_xz
	var placed: Array = []
	# Grade mais fina: estruturas soltas por todo o mapa (você sempre acha algo).
	# Algumas estruturas logo perto do spawn (a primeira vista acontece rápido).
	for k in 6:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(60.0, 170.0)
		_scatter_at(gen, spawn + Vector2(cos(a), sin(a)) * r, placed)
	var spacing := 110.0
	var n := 15
	for gz in range(-n, n + 1):
		for gx in range(-n, n + 1):
			var c := center + Vector2(gx, gz) * spacing
			c += Vector2(_rng.randf_range(-45.0, 45.0), _rng.randf_range(-45.0, 45.0))
			if c.distance_to(spawn) < 45.0:
				continue
			if _rng.randf() > 0.62:
				continue
			if not _spot_ok(gen, c, placed, spacing * 0.75):
				continue
			_scatter_at(gen, c, placed)


## Coloca uma estrutura solta em `c` (se o lugar servir).
func _scatter_at(gen: LFTerrainGenerator, c: Vector2, placed: Array) -> void:
	if not _spot_ok(gen, c, placed, 26.0):
		return
	for v: Dictionary in villages:
		if (v["center"] as Vector2).distance_to(c) < float(v["radius"]) + 30.0:
			return
	var path := _pick_structure(gen, c)
	if path == "":
		return
	var level: float = gen.get_height(c.x, c.y)
	_stamps.add(c, 14.0, level, 7.0)
	gen.ground_mask.add_circle(c, 13.0)
	gen.add_site("scatter_%d" % placed.size(), SitePlan.new(14.0), [Vector3(c.x, level, c.y), 0.0], 8.0)
	placed.append(c)
	scattered.append({"scene": path, "pos": Vector3(c.x, level, c.y), "yaw": _rng.randf() * TAU})


## Espalha castelos: um "principal" (muralha + torres) e torres/muralhas soltas.
func _plan_castles(gen: LFTerrainGenerator) -> void:
	var center: Vector2 = gen.region_center
	var spawn: Vector2 = gen.spawn_xz
	var placed: Array = []
	# Um castelo principal garantido a ~600 m do spawn (dá para achar caminhando).
	_place_castle(gen, spawn + Vector2(430.0, 320.0), placed, CASTLE_MAIN, 22.0)
	# Outros castelos espalhados (raros).
	var spacing := 900.0
	var n := 4
	for gz in range(-n, n + 1):
		for gx in range(-n, n + 1):
			var c := center + Vector2(gx, gz) * spacing
			c += Vector2(_rng.randf_range(-150.0, 150.0), _rng.randf_range(-150.0, 150.0))
			if c.distance_to(spawn) < 320.0:
				continue
			if _rng.randf() > 0.6:
				continue
			if not _spot_ok(gen, c, placed, spacing * 0.7):
				continue
			_place_castle(gen, c, placed, CASTLE_MAIN, 22.0)
	# Torres/muralhas soltas, mais comuns, para dar clima de reino.
	var spacing2 := 420.0
	for gz in range(-6, 7):
		for gx in range(-6, 7):
			var c := center + Vector2(gx, gz) * spacing2
			c += Vector2(_rng.randf_range(-90.0, 90.0), _rng.randf_range(-90.0, 90.0))
			if c.distance_to(spawn) < 200.0:
				continue
			if _rng.randf() > 0.30:
				continue
			var piece: String = ["castle-tower", "castle-wall", "gatehouse", "keep", "portcullis", "drawbridge"][_rng.randi() % 6]
			_place_castle(gen, c, placed, [piece], 7.0)


func _place_castle(gen: LFTerrainGenerator, near: Vector2, placed: Array, pool: Array, radius: float) -> void:
	var c := near
	var found := false
	for _try in 12:
		if _spot_ok(gen, c, placed, radius * 2.2):
			found = true
			break
		c = near + Vector2(_rng.randf_range(-90.0, 90.0), _rng.randf_range(-90.0, 90.0))
	if not found:
		return
	var piece: String = pool[_rng.randi() % pool.size()]
	var level: float = gen.get_height(c.x, c.y)
	_stamps.add(c, radius, level, radius * 0.5)
	gen.ground_mask.add_circle(c, radius)
	gen.add_site("castle_%d" % placed.size(), SitePlan.new(radius), [Vector3(c.x, level, c.y), 0.0], 10.0)
	placed.append(c)
	castles.append({"scene": CASTLE_DIR + piece + ".glb", "pos": Vector3(c.x, level, c.y), "yaw": _rng.randf() * TAU, "scale": 1.0})


## Escolhe a estrutura para um ponto: as do bioma, senão as comuns; às vezes um marco.
func _pick_structure(gen: LFTerrainGenerator, c: Vector2) -> String:
	if _rng.randf() < 0.06:
		return LANDMARK_DIR + LANDMARKS[_rng.randi() % LANDMARKS.size()] + ".glb"
	var biome := _biome_at(gen, c)
	var pool: Array = BIOME_STRUCTS.get(biome, [])
	if not pool.is_empty() and _rng.randf() < 0.75:
		var scene: String = pool[_rng.randi() % pool.size()]
		var path := STRUCT_DIR + scene + ".tscn"
		if _footprints.has(path):
			return path
	var scene2: String = SCATTER_STRUCTS[_rng.randi() % SCATTER_STRUCTS.size()]
	return STRUCT_DIR + scene2 + ".tscn"


## Nome do bioma dominante num ponto.
func _biome_at(gen: LFTerrainGenerator, c: Vector2) -> String:
	var w := gen.biome_weights(c.x, c.y)
	var idx := LFTerrainGenerator.pick_biome(w, 0.5)
	var defs := gen.biomes()
	if idx >= 0 and idx < defs.size():
		return defs[idx].name
	return ""


## Um ponto bom para uma vila/estrutura: em terra firme e longe dos outros.
## Usa `base_height` (barato) e só uma amostra: o relevo do ponto é achatado
## pelo achatamento de qualquer jeito, então não precisa medir a inclinação.
func _spot_ok(gen: LFTerrainGenerator, c: Vector2, placed: Array, min_dist: float) -> bool:
	for p: Vector2 in placed:
		if p.distance_to(c) < min_dist:
			return false
	var h: float = gen.base_height(c.x, c.y)
	if h < 2.0:
		return false   # perto da água / no mar
	if gen.water_level_at(c.x, c.y) > h - 0.6:
		return false
	return true
