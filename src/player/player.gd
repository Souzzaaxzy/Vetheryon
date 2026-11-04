extends CharacterBody3D
class_name Player

## Vetheryon player controller — Phase 1 vertical slice.
## Movimento relativo à câmera, pulo e gravidade. Entrada vem do teclado (desktop)
## e do TouchControls (Android). A câmera 1ª/3ª pessoa vive em CameraRig.

@export var walk_speed: float = 5.0
@export var run_speed: float = 8.5
@export var jump_velocity: float = 5.0
@export var acceleration: float = 12.0
@export var rotation_speed: float = 12.0

@onready var camera_rig: CameraRig = $CameraRig

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

# Input state, fed by keyboard and/or the on-screen joystick.
var move_input: Vector2 = Vector2.ZERO
var look_input: Vector2 = Vector2.ZERO
var wants_jump: bool = false
var wants_run: bool = false


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

	# Movement is relative to where the camera looks (horizontal only).
	var basis: Basis = camera_rig.get_yaw_basis()
	var direction: Vector3 = (basis * Vector3(move_input.x, 0.0, move_input.y)).normalized()
	var target: Vector3 = direction * speed * move_input.length()

	velocity.x = move_toward(velocity.x, target.x, acceleration * delta * speed)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta * speed)

	if direction.length_squared() > 0.001:
		var target_angle := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)

	move_and_slide()


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
