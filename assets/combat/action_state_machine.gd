@tool
extends RefCounted
class_name ActionStateMachine

# Pure combat state logic: no nodes, no physics, no input singletons.
# CombatComponent feeds it a CombatIntent every physics frame and applies the
# returned events. Hit reactions come in through apply_stagger / apply_knockback.
#
# Rules (see the combat plan):
# - Tap attack (released before charge_threshold) = next light move of the combo.
# - Hold attack >= charge_threshold = CHARGING; release = one heavy move.
# - A tap made while attacking or dashing is queued and fires when that ends.
# - After a light move's recovery, the next tap continues the combo within combo_window.
# - Block (held) from IDLE or CHARGING; no attack/dash while blocking.
# - Dash (pressed) from IDLE or CHARGING; cooldown starts when the dash ends.
# - Stagger/knockback interrupt everything and reset the combo.

enum State {IDLE, CHARGING, ATTACK, BLOCK, DASH, STAGGER, KNOCKBACK, DEAD}
enum Phase {NONE, STARTUP, ACTIVE, RECOVERY}
enum MoveMode {FREE, SLOWED, LOCKED, LUNGE, DASH, KNOCKBACK}

const DIRECTION_COUNT := 8
const MIN_ATTACK_SPEED := 0.05

# ---- configuration ----
var weapon: WeaponData
var attack_speed: float = 1.0
var dash_duration: float = 0.2
var dash_cooldown: float = 0.5

# ---- public state (read-only for other code) ----
var state: State = State.IDLE
var phase: Phase = Phase.NONE
var facing: Vector2 = Vector2.DOWN
var block_dir_index: int = 2 # 0 = RIGHT, clockwise (2 = DOWN)

var current_move: AttackMove = null
var current_is_heavy: bool = false
var current_charge_mult: float = 1.0
var current_is_final: bool = false
var attack_dir: Vector2 = Vector2.DOWN
var attack_lunge_distance: float = 0.0
## Index of the light move currently playing (or last played).
var combo_index: int = 0
var charge_time: float = 0.0
var dash_dir: Vector2 = Vector2.DOWN

# ---- internals ----
var _prev_attack_held: bool = false
var _prev_dash_held: bool = false
var _press_active: bool = false
var _press_time: float = 0.0
var _light_queued: bool = false
var _next_combo_index: int = 0
var _combo_timer: float = 0.0
var _phase_time_left: float = 0.0
var _state_time_left: float = 0.0
var _dash_cooldown_left: float = 0.0


func _init(p_weapon: WeaponData = null, p_attack_speed: float = 1.0) -> void:
	weapon = p_weapon
	attack_speed = p_attack_speed


# ======================================================================
# Tick
# ======================================================================

## Advances the machine by delta. Returns events as dictionaries:
## {type="attack_started", move, is_heavy, charge_mult, combo_index, is_final, dir}
## {type="active_started"} / {type="active_ended"}
## {type="dash_started", dir}
func tick(intent: CombatIntent, delta: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []

	var attack_pressed := intent.attack_held and not _prev_attack_held
	var attack_released := (not intent.attack_held) and _prev_attack_held
	var dash_pressed := intent.dash_held and not _prev_dash_held
	_prev_attack_held = intent.attack_held
	_prev_dash_held = intent.dash_held

	if state == State.DEAD:
		return events

	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)

	# ---- attack button tracking (independent of state) ----
	var heavy_release := false
	if attack_pressed:
		if _can_track_attack_press():
			_press_active = true
			_press_time = 0.0
	elif _press_active and intent.attack_held:
		_press_time += delta

	if attack_released and _press_active:
		_press_active = false
		if state == State.CHARGING:
			heavy_release = true
		elif _can_queue_light():
			_light_queued = true

	# ---- state logic ----
	match state:
		State.IDLE:
			_combo_timer = maxf(_combo_timer - delta, 0.0)
			if _combo_timer <= 0.0:
				_next_combo_index = 0
			_update_free_facing(intent)
			_try_leave_idle(intent, dash_pressed, events)

		State.CHARGING:
			facing = _aim(intent)
			if heavy_release:
				_start_attack(true, intent, events)
			elif intent.block_held:
				_cancel_charge()
				_enter_block(intent)
			elif dash_pressed and _dash_cooldown_left <= 0.0:
				_cancel_charge()
				_start_dash(intent, events)
			else:
				charge_time = _press_time

		State.ATTACK:
			_tick_attack(intent, delta, events)

		State.BLOCK:
			if intent.block_held:
				_update_block_dir(_aim(intent))
			else:
				_set_state(State.IDLE)
				_try_leave_idle(intent, false, events)

		State.DASH:
			_state_time_left -= delta
			if _state_time_left <= 0.0:
				_dash_cooldown_left = dash_cooldown
				_set_state(State.IDLE)
				_try_leave_idle(intent, false, events)

		State.STAGGER, State.KNOCKBACK:
			_state_time_left -= delta
			if _state_time_left <= 0.0:
				_set_state(State.IDLE)
				_try_leave_idle(intent, false, events)

	return events


func _tick_attack(intent: CombatIntent, delta: float, events: Array[Dictionary]) -> void:
	_phase_time_left -= delta
	while state == State.ATTACK and _phase_time_left <= 0.0:
		match phase:
			Phase.STARTUP:
				phase = Phase.ACTIVE
				_phase_time_left += _scaled(current_move.active)
				events.append({"type": "active_started"})
			Phase.ACTIVE:
				phase = Phase.RECOVERY
				_phase_time_left += _scaled(current_move.recovery)
				events.append({"type": "active_ended"})
			Phase.RECOVERY:
				_finish_attack()
				_try_leave_idle(intent, false, events)


# IDLE transitions, in priority order.
func _try_leave_idle(intent: CombatIntent, dash_pressed: bool, events: Array[Dictionary]) -> void:
	if state != State.IDLE:
		return
	if intent.block_held:
		_enter_block(intent)
	elif dash_pressed and _dash_cooldown_left <= 0.0:
		_start_dash(intent, events)
	elif _press_active and _press_time >= _charge_threshold():
		_light_queued = false
		charge_time = _press_time
		facing = _aim(intent)
		_set_state(State.CHARGING)
	elif _light_queued:
		_light_queued = false
		_start_attack(false, intent, events)


# ======================================================================
# Actions
# ======================================================================

func _start_attack(is_heavy: bool, intent: CombatIntent, events: Array[Dictionary]) -> void:
	if weapon == null:
		_set_state(State.IDLE)
		return

	var move: AttackMove
	var index := 0
	if is_heavy:
		move = weapon.heavy_move
		current_charge_mult = lerpf(weapon.heavy_min_mult, weapon.heavy_max_mult, charge_ratio())
	else:
		index = _next_combo_index if _combo_timer > 0.0 else 0
		index = clampi(index, 0, maxi(weapon.light_move_count() - 1, 0))
		move = weapon.get_light_move(index)
		current_charge_mult = 1.0

	if move == null:
		_set_state(State.IDLE)
		return

	current_move = move
	current_is_heavy = is_heavy
	current_is_final = is_heavy or index >= weapon.light_move_count() - 1
	combo_index = index
	_combo_timer = 0.0
	attack_dir = _aim(intent)
	facing = attack_dir
	attack_lunge_distance = minf(move.lunge_distance, maxf(intent.lunge_limit, 0.0))
	charge_time = 0.0

	_set_state(State.ATTACK)
	phase = Phase.STARTUP
	_phase_time_left = _scaled(move.startup)

	events.append({
		"type": "attack_started",
		"move": move,
		"is_heavy": is_heavy,
		"charge_mult": current_charge_mult,
		"combo_index": index,
		"is_final": current_is_final,
		"dir": attack_dir,
	})


func _finish_attack() -> void:
	if current_is_heavy or current_is_final:
		_next_combo_index = 0
		_combo_timer = 0.0
	else:
		_next_combo_index = combo_index + 1
		_combo_timer = weapon.combo_window
	phase = Phase.NONE
	current_move = null
	_set_state(State.IDLE)


func _start_dash(intent: CombatIntent, events: Array[Dictionary]) -> void:
	dash_dir = intent.move_dir.normalized() if intent.move_dir != Vector2.ZERO else facing
	if dash_dir == Vector2.ZERO:
		dash_dir = Vector2.DOWN
	facing = dash_dir
	_reset_combo()
	_light_queued = false
	_state_time_left = dash_duration
	_set_state(State.DASH)
	events.append({"type": "dash_started", "dir": dash_dir})


func _enter_block(intent: CombatIntent) -> void:
	_press_active = false
	_light_queued = false
	_reset_combo()
	_update_block_dir(_aim(intent))
	_set_state(State.BLOCK)


func _cancel_charge() -> void:
	_press_active = false
	charge_time = 0.0


# ======================================================================
# Reactions (called by CombatComponent when a hit lands)
# ======================================================================

func apply_stagger(duration: float) -> void:
	if state == State.DEAD or state == State.KNOCKBACK:
		return
	_interrupt()
	_state_time_left = maxf(duration, 0.0)
	_set_state(State.STAGGER)


func apply_knockback(duration: float) -> void:
	if state == State.DEAD:
		return
	_interrupt()
	_state_time_left = maxf(duration, 0.0)
	_set_state(State.KNOCKBACK)


func kill() -> void:
	_interrupt()
	_set_state(State.DEAD)


func _interrupt() -> void:
	phase = Phase.NONE
	current_move = null
	_press_active = false
	_light_queued = false
	charge_time = 0.0
	_reset_combo()


func _reset_combo() -> void:
	_next_combo_index = 0
	_combo_timer = 0.0


# ======================================================================
# Queries
# ======================================================================

func charge_ratio() -> float:
	if weapon == null:
		return 0.0
	var span := weapon.max_charge_time - weapon.charge_threshold
	if span <= 0.0:
		return 1.0
	return clampf((charge_time - weapon.charge_threshold) / span, 0.0, 1.0)


func is_blocking() -> bool:
	return state == State.BLOCK


## from_dir: direction the hit comes FROM (victim → attacker).
func is_blocking_from(from_dir: Vector2) -> bool:
	if state != State.BLOCK or from_dir == Vector2.ZERO:
		return false
	var diff := wrapi(direction_to_index(from_dir) - block_dir_index, -4, 4)
	return absi(diff) <= 1


func block_direction() -> Vector2:
	return index_to_direction(block_dir_index)


func movement_mode() -> MoveMode:
	match state:
		State.IDLE:
			return MoveMode.FREE
		State.CHARGING, State.BLOCK:
			return MoveMode.SLOWED
		State.ATTACK:
			return MoveMode.LUNGE if phase == Phase.STARTUP else MoveMode.LOCKED
		State.DASH:
			return MoveMode.DASH
		State.KNOCKBACK:
			return MoveMode.KNOCKBACK
	return MoveMode.LOCKED


## Velocity during the startup lunge.
func lunge_velocity() -> Vector2:
	if state != State.ATTACK or phase != Phase.STARTUP or current_move == null:
		return Vector2.ZERO
	var startup := _scaled(current_move.startup)
	if startup <= 0.0:
		return Vector2.ZERO
	return attack_dir * (attack_lunge_distance / startup)


func is_in_combo_window() -> bool:
	return state == State.IDLE and _combo_timer > 0.0


func dash_ready() -> bool:
	return _dash_cooldown_left <= 0.0


static func direction_to_index(dir: Vector2) -> int:
	return posmod(roundi(dir.angle() / (TAU / DIRECTION_COUNT)), DIRECTION_COUNT)


static func index_to_direction(index: int) -> Vector2:
	return Vector2.RIGHT.rotated(index * TAU / DIRECTION_COUNT)


# ======================================================================
# Helpers
# ======================================================================

func _set_state(new_state: State) -> void:
	state = new_state
	if new_state != State.ATTACK:
		phase = Phase.NONE


func _scaled(duration: float) -> float:
	return duration / maxf(attack_speed, MIN_ATTACK_SPEED)


func _charge_threshold() -> float:
	return weapon.charge_threshold if weapon else INF


func _aim(intent: CombatIntent) -> Vector2:
	return intent.aim_dir.normalized() if intent.aim_dir != Vector2.ZERO else facing


func _update_free_facing(intent: CombatIntent) -> void:
	if intent.move_dir != Vector2.ZERO:
		facing = intent.move_dir.normalized()


func _update_block_dir(aim: Vector2) -> void:
	block_dir_index = direction_to_index(aim)
	facing = index_to_direction(block_dir_index)


# A new attack press starts tracking unless blocking or reacting to a hit.
func _can_track_attack_press() -> bool:
	return state == State.IDLE or state == State.ATTACK or state == State.DASH or state == State.CHARGING


func _can_queue_light() -> bool:
	return state == State.IDLE or state == State.ATTACK or state == State.DASH
