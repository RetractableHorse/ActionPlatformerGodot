extends ProgressBar

func _ready():
	max_value = 100
	value = 100

func update_health(current_health, max_health):
	max_value = max_health
	value = current_health
