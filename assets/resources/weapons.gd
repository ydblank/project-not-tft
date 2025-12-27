extends Resource
class_name WeaponsDB

@export var weapons = {
	"sword": {
		"type": "melee",
		"dmg": 10,
		"q_attack": 1,
		"h_attack": 1.5,
		"attack_speed": 10,
		"range": 50
	},
	"dagger": {
		"type": "melee",
		"dmg": 5,
		"q_attack": 1,
		"h_attack": 1.5,
		"attack_speed": 25,
		"range": 30
	},
	"bow": {
		"type": "range",
		"dmg": 10,
		"q_attack": 1,
		"h_attack": 3,
		"attack_speed": 5,
		"range": 300
	}
}
