extends Node3D
class_name VetheryonWorld

## Mundo INFINITO por chunks, gerado em runtime (como Minecraft).
##
## Usa o gerador procedural do LowLand Forge (LFTerrainGenerator) direto em memória
## — sem escrever arquivos, então funciona no Android. Cada chunk (128 m) é gerado
## numa thread e montado, um por frame, no thread principal.
##
## Mantém 5 chunks em cruz (o do jogador + 4 vizinhos). Ao sair da cruz, o chunk é
## liberado; se o jogador voltar, é gerado DE NOVO (mesma seed => mesmo terreno).
## Cada chunk traz o terreno (heightmap), as árvores/pedras (MultiMesh) e a colisão
## de tudo (heightmap + troncos/pedras/troncos caídos).

const CHUNK := LFTileBaker.BLOCK          # 128 m
const BLOCK_CELLS := LFTileBaker.BLOCK_CELLS
## 5 chunks em cruz (o do jogador + 4 vizinhos) = 128 m em cada direção.
const CHUNK_OFFSETS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
]
const MAX_PER_FRAME := 1                  # montagens por frame (limita o travamento)

@export var world_seed: int = 20261104
@export var preset: String = "Rolling Plains"
@export var density: float = 0.5
@export var player_path: NodePath
## Dimensiona os predios pela porta: a porta fica `door_factor` x a altura do
## personagem (bem maior que ele) e o predio inteiro e escalado junto, para nao
## parecer casinha de boneca.
@export var door_factor: float = 1.45
@export var door_margin: float = 0.15

var _gen: LFTerrainGenerator
var _lib: LFPropMeshes
var _terrain_shader: Shader
var _player: Node3D

var _chunks: Dictionary = {}       # Vector2i -> Node3D (montado)
var _inflight: Dictionary = {}     # Vector2i -> true (gerando agora numa thread)
var _center := Vector2i(999999, 999999)

# As threads escrevem aqui; o Mutex protege a fila. Montamos no thread principal.
var _mutex := Mutex.new()
var _results: Array = []           # [ {coord, block} ] prontos para montar

var _planner: VillagePlanner
var _struct_scenes: Dictionary = {}   # path -> PackedScene
var _baked: Dictionary = {}          # path -> {mesh, aabb} (construcao cozida)
var _player_h := 1.9                 # altura do personagem (medida no _ready)
var _pending_structs: Array = []     # [{coord, entry}] esperando cozinhar (fora do orçamento do frame)
var _bake_budget_ms := 40.0          # tempo maximo por frame cozinhando predios
var _spawn_ready := false            # os chunks do spawn ja montaram (tela de carregamento)


## Todos os biomas do gerador (os 4 padrão + os 5 extras do LowLand Forge).
const ALL_BIOMES: Array[String] = [
	"Meadow", "Pine Forest", "Birch Woods", "Old Growth",
	"Desert", "Palm Coast", "Frozen Highlands", "Ash Barrens", "Drowned Marsh",
]


func _ready() -> void:
	add_to_group("world")
	_player = get_node_or_null(player_path)
	_gen = LFTerrainGenerator.new()
	_gen.params = _make_params()
	_gen.setup(world_seed)
	# Vilas e estruturas: planejadas agora (achatam o terreno via stamps) para
	# valerem em todo get_height/props dos chunks gerados depois.
	_planner = VillagePlanner.new()
	_planner.plan(_gen, world_seed)
	_lib = LFPropMeshes.new()
	_lib.rock_color = _gen.params.rock_color
	_lib.build(world_seed)
	_terrain_shader = load("res://addons/lowland_forge/shaders/terrain_baked.gdshader")
	# Leva o jogador ao ponto de spawn do mundo ANTES de pedir os chunks: senão o
	# mundo pediria (e calcularia) os 5 chunks da origem (0,0), longe de tudo, e
	# ainda atrasaria os chunks do spawn.
	if _player:
		var sp := _gen.spawn_xz
		_player.global_position = Vector3(sp.x, _gen.get_height(sp.x, sp.y) + 2.0, sp.y)
		_player_h = _measure_height(_player.get_node_or_null("Model"))
	_spawn_ready = false
	_update_center(true)
	await get_tree().process_frame


## True quando os 5 chunks em volta do jogador estão montados (e as estruturas
## deles já foram montadas). É o que a tela de carregamento espera.
func is_ready() -> bool:
	if not _spawn_ready:
		for off in CHUNK_OFFSETS:
			if not _chunks.has(_center + off):
				return false
		if not _pending_structs.is_empty():
			return false
		_spawn_ready = true
	return _spawn_ready


## Progresso do carregamento (0..1) para a tela de carregamento.
func loading_progress() -> float:
	var want := 0
	var got := 0
	for off in CHUNK_OFFSETS:
		want += 1
		if _chunks.has(_center + off):
			got += 1
	var chunk_frac := float(got) / float(maxi(want, 1))
	# Os prédios pendentes são a parte final; descontam um pouco do progresso.
	if not _pending_structs.is_empty():
		chunk_frac *= 0.85
	return clampf(chunk_frac, 0.0, 1.0)


## Params do mundo: presets de relevo/água + TODOS os biomas ligados. O ruído de
## clima (que o setup faz a partir da seed) distribui os biomas aleatoriamente:
## cada região pega o bioma que combina mais com a temperatura/umidade dela, então
## o mesmo mapa nunca tem os biomas nos mesmos lugares.
func _make_params() -> LFMapParams:
	var p := LFMapPresets.make(preset)
	var have := {}
	for b in p.biomes:
		have[b.name] = true
	for b in LFBiomePresets.all():
		if not have.has(b.name):
			p.biomes.append(b)
	for b in p.biomes:
		b.enabled = b.name in ALL_BIOMES
	# BIOMAS GRANDES: baixo o `climate_freq` (o ruído de clima vira regiões amplas,
	# um bioma por região, não manchas pequenas). Transições suaves com biome_blend.
	p.climate_freq = 0.00055
	p.biome_blend = 3.5
	var d := density
	p.prop_density = d
	p.tree_density = d
	p.rock_density = d
	p.ground_cover_density = d
	return p


## Altura do chão (terreno, já com vilas achatadas) num ponto. Usada pelo
## resgate do void: se o jogador cair abaixo disso, é devolvido para cima.
func ground_height(x: float, z: float) -> float:
	return _gen.get_height(x, z)


func _physics_process(_delta: float) -> void:
	if _player:
		_update_center(false)
	_mount_pending()
	_flush_pending_structs()


func _update_center(force: bool) -> void:
	var p := _player.global_position
	var c := Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))
	if c == _center and not force:
		return
	_center = c
	_spawn_ready = false   # mudou de área: a tela de carregamento espera de novo
	var wanted := {}
	for off in CHUNK_OFFSETS:
		wanted[c + off] = true
		_request(c + off)
	# Libera os que saíram da cruz (o jogador pode voltar: serao gerados de novo).
	for coord: Vector2i in _chunks.keys():
		if not wanted.has(coord):
			var node: Node3D = _chunks[coord]
			_chunks.erase(coord)
			node.queue_free()


func _request(coord: Vector2i) -> void:
	if _chunks.has(coord) or _inflight.has(coord):
		return
	_inflight[coord] = true
	var g := _gen
	var lib := _lib
	var mutex := _mutex
	var results := _results
	WorkerThreadPool.add_task(func() -> void:
		var block := _compute_block(g, lib, coord)
		mutex.lock()
		results.append({"coord": coord, "block": block})
		mutex.unlock()
	)


## Combina os 4x4 sub-chunks de 32 m num bloco de 128 m (alturas, facets e props).
static func _compute_block(g: LFTerrainGenerator, lib: LFPropMeshes, coord: Vector2i) -> Dictionary:
	var n := BLOCK_CELLS + 1
	var hm := PackedFloat32Array()
	hm.resize(n * n)
	var facets := PackedByteArray()
	facets.resize(BLOCK_CELLS * 2 * BLOCK_CELLS * 3)
	var mms := {}
	var colliders: Array = []
	var log_colliders: Array = []
	var cliff_colliders: Array = []
	var V := LFTerrainGenerator.VERTS
	var cells := LFTerrainGenerator.CELLS
	var sub := LFTileBaker.BLOCK_CHUNKS
	for cj in sub:
		for ci in sub:
			var c := coord * sub + Vector2i(ci, cj)
			var td: Dictionary = LFChunkData.compute_terrain(g, c)
			var heights: PackedFloat32Array = td["heights"]
			var cols: PackedColorArray = td["colors"]
			for j in cells:
				for i in cells:
					for t in 2:
						var col := cols[((j * cells + i) * 2 + t) * 3]
						var px := (((cj * cells + j) * BLOCK_CELLS + ci * cells + i) * 2 + t) * 3
						facets[px] = col.r8
						facets[px + 1] = col.g8
						facets[px + 2] = col.b8
			for j in V:
				for i in V:
					hm[(cj * cells + j) * n + ci * cells + i] = heights[j * V + i]
			var pd: Dictionary = LFChunkData.compute_props(g, lib, c, heights, false, td["levels"])
			var off := Vector3(ci, 0, cj) * LFTerrainGenerator.CHUNK_SIZE
			for cc: Array in pd.get("colliders", []):
				colliders.append([cc[0], (cc[1] as Vector3) + off, cc[2], cc[3]])
			for lc: Array in pd.get("log_colliders", []):
				log_colliders.append([(lc[0] as Transform3D).translated(off), lc[1], lc[2]])
			for hull: PackedVector3Array in pd.get("cliff_colliders", []):
				var moved := PackedVector3Array()
				for q in hull:
					moved.append(q + off)
				cliff_colliders.append(moved)
			for mm: Dictionary in pd.get("mms", []):
				var key: Vector2i = mm["key"]
				var buf: PackedFloat32Array = mm["buf"]
				for k in range(0, buf.size(), 12):
					buf[k + 3] += off.x
					buf[k + 11] += off.z
				if not mms.has(key):
					mms[key] = PackedFloat32Array()
				mms[key].append_array(buf)
	return {"hm": hm, "facets": facets, "mms": mms,
			"colliders": colliders, "log_colliders": log_colliders, "cliff_colliders": cliff_colliders}


func _mount_pending() -> void:
	var made := 0
	while made < MAX_PER_FRAME:
		_mutex.lock()
		if _results.is_empty():
			_mutex.unlock()
			break
		var e: Dictionary = _results.pop_front()
		_mutex.unlock()
		_inflight.erase(e["coord"])
		# O jogador pode ter andado: só monta o que ainda está na cruz.
		if _wanted(e["coord"]):
			_mount_chunk(e["coord"], {"block": e["block"]})
		made += 1


func _wanted(coord: Vector2i) -> bool:
	for off in CHUNK_OFFSETS:
		if coord == _center + off:
			return true
	return false


func _mount_chunk(coord: Vector2i, data: Dictionary) -> void:
	if _chunks.has(coord):
		return
	var root := Node3D.new()
	root.position = Vector3(coord.x, 0, coord.y) * CHUNK
	root.name = "Chunk_%d_%d" % [coord.x, coord.y]

	var bd: Dictionary = data["block"]
	var hm: PackedFloat32Array = bd["hm"]
	var facets: PackedByteArray = bd["facets"]

	var mi := MeshInstance3D.new()
	mi.mesh = _build_mesh(hm)
	var mat := ShaderMaterial.new()
	mat.shader = _terrain_shader
	mat.set_shader_parameter("facets", ImageTexture.create_from_image(
			Image.create_from_data(BLOCK_CELLS * 2, BLOCK_CELLS, false, Image.FORMAT_RGB8, facets)))
	mat.set_shader_parameter("cell", LFTerrainGenerator.STEP)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

	# Colisão (HeightMapShape3D).
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.add_to_group(LFTileBaker.GROUP_TERRAIN, true)
	var hs := HeightMapShape3D.new()
	hs.map_width = BLOCK_CELLS + 1
	hs.map_depth = BLOCK_CELLS + 1
	var scaled := PackedFloat32Array()
	scaled.resize(hm.size())
	for k in hm.size():
		scaled[k] = hm[k] / LFTerrainGenerator.STEP
	hs.map_data = scaled
	var cs := CollisionShape3D.new()
	cs.shape = hs
	cs.scale = Vector3.ONE * LFTerrainGenerator.STEP
	cs.position = Vector3(CHUNK * 0.5, 0, CHUNK * 0.5)
	body.add_child(cs)
	root.add_child(body)

	# Props (arvores/rochas) via MultiMesh.
	var mms: Dictionary = bd["mms"]
	for key: Vector2i in mms:
		var meshes: Array = _lib.variants.get(key.x, [])
		if key.y >= meshes.size():
			continue
		var buf: PackedFloat32Array = mms[key]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = meshes[key.y]
		multi.instance_count = buf.size() / 12
		for i in range(multi.instance_count):
			var b := i * 12
			var t := Transform3D(
					Basis(Vector3(buf[b], buf[b + 4], buf[b + 8]),
							Vector3(buf[b + 1], buf[b + 5], buf[b + 9]),
							Vector3(buf[b + 2], buf[b + 6], buf[b + 10])),
					Vector3(buf[b + 3], buf[b + 7], buf[b + 11]))
			multi.set_instance_transform(i, t)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = multi
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.material_override = _prop_material(key.x)
		root.add_child(mmi)

	# Colisao dos props (troncos, pedras, troncos caidos) no formato do addon:
	# um ConcavePolygonShape3D por tipo, no espaco do chunk.
	for prop_body in _prop_bodies(bd.get("colliders", []), bd.get("log_colliders", []), bd.get("cliff_colliders", [])):
		root.add_child(prop_body)

	_place_structures(coord, root)

	add_child(root)
	_chunks[coord] = root


## Mesma geometria de colisao que o LowLand Forge gera no bake: prismas de 6 lados
## para troncos, esferas para pedras e as cascas (hulls) das pedras de encosta.
static func _prop_bodies(colliders: Array, log_colliders: Array, cliff_colliders: Array) -> Array[StaticBody3D]:
	var trees := PackedVector3Array()
	var rocks := PackedVector3Array()
	var logs := PackedVector3Array()
	for c: Array in colliders:
		var pos: Vector3 = c[1]
		if c[0]:
			_sphere_faces(rocks, pos, c[2])
		else:
			_prism_faces(trees, Transform3D(Basis(), pos + Vector3(0, c[3] * 0.5, 0)), c[2], c[3], false)
	for lc: Array in log_colliders:
		_prism_faces(logs, lc[0], lc[1], lc[2])
	for hull: PackedVector3Array in cliff_colliders:
		rocks.append_array(hull)
	var out: Array[StaticBody3D] = []
	for kind: Array in [["Tree", trees, LFTileBaker.GROUP_TREE], ["Rock", rocks, LFTileBaker.GROUP_ROCK], ["Log", logs, LFTileBaker.GROUP_LOG]]:
		var f: PackedVector3Array = kind[1]
		if f.is_empty():
			continue
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(f)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		var body := StaticBody3D.new()
		body.name = "%sBody" % kind[0]
		body.add_to_group(kind[2], true)
		body.add_child(cs)
		out.append(body)
	return out


const COLLIDE_SIDES := 6


static func _prism_faces(f: PackedVector3Array, xf: Transform3D, r: float, height: float, bottom := true) -> void:
	var h := height * 0.5
	var top := xf * Vector3(0, h, 0)
	var bot := xf * Vector3(0, -h, 0)
	for i in COLLIDE_SIDES:
		var a0 := TAU * i / COLLIDE_SIDES
		var a1 := TAU * (i + 1) / COLLIDE_SIDES
		var p0 := Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, 0, sin(a1) * r)
		var t0 := xf * (p0 + Vector3(0, h, 0))
		var t1 := xf * (p1 + Vector3(0, h, 0))
		var b0 := xf * (p0 - Vector3(0, h, 0))
		var b1 := xf * (p1 - Vector3(0, h, 0))
		f.append_array(PackedVector3Array([b0, t0, t1, b0, t1, b1, top, t1, t0]))
		if bottom:
			f.append_array(PackedVector3Array([bot, b0, b1]))


static func _sphere_faces(f: PackedVector3Array, c: Vector3, r: float) -> void:
	var rings := 4
	var segs := 6
	var pts: Array = []
	for j in range(rings + 1):
		var phi := PI * j / rings
		var row: Array = []
		for i in segs:
			var th := TAU * i / segs
			row.append(c + Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th)) * r)
		pts.append(row)
	for j in rings:
		for i in segs:
			var a: Vector3 = pts[j][i]
			var b: Vector3 = pts[j][(i + 1) % segs]
			var d: Vector3 = pts[j + 1][i]
			var e: Vector3 = pts[j + 1][(i + 1) % segs]
			f.append_array(PackedVector3Array([a, b, d, b, e, d]))


## Coloca as construcoes cujo centro cai neste chunk. Cada TIPO de construcao e
## cozido UMA vez em: uma malha unica (1 draw call, em vez de ~100 MeshInstance3D)
## e uma casca de colisao unica. Depois so instanciamos a versao pronta.
func _place_structures(coord: Vector2i, root: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	for entry in _structs_in(coord):
		var path: String = entry["scene"]
		var baked = _baked.get(path)
		if not (baked is Dictionary):
			# Cozinhar um predio custa ~100 ms; se passar do orçamento do frame,
			# adia para nao travar. O resto sai nos frames seguintes.
			if Time.get_ticks_msec() - t0 > _bake_budget_ms:
				_pending_structs.append({"coord": coord, "entry": entry})
				continue
			baked = _bake_structure(path, entry)
			if (baked as Dictionary).is_empty():
				continue
			_baked[path] = baked
		_instantiate_structure(baked, entry, root)


func _instantiate_structure(baked: Dictionary, entry: Dictionary, root: Node3D) -> void:
	var path: String = entry["scene"]
	var pos: Vector3 = entry["pos"]
	var yaw: float = entry["yaw"]
	var mi := MeshInstance3D.new()
	mi.mesh = baked["mesh"]
	mi.name = "Struct_%s" % path.get_file().get_basename()
	mi.position = pos - root.position
	mi.rotation.y = yaw
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var aabb: AABB = baked["aabb"]
	var body := StaticBody3D.new()
	body.name = "StructBody_%s" % path.get_file().get_basename()
	body.add_to_group(LFTileBaker.GROUP_TREE, true)
	var shape := BoxShape3D.new()
	shape.size = aabb.size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = aabb.position + aabb.size * 0.5
	body.add_child(cs)
	body.position = mi.position
	body.rotation.y = yaw
	root.add_child(body)


## Monta as estruturas adiadas, respeitando o orçamento de tempo por frame.
func _flush_pending_structs() -> void:
	if _pending_structs.is_empty():
		return
	var t0 := Time.get_ticks_msec()
	var still: Array = []
	for e: Dictionary in _pending_structs:
		var root: Node3D = _chunks.get(e["coord"])
		if root == null:
			continue   # chunk ja foi liberado
		var path: String = e["entry"]["scene"]
		var baked = _baked.get(path)
		if not (baked is Dictionary):
			if Time.get_ticks_msec() - t0 > _bake_budget_ms:
				still.append(e)
				continue
			baked = _bake_structure(path, e["entry"])
			if (baked as Dictionary).is_empty():
				continue
			_baked[path] = baked
		_instantiate_structure(baked, e["entry"], root)
	_pending_structs = still


## Cozinha uma construcao: junta todas as malhas numa so (draw calls) e todas as
## faces de colisao num ConcavePolygonShape3D (local, sem o deslocamento do chunk).
func _bake_structure(path: String, entry: Dictionary = {}) -> Dictionary:
	var scene: PackedScene = _struct_scenes.get(path)
	if scene == null:
		scene = load(path)
		if scene == null:
			return {}
		_struct_scenes[path] = scene
	var inst: Node3D = scene.instantiate()
	# Escala: se a entrada trouxer `scale` (modelos do KayKit, em escala de grade
	# hexagonal), usa direto. Senão, dimensiona pela porta do predio.
	var sc := float(entry.get("scale", 0.0))
	if sc <= 0.0:
		var door_h := _door_height(inst)
		sc = 1.0
		if door_h > 0.2:
			sc = (_player_h * door_factor + door_margin) / door_h
	var base := Transform3D(Basis().scaled(Vector3(sc, sc, sc)), Vector3.ZERO)
	var surfaces: Array = []   # [ [material, PackedVector3Array verts] ]
	var faces := PackedVector3Array()
	_collect(inst, base, surfaces, faces)
	inst.free()
	# Caixa de colisao: muito mais barata que um trimesh (que aqui passava de
	# 100 mil triangulos por predio). O predio nao tem interior, entao uma caixa
	# bloqueia igual.
	var aabb := AABB()
	var first := true
	for v in faces:
		if first:
			aabb = AABB(v, Vector3.ZERO)
			first = false
		else:
			aabb = aabb.expand(v)
	# IMPORTANTE: `SurfaceTool.commit()` faz UMA superfície com UM material. Como os
	# prédios usam vários materiais, juntamos os triângulos POR material e criamos
	# uma superfície para cada — senão o prédio inteiro pega o material errado
	# (ficava sem cor).
	var by_mat: Dictionary = {}
	for surf: Array in surfaces:
		var mat: Material = surf[0]
		var key := mat.get_instance_id() if mat else 0
		# PackedVector3Array/PackedColorArray são tipo por valor: pegar, mexer e devolver.
		var acc: PackedVector3Array = by_mat.get(key, {}).get("verts", PackedVector3Array())
		var accc: PackedColorArray = by_mat.get(key, {}).get("cols", PackedColorArray())
		acc.append_array(surf[1])
		accc.append_array(surf[2])
		by_mat[key] = {"mat": mat, "verts": acc, "cols": accc}
	var mesh := ArrayMesh.new()
	for key in by_mat:
		var grp: Dictionary = by_mat[key]
		var verts: PackedVector3Array = grp["verts"]
		var cols: PackedColorArray = grp["cols"]
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_COLOR] = cols
		var normals := PackedVector3Array()
		normals.resize(verts.size())
		for i in verts.size():
			normals[i] = Vector3.UP
		arrays[Mesh.ARRAY_NORMAL] = normals
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, grp["mat"])
	return {"mesh": mesh, "aabb": aabb}


## Altura da porta de um predio (a maior porta), em espaco local.
func _door_height(root: Node) -> float:
	var best := 0.0
	for n in _all_nodes(root):
		if n is Node3D and ("Door" in n.name) and not (n is MeshInstance3D):
			var a := _local_aabb(n, Transform3D())
			if a.size.y > best and a.size.y < 8.0:
				best = a.size.y
	return best


func _all_nodes(n: Node) -> Array:
	var o: Array = [n]
	for c in n.get_children():
		o.append_array(_all_nodes(c))
	return o


func _local_aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	var cur := xf
	if n is Node3D:
		cur = xf * (n as Node3D).transform
	if n is MeshInstance3D:
		var m: Mesh = (n as MeshInstance3D).mesh
		if m:
			var a: AABB = cur * m.get_aabb()
			out = a
			first = false
	for c in n.get_children():
		var ca := _local_aabb(c, cur)
		if ca.size == Vector3.ZERO and ca.position == Vector3.ZERO:
			continue
		if first:
			out = ca
			first = false
		else:
			out = out.merge(ca)
	return out


## Altura visual (Y) de um no (para medir o personagem).
func _measure_height(n: Node) -> float:
	if n == null:
		return 1.9
	var a := _local_aabb(n, Transform3D())
	return maxf(a.size.y, 0.5)


func _collect(n: Node, xf: Transform3D, surfaces: Array, faces: PackedVector3Array) -> void:
	var cur := xf
	if n is Node3D:
		cur = xf * (n as Node3D).transform
	if n is MeshInstance3D:
		var mesh: Mesh = (n as MeshInstance3D).mesh
		if mesh:
			for si in mesh.get_surface_count():
				var arrays: Array = mesh.surface_get_arrays(si)
				if arrays.size() <= Mesh.ARRAY_INDEX or arrays[Mesh.ARRAY_VERTEX] == null or arrays[Mesh.ARRAY_INDEX] == null:
					continue
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var mat: Material = mesh.surface_get_material(si)
				# As malhas do kit trazem a cor em COLOR_0 (o shader dele usava isso).
				# Sem copiar as cores, as partes que dependem só da cor saem brancas.
				var vcols: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays.size() > Mesh.ARRAY_COLOR and arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
				var out := PackedVector3Array()
				var ocol := PackedColorArray()
				for k in range(0, idx.size(), 3):
					var ia := idx[k]
					var ib := idx[k + 1]
					var ic := idx[k + 2]
					var a := cur * verts[ia]
					var b := cur * verts[ib]
					var c := cur * verts[ic]
					out.append(a)
					out.append(b)
					out.append(c)
					if vcols.is_empty():
						ocol.append(Color.WHITE)
						ocol.append(Color.WHITE)
						ocol.append(Color.WHITE)
					else:
						ocol.append(vcols[ia])
						ocol.append(vcols[ib])
						ocol.append(vcols[ic])
					faces.append(a)
					faces.append(b)
					faces.append(c)
				surfaces.append([mat, out, ocol])
	for c in n.get_children():
		_collect(c, cur, surfaces, faces)


## As construcoes cujo centro cai no chunk `coord`.
func _structs_in(coord: Vector2i) -> Array:
	var out: Array = []
	if _planner == null:
		return out
	for v: Dictionary in _planner.villages:
		for b: Dictionary in v["buildings"]:
			if _chunk_of(b["pos"]) == coord:
				out.append(b)
	for sc: Dictionary in _planner.scattered:
		if _chunk_of(sc["pos"]) == coord:
			out.append(sc)
	for ca: Dictionary in _planner.castles:
		if _chunk_of(ca["pos"]) == coord:
			out.append(ca)
	return out


func _chunk_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))


func _prop_material(kind: int) -> Material:
	# Materiais simples (a cor do tronco/folha fica na malha; aqui só um fallback).
	if _lib.trunk_materials.has(kind):
		return _lib.trunk_materials[kind]
	if _lib.canopy_materials.has(kind):
		return _lib.canopy_materials[kind]
	if _lib.plant_material:
		return _lib.plant_material
	return null


func _build_mesh(hm: PackedFloat32Array) -> ArrayMesh:
	var n := BLOCK_CELLS + 1
	var s := LFTerrainGenerator.STEP
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	verts.resize(n * n)
	normals.resize(n * n)
	for j in n:
		for i in n:
			var h := hm[j * n + i]
			verts[j * n + i] = Vector3(i * s, h, j * s)
			var dx := hm[j * n + mini(i + 1, n - 1)] - hm[j * n + maxi(i - 1, 0)]
			var dz := hm[mini(j + 1, n - 1) * n + i] - hm[maxi(j - 1, 0) * n + i]
			normals[j * n + i] = Vector3(-dx, 2.0 * s, -dz).normalized()
	var idx := PackedInt32Array()
	for j in range(BLOCK_CELLS):
		for i in range(BLOCK_CELLS):
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d := c + 1
			idx.append_array(PackedInt32Array([a, b, c, b, d, c]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
