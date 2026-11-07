@tool
extends Resource
class_name Weapons

# Weapon registry and balance table: every weapon's type, skill and numbers in one place.
# Edit the numbers here; nothing else needs to change.
#
# How each weapon works (melee or ranged, its projectile, the moves' timing, reach, lunge, knockback and
# effects) stays in its WeaponData file in assets/combat/weapons/; this table holds what you balance.
# It is written into the weapon when it loads (get_weapon_data). The skills' own numbers are in
# assets/resources/skills.gd. A Dev Tools slider (Quick-combo cooldown, Combo hitstun) overrides the
# table only once it is moved.
#
# Fields (all optional per row; a missing one keeps the .tres value):
#   type                  weapon family: WeaponData.Type.SWORD / DAGGER / BOW / STAFF (NONE = unarmed)
#   skill                 skill id = file name in assets/combat/skills/ ("sword_spin"), "" = no skill.
#                         The skill belongs to this weapon, not to its type.
#   power_mult            multiplier on the class power (1.0 = the class's power as it is)
#   attack_speed_bonus    added to the attack speed multiplier
#   light_damage          damage multiplier of each quick-combo hit, in order (one per light move)
#   heavy_damage          damage multiplier of each heavy hit: the heavy combo's hits in order, or the
#                         single heavy move for weapons without a combo (bow, staff)
#   heavy_min_mult        heavy charge multiplier at the start of a charge
#   heavy_max_mult        ... and at a full charge
#   max_charge_time       seconds of holding for a full charge
#   light_combo_cooldown  seconds quick attacks are locked after a full quick combo (bow / staff: between shots)
#   ai_engage_range       px: how close a bot gets before its quick attacks

enum WEAPONS {NONE, SWORD, DAGGER, BOW, STAFF}

const WEAPON_DATA_PATHS := {
	WEAPONS.NONE: "res://assets/combat/weapons/unarmed.tres",
	WEAPONS.SWORD: "res://assets/combat/weapons/sword.tres",
	WEAPONS.DAGGER: "res://assets/combat/weapons/dagger.tres",
	WEAPONS.BOW: "res://assets/combat/weapons/bow.tres",
	WEAPONS.STAFF: "res://assets/combat/weapons/staff.tres",
}

const TABLE := {
	WEAPONS.NONE: {
		"type": WeaponData.Type.NONE,
		"skill": "",
		"light_damage": [1.0],
		"heavy_damage": [1.0],
		"ai_engage_range": 20.0,
	},
	WEAPONS.SWORD: {
		"type": WeaponData.Type.SWORD,
		"skill": "sword_spin",
		"power_mult": 1.0,
		"attack_speed_bonus": 0.1,
		"light_damage": [0.5, 0.5, 1.2],
		"heavy_damage": [0.7, 0.7, 1.3],
		"heavy_min_mult": 1.0,
		"heavy_max_mult": 1.5,
		"light_combo_cooldown": 0.6,
		"ai_engage_range": 30.0,
	},
	WEAPONS.DAGGER: {
		"type": WeaponData.Type.DAGGER,
		"skill": "dagger_dash",
		"power_mult": 1.0,
		"attack_speed_bonus": 0.25,
		"light_damage": [0.4, 0.4, 0.4, 1.2],
		"heavy_damage": [0.5, 0.5, 1.0],
		"heavy_min_mult": 1.0,
		"heavy_max_mult": 1.5,
		"light_combo_cooldown": 0.6,
		"ai_engage_range": 25.0,
	},
	WEAPONS.BOW: {
		"type": WeaponData.Type.BOW,
		"skill": "bow_volley",
		"power_mult": 1.0,
		"attack_speed_bonus": 0.05,
		"light_damage": [1.0],
		"heavy_damage": [1.5],
		"heavy_min_mult": 0.5,
		"heavy_max_mult": 2.0,
		"max_charge_time": 2.2,
		"light_combo_cooldown": 0.55,
		"ai_engage_range": 120.0,
	},
	WEAPONS.STAFF: {
		"type": WeaponData.Type.STAFF,
		"skill": "staff_fireball",
		"power_mult": 0.8,
		"attack_speed_bonus": 0.0,
		"light_damage": [1.0],
		"heavy_damage": [1.5],
		"heavy_min_mult": 0.6,
		"heavy_max_mult": 2.5,
		"max_charge_time": 2.6,
		"light_combo_cooldown": 0.75,
		"ai_engage_range": 120.0,
	},
}

## Where the skill files live: "<skill id>.tres".
const SKILL_PATH := "res://assets/combat/skills/%s.tres"


static func get_weapon_data(weapon: WEAPONS) -> WeaponData:
	var path: String = WEAPON_DATA_PATHS.get(weapon, WEAPON_DATA_PATHS[WEAPONS.NONE])
	var data := load(path) as WeaponData
	if data:
		apply(weapon if WEAPON_DATA_PATHS.has(weapon) else WEAPONS.NONE, data)
	return data


## Writes the weapon's table row into its loaded resource, once (later loads share the same resource).
## The skill's own numbers then come from assets/resources/skills.gd.
static func apply(weapon: WEAPONS, data: WeaponData) -> void:
	if data.has_meta(&"weapons_table_applied"):
		return
	data.set_meta(&"weapons_table_applied", true)
	var row: Dictionary = TABLE.get(weapon, {})
	for field in row:
		var v: Variant = row[field]
		match field:
			"type":
				data.weapon_type = v
			"skill":
				data.skill = load(SKILL_PATH % v) as SkillData if String(v) != "" else null
			"light_damage":
				_set_damage(data.light_moves, v)
			"heavy_damage":
				_set_damage(heavy_moves(data), v)
			_:
				data.set(field, v)
	if data.skill:
		Skills.apply(data.skill)


## The moves a heavy plays: the heavy combo, or the single heavy move.
static func heavy_moves(data: WeaponData) -> Array[AttackMove]:
	if not data.heavy_combo.is_empty():
		return data.heavy_combo
	var single: Array[AttackMove] = []
	if data.heavy_move:
		single.append(data.heavy_move)
	return single


static func _set_damage(moves: Array[AttackMove], mults: Array) -> void:
	for i in mini(moves.size(), mults.size()):
		if moves[i]:
			moves[i].damage_mult = mults[i]
