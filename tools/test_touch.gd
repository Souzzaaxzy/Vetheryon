extends SceneTree

## Teste automatizado dos controles touch (headless).
## Simula toque no joystick (esquerda) e arrasto na câmera (direita), verificando
## que o personagem se move e que a câmera gira. Roda com:
##   godot --headless --path . --script res://tools/test_touch.gd

func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var packed: PackedScene = load("res://src/world/main.tscn")
	var main: Node = packed.instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout

	var player: Player = main.get_node_or_null("Player")
	var touch: Node = main.get_node_or_null("TouchControls")
	print("TEST player=", player != null, " touch=", touch != null)
	if player == null or touch == null:
		quit()
		return

	var start_pos: Vector3 = player.global_position
	var start_rot: float = player.camera_rig.rotation.y

	# 1) Joystick: toque na metade esquerda e arraste para cima.
	var joy := Vector2(150, 600)
	touch._handle_touch(_make_touch(0, joy, true))
	touch._handle_drag(_make_drag(0, joy + Vector2(0, -90)))
	for _i in range(60):
		await physics_frame
	print("TEST move_input=", player.move_input)

	# 2) Câmera: arraste na metade direita.
	var cam_start := Vector2(900, 400)
	touch._handle_touch(_make_touch(1, cam_start, true))
	touch._handle_drag(_make_drag(1, cam_start + Vector2(120, 0)))
	await physics_frame
	print("TEST cam_rot_before=", start_rot, " after=", player.camera_rig.rotation.y)

	var moved: float = player.global_position.distance_to(start_pos)
	print("TEST moved_dist=", moved)
	print("TEST_RESULT moved_ok=", moved > 0.5, " cam_ok=", abs(player.camera_rig.rotation.y - start_rot) > 0.05)
	quit()


func _make_touch(index: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	return e


func _make_drag(index: int, pos: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	e.relative = Vector2.ZERO
	return e
