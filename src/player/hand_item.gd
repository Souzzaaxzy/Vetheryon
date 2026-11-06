extends Node3D

## Item na mão do jogador (espada/tocha).
##
## A lição das tentativas anteriores: NÃO reposicionar o item a cada frame com
## `global_position`/`global_basis`. Fazer isso "pega" a mão num instante, mas o
## esqueleto é atualizado DEPOIS do `_physics_process`, então o item ficava um
## frame atrás — parado parecia certo, mas andando/correndo ele ficava para trás
## ("voando"). E o osso da mão está girado no repouso, então herdar a rotação do
## osso deixa a lâmina para baixo.
##
## A solução é um `BoneAttachment3D` no osso `RightHand`: o motor o mantém colado
## à mão, na ordem certa, e o item é filho dele. A orientação é corrigida UMA vez,
## com um offset de rotação calculado a partir do repouso do osso — assim o item
## acompanha qualquer animação (Idle/Walk/Run/Jump/Punch) sem atraso.

## Para onde a lâmina da espada aponta no ESPAÇO DO JOGADOR (para cima e à frente).
const SWORD_DIR := Vector3(0.0, 1.0, -0.30)
## Direção da haste da tocha (praticamente em pé).
const TORCH_DIR := Vector3(0.0, 1.0, -0.10)
## Posição do item em relação à mão, no espaço do jogador.
const HAND_OFFSET := Vector3(0.02, 0.02, 0.02)

var inventory: Node = null
var world: Node = null

var _attachment: BoneAttachment3D
var _sword: Node3D
var _torch: Node3D
var _torch_light: OmniLight3D
var _held_id := ""
var _swing_t := 0.0
var _player: Node3D


func _ready() -> void:
	_player = get_parent() as Node3D
	# Roda depois do esqueleto (que está em outro ramo da árvore), senão lemos a
	# base do osso com um frame de atraso e o item treme.
	process_priority = 100
	_build_attachment()
	_build_sword()
	_build_torch()
	_refresh()


## Cria a ligação ao osso da mão direita.
func _build_attachment() -> void:
	var skel := _find_skeleton(get_parent())
	if skel == null:
		push_warning("HandItem: sem Skeleton3D.")
		return
	var bone := skel.find_bone("RightHand")
	if bone < 0:
		bone = skel.find_bone("LeftHand")
	if bone < 0:
		push_warning("HandItem: sem osso de mão.")
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


func _process(_delta: float) -> void:
	# A base do osso MUDA a cada pose (Idle/Walk/Run têm mãos diferentes), então a
	# orientação é recalculada todo frame. A POSIÇÃO continua sendo do
	# BoneAttachment3D — é ele que impede o item de "ficar para trás" ao andar.
	if _attachment != null and _player != null:
		_update_pose()


## Dá ao item a orientação desejada, resolvida na pose ATUAL do osso.
func _update_pose() -> void:
	var ab := _attachment.global_basis
	if absf(ab.determinant()) < 0.000001:
		return
	var pb := _player.global_basis
	var inv := ab.inverse()
	if _sword and _sword.visible:
		var want := pb * _aim_local_basis(SWORD_DIR)
		var b := inv * want
		if _swing_t > 0.0:
			var k := sin(_swing_t * PI)
			b = b.rotated((inv * (pb * Vector3.RIGHT)).normalized(), deg_to_rad(-115.0 * k))
		_sword.transform = Transform3D(b, HAND_OFFSET)
	if _torch and _torch.visible:
		_torch.transform = Transform3D(inv * (pb * _aim_local_basis(TORCH_DIR)), HAND_OFFSET)


func _holder() -> Node3D:
	return _attachment if _attachment else self


## Base do item no espaço do jogador: eixo Y apontando para `dir`.
func _aim_local_basis(dir: Vector3) -> Basis:
	var up := dir.normalized()
	var fwd := Vector3(0.0, 0.0, -1.0)
	var right := fwd.cross(up)
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	right = right.normalized()
	var back := right.cross(up).normalized()
	return Basis(right, up, back)



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
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.85, 0.014)
	blade.mesh = bm
	blade.material_override = _mat(Color(0.82, 0.86, 0.93), 0.85, 0.28)
	blade.position = Vector3(0, 0.56, 0)
	_sword.add_child(blade)
	var tip := MeshInstance3D.new()
	var tm := PrismMesh.new()
	tm.size = Vector3(0.05, 0.13, 0.014)
	tip.mesh = tm
	tip.material_override = blade.material_override
	tip.position = Vector3(0, 1.05, 0)
	_sword.add_child(tip)
	var guard := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.28, 0.05, 0.05)
	guard.mesh = gm
	guard.material_override = _mat(Color(0.55, 0.42, 0.22), 0.5, 0.5)
	guard.position = Vector3(0, 0.12, 0)
	_sword.add_child(guard)
	var grip := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.028
	rm.bottom_radius = 0.03
	rm.height = 0.18
	grip.mesh = rm
	grip.material_override = _mat(Color(0.30, 0.20, 0.12), 0.0, 0.85)
	grip.position = Vector3(0, 0.02, 0)
	_sword.add_child(grip)
	var pommel := MeshInstance3D.new()
	var pm := SphereMesh.new()
	pm.radius = 0.036
	pm.height = 0.072
	pommel.mesh = pm
	pommel.material_override = _mat(Color(0.55, 0.42, 0.22), 0.6, 0.4)
	pommel.position = Vector3(0, -0.08, 0)
	_sword.add_child(pommel)
	_sword.visible = false
	_holder().add_child(_sword)


func _build_torch() -> void:
	_torch = Node3D.new()
	_torch.name = "HeldTorch"
	var stick := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.022
	sm.bottom_radius = 0.03
	sm.height = 0.48
	stick.mesh = sm
	stick.material_override = _mat(Color(0.34, 0.22, 0.12), 0.0, 0.9)
	stick.position = Vector3(0, 0.24, 0)
	_torch.add_child(stick)
	var wrap := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 0.04
	wm.bottom_radius = 0.034
	wm.height = 0.11
	wrap.mesh = wm
	wrap.material_override = _mat(Color(0.20, 0.14, 0.09), 0.0, 0.95)
	wrap.position = Vector3(0, 0.49, 0)
	_torch.add_child(wrap)
	var flame := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.075
	fm.height = 0.17
	flame.mesh = fm
	flame.material_override = _mat(Color(1.0, 0.68, 0.22), 0.0, 0.4, 3.5)
	flame.position = Vector3(0, 0.58, 0)
	_torch.add_child(flame)
	_torch_light = OmniLight3D.new()
	_torch_light.light_color = Color(1.0, 0.76, 0.45)
	_torch_light.light_energy = 2.4
	_torch_light.omni_range = 15.0
	_torch_light.shadow_enabled = false
	_torch_light.position = Vector3(0, 0.58, 0)
	_torch.add_child(_torch_light)
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
