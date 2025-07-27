extends RigidBody2D

@export var move_speed: float = 2000.0
@export var jump_force: float = -1500.0 
@export var air_control: float = 0.3
@export var max_jump_height: float = 100.0
@export var auto_step_height: float = 30.0
@export var terrain_smoothing: float = 0.8
@export var stuck_threshold: float = 50.0

@onready var sprite: AnimatedSprite2D = $Cow
@onready var ground_raycast: RayCast2D = $RayCast2D
var fuel = 100
var move_input = 0.0
var last_ground_position: Vector2  
var stuck_timer: float = 0.0
var last_position: Vector2
var surface_normal: Vector2 = Vector2.UP

var is_grounded: bool = false

func _ready() -> void:
	get_parent().update_fuel_UI(fuel)
	
	gravity_scale = 1.5
	lock_rotation = true
	
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

func _physics_process(delta: float) -> void:
	check_ground()
	detect_stuck(delta)
	handle_input(delta)
	handle_animation()
	apply_terrain_smoothing(delta)
	
	if move_input == 1.0:
		$EngineSound.pitch_scale = lerp($EngineSound.pitch_scale, 2.0, 2 * delta)
		use_fuel(delta)
	else:
		$EngineSound.pitch_scale = lerp($EngineSound.pitch_scale, 1.0, 2 * delta)

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

func check_ground() -> void:
	var was_grounded = is_grounded
	is_grounded = false
	surface_normal = Vector2.UP
	
	var bodies = get_colliding_bodies()
	for body in bodies:
		if body != self and body != null:
			is_grounded = true
			last_ground_position = global_position

			var contacts = get_colliding_bodies()
			if contacts.size() > 0:
				surface_normal = get_surface_normal_at_contact(body)
			break
	
	if not is_grounded and ground_raycast and ground_raycast.is_colliding():
		var collider = ground_raycast.get_collider()
		if collider != null and collider != self:
			is_grounded = true
			last_ground_position = global_position
			surface_normal = ground_raycast.get_collision_normal()

	if not is_grounded:
		var space_state = get_world_2d().direct_space_state
		var check_points = [
			Vector2(0, 0),
			Vector2(-10, 0),
			Vector2(10, 0),
		]
		
		for point_offset in check_points:
			var query = PhysicsRayQueryParameters2D.new()
			query.from = global_position + point_offset
			query.to = global_position + point_offset + Vector2(0, 60)
			query.collision_mask = 0xFFFFFFFF
			query.exclude = [self]
			
			var result = space_state.intersect_ray(query)
			if result:
				var distance_to_ground = result.position.y - global_position.y
				if distance_to_ground <= max_jump_height and distance_to_ground >= -10:
					is_grounded = true
					last_ground_position = global_position
					surface_normal = result.normal
					break
	
	if is_grounded and not was_grounded:
		last_ground_position = global_position

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
	
	return Vector2.UP  # Default fallback

func handle_input(delta: float) -> void:
	move_input = 0.0
	if Input.is_action_pressed("ui_right"):
		move_input = 1.0
	elif Input.is_action_pressed("ui_left"):
		move_input = -1.0
	
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up"):
		var can_jump = false
		
		if is_grounded:
			can_jump = true
		
		elif last_ground_position != Vector2.ZERO:
			var height_from_ground = global_position.y - last_ground_position.y
			if height_from_ground <= max_jump_height:
				can_jump = true
		
		if not can_jump:
			var space_state = get_world_2d().direct_space_state
			var query = PhysicsRayQueryParameters2D.new()
			query.from = global_position
			query.to = global_position + Vector2(0, max_jump_height)
			query.collision_mask = 0xFFFFFFFF
			query.exclude = [self]
			
			var result = space_state.intersect_ray(query)
			if result:
				var distance_to_ground = result.position.y - global_position.y
				if distance_to_ground <= max_jump_height:
					can_jump = true
		
		if can_jump:
			sleeping = false
			linear_velocity.y = jump_force
			stuck_timer = 0.0

	if move_input != 0:
		sleeping = false
		freeze = false
		
		var base_target = move_input * move_speed
		var target_velocity_x = base_target
		
		if is_grounded and surface_normal != Vector2.UP:
			var slope_factor = abs(surface_normal.dot(Vector2.UP))  # 1.0 = flat, 0.0 = vertical
			slope_factor = clamp(slope_factor, 0.3, 1.0)  # Don't go too slow on slopes
			target_velocity_x *= slope_factor
			
			if (move_input > 0 and surface_normal.x < 0) or (move_input < 0 and surface_normal.x > 0):
				var slope_boost = Vector2(0, -200 * (1.0 - slope_factor))
				apply_central_force(slope_boost)
		
		var acceleration_factor = 15.0 if is_grounded else air_control * 10.0  # Increased responsiveness
		linear_velocity.x = lerp(linear_velocity.x, target_velocity_x, acceleration_factor * delta)
		
		var current_speed = abs(linear_velocity.x)
		var desired_speed = abs(target_velocity_x)
		
		if current_speed < desired_speed * 0.3 and stuck_timer < 0.4:  # Don't interfere with unstick system
			var boost_force = Vector2(move_input * move_speed * 1.2, 0)  # Gentler boost
			apply_central_force(boost_force)
		
		if is_grounded and current_speed < desired_speed * 0.2 and stuck_timer < 0.3:
			var hop_check = check_for_tiny_obstacle()
			if hop_check:
				var micro_hop = Vector2(move_input * 200, -100)  # Gentler micro-hop
				apply_central_impulse(micro_hop)
				print("MICRO-HOP over tiny obstacle")
		
	else:
		stuck_timer = 0.0
		if is_grounded:
			linear_velocity.x = lerp(linear_velocity.x, 0.0, 8.0 * delta)
		else:
			linear_velocity.x = lerp(linear_velocity.x, 0.0, 2.0 * delta)

func check_for_tiny_obstacle() -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.new()
	query.from = global_position
	query.to = global_position + Vector2(move_input * 20, 0)  # Short distance check
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
			return obstacle_height > 0 and obstacle_height <= 15  # Very small obstacles only
	
	return false

func handle_animation() -> void:
	if not sprite:
		return
		
	var speed = abs(linear_velocity.x)
	
	if is_grounded:
		if speed > 10:
			if sprite.sprite_frames.has_animation("walk"):
				sprite.play("walk")
			sprite.speed_scale = clamp(speed / 100.0, 0.5, 2.0)
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

func use_fuel(delta):
	fuel -= 10 * delta
	fuel = clamp(fuel, 0, 100)
	get_parent().update_fuel_UI(fuel)
