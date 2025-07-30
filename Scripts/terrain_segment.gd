extends Node2D

@export var segment_length := 700.0
@export var segment_resolution := 60
@export var ahead_distance := 2000.0

@export var terrain_scene: PackedScene = preload("res://Scenes/TerrainSegment.tscn")
@export var coin_scene: PackedScene    = preload("res://Scenes/coin.tscn")
@export var fuel_scene: PackedScene    = preload("res://Scenes/fuel.tscn")
@export var boost_scene: PackedScene   = preload("res://Scenes/boost.tscn")  # Add boost scene

@export var wave_amplitude_range := Vector2(160, 300)
@export var ground_level := 450
@export_range(0.0, 1.0) var coin_spawn_chance := 0.01
@export_range(0.0, 1.0) var fuel_spawn_chance := 0.007
@export_range(0.0, 1.0) var boost_spawn_chance := 0.005
@export_range(0.0, 1.0) var heart_spawn_chance := 0.005  # Add boost spawn chance

@onready var player      := get_tree().get_current_scene().get_node("Cow")
@onready var fuel_bar    := get_node_or_null("UI/fuel/ProgressBar")
@onready var fuel_anim   := get_node_or_null("UI/fuel/AnimationPlayer")
@onready var coin_label  := get_node("UI/coin/Label")
@onready var distance_label  := get_node("UI/Distance/Label")
var last_x := 0.0
var last_y := ground_level
var current_wave_amp := 220.0
var terrain_slope := 0.0
var coins_collected := 0

enum TerrainType { HILLS, FLAT, BUMPY }
var current_terrain := TerrainType.HILLS
var segments_since_change := 0

var noise: FastNoiseLite
var noise_scale_large := 0.001
var noise_scale_small := 0.01

var grass_height := 40.0
var bottom_y_offset := 600.0
var spline_samples := 3
var spawn_check_interval := 15   

var temp_top_points := []
var temp_bottom_points := []
var temp_collision_points := PackedVector2Array()
var temp_terrain_points := PackedVector2Array()
var temp_grass_points := PackedVector2Array()
 
var dirt_texture: Texture2D
var grass_texture: Texture2D
 
var terrain_segments := []
var max_segments := 8   
var delete_distance := 20000.0   
var invisible_wall: StaticBody2D  

func _ready():
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 1.0
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.5
	
	dirt_texture = preload("res://Images/Terrain/DirtBG.png")
	grass_texture = preload("res://Images/Terrain/Grass.png")
 
	temp_top_points.resize(segment_resolution + 1)
	temp_bottom_points.resize(segment_resolution + 1)
 
	_create_invisible_wall()

func _process(_delta):
	if not player:
		return
	var target_x = player.global_position.x + ahead_distance
	while last_x < target_x:
		_generate_segment()
 
	_update_invisible_wall()
	_cleanup_old_terrain()

func _generate_segment():
	segments_since_change += 1
	if segments_since_change >= 8:
		current_terrain = randi() % 3
		segments_since_change = 0

	_update_terrain_parameters()
	
	var segment_width = segment_length / segment_resolution
	var spawn_positions := []
	
	temp_top_points.clear()
	temp_collision_points.clear()
	temp_terrain_points.clear()
	temp_grass_points.clear()

	_generate_terrain_points(segment_width, spawn_positions)
	
	_apply_light_smoothing()
	
	_create_optimized_polygons()
	
	var segment = _create_terrain_segment()
	if not segment:
		return
	
	terrain_segments.append({
		"node": segment,
		"start_x": last_x,
		"end_x": last_x + segment_length
	})
		
	add_child(segment)
	
	_spawn_collectibles(spawn_positions)
	
	last_x += segment_length

func _update_terrain_parameters():
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

func _generate_terrain_points(segment_width: float, spawn_positions: Array):
	var smoothing_factor := 0.7
	
	for i in range(segment_resolution + 1):
		var x = last_x + i * segment_width
		
		var noise_large = noise.get_noise_1d(x * noise_scale_large)
		var noise_small = noise.get_noise_1d(x * noise_scale_small)
		var y = noise_large * current_wave_amp + noise_small * 20 + ground_level + (i * terrain_slope)
		
		if i == 0:
			y = last_y
		else:
			y = last_y * smoothing_factor + y * (1.0 - smoothing_factor)
		
		last_y = y
		temp_top_points.append(Vector2(x, y))
		
		if i % spawn_check_interval == 0 and randf() < 0.5:
			spawn_positions.append(Vector2(x, y - randf_range(60, 100)))

func _apply_light_smoothing():
	if temp_top_points.size() < 3:
		return
		
	for i in range(1, temp_top_points.size() - 1):
		var prev = temp_top_points[i - 1]
		var curr = temp_top_points[i]
		var next = temp_top_points[i + 1]
		
		temp_top_points[i].y = (prev.y + curr.y * 2.0 + next.y) * 0.25

func _create_optimized_polygons():
	var bottom_y = ground_level + bottom_y_offset
	
	var point_count = temp_top_points.size()
	temp_collision_points.resize(point_count * 2)
	temp_terrain_points.resize(point_count * 2)
	temp_grass_points.resize(point_count * 2)
	
	for i in range(point_count):
		temp_collision_points[i] = temp_top_points[i]
		temp_collision_points[point_count * 2 - 1 - i] = Vector2(temp_top_points[i].x, bottom_y)
	
	for i in range(point_count):
		var point = temp_top_points[i]
		if i == 0:
			point.x -= 2
		elif i == point_count - 1:
			point.x += 2
			
		temp_terrain_points[i] = point
		temp_terrain_points[point_count * 2 - 1 - i] = Vector2(point.x, bottom_y)
	
	for i in range(point_count):
		var top_point = temp_top_points[i]
		temp_grass_points[i] = Vector2(top_point.x, top_point.y - grass_height)
		temp_grass_points[point_count * 2 - 1 - i] = top_point

func _create_terrain_segment() -> Node2D:
	var segment = terrain_scene.instantiate()
	var poly = segment.get_node_or_null("CollisionPolygon2D")
	if not poly:
		push_error("Missing CollisionPolygon2D in terrain scene")
		segment.queue_free()
		return null
	
	poly.polygon = temp_collision_points
	
	var terrain_polygon = Polygon2D.new()
	terrain_polygon.polygon = temp_terrain_points
	terrain_polygon.texture = dirt_texture
	terrain_polygon.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	terrain_polygon.z_index = 0
	segment.add_child(terrain_polygon)
	
	var grass_polygon = Polygon2D.new()
	grass_polygon.polygon = temp_grass_points
	grass_polygon.texture = grass_texture
	grass_polygon.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	grass_polygon.texture_scale = Vector2(1.0, 50.0)
	grass_polygon.z_index = 1
	segment.add_child(grass_polygon)
	
	return segment

func _spawn_collectibles(spawn_positions: Array):
	for pos in spawn_positions:
		var r = randf()
		var grass_pos = Vector2(pos.x, pos.y - grass_height)
		
		if r < fuel_spawn_chance:
			var fuel = fuel_scene.instantiate()
			fuel.global_position = grass_pos
			add_child(fuel)
		elif r < fuel_spawn_chance + boost_spawn_chance:
			var boost = boost_scene.instantiate()
			boost.global_position = grass_pos
			add_child(boost)
		elif r < fuel_spawn_chance + boost_spawn_chance + coin_spawn_chance:
			var coin = coin_scene.instantiate()
			coin.global_position = grass_pos
			add_child(coin)
		elif r < fuel_spawn_chance + heart_spawn_chance + 0.01:
			var heart = preload("res://HeartPickup.tscn").instantiate()
			heart.position = grass_pos 
			add_child(heart)
			heart.connect("picked_up", Callable($Cow, "revive"))


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
func update_distance_UI(value: float):
	if distance_label:
		distance_label.text = str(value/1000)

func _create_invisible_wall():
	invisible_wall = StaticBody2D.new()
	var collision_shape = CollisionShape2D.new()
	var rectangle_shape = RectangleShape2D.new()
	rectangle_shape.size = Vector2(50, 2000)
	collision_shape.shape = rectangle_shape
	invisible_wall.add_child(collision_shape)
	invisible_wall.position = Vector2(-1000, 0)
	add_child(invisible_wall)

func _update_invisible_wall():
	if invisible_wall and player:
		var wall_x = player.global_position.x - delete_distance + 500
		invisible_wall.global_position.x = wall_x

func _cleanup_old_terrain():
	if not player:
		return
		
	var player_x = player.global_position.x
	var cleanup_threshold = player_x - delete_distance
	
	var segments_to_remove = []
	for i in range(terrain_segments.size()):
		var segment_data = terrain_segments[i]
		if segment_data.end_x < cleanup_threshold:
			segments_to_remove.append(i)
	
	for i in range(segments_to_remove.size() - 1, -1, -1):
		var index = segments_to_remove[i]
		var segment_data = terrain_segments[index]
		
		for child in segment_data.node.get_children():
			child.queue_free()
		segment_data.node.queue_free()
		terrain_segments.remove_at(index)
	
	_cleanup_orphaned_collectibles(cleanup_threshold)

func _cleanup_orphaned_collectibles(cleanup_x: float):
	var children_to_remove = []
	for child in get_children():
		if child.has_method("get_global_position"):
			if child.global_position.x < cleanup_x:
				if child.scene_file_path == coin_scene.resource_path or child.scene_file_path == fuel_scene.resource_path or child.scene_file_path == boost_scene.resource_path:  # Include boost cleanup
					children_to_remove.append(child)
	
	for child in children_to_remove:
		child.queue_free()
