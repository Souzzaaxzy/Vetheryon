extends CharacterBody3D
class_name Player

## Vetheryon player controller — modelo humano animado (hero.glb).
## Movimento relativo ao YAW DA CÂMERA (empurrar o analógico para cima faz o
## personagem ir para onde a câmera aponta). O corpo gira para encarar a direção
## do movimento; a câmera é um nó separado (CameraRig) e não é afetada por isso.

@export var walk_speed: float = 3.6
@export var run_speed: float = 7.0
@export var jump_velocity: float = 3.2
@export var acceleration: float = 12.0
@export var rotation_speed: float = 12.0
@export var camera_rig_path: NodePath
## Levanta o modelo em relação à cápsula. O terreno é facetado (triângulos de 2 m),
## então sem isso o pé fica coplanar com a grama e some; alguns cm o deixam visível.
@export var model_foot_offset: float = 0.04
## Quanto abaixo do terreno o jogador pode ficar antes de ser resgatado (m).
## Pega o caso de cair para fora do mundo quando um chunk ainda não carregou.
@export var void_margin: float = 4.0

@onready var model: Node3D = $Model

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var move_input: Vector2 = Vector2.ZERO
var wants_jump: bool = false
var wants_run: bool = false

var _camera_rig: CameraRig
var _anim: AnimationPlayer
var _current: String = ""
var _world: Node
var _attack_t := 0.0
var _hand: Node3D


func _ready() -> void:
	if model:
		model.position.y = model_foot_offset
	_camera_rig = get_node_or_null(camera_rig_path)
	if _camera_rig == null:
		_camera_rig = get_tree().get_first_node_in_group("camera_rig") as CameraRig
	_world = get_tree().get_first_node_in_group("world")
	_hand = get_node_or_null("Hand")
	_anim = _find_animation_player(model)
	if _anim:
		_play("Idle")


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if _camera_rig:
			_camera_rig.apply_look(event.relative)


func _physics_process(delta: float) -> void:
	_read_keyboard()

	if not is_on_floor():
		velocity.y -= gravity * delta

	if wants_jump and is_on_floor():
		velocity.y = jump_velocity
	wants_jump = false

	var speed := run_speed if wants_run else walk_speed
	var direction := Vector3.ZERO
	if _camera_rig:
		var basis: Basis = _camera_rig.get_yaw_basis()
		direction = (basis * Vector3(move_input.x, 0.0, move_input.y)).normalized()
	var target: Vector3 = direction * speed * move_input.length()

	velocity.x = move_toward(velocity.x, target.x, acceleration * delta * speed)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta * speed)

	if direction.length_squared() > 0.001:
		var target_angle := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)

	move_and_slide()
	_check_void()
	_update_animation()
	if _attack_t > 0.0:
		_attack_t = maxf(0.0, _attack_t - delta)


## Ataca com o item na mão (a espada balança; só é "ataque" se for arma).
func attack() -> void:
	if _attack_t > 0.0:
		return
	_attack_t = 0.45
	var item = null
	if _hand and _hand.inventory:
		item = _hand.inventory.held_item()
	var id: String = item.get("id", "") if item is Dictionary else ""
	if id == "sword":
		_swing()


func _swing() -> void:
	if _hand == null or _hand._sword == null:
		return
	var sw: Node3D = _hand._sword
	var tw := create_tween()
	tw.tween_property(sw, "rotation:x", deg_to_rad(-110.0), 0.12)
	tw.tween_property(sw, "rotation:x", 0.0, 0.22)


## É a arma na mão? (para o HUD saber)
func held_is_sword() -> bool:
	if _hand == null or _hand.inventory == null:
		return false
	var item = _hand.inventory.held_item()
	return item is Dictionary and item.get("id", "") == "sword"


## Se o jogador caiu abaixo do terreno (chunk não carregou, buraco no mundo),
## devolve ele para a altura do chão no ponto atual. Roda todo frame, então
## basta o chunk montar para ele pousar de verdade.
func _check_void() -> void:
	if _world == null or not _world.has_method("ground_height"):
		return
	var p := global_position
	var gy: float = _world.ground_height(p.x, p.z)
	if p.y < gy - void_margin:
		global_position = Vector3(p.x, gy + 2.0, p.z)
		velocity = Vector3.ZERO


func _update_animation() -> void:
	if not _anim:
		return
	if not is_on_floor():
		_play("Jump")
		return
	var planar := Vector2(velocity.x, velocity.z).length()
	if planar < 0.3:
		_play("Idle")
	elif planar < (walk_speed + run_speed) * 0.5:
		_play("Walk")
	else:
		_play("Run")


func _play(anim_name: String) -> void:
	if _current == anim_name or not _anim:
		return
	if not _anim.has_animation(anim_name):
		return
	_current = anim_name
	var anim := _anim.get_animation(anim_name)
	if anim:
		anim.loop_mode = Animation.LOOP_NONE if anim_name == "Jump" else Animation.LOOP_LINEAR
	_anim.play(anim_name)


func _read_keyboard() -> void:
	var kb := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	if kb.length_squared() > 0.0:
		move_input = kb.limit_length(1.0)
	wants_run = wants_run or Input.is_action_pressed("run")
	if Input.is_action_just_pressed("jump"):
		wants_jump = true
	if Input.is_action_just_pressed("toggle_camera") and _camera_rig:
		_camera_rig.toggle_mode()


func set_move_input(value: Vector2) -> void:
	move_input = value


func apply_look(relative: Vector2) -> void:
	if _camera_rig:
		_camera_rig.apply_look(relative)


func toggle_camera_mode() -> void:
	if _camera_rig:
		_camera_rig.toggle_mode()
		# Em 1ª pessoa, esconde o modelo (senão a cabeça fica na frente da câmera).
		if model:
			model.visible = _camera_rig.mode != CameraRig.FIRST_PERSON
