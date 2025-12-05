extends CharacterBody2D
@export var HEALTH = 100
@export var SPEED = 300.0
@export var BEGIN_SPEED = 150.0
@export var JUMP_VELOCITY = -400.0
@export var JUMP_CUT_MULTIPLIER = 0.5  # How much to cut jump when releasing button
@export var FALL_GRAVITY_MULTIPLIER = 3.5
@onready var COYOTE_TIME = $CoyoteTimer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animation_player = $AnimatedSprite2D/AnimationPlayer
@onready var someGravity = 1.0
@onready var noGravity = 0
#@onready var player = $BlankBody
@onready var health_bar = $"../HUD/Health"  # Adjust path to wherever you put it
# Or if it's in the UI: 
var direction: Vector2 = Vector2.RIGHT
var was_on_floor = false
var airspin_played = false  # Track if airspin has played
var is_dead = false

func _ready():
	health_bar.update_health(HEALTH, HEALTH)
	
func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("Left", "Right")
	
	# Apply gravity
	if not is_on_floor():
		var gravity_multiplier = FALL_GRAVITY_MULTIPLIER if velocity.y > noGravity else someGravity
		velocity += get_gravity() * delta * someGravity
	
	# Handle jump with coyote time
	if Input.is_action_just_pressed("Jump") and (is_on_floor() or !COYOTE_TIME.is_stopped()):
		velocity.y = JUMP_VELOCITY
		COYOTE_TIME.stop()
		airspin_played = false  # Reset animation tracker
	
	# Variable jump height - cut jump short when releasing button
	if Input.is_action_just_released("Jump") and velocity.y < 0:
		velocity.y *= JUMP_CUT_MULTIPLIER
	
	# Handle air animations
	if !is_on_floor():
		if !airspin_played:
			animated_sprite.play("airspin")
			#animation_player.play("airspin") commenting out for now until state machine is set up
			# Check if airspin animation finished
			if animated_sprite.animation == "airspin" and animated_sprite.frame == animated_sprite.sprite_frames.get_frame_count("airspin") - 1:
				airspin_played = true
		else:
			# Play jumpbase, then stop on last frame
			animated_sprite.play("jumpbase")
			#animation_player.play("jumpbase")
			# Stop animation on last frame to hold it
			if animated_sprite.frame == animated_sprite.sprite_frames.get_frame_count("jumpbase") - 1:
				animated_sprite.stop()
				#animation_player.stop()
	else:
		airspin_played = false  # Reset when landing
	
	# Handle horizontal movement
	if direction != 0:
		velocity.x = direction * SPEED
		animated_sprite.flip_h = direction < 0
		if is_on_floor():
			animated_sprite.play("runningbasic")
			#animation_player.play("runningbasic")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		if is_on_floor():
			animated_sprite.play("idle")
			#animation_player.play("idle")
	
	# Handle coyote time
	if was_on_floor and !is_on_floor():
		COYOTE_TIME.start()
	
	if is_on_floor():
		COYOTE_TIME.stop()
	
	was_on_floor = is_on_floor()
	move_and_slide()
	
func die():
	if is_dead:
		return  # Prevent multiple death triggers
	
	is_dead = true
	
	if is_dead:
		HEALTH = 0
	
	# Disable player control
	set_physics_process(false)
	
	# Play death animation
	animated_sprite.play("death")
	
	# Wait for animation to finish + 1 second
	await animated_sprite.animation_finished
	await get_tree().create_timer(1.0).timeout
	
	# Fade out, reset scene, fade in using Universal Fade
	restart_scene()

func restart_scene():
	# Fade out
	Fade.fade_out(1)  # 1 second fade out
	await Fade.fade_out(1, Color.BLACK, "diamond").finished
	
	# Reset scene
	get_tree().reload_current_scene()
	
	# Fade in happens automatically when scene loads
	Fade.fade_in(1, Color.BLACK, "diamond")  # 1 second fade in
	
 # Initialize to full

func take_damage(amount):
	HEALTH -= amount
	health_bar.update_health(HEALTH, 100)  # Update the bar
	
	if HEALTH <= 0:
		die()
	
func _on_coyote_timer_timeout() -> void:
	
	
	pass
