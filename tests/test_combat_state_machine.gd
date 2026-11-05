@tool
extends McpTestSuite

const SM := preload("res://assets/combat/action_state_machine.gd")
const DT := 1.0 / 60.0

# Light move: 0.1 + 0.1 + 0.15 = 0.35s. Heavy: 0.15 + 0.12 + 0.25 = 0.52s.
const LIGHT_TOTAL := 0.35
const HEAVY_TOTAL := 0.52


func suite_name() -> String:
	return "combat_state_machine"


# ---------------------------------------------------------------- helpers

func _move(startup := 0.1, active := 0.1, recovery := 0.15, lunge := 10.0) -> AttackMove:
	var m := AttackMove.new()
	m.startup = startup
	m.active = active
	m.recovery = recovery
	m.lunge_distance = lunge
	return m


func _weapon(light_count := 3) -> WeaponData:
	var w := WeaponData.new()
	var moves: Array[AttackMove] = []
	for i in light_count:
		moves.append(_move())
	w.light_moves = moves
	w.heavy_move = _move(0.15, 0.12, 0.25, 15.0)
	w.charge_threshold = 0.4
	w.max_charge_time = 1.5
	w.heavy_min_mult = 1.0
	w.heavy_max_mult = 1.5
	w.combo_window = 0.5
	return w


func _sm(light_count := 3) -> ActionStateMachine:
	return SM.new(_weapon(light_count), 1.0)


func _intent(attack := false, block := false, dash := false, aim := Vector2.RIGHT, move := Vector2.ZERO) -> CombatIntent:
	var i := CombatIntent.new()
	i.attack_held = attack
	i.block_held = block
	i.dash_held = dash
	i.aim_dir = aim
	i.move_dir = move
	return i


## Runs the machine for `seconds` with the same intent; returns all events.
func _run(sm: ActionStateMachine, intent: CombatIntent, seconds: float, dt := DT) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var t := 0.0
	while t < seconds - 0.00001:
		events.append_array(sm.tick(intent, dt))
		t += dt
	return events


## One-frame press followed by one-frame release.
func _tap(sm: ActionStateMachine, aim := Vector2.RIGHT) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	events.append_array(sm.tick(_intent(true, false, false, aim), DT))
	events.append_array(sm.tick(_intent(false, false, false, aim), DT))
	return events


func _of_type(events: Array[Dictionary], type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in events:
		if e.type == type:
			out.append(e)
	return out


# ---------------------------------------------------------------- light / combo

func test_tap_starts_light_attack() -> void:
	var sm := _sm()
	var started := _of_type(_tap(sm), "attack_started")
	assert_eq(started.size(), 1, "one attack")
	assert_false(started[0].is_heavy, "light")
	assert_eq(started[0].combo_index, 0)
	assert_eq(sm.state, ActionStateMachine.State.ATTACK)
	assert_eq(sm.phase, ActionStateMachine.Phase.STARTUP)


func test_attack_phases_in_order_and_return_to_idle() -> void:
	var sm := _sm()
	_tap(sm)
	var ev := _run(sm, _intent(), LIGHT_TOTAL + 0.05)
	assert_eq(_of_type(ev, "active_started").size(), 1)
	assert_eq(_of_type(ev, "active_ended").size(), 1)
	assert_eq(sm.state, ActionStateMachine.State.IDLE)
	assert_true(sm.is_in_combo_window(), "combo window opens after a non-final hit")


func test_buffered_taps_chain_full_combo_then_reset() -> void:
	var sm := _sm(3)
	var started: Array[Dictionary] = []
	started.append_array(_of_type(_tap(sm), "attack_started"))
	# Two more taps during the first attack: only one may be queued at a time.
	started.append_array(_of_type(_tap(sm), "attack_started"))
	started.append_array(_of_type(_run(sm, _intent(), LIGHT_TOTAL), "attack_started"))
	started.append_array(_of_type(_tap(sm), "attack_started"))
	started.append_array(_of_type(_run(sm, _intent(), LIGHT_TOTAL * 2 + 0.1), "attack_started"))
	assert_eq(started.size(), 3, "three hits")
	assert_eq(started[0].combo_index, 0)
	assert_eq(started[1].combo_index, 1)
	assert_eq(started[2].combo_index, 2)
	assert_true(started[2].is_final, "third hit is final")
	assert_false(sm.is_in_combo_window(), "final hit closes the combo")
	var next := _of_type(_tap(sm), "attack_started")
	assert_eq(next[0].combo_index, 0, "combo restarts after the final hit")


func test_tap_within_window_continues_combo() -> void:
	var sm := _sm()
	_tap(sm)
	_run(sm, _intent(), LIGHT_TOTAL + 0.2)
	var next := _of_type(_tap(sm), "attack_started")
	assert_eq(next[0].combo_index, 1)


func test_combo_window_expiry_resets() -> void:
	var sm := _sm()
	_tap(sm)
	_run(sm, _intent(), LIGHT_TOTAL + 0.6)
	var next := _of_type(_tap(sm), "attack_started")
	assert_eq(next[0].combo_index, 0)


func test_single_move_weapon_every_hit_is_final() -> void:
	var sm := _sm(1)
	var first := _of_type(_tap(sm), "attack_started")
	assert_true(first[0].is_final)
	_run(sm, _intent(), LIGHT_TOTAL + 0.05)
	assert_false(sm.is_in_combo_window())


# ---------------------------------------------------------------- charge / heavy

func test_hold_enters_charging_at_threshold() -> void:
	var sm := _sm()
	_run(sm, _intent(true), 0.35)
	assert_eq(sm.state, ActionStateMachine.State.IDLE, "not charging before threshold")
	_run(sm, _intent(true), 0.1)
	assert_eq(sm.state, ActionStateMachine.State.CHARGING)


func test_full_charge_release_is_one_heavy_at_max_mult() -> void:
	var sm := _sm()
	_run(sm, _intent(true), 1.6)
	var ev := sm.tick(_intent(false), DT)
	var started := _of_type(ev, "attack_started")
	assert_eq(started.size(), 1)
	assert_true(started[0].is_heavy)
	assert_true(started[0].is_final)
	assert_eq(snappedf(started[0].charge_mult, 0.001), 1.5)
	var later := _run(sm, _intent(), HEAVY_TOTAL + 0.6)
	assert_eq(_of_type(later, "attack_started").size(), 0, "heavy is a single hit")
	assert_false(sm.is_in_combo_window(), "heavy resets the combo")


func test_minimal_charge_release_is_min_mult() -> void:
	var sm := _sm()
	_run(sm, _intent(true), 0.42)
	assert_eq(sm.state, ActionStateMachine.State.CHARGING)
	var started := _of_type(sm.tick(_intent(false), DT), "attack_started")
	assert_true(started[0].is_heavy)
	assert_true(started[0].charge_mult < 1.02, "close to heavy_min_mult")


func test_spam_tapping_never_produces_heavy() -> void:
	var sm := _sm()
	var heavies := 0
	var lights := 0
	# 6 seconds of mashing: 1-6 frames held, 1-4 frames released, mixed deltas
	# (including hitstop-sized tiny steps).
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var t := 0.0
	while t < 6.0:
		var held_frames := rng.randi_range(1, 6)
		var free_frames := rng.randi_range(1, 4)
		for i in held_frames:
			var dt := DT * (0.05 if rng.randf() < 0.2 else 1.0)
			for e in _of_type(sm.tick(_intent(true), dt), "attack_started"):
				if e.is_heavy: heavies += 1
				else: lights += 1
			t += dt
		for i in free_frames:
			for e in _of_type(sm.tick(_intent(false), DT), "attack_started"):
				if e.is_heavy: heavies += 1
				else: lights += 1
			t += DT
	assert_eq(heavies, 0, "no accidental heavy")
	assert_gt(lights, 10, "mashing produces light attacks")


func test_hold_through_attack_charges_when_attack_ends() -> void:
	var sm := _sm()
	_tap(sm)
	# Press again during the attack and keep holding past the threshold.
	_run(sm, _intent(true), 0.5)
	assert_eq(sm.state, ActionStateMachine.State.CHARGING, "charging once the attack finished")


# ---------------------------------------------------------------- block

func test_block_prevents_attack_and_dash() -> void:
	var sm := _sm()
	sm.tick(_intent(false, true), DT)
	assert_eq(sm.state, ActionStateMachine.State.BLOCK)
	var ev: Array[Dictionary] = []
	ev.append_array(sm.tick(_intent(true, true), DT))
	ev.append_array(sm.tick(_intent(false, true), DT))
	ev.append_array(sm.tick(_intent(false, true, true), DT))
	assert_eq(ev.size(), 0, "no attack or dash while blocking")
	assert_eq(sm.state, ActionStateMachine.State.BLOCK)
	sm.tick(_intent(), DT)
	assert_eq(sm.state, ActionStateMachine.State.IDLE, "release block -> idle")
	var after := _of_type(sm.tick(_intent(), DT), "attack_started")
	assert_eq(after.size(), 0, "tap made during block is not replayed")


func test_block_cancels_charge() -> void:
	var sm := _sm()
	_run(sm, _intent(true), 0.6)
	assert_eq(sm.state, ActionStateMachine.State.CHARGING)
	sm.tick(_intent(true, true), DT)
	assert_eq(sm.state, ActionStateMachine.State.BLOCK)
	var ev := sm.tick(_intent(false, false), DT)
	assert_eq(_of_type(ev, "attack_started").size(), 0, "releasing after a cancelled charge does nothing")


func test_block_covers_three_directions() -> void:
	var sm := _sm()
	sm.tick(_intent(false, true, false, Vector2.RIGHT), DT)
	var covered := []
	for i in 8:
		covered.append(sm.is_blocking_from(ActionStateMachine.index_to_direction(i)))
	# index 0 = RIGHT, 1 = DOWN_RIGHT, 7 = UP_RIGHT
	assert_eq(covered, [true, true, false, false, false, false, false, true])
	sm.tick(_intent(false, true, false, Vector2(1, -1)), DT)
	covered = []
	for i in 8:
		covered.append(sm.is_blocking_from(ActionStateMachine.index_to_direction(i)))
	assert_eq(covered, [true, false, false, false, false, false, true, true], "up-right covers up, up-right, right")


func test_not_blocking_outside_block_state() -> void:
	var sm := _sm()
	assert_false(sm.is_blocking_from(Vector2.RIGHT))


# ---------------------------------------------------------------- dash

func test_dash_and_cooldown() -> void:
	var sm := _sm()
	var ev := sm.tick(_intent(false, false, true, Vector2.RIGHT, Vector2.UP), DT)
	var dash := _of_type(ev, "dash_started")
	assert_eq(dash.size(), 1)
	assert_eq(dash[0].dir, Vector2.UP, "dash follows movement input")
	_run(sm, _intent(), 0.21)
	assert_eq(sm.state, ActionStateMachine.State.IDLE)
	sm.tick(_intent(false, false, true), DT)
	assert_eq(sm.state, ActionStateMachine.State.IDLE, "cooldown blocks the dash")
	sm.tick(_intent(), DT)
	_run(sm, _intent(), 0.5)
	sm.tick(_intent(false, false, true), DT)
	assert_eq(sm.state, ActionStateMachine.State.DASH, "dash after cooldown")


func test_dash_not_allowed_during_attack() -> void:
	var sm := _sm()
	_tap(sm)
	sm.tick(_intent(false, false, true), DT)
	assert_eq(sm.state, ActionStateMachine.State.ATTACK)


func test_dash_cancels_charge() -> void:
	var sm := _sm()
	_run(sm, _intent(true), 0.6)
	sm.tick(_intent(true, false, true), DT)
	assert_eq(sm.state, ActionStateMachine.State.DASH)
	var ev := _run(sm, _intent(false), 0.3)
	assert_eq(_of_type(ev, "attack_started").size(), 0)


func test_tap_during_dash_attacks_after_dash() -> void:
	var sm := _sm()
	sm.tick(_intent(false, false, true), DT)
	_tap(sm)
	var ev := _run(sm, _intent(), 0.25)
	assert_eq(_of_type(ev, "attack_started").size(), 1)


# ---------------------------------------------------------------- reactions

func test_stagger_interrupts_attack_and_resets_combo() -> void:
	var sm := _sm()
	_tap(sm)
	_run(sm, _intent(), LIGHT_TOTAL + 0.05)
	_tap(sm) # combo hit 2 starting
	sm.apply_stagger(0.2)
	assert_eq(sm.state, ActionStateMachine.State.STAGGER)
	assert_eq(sm.movement_mode(), ActionStateMachine.MoveMode.LOCKED)
	_run(sm, _intent(), 0.21)
	assert_eq(sm.state, ActionStateMachine.State.IDLE)
	var next := _of_type(_tap(sm), "attack_started")
	assert_eq(next[0].combo_index, 0)


func test_stagger_cancels_charge_and_block() -> void:
	var sm := _sm()
	_run(sm, _intent(true), 0.6)
	sm.apply_stagger(0.2)
	var ev := _run(sm, _intent(false), 0.3)
	assert_eq(_of_type(ev, "attack_started").size(), 0, "charge lost")
	sm.tick(_intent(false, true), DT)
	assert_eq(sm.state, ActionStateMachine.State.BLOCK)
	sm.apply_stagger(0.2)
	assert_false(sm.is_blocking_from(Vector2.RIGHT), "block dropped")


func test_knockback_wins_over_stagger() -> void:
	var sm := _sm()
	sm.apply_knockback(0.25)
	sm.apply_stagger(0.2)
	assert_eq(sm.state, ActionStateMachine.State.KNOCKBACK)
	assert_eq(sm.movement_mode(), ActionStateMachine.MoveMode.KNOCKBACK)


func test_dead_ignores_everything() -> void:
	var sm := _sm()
	sm.kill()
	var ev: Array[Dictionary] = []
	ev.append_array(_tap(sm))
	ev.append_array(sm.tick(_intent(false, true, true), DT))
	sm.apply_stagger(0.2)
	sm.apply_knockback(0.2)
	assert_eq(ev.size(), 0)
	assert_eq(sm.state, ActionStateMachine.State.DEAD)


# ---------------------------------------------------------------- movement / facing

func test_movement_modes() -> void:
	var sm := _sm()
	assert_eq(sm.movement_mode(), ActionStateMachine.MoveMode.FREE)
	_tap(sm)
	assert_eq(sm.movement_mode(), ActionStateMachine.MoveMode.LUNGE)
	_run(sm, _intent(), 0.12)
	assert_eq(sm.movement_mode(), ActionStateMachine.MoveMode.LOCKED)
	_run(sm, _intent(), 1.0)
	_run(sm, _intent(true), 0.5)
	assert_eq(sm.movement_mode(), ActionStateMachine.MoveMode.SLOWED, "charging is slowed")


func test_lunge_respects_limit() -> void:
	var sm := _sm()
	var i := _intent(true)
	i.lunge_limit = 4.0
	sm.tick(i, DT)
	var r := _intent(false)
	r.lunge_limit = 4.0
	sm.tick(r, DT)
	assert_eq(snappedf(sm.attack_lunge_distance, 0.001), 4.0)
	assert_eq(snappedf(sm.lunge_velocity().length(), 0.01), 40.0, "4px over 0.1s startup")


func test_attack_faces_aim_and_idle_faces_movement() -> void:
	var sm := _sm()
	sm.tick(_intent(false, false, false, Vector2.LEFT, Vector2.UP), DT)
	assert_eq(sm.facing, Vector2.UP)
	_tap(sm, Vector2.LEFT)
	assert_eq(sm.facing, Vector2.LEFT)


func test_attack_speed_scales_duration() -> void:
	var sm := SM.new(_weapon(), 2.0)
	_tap(sm)
	_run(sm, _intent(), LIGHT_TOTAL / 2.0 + 0.03)
	assert_eq(sm.state, ActionStateMachine.State.IDLE, "twice as fast")
