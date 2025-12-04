extends Node

func _ready() -> void:
	$Fade.call_deferred("fade_in", .5, Color.DARK_ORANGE, "squares")
	print("Fade-in started!")
