extends CanvasLayer

## Tela de início (tipo login, mas só com "toque para entrar").
##
## Cobre o jogo com a arte de abertura; o mundo carrega por trás (streaming), então
## entrar é instantâneo. Um toque em qualquer lugar (ou no botão) inicia o jogo.
## O botão pulsa e desliza de leve para não parecer uma imagem parada.

signal entered

@export var image_path: String = "res://assets/branding/tela-inicial.png"
@export var title: String = "TOQUE PARA ENTRAR"

var _root: Control
var _button: Label
var _panel: PanelContainer
var _t := 0.0
var _entered := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_build()


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

	# Escurecimento leve no rodapé para o texto ficar legível sobre a arte.
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0.35)
	fade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	fade.anchor_top = 0.72
	fade.offset_bottom = 0
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(fade)

	# Faixa inferior que centraliza o botão (o container dá o tamanho do painel).
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	holder.offset_top = -150
	holder.offset_bottom = -40
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(holder)

	# Painel do botão: só o texto, sem fundo nem borda (fundo transparente).
	# PanelContainer abraça o texto, então o CenterContainer centraliza de verdade.
	_panel = PanelContainer.new()
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_panel)

	_button = Label.new()
	_button.text = title
	_button.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_button.add_theme_font_size_override("font_size", 30)
	_button.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
	_button.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_button.add_theme_constant_override("shadow_offset_x", 1)
	_button.add_theme_constant_override("shadow_offset_y", 2)
	_panel.add_child(_button)

	_root.gui_input.connect(_on_input)
	await get_tree().process_frame
	_panel.pivot_offset = _panel.size * 0.5


func _process(delta: float) -> void:
	if _entered:
		return
	_t += delta
	# Pulso suave: brilho + leve subida/descida.
	var pulse := 0.5 + 0.5 * sin(_t * 2.2)
	_button.modulate.a = 0.72 + 0.28 * pulse
	_panel.position.y = -6.0 * pulse
	_panel.scale = Vector2.ONE * (1.0 + 0.03 * pulse)


func _on_input(event: InputEvent) -> void:
	if _entered:
		return
	var pressed := false
	if event is InputEventScreenTouch and event.pressed:
		pressed = true
	elif event is InputEventMouseButton and event.pressed:
		pressed = true
	elif event is InputEventKey and event.pressed:
		pressed = true
	if pressed:
		_enter()


func _enter() -> void:
	_entered = true
	get_tree().paused = false
	entered.emit()
	# Fade de saída e depois libera a tela.
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)
