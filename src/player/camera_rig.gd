extends Node3D
class_name CameraRig

## Alterna entre primeira e terceira pessoa (decisão confirmada do design).
## Primeira pessoa: câmera no "olho" do jogador.
## Terceira pessoa: câmera recuada, com spring arm para não atravessar o mundo.

const FIRST_PERSON := 0
const THIRD_PERSON := 1

@export var sensitivity: float = 0.0025
@export var pitch_min: float = -1.2
@export var pitch_max: float = 0.9

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var mode: int = THIRD_PERSON
var _pitch: float = -0.32
var _yaw: float = 0.0


func _ready() -> void:
	_apply_mode()


func apply_look(relative: Vector2) -> void:
	_yaw -= relative.x * sensitivity
	_pitch = clampf(_pitch - relative.y * sensitivity, pitch_min, pitch_max)
	rotation.y = _yaw
	rotation.x = _pitch


func get_yaw_basis() -> Basis:
	# Movement basis: only yaw, so looking up/down never tilts the player.
	return Basis(Vector3.UP, _yaw)


func toggle_mode() -> void:
	mode = THIRD_PERSON if mode == FIRST_PERSON else FIRST_PERSON
	_apply_mode()


func _apply_mode() -> void:
	if mode == FIRST_PERSON:
		spring_arm.spring_length = 0.0
		camera.position = Vector3(0, 0.05, 0)
	else:
		spring_arm.spring_length = 3.2
		camera.position = Vector3(0.6, 0.0, 0.0)
