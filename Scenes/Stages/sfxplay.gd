extends Node

# Get a reference to your AudioStreamPlayer node
@onready var sound_effect = $AudioStreamPlayer

func _ready():
	# You might connect a signal here, for example:
	$Button.pressed.connect(play_sound)
	pass

func play_sound():
	#if not sound_effect.is_playing(): # Optional: only play if not already playing
		sound_effect.play() # Plays the assigned stream
