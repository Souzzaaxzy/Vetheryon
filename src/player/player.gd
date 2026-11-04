extends CharacterBody3D
class_name Player

## Vetheryon player controller — modelo humano animado (hero.glb).
## Movimento relativo à câmera, pulo, gravidade e uma máquina de estados simples
## que escolhe entre as animações Idle/Walk/Run/Jump.

@export var walk_speed: float = 3.4
@export var run_speed: float = 7.0
@export var jump_velocity: float = 5.2
@export var acceleration: float = 12.0
@export var rotation_speed: float = 12.0

@onready var camera_rig: CameraRig = $CameraRig
@onready var model: Node3D = $Model

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var move_input: Vector2 = Vector2.ZERO
var wants_jump: bool = false
var wants_run: bool = false

var _anim: AnimationPlayer
var _current: String = ""


func _ready() -> void:
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
		camera_rig.apply_look(event.relative)


func _physics_process(delta: float) -> void:
	_read_keyboard()

	if not is_on_floor():
		velocity.y -= gravity * delta

	if wants_jump and is_on_floor():
		velocity.y = jump_velocity
	wants_jump = false

	var speed := run_speed if wants_run else walk_speed
	var basis: Basis = camera_rig.get_yaw_basis()
	var direction: Vector3 = (basis * Vector3(move_input.x, 0.0, move_input.y)).normalized()
	var target: Vector3 = direction * speed * move_input.length()

	velocity.x = move_toward(velocity.x, target.x, acceleration * delta * speed)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta * speed)

	if direction.length_squared() > 0.001:
		var target_angle := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)

	move_and_slide()
	_update_animation()


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
	if Input.is_action_just_pressed("toggle_camera"):
		camera_rig.toggle_mode()


func set_move_input(value: Vector2) -> void:
	move_input = value


func apply_look(relative: Vector2) -> void:
	camera_rig.apply_look(relative)
