extends Resource
class_name Classes

enum CLASSES {NONE, KNIGHT, ROGUE, ARCHER}

static var classStats = {
	CLASSES.NONE: {
		"bonus_hp": 0,
		"bonus_def": 0,
		"bonus_knockback_res": 0,
		"bonus_attack_speed": 0.0,
		"allowed_weapons": [],
		"sprite_path": ""
	},
	CLASSES.KNIGHT: {
		"bonus_hp": 0,
		"bonus_def": 20,
		"bonus_knockback_res": 20,
		"bonus_attack_speed": -0.15,
		"allowed_weapons": [Weapons.WEAPONS.SWORD],
		"sprite_path": "res://assets/art/1 Characters/2/2.png"
	},
	CLASSES.ROGUE: {
		"bonus_hp": 0,
		"bonus_def": 10,
		"bonus_knockback_res": 10,
		"bonus_attack_speed": 0.25,
		"allowed_weapons": [Weapons.WEAPONS.DAGGER, Weapons.WEAPONS.SWORD],
		"sprite_path": "res://assets/art/1 Characters/1/1.png"
	},
	CLASSES.ARCHER: {
		"bonus_hp": 0,
		"bonus_def": 5,
		"bonus_knockback_res": 5,
		"bonus_attack_speed": 0.10,
		"allowed_weapons": [Weapons.WEAPONS.BOW, Weapons.WEAPONS.DAGGER],
		"sprite_path": "res://assets/art/1 Characters/3/3.png"
	}
}
