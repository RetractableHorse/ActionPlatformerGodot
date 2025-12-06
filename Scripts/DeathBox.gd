extends Area2D

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(100, global_position)  # Instant death with knockback
