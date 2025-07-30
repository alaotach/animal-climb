extends RigidBody2D

@export var move_speed: float = 2000.0
@export var jump_force: float = -1500.0 
@export var double_jump_force: float = -1000
@export var air_control: float = 0.3
@export var max_jump_height: float = 2.0
@export var auto_step_height: float = 30.0
@export var terrain_smoothing: float = 0.8
@export var stuck_threshold: float = 50.0
@export var ground_proximity_threshold: float = 800.0
@export var rotation_lock_strength: float = 8.0
@export var acceleration: float = 8.0
@export var deceleration: float = 12.0
@export var air_acceleration: float = 4.0
@export var air_deceleration: float = 6.0 
@export var min_flip_sensitivity: float = 2000.0
@export var max_flip_sensitivity: float = 12000.0
@export var flip_speed_threshold: float = 1000.0

@export var backward_limit_distance: float = 5000.0


@export var rainbow_scene: PackedScene
@export var cow: Node2D
@export var spawn_interval := 0.05  
@export var fade_time := 2.0  
@export var trail_smoothing := 0.8  
@export var min_spawn_distance := 0.0  

# Speed boost properties
@export var boost_multiplier: float = 10.0
@export var boost_duration: float = 5.0
var is_boosted: bool = false
var boost_timer: float = 0.0
var original_move_speed: float

# Trick system properties
@export var flip_sensitivity: float = 7000.0
@export var min_airtime_for_bonus: float = 2.5
@export var min_jump_height: float = 200.0
@export var airtime_coin_value: int = 5
@export var flip_coin_value: int = 10
@export var max_airtime_bonus: int = 500000000

var current_airtime: float = 0.0
var total_flips: int = 0
var accumulated_rotation: float = 0.0
var completed_flips: int = 0
var last_angular_velocity: float = 0.0
var current_flip_rotation: float = 0.0
var last_flip_direction: int = 0
var rotation_threshold: float = 2 * PI
var flip_completed: bool = false
var max_height_this_jump: float = 0.0
var jump_start_y: float = 0.0
var was_grounded_last_frame: bool = true
var total_coins_earned: int = 0
var jumps_remaining: int = 2
var max_jumps: int = 2
var near_ground: bool = false

# Game over properties
@export var fall_death_y: float = 2000.0
@export var stuck_death_time: float = 15.0
@export var game_over_delay: float = 3.0
@export var max_respawn_attempts: int = 2

var dead: bool = false
var game_over_triggered: bool = false
var respawn_attempts: int = 0
var last_safe_position: Vector2 = Vector2.ZERO
var stuck_death_timer: float = 0.0
var was_moving_recently: bool = false
var movement_check_timer: float = 0.0

@onready var sprite: AnimatedSprite2D = $Cow
@onready var ground_raycast: RayCast2D = $RayCast2D
@onready var engine_sound = $EngineSound

@export var max_lives := 4
var lives := 2

var settings_infinite_jumps: bool = false
var settings_speed_multiplier: float = 1.0
var settings_acceleration_multiplier: float = 1.0
var settings_jump_height_multiplier: float = 1.0
var settings_air_speed_multiplier: float = 1.0
var settings_flip_sensitivity_multiplier: float = 1.0
var settings_infinite_fuel: bool = false



func revive():
	if lives < max_lives:
		lives += 1
		print("Revived! Lives: ", lives)
		update_lives_ui()

var hearts = [
	get_node("/Level1/UI/Heart/Heart"),
	get_node("/Level1/UI/Heart/Heart2"),
	get_node("/Level1/UI/Heart/Heart3"),
	get_node("/Level1/UI/Heart/Heart4")
]

func update_lives_ui():
	var ui = get_node("/root/Level1/UI/Heart")
	var hearts = ui.get_children()
	
	for i in range(hearts.size()):
		hearts[i].visible = i < lives




var fuel = 100
var move_input = 0.0
var last_ground_position: Vector2  
var stuck_timer: float = 0.0
var last_position: Vector2
var surface_normal: Vector2 = Vector2.UP

var is_grounded: bool = false

var furthest_x_position: float = 0.0
var backward_limit_x: float = 0.0
var starting_x_position: float = 0.0

var game_over_timer: Timer
var spawn_timer := 0.0
var rainbows := []
var last_rainbow_position: Vector2 = Vector2.ZERO
var current_tail_position: Vector2 = Vector2.ZERO
var smoothed_tail_position: Vector2 = Vector2.ZERO

func load_game_settings():
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err == OK:
		settings_infinite_jumps = config.get_value("settings", "infinite_jumps", false)
		settings_speed_multiplier = config.get_value("settings", "speed_multiplier", 1.0)
		settings_acceleration_multiplier = config.get_value("settings", "acceleration_multiplier", 1.0)
		settings_jump_height_multiplier = config.get_value("settings", "jump_height_multiplier", 1.0)
		settings_air_speed_multiplier = config.get_value("settings", "air_speed_multiplier", 1.0)
		settings_flip_sensitivity_multiplier = config.get_value("settings", "flip_sensitivity_multiplier", 1.0)
		settings_infinite_fuel = config.get_value("settings", "infinite_fuel", false)

func apply_settings_modifiers():
	move_speed = 2000.0 * settings_speed_multiplier
	acceleration *= settings_acceleration_multiplier
	deceleration *= settings_acceleration_multiplier
	air_acceleration *= settings_acceleration_multiplier * settings_air_speed_multiplier
	air_deceleration *= settings_acceleration_multiplier * settings_air_speed_multiplier
	jump_force = -1500.0 * settings_jump_height_multiplier
	double_jump_force = -1000.0 * settings_jump_height_multiplier
	min_flip_sensitivity *= settings_flip_sensitivity_multiplier
	max_flip_sensitivity *= settings_flip_sensitivity_multiplier


func _ready() -> void:
	load_game_settings()
	apply_settings_modifiers()

	update_lives_ui()
	get_parent().update_fuel_UI(fuel)
	
	gravity_scale = 1.5
	lock_rotation = false
	
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = false
	sleeping = false
	can_sleep = false
	
	mass = 1.0
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.05
	physics_material_override.bounce = 0.1
	
	contact_monitor = true
	max_contacts_reported = 5
	
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	
	original_move_speed = move_speed
	
	# Setup game over timer
	game_over_timer = Timer.new()
	game_over_timer.wait_time = game_over_delay
	game_over_timer.one_shot = true
	game_over_timer.timeout.connect(func(): get_tree().reload_current_scene())
	add_child(game_over_timer)
	
	if ground_raycast:
		ground_raycast.enabled = true
		
		var collision_shape = $CollisionShape2D
		if collision_shape and collision_shape.shape:
			var shape_height = 0.0
			if collision_shape.shape is RectangleShape2D:
				shape_height = collision_shape.shape.size.y / 2.0
			elif collision_shape.shape is CapsuleShape2D:
				shape_height = collision_shape.shape.height / 2.0
			elif collision_shape.shape is CircleShape2D:
				shape_height = collision_shape.shape.radius
			
			ground_raycast.position = Vector2(0, shape_height)
		else:
			ground_raycast.position = Vector2(0, 25)
		
		ground_raycast.target_position = Vector2(0, 50)
		ground_raycast.collision_mask = 0xFFFFFFFF
		
	last_position = global_position
	furthest_x_position = global_position.x
	starting_x_position = global_position.x
	backward_limit_x = global_position.x - backward_limit_distance
	last_safe_position = global_position
	
	update_tail_position()
	smoothed_tail_position = current_tail_position
	last_rainbow_position = current_tail_position
	
	update_distance_UI()
	update_coins_UI(total_coins_earned)

func update_tail_position():
	var tail_point = cow.get_node_or_null("TailPoint")
	if tail_point:
		current_tail_position = tail_point.global_position
	else:
		var offset_x = -40 if linear_velocity.x >= 0 else 40
		current_tail_position = cow.global_position + Vector2(offset_x, 0)

	
func _process(delta):
	if dead or game_over_triggered:
		return
	
	update_tail_position()
	smoothed_tail_position = smoothed_tail_position.lerp(current_tail_position, trail_smoothing)
	
	spawn_timer += delta
	
	var speed = abs(linear_velocity.x)
	var dynamic_spawn_interval = spawn_interval
	
	if speed > 800:  
		dynamic_spawn_interval = spawn_interval * 0.6
	elif speed < 200:  
		dynamic_spawn_interval = spawn_interval * 1.5
	
	if spawn_timer >= dynamic_spawn_interval:
		var distance_moved = smoothed_tail_position.distance_to(last_rainbow_position)
		if distance_moved >= min_spawn_distance or speed > 1000:  # Always spawn at very high speeds
			spawn_timer = 0.0
			spawn_smooth_rainbow()

		update_rainbows(delta)
	
func spawn_smooth_rainbow():
	if not rainbow_scene:
		return
		
	var rainbow = rainbow_scene.instantiate()
	get_tree().current_scene.add_child(rainbow)
	
	
	rainbow.global_position = smoothed_tail_position
	
	
	var randomness = Vector2(randf_range(-2, 2), randf_range(-1, 1))
	rainbow.global_position += randomness
	
	
	var speed = abs(linear_velocity.x)
	var speed_scale = clamp(speed / 1000.0, 0.6, 1.4)
	rainbow.scale = Vector2(speed_scale, speed_scale)
	
	
	var rainbow_data = {
		"node": rainbow,
		"elapsed": 0.0,
		"initial_scale": rainbow.scale,
		"spawn_position": rainbow.global_position
	}
	
	rainbows.append(rainbow_data)
	last_rainbow_position = smoothed_tail_position
	
	
	if rainbows.size() > 100:
		var oldest = rainbows[0]
		if oldest["node"] and is_instance_valid(oldest["node"]):
			oldest["node"].queue_free()
		rainbows.remove_at(0)

func update_rainbows(delta):
	
	for i in range(rainbows.size() - 1, -1, -1):
		var data = rainbows[i]
		data["elapsed"] += delta
		var t = data["elapsed"] / fade_time
		var node = data["node"]

		if not node or not is_instance_valid(node):
			rainbows.remove_at(i)
			continue

	
		var fade_curve = 1.0 - smoothstep(0.0, 1.0, t)
		node.modulate.a = fade_curve
		
	
		var scale_factor = 1.0 + (1.0 - fade_curve) * 0.1  # Slight growth as it fades
		node.scale = data["initial_scale"] * scale_factor
		
	
		node.global_position.y -= 10 * delta * (1.0 - fade_curve)
		
	
		var mesh = node.get_node_or_null("MeshInstance2D")
		if mesh and mesh.material is ShaderMaterial:
			var mat: ShaderMaterial = mesh.material
			mat.set_shader_parameter("life", fade_curve)
			
	
		if move_input == 0 or dead:
			node.modulate.a *= 0.3  # Extra fade when not moving
		elif is_boosted:
	
			node.modulate = node.modulate * Color(1.2, 1.2, 1.0, 1.0)

	
		if t >= 1.0:
			node.queue_free()
			rainbows.remove_at(i)

func clear_rainbow_trail():
	
	for data in rainbows:
		if data["node"] and is_instance_valid(data["node"]):
			data["node"].queue_free()
	rainbows.clear()
	last_rainbow_position = current_tail_position


func _physics_process(delta: float) -> void:
	
	check_death_conditions(delta)
	
	
	if not dead and not game_over_triggered:
		update_backward_limit()
		enforce_backward_limit()
		check_ground()
		handle_tricks_and_airtime(delta)
		detect_stuck(delta)
		handle_boost(delta)
		handle_input(delta)
		handle_animation()
		apply_terrain_smoothing(delta)
		update_safe_position()
		check_ground_proximity()  
		handle_dynamic_rotation_lock(delta)
		
		if move_input == 1.0:
			var target_pitch = 2.5 if is_boosted else 2.0
			engine_sound.pitch_scale = lerp(engine_sound.pitch_scale, target_pitch, 2 * delta)
			use_fuel(delta)
		else:
			engine_sound.pitch_scale = lerp(engine_sound.pitch_scale, 1.0, 2 * delta)
	else:
		handle_death_state(delta)

func check_death_conditions(delta: float) -> void:
	if dead or game_over_triggered:
		return
	
	if global_position.y > fall_death_y:
		trigger_death("FELL OFF THE WORLD!")
		return
	
	if not settings_infinite_fuel and fuel <= 0:
		trigger_death("OUT OF FUEL!")
		return
	
	check_stuck_death(delta)


func check_stuck_death(delta: float) -> void:
	movement_check_timer += delta
	
	if movement_check_timer >= 0.5:
		var position_change = global_position.distance_to(last_position)
		was_moving_recently = position_change > 20.0
		movement_check_timer = 0.0
	
	if move_input != 0.0 and not was_moving_recently:
		stuck_death_timer += delta
		if stuck_death_timer >= stuck_death_time:
			trigger_death("STUCK FOR TOO LONG!")
			return
	else:
		stuck_death_timer = 0.0


func update_safe_position() -> void:
	if is_grounded and fuel > 20 and abs(linear_velocity.y) < 100:
		if global_position.x > backward_limit_x + 200:
			last_safe_position = global_position


func trigger_death(reason: String = "DIED!") -> void:
	if dead:
		return
		
	print("Death triggered: ", reason)
	dead = true
	
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	

	clear_rainbow_trail()
	
	if respawn_attempts < lives:
		attempt_respawn(reason)
		lives -= 1
		update_lives_ui()
	else:
		trigger_game_over(reason + " - NO MORE RESPAWNS!")


func attempt_respawn(reason: String) -> void:
	respawn_attempts += 1
	print("Attempting respawn #", respawn_attempts, " - Reason: ", reason)
	
	show_respawn_message(reason, respawn_attempts)
	
	await get_tree().create_timer(2.0).timeout
	
	if is_instance_valid(self):
		global_position = last_safe_position
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		
		dead = false
		stuck_timer = 0.0
		stuck_death_timer = 0.0
		
		fuel = max(fuel, 60)
		get_parent().update_fuel_UI(fuel)
		
		update_distance_UI()
		
		if is_boosted:
			end_speed_boost()
		

		update_tail_position()
		smoothed_tail_position = current_tail_position
		last_rainbow_position = current_tail_position
		
		print("Respawned! Attempts remaining: ", lives - respawn_attempts)

func trigger_game_over(reason: String = "GAME OVER!") -> void:
	if game_over_triggered:
		return
		
	print("Game Over: ", reason)
	game_over_triggered = true
	dead = true
	
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	
	show_game_over_screen(reason)
	
	if game_over_timer and game_over_timer.is_stopped():
		game_over_timer.start()
	
	#if trail_line:
		#var tween = create_tween()
		#tween.tween_property(trail_line, "modulate", Color.TRANSPARENT, 1.0)

func show_respawn_message(reason: String, attempt: int) -> void:
	print("=== RESPAWNING ===")
	print("Reason: ", reason)
	print("Attempt: ", attempt, "/", lives)
	print("Respawning in 2 seconds...")
	

	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  
	get_tree().current_scene.add_child(canvas_layer)
	
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.size = get_viewport().size
	overlay.position = Vector2.ZERO
	canvas_layer.add_child(overlay)
	
	
	var container = VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.position = Vector2(get_viewport().size.x/2 - 200, get_viewport().size.y/2 - 100)
	container.size = Vector2(400, 200)
	overlay.add_child(container)
	
	
	var title_label = Label.new()
	title_label.text = "RESPAWNING..."
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.modulate = Color.YELLOW
	container.add_child(title_label)
	
	
	var reason_label = Label.new()
	reason_label.text = reason
	reason_label.add_theme_font_size_override("font_size", 24)
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason_label.modulate = Color.ORANGE
	container.add_child(reason_label)
	
	
	var attempt_label = Label.new()
	attempt_label.text = "Attempt " + str(attempt) + "/" + str(lives)
	attempt_label.add_theme_font_size_override("font_size", 20)
	attempt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attempt_label.modulate = Color.WHITE
	container.add_child(attempt_label)
	
	
	var countdown_label = Label.new()
	countdown_label.add_theme_font_size_override("font_size", 32)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.modulate = Color.CYAN
	container.add_child(countdown_label)
	
	
	for i in range(2, 0, -1):
		countdown_label.text = "Respawning in " + str(i) + "..."
	
		var tween = create_tween()
		tween.tween_property(countdown_label, "scale", Vector2(1.2, 1.2), 0.3)
		tween.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.3)
		await get_tree().create_timer(1.0).timeout
	
	countdown_label.text = "RESPAWNING NOW!"
	countdown_label.modulate = Color.GREEN
	
	
	var flash_tween = create_tween()
	flash_tween.tween_property(overlay, "modulate", Color.WHITE, 0.2)
	flash_tween.tween_property(overlay, "modulate", Color.TRANSPARENT, 0.3)
	
	await get_tree().create_timer(0.5).timeout
	
	if canvas_layer and is_instance_valid(canvas_layer):
		canvas_layer.queue_free()

func show_game_over_screen(reason: String) -> void:
	print("=== GAME OVER ===")
	print("Reason: ", reason)
	print("Restarting in ", game_over_delay, " seconds...")
	
	
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  
	get_tree().current_scene.add_child(canvas_layer)
	
	var overlay = ColorRect.new()
	overlay.color = Color(0.1, 0, 0, 0.9) 
	overlay.size = get_viewport().size
	overlay.position = Vector2.ZERO
	canvas_layer.add_child(overlay)
	

	var container = VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.position = Vector2(get_viewport().size.x/2 - 250, get_viewport().size.y/2 - 150)
	container.size = Vector2(500, 300)
	overlay.add_child(container)
	

	var title_label = Label.new()
	title_label.text = "GAME OVER"
	title_label.add_theme_font_size_override("font_size", 64)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.modulate = Color.RED
	container.add_child(title_label)
	

	var title_tween = create_tween()
	title_tween.set_loops()
	title_tween.tween_property(title_label, "scale", Vector2(1.1, 1.1), 0.5)
	title_tween.tween_property(title_label, "scale", Vector2(1.0, 1.0), 0.5)
	

	var reason_label = Label.new()
	reason_label.text = reason
	reason_label.add_theme_font_size_override("font_size", 28)
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason_label.modulate = Color.ORANGE_RED
	reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(reason_label)
	

	var total_distance = int(furthest_x_position - starting_x_position)
	var stats_label = Label.new()
	stats_label.text = "Distance Traveled: " + str(total_distance) + "m\nCoins Earned: " + str(total_coins_earned) + "\nFlips Performed: " + str(total_flips) + "\nRespawns Used: " + str(respawn_attempts) + "/" + str(lives)
	stats_label.add_theme_font_size_override("font_size", 18)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.modulate = Color.GRAY
	container.add_child(stats_label)
	

	var restart_label = Label.new()
	restart_label.add_theme_font_size_override("font_size", 32)
	restart_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_label.modulate = Color.WHITE
	container.add_child(restart_label)
	

	var time_left = int(game_over_delay)
	while time_left > 0:
		restart_label.text = "Restarting in " + str(time_left) + "..."
		

		if time_left <= 1:
			restart_label.modulate = Color.RED
		elif time_left <= 2:
			restart_label.modulate = Color.YELLOW
		

		var pulse_tween = create_tween()
		pulse_tween.tween_property(restart_label, "scale", Vector2(1.3, 1.3), 0.2)
		pulse_tween.tween_property(restart_label, "scale", Vector2(1.0, 1.0), 0.3)
		
		await get_tree().create_timer(1.0).timeout
		time_left -= 1
	
	restart_label.text = "RESTARTING..."
	restart_label.modulate = Color.GREEN
	

	var final_tween = create_tween()
	final_tween.tween_property(overlay, "color", Color.WHITE, 0.5)
	

	game_over_timer.timeout.connect(func(): 
		if canvas_layer and is_instance_valid(canvas_layer):
			canvas_layer.queue_free()
	, CONNECT_ONE_SHOT)

func handle_death_state(delta: float) -> void:

	if engine_sound:
		engine_sound.volume_db = lerp(engine_sound.volume_db, -20.0, 5 * delta)
	

	linear_velocity = linear_velocity.lerp(Vector2.ZERO, 2.0 * delta)
	angular_velocity = lerp(angular_velocity, 0.0, 2.0 * delta)
	

	if sprite:
		sprite.modulate = sprite.modulate.lerp(Color.GRAY, 3.0 * delta)


func handle_boost(delta: float) -> void:
	if is_boosted:
		boost_timer -= delta
		if boost_timer <= 0.0:
			end_speed_boost()

func activate_speed_boost() -> void:
	if not is_boosted:
		is_boosted = true
		boost_timer = boost_duration
		move_speed = original_move_speed * boost_multiplier
		sprite.modulate = Color(1.2, 1.2, 0.8)
	else:
		boost_timer = boost_duration
		
func end_speed_boost() -> void:
	if is_boosted:
		is_boosted = false
		boost_timer = 0.0
		move_speed = original_move_speed
		if not dead:
			sprite.modulate = Color.WHITE

func update_backward_limit():
	var old_furthest = furthest_x_position
	if global_position.x > furthest_x_position:
		furthest_x_position = global_position.x
		backward_limit_x = furthest_x_position - backward_limit_distance
		
		if furthest_x_position != old_furthest:
			update_distance_UI()

func update_distance_UI():
	var distance_traveled = int(furthest_x_position - starting_x_position)
	if get_parent().has_method("update_distance_UI"):
		get_parent().update_distance_UI(distance_traveled)

func update_coins_UI(total_coins_earned):
	if get_parent().has_method("update_coins_UI"):
		get_parent().update_coins_UI(total_coins_earned)


func enforce_backward_limit():
	if global_position.x < backward_limit_x:
		if linear_velocity.x < 0:
			linear_velocity.x = 0
		
		global_position.x = backward_limit_x + 5.0
		apply_central_force(Vector2(500, 0))

func detect_stuck(delta: float) -> void:
	var position_change = global_position.distance_to(last_position)
	var movement_per_frame = position_change / delta
	
	if move_input != 0.0 and movement_per_frame < 30.0:
		stuck_timer += delta
		
		if stuck_timer > 0.5 and stuck_timer < 0.6:
			var unstick_force = Vector2(move_input * 600, -200)
			apply_central_impulse(unstick_force)
			print("GENTLE UNSTICK: ", unstick_force)
			
		elif stuck_timer > 1.2 and stuck_timer < 1.3:
			var medium_unstick = Vector2(move_input * 900, -400)
			apply_central_impulse(medium_unstick)
			print("MEDIUM UNSTICK: ", medium_unstick)
			
		elif stuck_timer > 2.0:
			var mega_unstick = Vector2(move_input * 1200, -600)
			apply_central_impulse(mega_unstick)
			stuck_timer = 0.0 
			print("MEGA UNSTICK (RESET): ", mega_unstick)
			
	elif movement_per_frame > 50.0: 
		stuck_timer = 0.0
	
	last_position = global_position

func apply_terrain_smoothing(delta: float) -> void:
	if not is_grounded or move_input == 0:
		return
	
	if surface_normal != Vector2.UP:
		var surface_right = Vector2(surface_normal.y, -surface_normal.x)
		var desired_surface_velocity = surface_right * move_input * move_speed
		
		linear_velocity = linear_velocity.lerp(desired_surface_velocity, terrain_smoothing * delta)
	
	if abs(linear_velocity.y) < 100 and is_grounded:
		linear_velocity.y = lerp(linear_velocity.y, 0.0, 5.0 * delta)



func get_surface_normal_at_contact(body: Node2D) -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.new()
	query.from = global_position + Vector2(0, -10)
	query.to = global_position + Vector2(0, 30)
	query.collision_mask = 0xFFFFFFFF
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	if result and result.collider == body:
		return result.normal
	
	return Vector2.UP

func handle_input(delta: float) -> void:

	move_input = 0.0
	var target_velocity_x = 0.0
	

	if is_grounded or near_ground:

		if Input.is_action_pressed("ui_right"):
			move_input = 1.0
			target_velocity_x = move_speed
		elif Input.is_action_pressed("ui_left"):
			move_input = -1.0
			if global_position.x <= backward_limit_x + 10.0:
				move_input = 0.0
				target_velocity_x = 0.0
			else:
				target_velocity_x = -move_speed
	else:

		if Input.is_action_pressed("ui_right"):
			move_input = 0.5 
			target_velocity_x = move_speed * 0.5
		elif Input.is_action_pressed("ui_left"):
			move_input = -0.5
			target_velocity_x = -move_speed * 0.5

	var current_speed = abs(linear_velocity.x)
	var speed_factor = clamp(current_speed / flip_speed_threshold, 0.0, 1.0)
	var current_flip_sensitivity = lerp(min_flip_sensitivity, max_flip_sensitivity, speed_factor)
	

	if not is_grounded and not near_ground:
		if Input.is_action_pressed("ui_right") and not Input.is_action_pressed("ui_left"):

			apply_torque(current_flip_sensitivity)
		elif Input.is_action_pressed("ui_left") and not Input.is_action_pressed("ui_right"):

			apply_torque(-current_flip_sensitivity)


	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up"):
		var can_jump = false
		if settings_infinite_jumps:
			can_jump = true  
		else:
			can_jump = jumps_remaining > 0 

		if can_jump:
			sleeping = false
			stuck_timer = 0.0
			var current_jump_force = jump_force
			if not settings_infinite_jumps and jumps_remaining == 1:
				current_jump_force = double_jump_force
				print("Double jump executed!")
			else:
				print("Jump executed!")
			linear_velocity.y = current_jump_force
			if not settings_infinite_jumps:
				jumps_remaining -= 1


	
	if move_input != 0:
		sleeping = false
		freeze = false
		
	
		if is_grounded and surface_normal != Vector2.UP:
			var slope_factor = abs(surface_normal.dot(Vector2.UP))
			slope_factor = clamp(slope_factor, 0.3, 1.0)
			target_velocity_x *= slope_factor
			
	
			if (move_input > 0 and surface_normal.x < 0) or (move_input < 0 and surface_normal.x > 0):
				var slope_boost = Vector2(0, -200 * (1.0 - slope_factor))
				apply_central_force(slope_boost)
		
	
		var accel_rate = acceleration if is_grounded else air_acceleration
		
	
		if (target_velocity_x > 0 and linear_velocity.x < target_velocity_x) or \
		   (target_velocity_x < 0 and linear_velocity.x > target_velocity_x):
			linear_velocity.x = move_toward(linear_velocity.x, target_velocity_x, accel_rate * abs(target_velocity_x) * delta)
		
	
		var desired_speed = abs(target_velocity_x)
		
		if current_speed < desired_speed * 0.2 and stuck_timer < 0.4:
			var boost_force = Vector2(move_input * move_speed * 1.5, 0)
			apply_central_force(boost_force)
		
	
		if is_grounded and current_speed < desired_speed * 0.15 and stuck_timer < 0.3:
			var hop_check = check_for_tiny_obstacle()
			if hop_check:
				var micro_hop = Vector2(move_input * 200, -100)
				apply_central_impulse(micro_hop)
				print("MICRO-HOP over tiny obstacle")
		
	else:
	
		stuck_timer = 0.0
		var decel_rate = deceleration if is_grounded else air_deceleration
		
	
		if abs(linear_velocity.x) > 10: 
			var decel_amount = decel_rate * abs(linear_velocity.x) * delta
			if linear_velocity.x > 0:
				linear_velocity.x = max(0, linear_velocity.x - decel_amount)
			else:
				linear_velocity.x = min(0, linear_velocity.x + decel_amount)
		else:
			linear_velocity.x = 0  


func check_ground() -> void:
	var was_grounded = is_grounded
	is_grounded = false
	surface_normal = Vector2.UP
	

	var bodies = get_colliding_bodies()
	for body in bodies:
		if body != self and body != null:

			var body_top_y = body.global_position.y

			if global_position.y >= body_top_y - 50:  
				is_grounded = true
				last_ground_position = global_position
				surface_normal = get_surface_normal_at_contact(body)
				break
	
	
	if not is_grounded and ground_raycast and ground_raycast.is_colliding():
		var collider = ground_raycast.get_collider()
		if collider != null and collider != self:
			var collision_point = ground_raycast.get_collision_point()
			var distance_to_ground = collision_point.y - global_position.y
			
	
			if distance_to_ground <= 60 and distance_to_ground >= -10:
				is_grounded = true
				last_ground_position = global_position
				surface_normal = ground_raycast.get_collision_normal()
	
	
	if not is_grounded:
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.new()
		query.from = global_position
		query.to = global_position + Vector2(0, 70) 
		query.collision_mask = 0xFFFFFFFF
		query.exclude = [self]
		
		var result = space_state.intersect_ray(query)
		if result:
			var distance_to_ground = result.position.y - global_position.y
			if distance_to_ground <= 65 and distance_to_ground >= 0:
				is_grounded = true
				last_ground_position = global_position
				surface_normal = result.normal
	
	if is_grounded and not was_grounded:
		last_ground_position = global_position
	
		jumps_remaining = max_jumps
		print("Grounded detected at: ", global_position, " - Jumps reset to: ", jumps_remaining)

func check_for_tiny_obstacle() -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.new()
	query.from = global_position
	query.to = global_position + Vector2(move_input * 20, 0)
	query.collision_mask = 0xFFFFFFFF
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	if result:
		var height_query = PhysicsRayQueryParameters2D.new()
		height_query.from = result.position + Vector2(0, -20)
		height_query.to = result.position + Vector2(0, 20)
		height_query.collision_mask = 0xFFFFFFFF
		height_query.exclude = [self]
		
		var height_result = space_state.intersect_ray(height_query)
		if height_result:
			var obstacle_height = global_position.y - height_result.position.y
			return obstacle_height > 0 and obstacle_height <= 15
	
	return false

func handle_animation() -> void:
	if not sprite:
		return
		
	var speed = abs(linear_velocity.x)
	
	if is_grounded:
		if speed > 10:
			if sprite.sprite_frames.has_animation("walk"):
				sprite.play("walk")
	
			var base_speed = clamp(speed / 100.0, 0.5, 2.0)
			sprite.speed_scale = base_speed * (1.5 if is_boosted else 1.0)
		else:
			if sprite.sprite_frames.has_animation("idle"):
				sprite.play("idle")
			else:
				sprite.stop()
	else:
		if linear_velocity.y < -50:
			if sprite.sprite_frames.has_animation("jump"):
				sprite.play("jump")
		elif linear_velocity.y > 50:
			if sprite.sprite_frames.has_animation("fall"):
				sprite.play("fall")
		else:
			if sprite.sprite_frames.has_animation("jump"):
				sprite.play("jump")
	
	if linear_velocity.x > 5:
		sprite.flip_h = false
	elif linear_velocity.x < -5:
		sprite.flip_h = true

func refuel():
	fuel = 100
	get_parent().update_fuel_UI(fuel)
	
	
	stuck_death_timer = 0.0

func use_fuel(delta):
	if settings_infinite_fuel:
		return
	
	var fuel_consumption = 5 * delta
	if is_boosted:
		fuel_consumption *= 2  
	
	fuel -= fuel_consumption
	fuel = clamp(fuel, 0, 100)
	get_parent().update_fuel_UI(fuel)


func reset_respawn_attempts() -> void:
	respawn_attempts = 0
	print("Respawn attempts reset!")


func get_distance_traveled() -> int:
	return int(furthest_x_position - starting_x_position)


func get_furthest_position() -> float:
	return furthest_x_position


func handle_tricks_and_airtime(delta: float) -> void:
	
	

	if not is_grounded:
		current_airtime += delta
		

		if global_position.y < max_height_this_jump:
			max_height_this_jump = global_position.y
		

		var current_angular_vel = angular_velocity
		

		accumulated_rotation += abs(current_angular_vel) * delta
		

		check_for_completed_flips()
		
		last_angular_velocity = current_angular_vel
		
	else:

		if not was_grounded_last_frame:

			var jump_height = jump_start_y - max_height_this_jump
			

			if current_airtime >= min_airtime_for_bonus and jump_height >= min_jump_height:
				award_airtime_bonus()
			elif current_airtime >= min_airtime_for_bonus:
				print("Jump too low for airtime bonus: ", jump_height, "px (need ", min_jump_height, "px)")
			elif jump_height >= min_jump_height:
				print("Airtime too short for bonus: ", current_airtime, "s (need ", min_airtime_for_bonus, "s)")
		

		if was_grounded_last_frame:

			if accumulated_rotation >= rotation_threshold * 0.7:  # 70% of a flip
				print("Near-flip detected: ", accumulated_rotation / rotation_threshold * 100, "% of full rotation")
			
			current_airtime = 0.0
			accumulated_rotation = 0.0
			completed_flips = 0
			last_angular_velocity = 0.0
			max_height_this_jump = global_position.y
			jump_start_y = global_position.y
		

		if abs(angular_velocity) > 0.1:
			angular_velocity = lerp(angular_velocity, 0.0, 10.0 * delta)
	

	if is_grounded and not was_grounded_last_frame:
		jump_start_y = global_position.y
		max_height_this_jump = global_position.y
	
	was_grounded_last_frame = is_grounded


func check_for_completed_flips() -> void:

	var flips_completed_now = int(accumulated_rotation / rotation_threshold)
	

	if flips_completed_now > completed_flips:
		var new_flips = flips_completed_now - completed_flips
		for i in range(new_flips):

			var flip_direction = 1 if last_angular_velocity > 0 else -1
			award_flip_bonus(flip_direction)
		
		completed_flips = flips_completed_now
		

		print("Total rotation accumulated: ", accumulated_rotation, " radians")
		print("Flips completed this session: ", completed_flips)


func award_flip_bonus(direction: int) -> void:
	var flip_type = "FRONTFLIP" if direction > 0 else "BACKFLIP"
	total_flips += 1
	total_coins_earned += flip_coin_value
	
	print(flip_type + " COMPLETED! +" + str(flip_coin_value) + " coins (Total flips: " + str(total_flips) + ")")
	show_trick_popup(flip_type, flip_coin_value)
	

	if get_parent().has_method("add_coins"):
		get_parent().add_coins(flip_coin_value)
	

	update_coins_UI(total_coins_earned)



func award_airtime_bonus() -> void:
	var bonus_coins = min(int(current_airtime * airtime_coin_value), max_airtime_bonus)
	if bonus_coins > 0:
		total_coins_earned += bonus_coins
		print("AIRTIME BONUS! " + str(current_airtime).pad_decimals(1) + "s = +" + str(bonus_coins) + " coins")
		show_trick_popup("AIRTIME BONUS", bonus_coins, str(current_airtime).pad_decimals(1) + "s")
		print(total_coins_earned)
		get_parent().add_coins(bonus_coins)

func show_trick_popup(trick_name: String, coins: int, extra_text: String = "") -> void:

	var popup = Label.new()
	popup.text = trick_name + "\n+" + str(coins) + " coins"
	if extra_text != "":
		popup.text += "\n" + extra_text
	
	popup.add_theme_font_size_override("font_size", 100)
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.modulate = Color.YELLOW
	

	var world_pos = global_position + Vector2(0, -50)
	

	get_tree().current_scene.add_child(popup)
	popup.global_position = world_pos
	

	var tween = create_tween()
	tween.parallel().tween_property(popup, "global_position", world_pos + Vector2(0, -100), 2.0)
	tween.parallel().tween_property(popup, "modulate", Color.TRANSPARENT, 2.0)
	tween.tween_callback(popup.queue_free)


func get_total_flips() -> int:
	return total_flips

func get_total_coins() -> int:
	return total_coins_earned

func get_current_airtime() -> float:
	return current_airtime

func _input(event):

	if event.is_action_pressed("ui_select"):  
		print("=== FLIP DEBUG INFO ===")
		print("Is grounded: ", is_grounded)
		print("Angular velocity: ", angular_velocity)
		print("Accumulated rotation: ", accumulated_rotation, " radians")
		print("Rotation in degrees: ", rad_to_deg(accumulated_rotation))
		print("Completed flips: ", completed_flips)
		print("Total flips: ", total_flips)
		print("Current airtime: ", current_airtime, "s")
		print("Jump height this session: ", jump_start_y - max_height_this_jump, "px")
		print("=======================")

func check_ground_proximity() -> void:
	var was_near_ground = near_ground
	near_ground = false
	

	if ground_raycast and ground_raycast.is_colliding():
		var collision_point = ground_raycast.get_collision_point()
		var distance_to_ground = collision_point.y - global_position.y
		
		if distance_to_ground <= ground_proximity_threshold:
			near_ground = true
	else:
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.new()
		query.from = global_position
		query.to = global_position + Vector2(0, ground_proximity_threshold)
		query.collision_mask = 0xFFFFFFFF
		query.exclude = [self]
		
		var result = space_state.intersect_ray(query)
		if result:
			var distance_to_ground = result.position.y - global_position.y
			if distance_to_ground <= ground_proximity_threshold and distance_to_ground >= 0:
				near_ground = true

func handle_dynamic_rotation_lock(delta: float) -> void:
	if near_ground or is_grounded:
		lock_rotation = true

		if abs(angular_velocity) > 0.1:
			angular_velocity = lerp(angular_velocity, 0.0, rotation_lock_strength *10 * delta)
	else:
		lock_rotation = false
