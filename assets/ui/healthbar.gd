extends ProgressBar

@onready var timer = $Timer
@onready var damage_bar = $Damagebar

var health: float = 0 : set = _set_health

func _set_health(new_health):
	var prev_health = health
	print('[set_health] prev', prev_health)
	health = min(max_value, new_health)
	print('[set_health] curr', health)
	value = health
	print('[set_health] value', value)
	
		
	if health < prev_health:
		timer.start()
	else:
		damage_bar.value = health

func init_health(_health):
	max_value = _health
	health = _health
	value = health
	damage_bar.max_value = health
	damage_bar.value = health


func _on_timer_timeout() -> void:
	damage_bar.value = health
