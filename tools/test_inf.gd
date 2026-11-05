extends SceneTree

## Testa o mundo infinito: conta chunks, anda 1 km e confere que novos chunks
## aparecem (e que voltar regenera os antigos).

func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = load("res://src/world/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(3.0).timeout
	var ss := main.get_node_or_null("StartScreen")
	if ss:
		ss._enter()
	await create_timer(4.0).timeout

	var world: Node = main.get_node_or_null("World")
	var player: Node3D = main.get_node_or_null("Player")
	if world == null or player == null:
		print("SEM WORLD/PLAYER")
		quit()
		return
	print("CHUNKS inicial=", world._chunks.size())
	print("POS inicial=", player.global_position)
	print("PERF draws=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), " fps=", Engine.get_frames_per_second())

	# Teleporta ACIMA do terreno (senao a capsula entra no morro).
	player.global_position = Vector3(1000, 80, 0)
	await create_timer(10.0).timeout
	print("CHUNKS apos andar=", world._chunks.size())
	print("POS player=", player.global_position)
	print("PERF2 draws=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), " fps=", Engine.get_frames_per_second())

	# Volta: os chunks antigos devem ser regenerados.
	player.global_position = Vector3(0, 80, 0)
	await create_timer(10.0).timeout
	print("CHUNKS apos voltar=", world._chunks.size())
	print("POS volta=", player.global_position)
	quit()
