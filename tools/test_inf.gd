extends SceneTree

func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node3D = load("res://src/world/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(3.0).timeout
	var ss := main.get_node_or_null("StartScreen")
	if ss: ss._enter()
	await create_timer(8.0).timeout
	var world: Node = main.get_node_or_null("World")
	var player: Node = main.get_node_or_null("Player")
	print("CHUNKS=", world._chunks.size(), " keys=", world._chunks.keys())
	var trees := 0; var rocks := 0; var logs := 0; var terr := 0
	for c in world._chunks.values():
		for ch in c.get_children():
			if ch is StaticBody3D:
				if ch.is_in_group(LFTileBaker.GROUP_TREE): trees += 1
				elif ch.is_in_group(LFTileBaker.GROUP_ROCK): rocks += 1
				elif ch.is_in_group(LFTileBaker.GROUP_LOG): logs += 1
				elif ch.is_in_group(LFTileBaker.GROUP_TERRAIN): terr += 1
	print("BODIES trees=", trees, " rocks=", rocks, " logs=", logs, " terrain=", terr)
	print("FPS=", Engine.get_frames_per_second(), " draws=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	# Anda 1 km e confere a cruz de 5.
	player.global_position = Vector3(1000, 80, 0)
	await create_timer(8.0).timeout
	print("CHUNKS apos andar=", world._chunks.size(), " player=", player.global_position)
	print("FPS2=", Engine.get_frames_per_second(), " draws=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	quit()
