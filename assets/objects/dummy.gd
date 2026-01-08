extends CharacterBody2D

@export var def = 10

var dummy_stats: Dictionary = {
	"def": def
}

var CombatClass = Combat

func take_damage(damage: float):
	var dmg = Combat.calculations.calculate_receive_damage(dummy_stats, damage)
	print(dmg)
