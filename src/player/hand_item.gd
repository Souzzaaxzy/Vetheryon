extends Node3D

## Item na mão do jogador: mostra a espada ou a tocha e cuida da luz da tocha.
##
## A tocha tem luz real (OmniLight3D) enquanto está na mão. "Quebrar/colocar"
## (o mesmo botão da mochila + o botão de colocar) larga uma tocha no chão, com
## a própria luz, e some da mão.

## Nó onde os itens da mão são pendurados (o modelo do personagem).
@export var hand_path: NodePath

var inventory: Node = null
var world: Node = null

var _sword: Node3D
var _torch: Node3D
var _torch_light: OmniLight3D
var _held_id := ""


func _ready() -> void:
	_build_models()


func set_inventory(inv: Node) -> void:
	inventory = inv
	if inventory and not inventory.changed.is_connected(_refresh):
		inventory.changed.connect(_refresh)
	_refresh()


func _build_models() -> void:
	# --- Espada (lâmina, guarda, punho) ---
	_sword = Node3D.new()
	_sword.name = "HeldSword"
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.62, 0.012)
	blade.mesh = bm
	blade.material_override = _metal(Color(0.78, 0.82, 0.9))
	blade.position = Vector3(0, 0.42, 0)
	_sword.add_child(blade)
	var guard := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.20, 0.035, 0.035)
	guard.mesh = gm
	guard.material_override = _metal(Color(0.55, 0.42, 0.22))
	guard.position = Vector3(0, 0.10, 0)
	_sword.add_child(guard)
	var grip := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(0.05, 0.14, 0.05)
	grip.mesh = rm
	grip.material_override = _metal(Color(0.32, 0.22, 0.13))
	grip.position = Vector3(0, 0.02, 0)
	_sword.add_child(grip)
	# Segura na mão: um pouco à frente e de lado.
	_sword.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-20)), Vector3(0.22, 0.55, 0.05))
	_sword.visible = false
	add_child(_sword)

	# --- Tocha (cabo + chama + luz) ---
	_torch = Node3D.new()
	_torch.name = "HeldTorch"
	var stick := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.02
	sm.bottom_radius = 0.025
	sm.height = 0.42
	stick.mesh = sm
	stick.material_override = _metal(Color(0.36, 0.24, 0.13))
	stick.position = Vector3(0, 0.21, 0)
	_torch.add_child(stick)
	var flame := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.06
	fm.height = 0.12
	flame.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(1.0, 0.72, 0.25)
	fmat.emission_enabled = true
	fmat.emission = Color(1.0, 0.62, 0.20)
	fmat.emission_energy_multiplier = 3.0
	flame.material_override = fmat
	flame.position = Vector3(0, 0.46, 0)
	_torch.add_child(flame)
	_torch_light = OmniLight3D.new()
	_torch_light.light_color = Color(1.0, 0.75, 0.42)
	_torch_light.light_energy = 2.2
	_torch_light.omni_range = 14.0
	_torch_light.shadow_enabled = false
	_torch_light.position = Vector3(0, 0.46, 0)
	_torch.add_child(_torch_light)
	_torch.transform = Transform3D(Basis(), Vector3(0.26, 0.35, 0.10))
	_torch.visible = false
	add_child(_torch)


func _metal(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.55
	m.metallic = 0.3
	return m


func _refresh() -> void:
	var held := ""
	if inventory:
		var item = inventory.held_item()
		if item is Dictionary and item.get("id", "") != "":
			held = item["id"]
	_held_id = held
	var show_sword := held == "sword"
	var show_torch := held == "torch"
	if _sword:
		_sword.visible = show_sword
	if _torch:
		_torch.visible = show_torch
	if _torch_light:
		_torch_light.visible = show_torch


## A tocha na mão está acesa?
func torch_lit() -> bool:
	return _held_id == "torch" and _torch_light != null and _torch_light.visible


## Larga a tocha no chão em frente ao jogador (com a própria luz). Devolve true se
## largou (tinha uma tocha na mão).
func place_torch(player: Node3D) -> bool:
	if _held_id != "torch" or inventory == null:
		return false
	if inventory.remove_item("torch", 1) <= 0:
		return false
	var fwd := -player.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var pos := player.global_position + fwd * 1.6 + Vector3(0, 0.1, 0)
	if world and world.has_method("ground_height"):
		pos.y = world.ground_height(pos.x, pos.z) + 0.05
	_spawn_ground_torch(pos)
	_refresh()
	return true


## Cria uma tocha acesa no chão.
func _spawn_ground_torch(pos: Vector3) -> void:
	var t := Node3D.new()
	t.name = "GroundTorch"
	var stick := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.03
	sm.bottom_radius = 0.04
	sm.height = 0.8
	stick.mesh = sm
	stick.material_override = _metal(Color(0.34, 0.22, 0.12))
	stick.position = Vector3(0, 0.4, 0)
	t.add_child(stick)
	var flame := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.10
	fm.height = 0.20
	flame.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(1.0, 0.72, 0.25)
	fmat.emission_enabled = true
	fmat.emission = Color(1.0, 0.62, 0.20)
	fmat.emission_energy_multiplier = 3.5
	flame.material_override = fmat
	flame.position = Vector3(0, 0.86, 0)
	t.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.42)
	light.light_energy = 2.6
	light.omni_range = 16.0
	light.shadow_enabled = false
	light.position = Vector3(0, 0.9, 0)
	t.add_child(light)
	t.global_position = pos
	# Fica no mundo (não no chunk), então não some ao andar.
	var parent := world.get_parent() if world else get_tree().current_scene
	parent.add_child(t)
