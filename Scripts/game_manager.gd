extends Node

func _ready() -> void:
	$Fade.call_deferred("fade_in", 1, Color.BLACK, "diamond")
	print("Fade-in started!")
