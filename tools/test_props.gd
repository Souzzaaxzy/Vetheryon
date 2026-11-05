extends SceneTree

## Confirma: (1) pe acima do chao (model_foot_offset), (2) chunks = 5,
## (3) corpos de colisao de arvore/pedra presentes.

func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node3D = load("res://src/world/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(3.0).timeout
	var ss := main.get_node_or_null("StartScreen")
	if ss:
		ss._enter()
	await create_timer(8.0).timeout

	var player: Node3D = main.get_node_or_null("Player")
	var world: Node = main.get_node_or_null("World")
	print("CHUNKS=", world._chunks.size(), " offsets=", world._chunks.keys())

	var trees := 0
	var rocks := 0
	var logs := 0
	for c in world._chunks.values():
		for ch in c.get_children():
			if ch is StaticBody3D:
				if ch.is_in_group(LFTileBaker.GROUP_TREE):
					trees += 1
				elif ch.is_in_group(LFTileBaker.GROUP_ROCK):
					rocks += 1
				elif ch.is_in_group(LFTileBaker.GROUP_LOG):
					logs += 1
	print("PROP_BODIES trees=", trees, " rocks=", rocks, " logs=", logs)

	var model: Node3D = player.get_node_or_null("Model")
	var mn := 1e9
	for n in _meshes(model):
		var aabb := (n as VisualInstance3D).get_aabb()
		var gt := (n as Node3D).global_transform
		for k in 8:
			mn = minf(mn, (gt * aabb.get_endpoint(k)).y)
	print("FOOT: player.y=", player.global_position.y, " model_min_y=", mn, " acima=", mn - player.global_position.y)
	print("FPS=", Engine.get_frames_per_second(), " draws=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	quit()


func _meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out
