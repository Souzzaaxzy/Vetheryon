extends SceneTree

## Teste de solidez: verifica que o chão segura o jogador, que há colisão nas
## estruturas/casas e que a vila foi construída.
##   godot --headless --path . --script res://tools/test_solid.gd

func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var packed: PackedScene = load("res://src/world/main.tscn")
	var main: Node = packed.instantiate()
	root.add_child(main)
	for _i in range(30):
		await physics_frame

	var player: Player = main.get_node_or_null("Player")
	print("TEST player=", player != null, " y=", player.global_position.y if player else "nil")

	# Conta corpos estáticos (colisão) e casas.
	var acc := [0, 0, 0]
	_count(main, acc)
	print("TEST meshes=", acc[2], " static_bodies=", acc[0], " houses=", acc[1])

	# Testa colisão: tenta atravessar uma casa andando contra ela.
	if player and acc[1] > 0:
		var house := _find_house(main)
		if house:
			player.global_position = house.global_position + Vector3(0, 1.0, 6.0)
			var before := player.global_position.distance_to(house.global_position)
			Input.action_press("move_forward")
			for _i in range(90):
				await physics_frame
			Input.action_release("move_forward")
			var after := player.global_position.distance_to(house.global_position)
			print("TEST house_collision dist_before=", before, " after=", after, " blocked=", after > 2.0)

	# Testa o chão: teleporta o jogador para bem alto e deixa cair.
	if player:
		player.global_position = Vector3(0, 60, 0)
		player.velocity = Vector3.ZERO
		for _i in range(180):
			await physics_frame
		var gy := player.global_position.y
		print("TEST fall_landed_y=", gy, " (esperado ~ altura do terreno, NAO negativo)")
		print("TEST_SOLID_OK=", gy > -5.0 and player.is_on_floor())
	quit()


func _count(node: Node, acc: Array) -> void:
	if node is MeshInstance3D:
		acc[2] += 1
	if node is StaticBody3D:
		acc[0] += 1
	if node.name.begins_with("House"):
		acc[1] += 1
	for c in node.get_children():
		_count(c, acc)


func _find_house(node: Node) -> Node3D:
	if node.name.begins_with("House"):
		return node
	for c in node.get_children():
		var f := _find_house(c)
		if f:
			return f
	return null
