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
@export var FAST_FALL_MULTIPLIER = 2.0  # Additional multiplier when holding down
@export var death_sound_path: String = "res://Sounds/dontwannadie.wav"

# - Damage parameters
@export_group("Damage Parameters")
@export var invincibility_duration: float = 1.0
@export var damage_knockback: Vector2 = Vector2(200, -150)
@export var damage_flash_duration: float = 0.1
@export var dash_jump_buffer: float = 0.15  # Time window to jump after dash ends

# Then continue with your ability unlock system...
@export_group("Unlockable Abilities")

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

# === NODE REFERENCES ===
@onready var COYOTE_TIME = $CoyoteTimer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animation_player = $AnimatedSprite2D/AnimationPlayer
@onready var health_bar = $"../HUD/Health"

# === INPUT BUFFER SYSTEM ===
@export_group("Input Buffer")
@export var jump_buffer_time: float = 0.15  # How long jump input is remembered
@export var dash_buffer_time: float = 0.15  # How long dash input is remembered
@export var attack_buffer_time: float = 0.15  # For future melee attacks

# Input buffer timers
var jump_buffer_timer: float = 0.0
var dash_buffer_timer: float = 0.0
var attack_buffer_timer: float = 0.0

# === STATE VARIABLES ===
var was_on_floor = false
var airspin_played = false
var is_dead = false

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
var dash_jump_buffer_timer: float = 0.0  # ADD THIS - MMZ3 dash-jump buffer

# ADD THESE - Damage state variables
var is_invincible = false
var is_taking_damage = false
var damage_timer: float = 0.0

func _ready():
	add_to_group("player")
	
	# Safe health bar initialization with error checking
	if health_bar:
		print("Health bar node found: ", health_bar)
		print("Health bar type: ", health_bar.get_class())
		if health_bar.has_method("update_health"):
			health_bar.update_health(HEALTH, HEALTH)
		else:
			print("ERROR: health_bar doesn't have update_health method!")
	else:
		print("ERROR: health_bar is null!")
	

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
	
	# INPUT BUFFER TIMERS
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	if dash_buffer_timer > 0:
		dash_buffer_timer -= delta
	if attack_buffer_timer > 0:
		attack_buffer_timer -= delta
	
	# CAPTURE INPUT BUFFERS
	if Input.is_action_just_pressed("Jump"):
		jump_buffer_timer = jump_buffer_time
	if Input.is_action_just_pressed("Dash"):
		dash_buffer_timer = dash_buffer_time
	# Future: if Input.is_action_just_pressed("Attack"):
	#     attack_buffer_timer = attack_buffer_time
	
	# === WALL DETECTION (if wall jump unlocked) ===
	if ability_wall_jump:
		check_wall_collision()
	
	# === DASHING STATE ===
	if is_dashing:
		handle_dash(delta)
		move_and_slide()
		handle_animations(input_direction)
		return  # Skip normal movement while dashing
	
	# === GRAVITY ===
	if not is_on_floor():
		# Wall sliding (if unlocked and on wall)
		if ability_wall_jump and (is_on_wall_left or is_on_wall_right) and velocity.y > 0:
			velocity.y = min(velocity.y, wall_slide_speed)
		else:
			# Normal gravity with optional fast fall
			var gravity_multiplier = FALL_GRAVITY_MULTIPLIER if velocity.y > 0 else 1.0
			
			# Fast fall when holding down (MMZ3/Celeste style)
			if Input.is_action_pressed("Down") and velocity.y > 0:
				gravity_multiplier *= FAST_FALL_MULTIPLIER
			
			velocity += get_gravity() * delta * gravity_multiplier
	
# === GROUND DASH (if unlocked) - WITH BUFFER ===
	if ability_ground_dash and dash_buffer_timer > 0 and is_on_floor() and dash_cooldown_timer <= 0:
		start_ground_dash(input_direction)
		dash_buffer_timer = 0.0  # Consume buffer
	
	# === WALL JUMP (if unlocked) - WITH BUFFER ===
	if ability_wall_jump and jump_buffer_timer > 0 and !is_on_floor():
		if is_on_wall_left or is_on_wall_right or wall_jump_coyote_timer > 0:
			perform_wall_jump()
			jump_buffer_timer = 0.0  # Consume buffer
			move_and_slide()
			handle_animations(input_direction)
			return
	
	# === NORMAL JUMP (with buffer) OR DASH JUMP BUFFER ===
	if jump_buffer_timer > 0:
		# MMZ3 dash jump: Can jump shortly after dash ends
		if dash_jump_buffer_timer > 0:
			velocity.y = JUMP_VELOCITY
			dash_jump_buffer_timer = 0.0
			jump_buffer_timer = 0.0  # Consume buffer
			airspin_played = false
			
			if abs(velocity.x) > SPEED_THRESHOLD:
				velocity.y *= 1.1
		# Normal jump (with coyote time)
		elif is_on_floor() or !COYOTE_TIME.is_stopped():
			velocity.y = JUMP_VELOCITY
			COYOTE_TIME.stop()
			jump_buffer_timer = 0.0  # Consume buffer
			airspin_played = false
			
			if abs(velocity.x) > SPEED_THRESHOLD:
				velocity.y *= 1.1
	
	# === VARIABLE JUMP HEIGHT ===
	if Input.is_action_just_released("Jump") and velocity.y < 0:
		velocity.y *= JUMP_CUT_MULTIPLIER
	
	# === MOMENTUM SYSTEM ===
	var current_speed = abs(velocity.x)
	var is_in_flow_state = current_speed > SPEED_THRESHOLD
	
	if is_on_floor():
		# GROUND MOVEMENT
		if input_direction != 0:
			velocity.x = move_toward(velocity.x, input_direction * MAX_SPEED, ACCELERATION * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, GROUND_FRICTION * delta)
	else:
		# AIR MOVEMENT - Preserve high-speed momentum from dashing (MMZ3 tech)
		var momentum_speed = abs(velocity.x)
		var is_high_speed = momentum_speed > MAX_SPEED
		
		if input_direction != 0:
			# Less air control when going fast (commitment)
			var air_control_modifier = 1.0
			if is_in_flow_state:
				air_control_modifier = 0.75
			elif is_high_speed:
				air_control_modifier = 0.5
			
			# Don't fight against high momentum
			if is_high_speed and sign(input_direction) == sign(velocity.x):
				velocity.x = move_toward(velocity.x, input_direction * momentum_speed, AIR_ACCELERATION * air_control_modifier * delta)
			else:
				velocity.x = move_toward(velocity.x, input_direction * MAX_SPEED, AIR_ACCELERATION * air_control_modifier * delta)
		else:
			# Reduced air friction when at high speed (preserve momentum)
			var friction = AIR_FRICTION if not is_high_speed else AIR_FRICTION * 0.5
			velocity.x = move_toward(velocity.x, 0, friction * delta)
	
	# === COYOTE TIME ===
	if was_on_floor and !is_on_floor():
		COYOTE_TIME.start()
	if is_on_floor():
		COYOTE_TIME.stop()
	
	# === WALL JUMP COYOTE TIME ===
	if was_on_wall and !is_on_wall_left and !is_on_wall_right:
		wall_jump_coyote_timer = wall_jump_coyote_time
	was_on_wall = is_on_wall_left or is_on_wall_right
	
	was_on_floor = is_on_floor()
	move_and_slide()
	handle_animations(input_direction)

# === WALL JUMP FUNCTIONS ===
func check_wall_collision():
	is_on_wall_left = test_move(transform, Vector2(-1, 0))
	is_on_wall_right = test_move(transform, Vector2(1, 0))

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
	
	# MMZ3-STYLE: Add to current speed instead of setting it
	var current_speed = velocity.x
	var target_speed = dash_direction * ground_dash_speed
	
	if sign(current_speed) == sign(dash_direction):
		velocity.x = clamp(current_speed + (dash_direction * ground_dash_boost), -dash_max_speed, dash_max_speed)
	else:
		velocity.x = target_speed
	
	velocity.y = 0

func handle_dash(delta: float):
	dash_timer -= delta
	
	if dash_timer <= 0:
		is_dashing = false
		velocity.x *= dash_momentum_preservation
	else:
		if abs(velocity.x) < abs(dash_direction * ground_dash_speed):
			velocity.x = move_toward(velocity.x, dash_direction * ground_dash_speed, ACCELERATION * delta)

# === ANIMATION HANDLER ===
func handle_animations(input_direction: float):
	# Wall sliding (highest priority)
	if ability_wall_jump and (is_on_wall_left or is_on_wall_right) and !is_on_floor() and velocity.y > 0:
		if is_on_wall_left:
			animated_sprite.play(anim_wall_slide_left)
			animated_sprite.flip_h = false
		elif is_on_wall_right:
			animated_sprite.play(anim_wall_slide_right)
			animated_sprite.flip_h = true
		return
	
	# Dashing
	if is_dashing:
		animated_sprite.play(anim_ground_dash)
		animated_sprite.flip_h = dash_direction < 0
		return
	
	# Air animations
	if !is_on_floor():
		if !airspin_played:
			animated_sprite.play(anim_jump_start)
			if animated_sprite.animation == anim_jump_start and animated_sprite.frame == animated_sprite.sprite_frames.get_frame_count(anim_jump_start) - 1:
				airspin_played = true
		else:
			animated_sprite.play(anim_jump_fall)
			if animated_sprite.frame == animated_sprite.sprite_frames.get_frame_count(anim_jump_fall) - 1:
				animated_sprite.stop()
		
		# Flip sprite in air
		if input_direction != 0:
			animated_sprite.flip_h = input_direction < 0
		elif abs(velocity.x) > 10:
			animated_sprite.flip_h = velocity.x < 0
		return
	
	# Ground animations
	airspin_played = false
	
	if input_direction != 0:
		animated_sprite.flip_h = input_direction < 0
		animated_sprite.play(anim_run)
	else:
		if abs(velocity.x) < 50:
			animated_sprite.play(anim_idle)
		else:
			animated_sprite.play(anim_run)

# === DEATH AND DAMAGE ===
func die():
	if is_dead:
		return
	
	is_dead = true
	HEALTH = 0
	
	# Hitstop
	Engine.time_scale = 0.0
	await get_tree().create_timer(0.5, true, false, true).timeout
	Engine.time_scale = 1.0
	
	# Play death sound (fixed - wait for it to finish)
	var death_sound = AudioStreamPlayer.new()
	death_sound.stream = load(death_sound_path)
	get_tree().root.add_child(death_sound)  # Add to root so it persists
	death_sound.play()
	
	# Disable player control
	set_physics_process(false)
	animated_sprite.play(anim_death)
	
	# Wait for animation and sound
	await animated_sprite.animation_finished
	await get_tree().create_timer(1.0).timeout
	
	# Clean up sound before restart
	death_sound.queue_free()
	restart_scene()

func restart_scene():
	Fade.fade_out(1)
	await Fade.fade_out(1, Color.BLACK, "diamond").finished
	get_tree().reload_current_scene()
	Fade.fade_in(1, Color.BLACK, "diamond")

func take_damage(amount):
	HEALTH -= amount
	health_bar.update_health(HEALTH, 100)
	
	if HEALTH <= 0:
		die()
		


func _on_coyote_timer_timeout() -> void:
	pass
