@tool
extends Resource
class_name Weapons

enum WEAPONS {NONE, SWORD, DAGGER, BOW}

# Weapon stats and movesets live in WeaponData resources (assets/combat/weapons/),
# mapped from the WEAPONS enum here.
const WEAPON_DATA_PATHS := {
	WEAPONS.NONE: "res://assets/combat/weapons/unarmed.tres",
	WEAPONS.SWORD: "res://assets/combat/weapons/sword.tres",
	WEAPONS.DAGGER: "res://assets/combat/weapons/dagger.tres",
	WEAPONS.BOW: "res://assets/combat/weapons/bow.tres",
}


static func get_weapon_data(weapon: WEAPONS) -> WeaponData:
	var path: String = WEAPON_DATA_PATHS.get(weapon, WEAPON_DATA_PATHS[WEAPONS.NONE])
	return load(path) as WeaponData
