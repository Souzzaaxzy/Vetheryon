extends SceneTree

## Ferramenta de captura: entra no mundo, mira numa vila e salva um PNG.
##   VETHERYON_SHOT=/tmp/x.png godot --path . --script res://tools/screenshot.gd
## Variáveis: VETHERYON_SHOT (arquivo), VETHERYON_MODE=ground|aerial|hand.

func _init() -> void:
	var out := OS.get_environment("VETHERYON_SHOT")
	if out == "":
		out = "/tmp/vetheryon.png"
	var mode := OS.get_environment("VETHERYON_MODE")
	if mode == "":
		mode = "aerial"

	var main: Node = load("res://src/world/main.tscn").instantiate()
	get_root().add_child(main)
	# A tela inicial pausa o jogo e cobre tudo: some com ela para capturar o mundo.
	paused = false
	for n in ["StartScreen", "LoadingScreen", "PauseMenu"]:
		var c := main.get_node_or_null(n)
		if c:
			c.visible = false
			c.queue_free()
	var world: Node = main.get_node("World")
	var t := 0
	while t < 3000 and not world.is_ready():
		await process_frame
		t += 1
	# Deixa as estruturas montarem/cozinharem.
	for i in 600:
		await process_frame

	var player: Node3D = main.get_node("Player")
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 4000.0
	cam.current = true
	main.add_child(cam)

	if mode == "hand":
		cam.global_position = player.global_position + Vector3(1.2, 1.6, 1.2)
		cam.look_at(player.global_position + Vector3(0, 1.2, 0), Vector3.UP)
	elif mode == "close":
		# Mira no nó de estrutura realmente montado mais próximo do jogador.
		var target := _nearest_mounted(world, player.global_position)
		var y0: float = world.ground_height(target.x, target.z)
		cam.global_position = Vector3(target.x - 10.0, y0 + 5.0, target.z - 10.0)
		cam.look_at(Vector3(target.x, y0 + 3.0, target.z), Vector3.UP)
		print("CLOSE em ", target)
	elif mode == "ground":
		var vc := _nearest_village(world, player.global_position)
		var y: float = world.ground_height(vc.x, vc.y) + 3.0
		cam.global_position = Vector3(vc.x - 26.0, y + 4.0, vc.y - 26.0)
		cam.look_at(Vector3(vc.x, y + 2.0, vc.y), Vector3.UP)
	else:
		var vc2 := _nearest_village(world, player.global_position)
		var y2: float = world.ground_height(vc2.x, vc2.y)
		cam.global_position = Vector3(vc2.x + 46.0, y2 + 40.0, vc2.y + 46.0)
		cam.look_at(Vector3(vc2.x, y2 + 3.0, vc2.y), Vector3.UP)

	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := get_root().get_viewport().get_texture().get_image()
	img.save_png(out)
	print("SHOT_SAVED ", out)
	quit()


func _nearest_village(world: Node, p: Vector3) -> Vector2:
	var planner = world.get("_planner")
	if planner == null:
		return Vector2(p.x, p.z)
	var best := Vector2(p.x, p.z)
	var bd := 1e18
	for v: Dictionary in planner.villages:
		var c: Vector2 = v["center"]
		var d := c.distance_to(Vector2(p.x, p.z))
		if d < bd:
			bd = d
			best = c
	return best


func _nearest_mounted(world: Node, p: Vector3) -> Vector3:
	var sm = world.get_node_or_null("Structures")
	if sm == null:
		return p
	var best := p
	var bd := 1e18
	for i in sm._active:
		var e: Dictionary = sm._entries[i]
		var path: String = e["scene"]
		# Prefere um prédio de verdade (não uma árvore).
		if not ("building" in path or "wall" in path or "tent" in path):
			continue
		var pos: Vector3 = e["pos"]
		var d := pos.distance_to(p)
		if d < bd:
			bd = d
			best = pos
	return best


func _nearest_building(world: Node, p: Vector3) -> Dictionary:
	var planner = world.get("_planner")
	if planner == null:
		return {"pos": p}
	var vc := _nearest_village(world, p)
	var best: Dictionary = {}
	var bd := 1e18
	for v: Dictionary in planner.villages:
		if (v["center"] as Vector2).distance_to(vc) > 1.0:
			continue
		for b: Dictionary in v["buildings"]:
			var bp: Vector3 = b["pos"]
			var d := bp.distance_to(p)
			if d < bd:
				bd = d
				best = b
	return best if not best.is_empty() else {"pos": p}

