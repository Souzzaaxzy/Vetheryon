extends CanvasLayer

## Menu de pausa do jogo: uma engrenagem desenhada no canto superior direito.
##
## Ao tocar, o jogo pausa e aparece um painel com opções. "Salvar e sair" grava o
## mundo e avisa quem escutou (`exit_requested`) para voltar à tela inicial.

signal exit_requested
signal save_requested

const GEAR_SIZE := 78.0
const GEAR_MARGIN := 16.0

var _gear: Control
var _overlay: Control
var _toast: Label
var _enabled := false
var _open := false
var _toast_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 9
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _build() -> void:
	# --- engrenagem (canto superior direito) ---
	_gear = Control.new()
	_gear.custom_minimum_size = Vector2(GEAR_SIZE, GEAR_SIZE)
	_gear.size = Vector2(GEAR_SIZE, GEAR_SIZE)
	_gear.mouse_filter = Control.MOUSE_FILTER_STOP
	_gear.visible = false
	_gear.draw.connect(_draw_gear)
	_gear.gui_input.connect(_on_gear_input)
	add_child(_gear)

	# --- overlay do menu ---
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.11, 0.13, 0.96)
	sb.border_color = Color(0.92, 0.78, 0.42, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 26
	sb.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(320, 0)
	panel.add_child(col)

	var title := Label.new()
	title.text = "PAUSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
	col.add_child(title)

	_add_menu_button(col, "CONTINUAR", _close_menu)
	_add_menu_button(col, "SALVAR", _on_save_only)
	_add_menu_button(col, "SALVAR E SAIR", _on_save_exit)

	# --- aviso "Salvo!" ---
	_toast = Label.new()
	_toast.text = "Mundo salvo!"
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 18)
	_toast.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
	_toast.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_toast.add_theme_constant_override("shadow_offset_x", 1)
	_toast.add_theme_constant_override("shadow_offset_y", 2)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.visible = false
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)


func _add_menu_button(parent: Node, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 58)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.19, 0.23, 0.95)
	sb.border_color = Color(1, 1, 1, 0.12)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	b.add_theme_stylebox_override("normal", sb)
	var hb := sb.duplicate() as StyleBoxFlat
	hb.bg_color = Color(0.26, 0.28, 0.33, 0.98)
	b.add_theme_stylebox_override("hover", hb)
	b.add_theme_stylebox_override("pressed", hb)
	b.pressed.connect(action)
	parent.add_child(b)


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	_gear.position = Vector2(size.x - GEAR_SIZE - GEAR_MARGIN, GEAR_MARGIN)
	if _toast:
		_toast.size = Vector2(400, 40)
		_toast.position = Vector2((size.x - 400) * 0.5, size.y * 0.18)
	_gear.queue_redraw()


## Liga/desliga a engrenagem (escondida antes de entrar no mundo).
func set_enabled(on: bool) -> void:
	_enabled = on
	if _gear:
		_gear.visible = on
	if not on:
		_close_menu()


func _draw_gear() -> void:
	var c := Vector2(GEAR_SIZE, GEAR_SIZE) * 0.5
	var r := GEAR_SIZE * 0.5 - 8.0
	# Fundo para dar contraste sobre qualquer cenário.
	_gear.draw_circle(c, r * 1.18, Color(0, 0, 0, 0.30))
	var col := Color(1, 1, 1, 0.92)
	var teeth := 8
	for i in teeth:
		var a := TAU * i / teeth
		var dir := Vector2(cos(a), sin(a))
		_gear.draw_line(c + dir * (r * 0.66), c + dir * (r * 1.02), col, r * 0.40, true)
	_gear.draw_circle(c, r * 0.80, col)
	_gear.draw_circle(c, r * 0.30, Color(0.10, 0.10, 0.12, 1))


func _on_gear_input(event: InputEvent) -> void:
	if not _enabled or _open:
		return
	var pressed := false
	if event is InputEventScreenTouch and event.pressed:
		pressed = true
	elif event is InputEventMouseButton and event.pressed:
		pressed = true
	if pressed:
		_open_menu()


func _open_menu() -> void:
	_open = true
	_overlay.visible = true
	_gear.visible = false
	get_tree().paused = true


func _close_menu() -> void:
	_open = false
	if _overlay:
		_overlay.visible = false
	if _gear:
		_gear.visible = _enabled
	get_tree().paused = false


func _on_save_only() -> void:
	save_requested.emit()
	_show_toast()


func _on_save_exit() -> void:
	# Marca a intenção de sair e pede o salvamento; quem escuta cuida do resto.
	_close_menu()
	exit_requested.emit()


func _show_toast() -> void:
	if _toast == null:
		return
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_t = 1.6


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast.visible = false
