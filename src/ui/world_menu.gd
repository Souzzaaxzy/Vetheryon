extends CanvasLayer

## Menu de mundos (tela inicial).
##
## Mostra a arte de abertura e, por cima, a lista dos mundos salvos. Dá para criar
## um mundo novo (com nome), entrar num existente e apagar. Entrar num mundo emite
## `world_chosen` com o id; quem escuta (o GameRoot) cuida de carregar.

signal world_chosen(id: String)

@export var image_path: String = "res://assets/branding/tela-inicial.png"

var _root: Control
var _list: VBoxContainer
var _empty_hint: Label
var _panel: PanelContainer          # painel de criar mundo
var _name_edit: LineEdit
var _status: Label
var _chosen := false
var _title_screen: Control          # tela "TOQUE PARA ENTRAR"
var _menu_box: VBoxContainer        # o menu de mundos em si
var _t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	get_tree().paused = true
	_build()
	_refresh()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var bg := TextureRect.new()
	bg.texture = load(image_path)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	_build_title_screen()
	_build_world_menu()
	_build_create_panel()


## Primeira tela: só o convite para entrar (a lista de mundos vem depois).
func _build_title_screen() -> void:
	_title_screen = Control.new()
	_title_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_title_screen)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_screen.add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	center.add_child(col)

	var title := Label.new()
	title.text = "VETHERYON"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	col.add_child(title)

	var hint := Label.new()
	hint.text = "TOQUE PARA ENTRAR"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 26)
	hint.add_theme_color_override("font_color", Color(0.98, 0.9, 0.72))
	hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	hint.add_theme_constant_override("shadow_offset_x", 1)
	hint.add_theme_constant_override("shadow_offset_y", 2)
	col.add_child(hint)
	_title_screen.set_meta("hint", hint)

	_title_screen.gui_input.connect(_on_title_input)


func _on_title_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventScreenTouch and event.pressed:
		pressed = true
	elif event is InputEventMouseButton and event.pressed:
		pressed = true
	elif event is InputEventKey and event.pressed:
		pressed = true
	if pressed:
		_show_menu()


## Sai da tela de título e mostra a lista de mundos.
func _show_menu() -> void:
	if _title_screen:
		_title_screen.visible = false
	if _menu_box:
		_menu_box.visible = true
	_refresh()


## Volta para a tela de título (usado quando o jogo volta ao menu).
func reset_to_title() -> void:
	_chosen = false
	if _panel:
		_panel.visible = false
	if _menu_box:
		_menu_box.visible = false
	if _title_screen:
		_title_screen.visible = true
		_root.modulate.a = 1.0


func _process(delta: float) -> void:
	# O convite pulsa, para não parecer uma imagem parada.
	if _title_screen == null or not _title_screen.visible:
		return
	_t += delta
	var hint: Label = _title_screen.get_meta("hint")
	if hint:
		hint.modulate.a = 0.65 + 0.35 * (0.5 + 0.5 * sin(_t * 2.2))


func _build_world_menu() -> void:
	# Painel central com título, lista e botões.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(560, 0)
	center.add_child(col)
	_menu_box = col

	var title := Label.new()
	title.text = "SEUS MUNDOS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	col.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	_list.custom_minimum_size = Vector2(540, 0)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	_empty_hint = Label.new()
	_empty_hint.text = "Nenhum mundo ainda. Crie o primeiro!"
	_empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_hint.add_theme_font_size_override("font_size", 15)
	_empty_hint.add_theme_color_override("font_color", Color(0.8, 0.83, 0.9))
	col.add_child(_empty_hint)

	_button(col, "CRIAR MUNDO", _open_create)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 14)
	_status.add_theme_color_override("font_color", Color(0.95, 0.75, 0.45))
	col.add_child(_status)
	_menu_box.visible = false


## Painel de criação de mundo (nome + criar/cancelar).
func _build_create_panel() -> void:
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.11, 0.13, 0.98)
	sb.border_color = Color(0.92, 0.78, 0.42, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 26
	sb.content_margin_bottom = 26
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.visible = false
	_root.add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(360, 0)
	_panel.add_child(col)

	var t := Label.new()
	t.text = "NOVO MUNDO"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 26)
	t.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
	col.add_child(t)

	var lbl := Label.new()
	lbl.text = "Nome do mundo"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.94))
	col.add_child(lbl)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Ex.: Reino do Norte"
	_name_edit.custom_minimum_size = Vector2(360, 46)
	_name_edit.add_theme_font_size_override("font_size", 18)
	_name_edit.text_submitted.connect(func(_t: String) -> void: _create())
	col.add_child(_name_edit)

	_button(col, "CRIAR", _create)
	_button(col, "CANCELAR", _close_create)


func _button(parent: Node, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 54)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 19)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.19, 0.23, 0.96)
	sb.border_color = Color(1, 1, 1, 0.14)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	b.add_theme_stylebox_override("normal", sb)
	var hb := sb.duplicate() as StyleBoxFlat
	hb.bg_color = Color(0.27, 0.29, 0.34, 0.98)
	b.add_theme_stylebox_override("hover", hb)
	b.add_theme_stylebox_override("pressed", hb)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var worlds := SaveGame.list_worlds()
	_empty_hint.visible = worlds.is_empty()
	for w: Dictionary in worlds:
		_list.add_child(_world_row(w))


## Uma linha da lista: nome + data, botão de entrar e botão de apagar.
func _world_row(w: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var b := Button.new()
	var id := str(w.get("id", ""))
	b.text = "%s\n%s" % [str(w.get("name", id)), _date_label(str(w.get("saved_at", "")))]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(430, 62)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 17)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.18, 0.22, 0.94)
	sb.border_color = Color(1, 1, 1, 0.12)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	b.add_theme_stylebox_override("normal", sb)
	var hb := sb.duplicate() as StyleBoxFlat
	hb.bg_color = Color(0.24, 0.27, 0.33, 0.98)
	hb.border_color = Color(0.92, 0.78, 0.42, 0.7)
	b.add_theme_stylebox_override("hover", hb)
	b.pressed.connect(func() -> void: _enter(id))
	row.add_child(b)

	var del := Button.new()
	del.text = "X"
	del.custom_minimum_size = Vector2(56, 62)
	del.focus_mode = Control.FOCUS_NONE
	del.add_theme_font_size_override("font_size", 18)
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(0.28, 0.13, 0.13, 0.92)
	dsb.set_corner_radius_all(10)
	del.add_theme_stylebox_override("normal", dsb)
	del.pressed.connect(func() -> void:
		SaveGame.delete_world(id)
		_refresh())
	row.add_child(del)
	return row


func _date_label(s: String) -> String:
	if s == "":
		return "novo"
	# "2026-11-06T13:08:00" -> "06/11 13:08"
	var d := s.replace("T", " ")
	if d.length() >= 16:
		var date := d.substr(0, 10).split("-")
		var tm := d.substr(11, 5)
		if date.size() == 3:
			return "%s/%s %s" % [date[2], date[1], tm]
	return s


func _open_create() -> void:
	_panel.visible = true
	_status.text = ""
	_name_edit.text = ""
	_name_edit.grab_focus()


func _close_create() -> void:
	_panel.visible = false


func _create() -> void:
	var name := _name_edit.text.strip_edges()
	if name == "":
		_status.text = "Dê um nome ao mundo."
		return
	# Seed nova a cada mundo (o jogador pode ter vários mundos diferentes).
	var seed_value := int(Time.get_unix_time_from_system()) ^ (randi() << 3)
	var id := SaveGame.create_world(name, seed_value)
	_close_create()
	_enter(id)


func _enter(id: String) -> void:
	if _chosen:
		return
	_chosen = true
	SaveGame.current_id = id
	get_tree().paused = false
	world_chosen.emit(id)
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
