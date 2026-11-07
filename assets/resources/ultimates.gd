@tool
extends Resource
class_name Ultimates

# Ultimate balance table (GAM-23): one ultimate per class, on Q (RB on a controller).
# Edit the numbers here; ActionStateMachine and CombatComponent read them through row_for().
#
# The meter fills from hits you land on an enemy's health. Each hit adds its own multiplier
# (a sword quick hit 0.5, a full bow draw 2.0, a skill's damage_mult, a burning tick's share),
# never its damage, so a high-power class does not fill faster just from its stats.
# Below low_hp_threshold of your HP the gain ramps up, to low_hp_max_mult at 0 HP.
# Nothing is gained while the ultimate runs.
#
# Fields (DEFAULTS apply to every class; a class row overrides any of them):
#   name               shown on activation
#   color              the aura colour while active
#   charge_points      sum of hit multipliers that fills the meter
#   duration           seconds the ultimate lasts
#   low_hp_threshold   HP share below which the gain speeds up
#   low_hp_max_mult    gain multiplier at 0 HP
#   immune             no damage, no stagger, no knockback (Knight)
#   move_speed_mult    walking speed multiplier
#   attack_speed_mult  attack speed multiplier (move times and the quick-combo cooldown)
#   dodge_projectiles  single-target projectiles fly through (AoE still hits) (Thief)
#   auto_heavy         every attack is a heavy, no charge-up; hold to keep firing at the quick-shot pace (Archer)
#   auto_heavy_charge  how charged those heavies are, 0..1 of a full charge. The bow's heavy is 1.5x and a
#                      full charge 2.0x on top (3x a quick shot); 0.6 gives about 2.1x, steady rather than burst
#   cooldown_mult      skill cooldown multiplier (also speeds up a cooldown already running)
#   cast_time_mult     skill cast time multiplier
#   charge_time_mult   heavy charge time multiplier

const DEFAULTS := {
	"name": "Ultimate",
	"color": Color(1.0, 0.25, 0.2),
	"charge_points": 10.0,
	"duration": 5.0,
	"low_hp_threshold": 0.5,
	"low_hp_max_mult": 2.0,
	"immune": false,
	"move_speed_mult": 1.0,
	"attack_speed_mult": 1.0,
	"dodge_projectiles": false,
	"auto_heavy": false,
	"auto_heavy_charge": 1.0,
	"cooldown_mult": 1.0,
	"cast_time_mult": 1.0,
	"charge_time_mult": 1.0,
}

const TABLE := {
	Classes.CLASSES.KNIGHT: {
		"name": "Unbreakable",
		"color": Color(1.0, 0.8, 0.3),
		"immune": true,
		"move_speed_mult": 1.2,
	},
	Classes.CLASSES.THIEF: {
		"name": "Shadow Rush",
		"color": Color(0.75, 0.4, 1.0),
		"move_speed_mult": 1.4,
		"attack_speed_mult": 1.4,
		"dodge_projectiles": true,
	},
	Classes.CLASSES.ARCHER: {
		"name": "Deadeye",
		"color": Color(0.45, 1.0, 0.45),
		"auto_heavy": true,
		"auto_heavy_charge": 0.6,
	},
	Classes.CLASSES.MAGE: {
		"name": "Arcane Surge",
		"color": Color(0.4, 0.7, 1.0),
		"cooldown_mult": 0.25,
		"cast_time_mult": 0.25,
		"charge_time_mult": 0.25,
	},
}


## True when this class has an ultimate.
static func has_ultimate(cls: int) -> bool:
	return TABLE.has(cls)


## The full row for a class: DEFAULTS with the class's own values on top, plus "class".
## Empty for a class without an ultimate.
static func row_for(cls: int) -> Dictionary:
	if not TABLE.has(cls):
		return {}
	var row := DEFAULTS.duplicate()
	row.merge(TABLE[cls], true)
	row["class"] = cls
	return row


## Gain multiplier for the attacker's HP share: 1.0 above the threshold, rising to low_hp_max_mult at 0 HP.
static func hp_mult(hp_ratio: float, row: Dictionary) -> float:
	var threshold: float = row.get("low_hp_threshold", DEFAULTS.low_hp_threshold)
	var max_mult: float = row.get("low_hp_max_mult", DEFAULTS.low_hp_max_mult)
	if threshold <= 0.0 or hp_ratio >= threshold:
		return 1.0
	return lerpf(max_mult, 1.0, clampf(hp_ratio / threshold, 0.0, 1.0))


## Meter gain (0..1 of a full meter) for a hit worth `points` landed at `hp_ratio` of the attacker's HP.
static func charge_gain(points: float, hp_ratio: float, row: Dictionary) -> float:
	var needed: float = row.get("charge_points", DEFAULTS.charge_points)
	if needed <= 0.0 or points <= 0.0:
		return 0.0
	return points * hp_mult(hp_ratio, row) / needed
