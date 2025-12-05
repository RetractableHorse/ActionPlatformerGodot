extends CharacterBody2D
@export var HEALTH = 100
@export var MAX_SPEED = 300.0
@export var ACCELERATION = 2000.0  # Fast acceleration (MMZ feel)
@export var GROUND_FRICTION = 1500.0  # Quick stop capability (MMZ precision)
@export var AIR_ACCELERATION = 1600.0  # Good air control (MMZ style)
@export var AIR_FRICTION = 200.0  # Slight air momentum (Sonic flow)
@export var SPEED_THRESHOLD = 250.0  # Speed where "flow state" kicks in
@export var JUMP_VELOCITY = -400.0
@export var JUMP_CUT_MULTIPLIER = 0.5
@export var FALL_GRAVITY_MULTIPLIER = 3.5

@onready var COYOTE_TIME = $CoyoteTimer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animation_player = $AnimatedSprite2D/AnimationPlayer
@onready var health_bar = $"../HUD/Health"
@export var death_sound_path: String = "res://Music/Sounds/SFX/dontwannadie.wav"
@onready var damage =  $"../CharacterBody2D/Enemy".damage

var was_on_floor = false
var airspin_played = false
var is_dead = false

func _ready():
	health_bar.update_health(HEALTH, HEALTH)
	
func _physics_process(delta: float) -> void:
	var input_direction := Input.get_axis("Left", "Right")
	
	# Apply gravity
	if not is_on_floor():
		var gravity_multiplier = FALL_GRAVITY_MULTIPLIER if velocity.y > 0 else 1.0
		velocity += get_gravity() * delta * gravity_multiplier
	#Fastfall	
	if Input.is_action_pressed("Down") and (!is_on_floor()):
		var gravity_multiplier = FALL_GRAVITY_MULTIPLIER if velocity.y > 0 else 1.0
		velocity += get_gravity() * delta * gravity_multiplier
	
	# Handle jump with coyote time
	if Input.is_action_just_pressed("Jump") and (is_on_floor() or !COYOTE_TIME.is_stopped()):
		velocity.y = JUMP_VELOCITY
		COYOTE_TIME.stop()
		airspin_played = false
	
	# Variable jump height
	if Input.is_action_just_released("Jump") and velocity.y < 0:
		velocity.y *= JUMP_CUT_MULTIPLIER
	
	# === MOMENTUM SYSTEM ===
	
	# Calculate current speed for flow state detection
	var current_speed = abs(velocity.x)
	var is_in_flow_state = current_speed > SPEED_THRESHOLD
	
	if is_on_floor():
		# GROUND MOVEMENT - MMZ-style responsive with momentum building
		if input_direction != 0:
			# Accelerate towards max speed
			velocity.x = move_toward(velocity.x, input_direction * MAX_SPEED, ACCELERATION * delta)
		else:
			# Quick stop on ground (MMZ precision)
			velocity.x = move_toward(velocity.x, 0, GROUND_FRICTION * delta)
	else:
		# AIR MOVEMENT - Hybrid control
		if input_direction != 0:
			# Good air control at low speeds (MMZ precision)
			# Slightly less at high speeds (Sonic commitment)
			var air_control_modifier = 1.0 if not is_in_flow_state else 0.75
			velocity.x = move_toward(velocity.x, input_direction * MAX_SPEED, AIR_ACCELERATION * air_control_modifier * delta)
		else:
			# Light air friction (preserves momentum like Sonic)
			velocity.x = move_toward(velocity.x, 0, AIR_FRICTION * delta)
	
	# === ANIMATION HANDLING ===
	
	# Air animations
	if !is_on_floor():
		if !airspin_played:
			animated_sprite.play("airspin")
			if animated_sprite.animation == "airspin" and animated_sprite.frame == animated_sprite.sprite_frames.get_frame_count("airspin") - 1:
				airspin_played = true
		else:
			animated_sprite.play("jumpbase")
			if animated_sprite.frame == animated_sprite.sprite_frames.get_frame_count("jumpbase") - 1:
				animated_sprite.stop()
	else:
		airspin_played = false
	
	# Ground animations and sprite flipping
	if is_on_floor():
		if input_direction != 0:
			animated_sprite.flip_h = input_direction < 0
			animated_sprite.play("runningbasic")
		else:
			# Only play idle if moving slowly (prevents janky transitions)
			if abs(velocity.x) < 50:
				animated_sprite.play("idle")
	
	# Always flip sprite based on movement direction when moving
	if abs(velocity.x) > 10:
		animated_sprite.flip_h = velocity.x < 0
	
	# === COYOTE TIME ===
	if was_on_floor and !is_on_floor():
		COYOTE_TIME.start()
	
	if is_on_floor():
		COYOTE_TIME.stop()
	
	was_on_floor = is_on_floor()
	move_and_slide()
	
func restart_scene():
	# Fade out
	Fade.fade_out(1)
	await Fade.fade_out(1, Color.BLACK, "diamond").finished
	
	# Reset scene
	get_tree().reload_current_scene()
	
	# Fade in happens automatically when scene loads
	Fade.fade_in(1, Color.BLACK, "diamond")
	
func take_damage(damage):
	HEALTH -= damage
	health_bar.update_health(HEALTH, 100)  # Update the bar
	
	if HEALTH <= 0:
		die()
	


func die():
	if is_dead:
		return
	
	is_dead = true
	
	if is_dead:
		HEALTH = 0
	
	# HITSTOP - Freeze the game for dramatic effect
	Engine.time_scale = 0.0
	await get_tree().create_timer(0.5, true, false, true).timeout  # true = process in pause, ignores time_scale
	Engine.time_scale = 1.0
	
	
	# Play death sound
	var death_sound = AudioStreamPlayer.new()
	death_sound.stream = load("res://Music/Sounds/PlayerSFX/dontwannadie.wav")
	add_child(death_sound)
	death_sound.play()
	
	# Disable player control and play animation
	set_physics_process(false)
	animated_sprite.play("death")
	
	await animated_sprite.animation_finished
	await get_tree().create_timer(1.0).timeout
	
	# Fade out
	Fade.fade_out(1)  # 1 second fade out
	await Fade.fade_out(1, Color.BLACK, "diamond").finished
	
	# Reset scene
	get_tree().reload_current_scene()
	
	# Fade in happens automatically when scene loads
	Fade.fade_in(1, Color.BLACK, "diamond")  # 1 second fade in
	

func _on_coyote_timer_timeout() -> void:
	pass
	 # Replace with function body.


#func _on_enemy_body_entered(body: Node2D) -> void:
	#take_damage("damage")
	pass # Replace with function body.
