extends CanvasLayer

## Tela inicial e menu de mundos do Vetheryon.
##
## Duas telas, em sequência:
##   1. "TOQUE PARA ENTRAR" — só o convite, com o botão na parte de baixo da tela
##      (como era antes). Um toque em qualquer lugar avança.
##   2. "SEUS MUNDOS" — lista os mundos salvos, cria um novo, entra ou apaga.
##
## IMPORTANTE (bug corrigido): a lista de mundos ficava num `CenterContainer` de
## tela cheia que, com o `mouse_filter` padrão (`STOP`), ENGOLIA o toque antes de
## ele chegar na tela de título — o jogo travava no "toque para entrar". Agora a
## tela de título é a única que capta o toque enquanto está visível, e os
## containers de fundo ignoram o mouse.

signal world_chosen(id: String)

@export var image_path: String = "res://assets/branding/tela-inicial.png"

var _root: Control
var _title_screen: Control
var _title_button: Label
var _title_panel: PanelContainer
var _menu_screen: Control
var _list: VBoxContainer
var _empty_hint: Label
var _create_panel: PanelContainer
var _name_edit: LineEdit
var _status: Label
var _chosen := false
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
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE   # não capta: quem capta é cada tela
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
	_build_menu_screen()
	_build_create_panel()
	_show_title()


# --- tela 1: toque para entrar ------------------------------------------------

## Só o convite, com o botão centralizado na parte de baixo da tela.
func _build_title_screen() -> void:
	_title_screen = Control.new()
	_title_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_title_screen)

	# Faixa inferior que centraliza o botão (o container dá o tamanho do painel).
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	holder.offset_top = -150
	holder.offset_bottom = -40
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_screen.add_child(holder)

	# Painel do botão: só o texto, sem fundo nem borda.
	_title_panel = PanelContainer.new()
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	_title_panel.add_theme_stylebox_override("panel", sb)
	_title_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_title_panel)

	_title_button = Label.new()
	_title_button.text = "TOQUE PARA ENTRAR"
	_title_button.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_button.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_button.add_theme_font_size_override("font_size", 30)
	_title_button.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
	_title_button.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_title_button.add_theme_constant_override("shadow_offset_x", 1)
	_title_button.add_theme_constant_override("shadow_offset_y", 2)
	_title_panel.add_child(_title_button)

	# (Sem título no topo: a arte de abertura já traz o logo.)
	_title_screen.gui_input.connect(_on_title_input)


func _on_title_input(event: InputEvent) -> void:
	if not _is_press(event):
		return
	_show_menu()


# --- tela 2: menu de mundos ---------------------------------------------------

func _build_menu_screen() -> void:
	_menu_screen = Control.new()
	_menu_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_menu_screen)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_screen.add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(560, 0)
	center.add_child(col)

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
	scroll.custom_minimum_size = Vector2(560, 290)
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

	_menu_button(col, "CRIAR MUNDO", _open_create)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 14)
	_status.add_theme_color_override("font_color", Color(0.95, 0.75, 0.45))
	col.add_child(_status)


func _menu_button(parent: Node, text: String, action: Callable) -> Button:
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


## Uma linha da lista: nome + data, botão de entrar e botão de apagar.
func _world_row(w: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var id := str(w.get("id", ""))

	var b := Button.new()
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
	var d := s.replace("T", " ")
	if d.length() >= 16:
		var date := d.substr(0, 10).split("-")
		var tm := d.substr(11, 5)
		if date.size() == 3:
			return "%s/%s %s" % [date[2], date[1], tm]
	return s


# --- painel de criar mundo ----------------------------------------------------

func _build_create_panel() -> void:
	_create_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.11, 0.13, 0.98)
	sb.border_color = Color(0.92, 0.78, 0.42, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 26
	sb.content_margin_bottom = 26
	_create_panel.add_theme_stylebox_override("panel", sb)
	_create_panel.set_anchors_preset(Control.PRESET_CENTER)
	_create_panel.visible = false
	_root.add_child(_create_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(360, 0)
	_create_panel.add_child(col)

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

	_menu_button(col, "CRIAR", _create)
	_menu_button(col, "CANCELAR", _close_create)


# --- navegação ----------------------------------------------------------------

func _show_title() -> void:
	_title_screen.visible = true
	_menu_screen.visible = false
	_create_panel.visible = false


func _show_menu() -> void:
	_title_screen.visible = false
	_menu_screen.visible = true
	_create_panel.visible = false
	_refresh()


## Volta para a tela de título (usado quando o jogo volta ao menu).
func reset_to_title() -> void:
	_chosen = false
	_root.modulate.a = 1.0
	_show_title()


func _refresh() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		c.queue_free()
	var worlds := SaveGame.list_worlds()
	_empty_hint.visible = worlds.is_empty()
	for w: Dictionary in worlds:
		_list.add_child(_world_row(w))


func _open_create() -> void:
	_create_panel.visible = true
	_status.text = ""
	_name_edit.text = ""
	_name_edit.grab_focus()


func _close_create() -> void:
	_create_panel.visible = false


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


func _is_press(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventKey:
		return (event as InputEventKey).pressed
	return false


func _process(delta: float) -> void:
	# O convite pulsa, para não parecer uma imagem parada.
	if _title_screen == null or not _title_screen.visible:
		return
	_t += delta
	var pulse := 0.5 + 0.5 * sin(_t * 2.2)
	_title_button.modulate.a = 0.72 + 0.28 * pulse
	_title_panel.position.y = -6.0 * pulse
	_title_panel.scale = Vector2.ONE * (1.0 + 0.03 * pulse)
