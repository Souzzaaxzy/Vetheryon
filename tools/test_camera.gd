extends SceneTree

## Testa a relação câmera/analógico: empurrar o analógico "para cima" deve mover
## o personagem na direção em que a câmera aponta, e girar a câmera deve mudar
## essa direção (sem loop de realimentação).

func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var packed: PackedScene = load("res://src/world/main.tscn")
	var main: Node = packed.instantiate()
	root.add_child(main)
	for _i in range(20):
		await physics_frame

	var player: Player = main.get_node_or_null("Player")
	var cam: CameraRig = main.get_node_or_null("CameraRig")
	print("TEST player=", player != null, " cam=", cam != null)
	if player == null or cam == null:
		quit()
		return

	# 1) Câmera olhando para -Z (yaw 0). Empurrar "para cima" (y=-1) deve mover
	#    o personagem na direção -Z.
	cam.apply_look(Vector2(0, 0))
	await physics_frame
	var before: Vector3 = player.global_position
	player.set_move_input(Vector2(0, -1))
	for _i in range(40):
		await physics_frame
	var after: Vector3 = player.global_position
	var delta := after - before
	print("TEST yaw0 move=(%.2f, %.2f) dz=%.2f dx=%.2f" % [delta.x, delta.z, delta.z, delta.x])
	print("TEST forward_is_-Z=", delta.z < -0.3)

	# 2) Gira a câmera 90 graus (arrasto para a direita) e verifica que a nova
	#    direção "para cima" mudou.
	cam.apply_look(Vector2(500, 0))
	await physics_frame
	player.set_move_input(Vector2.ZERO)
	for _i in range(20):
		await physics_frame
	var b2: Vector3 = player.global_position
	player.set_move_input(Vector2(0, -1))
	for _i in range(40):
		await physics_frame
	var d2 := player.global_position - b2
	print("TEST yaw90 move dx=%.2f dz=%.2f" % [d2.x, d2.z])
	print("TEST direction_changed=", abs(d2.x) > 0.3 and abs(d2.z) < 0.3)
	quit()
