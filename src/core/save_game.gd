class_name SaveGame
extends RefCounted

## Save do mundo do Vetheryon.
##
## O mundo é procedural: o que existe de verdade é a SEED e onde o jogador está.
## Então "salvar o mundo" = gravar a seed + a posição do jogador. Ao entrar de
## novo com a mesma seed, o jogador volta para onde parou.

const PATH := "user://vetheryon_save.json"


## Grava o estado atual. `extra` permite acrescentar campos sem quebrar o formato.
static func save(seed_value: int, player_pos: Vector3, extra := {}) -> void:
	var d := {
		"seed": seed_value,
		"player": [player_pos.x, player_pos.y, player_pos.z],
		"saved_at": Time.get_datetime_string_from_system(),
	}
	for k in extra:
		d[k] = extra[k]
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("SaveGame: não consegui abrir %s para escrita." % PATH)
		return
	f.store_string(JSON.stringify(d))
	f.close()


## Lê o save (dicionário vazio se não existir ou estiver corrompido).
static func load_data() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var d: Variant = JSON.parse_string(txt)
	if d is Dictionary:
		return d
	return {}


## Posição salva do jogador, ou null se não houver save (ou a seed for outra).
static func saved_player(seed_value: int) -> Variant:
	var d := load_data()
	if d.is_empty() or int(d.get("seed", 0)) != seed_value:
		return null
	var p: Variant = d.get("player")
	if p is Array and (p as Array).size() >= 3:
		return Vector3(float(p[0]), float(p[1]), float(p[2]))
	return null


static func has_save(seed_value: int) -> bool:
	return saved_player(seed_value) != null


## Apaga o save (usado por "novo mundo").
static func clear() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
