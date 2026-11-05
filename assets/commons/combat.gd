@tool
extends Node
class_name CombatGlobal

# Autoloaded as "Combat". Damage / speed formulas (static) plus global hitstop.

const HITSTOP_TIME_SCALE := 0.05

var _hitstop_end_msec: int = 0
var _hitstop_token: int = 0


# ---- pure formulas (unit-tested) ----

## Base attack speed (base + class bonus) + weapon bonus, additive.
static func attack_speed(entity_attack_speed: float, weapon: WeaponData) -> float:
	var weapon_bonus: float = weapon.attack_speed_bonus if weapon else 0.0
	return maxf(entity_attack_speed + weapon_bonus, 0.001)


## str × weapon base damage, at least 1.
static func attack_damage(entity_str: float, weapon: WeaponData) -> float:
	var weapon_dmg: float = weapon.base_damage if weapon else 0.0
	return maxf(entity_str * weapon_dmg, 1.0)


## Damage after defense (percent), at least 1.
static func receive_damage(defense: float, received_damage: float) -> float:
	return maxf((1.0 - defense / 100.0) * received_damage, 1.0)


# ---- StatsComponent wrappers ----

static func calculate_attack_speed(stats: StatsComponent) -> float:
	if stats == null:
		return 1.0
	return attack_speed(float(stats.get_entity_stats().get("attack_speed", 1.0)), stats.get_weapon_data())


static func calculate_attack_damage(stats: StatsComponent) -> float:
	if stats == null:
		return 1.0
	return attack_damage(float(stats.get_entity_stats().get("str", 1.0)), stats.get_weapon_data())


static func calculate_receive_damage(stats: StatsComponent, received_damage: float) -> float:
	if stats == null:
		return received_damage
	return receive_damage(float(stats.get_entity_stats().get("def", 0)), received_damage)


## Briefly slows the whole game. Unlike pausing the tree, input keeps flowing.
## Overlapping calls extend to the latest end time.
func hitstop(duration: float) -> void:
	if duration <= 0.0:
		return
	var end_msec := Time.get_ticks_msec() + int(duration * 1000.0)
	if end_msec <= _hitstop_end_msec:
		return
	_hitstop_end_msec = end_msec
	_hitstop_token += 1
	var token := _hitstop_token
	Engine.time_scale = HITSTOP_TIME_SCALE
	await get_tree().create_timer(duration, true, false, true).timeout
	# Only the call that set the latest end time restores the time scale.
	if token == _hitstop_token:
		Engine.time_scale = 1.0
