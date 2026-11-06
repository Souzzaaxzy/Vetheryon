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
## 5x5 chunks em volta do jogador (25). Em vez de manter 25 blocos sempre
## visíveis (eram 874 draw calls e o FPS caía para ~8), cada chunk recebe uma
## distância de visibilidade: o mundo continua sólido de perto, mas o que está
## longe deixa de ser desenhado. É isso que destrava o celular.
const CHUNK_OFFSETS: Array[Vector2i] = [
	Vector2i(-2, -2), Vector2i(-1, -2), Vector2i(0, -2), Vector2i(1, -2), Vector2i(2, -2),
	Vector2i(-2, -1), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(2, -1),
	Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
	Vector2i(-2, 1), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
	Vector2i(-2, 2), Vector2i(-1, 2), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2),
]
const MAX_PER_FRAME := 1                  # montagens por frame (limita o travamento)
## O terreno aparece até esta distância; além disso o chunk existe (colisão) mas
## não é desenhado.
const TERRAIN_VIEW := 240.0
## A vegetação (MultiMesh, o que mais pesa) some bem antes.
const PROPS_VIEW := 130.0

@export var world_seed: int = 20261104
@export var preset: String = "Rolling Plains"
## Densidade da vegetação. Menos props = menos geometria para gerar e desenhar
## (as árvores agora são gigantes, então cada uma pesa muito mais que antes).
@export var density: float = 0.32
@export var player_path: NodePath
## Dimensiona os predios pela porta: a porta fica `door_factor` x a altura do
## personagem (bem maior que ele) e o predio inteiro e escalado junto, para nao
## parecer casinha de boneca.
@export var door_factor: float = 1.45
@export var door_margin: float = 0.15

var _gen: LFTerrainGenerator
var _lib: LFPropMeshes
var _terrain_shader: Shader
var _noise_tex: ImageTexture
var _player: Node3D

var _chunks: Dictionary = {}       # Vector2i -> Node3D (montado)
var _inflight: Dictionary = {}     # Vector2i -> true (gerando agora numa thread)
var _center := Vector2i(999999, 999999)
## Cache dos blocos JÁ GERADOS (como o cache de chunks do Minecraft). Sem ele, o
## jogador andando para a frente e para trás sobre a borda regenerava o mesmo
## chunk (127 ms cada). Com ele, voltar é instantâneo.
var _cache: Dictionary = {}        # Vector2i -> block data
## Fila de geração, sempre da mais perto para a mais longe do jogador.
var _queue: Array[Vector2i] = []
## Quantas gerações rodam ao mesmo tempo. O Minecraft usa poucos workers; disparar
## as 25 de uma vez entope a pool e as do lado do jogador chegam por último.
var _max_tasks := 3

# As threads escrevem aqui; o Mutex protege a fila. Montamos no thread principal.
var _mutex := Mutex.new()
var _results: Array = []           # [ {coord, block} ] prontos para montar

var _planner: VillagePlanner
var _structures: StructureManager
var _player_h := 1.9                 # altura do personagem (medida no _ready)
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
	_terrain_shader = load("res://src/world/terrain.gdshader")
	_noise_tex = _make_noise_texture()
	# Leva o jogador ao ponto de spawn do mundo ANTES de pedir os chunks: senão o
	# mundo pediria (e calcularia) os 5 chunks da origem (0,0), longe de tudo, e
	# ainda atrasaria os chunks do spawn.
	if _player:
		var sp := _gen.spawn_xz
		_player.global_position = Vector3(sp.x, _gen.get_height(sp.x, sp.y) + 2.0, sp.y)
		_player_h = _measure_height(_player.get_node_or_null("Model"))
	# As construções têm streaming próprio (independente dos chunks): nascem por
	# distância ao jogador, então uma vila inteira aparece mesmo cruzando chunks.
	_structures = StructureManager.new()
	_structures.name = "Structures"
	add_child(_structures)
	_structures.setup(_planner, _player, _player_h, door_factor, door_margin)
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
	return clampf(float(got) / float(maxi(want, 1)), 0.0, 1.0)


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
	# A vegetação rasteira (grama, flores, arbustos) é a que mais gera geometria e
	# não tem colisão: com as árvores gigantes, dá para ser bem mais rala sem o
	# mundo parecer vazio.
	p.ground_cover_density = d * 0.45
	return p


## Altura do chão (terreno, já com vilas achatadas) num ponto. Usada pelo
## resgate do void: se o jogador cair abaixo disso, é devolvido para cima.
func ground_height(x: float, z: float) -> float:
	return _gen.get_height(x, z)


## Descarrega TUDO (chunks montados, fila e caches de memória) para trocar de mundo.
## Os caches de DISCO ficam: são por seed, então cada mundo reaproveita os seus.
func unload_all() -> void:
	for coord: Vector2i in _chunks.keys():
		var node: Node3D = _chunks[coord]
		if is_instance_valid(node):
			node.queue_free()
	_chunks.clear()
	_inflight.clear()
	_queue.clear()
	_cache.clear()
	_mutex.lock()
	_results.clear()
	_mutex.unlock()
	if _structures and _structures.has_method("unload_all"):
		_structures.unload_all()


func _physics_process(_delta: float) -> void:
	if _player:
		_update_center(false)
	_dispatch()
	_mount_pending()


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
	# Libera os que saíram da área (o BLOCO fica no cache; a malha é descartada).
	for coord: Vector2i in _chunks.keys():
		if not wanted.has(coord):
			var node: Node3D = _chunks[coord]
			_chunks.erase(coord)
			node.queue_free()
	# Reenfileira o que falta, do mais perto para o mais longe (prioridade).
	var pend: Array = []
	for coord: Vector2i in wanted:
		if _chunks.has(coord) or _inflight.has(coord):
			continue
		if _cache.has(coord):
			continue   # já gerado: _fill_from_cache monta sem thread
		pend.append(coord)
	pend.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _dist2(a, c) < _dist2(b, c))
	# A fila passa a ser só a da nova área (o que saiu não interessa mais).
	_queue.clear()
	for coord: Vector2i in pend:
		_enqueue(coord)


func _dist2(coord: Vector2i, c: Vector2i) -> int:
	var d := coord - c
	return d.x * d.x + d.y * d.y


func _enqueue(coord: Vector2i) -> void:
	if _inflight.has(coord) or _chunks.has(coord):
		return
	if not _queue.has(coord):
		_queue.append(coord)


## Mantém no máximo `_max_tasks` gerações rodando, tirando sempre a mais próxima.
func _dispatch() -> void:
	while _inflight.size() < _max_tasks and not _queue.is_empty():
		var coord: Vector2i = _queue.pop_front()
		if _inflight.has(coord) or _chunks.has(coord):
			continue
		if _cache.has(coord):
			continue
		_start_task(coord)


func _start_task(coord: Vector2i) -> void:
	# Primeiro o cache de DISCO (chunk já gerado antes, em qualquer sessão): é o
	# que evita a geração de 120 ms na maior parte do tempo.
	var disk := _load_chunk_cache(coord)
	if not disk.is_empty():
		_cache[coord] = disk
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
		var coord: Vector2i = e["coord"]
		_inflight.erase(coord)
		# Guarda no cache (memória + disco: o chunk gerado é reaproveitado depois).
		if not _cache.has(coord):
			_cache[coord] = e["block"]
			_save_chunk_cache(coord, e["block"])
		# Só monta o que ainda está na área.
		if _wanted(coord):
			_mount_chunk(coord, {"block": e["block"]})
		made += 1
	# Monta direto do cache o que entrou na área e já foi gerado antes.
	_fill_from_cache()
	_trim_cache()


## Monta, sem thread, os chunks da área que já estão no cache (volta a um lugar).
func _fill_from_cache() -> void:
	var made := 0
	for off in CHUNK_OFFSETS:
		if made >= MAX_PER_FRAME:
			break
		var coord: Vector2i = _center + off
		if _chunks.has(coord) or _inflight.has(coord):
			continue
		if not _cache.has(coord):
			continue
		_mount_chunk(coord, {"block": _cache[coord]})
		made += 1


## Descarta do cache o que ficou muito longe (o Minecraft também limita a memória).
func _trim_cache() -> void:
	if _cache.size() < 80:
		return
	var keep := 70
	var keys: Array = _cache.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _dist2(a, _center) > _dist2(b, _center))
	for i in range(keys.size() - keep):
		_cache.erase(keys[i])


# --- cache em disco dos chunks -------------------------------------------------
#
# Igual ao Minecraft, que salva o chunk já gerado: como o mundo é procedural com
# seed fixa, o mesmo chunk dá sempre o mesmo resultado. Então gerar (a parte
# caríssima, ~120 ms) só acontece UMA vez por chunk, por mundo; depois é leitura
# de arquivo. O cache é por seed, para não misturar mundos.

const CHUNK_CACHE_DIR := "user://chunk_cache"
## Suba ao mudar QUALQUER coisa na geração (densidade, escala, colisão), senão o
## jogo reaproveita os chunks gerados com os parâmetros antigos.
const CHUNK_CACHE_VERSION := 2


func _chunk_cache_path(coord: Vector2i) -> String:
	return "%s/%d_%d_%d_%d.var" % [CHUNK_CACHE_DIR, CHUNK_CACHE_VERSION, world_seed, coord.x, coord.y]


## Grava o bloco em disco. Guarda só o essencial (alturas, facets e props); as
## colisões são reconstruídas na montagem (são baratas: ~5 ms).
func _save_chunk_cache(coord: Vector2i, block: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CHUNK_CACHE_DIR))
	var f := FileAccess.open(_chunk_cache_path(coord), FileAccess.WRITE)
	if f == null:
		return
	f.store_var({
		"hm": block["hm"],
		"facets": block["facets"],
		"mms": block["mms"],
		"colliders": block["colliders"],
		"log_colliders": block["log_colliders"],
		"cliff_colliders": block["cliff_colliders"],
	})
	f.close()


func _load_chunk_cache(coord: Vector2i) -> Dictionary:
	var path := _chunk_cache_path(coord)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = f.get_var()
	f.close()
	if d is Dictionary and (d as Dictionary).has("hm"):
		return d
	return {}


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
	mat.set_shader_parameter("noise_tex", _noise_tex)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = TERRAIN_VIEW
	mi.visibility_range_end_margin = 40.0
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
	#
	# Cada (tipo, variante) do gerador virava um MultiMeshInstance3D próprio: num
	# bloco de 128 m isso dava ~42 nós por chunk (~1000 no mundo todo) e cada nó é
	# uma draw call — era isso que travava. Agora:
	#   * o que NÃO balança com o vento (grama, flores, rochas, troncos, cristais,
	#     falésias...) é fundido numa malha por material — 1 draw call por material;
	#   * as árvores continuam em MultiMesh (o shader do vento precisa da matriz por
	#     instância para dobrar cada árvore em torno da própria base).
	# Com o LOD por distância, as draw calls caem de ~42 para ~8 por chunk.
	var mms: Dictionary = bd["mms"]
	var static_by_mat: Dictionary = {}   # material RID -> {mat, st: SurfaceTool}
	var by_mesh: Dictionary = {}         # mesh RID -> {mesh, mat, xforms: PackedFloat32Array}
	for key: Vector2i in mms:
		var meshes: Array = _lib.variants.get(key.x, [])
		if key.y >= meshes.size():
			continue
		var m: Mesh = meshes[key.y]
		var buf: PackedFloat32Array = mms[key]
		if _lib.canopy_materials.has(key.x) or _lib.trunk_materials.has(key.x):
			var id := m.get_rid()
			if not by_mesh.has(id):
				by_mesh[id] = {"mesh": m, "mat": _prop_material(key.x), "xforms": PackedFloat32Array()}
			var arr: PackedFloat32Array = by_mesh[id]["xforms"]
			var ks := _kind_scale(key.x)
			for i in range(buf.size() / 12):
				arr.append_array(_scaled_xform(buf, i, ks))
			by_mesh[id]["xforms"] = arr
			continue
		var surf_mat: Material = m.surface_get_material(0) if m.get_surface_count() > 0 else null
		var mid: int = surf_mat.get_rid().get_id() if surf_mat else 0
		if not static_by_mat.has(mid):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			static_by_mat[mid] = {"mat": surf_mat, "st": st}
		var st2: SurfaceTool = static_by_mat[mid]["st"]
		var ks2 := _kind_scale(key.x)
		for i in range(buf.size() / 12):
			var xf := _scaled_xform_t(buf, i, ks2)
			st2.append_from(m, 0, xf)
			# Pedras grandes viram montanha: empilha pedras menores em volta.
			if key.x == LFPropMeshes.Kind.ROCK:
				for extra: Transform3D in _rock_pile(int(xf.origin.x * 31.0 + xf.origin.z * 17.0), xf):
					st2.append_from(m, 0, extra)

	for mid in static_by_mat:
		var grp0: Dictionary = static_by_mat[mid]
		var gm := MeshInstance3D.new()
		gm.mesh = (grp0["st"] as SurfaceTool).commit()
		gm.material_override = grp0["mat"]
		gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gm.visibility_range_end = PROPS_VIEW
		gm.visibility_range_end_margin = 25.0
		root.add_child(gm)

	for id in by_mesh:
		var grp: Dictionary = by_mesh[id]
		var buf2: PackedFloat32Array = grp["xforms"]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = grp["mesh"]
		multi.instance_count = buf2.size() / 12
		for i in range(multi.instance_count):
			multi.set_instance_transform(i, _xform_at(buf2, i))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = multi
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mmi.material_override = grp["mat"]
		# LOD: a vegetação some suave antes do fim do terreno (é o que mais pesa).
		mmi.visibility_range_end = PROPS_VIEW
		mmi.visibility_range_end_margin = 25.0
		root.add_child(mmi)

	# Colisao dos props (troncos, pedras, troncos caidos) no formato do addon:
	# um ConcavePolygonShape3D por tipo, no espaco do chunk.
	for prop_body in _prop_bodies(bd.get("colliders", []), bd.get("log_colliders", []), bd.get("cliff_colliders", [])):
		root.add_child(prop_body)

	add_child(root)
	_chunks[coord] = root


## A colisão da árvore é um cilindro no TRONCO. O raio vem do próprio gerador
## (`collide_radius` do tipo × escala do exemplar), que corresponde ao tronco real,
## mas com um TETO: nas variantes de copa larga esse valor dobra e, com as árvores
## gigantes, virava um muro que prendia o jogador.
const TRUNK_MAX_RADIUS := 2.4
## Altura do tronco sólido (m). Acima disso é copa — atravessável, como no Minecraft.
const TRUNK_COLLIDE_HEIGHT := 8.0


## Mesma geometria de colisao que o LowLand Forge gera no bake: prismas de 6 lados
## para troncos, esferas para pedras e as cascas (hulls) das pedras de encosta.
static func _prop_bodies(colliders: Array, log_colliders: Array, cliff_colliders: Array) -> Array[StaticBody3D]:
	var trees := PackedVector3Array()
	var rocks := PackedVector3Array()
	var logs := PackedVector3Array()
	for c: Array in colliders:
		var pos: Vector3 = c[1]
		if c[0]:
			# Pedra: esfera do tamanho real (o addon guarda o raio no mesmo campo).
			_sphere_faces(rocks, pos, c[2] * _collide_scale(LFPropMeshes.Kind.ROCK))
		else:
			# Árvore: cilindro no tronco, com o raio do próprio gerador (× a escala
			# do exemplar) limitado por TRUNK_MAX_RADIUS. A copa fica atravessável.
			var ts := _collide_scale(LFPropMeshes.Kind.PINE)
			var r: float = minf(c[2] * ts, TRUNK_MAX_RADIUS)
			var h := TRUNK_COLLIDE_HEIGHT
			_prism_faces(trees, Transform3D(Basis(), pos + Vector3(0, h * 0.5, 0)), r, h, false)
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




## Fator de escala aplicado a cada tipo de prop do gerador. O LowLand Forge planta
## tudo em escala de "boneco"; aqui aumentamos para um mundo com árvores GIGANTES e
## pedras grandes, como o usuário pediu.
static func _kind_scale(kind: int) -> float:
	var K := LFPropMeshes.Kind
	if kind == K.PINE or kind == K.BIRCH or kind == K.BROAD \
			or kind == K.SNOW_PINE or kind == K.WILLOW or kind == K.DEAD:
		return 7.5          # árvores de floresta: gigantes (~9-10 m)
	if kind == K.PALM:
		return 5.0
	if kind == K.CACTUS:
		return 3.5
	if kind == K.ROCK:
		return 4.0          # pedras grandes
	if kind == K.CRYSTAL:
		return 3.2
	return 1.0


## Fator de escala da COLISÃO do prop, por categoria. Tem que acompanhar o visual,
## senão o jogador atravessa a árvore (a colisão fica no tamanho antigo).
static func _collide_scale(kind: int) -> float:
	var K := LFPropMeshes.Kind
	if kind == K.ROCK:
		return 4.0
	if kind == K.CLIFF:
		return 1.0
	return _kind_scale(kind)


## Montanha de pedras: em volta de uma rocha grande, empilha pedras menores. Devolve
## uma lista de transforms extras (já no espaço do chunk).
static func _rock_pile(seed_val: int, base: Transform3D) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var out: Array = []
	if rng.randf() > 0.16:
		return out   # só algumas rochas viram montanha
	var n := rng.randi_range(3, 7)
	for i in n:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(0.2, 0.9) * base.basis.get_scale().x * 1.4
		var up := rng.randf_range(0.05, 0.55) * base.basis.get_scale().x
		var s := rng.randf_range(0.35, 0.85)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(base.basis.get_scale() * s)
		out.append(Transform3D(b, base.origin + Vector3(cos(ang) * dist, up, sin(ang) * dist)))
	return out


## Transform de uma instância no buffer achatado (12 floats: 9 da base + 3 da posição),
## com o fator de escala do tipo aplicado.
static func _scaled_xform_t(buf: PackedFloat32Array, i: int, k: float) -> Transform3D:
	var t := _xform_at(buf, i)
	t.basis = t.basis.scaled(Vector3(k, k, k))
	return t


## O mesmo, no formato achatado (para o MultiMesh).
static func _scaled_xform(buf: PackedFloat32Array, i: int, k: float) -> PackedFloat32Array:
	var t := _scaled_xform_t(buf, i, k)
	var b := t.basis
	var o := t.origin
	return PackedFloat32Array([
		b.x.x, b.y.x, b.z.x, o.x,
		b.x.y, b.y.y, b.z.y, o.y,
		b.x.z, b.y.z, b.z.z, o.z,
	])


## Transform de uma instância no buffer achatado (12 floats: 9 da base + 3 da posição).
static func _xform_at(buf: PackedFloat32Array, i: int) -> Transform3D:
	var b := i * 12
	return Transform3D(
			Basis(Vector3(buf[b], buf[b + 4], buf[b + 8]),
					Vector3(buf[b + 1], buf[b + 5], buf[b + 9]),
					Vector3(buf[b + 2], buf[b + 6], buf[b + 10])),
			Vector3(buf[b + 3], buf[b + 7], buf[b + 11]))


func _prop_material(kind: int) -> Material:
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


## Ruído suave para quebrar a cor chapada do terreno. Uma textura só, reusada
## por todos os chunks.
func _make_noise_texture() -> ImageTexture:
	var n := 256
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.045
	noise.fractal_octaves = 4
	var img := Image.create(n, n, false, Image.FORMAT_L8)
	for y in n:
		for x in n:
			var v := (noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	return ImageTexture.create_from_image(img)

