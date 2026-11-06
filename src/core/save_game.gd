class_name SaveGame
extends RefCounted

## Vários mundos salvos do Vetheryon.
##
## O mundo é procedural: o que existe de verdade é a SEED e onde o jogador está.
## Então "salvar um mundo" = gravar nome + seed + posição. Cada mundo é um arquivo
## em `user://worlds/`, e o índice (`user://worlds/index.json`) lista todos para a
## tela de seleção.

const DIR := "user://worlds"
const INDEX := "user://worlds/index.json"

## Id do mundo aberto agora ("" = nenhum). O resto do jogo lê daqui para salvar.
static var current_id: String = ""


static func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))


static func _path(id: String) -> String:
	return "%s/%s.json" % [DIR, id]


## Lista os mundos salvos, do mais recente para o mais antigo.
## Cada item: {id, name, seed, player, saved_at}.
static func list_worlds() -> Array:
	_ensure_dir()
	var out: Array = []
	if not FileAccess.file_exists(INDEX):
		return out
	var f := FileAccess.open(INDEX, FileAccess.READ)
	if f == null:
		return out
	var txt := f.get_as_text()
	f.close()
	var d: Variant = JSON.parse_string(txt)
	if not (d is Array):
		return out
	for entry: Variant in (d as Array):
		if entry is Dictionary:
			out.append(entry)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("saved_at", "")) > str(b.get("saved_at", "")))
	return out


static func _write_index(items: Array) -> void:
	_ensure_dir()
	var f := FileAccess.open(INDEX, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(items))
	f.close()


## Cria um mundo novo e devolve o id (o nome precisa ser único).
static func create_world(name: String, seed_value: int) -> String:
	_ensure_dir()
	var id := _slug(name)
	var items := list_worlds()
	# Garante id único.
	var base := id
	var n := 2
	while _id_taken(items, id):
		id = "%s_%d" % [base, n]
		n += 1
	var entry := {
		"id": id,
		"name": name,
		"seed": seed_value,
		"player": [0.0, 0.0, 0.0],
		"saved_at": Time.get_datetime_string_from_system(),
	}
	# Grava o ARQUIVO do mundo (não só o índice): é dele que saem a seed e a posição.
	_write_world(entry)
	items.append(entry)
	_write_index(items)
	current_id = id
	return id


static func _write_world(entry: Dictionary) -> void:
	_ensure_dir()
	var f := FileAccess.open(_path(str(entry.get("id", ""))), FileAccess.WRITE)
	if f == null:
		push_warning("SaveGame: não consegui gravar o mundo %s." % entry.get("id", ""))
		return
	f.store_string(JSON.stringify(entry))
	f.close()


static func _slug(name: String) -> String:
	var s := name.to_lower()
	var out := ""
	for i in s.length():
		var c := s[i]
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			out += c
		elif c == " " or c == "-" or c == "_":
			out += "_"
	if out == "":
		out = "mundo"
	return out


static func _id_taken(items: Array, id: String) -> bool:
	for e: Dictionary in items:
		if str(e.get("id", "")) == id:
			return true
	return false


## Lê os dados de um mundo ({} se não existir).
static func world_data(id: String) -> Dictionary:
	if id == "":
		return {}
	var p := _path(id)
	if not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var d: Variant = JSON.parse_string(txt)
	return d if d is Dictionary else {}


## Grava o progresso do mundo aberto (posição do jogador).
static func save_current(player_pos: Vector3) -> void:
	if current_id == "":
		return
	var d := world_data(current_id)
	if d.is_empty():
		return
	d["player"] = [player_pos.x, player_pos.y, player_pos.z]
	d["saved_at"] = Time.get_datetime_string_from_system()
	_write_world(d)
	# Atualiza o índice (nome/seed/data).
	var items := list_worlds()
	for e: Dictionary in items:
		if str(e.get("id", "")) == current_id:
			e["player"] = d["player"]
			e["saved_at"] = d["saved_at"]
	_write_index(items)


## Seed do mundo aberto.
static func current_seed() -> int:
	var d := world_data(current_id)
	return int(d.get("seed", 0))


## Posição salva do jogador no mundo aberto (null se não houver).
static func current_player() -> Variant:
	var d := world_data(current_id)
	var p: Variant = d.get("player")
	if p is Array and (p as Array).size() >= 3:
		return Vector3(float(p[0]), float(p[1]), float(p[2]))
	return null


static func delete_world(id: String) -> void:
	if FileAccess.file_exists(_path(id)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path(id)))
	var items := list_worlds()
	var keep: Array = []
	for e: Dictionary in items:
		if str(e.get("id", "")) != id:
			keep.append(e)
	_write_index(keep)
	if current_id == id:
		current_id = ""


## Compatibilidade com o formato antigo (um único save).
static func has_save(_seed_value: int) -> bool:
	return current_id != "" and current_player() != null


static func clear() -> void:
	if current_id != "":
		delete_world(current_id)
