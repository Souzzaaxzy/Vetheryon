extends SceneTree

## Testa as vilas: conta construcoes, confere colisao e tira um screenshot aereo
## da vila mais proxima do spawn.

func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node3D = load("res://src/world/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(4.0).timeout
	var ss := main.get_node_or_null("StartScreen")
	if ss:
		ss._enter()
	await create_timer(8.0).timeout

	var world: Node = main.get_node_or_null("World")
	var player: Node3D = main.get_node_or_null("Player")
	print("VILLAGES=", world._planner.villages.size(), " SCATTER=", world._planner.scattered.size())
	var total_b := 0
	for v: Dictionary in world._planner.villages:
		total_b += (v["buildings"] as Array).size()
	print("BUILDINGS total=", total_b)
	if world._planner.villages.size() > 0:
		var v0: Dictionary = world._planner.villages[0]
		print("vila0 center=", v0["center"], " buildings=", (v0["buildings"] as Array).size())

	# Conta nos montados + corpos de estrutura.
	var mounted := 0
	var bodies := 0
	for c in world._chunks.values():
		for ch in c.get_children():
			if ch is Node3D and ch.name.begins_with("Struct_"):
				mounted += 1
			if ch is StaticBody3D and ch.name.begins_with("StructBody_"):
				bodies += 1
	print("MOUNTED structs=", mounted, " struct_bodies=", bodies)

	# Teleporta para a vila 0 e espera os chunks montarem.
	if world._planner.villages.size() > 0:
		var v0: Dictionary = world._planner.villages[0]
		var ctr: Vector2 = v0["center"]
		var lv: float = v0["level"]
		player.global_position = Vector3(ctr.x, lv + 3.0, ctr.y)
		await create_timer(10.0).timeout
		var m2 := 0
		var b2 := 0
		for c in world._chunks.values():
			for ch in c.get_children():
				if ch is Node3D and ch.name.begins_with("Struct_"): m2 += 1
				if ch is StaticBody3D and ch.name.begins_with("StructBody_"): b2 += 1
		print("APOS teleporte: mounted=", m2, " bodies=", b2)
		var cam := Camera3D.new()
		cam.fov = 60.0
		cam.far = 4000.0
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.5, 0.6, 0.7)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.9, 0.93, 0.98)
		env.ambient_light_energy = 1.4
		env.fog_enabled = false
		cam.environment = env
		main.add_child(cam)
		cam.global_position = Vector3(ctr.x + 26, lv + 16, ctr.y + 26)
		cam.look_at(Vector3(ctr.x, lv + 4, ctr.y), Vector3.UP)
		cam.current = true
		await create_timer(0.6).timeout
		root.get_texture().get_image().save_png("/workspace/tools/downloads/village.png")
		print("SHOT village.png")
	quit()
