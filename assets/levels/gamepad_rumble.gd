extends Node
class_name GamepadRumble

# Controller rumble for Player 1. It watches the fighter you control and vibrates the pad when something
# happens: you take a hit, block, parry, land a hit, swing a heavy attack, dash, cast a skill, charge a shot to
# full, or die. It only buzzes while you are actually using the controller (GamepadControls on and a stick or
# button used more recently than the mouse), so a keyboard player with a pad plugged in feels nothing.
#
# Two motors: "strong" is the heavy, low-frequency one (thuds, weight), "weak" is the light, high-frequency one
# (sharp taps). The strength is the "Controller rumble" setting (Settings > Controls); 0 turns it off.
# Every vibration goes through _vibrate(), which keeps a big rumble from being cut short by a small one.

## Seconds a sustained rumble (the charge hum) is refreshed for each frame.
const HUM_TIME := 0.1
## The charge hum peaks at this strength (the heavy motor) when the shot is nearly full.
const HUM_MAX := 0.3

var _player: Node2D
var _combat: CombatComponent
var _hitbox: HitboxComponent
var _health: HealthComponent
var _active_until: float = 0.0 # seconds (Time.get_ticks_msec / 1000) the current rumble lasts
var _active_power: float = 0.0
var _was_full: bool = false


func _process(_delta: float) -> void:
	if _combat != null and not is_instance_valid(_combat):
		_combat = null # the fighter we were watching was freed
		_hitbox = null
		_health = null
	var player := _find_player()
	if player != _player:
		_bind(player)
	_charge_hum()


## Vibrates every recognised pad. `weak` and `strong` are 0..1 before the player's strength setting is applied.
## A rumble that is weaker than the one still running is dropped (hum = true: the quiet charge hum, which never
## replaces anything).
func _vibrate(weak: float, strong: float, duration: float, hum: bool = false) -> void:
	var scale := _strength()
	if scale <= 0.0 or not _pad_in_use():
		return
	var power := maxf(weak, strong) * scale
	var now := Time.get_ticks_msec() / 1000.0
	if now < _active_until and (hum or power < _active_power * 0.9):
		return
	_active_power = power
	_active_until = now + duration
	for device in Input.get_connected_joypads():
		if Input.is_joy_known(device):
			Input.start_joy_vibration(device, clampf(weak * scale, 0.0, 1.0), clampf(strong * scale, 0.0, 1.0), duration)


func _strength() -> float:
	return float(DevSettings.get_value("rumble_strength"))


func _pad_in_use() -> bool:
	if not GamepadControls.active or _combat == null:
		return false
	var controller := _combat.controller as PlayerController
	return controller != null and controller.is_pad_in_use()


func _find_player() -> Node2D:
	for node in get_tree().get_nodes_in_group("players"):
		var candidate := node as Node2D
		if candidate and candidate.is_multiplayer_authority():
			return candidate
	return null


## Connects to the fighter you control (and lets go of the previous one after a character switch).
func _bind(player: Node2D) -> void:
	_unbind()
	_player = player
	_was_full = false
	if player == null:
		return
	_combat = CombatComponent.find_on(player)
	if _combat == null:
		return
	_hitbox = _combat.hitbox_component
	_health = _combat.health_component
	if _hitbox:
		_hitbox.hit_received.connect(_on_hit_received)
		_hitbox.blocked_hit.connect(_on_blocked_hit)
		_hitbox.parried.connect(_on_parried)
	_combat.hit_landed.connect(_on_hit_landed)
	_combat.attack_started.connect(_on_attack_started)
	_combat.state_changed.connect(_on_state_changed)
	_combat.clashed.connect(_on_clashed)
	_combat.armor_broken.connect(_on_armor_broken)


func _unbind() -> void:
	if is_instance_valid(_hitbox):
		_hitbox.hit_received.disconnect(_on_hit_received)
		_hitbox.blocked_hit.disconnect(_on_blocked_hit)
		_hitbox.parried.disconnect(_on_parried)
	if is_instance_valid(_combat):
		_combat.hit_landed.disconnect(_on_hit_landed)
		_combat.attack_started.disconnect(_on_attack_started)
		_combat.state_changed.disconnect(_on_state_changed)
		_combat.clashed.disconnect(_on_clashed)
		_combat.armor_broken.disconnect(_on_armor_broken)
	_combat = null
	_hitbox = null
	_health = null


# ---------------------------------------------------------------- events

## You were hurt: a thud that grows with how much of your health the hit took.
func _on_hit_received(_attacker: Node, damage: float, _direction: Vector2) -> void:
	var max_hp := _health.get_max_hp() if _health else 100.0
	var share := clampf(damage / maxf(max_hp, 1.0), 0.0, 1.0)
	var strong := clampf(0.35 + share * 2.5, 0.35, 1.0)
	_vibrate(strong * 0.5, strong, 0.18 + share * 0.5)


## A blocked hit: a short dull thud (heavier for a heavy hit).
func _on_blocked_hit(_direction: Vector2, is_heavy: bool) -> void:
	_vibrate(0.15, 0.8 if is_heavy else 0.45, 0.2 if is_heavy else 0.12)


## A parry: a sharp, bright snap.
func _on_parried(_direction: Vector2) -> void:
	_vibrate(1.0, 0.3, 0.14)


## You landed a hit: a light tap.
func _on_hit_landed(_target: Node2D, result: int) -> void:
	if result == HitboxComponent.Result.HIT:
		_vibrate(0.35, 0.25, 0.07)


## A heavy attack swings: a weighty thump.
func _on_attack_started(_move: AttackMove, is_heavy: bool) -> void:
	if is_heavy:
		_vibrate(0.2, 0.55, 0.15)


## Dash, skill cast and death.
func _on_state_changed(_from: ActionStateMachine.State, to: ActionStateMachine.State) -> void:
	match to:
		ActionStateMachine.State.DASH:
			_vibrate(0.35, 0.0, 0.06)
		ActionStateMachine.State.SKILL:
			_vibrate(0.5, 0.6, 0.22)
		ActionStateMachine.State.DEAD:
			_vibrate(0.6, 1.0, 0.7)


func _on_clashed(_position: Vector2) -> void:
	_vibrate(0.7, 0.6, 0.15)


func _on_armor_broken() -> void:
	_vibrate(0.8, 0.45, 0.25)


## While you charge a shot or a heavy attack, a low hum builds with the charge, and a sharp pulse says "full".
func _charge_hum() -> void:
	if _combat == null:
		return
	if _combat.get_state() != ActionStateMachine.State.CHARGING:
		_was_full = false
		return
	var ratio := _combat.get_charge_ratio()
	if ratio >= 1.0:
		if not _was_full:
			_was_full = true
			_vibrate(0.8, 0.2, 0.1)
		return
	_vibrate(0.0, HUM_MAX * ratio * ratio, HUM_TIME, true)
