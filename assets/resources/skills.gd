@tool
extends Resource
class_name Skills

# Skill balance table (GAM-20): every skill's damage, cooldown, timing and reach in one place.
# Edit the numbers here; nothing else needs to change.
#
# How a skill works (kind, tags, aim mode, knockback, stagger, visuals) stays in its SkillData file
# in assets/combat/skills/<id>.tres; this table holds the numbers you balance. The row name is the
# .tres file name. Distances are in arena tiles (16 px, SkillData.TILE); the F5 ruler in game shows
# them. The pause menu's Dev Tools -> Skills sliders start from these values and override them only while moved
# (Dev Tools -> Reset to defaults goes back to the table).
#
# Fields (all optional per row; a missing one keeps the .tres value):
#   damage_mult        multiplier on the fighter's power (each arrow for the volley, the blast for the fireball)
#   dot_mult_per_sec   burning ground damage per second, multiplier on power
#   cooldown           seconds
#   cast_time          seconds of wind-up before the skill takes effect (fireball)
#   duration           seconds busy after the cast (spin length; for the volley it follows the volley count)
#   range_tiles        max reach: dash length, arrow flight, fireball throw
#   radius_tiles       area radius: spin circle, fireball blast
#   move_speed_mult    walking speed while the skill runs, share of normal (spin; below 0 = the shared slow speed)
#   burn_radius_tiles  burning ground radius
#   burn_duration      seconds the ground burns
#   spread_deg         volley fan angle
#   volley_count, arrows_per_volley
#   ai_range_tiles     farthest target a bot uses the skill on (default: range_tiles)

const TABLE := {
	"sword_spin": {
		"damage_mult": 1.5,
		"cooldown": 7.0,
		"duration": 0.6,
		"radius_tiles": 2.0,
		"move_speed_mult": 0.6,
	},
	"dagger_dash": {
		"damage_mult": 2.0,
		"cooldown": 3.0,
		"range_tiles": 6.0,
	},
	"bow_volley": {
		"damage_mult": 1.0,
		"cooldown": 10.0,
		"range_tiles": 12.0,
		"spread_deg": 40.0,
		"volley_count": 5,
		"arrows_per_volley": 5,
		"ai_range_tiles": 10.0,
	},
	"staff_fireball": {
		"damage_mult": 3.0,
		"dot_mult_per_sec": 1.0,
		"cooldown": 10.0,
		"cast_time": 0.5,
		"range_tiles": 10.0,
		"radius_tiles": 3.5,
		"burn_radius_tiles": 3.5,
		"burn_duration": 3.0,
	},
}

## Table fields measured in tiles -> the SkillData property (in pixels) they set.
const TILE_FIELDS := {
	"range_tiles": "max_range",
	"radius_tiles": "radius",
	"burn_radius_tiles": "dot_radius",
	"ai_range_tiles": "ai_max_range",
}
## Table fields whose SkillData property has another name.
const RENAMED_FIELDS := {
	"burn_duration": "dot_duration",
}
## The volley is busy this long after its last volley leaves.
const VOLLEY_TAIL := 0.13


## Table row id of a skill: its .tres file name ("sword_spin").
static func id_of(skill: SkillData) -> String:
	return skill.resource_path.get_file().get_basename() if skill else ""


## A table value (tiles stay tiles), or `fallback` when the row or field is missing.
static func value(id: String, field: String, fallback: Variant = null) -> Variant:
	var row: Dictionary = TABLE.get(id, {})
	return row.get(field, fallback)


## Writes the table's numbers into a loaded skill, once (Weapons.get_weapon_data calls it).
static func apply(skill: SkillData) -> void:
	if skill == null or skill.has_meta(&"skills_table_applied"):
		return
	skill.set_meta(&"skills_table_applied", true)
	var row: Dictionary = TABLE.get(id_of(skill), {})
	for field in row:
		set_field(skill, field, row[field])


## Sets one table field on a skill (tiles converted to pixels), keeping linked values in step.
static func set_field(skill: SkillData, field: String, v: Variant) -> void:
	if TILE_FIELDS.has(field):
		skill.set(TILE_FIELDS[field], float(v) * SkillData.TILE)
	elif RENAMED_FIELDS.has(field):
		skill.set(RENAMED_FIELDS[field], v)
	else:
		skill.set(field, v)
	match skill.kind:
		SkillData.Kind.SPIN:
			if field == "radius_tiles":
				skill.max_range = skill.radius # the spin reaches as far as its circle
				skill.ai_max_range = skill.radius
		SkillData.Kind.VOLLEY:
			if field == "volley_count" or field == "volley_interval":
				skill.duration = skill.volley_interval * maxi(skill.volley_count - 1, 0) + VOLLEY_TAIL
