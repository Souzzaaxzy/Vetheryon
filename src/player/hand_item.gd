extends Node3D

## Item na mão do jogador (espada/tocha).
##
## O `BoneAttachment3D` no osso `RightHand` dá a POSIÇÃO da mão. A ORIENTAÇÃO do
## item NÃO é herdada do osso: o osso da mão está girado no repouso e o item saía
## de cabeça para baixo (lâmina apontando para o chão). Em vez disso, a cada frame
## o item recebe uma orientação escolhida no espaço do jogador — a lâmina fica para
## cima, a tocha em pé, e o golpe gira em torno do eixo certo.

## Para onde a lâmina da espada aponta (no espaço do jogador): para cima e à frente.
const SWORD_DIR := Vector3(0.0, 1.0, -0.38)
## Direção da haste da tocha (praticamente em pé).
const TORCH_DIR := Vector3(0.0, 1.0, -0.12)
## Deslocamento do item em relação ao osso da mão.
const HAND_OFFSET := Vector3(0.0, 0.02, 0.0)

var inventory: Node = null
var world: Node = null

var _attachment: BoneAttachment3D
var _sword: Node3D
var _torch: Node3D
var _torch_light: OmniLight3D
var _held_id := ""
var _swing_t := 0.0


func _ready() -> void:
	_build_attachment()
	_build_sword()
	_build_torch()
	_refresh()


func _build_attachment() -> void:
	var player := get_parent()
	var skel := _find_skeleton(player)
	if skel == null:
		push_warning("HandItem: sem Skeleton3D; o item fica preso ao nó raiz.")
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


func _physics_process(_delta: float) -> void:
	_follow_hand()


## Põe o item na mão com a orientação escolhida, no espaço do jogador.
func _follow_hand() -> void:
	var item := _active_item()
	var player := get_parent() as Node3D
	if item == null or player == null:
		return
	var origin: Vector3
	if _attachment:
		origin = _attachment.global_position
	else:
		origin = player.global_position + player.global_basis * Vector3(0.35, 1.2, 0.0)
	var dir := SWORD_DIR if _held_id == "sword" else TORCH_DIR
	var basis := _aim_basis(player.global_basis, dir)
	# O golpe gira o item em torno do eixo lateral do jogador (corte de cima).
	if _held_id == "sword" and _swing_t > 0.0:
		basis = basis.rotated(player.global_basis.x, _swing_angle())
	item.global_position = origin + player.global_basis * HAND_OFFSET
	item.global_basis = basis


func _active_item() -> Node3D:
	if _held_id == "sword":
		return _sword
	if _held_id == "torch":
		return _torch
	return null


## Base com o eixo Y apontando para `dir` (no espaço do jogador).
func _aim_basis(player_basis: Basis, dir: Vector3) -> Basis:
	var up := dir.normalized()
	var fwd := Vector3(0.0, 0.0, -1.0)
	var right := fwd.cross(up)
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	right = right.normalized()
	var back := right.cross(up).normalized()
	return player_basis * Basis(right, up, back)


## Curva do corte: sobe (0..0.5) e volta (0.5..1), em torno de -110°.
func _swing_angle() -> float:
	var t := _swing_t
	var k := sin(t * PI) if t <= 0.5 else sin((1.0 - t) * PI)
	return deg_to_rad(-110.0) * k


## Inicia o golpe (chamado por Player.attack()).
func swing() -> void:
	if _held_id != "sword" or _swing_t > 0.0:
		return
	var tw := create_tween()
	tw.tween_method(_set_swing, 0.0, 1.0, 0.34)


func _set_swing(v: float) -> void:
	_swing_t = v if v < 1.0 else 0.0


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
	_sword.visible = false
	add_child(_sword)


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
	_torch.visible = false
	add_child(_torch)


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
