extends Node

## Ciclo de dia e noite + o visual do mundo (Environment).
##
## Controla o `Sun` (DirectionalLight3D, com SOMBRA) e monta um `Environment` com
## tonemap ACES, glow, névoa com altura (neblina rente ao chão) e exposição. O céu
## é procedural (sol, lua, estrelas) e as cores acompanham a hora.
##
## O renderizador é o Mobile: ele não tem SSAO/SSIL/SSR/fog volumétrico, então o
## realismo vem de sombra, tonemap, névoa e reflexo do céu — o que o Mobile faz.

## Duração de um dia completo (segundos). 0 ou menos = parado.
@export var day_length: float = 240.0
## Hora inicial: 0 = meia-noite, 0.25 = amanhecer, 0.5 = meio-dia, 0.75 = anoitecer.
@export var start_time: float = 0.28

var _time := 0.0   # 0..1
var _sun: DirectionalLight3D
var _env: WorldEnvironment
var _sky_mat: ShaderMaterial
var _light_energy := 1.0
var _moon: DirectionalLight3D


func _ready() -> void:
	_time = start_time
	var main := get_parent()
	_sun = main.get_node_or_null("Sun") as DirectionalLight3D
	_env = main.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if _sun:
		_light_energy = _sun.light_energy
		# Sombra real: é o que dá volume ao mundo (o Mobile suporta).
		_sun.shadow_enabled = true
		_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		_sun.directional_shadow_max_distance = 120.0
		_sun.shadow_bias = 0.05
		_sun.shadow_normal_bias = 1.5
		_sun.light_angular_distance = 0.6
	if _env:
		# Monta um Environment NOVO (não mexe no da cena: alterar o sub-recurso em
		# memória não estava valendo, e o céu ficava preto).
		var env := Environment.new()
		env.background_mode = Environment.BG_SKY
		_sky_mat = ShaderMaterial.new()
		_sky_mat.shader = load("res://src/world/sky.gdshader")
		var sky := Sky.new()
		sky.sky_material = _sky_mat
		sky.radiance_size = Sky.RADIANCE_SIZE_128
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.55
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		# Tonemap ACES: contraste de filme, tira o "cara de desenho".
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.tonemap_exposure = 1.0
		env.tonemap_white = 6.0
		# Glow discreto no sol e nas chamas.
		env.glow_enabled = true
		env.glow_intensity = 0.5
		env.glow_bloom = 0.05
		env.glow_hdr_threshold = 1.1
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
		# Névoa com altura: a neblina fica rente ao chão e some acima.
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_light_color = Color(0.62, 0.68, 0.78)
		env.fog_light_energy = 1.0
		env.fog_density = 0.0009
		env.fog_height = 5.0
		env.fog_height_density = 0.35
		env.fog_depth_begin = 60.0
		env.fog_depth_end = 600.0
		env.fog_depth_curve = 1.4
		env.fog_aerial_perspective = 0.3
		env.fog_sky_affect = 0.0   # a neblina não cobre o céu (senão fica cinza)
		# Ajuste leve: um pouco menos de saturação, contraste um pouco maior.
		env.adjustment_enabled = true
		env.adjustment_saturation = 0.92
		env.adjustment_contrast = 1.06
		_env.environment = env
	# Lua: uma segunda luz fraca, para a noite não ficar preta.
	_moon = DirectionalLight3D.new()
	_moon.name = "Moon"
	_moon.light_color = Color(0.62, 0.70, 0.95)
	_moon.light_energy = 0.0
	_moon.shadow_enabled = false
	main.add_child.call_deferred(_moon)
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
		_sun.light_energy = _light_energy * clampf(sun_dir.y * 3.0 + 0.15, 0.0, 1.0)

	if _moon:
		_moon.look_at_from_position(-sun_dir * 100.0, Vector3.ZERO, Vector3.UP)
		# A lua só acende quando o sol está abaixo do horizonte.
		_moon.light_energy = clampf(-sun_dir.y * 2.2, 0.0, 0.35)

	if _sky_mat:
		_sky_mat.set_shader_parameter("sun_dir", sun_dir)
		_sky_mat.set_shader_parameter("moon_dir", -sun_dir)
		_sky_mat.set_shader_parameter("day", day)

	if _env and _env.environment:
		var env := _env.environment
		# Neblina: clara de dia, escura à noite.
		env.fog_light_color = Color(0.62, 0.68, 0.78).lerp(Color(0.05, 0.07, 0.14), 1.0 - day)
		env.ambient_light_energy = lerpf(0.18, 0.55, day)
