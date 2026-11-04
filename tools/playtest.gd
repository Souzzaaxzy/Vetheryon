extends SceneTree

## Harness de playtest: carrega o jogo, simula inputs e captura screenshots de
## vários ângulos/estados para inspeção (inclusive 1ª pessoa e perto do corpo).
##
##   VETHERYON_PLAYDIR=/tmp/play godot --rendering-driver opengl3 --script res://tools/playtest.gd

var _dir := "/tmp/play"
var _main: Node
var _player: Player
var _cam: CameraRig


func _initialize() -> void:
	_run()


func _run() -> void:
	var d := OS.get_environment("VETHERYON_PLAYDIR")
	if d != "":
		_dir = d
	DirAccess.make_dir_recursive_absolute(_dir)

	await process_frame
	_main = load("res://src/world/main.tscn").instantiate()
	root.add_child(_main)
	await create_timer(0.6).timeout

	_player = _main.get_node_or_null("Player")
	_cam = _main.get_node_or_null("CameraRig")
	print("PLAY player=", _player != null, " cam=", _cam != null)

	# 1) Terceira pessoa, parado.
	await _shot("01_third_idle")

	# 2) Terceira pessoa, andando.
	Input.action_press("move_forward")
	await create_timer(0.8).timeout
	await _shot("02_third_walk")
	Input.action_release("move_forward")
	await create_timer(0.4).timeout

	# 3) Gira a câmera 180º (ver a frente do personagem).
	if _cam:
		_cam.apply_look(Vector2(700, 0))
	await create_timer(0.3).timeout
	await _shot("03_third_front")

	# 4) Primeira pessoa.
	if _cam:
		_cam.toggle_mode()
	await create_timer(0.3).timeout
	await _shot("04_first")

	# 5) Close no personagem (câmera livre rente ao corpo).
	if _cam:
		_cam.toggle_mode()  # volta a 3a
	await create_timer(0.2).timeout
	await _free_closeup("05_closeup")

	# 6) Vista de longe do vilarejo.
	await _village_shot("06_village")

	print("PLAY_DONE")
	quit()


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [_dir, name])
	print("SHOT ", name)


func _free_closeup(name: String) -> void:
	var cam := Camera3D.new()
	cam.fov = 35.0
	_main.add_child(cam)
	var pp: Vector3 = _player.global_position
	cam.global_position = pp + Vector3(0.9, 1.0, 1.6)
	cam.look_at(pp + Vector3(0, 0.9, 0), Vector3.UP)
	cam.current = true
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
	print("SHOT ", name)


func _village_shot(name: String) -> void:
	var terrain := _main.get_node_or_null("Terrain")
	var c := Vector3(60, 0, -60)
	if terrain:
		c = Vector3(terrain.village_center.x, 0, terrain.village_center.y)
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.far = 3000.0
	_main.add_child(cam)
	cam.global_position = c + Vector3(10, 14, 34)
	cam.look_at(c + Vector3(0, 3, 0), Vector3.UP)
	cam.current = true
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
	print("SHOT ", name)
