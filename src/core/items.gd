class_name Items
extends RefCounted

## Catálogo de itens do jogo. Cada item é um dicionário simples, então dá para
## acrescentar novos sem mexer na interface.

enum Kind { MATERIAL, WEAPON, TOOL, LIGHT, ARMOR }

## id -> definição. `icon` é a cor do quadradinho; `mesh` (opcional) é um
## PackedScene para segurar/mostrar no mundo.
const CATALOG := {
	"torch": {
		"name": "Tocha",
		"kind": Kind.LIGHT,
		"icon": Color(1.0, 0.72, 0.30),
		"stack": 16,
		"holdable": true,
		"placeable": true,
	},
	"sword": {
		"name": "Espada",
		"kind": Kind.WEAPON,
		"icon": Color(0.72, 0.78, 0.86),
		"stack": 1,
		"holdable": true,
		"placeable": false,
	},
}


static func get_item(id: String) -> Dictionary:
	return CATALOG.get(id, {})


static func item_name(id: String) -> String:
	return CATALOG.get(id, {}).get("name", id)


static func icon_color(id: String) -> Color:
	return CATALOG.get(id, {}).get("icon", Color(0.6, 0.6, 0.6))


static func kind(id: String) -> int:
	return int(CATALOG.get(id, {}).get("kind", Kind.MATERIAL))


static func stack_size(id: String) -> int:
	return int(CATALOG.get(id, {}).get("stack", 1))


static func is_holdable(id: String) -> bool:
	return bool(CATALOG.get(id, {}).get("holdable", false))


static func is_placeable(id: String) -> bool:
	return bool(CATALOG.get(id, {}).get("placeable", false))
