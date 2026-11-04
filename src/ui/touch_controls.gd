extends CanvasLayer

## Controles touchscreen para Android: joystick virtual (esquerda) e botões
## de ação (direita). Construídos em código para não depender de assets.
## No desktop os controles ficam visíveis apenas para depuração; o teclado funciona.

@export var player_path: NodePath

@onready var _player: Player = get_node_or_null(player_path)

var _joystick: Control
var _knob: Control
var _base_radius: float = 90.0
var _touch_index: int = -1
var _origin: Vector2
var _output: Vector2 = Vector2.ZERO


func _ready() -> void:
	_build()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_joystick = Control.new()
	_joystick.custom_minimum_size = Vector2(_base_radius * 2, _base_radius * 2)
	_joystick.size = _joystick.custom_minimum_size
	_joystick.position = Vector2(60, 0)
	_joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_joystick.position = Vector2(60, -_base_radius * 2 - 60)
	_joystick.mouse_filter = Control.MOUSE_FILTER_STOP
	_joystick.draw.connect(_draw_joystick)
	root.add_child(_joystick)

	_knob = Control.new()
	_knob.custom_minimum_size = Vector2(56, 56)
	_knob.size = _knob.custom_minimum_size
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_knob)

	_add_button(root, "PULAR", Vector2(-150, -170), func(): if _player: _player.wants_jump = true)
	_add_button(root, "CORRER", Vector2(-150, -90), func(): if _player: _player.wants_run = not _player.wants_run)
	_add_button(root, "CÂM", Vector2(-150, -250), func(): if _player: _player.camera_rig.toggle_mode())


func _add_button(root: Control, label: String, offset: Vector2, action: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(96, 56)
	b.size = b.custom_minimum_size
	b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.position = offset
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(action)
	root.add_child(b)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1 and _in_joystick(event.position):
			_touch_index = event.index
			_origin = _joystick.global_position + _joystick.size * 0.5
			_update_knob(event.position)
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			_output = Vector2.ZERO
			_knob.position = _origin - _knob.size * 0.5
			_apply()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_knob(event.position)


func _in_joystick(pos: Vector2) -> bool:
	return _joystick.get_global_rect().grow(40).has_point(pos)


func _update_knob(pos: Vector2) -> void:
	var delta := pos - _origin
	if delta.length() > _base_radius:
		delta = delta.normalized() * _base_radius
	_knob.position = _origin + delta - _knob.size * 0.5
	_output = delta / _base_radius
	_apply()


func _apply() -> void:
	if _player:
		_player.set_move_input(_output)


func _draw_joystick() -> void:
	var c := _joystick.size * 0.5
	_joystick.draw_circle(c, _base_radius, Color(1, 1, 1, 0.12))
	_joystick.draw_arc(c, _base_radius, 0, TAU, 48, Color(1, 1, 1, 0.35), 2.0)
