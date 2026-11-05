class_name VillagePlanner
extends RefCounted

## Planeja vilas, castelos e estruturas soltas sobre o mundo do LowLand Forge,
## usando os modelos CC0 do KayKit (Medieval Hexagon Pack) + Kenney.
##
## Escolhe os lugares a partir da seed, achata o terreno sob cada lugar (via
## `gen.stamps`), marca o chão como pisado (para não nascer mato dentro) e monta:
##   - vilas: uma praça com prédios em volta (ferreiro, taverna, casas...);
##   - castelos: muralha + torres + portão + fortaleza (uma cidadela de verdade);
##   - estruturas soltas: torres, acampamentos, moinhos, pedras, árvores.
##
## O mundo lê `villages`, `castles` e `scattered` e monta cada peça no chunk certo.

const KK := "res://assets/kaykit/"

## Prédios de vila (por cor; o planner sorteia uma cor por vila para dar identidade).
const VILLAGE_BUILDINGS: Array[String] = [
	"building_home_A", "building_home_B", "building_blacksmith", "building_tavern",
	"building_market", "building_church", "building_lumbermill", "building_watermill",
	"building_windmill", "building_mine", "building_barracks", "building_archeryrange",
]
## Prédio grande no centro da vila.
const VILLAGE_CENTER: Array[String] = ["building_church", "building_market", "building_barracks"]
## Peças de castelo (neutral = cor única, serve para qualquer reino).
const CASTLE_WALLS: Array[String] = [
	"wall_straight", "wall_straight", "wall_straight", "wall_corner_A_inside",
	"wall_corner_A_outside", "wall_corner_B_inside", "wall_corner_B_outside",
]
const CASTLE_GATE := "wall_straight_gate"
const CASTLE_KEEP := "building_castle"
const CASTLE_TOWER := "building_tower_A"
const CASTLE_TOWER_BASE := "building_tower_base"
## Props de decoração (também por cor quando faz sentido).
const DECOR_ROCKS: Array[String] = [
	"decoration/nature/rock_single_A", "decoration/nature/rock_single_B",
	"decoration/nature/rock_single_C", "decoration/nature/rock_single_D",
	"decoration/nature/rock_single_E",
]
const DECOR_TREES: Array[String] = [
	"decoration/nature/trees_A_large", "decoration/nature/trees_A_medium",
	"decoration/nature/trees_A_small", "decoration/nature/trees_B_large",
	"decoration/nature/trees_B_medium", "decoration/nature/trees_B_small",
	"decoration/nature/tree_single_A", "decoration/nature/tree_single_B",
]
const DECOR_PROPS: Array[String] = [
	"decoration/props/barrel", "decoration/props/crate_A_big", "decoration/props/crate_A_small",
	"decoration/props/crate_long_A", "decoration/props/tent", "decoration/props/ladder",
	"decoration/props/sack", "decoration/props/target", "decoration/props/weaponrack",
	"decoration/props/wheelbarrow", "decoration/props/resource_lumber",
	"decoration/props/resource_stone", "decoration/props/pallet",
]

## Escala: os modelos do KayKit são de grade hexagonal (~1 hex = 1 unidade). Para
## uma casa ter ~7 m de largura (como as nossas), multiplicamos por este fator.
const KK_SCALE := 3.4
## Cor sorteada por vila/castelo.
const COLORS: Array[String] = ["blue", "green", "red", "yellow"]


## Achata o terreno em vários discos (vilas, estruturas). Guarda os discos num
## índice espacial: `get_height` é chamado milhares de vezes por chunk, então
## testar TODOS os discos a cada chamada travava o carregamento.
##
## Formato que o `LFTerrainGenerator.stamps` espera (um objeto com `height(x,z,h)`).
class StampSet extends RefCounted:
	const BUCKET := 64.0
	var _flats: Array = []
	var _buckets: Dictionary = {}

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


var villages: Array = []   # [{center, radius, level, buildings}]
var scattered: Array = []  # [{scene, pos, yaw, scale}]
var castles: Array = []    # [{scene, pos, yaw, scale}]

var _stamps: StampSet
var _rng := RandomNumberGenerator.new()


## Planeja tudo. Deve ser chamado DEPOIS de `gen.setup()` e ANTES de gerar chunks.
func plan(gen: LFTerrainGenerator, seed_value: int) -> void:
	_rng.seed = seed_value * 2654435761 + 1013904223
	villages.clear()
	scattered.clear()
	castles.clear()
	_stamps = StampSet.new()
	gen.stamps.append(_stamps)
	_plan_villages(gen)
	_plan_castles(gen)
	_plan_scattered(gen)


# --- vilas ------------------------------------------------------------------

func _plan_villages(gen: LFTerrainGenerator) -> void:
	var center: Vector2 = gen.region_center
	var spawn: Vector2 = gen.spawn_xz
	var placed: Array = []
	# Uma vila garantida logo perto do spawn.
	_place_village(gen, spawn + Vector2(120.0, 60.0), placed, 46.0)
	var spacing := 260.0
	var n := 7
	for gz in range(-n, n + 1):
		for gx in range(-n, n + 1):
			var c := center + Vector2(gx, gz) * spacing
			c += Vector2(_rng.randf_range(-80.0, 80.0), _rng.randf_range(-80.0, 80.0))
			if c.distance_to(spawn) < 110.0:
				continue
			if _rng.randf() > 0.72:
				continue
			if not _spot_ok(gen, c, placed, spacing * 0.8):
				continue
			_place_village(gen, c, placed, 46.0)


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
	_stamps.add(c, radius, level, 16.0)
	gen.ground_mask.add_circle(c, radius + 3.0)
	gen.add_site("village_%d" % placed.size(), SitePlan.new(radius), [Vector3(c.x, level, c.y), 0.0], 14.0)
	placed.append(c)
	villages.append({
		"center": c,
		"radius": radius,
		"level": level,
		"buildings": _layout_village(gen, c, level, radius),
	})


## Monta a vila: um prédio central (igreja/mercado/quartel) + casas em volta.
func _layout_village(gen: LFTerrainGenerator, center: Vector2, level: float, radius: float) -> Array:
	var out: Array = []
	var taken: Array = []
	var color: String = COLORS[_rng.randi() % COLORS.size()]
	# Prédio central.
	var mid: String = VILLAGE_CENTER[_rng.randi() % VILLAGE_CENTER.size()]
	_try_place(_building_path(mid, color), center, _rng.randf() * TAU, taken, out, level, 7.0)
	# Casas e oficinas em volta, em 2 anéis.
	var count := _rng.randi_range(10, 16)
	for _i in count:
		var name: String = VILLAGE_BUILDINGS[_rng.randi() % VILLAGE_BUILDINGS.size()]
		var path := _building_path(name, color)
		for _attempt in 28:
			var ang := _rng.randf() * TAU
			var dist := _rng.randf_range(radius * 0.32, radius * 0.92)
			var p := center + Vector2(cos(ang), sin(ang)) * dist
			if _try_place(path, p, _rng.randf() * TAU, taken, out, level, 7.0):
				break
	# Decoração espalhada (barris, caixas, árvores, pedras).
	for _i in _rng.randi_range(8, 16):
		var ang2 := _rng.randf() * TAU
		var dist2 := _rng.randf_range(radius * 0.25, radius * 0.98)
		var p2 := center + Vector2(cos(ang2), sin(ang2)) * dist2
		var dname: String = DECOR_PROPS[_rng.randi() % DECOR_PROPS.size()]
		if _rng.randf() < 0.35:
			dname = DECOR_TREES[_rng.randi() % DECOR_TREES.size()]
		_try_place(KK + dname + ".gltf", p2, _rng.randf() * TAU, taken, out, level, 1.5)
	return out


func _building_path(name: String, color: String) -> String:
	return KK + "buildings/" + color + "/" + name + "_" + color + ".gltf"


# --- castelos ---------------------------------------------------------------

## Um castelo montado: muralha em anel + torres nos cantos + portão + fortaleza.
func _plan_castles(gen: LFTerrainGenerator) -> void:
	var center: Vector2 = gen.region_center
	var spawn: Vector2 = gen.spawn_xz
	var placed: Array = []
	# Castelo principal garantido a ~400 m do spawn.
	_build_castle(gen, spawn + Vector2(330.0, 240.0), placed, 30.0)
	# Outros castelos espalhados.
	var spacing := 780.0
	var n := 4
	for gz in range(-n, n + 1):
		for gx in range(-n, n + 1):
			var c := center + Vector2(gx, gz) * spacing
			c += Vector2(_rng.randf_range(-120.0, 120.0), _rng.randf_range(-120.0, 120.0))
			if c.distance_to(spawn) < 300.0:
				continue
			if _rng.randf() > 0.55:
				continue
			if not _spot_ok(gen, c, placed, spacing * 0.7):
				continue
			_build_castle(gen, c, placed, 30.0)


func _build_castle(gen: LFTerrainGenerator, near: Vector2, placed: Array, radius: float) -> void:
	var c := near
	var found := false
	for _try in 10:
		if _spot_ok(gen, c, placed, radius * 2.0):
			found = true
			break
		c = near + Vector2(_rng.randf_range(-70.0, 70.0), _rng.randf_range(-70.0, 70.0))
	if not found:
		return
	var level: float = gen.get_height(c.x, c.y)
	# Aplaina uma área grande e redonda para a muralha ficar reta.
	_stamps.add(c, radius, level, 18.0)
	gen.ground_mask.add_circle(c, radius + 4.0)
	gen.add_site("castle_%d" % placed.size(), SitePlan.new(radius), [Vector3(c.x, level, c.y), 0.0], 12.0)
	placed.append(c)

	var parts: Array = []
	var wall := 22.0   # meio-lado do quadrado da muralha
	var seg := 6.0     # comprimento de cada peça de muralha (no mundo)
	var color: String = COLORS[_rng.randi() % COLORS.size()]
	# Muralha: 4 lados, com portão no lado sul.
	var sides := [
		[Vector2(0, -wall), Vector2(1, 0)],   # norte
		[Vector2(0, wall), Vector2(1, 0)],    # sul
		[Vector2(-wall, 0), Vector2(0, 1)],   # oeste
		[Vector2(wall, 0), Vector2(0, 1)],    # leste
	]
	for si in sides.size():
		var base: Vector2 = sides[si][0]
		var dir: Vector2 = sides[si][1]
		var count := int(round((wall * 2.0) / seg))
		for i in count:
			var t := -wall + (i + 0.5) * (wall * 2.0 / count)
			var p: Vector2 = c + base + dir * t
			var yaw := 0.0 if dir.y != 0 else PI * 0.5
			var piece := "wall_straight"
			if si == 1 and i == count / 2:
				piece = CASTLE_GATE   # portão no meio do lado sul
			parts.append({"scene": KK + "buildings/neutral/" + piece + ".gltf",
				"pos": Vector3(p.x, level, p.y), "yaw": yaw, "scale": KK_SCALE * 1.5})
	# Torres nos 4 cantos.
	for cx in [-wall, wall]:
		for cz in [-wall, wall]:
			var p := c + Vector2(cx, cz)
			parts.append({"scene": KK + "buildings/neutral/" + CASTLE_TOWER_BASE + ".gltf",
				"pos": Vector3(p.x, level, p.y), "yaw": 0.0, "scale": KK_SCALE * 1.5})
			parts.append({"scene": KK + "buildings/neutral/" + CASTLE_TOWER + ".gltf",
				"pos": Vector3(p.x, level + 3.4, p.y), "yaw": 0.0, "scale": KK_SCALE * 1.5})
	# Fortaleza (castelo) no centro.
	parts.append({"scene": _building_path(CASTLE_KEEP, color),
		"pos": Vector3(c.x, level, c.y), "yaw": _rng.randf() * TAU, "scale": KK_SCALE * 1.6})
	# As peças entram na lista de estruturas soltas (montadas no chunk certo).
	for pt: Dictionary in parts:
		scattered.append(pt)


# --- estruturas soltas ------------------------------------------------------

func _plan_scattered(gen: LFTerrainGenerator) -> void:
	var center: Vector2 = gen.region_center
	var spawn: Vector2 = gen.spawn_xz
	var placed: Array = []
	# Alguns enfeites logo perto do spawn (primeira vista).
	for k in 8:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(40.0, 160.0)
		_scatter_at(gen, spawn + Vector2(cos(a), sin(a)) * r, placed)
	var spacing := 90.0
	var n := 18
	for gz in range(-n, n + 1):
		for gx in range(-n, n + 1):
			var c := center + Vector2(gx, gz) * spacing
			c += Vector2(_rng.randf_range(-40.0, 40.0), _rng.randf_range(-40.0, 40.0))
			if c.distance_to(spawn) < 30.0:
				continue
			if _rng.randf() > 0.55:
				continue
			if not _spot_ok(gen, c, placed, spacing * 0.7):
				continue
			_scatter_at(gen, c, placed)


## Um enfeite/estrutura solta em `c`: às vezes um prédio grande (moinho, torre),
## às vezes um acampamento, e no resto do tempo pedras/árvores.
func _scatter_at(gen: LFTerrainGenerator, c: Vector2, placed: Array) -> void:
	if not _spot_ok(gen, c, placed, 22.0):
		return
	for v: Dictionary in villages:
		if (v["center"] as Vector2).distance_to(c) < float(v["radius"]) + 24.0:
			return
	var roll := _rng.randf()
	var path := ""
	var scale := KK_SCALE
	var stamp_r := 4.0
	var level: float = gen.get_height(c.x, c.y)
	if roll < 0.18:
		# Prédio grande solto (moinho, torre, mina).
		var big: Array[String] = ["building_windmill", "building_watermill", "building_tower_A",
			"building_tower_B", "building_mine", "building_lumbermill"]
		var name: String = big[_rng.randi() % big.size()]
		var color: String = COLORS[_rng.randi() % COLORS.size()]
		path = _building_path(name, color)
		stamp_r = 8.0
	elif roll < 0.30:
		# Acampamento.
		path = KK + "decoration/props/tent.gltf"
		scale = KK_SCALE * 1.3
		stamp_r = 5.0
	else:
		# Natureza: árvore ou pedra.
		if _rng.randf() < 0.6:
			path = KK + DECOR_TREES[_rng.randi() % DECOR_TREES.size()] + ".gltf"
			scale = KK_SCALE * 2.6   # árvores altas
		else:
			path = KK + DECOR_ROCKS[_rng.randi() % DECOR_ROCKS.size()] + ".gltf"
			scale = KK_SCALE * 1.6
		stamp_r = 2.0
	if stamp_r > 3.0:
		_stamps.add(c, stamp_r, level, 6.0)
		gen.ground_mask.add_circle(c, stamp_r - 1.0)
		gen.add_site("scatter_%d" % placed.size(), SitePlan.new(stamp_r), [Vector3(c.x, level, c.y), 0.0], 6.0)
	placed.append(c)
	scattered.append({"scene": path, "pos": Vector3(c.x, level, c.y), "yaw": _rng.randf() * TAU, "scale": scale})


func _try_place(scene: String, pos: Vector2, yaw: float, taken: Array, out: Array, level: float, r: float) -> bool:
	for t: Dictionary in taken:
		var need: float = float(t["r"]) + r + 1.5
		if (t["pos"] as Vector2).distance_squared_to(pos) < need * need:
			return false
	taken.append({"pos": pos, "r": r})
	out.append({"scene": scene, "pos": Vector3(pos.x, level, pos.y), "yaw": yaw, "scale": KK_SCALE})
	return true


## Um ponto bom: em terra firme e longe dos outros.
func _spot_ok(gen: LFTerrainGenerator, c: Vector2, placed: Array, min_dist: float) -> bool:
	for p: Vector2 in placed:
		if p.distance_to(c) < min_dist:
			return false
	var h: float = gen.base_height(c.x, c.y)
	if h < 2.0:
		return false
	if gen.water_level_at(c.x, c.y) > h - 0.6:
		return false
	return true
