class_name InteriorBuilder
extends RefCounted

## Constrói o INTERIOR de um prédio: piso, paredes com vão de porta, teto e móveis.
##
## Os modelos do KayKit são cascas fechadas (a casa é um bloco sólido), então não
## dá para entrar nelas. Aqui montamos uma sala dentro do volume do prédio.
##
## Tudo é calculado em FRAÇÕES do tamanho do prédio (não em metros): a malha cozida
## fica em unidades nativas do modelo e a escala só é aplicada na instância, então
## o interior acompanha automaticamente o tamanho final de cada prédio.

const WOOD := Color(0.42, 0.29, 0.18)
const WOOD_DARK := Color(0.30, 0.20, 0.12)
const PLASTER := Color(0.80, 0.76, 0.67)
const CLOTH := Color(0.55, 0.22, 0.20)

var _st := SurfaceTool.new()


## `size` é o volume da sala (unidades nativas do modelo).
static func build(size: Vector3, seed_val: int) -> Dictionary:
	var b := InteriorBuilder.new()
	b._st.begin(Mesh.PRIMITIVE_TRIANGLES)
	b._room(size)
	b._furniture(size, seed_val)
	var mesh: ArrayMesh = b._st.commit()
	return {"mesh": mesh, "size": size}


func _tri(a: Vector3, b: Vector3, c: Vector3) -> void:
	_st.add_vertex(a); _st.add_vertex(b); _st.add_vertex(c)


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(a, b, c)
	_tri(a, c, d)


## Caixa fechada (para móveis).
func _box(center: Vector3, size: Vector3) -> void:
	var h := size * 0.5
	var p := [
		center + Vector3(-h.x, -h.y, -h.z), center + Vector3(h.x, -h.y, -h.z),
		center + Vector3(h.x, h.y, -h.z), center + Vector3(-h.x, h.y, -h.z),
		center + Vector3(-h.x, -h.y, h.z), center + Vector3(h.x, -h.y, h.z),
		center + Vector3(h.x, h.y, h.z), center + Vector3(-h.x, h.y, h.z),
	]
	var faces := [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5]]
	for f: Array in faces:
		_quad(p[f[0]], p[f[1]], p[f[2]], p[f[3]])


func _room(size: Vector3) -> void:
	var w := size.x
	var h := size.y
	var d := size.z
	# Chão e teto.
	_st.set_color(WOOD)
	_quad(Vector3(-w * 0.5, 0.0, -d * 0.5), Vector3(-w * 0.5, 0.0, d * 0.5),
		Vector3(w * 0.5, 0.0, d * 0.5), Vector3(w * 0.5, 0.0, -d * 0.5))
	_st.set_color(WOOD_DARK)
	_quad(Vector3(-w * 0.5, h, -d * 0.5), Vector3(w * 0.5, h, -d * 0.5),
		Vector3(w * 0.5, h, d * 0.5), Vector3(-w * 0.5, h, d * 0.5))
	_st.set_color(PLASTER)
	# Parede do fundo (-Z).
	_quad(Vector3(-w * 0.5, 0, -d * 0.5), Vector3(-w * 0.5, h, -d * 0.5),
		Vector3(w * 0.5, h, -d * 0.5), Vector3(w * 0.5, 0, -d * 0.5))
	# Parede da frente (+Z), com o vão da porta no meio.
	var dw := w * 0.30
	var dh := h * 0.62
	var x0 := -dw * 0.5
	var x1 := dw * 0.5
	_quad(Vector3(-w * 0.5, 0, d * 0.5), Vector3(-w * 0.5, h, d * 0.5),
		Vector3(x0, h, d * 0.5), Vector3(x0, 0, d * 0.5))
	_quad(Vector3(x1, 0, d * 0.5), Vector3(x1, h, d * 0.5),
		Vector3(w * 0.5, h, d * 0.5), Vector3(w * 0.5, 0, d * 0.5))
	_quad(Vector3(x0, dh, d * 0.5), Vector3(x0, h, d * 0.5),
		Vector3(x1, h, d * 0.5), Vector3(x1, dh, d * 0.5))
	# Paredes laterais.
	_quad(Vector3(-w * 0.5, 0, -d * 0.5), Vector3(-w * 0.5, 0, d * 0.5),
		Vector3(-w * 0.5, h, d * 0.5), Vector3(-w * 0.5, h, -d * 0.5))
	_quad(Vector3(w * 0.5, 0, d * 0.5), Vector3(w * 0.5, 0, -d * 0.5),
		Vector3(w * 0.5, h, -d * 0.5), Vector3(w * 0.5, h, d * 0.5))


func _furniture(size: Vector3, seed_val: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var w := size.x
	var d := size.z
	var h := size.y
	var s := minf(w, d)   # referência de escala interna
	# Mesa + bancos.
	_st.set_color(WOOD_DARK)
	var mx := -w * 0.16
	var mz := -d * 0.14
	var tw := s * 0.42
	var td := s * 0.30
	_box(Vector3(mx, h * 0.44, mz), Vector3(tw, h * 0.07, td))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(Vector3(mx + sx * tw * 0.4, h * 0.22, mz + sz * td * 0.4),
				Vector3(s * 0.05, h * 0.44, s * 0.05))
	for i in 2:
		var bx := mx + (1.0 if i == 0 else -1.0) * tw * 0.72
		_box(Vector3(bx, h * 0.26, mz), Vector3(s * 0.30, h * 0.06, s * 0.22))
		_box(Vector3(bx, h * 0.13, mz), Vector3(s * 0.24, h * 0.26, s * 0.16))
	# Barril no canto.
	if rng.randf() < 0.75:
		_st.set_color(WOOD)
		_box(Vector3(w * 0.30, h * 0.22, -d * 0.30), Vector3(s * 0.22, h * 0.44, s * 0.22))
	# Cama num canto.
	if rng.randf() < 0.7:
		_st.set_color(CLOTH)
		_box(Vector3(w * 0.28, h * 0.16, d * 0.26), Vector3(s * 0.5, h * 0.22, s * 0.9))
		_st.set_color(PLASTER)
		_box(Vector3(w * 0.28 - s * 0.2, h * 0.3, d * 0.26 - s * 0.38), Vector3(s * 0.18, h * 0.12, s * 0.18))
