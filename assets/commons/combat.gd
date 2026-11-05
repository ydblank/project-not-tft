@tool
extends Node
class_name CombatGlobal

# Autoloaded as "Combat". Damage / speed formulas (static) plus global hitstop.

const HITSTOP_TIME_SCALE := 0.0 # full freeze frame

## Dev-tunable (pause menu): scales every hitstop duration and all damage dealt.
var hitstop_multiplier: float = 1.0
var damage_multiplier: float = 1.0

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


## Freezes the whole game for a moment (freeze frame). Unlike pausing the tree, input keeps flowing.
## Overlapping calls extend to the latest end time.
func hitstop(duration: float) -> void:
	duration *= hitstop_multiplier
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


# ---- camera shake ----

const SHAKE_MAX_OFFSET := 10.0

## Dev-tunable (pause menu): scales every camera shake.
var shake_multiplier: float = 1.0

var _shake_strength: float = 0.0
var _shake_duration: float = 0.0
var _shake_left: float = 0.0
var _shake_dir: Vector2 = Vector2.ZERO
var _shake_camera: Camera2D
var _last_usec: int = 0


## Camera jolt in screen pixels. `direction` biases the first kick along a hit.
## A new shake replaces a weaker running one.
func shake(strength: float, duration: float = 0.18, direction: Vector2 = Vector2.ZERO) -> void:
	if Engine.is_editor_hint():
		return
	strength = minf(strength * shake_multiplier, SHAKE_MAX_OFFSET)
	if strength <= 0.0 or duration <= 0.0:
		return
	if strength < _current_shake():
		return
	_shake_strength = strength
	_shake_duration = duration
	_shake_left = duration
	_shake_dir = direction.normalized()


func _current_shake() -> float:
	if _shake_duration <= 0.0:
		return 0.0
	return _shake_strength * (_shake_left / _shake_duration)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# Real time, so the shake keeps going through hitstop slow-motion.
	var now := Time.get_ticks_usec()
	var real_delta := float(now - _last_usec) / 1000000.0
	_last_usec = now
	if _shake_left <= 0.0:
		return
	var cam := get_viewport().get_camera_2d()
	if cam != _shake_camera:
		_reset_camera()
		_shake_camera = cam
	if cam == null:
		_shake_left = 0.0
		return
	_shake_left = maxf(_shake_left - real_delta, 0.0)
	var amount := _current_shake()
	var jitter := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	if _shake_dir != Vector2.ZERO:
		jitter = (_shake_dir * 1.2 + jitter * 0.6) * (1.0 if randf() > 0.5 else 0.6)
	cam.offset = jitter * amount / maxf(cam.zoom.x, 0.01)
	if _shake_left <= 0.0:
		_reset_camera()


func _reset_camera() -> void:
	if is_instance_valid(_shake_camera):
		_shake_camera.offset = Vector2.ZERO
