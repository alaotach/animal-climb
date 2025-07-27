extends Node2D

# === Editable Parameters ===
@export var segment_length := 700.0
@export var segment_resolution := 120
@export var ahead_distance := 2000.0

@export var terrain_scene: PackedScene = preload("res://Scenes/TerrainSegment.tscn")
@export var coin_scene: PackedScene    = preload("res://Scenes/coin.tscn")
@export var fuel_scene: PackedScene    = preload("res://Scenes/fuel.tscn")

@export var wave_amplitude_range := Vector2(160, 300)
@export var ground_level := 450
@export_range(0.0, 1.0) var coin_spawn_chance := 0.01
@export_range(0.0, 1.0) var fuel_spawn_chance := 0.002

# === Scene References ===
@onready var player      := get_tree().get_current_scene().get_node("Cow")
@onready var fuel_bar    := get_node_or_null("UI/fuel/ProgressBar")
@onready var fuel_anim   := get_node_or_null("UI/fuel/AnimationPlayer")
@onready var coin_label  := get_node("UI/coin/Label")

# === Internal State ===
var last_x := 0.0
var last_y := ground_level
var current_wave_amp := 220.0
var terrain_slope := 0.0
var coins_collected := 0

# Terrain Biomes
enum TerrainType { HILLS, FLAT, BUMPY }
var current_terrain := TerrainType.HILLS
var segments_since_change := 0

# Noise
var noise: FastNoiseLite
var noise_scale_large := 0.001
var noise_scale_small := 0.01

func _ready():
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 1.0
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.5

func _process(_delta):
	if not player:
		return
	var target_x = player.global_position.x + ahead_distance
	while last_x < target_x:
		_generate_segment()

func _generate_segment():
	segments_since_change += 1
	if segments_since_change >= 8:
		current_terrain = randi() % 3
		segments_since_change = 0

	match current_terrain:
		TerrainType.HILLS:
			current_wave_amp = randf_range(wave_amplitude_range.x, wave_amplitude_range.y)
			terrain_slope = randf_range(-0.05, 0.05)
		TerrainType.FLAT:
			current_wave_amp = randf_range(20, 40)
			terrain_slope = randf_range(-0.01, 0.01)
		TerrainType.BUMPY:
			current_wave_amp = randf_range(100, 180)
			terrain_slope = randf_range(-0.08, 0.08)

	var segment_width = segment_length / segment_resolution
	var top_points = []
	var spawn_positions := []

	# Top edge: generate and smooth points
	for i in range(segment_resolution + 1):
		var x = last_x + i * segment_width
		var base_hill    = noise.get_noise_1d(x * noise_scale_large) * current_wave_amp
		var detail_bumps = noise.get_noise_1d(x * noise_scale_small) * 20
		var y = base_hill + detail_bumps + ground_level + (i * terrain_slope)
		if i == 0:
			y = last_y
		else:
			y = last_y * 0.85 + y * 0.15
		last_y = y
		top_points.append(Vector2(x, y))

		if i % 10 == 0 and randf() < 0.5:
			spawn_positions.append(Vector2(x, y - randf_range(60, 100)))

	# Spline smooth (Catmull-Rom, robust at segment joins)
	top_points = _catmull_rom_spline(top_points, 5)

	# --- Robust bottom edge generation ---
	var bottom_y = ground_level + 600
	var bottom_points = []
	for point in top_points:
		bottom_points.append(Vector2(point.x, bottom_y))
	# Reverse bottom points for correct polygon winding
	var reversed_bottom = bottom_points.duplicate()
	reversed_bottom.reverse()
	var points = PackedVector2Array()
	for p in top_points:
		points.append(p)
	for p in reversed_bottom:
		points.append(p)

	# Instantiate and configure segment
	var segment = terrain_scene.instantiate()
	var poly = segment.get_node_or_null("CollisionPolygon2D")
	if not poly:
		push_error("Missing CollisionPolygon2D in terrain scene")
		return
	poly.polygon = points

	# Setup visual sprite region
	var ground_sprite = segment.get_node_or_null("GroundSprite")
	if ground_sprite:
		var min_x = top_points[0].x
		var max_x = top_points[top_points.size() - 1].x
		ground_sprite.region_enabled = true
		ground_sprite.region_rect = Rect2(min_x, 0, max_x - min_x, bottom_y)
		ground_sprite.position = Vector2(min_x, 0)
		ground_sprite.z_index = -1

	add_child(segment)

	# Spawn collectibles
	for pos in spawn_positions:
		var r = randf()
		if r < fuel_spawn_chance:
			var fuel = fuel_scene.instantiate()
			fuel.global_position = pos
			add_child(fuel)
		elif r < fuel_spawn_chance + coin_spawn_chance:
			var coin = coin_scene.instantiate()
			coin.global_position = pos
			add_child(coin)

	last_x += segment_length

func _catmull_rom_spline(points: Array, samples_per_segment: int) -> Array:
	if points.size() < 4:
		return points
	var result = []
	var padded = [points[0]] + points + [points[points.size()-1]]
	for i in range(padded.size() - 3):
		var p0 = padded[i]
		var p1 = padded[i+1]
		var p2 = padded[i+2]
		var p3 = padded[i+3]
		for t in range(samples_per_segment):
			var s = float(t) / samples_per_segment
			var a1 = p1
			var a2 = 0.5 * (-p0 + p2)
			var a3 = 0.5 * (2*p0 - 5*p1 + 4*p2 - p3)
			var a4 = 0.5 * (-p0 + 3*p1 - 3*p2 + p3)
			var x = a1.x + a2.x*s + a3.x*s*s + a4.x*s*s*s
			var y = a1.y + a2.y*s + a3.y*s*s + a4.y*s*s*s
			result.append(Vector2(x, y))
	return result

func add_coins(amount: int):
	coins_collected += amount
	if coin_label:
		coin_label.text = str(coins_collected)

func update_fuel_UI(value: float):
	if fuel_bar:
		fuel_bar.value = value
	if fuel_anim:
		if value < 20:
			fuel_anim.play("alarm")
		else:
			fuel_anim.play("idle")
