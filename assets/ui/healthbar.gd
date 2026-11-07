extends ProgressBar
class_name HealthBarComponent

@onready var timer = $Timer
@onready var damage_bar = $Damagebar

var health: float = 0: set = _set_health


func _ready() -> void:
	_add_ultimate_bar.call_deferred() # the fighter's CombatComponent is set up after us


func _set_health(new_health):
	var prev_health = health
	health = min(max_value, new_health)
	value = health


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


## The thin ultimate meter under this bar (GAM-23), for a fighter whose class has an ultimate.
func _add_ultimate_bar() -> void:
	var combat := CombatComponent.find_on(owner)
	if combat == null:
		return
	var bar := UltimateBar.new()
	bar.name = "UltimateBar"
	add_child(bar)
	bar.setup(combat, self)
