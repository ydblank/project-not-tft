@tool
extends Resource
class_name Classes

# Class table. Values follow the design sheet (Linear GAM-29):
#
#   class  | starting weapon | power | defense | knockback res | attack speed | HP
#   Knight | Sword           | 10    | 10      | 10            | 2            | 100
#   Thief  | Dagger          | 5     | 7       | 5             | 10           | 100
#   Archer | Fist (sheet)    | 7     | 5       | 5             | 7            | 100
#   Mage   | Staff           | TBD (not in the game yet)
#
# The sheet's "damage" column is the "power" stat here (shared by physical and
# magic attacks). The Archer keeps the bow until the slingshot exists. Every
# class has only its starting weapon (no secondary weapon).
#
# "bonus_*" values are added to the StatsComponent bases (power, defense and
# knockback res bases are 0 and the HP base is 100, so the totals equal the
# sheet). Attack speed is a multiplier with base 1.0, and the sheet rates it
# from 1 to 10: bonus = ATTACK_SPEED_PER_POINT * rating - ATTACK_SPEED_OFFSET
# (rating 2 = 0.85x, 10 = 1.25x). See docs/features/calculations.md.

enum CLASSES {NONE, KNIGHT, THIEF, ARCHER}

## Attack speed multiplier gained per point of the sheet's attack speed rating.
const ATTACK_SPEED_PER_POINT := 0.05
## Subtracted so a rating of 5 gives the base 1.0 multiplier.
const ATTACK_SPEED_OFFSET := 0.25


static var classStats = {
	CLASSES.NONE: {
		"bonus_power": 0,
		"bonus_hp": 0,
		"bonus_def": 0,
		"bonus_knockback_res": 0,
		"bonus_attack_speed": 0.0,
		"allowed_weapons": [],
		"sprite_path": ""
	},
	CLASSES.KNIGHT: {
		"bonus_power": 10,
		"bonus_hp": 0,
		"bonus_def": 10,
		"bonus_knockback_res": 10,
		"bonus_attack_speed": -0.15, # sheet rating 2
		"allowed_weapons": [Weapons.WEAPONS.SWORD],
		"sprite_path": "res://assets/art/1 Characters/2/2.png"
	},
	CLASSES.THIEF: {
		"bonus_power": 5,
		"bonus_hp": 0,
		"bonus_def": 7,
		"bonus_knockback_res": 5,
		"bonus_attack_speed": 0.25, # sheet rating 10
		"allowed_weapons": [Weapons.WEAPONS.DAGGER],
		"sprite_path": "res://assets/art/1 Characters/1/1.png"
	},
	CLASSES.ARCHER: {
		"bonus_power": 7,
		"bonus_hp": 0,
		"bonus_def": 5,
		"bonus_knockback_res": 5,
		"bonus_attack_speed": 0.10, # sheet rating 7
		"allowed_weapons": [Weapons.WEAPONS.BOW], # the sheet says Fist; bow until the slingshot is added
		"sprite_path": "res://assets/art/1 Characters/3/3.png"
	}
}
