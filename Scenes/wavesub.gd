extends MeshInstance2D

@export var width: float = 300.0
@export var height: float = 100.0
@export var segments: int = 100

func _ready():
	var mesh = ArrayMesh.new()
	var arrays = []
	var vertices = PackedVector2Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	for i in range(segments + 1):
		var x = i * width / segments
		vertices.append(Vector2(x, 0))
		uvs.append(Vector2(i / float(segments), 0))

		vertices.append(Vector2(x, height))
		uvs.append(Vector2(i / float(segments), 1))

	for i in range(segments):
		var idx = i * 2
		indices.append_array([
			idx, idx + 1, idx + 2,
			idx + 2, idx + 1, idx + 3
		])

	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	self.mesh = mesh
	#print(vertices)
	#print("subdivided")
