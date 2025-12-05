extends Area2D

@export var damage = 5
@export var knockback_force = 300
@export var hop_force = Vector2(150, -5)  # x = horizontal speed, y = jump strength
@export var hop_interval = 3.0

var player = null
var can_hop = true

func _ready():
	body_entered.connect(_on_body_entered)
	# Start hop timer
	var timer = Timer.new()
	timer.wait_time = hop_interval
	timer.timeout.connect(_on_hop_timer_timeout)
	timer.autostart = true
	add_child(timer)
	
	print("rdy 2 hop!")

func _physics_process(delta):
	# Find player if we don't have reference
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		
	#print("found player node from first node in group...")

func _on_hop_timer_timeout():
	if player != null and can_hop:
		hop_towards_player()
		print("hopping confirmed!")

func hop_towards_player():
	var parent = get_parent()
	if parent is CharacterBody2D:  # Enemy needs to be CharacterBody2D
		# Determine direction to player
		var direction = sign(player.global_position.x - global_position.x)
		print("enemy moving towards you!")
		# Apply hop
		parent.velocity.x = hop_force.x * direction
		parent.velocity.y = hop_force.y
		
		print("enemy hopping!")
		
		# Flip sprite if you have one
		if parent.has_node("AnimatedSprite2D"):
			parent.get_node("AnimatedSprite2D").flip_h = direction < 0
			print("enemy sprite = flipped")

func _on_body_entered(body: Node2D)-> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		# Deal damage
		body.take_damage(damage)
		
		print("Damaged!")
		
		# Apply knockback
		var knockback_direction = (body.global_position - global_position).normalized()
		body.velocity = knockback_direction * knockback_force
		
		print("get knocked back lol")
