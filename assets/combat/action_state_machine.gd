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
# - Skill (weapon's SkillData, the E button): from IDLE, CHARGING, BLOCK or an attack's
#   recovery, when off cooldown. An aimed skill holds in SKILL_AIM until the button is
#   released (block cancels, no cooldown spent); an unaimed one casts on press. SKILL
#   lasts skill.cast_time + skill.duration. An unstoppable skill ignores stagger / knockback while it runs.
# - Ultimate (the class's row in Ultimates, the Q button): the meter (ult_charge, 0..1) is filled
#   from outside by add_ult_charge(). A press with a full meter starts it from any state but
#   DEAD / STAGGER / KNOCKBACK, with no state change of its own; it lasts the row's duration.
#   While it runs, the row's numbers change attack speed, skill cooldown and cast time, the heavy
#   charge time, auto heavies (Archer) and stun immunity (Knight).

enum State {IDLE, CHARGING, ATTACK, BLOCK, DASH, STAGGER, KNOCKBACK, DEAD, SKILL_AIM, SKILL}
enum Phase {NONE, STARTUP, ACTIVE, RECOVERY}
enum MoveMode {FREE, SLOWED, LOCKED, LUNGE, DASH, KNOCKBACK, SKILL_DASH}

const DIRECTION_COUNT := 8
const MIN_ATTACK_SPEED := 0.05
## A dash press made slightly too early still fires once the dash is possible.
const DASH_INPUT_BUFFER := 0.2
## A dash can chain into the next once this fraction of it has elapsed.
const DASH_CHAIN_PROGRESS := 0.5
## A skill press made while busy (stunned, mid-swing) still fires if the skill becomes possible this soon.
const SKILL_INPUT_BUFFER := 0.25

# ---- configuration ----
var weapon: WeaponData
var attack_speed: float = 1.0
var dash_duration: float = 0.2
## Pause after a dash ends before the next one (chaining gap).
var dash_cooldown: float = 0.5
## Dash charges. With recharge/reload times at 0 charges are not tracked (single dash).
var dash_max_charges: int = 1
## Seconds for each charge to come back, one at a time.
var dash_recharge_time: float = 0.0
## Slower return of the first charge after all were used in a row.
var dash_reload_time: float = 0.0
## That first charge comes back this many times faster (1 = as written above; the game's dev setting makes it 2).
var dash_first_charge_speedup: float = 1.0
## Multiplier on every skill cooldown (dev tuning).
var skill_cooldown_scale: float = 1.0
## This class's ultimate (Ultimates.row_for), empty = none.
var ultimate: Dictionary = {}
## Dev tuning: multiplier on meter gain and on the ultimate's duration.
var ult_charge_scale: float = 1.0
var ult_duration_scale: float = 1.0
## Dev tuning: the meter refills itself whenever the ultimate is not running.
var ult_always_full: bool = false

# ---- public state (read-only for other code) ----
var state: State = State.IDLE
var phase: Phase = Phase.NONE
var facing: Vector2 = Vector2.DOWN
var block_dir_index: int = 2 # 0 = RIGHT, clockwise (2 = DOWN)

var current_move: AttackMove = null
var current_is_heavy: bool = false
var current_charge_mult: float = 1.0
var current_is_final: bool = false
## Index of the heavy-combo hit currently playing (0 for single heavies).
var heavy_index: int = 0
var attack_dir: Vector2 = Vector2.DOWN
var attack_lunge_distance: float = 0.0
## Index of the light move currently playing (or last played).
var combo_index: int = 0
var charge_time: float = 0.0
var dash_dir: Vector2 = Vector2.DOWN
## The skill being cast (SKILL state), with its direction and aimed point.
var current_skill: SkillData = null
var skill_dir: Vector2 = Vector2.DOWN
var skill_target: Vector2 = Vector2.ZERO
## Ultimate meter, 0..1 (1 = ready).
var ult_charge: float = 0.0

# ---- internals ----
var _prev_attack_held: bool = false
var _prev_dash_held: bool = false
var _prev_skill_held: bool = false
var _prev_ult_held: bool = false
var _ult_time_left: float = 0.0
var _ult_time_total: float = 0.0
## Cast time of the running skill (the ultimate can shorten it).
var _current_cast_time: float = 0.0
var _skill_cooldown_left: float = 0.0
var _skill_cooldown_total: float = 0.0
var _skill_buffer_left: float = 0.0
var _press_active: bool = false
var _press_time: float = 0.0
var _heavy_pending: bool = false
var _stagger_dashable: bool = true
var _light_queued: bool = false
var _light_cooldown_left: float = 0.0
var _next_combo_index: int = 0
var _combo_timer: float = 0.0
var _phase_time_left: float = 0.0
var _state_time_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_buffer_left: float = 0.0
var _dash_charges: int = 1
var _recharge_left: float = 0.0
var _recharge_total: float = 0.0

## Parry: a block raised this recently (and not mashed) turns the first hit into a parry.
var parry_window: float = 0.2
## After letting go of block, the parry window is unavailable for this long (stops block-mashing).
var parry_cooldown: float = 0.45
## After a successful parry, a click starts a quick attack at once, even while still holding block (and ignoring the quick-combo cooldown) for this long.
var parry_counter_window: float = 0.7
var _counter_left: float = 0.0
var _block_age: float = 0.0
var _block_idle: float = 99.0 # seconds since block last ended
var _parry_armed: bool = false


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
## {type="skill_started", skill, dir, target} / {type="skill_ended", skill}
func tick(intent: CombatIntent, delta: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []

	var attack_pressed := intent.attack_held and not _prev_attack_held
	var attack_released := (not intent.attack_held) and _prev_attack_held
	var dash_pressed := intent.dash_held and not _prev_dash_held
	var skill_pressed := intent.skill_held and not _prev_skill_held
	var ult_pressed := intent.ultimate_held and not _prev_ult_held
	_prev_attack_held = intent.attack_held
	_prev_dash_held = intent.dash_held
	_prev_skill_held = intent.skill_held
	_prev_ult_held = intent.ultimate_held

	if state == State.DEAD:
		return events

	_tick_ultimate(ult_pressed, delta, events)
	# The Mage's ultimate runs the skill cooldown faster (a cooldown already running shrinks too).
	_skill_cooldown_left = maxf(_skill_cooldown_left - delta / maxf(float(_ult_value("cooldown_mult", 1.0)), 0.01), 0.0)
	_counter_left = maxf(_counter_left - delta, 0.0)
	if state == State.BLOCK:
		_block_age += delta
	else:
		_block_idle += delta
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	_light_cooldown_left = maxf(_light_cooldown_left - delta, 0.0)
	if _recharge_left > 0.0:
		_recharge_left = maxf(_recharge_left - delta, 0.0)
		if _recharge_left <= 0.0:
			# One charge comes back at a time, so a single dash is available early.
			_dash_charges = mini(_dash_charges + 1, dash_max_charges)
			if _dash_charges < dash_max_charges and dash_recharge_time > 0.0:
				_recharge_total = dash_recharge_time
				_recharge_left = _recharge_total
			elif _dash_charges < dash_max_charges:
				_dash_charges = dash_max_charges

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
		elif state == State.DASH and _press_time >= _charge_threshold():
			# Charged, dashed, then let go mid-dash: the heavy fires as the dash ends.
			_heavy_pending = true
			charge_time = _press_time
		elif _can_queue_light() and _light_cooldown_left <= _buffer_window():
			_light_queued = true

	# ---- dash: starts from almost any action; an early press is buffered ----
	if dash_pressed:
		_dash_buffer_left = DASH_INPUT_BUFFER
	else:
		_dash_buffer_left = maxf(_dash_buffer_left - delta, 0.0)
	if _dash_buffer_left > 0.0 and _can_start_dash():
		_dash_buffer_left = 0.0
		if state == State.ATTACK or state == State.BLOCK:
			_interrupt() # dash-cancel
		# A held heavy charge survives the dash (keeps charging, release after).
		_start_dash(intent, events)

	# ---- skill: aimed skills wait for the release, the others cast now ----
	# A press made while busy (stunned, mid-swing) is remembered for SKILL_INPUT_BUFFER.
	if skill_pressed:
		_skill_buffer_left = SKILL_INPUT_BUFFER
	else:
		_skill_buffer_left = maxf(_skill_buffer_left - delta, 0.0)
	if _skill_buffer_left > 0.0 and _can_start_skill():
		_skill_buffer_left = 0.0
		if state == State.ATTACK or state == State.CHARGING or state == State.BLOCK:
			_interrupt() # the skill cancels a charge, a block or an attack's recovery
			_set_state(State.IDLE)
		if weapon.skill.is_aimed() and intent.skill_held:
			facing = _aim(intent)
			_set_state(State.SKILL_AIM)
		else:
			_start_skill(intent, events)

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
			elif _ult_auto_heavy() and not intent.block_held:
				_press_active = false # the Archer's ultimate fires a charge at once
				_start_attack(true, intent, events)
			elif intent.block_held:
				_cancel_charge()
				_enter_block(intent)
			else:
				charge_time = _press_time

		State.ATTACK:
			_tick_attack(intent, delta, events)

		State.BLOCK:
			if attack_pressed and _counter_left > 0.0:
				# Parry counter: leave the block and swing right now.
				_counter_left = 0.0
				_light_cooldown_left = 0.0
				_light_queued = false
				_press_active = false
				_set_state(State.IDLE)
				facing = _aim(intent)
				_start_attack(false, intent, events)
			elif intent.block_held:
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

		State.SKILL_AIM:
			facing = _aim(intent)
			if intent.block_held:
				_set_state(State.IDLE) # cancelled: no cooldown spent
				_try_leave_idle(intent, false, events)
			elif not intent.skill_held:
				_start_skill(intent, events)

		State.SKILL:
			_state_time_left -= delta
			if _state_time_left <= 0.0:
				events.append({"type": "skill_ended", "skill": current_skill})
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
				if current_is_heavy and heavy_index + 1 < weapon.heavy_hit_count():
					# Heavy combo: the next hit follows on its own (no extra input).
					_start_attack(true, intent, events, heavy_index + 1, true)
				else:
					_finish_attack()
					_try_leave_idle(intent, false, events)


# IDLE transitions, in priority order.
func _try_leave_idle(intent: CombatIntent, dash_pressed: bool, events: Array[Dictionary]) -> void:
	if state != State.IDLE:
		return
	if intent.block_held:
		_enter_block(intent)
	elif dash_pressed and dash_ready():
		_start_dash(intent, events)
	elif _heavy_pending:
		_heavy_pending = false
		facing = _aim(intent)
		_start_attack(true, intent, events)
	elif _ult_auto_heavy() and (intent.attack_held or _light_queued) and _light_cooldown_left <= 0.0:
		# Archer ultimate: every shot is a heavy, with no charge-up; holding keeps firing.
		_light_queued = false
		_press_active = false
		facing = _aim(intent)
		_start_attack(true, intent, events)
	elif _press_active and _press_time >= _charge_threshold():
		_light_queued = false
		charge_time = _press_time
		facing = _aim(intent)
		_set_state(State.CHARGING)
	elif _light_queued and _light_cooldown_left <= 0.0:
		_light_queued = false
		_start_attack(false, intent, events)


# ======================================================================
# Actions
# ======================================================================

## heavy_idx / continuing: later hits of a heavy combo keep the charge multiplier
## of the first hit.
func _start_attack(is_heavy: bool, intent: CombatIntent, events: Array[Dictionary], heavy_idx: int = 0, continuing: bool = false) -> void:
	if weapon == null:
		_set_state(State.IDLE)
		return

	var move: AttackMove
	var index := 0
	if is_heavy:
		move = weapon.get_heavy_move(heavy_idx)
		heavy_index = heavy_idx
		index = heavy_idx
		if not continuing:
			var ratio := charge_ratio()
			if _ult_auto_heavy():
				ratio = clampf(float(_ult_value("auto_heavy_charge", 1.0)), 0.0, 1.0)
			current_charge_mult = lerpf(weapon.heavy_min_mult, weapon.heavy_max_mult, ratio)
	else:
		heavy_index = 0
		index = _next_combo_index if _combo_timer > 0.0 else 0
		index = clampi(index, 0, maxi(weapon.light_move_count() - 1, 0))
		move = weapon.get_light_move(index)
		current_charge_mult = 1.0

	if move == null:
		_set_state(State.IDLE)
		return

	current_move = move
	current_is_heavy = is_heavy
	if is_heavy:
		current_is_final = heavy_idx >= weapon.heavy_hit_count() - 1
	else:
		current_is_final = index >= weapon.light_move_count() - 1
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
	heavy_index = 0
	if current_is_heavy or current_is_final:
		_next_combo_index = 0
		_combo_timer = 0.0
		# Finished the whole quick combo: lock quick attacks for a moment.
		# The Archer's ultimate heavies keep the quick-shot pace, so they wait the same gap.
		if (not current_is_heavy or _ult_auto_heavy()) and weapon and weapon.light_combo_cooldown > 0.0:
			_light_cooldown_left = weapon.light_combo_cooldown / maxf(float(_ult_value("attack_speed_mult", 1.0)), MIN_ATTACK_SPEED)
			_light_queued = false
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
	_spend_dash_charge()
	_set_state(State.DASH)
	events.append({"type": "dash_started", "dir": dash_dir})


# Using the last charge restarts a slower full reload; otherwise the first use
# starts the normal recharge. With no recharge times configured, charges are
# not tracked (plain single dash with just the chaining gap).
func _spend_dash_charge() -> void:
	if dash_recharge_time <= 0.0 and dash_reload_time <= 0.0:
		return
	_dash_charges = maxi(_dash_charges - 1, 0)
	if _dash_charges <= 0:
		_recharge_total = maxf(dash_reload_time, dash_recharge_time) / maxf(dash_first_charge_speedup, 0.01)
		_recharge_left = _recharge_total
	elif _recharge_left <= 0.0:
		_recharge_total = dash_recharge_time
		_recharge_left = _recharge_total


func _refill_dash() -> void:
	_dash_charges = dash_max_charges
	_recharge_left = 0.0
	_recharge_total = 0.0
	_dash_cooldown_left = 0.0
	_dash_buffer_left = 0.0


func _start_skill(intent: CombatIntent, events: Array[Dictionary]) -> void:
	var sk := weapon.skill if weapon else null
	if sk == null:
		_set_state(State.IDLE)
		return
	_press_active = false
	_heavy_pending = false
	_light_queued = false
	_reset_combo()
	current_skill = sk
	skill_dir = _aim(intent)
	skill_target = intent.skill_target
	facing = skill_dir
	_skill_cooldown_total = maxf(sk.cooldown * skill_cooldown_scale, 0.0)
	_skill_cooldown_left = _skill_cooldown_total
	_current_cast_time = maxf(sk.cast_time * float(_ult_value("cast_time_mult", 1.0)), 0.0)
	_state_time_left = _current_cast_time + maxf(sk.duration, 0.0)
	_set_state(State.SKILL)
	events.append({"type": "skill_started", "skill": sk, "dir": skill_dir, "target": skill_target})


## Ends the running skill on the next tick (the dagger dash stops at its first hit or a wall).
func finish_skill() -> void:
	if state == State.SKILL:
		_state_time_left = 0.0


func _enter_block(intent: CombatIntent) -> void:
	_press_active = false
	_heavy_pending = false
	_light_queued = false
	_reset_combo()
	_update_block_dir(_aim(intent))
	_parry_armed = _block_idle >= parry_cooldown
	_block_age = 0.0
	_update_block_dir(_aim(intent))
	_set_state(State.BLOCK)


func _cancel_charge() -> void:
	_press_active = false
	charge_time = 0.0


# ======================================================================
# Reactions (called by CombatComponent when a hit lands)
# ======================================================================

## dashable: the victim may dash out of this stun (combo breaker). Guard breaks cannot.
## force: also stops an unstoppable skill (a parry stun).
func apply_stagger(duration: float, dashable: bool = true, force: bool = false) -> void:
	if state == State.DEAD or state == State.KNOCKBACK:
		return
	if ult_immune():
		return # the Knight's ultimate shrugs off every stun, a parry included
	if is_unstoppable() and not force:
		return
	_interrupt()
	_state_time_left = maxf(duration, 0.0)
	_stagger_dashable = dashable
	_set_state(State.STAGGER)


func apply_knockback(duration: float) -> void:
	if state == State.DEAD or is_unstoppable() or ult_immune():
		return
	_interrupt()
	_state_time_left = maxf(duration, 0.0)
	_set_state(State.KNOCKBACK)


func kill() -> void:
	_interrupt()
	_reset_ultimate()
	_set_state(State.DEAD)


## Swaps weapon / attack speed at runtime (loadout change): drops whatever
## attack, charge or combo was in progress.
func set_loadout(p_weapon: WeaponData, p_attack_speed: float) -> void:
	weapon = p_weapon
	attack_speed = p_attack_speed
	_reset_skill_cooldown()
	_reset_ultimate()
	if state == State.DEAD:
		return
	_interrupt()
	if state in [State.ATTACK, State.CHARGING, State.BLOCK, State.SKILL_AIM, State.SKILL]:
		_set_state(State.IDLE)


## Brings a DEAD machine back to IDLE (respawn).
func revive() -> void:
	if state != State.DEAD:
		return
	_interrupt()
	_prev_attack_held = false
	_prev_dash_held = false
	_prev_skill_held = false
	_prev_ult_held = false
	_refill_dash()
	_reset_skill_cooldown()
	_reset_ultimate()
	_set_state(State.IDLE)


func _reset_skill_cooldown() -> void:
	_skill_cooldown_left = 0.0
	_skill_cooldown_total = 0.0
	_skill_buffer_left = 0.0


# ======================================================================
# Ultimate
# ======================================================================

func _tick_ultimate(pressed: bool, delta: float, events: Array[Dictionary]) -> void:
	if _ult_time_left > 0.0:
		_ult_time_left = maxf(_ult_time_left - delta, 0.0)
		if _ult_time_left <= 0.0:
			events.append({"type": "ultimate_ended", "ultimate": ultimate})
		return
	if ult_always_full and not ultimate.is_empty():
		ult_charge = 1.0
	if pressed and _can_start_ultimate():
		ult_charge = 0.0
		_ult_time_total = maxf(float(ultimate.get("duration", 0.0)) * ult_duration_scale, 0.01)
		_ult_time_left = _ult_time_total
		events.append({"type": "ultimate_started", "ultimate": ultimate})


func _can_start_ultimate() -> bool:
	return ult_ready() and state != State.DEAD and state != State.STAGGER and state != State.KNOCKBACK


## Adds `amount` (share of a full meter, already scaled for HP) to the meter. Nothing while it runs.
func add_ult_charge(amount: float) -> void:
	if ultimate.is_empty() or ult_active() or state == State.DEAD or amount <= 0.0:
		return
	ult_charge = clampf(ult_charge + amount * ult_charge_scale, 0.0, 1.0)


## Empties the meter and ends a running ultimate (death, respawn, loadout change).
func _reset_ultimate() -> void:
	ult_charge = 0.0
	_ult_time_left = 0.0
	_ult_time_total = 0.0


## A field of the running ultimate's row, or `fallback` when no ultimate is running.
func _ult_value(field: String, fallback: Variant) -> Variant:
	if _ult_time_left <= 0.0:
		return fallback
	return ultimate.get(field, fallback)


func _ult_auto_heavy() -> bool:
	return bool(_ult_value("auto_heavy", false)) and weapon != null


## Sets this class's ultimate (Ultimates.row_for). An empty row = none.
func set_ultimate(row: Dictionary) -> void:
	ultimate = row
	_reset_ultimate()


func ult_ready() -> bool:
	return not ultimate.is_empty() and ult_charge >= 1.0 and not ult_active()


func ult_active() -> bool:
	return _ult_time_left > 0.0


func ult_time_left() -> float:
	return _ult_time_left


## 1.0 when it has just started, 0.0 when it is over.
func ult_time_ratio() -> float:
	if _ult_time_total <= 0.0:
		return 0.0
	return clampf(_ult_time_left / _ult_time_total, 0.0, 1.0)


## True while the Knight's ultimate runs: no damage, no stagger, no knockback.
func ult_immune() -> bool:
	return bool(_ult_value("immune", false))


## Walking speed multiplier of the running ultimate (1.0 without one).
func ult_move_speed_mult() -> float:
	return float(_ult_value("move_speed_mult", 1.0))


## True while single-target projectiles fly through this fighter (the Thief's ultimate).
func ult_dodges_projectiles() -> bool:
	return bool(_ult_value("dodge_projectiles", false))


func _interrupt() -> void:
	phase = Phase.NONE
	current_move = null
	_press_active = false
	_heavy_pending = false
	_light_queued = false
	charge_time = 0.0
	heavy_index = 0
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
	var scale := _charge_time_scale()
	var span := (weapon.max_charge_time - weapon.charge_threshold) * scale
	if span <= 0.0:
		return 1.0
	return clampf((charge_time - weapon.charge_threshold * scale) / span, 0.0, 1.0)


## The Mage's ultimate shortens the heavy charge (both the hold before charging and the full charge).
func _charge_time_scale() -> float:
	return maxf(float(_ult_value("charge_time_mult", 1.0)), 0.0)


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
		State.CHARGING, State.BLOCK, State.SKILL_AIM:
			return MoveMode.SLOWED
		State.ATTACK:
			return MoveMode.LUNGE if phase == Phase.STARTUP else MoveMode.LOCKED
		State.SKILL:
			if current_skill == null:
				return MoveMode.LOCKED
			match current_skill.kind:
				SkillData.Kind.SPIN, SkillData.Kind.VOLLEY:
					return MoveMode.SLOWED
				SkillData.Kind.DASH_STRIKE:
					return MoveMode.SKILL_DASH
			return MoveMode.LOCKED
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
	return _dash_cooldown_left <= 0.0 and _dash_charges > 0


## Dash is allowed out of idle, charging, attacking (dash-cancel), blocking and
## (breakable) stagger,
## and again mid-dash once the first one is half done. Not in knockback or dead.
func _can_start_dash() -> bool:
	if not dash_ready():
		return false
	match state:
		State.IDLE, State.CHARGING, State.ATTACK, State.BLOCK, State.SKILL_AIM:
			return true
		State.STAGGER:
			return _stagger_dashable # dash is the way out of a combo
		State.DASH:
			return _state_time_left <= dash_duration * DASH_CHAIN_PROGRESS
	return false


## Sets all dash tuning at once and refills the charges.
func configure_dash(duration: float, gap: float, max_charges: int, recharge_time: float, reload_time: float) -> void:
	dash_duration = duration
	dash_cooldown = gap
	dash_max_charges = maxi(max_charges, 1)
	dash_recharge_time = recharge_time
	dash_reload_time = reload_time
	_refill_dash()


func dash_charges() -> int:
	return _dash_charges


## 1.0 while dashing or right after, falling to 0.0 when the chaining gap is over.
func dash_cooldown_ratio() -> float:
	if state == State.DASH:
		return 1.0
	if dash_cooldown <= 0.0:
		return 0.0
	return clampf(_dash_cooldown_left / dash_cooldown, 0.0, 1.0)


## 1.0 right when a charge starts recharging (or a full reload starts), 0.0 when
## nothing is recharging.
func dash_recharge_ratio() -> float:
	if _recharge_left <= 0.0 or _recharge_total <= 0.0:
		return 0.0
	return clampf(_recharge_left / _recharge_total, 0.0, 1.0)


## True when the slow reload (all charges used in a row) is running.
func dash_is_reloading() -> bool:
	return _dash_charges <= 0 and _recharge_left > 0.0


## The weapon's skill (null when the weapon has none).
func get_skill() -> SkillData:
	return weapon.skill if weapon else null


## True when the skill exists and is off cooldown.
func skill_ready() -> bool:
	return get_skill() != null and _skill_cooldown_left <= 0.0


func skill_cooldown_left() -> float:
	return _skill_cooldown_left


## 1.0 right after casting, 0.0 when ready.
func skill_cooldown_ratio() -> float:
	if _skill_cooldown_left <= 0.0 or _skill_cooldown_total <= 0.0:
		return 0.0
	return clampf(_skill_cooldown_left / _skill_cooldown_total, 0.0, 1.0)


func is_skill_aiming() -> bool:
	return state == State.SKILL_AIM


## Seconds since the running skill was cast (0 outside SKILL).
func skill_elapsed() -> float:
	if state != State.SKILL or current_skill == null:
		return 0.0
	return maxf(_current_cast_time + current_skill.duration - _state_time_left, 0.0)


## Cast time of the running skill, after the ultimate's shortening (0 outside SKILL).
func skill_cast_time() -> float:
	return _current_cast_time if state == State.SKILL else 0.0


## True while casting a skill that hits cannot interrupt.
func is_unstoppable() -> bool:
	return state == State.SKILL and current_skill != null and current_skill.unstoppable


## A skill can start out of idle, a charge, a block or an attack's recovery, when off cooldown.
func _can_start_skill() -> bool:
	if not skill_ready():
		return false
	match state:
		State.IDLE, State.CHARGING, State.BLOCK:
			return true
		State.ATTACK:
			return phase == Phase.RECOVERY
	return false


static func direction_to_index(dir: Vector2) -> int:
	return posmod(roundi(dir.angle() / (TAU / DIRECTION_COUNT)), DIRECTION_COUNT)


static func index_to_direction(index: int) -> Vector2:
	return Vector2.RIGHT.rotated(index * TAU / DIRECTION_COUNT)


# ======================================================================
# Helpers
# ======================================================================

func _set_state(new_state: State) -> void:
	if state == State.BLOCK and new_state != State.BLOCK:
		_block_idle = 0.0
	if new_state != State.SKILL:
		current_skill = null
	state = new_state
	if new_state != State.ATTACK:
		phase = Phase.NONE


func _scaled(duration: float) -> float:
	return duration / maxf(attack_speed * float(_ult_value("attack_speed_mult", 1.0)), MIN_ATTACK_SPEED)


func _charge_threshold() -> float:
	return weapon.charge_threshold * _charge_time_scale() if weapon else INF


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


## A tap made this close to the end of the quick-combo cooldown is remembered.
func _buffer_window() -> float:
	return weapon.input_buffer if weapon else 0.0


## Seconds until quick attacks are available again after a full quick combo.
func light_cooldown_left() -> float:
	return _light_cooldown_left


## True while this fighter is mid-combo: swinging a non-final hit, or inside the
## window to continue a quick combo. Used to keep a hit victim locked in hitstun.
func in_combo() -> bool:
	if state == State.ATTACK:
		# The final swing still counts until it has landed (recovery = it is over).
		return not current_is_final or phase != Phase.RECOVERY
	return _combo_timer > 0.0 and _next_combo_index > 0 and state != State.DEAD


## Keeps a stagger running for at least `seconds` more (combo hitstun).
func hold_stagger(seconds: float) -> void:
	if state == State.STAGGER:
		_state_time_left = maxf(_state_time_left, seconds)


## True while staggered in a way a dash can escape (combo hitstun, not a guard break).
func can_dash_out() -> bool:
	return state == State.STAGGER and _stagger_dashable


## Called when a parry lands: opens the counter window (see parry_counter_window).
func grant_counter() -> void:
	_counter_left = parry_counter_window
	_light_cooldown_left = 0.0


## True while a click will start an instant counter-attack.
func is_counter_open() -> bool:
	return _counter_left > 0.0


## True during the first moments of a fresh block (see parry_window): a hit landing now is parried.
func is_parrying() -> bool:
	return state == State.BLOCK and _parry_armed and _block_age <= parry_window


## 0 at the start of an attack's wind-up, 1 when it is about to land (0 outside the wind-up).
func startup_progress() -> float:
	if state != State.ATTACK or phase != Phase.STARTUP or current_move == null:
		return 0.0
	var total := _scaled(current_move.startup)
	if total <= 0.0:
		return 1.0
	return clampf(1.0 - _phase_time_left / total, 0.0, 1.0)
