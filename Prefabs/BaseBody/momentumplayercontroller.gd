extends CharacterBody2D

# === CORE STATS ===
@export var HEALTH = 100
@export var MAX_SPEED = 300.0
@export var ACCELERATION = 2000.0
@export var GROUND_FRICTION = 1500.0
@export var AIR_ACCELERATION = 1600.0
@export var AIR_FRICTION = 200.0
@export var SPEED_THRESHOLD = 250.0
@export var JUMP_VELOCITY = -400.0
@export var JUMP_CUT_MULTIPLIER = 0.5
@export var FALL_GRAVITY_MULTIPLIER = 3.5
@export var FAST_FALL_MULTIPLIER = 2.0
@export var current_speed = velocity
@export var death_sound_path: String = "res://Sounds/dontwannadie.wav"

# === DAMAGE PARAMETERS ===
@export_group("Damage Parameters")
@export var invincibility_duration: float = 1.0
@export var damage_knockback: Vector2 = Vector2(200, -150)
@export var damage_flash_duration: float = 0.1

# === ABILITY UNLOCK SYSTEM ===
@export_group("Unlockable Abilities")
@export var ability_wall_jump: bool = false
@export var ability_ground_dash: bool = false
@export var ability_air_dash: bool = false
@export var ability_double_jump: bool = false
@export var ability_crawl: bool = false
@export var ability_homing_attack: bool = false
@export var ability_melee_attack: bool = false
@export var ability_rail_grind: bool = false

@export_group("Wall Jump Parameters")
@export var wall_jump_force: Vector2 = Vector2(300, -350)
@export var wall_slide_speed: float = 60.0
@export var wall_jump_coyote_time: float = 0.15

@export_group("Ground Dash Parameters")
@export var ground_dash_speed: float = 500.0
@export var ground_dash_boost: float = 200.0
@export var dash_max_speed: float = 600.0
@export var ground_dash_duration: float = 0.3
@export var dash_cooldown: float = 0.5
@export var dash_momentum_preservation: float = 0.85
@export var dash_jump_buffer: float = 0.15

@export_group("Dash Visual Effects")
@export var dash_ghost_enabled: bool = true
@export var dash_ghost_interval: float = 0.05
@export var dash_ghost_fade_duration: float = 0.3

# === ANIMATION SETTINGS ===
@export_group("Animations - Basic Movement")
@export var anim_idle: String = "idle"
@export var anim_run: String = "runningbasic"
@export var anim_jump_start: String = "airspin"
@export var anim_jump_fall: String = "jumpbase"
@export var anim_land: String = "idle"
@export var anim_death: String = "death"
@export var anim_hurt: String = "Hurt"

@export_group("Animations - Wall Jump")
@export var anim_wall_slide_left: String = "wallslideleft"
@export var anim_wall_slide_right: String = "wallslideright"
@export var anim_wall_jump: String = "airspin"

@export_group("Animations - Dash")
@export var anim_ground_dash: String = "runningbasic"
@export var anim_air_dash: String = "airspin"

@export_group("Animations - Future Abilities")
@export var anim_double_jump: String = "airspin"
@export var anim_crawl: String = "idle"
@export var anim_homing_attack: String = "airspin"
@export var anim_melee_1: String = "idle"
@export var anim_melee_2: String = "idle"
@export var anim_melee_3: String = "idle"
@export var anim_rail_grind: String = "runningbasic"

# === INPUT BUFFER SYSTEM ===
@export_group("Input Buffer")
@export var jump_buffer_time: float = 0.15
@export var dash_buffer_time: float = 0.15
@export var attack_buffer_time: float = 0.15

# === NODE REFERENCES ===
@onready var COYOTE_TIME = $CoyoteTimer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animation_player = $AnimatedSprite2D/AnimationPlayer
@onready var health_bar = null

# === STATE VARIABLES ===
var was_on_floor: bool = false
var airspin_played: bool = false
var is_dead: bool = false
var current_health: float = 0.0  # Track health locally

# Input buffer timers
var jump_buffer_timer: float = 0.0
var dash_buffer_timer: float = 0.0
var attack_buffer_timer: float = 0.0

# Wall jump state
var is_on_wall_left: bool = false
var is_on_wall_right: bool = false
var was_on_wall: bool = false
var wall_jump_coyote_timer: float = 0.0

# Dash state
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: float = 0.0
var dash_jump_buffer_timer: float = 0.0
var dash_ghost_timer: float = 0.0

# Damage state
var is_invincible: bool = false
var is_taking_damage: bool = false
var damage_timer: float = 0.0

func _ready():
	add_to_group("player")
	
	#if health_bar and health_bar.has_method("update_health"):
		#health_bar.update_health(HEALTH, HEALTH)

func _physics_process(delta: float) -> void:
	var input_direction := Input.get_axis("Left", "Right")
	
	# Update timers
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	if wall_jump_coyote_timer > 0:
		wall_jump_coyote_timer -= delta
	if dash_jump_buffer_timer > 0:
		dash_jump_buffer_timer -= delta
	if damage_timer > 0:
		damage_timer -= delta
		if damage_timer <= 0:
			is_taking_damage = false
	
	# Input buffer timers
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	if dash_buffer_timer > 0:
		dash_buffer_timer -= delta
	if attack_buffer_timer > 0:
		attack_buffer_timer -= delta
	
	# Capture input buffers
	if Input.is_action_just_pressed("Jump"):
		jump_buffer_timer = jump_buffer_time
	if Input.is_action_just_pressed("Dash"):
		dash_buffer_timer = dash_buffer_time
	
	# Skip normal movement when taking damage
	if is_taking_damage:
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		handle_animations(input_direction)
		return
	
	# Wall detection
	if ability_wall_jump:
		check_wall_collision()
	
	# Dashing state
	if is_dashing:
		handle_dash(delta)
		move_and_slide()
		handle_animations(input_direction)
		return
	
	# Gravity
	if not is_on_floor():
		if ability_wall_jump and (is_on_wall_left or is_on_wall_right) and velocity.y > 0:
			velocity.y = min(velocity.y, wall_slide_speed)
		else:
			var gravity_multiplier = FALL_GRAVITY_MULTIPLIER if velocity.y > 0 else 1.0
			
			if Input.is_action_pressed("Down") and velocity.y > 0:
				gravity_multiplier *= FAST_FALL_MULTIPLIER
			
			velocity += get_gravity() * delta * gravity_multiplier
	
	# Ground dash (with buffer)
	if ability_ground_dash and dash_buffer_timer > 0 and is_on_floor() and dash_cooldown_timer <= 0:
		start_ground_dash(input_direction)
		dash_buffer_timer = 0.0
	
	# Wall jump (with buffer)
	if ability_wall_jump and jump_buffer_timer > 0 and !is_on_floor():
		if is_on_wall_left or is_on_wall_right or wall_jump_coyote_timer > 0:
			perform_wall_jump()
			jump_buffer_timer = 0.0
			move_and_slide()
			handle_animations(input_direction)
			return
	
	# Normal jump (with buffer) - CANCELS DASH
	if jump_buffer_timer > 0:
		# Cancel dash immediately if jumping
		if is_dashing:
			is_dashing = false
			dash_timer = 0.0
		
		# Dash jump buffer
		if dash_jump_buffer_timer > 0:
			velocity.y = JUMP_VELOCITY
			dash_jump_buffer_timer = 0.0
			jump_buffer_timer = 0.0
			airspin_played = false
			
			if abs(velocity.x) > SPEED_THRESHOLD:
				velocity.y *= 1.1
		# Normal jump with coyote time
		elif is_on_floor() or !COYOTE_TIME.is_stopped():
			velocity.y = JUMP_VELOCITY
			COYOTE_TIME.stop()
			jump_buffer_timer = 0.0
			airspin_played = false
			
			if abs(velocity.x) > SPEED_THRESHOLD:
				velocity.y *= 1.1
	
	# Variable jump height
	if Input.is_action_just_released("Jump") and velocity.y < 0:
		velocity.y *= JUMP_CUT_MULTIPLIER
	
	# Momentum system
	print(current_speed)
	
	var current_speed = abs(velocity.x)
	var is_in_flow_state = current_speed > SPEED_THRESHOLD
	
	if is_on_floor():
		if input_direction != 0:
			velocity.x = move_toward(velocity.x, input_direction * MAX_SPEED, ACCELERATION * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, GROUND_FRICTION * delta)
	else:
		var momentum_speed = abs(velocity.x)
		var is_high_speed = momentum_speed > MAX_SPEED
		
		if input_direction != 0:
			var air_control_modifier = 1.0
			if is_in_flow_state:
				air_control_modifier = 0.75
			elif is_high_speed:
				air_control_modifier = 0.5
			
			if is_high_speed and sign(input_direction) == sign(velocity.x):
				velocity.x = move_toward(velocity.x, input_direction * momentum_speed, AIR_ACCELERATION * air_control_modifier * delta)
			else:
				velocity.x = move_toward(velocity.x, input_direction * MAX_SPEED, AIR_ACCELERATION * air_control_modifier * delta)
		else:
			var friction = AIR_FRICTION if not is_high_speed else AIR_FRICTION * 0.5
			velocity.x = move_toward(velocity.x, 0, friction * delta)
	
	# Coyote time
	if was_on_floor and !is_on_floor():
		COYOTE_TIME.start()
	if is_on_floor():
		COYOTE_TIME.stop()
	
	# Wall jump coyote time
	if was_on_wall and !is_on_wall_left and !is_on_wall_right:
		wall_jump_coyote_timer = wall_jump_coyote_time
	was_on_wall = is_on_wall_left or is_on_wall_right
	
	was_on_floor = is_on_floor()
	move_and_slide()
	handle_animations(input_direction)

# === WALL JUMP FUNCTIONS ===
func check_wall_collision():
	if !is_on_floor():
		is_on_wall_left = test_move(transform, Vector2(-1, 0))
		is_on_wall_right = test_move(transform, Vector2(1, 0))
	else:
		is_on_wall_left = false
		is_on_wall_right = false

func perform_wall_jump():
	var wall_direction = 0
	if is_on_wall_left or (wall_jump_coyote_timer > 0 and was_on_wall and velocity.x < 0):
		wall_direction = 1
	elif is_on_wall_right or (wall_jump_coyote_timer > 0 and was_on_wall and velocity.x > 0):
		wall_direction = -1
	
	if wall_direction != 0:
		velocity.x = wall_direction * wall_jump_force.x
		velocity.y = wall_jump_force.y
		airspin_played = false
		wall_jump_coyote_timer = 0.0
		animated_sprite.flip_h = wall_direction < 0

# === DASH FUNCTIONS ===
func start_ground_dash(input_dir: float):
	if input_dir != 0:
		dash_direction = input_dir
	else:
		dash_direction = -1 if animated_sprite.flip_h else 1
	
	is_dashing = true
	dash_timer = ground_dash_duration
	dash_cooldown_timer = dash_cooldown
	dash_ghost_timer = 0.0
	
	var current_speed = velocity.x
	var target_speed = dash_direction * ground_dash_speed
	
	if sign(current_speed) == sign(dash_direction):
		velocity.x = clamp(current_speed + (dash_direction * ground_dash_boost), -dash_max_speed, dash_max_speed)
	else:
		velocity.x = target_speed
	
	velocity.y = 0

func handle_dash(delta: float):
	dash_timer -= delta
	dash_ghost_timer -= delta
	
	# Spawn dash ghost
	if dash_ghost_enabled and dash_ghost_timer <= 0:
		spawn_dash_ghost()
		dash_ghost_timer = dash_ghost_interval
	
	if dash_timer <= 0:
		is_dashing = false
		velocity.x *= dash_momentum_preservation
		dash_jump_buffer_timer = dash_jump_buffer
	else:
		if abs(velocity.x) < abs(dash_direction * ground_dash_speed):
			velocity.x = move_toward(velocity.x, dash_direction * ground_dash_speed, ACCELERATION * delta)

func spawn_dash_ghost():
	var ghost = Sprite2D.new()
	
	ghost.texture = animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
	ghost.flip_h = animated_sprite.flip_h
	ghost.global_position = animated_sprite.global_position
	ghost.modulate = Color(9, 1, 1, 0.3)
	
	get_parent().add_child(ghost)
	fade_and_delete_ghost(ghost)

func fade_and_delete_ghost(ghost: Sprite2D):
	var tween = create_tween()
	tween.tween_property(ghost, "modulate:a", 0.1, dash_ghost_fade_duration)
	tween.tween_callback(ghost.queue_free)

# === ANIMATION HANDLER ===
func handle_animations(input_direction: float):
	if is_taking_damage:
		animated_sprite.play(anim_hurt)
		return
	
	if ability_wall_jump and (is_on_wall_left or is_on_wall_right) and !is_on_floor() and velocity.y > 0:
		if is_on_wall_left:
			animated_sprite.play(anim_wall_slide_left)
			animated_sprite.flip_h = false
		elif is_on_wall_right:
			animated_sprite.play(anim_wall_slide_right)
			animated_sprite.flip_h = true
		return
	
	if is_dashing:
		animated_sprite.play(anim_ground_dash)
		animated_sprite.flip_h = dash_direction < 0
		return
	
	if !is_on_floor():
		if !airspin_played:
			animated_sprite.play(anim_jump_start)
			if animated_sprite.animation == anim_jump_start and animated_sprite.frame == animated_sprite.sprite_frames.get_frame_count(anim_jump_start) - 1:
				airspin_played = true
		else:
			animated_sprite.play(anim_jump_fall)
			if animated_sprite.frame == animated_sprite.sprite_frames.get_frame_count(anim_jump_fall) - 1:
				animated_sprite.stop()
		
		if input_direction != 0:
			animated_sprite.flip_h = input_direction < 0
		elif abs(velocity.x) > 10:
			animated_sprite.flip_h = velocity.x < 0
		return
	
	airspin_played = false
	
	if input_direction != 0:
		animated_sprite.flip_h = input_direction < 0
		animated_sprite.play(anim_run)
	else:
		if abs(velocity.x) < 50:
			animated_sprite.play(anim_idle)
		else:
			animated_sprite.play(anim_run)

# === DAMAGE SYSTEM ===
func take_damage(amount: int, damage_source_position: Vector2 = global_position):
	if is_invincible or is_dead:
		return
	
	HEALTH -= amount
	
	if health_bar and health_bar.has_method("update_health"):
		health_bar.update_health(HEALTH, 100)
	
	if HEALTH <= 0:
		die()
		return
	# ... rest
	
	is_taking_damage = true
	is_invincible = true
	damage_timer = invincibility_duration
	
	var knockback_dir = sign(global_position.x - damage_source_position.x)
	if knockback_dir == 0:
		knockback_dir = -1 if animated_sprite.flip_h else 1
	
	velocity.x = knockback_dir * damage_knockback.x
	velocity.y = damage_knockback.y
	
	is_dashing = false
	dash_timer = 0.0
	
	start_invincibility_flash()

func start_invincibility_flash():
	var flash_count = int(invincibility_duration / (damage_flash_duration * 2))
	
	for i in range(flash_count):
		if not is_invincible:
			break
		animated_sprite.modulate.a = 0.3
		await get_tree().create_timer(damage_flash_duration).timeout
		animated_sprite.modulate.a = 1.0
		await get_tree().create_timer(damage_flash_duration).timeout
	
	animated_sprite.modulate.a = 1.0
	is_invincible = false

# === DEATH ===
func die():
	if is_dead:
		return
	
	is_dead = true
	HEALTH = 0
	
	Engine.time_scale = 0.0
	await get_tree().create_timer(0.5, true, false, true).timeout
	Engine.time_scale = 1.0
	
	var death_sound = AudioStreamPlayer.new()
	death_sound.stream = load(death_sound_path)
	get_tree().root.add_child(death_sound)
	death_sound.play()
	
	set_physics_process(false)
	animated_sprite.play(anim_death)
	
	await animated_sprite.animation_finished
	await get_tree().create_timer(1.0).timeout
	
	death_sound.queue_free()
	restart_scene()

func restart_scene():
	Fade.fade_out(1)
	await Fade.fade_out(1, Color.BLACK, "diamond").finished
	get_tree().reload_current_scene()
	Fade.fade_in(1, Color.BLACK, "diamond")

func _on_coyote_timer_timeout() -> void:
	pass
