extends Node3D
class_name Terrain

## Terreno procedural da fatia vertical.
## Gera uma malha a partir de ruído (FastNoiseLite), com cores por altitude
## (areia -> grama -> rocha -> neve) via vertex colors, e colisão correspondente.
## Não depende de texturas: o "look" vem da geometria + cor, evitando cara de PNG.

@export var size: float = 320.0
@export var resolution: int = 320
@export var height_scale: float = 22.0
@export var noise_frequency: float = 0.004
@export var seed: int = 20261104

var _noise: FastNoiseLite


func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = noise_frequency
	_noise.seed = seed
	_noise.fractal_octaves = 5
	_build()


func height_at(x: float, z: float) -> float:
	return _noise.get_noise_2d(x, z) * height_scale


func _build() -> void:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var step := size / float(resolution)
	var half := size * 0.5

	for iz in range(resolution + 1):
		for ix in range(resolution + 1):
			var x := -half + ix * step
			var z := -half + iz * step
			var y := height_at(x, z)
			verts.append(Vector3(x, y, z))
			uvs.append(Vector2(ix / float(resolution), iz / float(resolution)))
			normals.append(_normal_at(x, z, step))
			colors.append(_color_for_height(y))

	for iz in range(resolution):
		for ix in range(resolution):
			var a := iz * (resolution + 1) + ix
			var b := a + 1
			var c := a + (resolution + 1)
			var d := c + 1
			indices.append_array([a, c, b, b, c, d])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _make_material())

	var mi := MeshInstance3D.new()
	mi.name = "TerrainMesh"
	mi.mesh = mesh
	add_child(mi)

	var shape := HeightMapShape3D.new()
	shape.map_width = resolution + 1
	shape.map_depth = resolution + 1
	var heights := PackedFloat32Array()
	heights.resize((resolution + 1) * (resolution + 1))
	for iz in range(resolution + 1):
		for ix in range(resolution + 1):
			var x := -half + ix * step
			var z := -half + iz * step
			heights[iz * (resolution + 1) + ix] = height_at(x, z)
	shape.map_data = heights

	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)


func _normal_at(x: float, z: float, step: float) -> Vector3:
	# Central differences over the height field.
	var hx := height_at(x + step, z) - height_at(x - step, z)
	var hz := height_at(x, z + step) - height_at(x, z - step)
	return Vector3(-hx, 2.0 * step, -hz).normalized()


func _color_for_height(y: float) -> Color:
	var t := inverse_lerp(-height_scale, height_scale, y)
	if t < 0.30:
		return Color(0.76, 0.70, 0.48)   # areia / margem
	elif t < 0.62:
		return Color(0.32, 0.52, 0.24)   # grama
	elif t < 0.82:
		return Color(0.42, 0.40, 0.38)   # rocha
	else:
		return Color(0.92, 0.94, 0.97)   # neve


func _make_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.metallic = 0.0
	return mat
