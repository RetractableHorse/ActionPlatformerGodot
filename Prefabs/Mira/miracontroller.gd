extends CharacterBody2D

@export var HEALTH = 100
@export var SPEED = 300.0
@export var JUMP_VELOCITY = -400.0
@export var FALL_GRAVITY_MULTIPLIER = 3.5  # Makes falling feel snappier
@onready var COYOTE_TIME = $CoyoteTimer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animation_player = $AnimatedSprite2D/AnimationPlayer
@onready var someGravity = 1.0
@onready var noGravity = 0

var was_on_floor = false

func _physics_process(delta: float) -> void:
	# Get input once per frame
	var direction := Input.get_axis("Left", "Right")
	
	# Apply gravity
	if not is_on_floor():
		# Apply extra gravity when falling for better game feel
		var gravity_multiplier = FALL_GRAVITY_MULTIPLIER if velocity.y > noGravity else someGravity
		velocity += get_gravity() * delta * someGravity
	
	# Handle jump with coyote time
	if Input.is_action_just_pressed("Jump") and (is_on_floor() or !COYOTE_TIME.is_stopped() and is_on_floor()):
		velocity.y = JUMP_VELOCITY
		COYOTE_TIME.stop()
	if !is_on_floor():
		animated_sprite.play("airspin")
		animation_player.play("airspin")
	
	# Handle horizontal movement
	if direction != 0:
		velocity.x = direction * SPEED
		# Flip sprite based on direction
		animated_sprite.flip_h = direction < 0
		# Play running animation
		if is_on_floor():
			animated_sprite.play("runningbasic")
			animation_player.play("runningbasic")
	else:
		# Decelerate when no input
		velocity.x = move_toward(velocity.x, 0, SPEED)
		# Play idle animation
		if is_on_floor():
			animated_sprite.play("idle")
			animation_player.play("idle")
	
	# Handle coyote time
	if was_on_floor and !is_on_floor():
		COYOTE_TIME.start()
	
	if is_on_floor():
		COYOTE_TIME.stop()
	
	# Update floor state and move
	was_on_floor = is_on_floor()
	move_and_slide()

func _on_coyote_timer_timeout() -> void:
	pass  # Coyote time expired
