extends Resource
class_name WeaponsDB

@export var weapons = {
	"sword": {
		"type": "melee",
		"sprite": "",
		"dmg": 10,
		"quick_attack": [0.5, 0.5, 0.5, 0.5, 1.2],
		"heavy_attack": 1.5,
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
		"sprite": "",
		"dmg": 5,
		"quick_attack": [0.4, 0.4, 0.4, 1.2],
		"heavy_attack": 1.5,
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
		"sprite": "",
		"projectile": "",
		"dmg": 10,
		"quick_attack": [1.0],
		"heavy_attack": 1.5,
		"q_attack": 0.8,
		"h_attack_min": 0.5,
		"h_attack_max": 2.5,
		"attack_speed": 5,
		"charge_time": 4,
		"base_range": 300,
		"h_max_range": 500,
	}
}
