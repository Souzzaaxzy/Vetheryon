extends CanvasLayer

## Controles touchscreen do Vetheryon:
##  - joystick virtual (metade esquerda)  -> move o personagem
##  - arrastar na metade direita da tela  -> gira a câmera
##  - botões de ação (direita)            -> pular / correr / alternar câmera
##
## O joystick é desenhado por código (sem assets). O arrasto da câmera é
## detectado em coordenadas de tela, então funciona em qualquer resolução.

@export var player_path: NodePath

@onready var _player: Player = get_node_or_null(player_path)

const BASE_RADIUS := 95.0
const KNOB_RADIUS := 42.0
const JOY_CENTER_X := 150.0
const JOY_MARGIN_BOTTOM := 150.0

var _base_center: Vector2
var _knob_center: Vector2
var _joystick_touch: int = -1
var _camera_touch: int = -1
var _last_camera_pos: Vector2
var _move_output: Vector2 = Vector2.ZERO

var _buttons: Array[Button] = []
var _canvas: Control
var _visual: Control


func _ready() -> void:
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _build() -> void:
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)

	# Control dedicado ao desenho do joystick (CanvasLayer não tem _draw).
	_visual = Control.new()
	_visual.set_anchors_preset(Control.PRESET_FULL_RECT)
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.draw.connect(_draw_joystick)
	_canvas.add_child(_visual)

	_add_button("PULAR", _on_jump)
	_add_button("CORRER", _on_run)
	_add_button("CÂMERA", _on_camera)


func _add_button(label: String, action: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(112, 60)
	b.size = b.custom_minimum_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(action)
	_canvas.add_child(b)
	_buttons.append(b)


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	_base_center = Vector2(JOY_CENTER_X, size.y - JOY_MARGIN_BOTTOM)
	_knob_center = _base_center

	# Botões empilhados no canto inferior direito.
	var bw := 112.0
	var bh := 60.0
	var gap := 14.0
	var right_x := size.x - bw - 26.0
	var bottom_y := size.y - 26.0
	_buttons[0].position = Vector2(right_x, bottom_y - bh)                 # PULAR
	_buttons[1].position = Vector2(right_x, bottom_y - bh * 2 - gap)       # CORRER
	_buttons[2].position = Vector2(right_x, bottom_y - bh * 3 - gap * 2)   # CÂMERA
	if _visual:
		_visual.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	var half := get_viewport().get_visible_rect().size.x * 0.5
	if event.pressed:
		# Primeiro toque na metade esquerda: assume o joystick.
		if event.position.x < half and _joystick_touch == -1 and _in_joystick_zone(event.position):
			_joystick_touch = event.index
			_base_center = event.position
			_update_knob(event.position)
		elif event.position.x >= half and _camera_touch == -1:
			_camera_touch = event.index
			_last_camera_pos = event.position
	else:
		if event.index == _joystick_touch:
			_joystick_touch = -1
			_move_output = Vector2.ZERO
			_knob_center = _base_center
			_apply_move()
			_visual.queue_redraw()
		elif event.index == _camera_touch:
			_camera_touch = -1


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _joystick_touch:
		_update_knob(event.position)
	elif event.index == _camera_touch:
		var delta := event.position - _last_camera_pos
		_last_camera_pos = event.position
		if _player:
			_player.apply_look(delta)


func _in_joystick_zone(pos: Vector2) -> bool:
	return pos.distance_to(_base_center) < BASE_RADIUS * 2.0


func _update_knob(pos: Vector2) -> void:
	var delta := pos - _base_center
	if delta.length() > BASE_RADIUS:
		delta = delta.normalized() * BASE_RADIUS
	_knob_center = _base_center + delta
	_move_output = delta / BASE_RADIUS
	_apply_move()
	_visual.queue_redraw()


func _apply_move() -> void:
	if _player:
		_player.set_move_input(_move_output)


func _draw_joystick() -> void:
	# Base do joystick
	_visual.draw_circle(_base_center, BASE_RADIUS, Color(1, 1, 1, 0.10))
	_visual.draw_arc(_base_center, BASE_RADIUS, 0, TAU, 64, Color(1, 1, 1, 0.35), 3.0, true)
	# Knob
	_visual.draw_circle(_knob_center, KNOB_RADIUS, Color(0.35, 0.6, 0.95, 0.55))
	_visual.draw_arc(_knob_center, KNOB_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.6), 2.0, true)


func _on_jump() -> void:
	if _player:
		_player.wants_jump = true


func _on_run() -> void:
	if _player:
		_player.wants_run = not _player.wants_run


func _on_camera() -> void:
	if _player:
		_player.toggle_camera_mode()
