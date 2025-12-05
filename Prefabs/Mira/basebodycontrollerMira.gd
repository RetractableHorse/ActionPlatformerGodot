extends CharacterBody2D

@export var HEALTH = 100
@export var SPEED = 300.0
@export var JUMP_VELOCITY = -400.0
@export var FALL_VELOCITY = 650.0
@onready var COYOTE_TIME = $CoyoteTimer
#@onready var _animation_player = $AnimationPlayer
var CAN_JUMP = true
var was_on_floor = false
var direction = Input.get_axis("Left", "Right")
var is_touching = false




func _physics_process(delta: float) -> void:
	 #Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	 #Handle jump.
	if Input.is_action_just_pressed("Jump") and (is_on_floor() or !COYOTE_TIME.is_stopped()):
		CAN_JUMP = true
		velocity.y = JUMP_VELOCITY
		COYOTE_TIME.stop()
		
	if not is_on_floor():
		COYOTE_TIME.is_stopped()
		velocity.y += FALL_VELOCITY * delta
		#$Timer.start(.2: float = 1):
		
		if not is_on_floor() and COYOTE_TIME.is_stopped():
			CAN_JUMP = false
			JUMP_VELOCITY = is_on_floor()
			#
			

#func _process(_delta):
	#if Input.is_action_pressed("Right"):
		#$AnimatedSprite2D/AnimationPlayer.play("runningbasic")
		#flipSprite()
	#else:
		#$AnimatedSprite2D/AnimationPlayer.stop()
		
	#$AnimatedSprite2D/AnimationPlayer.play("runningbasic")
		#flipSprite()
	#else:
	#$AnimatedSprite2D/AnimationPlayer.stop()
		

	 #Get the input direction and handle the movement/deceleration.
	 #As good practice, you should replace UI actions with cu stom gameplay actions.
	var direction := Input.get_axis("Left", "Right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		
	was_on_floor = is_on_floor()
	move_and_slide()
	
	if !is_on_floor() and was_on_floor:
		COYOTE_TIME.start()
		
	if is_on_floor():
		COYOTE_TIME.stop()
		
	if !is_on_floor():
		Timer.one_shot
		
		
		
		
	$AnimatedSprite2D.play("idle")
		
		
func flipSprite():
	
	if direction:
		$AnimatedSprite2D.scale.x = -1
		
#func die():
	#if Node.name == "Mira":
		

func _on_coyote_timer_timeout() -> void:
	pass
	
