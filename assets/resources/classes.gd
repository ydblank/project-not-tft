extends Resource
class_name ClassesDB

@export var classes = {
	"knight": {
		"hp": 100,
		"dmg": 10,
		"def": 20,
		"knockback_res": 20,
		"attack_speed": 0.85,
		"starting_weapon": "sword",
		"sprite_path": "res://assets/art/1 Characters/2/2.png"
	},
	"rogue": {
		"hp": 100,
		"dmg": 5,
		"def": 10,
		"knockback_res": 10,
		"attack_speed": 1.25,
		"starting_weapon": "dagger",
		"sprite_path": "res://assets/art/1 Characters/1/1.png"
	},
	"archer": {
		"hp": 100,
		"dmg": 10,
		"def": 5,
		"knockback_res": 5,
		"attack_speed": 1.10,
		"starting_weapon": "bow",
		"sprite_path": "res://assets/art/1 Characters/3/3.png"
	}
}
