extends RigidBody2D

@export var move_speed: float = 2000.0
@export var jump_force: float = -1500.0 
@export var air_control: float = 0.3
@export var max_jump_height: float = 100.0
@export var auto_step_height: float = 30.0

@onready var sprite: AnimatedSprite2D = $Cow
@onready var ground_raycast: RayCast2D = $RayCast2D
var fuel = 100
var move_input = 0.0
var last_ground_position: Vector2  

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
	physics_material_override.friction = 0.1
	physics_material_override.bounce = 0.0
	
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
		
	else:
		pass	

func _physics_process(delta: float) -> void:
	check_ground()
	handle_input(delta)
	handle_animation()
	
	if move_input == 1.0:
		$EngineSound.pitch_scale = lerp($EngineSound.pitch_scale, 2.0, 2 * delta)
		use_fuel(delta)
	else:
		$EngineSound.pitch_scale = lerp($EngineSound.pitch_scale, 1.0, 2 * delta)

func check_ground() -> void:
	var was_grounded = is_grounded
	is_grounded = false
	var bodies = get_colliding_bodies()
	for body in bodies:
		if body != self and body != null:
			is_grounded = true
			last_ground_position = global_position
			break
	
	if not is_grounded and ground_raycast and ground_raycast.is_colliding():
		var collider = ground_raycast.get_collider()
		if collider != null and collider != self:
			is_grounded = true
			last_ground_position = global_position

	
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
			query.to = global_position + point_offset + Vector2(0, 60)  # Cast down 60px
			query.collision_mask = 0xFFFFFFFF
			query.exclude = [self]
			
			var result = space_state.intersect_ray(query)
			if result:
				var distance_to_ground = result.position.y - global_position.y
				if distance_to_ground <= max_jump_height and distance_to_ground >= -10:  # Allow slight overlap
					is_grounded = true
					last_ground_position = global_position
					break
	
	if is_grounded and not was_grounded:
		last_ground_position = global_position

func handle_input(delta: float) -> void:
	move_input = 0.0
	if Input.is_action_pressed("ui_right"):
		move_input = 1.0
	elif Input.is_action_pressed("ui_left"):
		move_input = -1.0
	
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up"):
		var can_jump = false
		var jump_reason = ""
		
		if is_grounded:
			can_jump = true
			jump_reason = "GROUNDED"
		
		elif last_ground_position != Vector2.ZERO:
			var height_from_ground = global_position.y - last_ground_position.y
			if height_from_ground <= max_jump_height:
				can_jump = true
				jump_reason = "HEIGHT_TOLERANCE (" + str(height_from_ground) + "px from ground)"
		
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
					jump_reason = "GROUND_WITHIN_RANGE (" + str(distance_to_ground) + "px below, type: " + result.collider.get_class() + ")"
		
		if can_jump:
			sleeping = false
			linear_velocity.y = jump_force
		else:
			if last_ground_position != Vector2.ZERO:
				var height_diff = global_position.y - last_ground_position.y
	
	if move_input != 0:
		sleeping = false
		freeze = false
				
		var target_velocity_x = move_input * move_speed  # Full speed now!
		
		if is_grounded:
			linear_velocity.x = lerp(linear_velocity.x, target_velocity_x, 10.0 * delta)
		else:
			linear_velocity.x = lerp(linear_velocity.x, target_velocity_x, air_control * 5.0 * delta)
		
		
		var current_speed = abs(linear_velocity.x)
		var desired_speed = abs(target_velocity_x)
		
		if current_speed < desired_speed * 0.5:
			var boost_force = Vector2(move_input * move_speed * 2.0, 0)
			apply_central_force(boost_force)
		
		
	else:
		if is_grounded:
			linear_velocity.x = lerp(linear_velocity.x, 0.0, 8.0 * delta)
		else:
			linear_velocity.x = lerp(linear_velocity.x, 0.0, 2.0 * delta)

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
