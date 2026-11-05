extends CanvasLayer

## Mochila: aberta pelo botão da hotbar. À esquerda a lista de itens da mochila
## (toca para mandar para a hotbar); à direita os slots de armadura e uma
## prévia do personagem girando.

signal closed

const PANEL_W := 0.86
const PANEL_H := 0.80

var inventory: Node = null

var _root: Control
var _list: VBoxContainer
var _armor_slots: Array[Control] = []
var _preview: SubViewportContainer
var _viewport: SubViewport
var _model_root: Node3D
var _spin := 0.0
var _open := false


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	get_viewport().size_changed.connect(_layout)


func set_inventory(inv: Node) -> void:
	inventory = inv
	if inventory:
		if not inventory.changed.is_connected(_refresh):
			inventory.changed.connect(_refresh)
	_refresh()


func open() -> void:
	_open = true
	visible = true
	get_tree().paused = true
	_refresh()


func close() -> void:
	_open = false
	visible = false
	get_tree().paused = false
	closed.emit()


func is_open() -> bool:
	return _open


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.11, 0.13, 0.97)
	sb.border_color = Color(0.92, 0.78, 0.42, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	panel.add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)
	var title := Label.new()
	title.text = "MOCHILA"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var close_btn := Button.new()
	close_btn.text = "FECHAR"
	close_btn.custom_minimum_size = Vector2(120, 44)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	outer.add_child(columns)

	# --- Esquerda: itens da mochila ---
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size = Vector2(300, 0)
	columns.add_child(left)
	var ltitle := Label.new()
	ltitle.text = "Itens"
	ltitle.add_theme_font_size_override("font_size", 18)
	ltitle.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96))
	left.add_child(ltitle)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 300)
	left.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	# --- Direita: armaduras + personagem ---
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	columns.add_child(right)
	var rtitle := Label.new()
	rtitle.text = "Equipamento"
	rtitle.add_theme_font_size_override("font_size", 18)
	rtitle.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96))
	right.add_child(rtitle)

	var right_row := HBoxContainer.new()
	right_row.add_theme_constant_override("separation", 14)
	right.add_child(right_row)

	var armor_col := VBoxContainer.new()
	armor_col.add_theme_constant_override("separation", 8)
	right_row.add_child(armor_col)
	for i in Inventory.ARMOR:
		var s := Control.new()
		s.custom_minimum_size = Vector2(58, 58)
		s.size = Vector2(58, 58)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.draw.connect(_draw_armor.bind(i))
		armor_col.add_child(s)
		_armor_slots.append(s)

	# Prévia do personagem (SubViewport com uma câmera girando em volta).
	_preview = SubViewportContainer.new()
	_preview.custom_minimum_size = Vector2(240, 320)
	_preview.stretch = true
	right_row.add_child(_preview)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(240, 320)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_preview.add_child(_viewport)
	_setup_preview()


func _setup_preview() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.14, 0.15, 0.18)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.9, 0.92, 1.0)
	e.ambient_light_energy = 1.1
	env.environment = e
	_viewport.add_child(env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 30, 0)
	light.light_energy = 1.1
	_viewport.add_child(light)

	_model_root = Node3D.new()
	_viewport.add_child(_model_root)
	var ps: PackedScene = load("res://src/player/player.tscn")
	if ps:
		var model: Node3D = ps.instantiate()
		# Tira a física/script: é só a prévia.
		model.set_script(null)
		model.name = "PreviewModel"
		_model_root.add_child(model)

	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.position = Vector3(0, 1.15, 3.0)
	cam.current = true
	_viewport.add_child(cam)


func _process(delta: float) -> void:
	if not _open or _model_root == null:
		return
	_spin += delta * 0.7
	_model_root.rotation.y = _spin


func _layout() -> void:
	if _root:
		_root.visible = _open


func _draw_armor(i: int) -> void:
	var c := _armor_slots[i]
	var r := Rect2(Vector2.ZERO, c.size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.11, 0.13, 0.72)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.18)
	c.draw_style_box(sb, r)
	var item = null
	if inventory and i < inventory.armor.size():
		item = inventory.armor[i]
	if item != null and item.get("id", "") != "":
		c.draw_rect(Rect2(Vector2(10, 10), c.size - Vector2(20, 20)), Items.icon_color(item["id"]), true)
	else:
		var f := ThemeDB.fallback_font
		var labels := ["CAB", "PEI", "PER", "PÉS"]
		c.draw_string(f, Vector2(0, c.size.y * 0.5 + 5), labels[i], HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 12, Color(1, 1, 1, 0.35))


func _refresh() -> void:
	if _list == null:
		return
	for ch in _list.get_children():
		ch.queue_free()
	var any := false
	if inventory:
		for i in inventory.backpack.size():
			var slot = inventory.backpack[i]
			if slot != null and slot.get("id", "") != "":
				any = true
				_list.add_child(_make_row(slot["id"], int(slot.get("count", 1)), i))
	if not any:
		var l := Label.new()
		l.text = "Vazia — pegue itens no mundo"
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		_list.add_child(l)
	for s in _armor_slots:
		s.queue_redraw()


func _make_row(id: String, count: int, backpack_index: int) -> Control:
	var row := Button.new()
	row.custom_minimum_size = Vector2(280, 52)
	row.focus_mode = Control.FOCUS_NONE
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hb)
	var sw := Control.new()
	sw.custom_minimum_size = Vector2(34, 34)
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sw.draw.connect(_draw_swatch.bind(sw, id))
	hb.add_child(sw)
	var lbl := Label.new()
	lbl.text = "%s  x%d" % [Items.item_name(id), count]
	lbl.add_theme_color_override("font_color", Color(0.95, 0.96, 0.99))
	hb.add_child(lbl)
	row.pressed.connect(_move_to_hotbar.bind(backpack_index))
	return row


func _draw_swatch(c: Control, id: String) -> void:
	c.draw_rect(Rect2(Vector2(2, 2), Vector2(30, 30)), Items.icon_color(id), true)


## Manda um item da mochila para a hotbar.
func _move_to_hotbar(backpack_index: int) -> void:
	if inventory == null:
		return
	var slot = inventory.backpack[backpack_index]
	if slot == null or slot.get("id", "") == "":
		return
	var id: String = slot["id"]
	var count: int = int(slot["count"])
	var leftover: int = inventory.add_item(id, count)
	var took: int = count - leftover
	if took > 0:
		inventory.backpack[backpack_index] = {}
		inventory.changed.emit()
