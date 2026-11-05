extends Node3D

## Item na mão do jogador.
##
## A espada e a tocha são presas ao OSSO da mão direita (`RightHand`) do esqueleto
## do personagem, com `BoneAttachment3D`. Assim elas seguem a mão em todas as
## animações (andar, correr, pular) e ficam bem na mão, não atrás do braço.
##
## A tocha tem luz real (OmniLight3D). "Colocar" larga uma tocha acesa no chão.

var inventory: Node = null
var world: Node = null

var _attachment: BoneAttachment3D
var _sword: Node3D
var _torch: Node3D
var _torch_light: OmniLight3D
var _held_id := ""


func _ready() -> void:
	_build_attachment()
	_build_sword()
	_build_torch()


## Acha o Skeleton3D do modelo e cria uma ligação ao osso da mão direita.
func _build_attachment() -> void:
	var player := get_parent()
	var skel := _find_skeleton(player)
	if skel == null:
		push_warning("HandItem: sem Skeleton3D, o item fica preso ao nó raiz.")
		return
	var bone := skel.find_bone("RightHand")
	if bone < 0:
		bone = skel.find_bone("LeftHand")
	if bone < 0:
		push_warning("HandItem: sem osso de mão no esqueleto.")
		return
	_attachment = BoneAttachment3D.new()
	_attachment.bone_name = skel.get_bone_name(bone)
	skel.add_child(_attachment)


func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var found := _find_skeleton(c)
		if found:
			return found
	return null


## Onde os itens são pendurados (osso da mão, ou o próprio Hand).
func _holder() -> Node3D:
	return _attachment if _attachment else self


func _mat(c: Color, metal := 0.0, rough := 0.6, emis := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	if emis > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emis
	return m


func _build_sword() -> void:
	_sword = Node3D.new()
	_sword.name = "HeldSword"
	# Lâmina (afilada): um prisma fino e comprido.
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.045, 0.78, 0.012)
	blade.mesh = bm
	blade.material_override = _mat(Color(0.82, 0.86, 0.93), 0.85, 0.28)
	blade.position = Vector3(0, 0.52, 0)
	_sword.add_child(blade)
	# Ponta.
	var tip := MeshInstance3D.new()
	var tm := PrismMesh.new()
	tm.size = Vector3(0.045, 0.12, 0.012)
	tip.mesh = tm
	tip.material_override = blade.material_override
	tip.position = Vector3(0, 0.97, 0)
	_sword.add_child(tip)
	# Guarda.
	var guard := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.26, 0.045, 0.045)
	guard.mesh = gm
	guard.material_override = _mat(Color(0.55, 0.42, 0.22), 0.5, 0.5)
	guard.position = Vector3(0, 0.11, 0)
	_sword.add_child(guard)
	# Punho.
	var grip := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.028
	rm.bottom_radius = 0.03
	rm.height = 0.17
	grip.mesh = rm
	grip.material_override = _mat(Color(0.30, 0.20, 0.12), 0.0, 0.85)
	grip.position = Vector3(0, 0.02, 0)
	_sword.add_child(grip)
	# Pomo.
	var pommel := MeshInstance3D.new()
	var pm := SphereMesh.new()
	pm.radius = 0.035
	pm.height = 0.07
	pommel.mesh = pm
	pommel.material_override = _mat(Color(0.55, 0.42, 0.22), 0.6, 0.4)
	pommel.position = Vector3(0, -0.07, 0)
	_sword.add_child(pommel)
	# Aponta para frente a partir da mão.
	_sword.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-95)), Vector3(0.02, 0.02, 0.02))
	_sword.visible = false
	_holder().add_child(_sword)


func _build_torch() -> void:
	_torch = Node3D.new()
	_torch.name = "HeldTorch"
	var stick := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.022
	sm.bottom_radius = 0.03
	sm.height = 0.46
	stick.mesh = sm
	stick.material_override = _mat(Color(0.34, 0.22, 0.12), 0.0, 0.9)
	stick.position = Vector3(0, 0.23, 0)
	_torch.add_child(stick)
	# Embrulho na ponta (onde pega fogo).
	var wrap := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 0.038
	wm.bottom_radius = 0.032
	wm.height = 0.10
	wrap.mesh = wm
	wrap.material_override = _mat(Color(0.20, 0.14, 0.09), 0.0, 0.95)
	wrap.position = Vector3(0, 0.47, 0)
	_torch.add_child(wrap)
	var flame := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.07
	fm.height = 0.16
	flame.mesh = fm
	flame.material_override = _mat(Color(1.0, 0.68, 0.22), 0.0, 0.4, 3.5)
	flame.position = Vector3(0, 0.55, 0)
	_torch.add_child(flame)
	_torch_light = OmniLight3D.new()
	_torch_light.light_color = Color(1.0, 0.76, 0.45)
	_torch_light.light_energy = 2.4
	_torch_light.omni_range = 15.0
	_torch_light.shadow_enabled = false
	_torch_light.position = Vector3(0, 0.55, 0)
	_torch.add_child(_torch_light)
	# Segura em pé, na mão.
	_torch.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-95)), Vector3(0.02, 0.0, 0.0))
	_torch.visible = false
	_holder().add_child(_torch)


func set_inventory(inv: Node) -> void:
	inventory = inv
	if inventory and not inventory.changed.is_connected(_refresh):
		inventory.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var held := ""
	if inventory:
		var item = inventory.held_item()
		if item is Dictionary and item.get("id", "") != "":
			held = item["id"]
	_held_id = held
	if _sword:
		_sword.visible = held == "sword"
	if _torch:
		_torch.visible = held == "torch"
	if _torch_light:
		_torch_light.visible = held == "torch"


func torch_lit() -> bool:
	return _held_id == "torch" and _torch_light != null and _torch_light.visible


## Larga a tocha no chão em frente ao jogador (com luz própria). Some da mão.
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


func _spawn_ground_torch(pos: Vector3) -> void:
	var t := Node3D.new()
	t.name = "GroundTorch"
	var stick := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.03
	sm.bottom_radius = 0.045
	sm.height = 0.85
	stick.mesh = sm
	stick.material_override = _mat(Color(0.34, 0.22, 0.12), 0.0, 0.9)
	stick.position = Vector3(0, 0.42, 0)
	t.add_child(stick)
	var flame := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.10
	fm.height = 0.22
	flame.mesh = fm
	flame.material_override = _mat(Color(1.0, 0.68, 0.22), 0.0, 0.4, 3.8)
	flame.position = Vector3(0, 0.92, 0)
	t.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.76, 0.45)
	light.light_energy = 2.8
	light.omni_range = 17.0
	light.shadow_enabled = false
	light.position = Vector3(0, 0.95, 0)
	t.add_child(light)
	var parent := world.get_parent() if world else get_tree().current_scene
	parent.add_child(t)
	t.global_position = pos
