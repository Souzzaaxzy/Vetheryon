class_name StructureManager
extends Node3D

## Monta e desmonta as construções em volta do jogador, com streaming próprio.
##
## Antes, cada construção era montada no chunk em que caía o CENTRO dela (e o
## mundo só mantém 5 chunks em cruz) — então uma vila, que ocupa vários chunks,
## tinha peças que nunca nasciam. Aqui a estrutura é montada pela DISTÂNCIA ao
## jogador, independente de chunk, com histerese para não ligar/desligar no vaivém.
##
## O "cozimento" (fundir as malhas do glTF numa só, preservando UV/normal/tangente,
## e gerar a casca de colisão exata) roda numa thread e é guardado por TIPO — pago
## uma vez por tipo, em memória e em disco.

const CACHE_DIR := "user://struct_cache"
## Versão do formato do cache. Suba SEMPRE que o cozimento mudar (senão o jogo
## reaproveita malhas antigas do disco, sem as mudanças).
const CACHE_VERSION := 4
## Célula do índice espacial (m). Grande o bastante para poucas células por busca.
const CELL := 64.0

## Raio em que as construções ficam montadas, e a margem para desmontar (histerese).
## Com 3x3 chunks (128 m cada) o terreno garante ≥128 m em TODA direção a partir do
## jogador, então 120 m nunca deixa estrutura pendurada sobre o vazio.
@export var view_radius: float = 120.0
@export var release_radius: float = 155.0
## Quantas construções montar/desmontar por frame (suaviza picos).
@export var mounts_per_frame: int = 4

var _entries: Array = []              # {path, pos, yaw, scale}
var _cells: Dictionary = {}           # Vector2i -> PackedInt32Array (índices)
var _active: Dictionary = {}          # índice -> Node3D montado
var _baked: Dictionary = {}           # path -> BakedStructure (memória)
var _baking: Dictionary = {}          # path -> true (cozinhando numa thread)
var _failed: Dictionary = {}          # path -> true (não carrega/coze: não repetir)
var _bake_results: Array = []         # [{path, baked}]
var _mutex := Mutex.new()

var _player_h := 1.9
var _door_factor := 1.45
var _door_margin := 0.15
var _player: Node3D
var _ready := false


func setup(planner: VillagePlanner, player: Node3D, player_h: float,
		door_factor: float, door_margin: float) -> void:
	_player = player
	_player_h = player_h
	_door_factor = door_factor
	_door_margin = door_margin
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR))
	_collect(planner)
	_index()
	_ready = true


## Junta todas as construções (prédios de vila, castelos e as soltas) numa lista só.
func _collect(planner: VillagePlanner) -> void:
	_entries.clear()
	for v: Dictionary in planner.villages:
		for b: Dictionary in v["buildings"]:
			_entries.append(b)
	for sc: Dictionary in planner.scattered:
		_entries.append(sc)


func _index() -> void:
	for i in _entries.size():
		var e: Dictionary = _entries[i]
		var p: Vector3 = e["pos"]
		var k := _cell_of(p)
		if not _cells.has(k):
			_cells[k] = PackedInt32Array()
		var arr: PackedInt32Array = _cells[k]
		arr.append(i)
		_cells[k] = arr


func _cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))


func total_structures() -> int:
	return _entries.size()


## Quantas estão montadas agora (para o HUD/diagnóstico).
func active_count() -> int:
	return _active.size()


## Desmonta tudo e esquece os cozimentos em memória (troca de mundo).
func unload_all() -> void:
	for i in _active:
		var node: Node3D = _active[i]
		if is_instance_valid(node):
			node.queue_free()
	_active.clear()
	_baking.clear()
	_bake_results.clear()
	# Os cozimentos de disco ficam: são os mesmos por tipo, servem para todo mundo.


func _process(_delta: float) -> void:
	if not _ready or _player == null:
		return
	_pump_bakes()
	_stream()


func _stream() -> void:
	var pp: Vector3 = _player.global_position
	var vr2 := view_radius * view_radius
	var rr2 := release_radius * release_radius
	var want := {}

	# Células dentro do raio de visão (folga de uma célula para não perder peças).
	var r := int(ceil(view_radius / CELL)) + 1
	var c0 := _cell_of(pp)
	for cz in range(c0.y - r, c0.y + r + 1):
		for cx in range(c0.x - r, c0.x + r + 1):
			var list: Variant = _cells.get(Vector2i(cx, cz))
			if list == null:
				continue
			for i: int in (list as PackedInt32Array):
				var p: Vector3 = _entries[i]["pos"]
				if p.distance_squared_to(pp) <= vr2:
					want[i] = true

	# Monta os que faltam, até o limite por frame.
	var made := 0
	for i in want:
		if made >= mounts_per_frame:
			break
		if not _active.has(i):
			_mount(i)
			made += 1

	# Desmonta o que ficou longe (só fora do raio maior: histerese).
	var gone: Array = []
	for i in _active:
		var p: Vector3 = _entries[i]["pos"]
		if p.distance_squared_to(pp) > rr2:
			gone.append(i)
	for i in gone:
		_unmount(i)


func _mount(i: int) -> void:
	var e: Dictionary = _entries[i]
	var path: String = e["scene"]
	var baked: BakedStructure = _baked.get(path)
	if baked == null:
		# Ainda não cozido: começa o cozimento e monta quando ficar pronto.
		if not _baking.has(path):
			_request_bake(path)
		return
	var node := _instance(baked, e)
	add_child(node)
	_active[i] = node


func _unmount(i: int) -> void:
	var node: Node3D = _active.get(i)
	if node:
		node.queue_free()
	_active.erase(i)


func _instance(baked: BakedStructure, e: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.position = e["pos"]
	root.rotation.y = e["yaw"]
	var s := float(e.get("scale", 0.0))
	if s <= 0.0:
		s = baked.default_scale
	root.scale = Vector3(s, s, s)
	var mi := MeshInstance3D.new()
	mi.mesh = baked.mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# Surge/some suave (evita o "pop" da estrutura ao entrar no raio de visão).
	mi.visibility_range_end = release_radius
	mi.visibility_range_end_margin = 24.0
	root.add_child(mi)
	if baked.shape != null:
		var body := StaticBody3D.new()
		body.add_to_group("structure", true)
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		cs.shape = baked.shape
		body.add_child(cs)
		root.add_child(body)
	# Interior: a sala aparece por dentro e tem colisão própria (piso + paredes).
	# A casca externa é "furada" na frente pelo `shape` já recortado, então o
	# jogador consegue atravessar o vão da porta e entrar.
	if baked.interior_mesh != null:
		var imi := MeshInstance3D.new()
		imi.mesh = baked.interior_mesh
		imi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		imi.visibility_range_end = release_radius
		imi.visibility_range_end_margin = 24.0
		imi.position = baked.interior_offset
		root.add_child(imi)
		if baked.interior_shape != null:
			var ib := StaticBody3D.new()
			ib.add_to_group("structure", true)
			ib.collision_layer = 1
			ib.collision_mask = 0
			var ics := CollisionShape3D.new()
			ics.shape = baked.interior_shape
			ics.position = baked.interior_offset
			ib.add_child(ics)
			root.add_child(ib)
	return root


# --- cozimento ---------------------------------------------------------------

func _request_bake(path: String) -> void:
	if _failed.has(path):
		return
	_baking[path] = true
	var cached := _load_cache(path)
	if cached != null:
		_baked[path] = cached
		_baking.erase(path)
		return
	# Carregar a cena é feito na thread principal (o carregador de recursos não é
	# seguro fora dela); só a fusão das malhas vai para a thread.
	var scene: PackedScene = load(path)
	if scene == null:
		push_warning("StructureManager: não consegui carregar %s" % path)
		_failed[path] = true
		_baking.erase(path)
		return
	var mutex := _mutex
	var results := _bake_results
	var ph := _player_h
	var df := _door_factor
	var dm := _door_margin
	WorkerThreadPool.add_task(func() -> void:
		var baked := _bake(scene, path, ph, df, dm)
		mutex.lock()
		results.append({"path": path, "baked": baked})
		mutex.unlock()
	)


func _pump_bakes() -> void:
	if _bake_results.is_empty():
		return
	_mutex.lock()
	var done := _bake_results.duplicate()
	_bake_results.clear()
	_mutex.unlock()
	for r: Dictionary in done:
		var path: String = r["path"]
		_baking.erase(path)
		if r["baked"] != null:
			_baked[path] = r["baked"]
			_save_cache(path, r["baked"])
		else:
			_failed[path] = true


## Funde o glTF numa malha só (por material), preservando UV/normal/tangente, e
## gera a casca de colisão exata. Roda fora do thread principal.
## A malha sai em unidades nativas (escala 1); a escala final é aplicada na
## instância, então um único bake serve para qualquer escala do mesmo tipo.
static func _bake(scene: PackedScene, path: String, player_h: float,
		door_factor: float, door_margin: float) -> BakedStructure:
	var inst: Node3D = scene.instantiate()
	var default_scale := _door_scale(inst, player_h, door_factor, door_margin)

	# Uma SurfaceTool por material (o commit faz 1 superfície por material).
	var groups: Dictionary = {}
	_collect_groups(inst, Transform3D(), groups)
	inst.free()

	var mesh := ArrayMesh.new()
	for key in groups:
		var g: Dictionary = groups[key]
		var st: SurfaceTool = g["st"]
		# As normais originais do asset são mantidas (algumas partes são suaves);
		# só as tangentes precisam ser geradas (exigem UV + normal, que já existem).
		st.generate_tangents()
		var sub: ArrayMesh = st.commit()
		if sub == null:
			continue
		for si in sub.get_surface_count():
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
					sub.surface_get_arrays(si))
			mesh.surface_set_material(mesh.get_surface_count() - 1, g["mat"])
	if mesh.get_surface_count() == 0:
		return null

	var baked := BakedStructure.new()
	baked.mesh = mesh
	baked.default_scale = default_scale
	# Interior (sala com móveis) — só para prédios habitáveis.
	var interior := build_interior(baked, path, path.hash())
	if not interior.is_empty():
		baked.interior_mesh = interior["mesh"]
		baked.interior_shape = interior["shape"]
		baked.interior_offset = interior["offset"]
		# Abre o vão da porta na casca EXTERNA: sem isso o prédio continua um bloco
		# fechado e o jogador não entra (só vê a parede de fora).
		baked.mesh = _carve_door(mesh, baked.interior_offset, interior["size"])
	baked.shape = baked.mesh.create_trimesh_shape()
	baked.faces = 0
	if baked.shape != null:
		baked.faces = baked.shape.get_faces().size() / 3
	return baked


## Remove os triângulos da casca que caem na frente do vão da porta, deixando uma
## abertura de verdade (na malha E, por consequência, na colisão).
static func _carve_door(mesh: ArrayMesh, offset: Vector3, room_size: Vector3) -> ArrayMesh:
	var out := ArrayMesh.new()
	# Frações do tamanho da sala (a malha está em unidades nativas do modelo).
	var door_w := room_size.x * 0.30
	var door_h := room_size.y * 0.62
	var front := offset.z + room_size.z * 0.5   # face +Z do prédio
	for si in mesh.get_surface_count():
		var arr: Array = mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx = arr[Mesh.ARRAY_INDEX]
		var kept := PackedVector3Array()
		if idx == null:
			# Sem índices: trata como triângulos soltos.
			for k in range(0, verts.size(), 3):
				if not _in_door(verts[k], verts[k + 1], verts[k + 2], front, door_w, door_h, offset):
					kept.append_array(PackedVector3Array([verts[k], verts[k + 1], verts[k + 2]]))
		else:
			var ids: PackedInt32Array = idx
			for k in range(0, ids.size(), 3):
				var a := verts[ids[k]]
				var b := verts[ids[k + 1]]
				var c := verts[ids[k + 2]]
				if not _in_door(a, b, c, front, door_w, door_h, offset):
					kept.append_array(PackedVector3Array([a, b, c]))
		if kept.is_empty():
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for v: Vector3 in kept:
			st.add_vertex(v)
		var sub: ArrayMesh = st.commit()
		if sub != null:
			for s2 in sub.get_surface_count():
				out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sub.surface_get_arrays(s2))
				out.surface_set_material(out.get_surface_count() - 1, mesh.surface_get_material(si))
	return out


## True se o triângulo está na área do vão (frente, dentro da largura/altura da porta).
static func _in_door(a: Vector3, b: Vector3, c: Vector3, front: float,
		door_w: float, door_h: float, offset: Vector3) -> bool:
	var mid := (a + b + c) / 3.0
	# Só a face frontal (perto do plano da frente).
	if absf(mid.z - front) > 0.35:
		return false
	if mid.y > offset.y + door_h:
		return false
	if absf(mid.x - offset.x) > door_w * 0.5:
		return false
	return true


## Constrói o interior de um prédio: uma sala com piso, paredes, teto e móveis,
## encaixada no volume do prédio, e a colisão RECORTADA para o vão da porta (senão
## o jogador não conseguiria entrar). Devolve {mesh, shape, floor_y}.
static func build_interior(baked: BakedStructure, path: String, seed_val: int) -> Dictionary:
	if baked == null or baked.mesh == null:
		return {}
	# Só prédios: muralhas, torres e enfeites ficam de fora.
	var n := path.get_file().get_basename()
	var is_building := ("building" in n) and not ("wall" in n) and not ("tower" in n) \
			and not ("fence" in n) and not ("stage" in n) and not ("bridge" in n) \
			and not ("scaffolding" in n) and not ("dirt" in n) and not ("grain" in n) \
			and not ("destroyed" in n)
	if not is_building:
		return {}
	var aabb: AABB = baked.mesh.get_aabb()
	# A malha cozida está em UNIDADES NATIVAS do modelo (a escala real é aplicada na
	# instância, por tipo), então os limites aqui são nativos — proporcionais.
	var size := aabb.size * 0.82
	# Só faz sentido abrir interior em prédio com porte suficiente.
	if size.x < 0.45 or size.z < 0.45 or size.y < 0.55:
		return {}
	var room := InteriorBuilder.build(size, seed_val)
	if room.is_empty():
		return {}
	var floor_y := aabb.position.y + 0.02
	var shape: ConcavePolygonShape3D = (room["mesh"] as ArrayMesh).create_trimesh_shape()
	return {
		"mesh": room["mesh"],
		"shape": shape,
		"offset": Vector3(aabb.position.x + aabb.size.x * 0.5, floor_y, aabb.position.z + aabb.size.z * 0.5),
		"size": size,
	}


## Reúne as malhas por material, já no espaço local escalado.
static func _collect_groups(n: Node, xf: Transform3D, groups: Dictionary) -> void:
	var cur := xf
	if n is Node3D:
		cur = xf * (n as Node3D).transform
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			for si in mi.mesh.get_surface_count():
				var mat: Material = mi.mesh.surface_get_material(si)
				var key := mat.get_instance_id() if mat else 0
				if not groups.has(key):
					var st := SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					groups[key] = {"mat": mat, "st": st}
				var st2: SurfaceTool = groups[key]["st"]
				st2.append_from(mi.mesh, si, cur)
	for c in n.get_children():
		_collect_groups(c, cur, groups)


## Escala pela altura da porta (maior porta do prédio), como antes.
static func _door_scale(inst: Node, player_h: float, door_factor: float, door_margin: float) -> float:
	var best := 0.0
	for n in _all(inst):
		if n is Node3D and ("Door" in n.name) and not (n is MeshInstance3D):
			var a := _aabb(n)
			if a.size.y > best and a.size.y < 8.0:
				best = a.size.y
	if best <= 0.2:
		return 1.0
	return (player_h * door_factor + door_margin) / best


static func _all(n: Node) -> Array:
	var o: Array = [n]
	for c in n.get_children():
		o.append_array(_all(c))
	return o


static func _aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for m in _meshes(n):
		var a: AABB = m.global_transform * m.mesh.get_aabb()
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	return out


static func _meshes(n: Node) -> Array:
	var o: Array = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		o.append(n)
	for c in n.get_children():
		o.append_array(_meshes(c))
	return o


# --- cache em disco ----------------------------------------------------------

static func _cache_path(path: String) -> String:
	return "%s/%d_%s.res" % [CACHE_DIR, CACHE_VERSION, str(path.hash()).replace("-", "n")]


static func _load_cache(path: String) -> BakedStructure:
	var cp := _cache_path(path)
	if not ResourceLoader.exists(cp):
		return null
	var res := ResourceLoader.load(cp)
	return res as BakedStructure


static func _save_cache(path: String, baked: BakedStructure) -> void:
	ResourceSaver.save(baked, _cache_path(path))
