extends Polygon2D

@export var width: float = 300.0
@export var height: float = 70.0
@export var segments: int = 100

func _ready():
	var poly = []
	var uvs = []
	
	for i in range(segments + 1):
		var x = i * width / segments
		poly.append(Vector2(x, 0))
		uvs.append(Vector2(float(i) / segments, 0))

	for i in range(segments, -1, -1):
		var x = i * width / segments
		poly.append(Vector2(x, height))
		uvs.append(Vector2(float(i) / segments, 1))

	polygon = poly
	uv = uvs

	position = -Vector2(width / 2, height / 2)
