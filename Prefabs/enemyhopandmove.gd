extends CharacterBody2D

@export var damage: int = 5
@export var hop_force: Vector2 = Vector2(150, -300)
@export var hop_interval: float = 3.0

var player = null
var damage_area: Area2D = null

func _ready():
	# Get the Area2D child - try multiple methods
	for child in get_children():
		if child is Area2D:
			damage_area = child
			break
	
	if damage_area:
		if not damage_area.body_entered.is_connected(_on_body_entered):
			damage_area.body_entered.connect(_on_body_entered)
	else:
		push_error("Enemy: No Area2D child found!")
	
	# Setup hop timer
	var timer = Timer.new()
	timer.wait_time = hop_interval
	timer.timeout.connect(_on_hop_timer_timeout)
	timer.autostart = true
	add_child(timer)

func _physics_process(delta):
	# Find player
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	
	# Apply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	move_and_slide()

func _on_hop_timer_timeout():
	if player != null and is_on_floor():
		hop_towards_player()

func hop_towards_player():
	var direction = sign(player.global_position.x - global_position.x)
	velocity.x = hop_force.x * direction
	velocity.y = hop_force.y

func _on_body_entered(body):
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage, global_position)
