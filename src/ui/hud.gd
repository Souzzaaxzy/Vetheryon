extends CanvasLayer

## HUD mínimo da fatia vertical: título, dica de controles e FPS.

var _label: Label
var _hint: Label
var _frames := 0


func _ready() -> void:
	_label = Label.new()
	_label.text = "VETHERYON"
	_label.add_theme_font_size_override("font_size", 22)
	_label.position = Vector2(20, 16)
	add_child(_label)

	_hint = Label.new()
	_hint.text = "Desktop: WASD + mouse (botão direito captura) · Shift correr · Espaço pular · F alterna câmera"
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.position = Vector2(20, 48)
	add_child(_hint)


func _process(_delta: float) -> void:
	if _label:
		_label.text = "VETHERYON   |   FPS: %d" % Engine.get_frames_per_second()

	var shot := OS.get_environment("VETHERYON_SCREENSHOT")
	if shot != "":
		_frames += 1
		if _frames == 120:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(shot)
			print("SHOT_SAVED ", shot)
			get_tree().quit()
