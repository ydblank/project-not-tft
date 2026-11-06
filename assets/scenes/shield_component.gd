extends Node2D
class_name ShieldComponent

# Shield HP meter for blocking (ported from the old shield system onto the
# ActionStateMachine): blocking itself is the BLOCK state; this node only
# tracks how much the shield can still take.
#
# - HitboxComponent routes blocked damage through absorb_damage().
# - At 0 HP the shield breaks: shield_broken fires (CombatComponent staggers
#   the owner) and blocking is unavailable until it has fully recovered.
# - Regenerates while not blocking, after a short delay since the last hit.

signal shield_broken()
signal shield_changed(value: float, max_value: float)

@export var combat_component: CombatComponent
@export var shield_bar: ShieldBarComponent

@export_group("Shield HP")
@export var max_shield_hp: float = 14.0
@export var regen_per_sec: float = 2.0
@export var regen_delay_after_hit: float = 0.5
## While broken, recovers this fraction of max HP per second.
@export var broken_recover_percent_per_sec: float = 0.5

@export_group("Blocking")
## Multiplier on damage dealt to the shield.
@export var damage_mult_while_blocking: float = 1.0
## Stagger applied to the owner when the shield breaks (replaces the hit's
## normal knockback/stagger reaction).
@export var stun_duration: float = 2.0

@export_group("Debug")
@export var debug_shield: bool = false

var shield_hp: float = 0.0
var _is_broken: bool = false
var _regen_delay_timer: float = 0.0


func _ready() -> void:
	shield_hp = max_shield_hp
	if shield_bar:
		shield_bar.init_shield(max_shield_hp)


func _process(delta: float) -> void:
	if _is_broken:
		_set_hp(shield_hp + max_shield_hp * broken_recover_percent_per_sec * delta)
		if shield_hp >= max_shield_hp:
			_is_broken = false
		return

	if _is_blocking():
		return
	if _regen_delay_timer > 0.0:
		_regen_delay_timer = maxf(_regen_delay_timer - delta, 0.0)
	elif shield_hp < max_shield_hp:
		_set_hp(shield_hp + regen_per_sec * delta)


## Full shield, no longer broken (respawn).
func reset() -> void:
	_is_broken = false
	_regen_delay_timer = 0.0
	_set_hp(max_shield_hp)


func can_block() -> bool:
	return not _is_broken and shield_hp > 0.0


func is_broken() -> bool:
	return _is_broken


## Drains the shield; returns the damage that gets through to health.
func absorb_damage(dmg: float) -> float:
	if dmg <= 0.0:
		return 0.0
	_regen_delay_timer = regen_delay_after_hit

	var before := shield_hp
	var absorbed := minf(shield_hp, dmg)
	_set_hp(shield_hp - absorbed)
	var leftover := dmg - absorbed

	if shield_hp <= 0.0 and not _is_broken:
		_is_broken = true
		shield_broken.emit()

	if debug_shield:
		print("[SHIELD] before=", snappedf(before, 0.01), " dmg_in=", snappedf(dmg, 0.01),
			" after=", snappedf(shield_hp, 0.01), " leftover=", snappedf(leftover, 0.01),
			" broken=", _is_broken)
	return leftover


func _is_blocking() -> bool:
	return combat_component != null and combat_component.get_state() == ActionStateMachine.State.BLOCK


func _set_hp(value: float) -> void:
	shield_hp = clampf(value, 0.0, max_shield_hp)
	if shield_bar:
		shield_bar.shield = shield_hp
	shield_changed.emit(shield_hp, max_shield_hp)
