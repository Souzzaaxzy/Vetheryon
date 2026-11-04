extends Node3D
class_name Terrain

## Terreno procedural do Vetheryon.
##
## Sólido de verdade: a malha é fechada (superfície + paredes laterais + fundo),
## o material é renderizado dos dois lados (cull_disabled) e há um "bedrock"
## cúbico de colisão sob o mapa. Assim não aparece mais o azul do céu por baixo.
##
## Também há uma área reta (plateau) reservada para a vila.

@export var size: float = 360.0
@export var resolution: int = 360
@export var height_scale: float = 20.0
@export var noise_frequency: float = 0.0038
@export var seed: int = 20261104
@export var bedrock_depth: float = 60.0
@export var village_center: Vector2 = Vector2(60.0, -60.0)
@export var village_radius: float = 26.0

var _noise: FastNoiseLite


func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = noise_frequency
	_noise.seed = seed
	_noise.fractal_octaves = 5
	_build()


## Altura do terreno em (x, z). Achata a área da vila para um plateau reto.
func height_at(x: float, z: float) -> float:
	var h := _noise.get_noise_2d(x, z) * height_scale
	var d := Vector2(x, z).distance_to(village_center)
	if d < village_radius:
		# Interpola suavemente para a altura do centro da vila.
		var flat := _noise.get_noise_2d(village_center.x, village_center.y) * height_scale
		var t := smoothstep(village_radius * 0.65, village_radius, d)
		h = lerp(flat, h, t)
	return h


func _build() -> void:
	var step := size / float(resolution)
	var half := size * 0.5

	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	# --- superfície ---
	for iz in range(resolution + 1):
		for ix in range(resolution + 1):
			var x := -half + ix * step
			var z := -half + iz * step
			var y := height_at(x, z)
			verts.append(Vector3(x, y, z))
			normals.append(_normal_at(x, z, step))
			colors.append(_color_for_height(y))

	var row := resolution + 1
	for iz in range(resolution):
		for ix in range(resolution):
			var a := iz * row + ix
			var b := a + 1
			var c := a + row
			var d := c + 1
			indices.append_array([a, c, b, b, c, d])

	# --- paredes laterais + fundo (malha fechada => 100% sólida) ---
	var bottom := -bedrock_depth
	_add_skirt(verts, normals, colors, indices, resolution, step, half, bottom)
	_add_bottom(verts, normals, colors, indices, half, bottom)

	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _make_material())

	var mi := MeshInstance3D.new()
	mi.name = "TerrainMesh"
	mi.mesh = mesh
	add_child(mi)

	_build_collision(resolution, step, half)


func _add_skirt(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, resolution: int, step: float, half: float, bottom: float) -> void:
	var rock := Color(0.30, 0.28, 0.26)
	# Para cada uma das 4 bordas, cria uma faixa vertical ligando a superfície ao fundo.
	var edges := [
		{"x": true, "fixed": -half},  # borda -X
		{"x": true, "fixed": half},   # borda +X
		{"x": false, "fixed": -half}, # borda -Z
		{"x": false, "fixed": half},  # borda +Z
	]
	for e in edges:
		var base: int = verts.size()
		for i in range(resolution + 1):
			var t: float = -half + i * step
			var x: float = e.fixed if e.x else t
			var z: float = t if e.x else e.fixed
			var y := height_at(x, z)
			verts.append(Vector3(x, y, z))
			normals.append(Vector3.UP)
			colors.append(rock)
		for i in range(resolution + 1):
			var t: float = -half + i * step
			var x: float = e.fixed if e.x else t
			var z: float = t if e.x else e.fixed
			verts.append(Vector3(x, bottom, z))
			normals.append(Vector3.UP)
			colors.append(rock)
		for i in range(resolution):
			var a: int = base + i
			var b: int = base + i + 1
			var c: int = base + (resolution + 1) + i
			var d: int = base + (resolution + 1) + i + 1
			indices.append_array([a, c, b, b, c, d])


func _add_bottom(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, half: float, bottom: float) -> void:
	var base: int = verts.size()
	var rock := Color(0.26, 0.24, 0.22)
	verts.append(Vector3(-half, bottom, -half))
	verts.append(Vector3(half, bottom, -half))
	verts.append(Vector3(half, bottom, half))
	verts.append(Vector3(-half, bottom, half))
	for _i in range(4):
		normals.append(Vector3.DOWN)
		colors.append(rock)
	indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])


func _build_collision(resolution: int, step: float, half: float) -> void:
	# Colisão por malha (ConcavePolygonShape3D) da superfície — sólida e exata.
	var verts := PackedVector3Array()
	for iz in range(resolution + 1):
		for ix in range(resolution + 1):
			var x := -half + ix * step
			var z := -half + iz * step
			verts.append(Vector3(x, height_at(x, z), z))
	var row := resolution + 1
	var faces := PackedVector3Array()
	for iz in range(resolution):
		for ix in range(resolution):
			var a := iz * row + ix
			var b := a + 1
			var c := a + row
			var d := c + 1
			faces.append(verts[a])
			faces.append(verts[c])
			faces.append(verts[b])
			faces.append(verts[b])
			faces.append(verts[c])
			faces.append(verts[d])

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true

	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)

	# Bedrock: caixa sólida gigante sob o terreno, garante que nada atravesse.
	var box := BoxShape3D.new()
	box.size = Vector3(size, 40.0, size)
	var box_col := CollisionShape3D.new()
	box_col.shape = box
	box_col.position = Vector3(0, -20.0 - height_scale, 0)
	body.add_child(box_col)


func _normal_at(x: float, z: float, step: float) -> Vector3:
	var hx := height_at(x + step, z) - height_at(x - step, z)
	var hz := height_at(x, z + step) - height_at(x, z - step)
	return Vector3(-hx, 2.0 * step, -hz).normalized()


func _color_for_height(y: float) -> Color:
	var t := inverse_lerp(-height_scale, height_scale, y)
	if t < 0.30:
		return Color(0.76, 0.70, 0.48)
	elif t < 0.62:
		return Color(0.32, 0.52, 0.24)
	elif t < 0.82:
		return Color(0.42, 0.40, 0.38)
	else:
		return Color(0.92, 0.94, 0.97)


func _make_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.metallic = 0.0
	# Renderiza os dois lados: nunca se vê "através" do chão.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
