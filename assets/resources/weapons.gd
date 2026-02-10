extends Resource
class_name Weapons

enum WEAPONS {NONE, SWORD, DAGGER, BOW}

static var weaponStats = {
	WEAPONS.NONE: {
		"type": "",
		"sprite": "",
		"projectile": "",
		"atk": 0,
		"attack_speed": 1.0,
		"base_attack_speed": 1.0,
		"quick_attack": [],
		"heavy_attack": [],
		"quick_attack_mult": [],
		"heavy_attack_mult": [],
		"q_attack_mult": 1.0,
		"h_attack_min_mult": 1.0,
		"h_attack_max_mult": 1.0,
		"heavy_charge_time": 0,
		"base_range": 0,
		"h_max_range": 0
	},
	WEAPONS.SWORD: {
		"type": "melee",
		"sprite": "",
		"dmg": 10.0,
		"quick_attack": [0.5, 0.5, 1.2],
		"heavy_attack": [1.0, 1.5],
		"quick_attack_mult": [0.5, 0.5, 1.2],
		"heavy_attack_mult": [1.0, 1.5],
		"q_attack_mult": 0.8,
		"h_attack_min_mult": 1.0,
		"h_attack_max_mult": 1.5,
		"attack_speed": 0.10,
		"heavy_charge_time": 2,
		"base_range": 50,
		"h_max_range": 100
	},
	WEAPONS.DAGGER: {
		"type": "melee",
		"sprite": "",
		"dmg": 5.0,
		"quick_attack": [0.4, 0.4, 0.4, 1.2],
		"heavy_attack": [1.0, 1.5],
		"quick_attack_mult": [0.4, 0.4, 0.4, 1.2],
		"heavy_attack_mult": [1.0, 1.5],
		"q_attack_mult": 0.8,
		"h_attack_min_mult": 1.0,
		"h_attack_max_mult": 1.5,
		"attack_speed": 0.25,
		"heavy_charge_time": 2,
		"base_range": 30,
		"h_max_range": 70
	},
	WEAPONS.BOW: {
		"type": "range",
		"sprite": "",
		"projectile": "",
		"dmg": 10.0,
		"quick_attack": [1.0],
		"heavy_attack": [1.5],
		"quick_attack_mult": [1.0],
		"heavy_attack_mult": [1.5],
		"q_attack_mult": 0.8,
		"h_attack_min_mult": 0.5,
		"h_attack_max_mult": 2.5,
		"attack_speed": 0.05,
		"base_attack_speed": 0.05,
		"heavy_charge_time": 4,
		"base_range": 300,
		"h_max_range": 500,
	}
}
