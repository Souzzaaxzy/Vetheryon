extends CanvasLayer

## HUD do Vetheryon: título, FPS e dica de controles.
## Se VETHERYON_SCREENSHOT estiver definida, salva um PNG e encerra — usado para
## validação visual automatizada (headless / CI).

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
	_hint.text = "Desktop: WASD + mouse · Shift correr · Espaço pular · F alterna câmera"
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
			if OS.get_environment("VETHERYON_AERIAL") != "":
				_add_aerial_camera()
				await get_tree().process_frame
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(shot)
			print("SHOT_SAVED ", shot)
			get_tree().quit()


func _add_aerial_camera() -> void:
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 3000.0
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.6, 0.7)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.9, 0.95)
	env.ambient_light_energy = 1.3
	env.fog_enabled = false
	cam.environment = env
	var main := get_node("/root/Main")
	main.add_child(cam)
	# Foca na vila (definida no Terrain).
	var terrain := main.get_node_or_null("Terrain")
	var vc := Vector3(60, 0, -60)
	if terrain and "village_center" in terrain:
		vc = Vector3(terrain.village_center.x, 0, terrain.village_center.y)
	cam.global_position = vc + Vector3(30, 45, 30)
	cam.look_at(vc + Vector3(0, 2, 0), Vector3.UP)
	cam.current = true
