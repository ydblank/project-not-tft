extends Resource
class_name WeaponsDB

@export var weapons = {
	"sword": {
		"type": "melee",
		"dmg": 10,
		"q_attack": 0.8,
		"h_attack_min": 1.0,
		"h_attack_max": 1.5,
		"attack_speed": 10,
		"charge_time": 2,
		"base_range": 50,
		"h_max_range": 100
	},
	"dagger": {
		"type": "melee",
		"dmg": 5,
		"q_attack": 0.8,
		"h_attack_min": 1.0,
		"h_attack_max": 1.5,
		"attack_speed": 25,
		"charge_time": 2,
		"base_range": 30,
		"h_max_range": 70
	},
	"bow": {
		"type": "range",
		"dmg": 10,
		"q_attack": 0.8,
		"h_attack_min": 0.5,
		"h_attack_max": 2.5,
		"attack_speed": 5,
		"charge_time": 4,
		"base_range": 300,
		"h_max_range": 500,
	}
}
