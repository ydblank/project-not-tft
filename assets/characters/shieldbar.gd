extends ProgressBar
class_name ShieldBarComponent

@onready var timer = $Timer
@onready var damage_bar = $Damagebar

var shield: float = 0: set = _set_shield

func _set_shield(new_shield):
	var prev_shield: float = shield
	shield = min(max_value, new_shield)
	value = shield
	
	if shield < prev_shield:
		timer.start()
	else:
		damage_bar.value = shield

func init_shield(_shield: float) -> void:
	max_value = _shield
	shield = _shield
	value = shield
	damage_bar.max_value = shield
	damage_bar.value = shield

func _on_timer_timeout() -> void:
	damage_bar.value = shield
