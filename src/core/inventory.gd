class_name Inventory
extends Node

## Inventário do jogador: a hotbar (9 slots) + a mochila (mais slots + armaduras).
##
## Guarda só os dados; quem desenha é a UI (`hotbar.gd`/`inventory_screen.gd`).
## Emite `changed` quando algo muda, então a UI se atualiza sozinha.

signal changed
signal selection_changed(index: int)

## Slots da hotbar (a barra de baixo).
const HOTBAR := 9
## Slots extras da mochila.
const BACKPACK := 18
## Slots de armadura (cabeça, peito, pernas, pés).
const ARMOR := 4

var hotbar: Array = []      # 9 x {id, count} ou null
var backpack: Array = []    # 18 x ...
var armor: Array = []       # 4 x ...
var selected := 0           # slot ativo da hotbar


func _ready() -> void:
	_fill(hotbar, HOTBAR)
	_fill(backpack, BACKPACK)
	_fill(armor, ARMOR)
	# Começa com os dois itens que existem.
	add_item("torch", 1)
	add_item("sword", 1)


func _fill(arr: Array, n: int) -> void:
	arr.clear()
	for i in n:
		arr.append({})


## Adiciona `count` de `id`; devolve o que não coube.
func add_item(id: String, count := 1) -> int:
	var max_stack := Items.stack_size(id)
	# Primeiro empilha no que já existe.
	for slot: Dictionary in _all_slots():
		if slot.get("id", "") == id and slot.get("count", 0) < max_stack:
			var room: int = max_stack - int(slot["count"])
			var put: int = mini(room, count)
			slot["count"] = int(slot["count"]) + put
			count -= put
			if count <= 0:
				changed.emit()
				return 0
	# Depois usa slots vazios.
	for slot: Dictionary in _all_slots():
		if slot.get("id", "") == "":
			var put: int = mini(max_stack, count)
			slot["id"] = id
			slot["count"] = put
			count -= put
			if count <= 0:
				changed.emit()
				return 0
	changed.emit()
	return count


## Tira `count` do item (procura em qualquer slot). Devolve quantos saíram.
func remove_item(id: String, count := 1) -> int:
	var removed := 0
	for slot: Dictionary in _all_slots():
		if slot.get("id", "") == id:
			var take: int = mini(int(slot["count"]), count - removed)
			slot["count"] = int(slot["count"]) - take
			removed += take
			if int(slot["count"]) <= 0:
				slot.erase("id")
				slot.erase("count")
			if removed >= count:
				break
	if removed > 0:
		changed.emit()
	return removed


func count_of(id: String) -> int:
	var n := 0
	for slot: Dictionary in _all_slots():
		if slot.get("id", "") == id:
			n += int(slot["count"])
	return n


## O item no slot ativo da hotbar (ou {} se vazio).
func held_item() -> Dictionary:
	var slot = hotbar[selected]
	if not (slot is Dictionary) or slot.get("id", "") == "":
		return {}
	return slot


func select(index: int) -> void:
	selected = clampi(index, 0, HOTBAR - 1)
	selection_changed.emit(selected)
	changed.emit()


func _all_slots() -> Array:
	return hotbar + backpack
