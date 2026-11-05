extends CanvasLayer

## Tela de carregamento do mundo (aparece depois do "toque para entrar").
##
## Mostra a arte de abertura desfocada/escurecida, uma barra de progresso e o
## que está sendo feito ("preparando o terreno", "montando as vilas"...). O mundo
## gera os chunks por trás; quando o chunk do spawn fica pronto, a tela some.
##
## Quem chama usa `show()` e depois, quando terminar, `finish()`.

signal finished

@export var image_path: String = "res://assets/branding/tela-inicial.png"

var _root: Control
var _bar: ProgressBar
var _status: Label
var _t := 0.0
var _done := false
var _progress := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 11
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

	# Escurece a arte para o texto/barra aparecerem.
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	col.custom_minimum_size = Vector2(420, 0)
	center.add_child(col)

	var title := Label.new()
	title.text = "VETHERYON"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	col.add_child(title)

	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.value = 0.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(420, 14)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.14)
	sb.set_corner_radius_all(7)
	_bar.add_theme_stylebox_override("background", sb)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.92, 0.78, 0.42, 0.95)
	fill.set_corner_radius_all(7)
	_bar.add_theme_stylebox_override("fill", fill)
	col.add_child(_bar)

	_status = Label.new()
	_status.text = "Preparando o terreno..."
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 16)
	_status.add_theme_color_override("font_color", Color(0.92, 0.94, 0.97))
	_status.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_status.add_theme_constant_override("shadow_offset_x", 1)
	_status.add_theme_constant_override("shadow_offset_y", 1)
	col.add_child(_status)


## Atualiza barra e texto. `progress` em 0..1.
func set_progress(progress: float, status: String = "") -> void:
	if _done:
		return
	_progress = clampf(progress, 0.0, 1.0)
	if _bar:
		_bar.value = _progress
	if status != "" and _status:
		_status.text = status


func _process(delta: float) -> void:
	if _done:
		return
	# A barra nunca enche sozinha: para em 0.95 até o mundo terminar.
	_t += delta
	var shown := minf(_progress, 0.95)
	if _bar and _bar.value < shown:
		_bar.value = minf(_bar.value + delta * 0.6, shown)


## Termina: enche a barra, dá um fade e libera a tela.
func finish() -> void:
	if _done:
		return
	_done = true
	if _bar:
		_bar.value = 1.0
	if _status:
		_status.text = "Pronto!"
	var tw := create_tween()
	tw.tween_interval(0.15)
	tw.tween_property(_root, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)
	finished.emit()
