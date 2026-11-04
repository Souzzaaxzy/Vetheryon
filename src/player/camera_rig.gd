extends Node3D
class_name CameraRig

## Câmera orbital de terceira pessoa, INDEPENDENTE do corpo do jogador.
##
## O nó desta câmera NÃO é filho do Player (senão, ao girar o personagem para
## andar, a câmera giraria junto e mudaria a direção de movimento — loop de
## realimentação que deixava os controles "bugados"). Em vez disso, este rig
## segue a posição do jogador (não a rotação) e mantém yaw/pitch próprios.
##
## O movimento é relativo ao yaw da câmera, como o usuário pediu:
## empurrar o analógico para cima => o personagem vai para onde a câmera aponta.

const FIRST_PERSON := 0
const THIRD_PERSON := 1

@export var sensitivity: float = 0.0032
@export var pitch_min: float = -1.15
@export var pitch_max: float = 0.75
@export var third_person_distance: float = 4.2
@export var first_person_height: float = 1.65
@export var third_person_height: float = 1.55

@export var target_path: NodePath

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var mode: int = THIRD_PERSON
var _pitch: float = -0.28
var _yaw: float = 0.0
var _target: Node3D


func _ready() -> void:
	_target = get_node_or_null(target_path)
	if _target == null and get_parent() is Node3D:
		_target = get_parent()
	_apply_mode()
	_update_transform()


func _process(_delta: float) -> void:
	_update_transform()


func _update_transform() -> void:
	if _target == null:
		return
	# Segue apenas a POSIÇÃO do alvo; a orientação é toda da câmera.
	global_position = _target.global_position + Vector3(0, _height(), 0)
	rotation = Vector3(_pitch, _yaw, 0)


func _height() -> float:
	return first_person_height if mode == FIRST_PERSON else third_person_height


## Chamado pelo input touch/mouse: gira a câmera.
func apply_look(relative: Vector2) -> void:
	_yaw -= relative.x * sensitivity
	_pitch = clampf(_pitch - relative.y * sensitivity, pitch_min, pitch_max)


## Base usada para mover o personagem: apenas o yaw da câmera.
func get_yaw_basis() -> Basis:
	return Basis(Vector3.UP, _yaw)


func toggle_mode() -> void:
	mode = THIRD_PERSON if mode == FIRST_PERSON else FIRST_PERSON
	_apply_mode()


func _apply_mode() -> void:
	if mode == FIRST_PERSON:
		# Câmera na altura dos olhos, um pouco à frente do rosto.
		spring_arm.spring_length = 0.0
		camera.position = Vector3(0, 0.0, -0.14)
		camera.near = 0.04
	else:
		spring_arm.spring_length = third_person_distance
		camera.position = Vector3(0.55, 0.0, 0.0)
		camera.near = 0.05
