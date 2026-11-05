extends CanvasLayer

## Barra de itens (hotbar): 9 quadradinhos arredondados embaixo da tela e, ao
## lado, um botão de mochila. Tocar num quadrado seleciona o item.

signal backpack_pressed
signal place_pressed

const SLOT := 64.0
const GAP := 8.0
const MARGIN := 16.0
const ICON_INSET := 12.0

var inventory: Node = null

var _root: Control
var _slots: Array[Control] = []
var _bag: Control
var _place: Control
var _selected := 0
var _enabled := false


func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()


func set_inventory(inv: Node) -> void:
	inventory = inv
	if inventory:
		if not inventory.changed.is_connected(_refresh):
			inventory.changed.connect(_refresh)
		if not inventory.selection_changed.is_connected(_on_sel):
			inventory.selection_changed.connect(_on_sel)
		_selected = inventory.selected
	_refresh()


func set_enabled(on: bool) -> void:
	_enabled = on
	if _root:
		_root.visible = on


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)

	for i in Inventory.HOTBAR:
		var s := Control.new()
		s.custom_minimum_size = Vector2(SLOT, SLOT)
		s.size = Vector2(SLOT, SLOT)
		s.mouse_filter = Control.MOUSE_FILTER_STOP
		s.draw.connect(_draw_slot.bind(i))
		s.gui_input.connect(_on_slot_input.bind(i))
		_root.add_child(s)
		_slots.append(s)

	_bag = Control.new()
	_bag.custom_minimum_size = Vector2(SLOT, SLOT)
	_bag.size = Vector2(SLOT, SLOT)
	_bag.mouse_filter = Control.MOUSE_FILTER_STOP
	_bag.draw.connect(_draw_bag)
	_bag.gui_input.connect(_on_bag_input)
	_root.add_child(_bag)

	_place = Control.new()
	_place.custom_minimum_size = Vector2(SLOT, SLOT)
	_place.size = Vector2(SLOT, SLOT)
	_place.mouse_filter = Control.MOUSE_FILTER_STOP
	_place.draw.connect(_draw_place)
	_place.gui_input.connect(_on_place_input)
	_root.add_child(_place)


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var total: float = Inventory.HOTBAR * SLOT + (Inventory.HOTBAR + 1) * GAP + SLOT * 2
	var x: float = (size.x - total) * 0.5
	var y := size.y - SLOT - MARGIN
	for i in _slots.size():
		_slots[i].position = Vector2(x + i * (SLOT + GAP), y)
	_bag.position = Vector2(x + Inventory.HOTBAR * (SLOT + GAP), y)
	_place.position = Vector2(x + (Inventory.HOTBAR + 1) * (SLOT + GAP), y)
	for s in _slots:
		s.queue_redraw()
	_bag.queue_redraw()


func _draw_slot(i: int) -> void:
	var c := _slots[i]
	var r := Rect2(Vector2.ZERO, Vector2(SLOT, SLOT))
	# Fundo do slot.
	c.draw_style_box(_slot_box(i == _selected), r)
	var item = null
	if inventory and i < inventory.hotbar.size():
		item = inventory.hotbar[i]
	if item != null and item.get("id", "") != "":
		_draw_item(c, item["id"], item.get("count", 1))


func _draw_bag() -> void:
	var c := _bag
	var r := Rect2(Vector2.ZERO, Vector2(SLOT, SLOT))
	c.draw_style_box(_slot_box(false), r)
	# Ícone de mochila desenhado (corpo + alça).
	var col := Color(0.86, 0.78, 0.62)
	var body := Rect2(Vector2(SLOT * 0.24, SLOT * 0.36), Vector2(SLOT * 0.52, SLOT * 0.42))
	c.draw_rect(body, col, true)
	c.draw_arc(Vector2(SLOT * 0.5, SLOT * 0.38), SLOT * 0.16, PI, TAU, 20, col, 3.0, true)
	c.draw_rect(Rect2(Vector2(SLOT * 0.36, SLOT * 0.52), Vector2(SLOT * 0.28, SLOT * 0.10)), Color(0.45, 0.36, 0.24), true)


func _draw_place() -> void:
	var c := _place
	c.draw_style_box(_slot_box(false), Rect2(Vector2.ZERO, Vector2(SLOT, SLOT)))
	# Ícone de "colocar": seta para baixo sobre uma linha (chão).
	var col := Color(0.72, 0.86, 0.66)
	c.draw_rect(Rect2(Vector2(SLOT * 0.22, SLOT * 0.72), Vector2(SLOT * 0.56, SLOT * 0.06)), col, true)
	c.draw_rect(Rect2(Vector2(SLOT * 0.45, SLOT * 0.26), Vector2(SLOT * 0.10, SLOT * 0.30)), col, true)
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(SLOT * 0.36, SLOT * 0.56), Vector2(SLOT * 0.64, SLOT * 0.56), Vector2(SLOT * 0.5, SLOT * 0.74)]), col)


func _on_place_input(event: InputEvent) -> void:
	if not _enabled:
		return
	if _is_press(event):
		place_pressed.emit()


func _slot_box(selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.11, 0.13, 0.72)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(3 if selected else 1)
	sb.border_color = Color(0.95, 0.82, 0.45, 0.95) if selected else Color(1, 1, 1, 0.20)
	return sb


func _draw_item(c: Control, id: String, count: int) -> void:
	var col := Items.icon_color(id)
	var box := Rect2(Vector2(ICON_INSET, ICON_INSET), Vector2(SLOT - ICON_INSET * 2, SLOT - ICON_INSET * 2))
	if id == "torch":
		# Cabo + chama.
		c.draw_rect(Rect2(Vector2(SLOT * 0.44, SLOT * 0.42), Vector2(SLOT * 0.12, SLOT * 0.38)), Color(0.42, 0.28, 0.16), true)
		c.draw_circle(Vector2(SLOT * 0.5, SLOT * 0.36), SLOT * 0.16, col)
		c.draw_circle(Vector2(SLOT * 0.5, SLOT * 0.33), SLOT * 0.08, Color(1.0, 0.95, 0.7))
	elif id == "sword":
		# Lâmina + guarda + punho.
		c.draw_rect(Rect2(Vector2(SLOT * 0.46, SLOT * 0.16), Vector2(SLOT * 0.08, SLOT * 0.48)), col, true)
		c.draw_rect(Rect2(Vector2(SLOT * 0.32, SLOT * 0.60), Vector2(SLOT * 0.36, SLOT * 0.07)), Color(0.55, 0.42, 0.22), true)
		c.draw_rect(Rect2(Vector2(SLOT * 0.45, SLOT * 0.67), Vector2(SLOT * 0.10, SLOT * 0.15)), Color(0.35, 0.24, 0.14), true)
	else:
		c.draw_rect(box, col, true)
	if count > 1:
		var f := ThemeDB.fallback_font
		c.draw_string(f, Vector2(SLOT - 8, SLOT - 6), str(count), HORIZONTAL_ALIGNMENT_RIGHT, SLOT, 16, Color.WHITE)


func _on_slot_input(event: InputEvent, i: int) -> void:
	if not _enabled:
		return
	if _is_press(event):
		if inventory:
			inventory.select(i)
		else:
			_selected = i
			_redraw_all()


func _on_bag_input(event: InputEvent) -> void:
	if not _enabled:
		return
	if _is_press(event):
		backpack_pressed.emit()


func _is_press(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return event.pressed
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	return false


func _on_sel(index: int) -> void:
	_selected = index
	_redraw_all()


func _refresh() -> void:
	_redraw_all()


func _redraw_all() -> void:
	for s in _slots:
		s.queue_redraw()
	if _bag:
		_bag.queue_redraw()
