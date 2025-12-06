extends ProgressBar

func update_health(current_health, max_health):
	if current_health == null or max_health == null:
		return
	
	max_value = max_health
	value = current_health
