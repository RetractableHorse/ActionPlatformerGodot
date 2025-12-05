extends Area2D

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body is CharacterBody2D and body.has_method("take_damage"):
		body.take_damage(100)  # Instant death
		# Or body.take_damage(20) for 20 damaged
