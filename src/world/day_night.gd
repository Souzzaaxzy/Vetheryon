extends Node

## Ciclo de dia e noite: gira o sol e a lua, muda a cor da luz e do céu e
## atualiza o céu procedural (sol de dia, lua e estrelas à noite).
##
## Fica no nó `DayNight` da cena principal e controla o `Sun` (DirectionalLight3D)
## e o `WorldEnvironment`.

## Duração de um dia completo (segundos). 0 ou menos = parado.
@export var day_length: float = 240.0
## Hora inicial: 0 = meia-noite, 0.25 = amanhecer, 0.5 = meio-dia, 0.75 = anoitecer.
@export var start_time: float = 0.28

var _time := 0.0   # 0..1
var _sun: DirectionalLight3D
var _env: WorldEnvironment
var _sky_mat: ShaderMaterial
var _light_energy := 1.0


func _ready() -> void:
	_time = start_time
	var main := get_parent()
	_sun = main.get_node_or_null("Sun") as DirectionalLight3D
	_env = main.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if _sun:
		_light_energy = _sun.light_energy
	if _env:
		# Monta um Environment NOVO (não mexe no da cena: alterar o sub-recurso em
		# memória não estava valendo, e o céu ficava preto).
		var env := Environment.new()
		env.background_mode = Environment.BG_SKY
		_sky_mat = ShaderMaterial.new()
		_sky_mat.shader = load("res://src/world/sky.gdshader")
		var sky := Sky.new()
		sky.sky_material = _sky_mat
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.55
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_white = 4.0
		env.fog_enabled = true
		env.fog_density = 0.0016
		env.fog_sky_affect = 0.0   # a neblina não cobre o céu (senão fica cinza)
		_env.environment = env
	_apply()


func _process(delta: float) -> void:
	if day_length > 0.0:
		_time = fmod(_time + delta / day_length, 1.0)
		_apply()


func _apply() -> void:
	# Ângulo do sol: 0.25 -> nasce no leste, 0.5 -> meio-dia (topo), 0.75 -> oeste.
	var ang := (_time - 0.25) * TAU
	var sun_dir := Vector3(cos(ang), sin(ang), 0.35).normalized()
	var day := clampf(sun_dir.y * 2.0 + 0.15, 0.0, 1.0)

	if _sun:
		_sun.look_at_from_position(sun_dir * 100.0, Vector3.ZERO, Vector3.UP)
		# Ao anoitecer a luz fica mais quente e fraca.
		var warm := clampf(1.0 - absf(sun_dir.y) * 3.0, 0.0, 1.0)
		_sun.light_color = Color(1.0, 0.95 - 0.12 * warm, 0.85 - 0.30 * warm)
		_sun.light_energy = _light_energy * clampf(sun_dir.y * 3.0 + 0.15, 0.06, 1.0)

	if _sky_mat:
		_sky_mat.set_shader_parameter("sun_dir", sun_dir)
		_sky_mat.set_shader_parameter("moon_dir", -sun_dir)
		_sky_mat.set_shader_parameter("day", day)

	if _env and _env.environment:
		var env := _env.environment
		# Neblina: clara de dia, escura à noite.
		env.fog_light_color = Color(0.72, 0.78, 0.85).lerp(Color(0.05, 0.07, 0.14), 1.0 - day)
		env.ambient_light_energy = lerpf(0.18, 0.55, day)
