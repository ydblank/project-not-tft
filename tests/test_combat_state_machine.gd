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

func test_block_prevents_attack_but_allows_dash() -> void:
	var sm := _sm()
	sm.tick(_intent(false, true), DT)
	assert_eq(sm.state, ActionStateMachine.State.BLOCK)
	var ev: Array[Dictionary] = []
	ev.append_array(sm.tick(_intent(true, true), DT))
	ev.append_array(sm.tick(_intent(false, true), DT))
	assert_eq(ev.size(), 0, "no attack while blocking")
	assert_eq(sm.state, ActionStateMachine.State.BLOCK)
	var dash := _of_type(sm.tick(_intent(false, true, true), DT), "dash_started")
	assert_eq(dash.size(), 1, "dash cancels the block")
	assert_eq(sm.state, ActionStateMachine.State.DASH)
	_run(sm, _intent(), 0.25)
	assert_eq(sm.state, ActionStateMachine.State.IDLE)
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


func test_dash_cancels_attack() -> void:
	var sm := _sm()
	_tap(sm)
	assert_eq(sm.state, ActionStateMachine.State.ATTACK)
	var ev := sm.tick(_intent(false, false, true), DT)
	assert_eq(_of_type(ev, "dash_started").size(), 1)
	assert_eq(sm.state, ActionStateMachine.State.DASH, "dash cancels an attack")
	assert_true(sm.current_move == null, "attack was cancelled")


func test_dash_press_during_cooldown_is_buffered() -> void:
	var sm := _sm()
	sm.dash_cooldown = 0.1
	sm.tick(_intent(false, false, true), DT) # dash 1 (0.2s), gap until ~0.3s
	_run(sm, _intent(), 0.25)
	assert_eq(sm.state, ActionStateMachine.State.IDLE)
	var ev: Array[Dictionary] = []
	ev.append_array(sm.tick(_intent(false, false, true), DT)) # too early: gap still running
	assert_eq(_of_type(ev, "dash_started").size(), 0)
	ev.append_array(_run(sm, _intent(), 0.1))
	assert_eq(_of_type(ev, "dash_started").size(), 1, "buffered press fires as soon as the gap ends")


func test_dash_can_chain_midway_through_a_dash() -> void:
	var sm := _charged_sm() # gap 0.15 would block, so zero it
	sm.dash_cooldown = 0.0
	sm.tick(_intent(false, false, true), DT)
	sm.tick(_intent(), DT)
	_run(sm, _intent(), 0.12) # past half of the 0.2s dash
	assert_eq(sm.state, ActionStateMachine.State.DASH)
	var ev := sm.tick(_intent(false, false, true, Vector2.RIGHT, Vector2.LEFT), DT)
	assert_eq(_of_type(ev, "dash_started").size(), 1, "second dash starts without waiting")
	assert_eq(sm.dash_dir, Vector2.LEFT, "new dash takes the new direction")
	assert_eq(sm.dash_charges(), 0)


func test_dash_cannot_chain_in_first_half_of_a_dash() -> void:
	var sm := _charged_sm()
	sm.dash_cooldown = 0.0
	sm.tick(_intent(false, false, true), DT)
	sm.tick(_intent(), DT)
	_run(sm, _intent(), 0.03)
	var ev := sm.tick(_intent(false, false, true), DT)
	assert_eq(_of_type(ev, "dash_started").size(), 0)
	assert_eq(sm.dash_charges(), 1)


func test_dash_allowed_out_of_stagger() -> void:
	var sm := _sm()
	sm.apply_stagger(0.3)
	var ev := sm.tick(_intent(false, false, true), DT)
	assert_eq(_of_type(ev, "dash_started").size(), 1, "dash breaks the combo")
	assert_eq(sm.state, ActionStateMachine.State.DASH)


func test_dash_not_allowed_out_of_guard_break_stun() -> void:
	var sm := _sm()
	sm.apply_stagger(0.3, false)
	var ev := sm.tick(_intent(false, false, true), DT)
	assert_eq(_of_type(ev, "dash_started").size(), 0)
	assert_eq(sm.state, ActionStateMachine.State.STAGGER)


func test_dash_not_allowed_in_knockback() -> void:
	var sm := _sm()
	sm.apply_knockback(0.3)
	var ev := sm.tick(_intent(false, false, true), DT)
	assert_eq(_of_type(ev, "dash_started").size(), 0)
	assert_eq(sm.state, ActionStateMachine.State.KNOCKBACK)

func test_charge_survives_dash_and_releases_after() -> void:
	var sm := _sm()
	_run(sm, _intent(true), 0.6)
	assert_eq(sm.state, ActionStateMachine.State.CHARGING)
	sm.tick(_intent(true, false, true), DT)
	assert_eq(sm.state, ActionStateMachine.State.DASH)
	# keep holding through the dash: back to charging, charge kept
	_run(sm, _intent(true), sm.dash_duration + 0.05)
	assert_eq(sm.state, ActionStateMachine.State.CHARGING, "charging again after dash")
	assert_true(sm.charge_time >= 0.6, "charge kept growing")
	var ev := _run(sm, _intent(false), 0.05)
	var started := _of_type(ev, "attack_started")
	assert_eq(started.size(), 1, "heavy released")
	assert_true(started[0].is_heavy, "is heavy")


func test_release_during_dash_fires_heavy_when_dash_ends() -> void:
	var sm := _sm()
	_run(sm, _intent(true), 0.6)
	sm.tick(_intent(true, false, true), DT)
	var ev := _run(sm, _intent(false), 0.05) # let go mid-dash
	assert_eq(_of_type(ev, "attack_started").size(), 0, "not yet")
	ev = _run(sm, _intent(false), sm.dash_duration + 0.05)
	var started := _of_type(ev, "attack_started")
	assert_eq(started.size(), 1, "heavy fires after dash")
	assert_true(started[0].is_heavy)
	assert_true(started[0].charge_mult > 1.0, "kept the charge")


func test_uncharged_hold_released_in_dash_is_not_heavy() -> void:
	var sm := _sm()
	sm.tick(_intent(true), DT)
	sm.tick(_intent(true, false, true), DT)
	_run(sm, _intent(false), 0.05)
	var ev := _run(sm, _intent(false), 0.4)
	for e in _of_type(ev, "attack_started"):
		assert_false(e.is_heavy, "short press is light")


func test_stagger_clears_pending_heavy() -> void:
	var sm := _sm()
	_run(sm, _intent(true), 0.6)
	sm.tick(_intent(true, false, true), DT)
	_run(sm, _intent(false), 0.05)
	sm.apply_stagger(0.2)
	var ev := _run(sm, _intent(false), 0.6)
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


func test_revive_returns_dead_to_idle_and_allows_attacking() -> void:
	var sm := _sm()
	sm.kill()
	sm.revive()
	assert_eq(sm.state, ActionStateMachine.State.IDLE)
	var ev := _tap(sm)
	var started := false
	for e in ev:
		if e.type == "attack_started":
			started = true
	assert_true(started)


func test_dash_cooldown_ratio_runs_from_full_to_ready() -> void:
	var sm := _sm()
	assert_eq(sm.dash_cooldown_ratio(), 0.0)
	sm.dash_duration = 0.2
	sm.dash_cooldown = 0.5
	sm.tick(_intent(false, false, true), DT) # dash pressed
	assert_eq(sm.state, ActionStateMachine.State.DASH)
	assert_eq(sm.dash_cooldown_ratio(), 1.0)
	_run(sm, _intent(), 0.25) # dash ends, cooldown starts at 1.0
	assert_eq(sm.state, ActionStateMachine.State.IDLE)
	var mid := sm.dash_cooldown_ratio()
	assert_true(mid > 0.0 and mid < 1.0, "cooldown in progress: %s" % mid)
	_run(sm, _intent(), 0.6)
	assert_eq(sm.dash_cooldown_ratio(), 0.0)
	assert_true(sm.dash_ready())


func _charged_sm() -> ActionStateMachine:
	var sm := _sm()
	# duration 0.2, gap 0.15, 2 charges, recharge 0.8, reload 1.8
	sm.configure_dash(0.2, 0.15, 2, 0.8, 1.8)
	return sm


## One dash press (press + release) followed by `wait` seconds of idling.
func _dash_then_wait(sm: ActionStateMachine, wait: float) -> void:
	sm.tick(_intent(false, false, true), DT)
	sm.tick(_intent(), DT)
	_run(sm, _intent(), wait)


func test_two_dashes_in_a_row_then_locked_until_reload() -> void:
	var sm := _charged_sm()
	assert_eq(sm.dash_charges(), 2)
	_dash_then_wait(sm, 0.4) # dash (0.2) + gap (0.15) passed
	assert_eq(sm.dash_charges(), 1)
	assert_true(sm.dash_ready(), "second charge usable right away")
	_dash_then_wait(sm, 0.4)
	assert_eq(sm.dash_charges(), 0)
	assert_false(sm.dash_ready(), "out of charges")
	assert_true(sm.dash_is_reloading())
	# Using both in a row means the first charge takes the slow 1.8s.
	_run(sm, _intent(), 1.0)
	assert_eq(sm.dash_charges(), 0, "still reloading after 1.0s")
	_run(sm, _intent(), 1.0)
	assert_eq(sm.dash_charges(), 1, "one charge is back, the other is still recharging")
	assert_true(sm.dash_ready(), "early dash without waiting for both")
	_run(sm, _intent(), 0.9)
	assert_eq(sm.dash_charges(), 2, "second charge returns after its own timer")


func test_charges_come_back_one_at_a_time() -> void:
	var sm := _charged_sm()
	_dash_then_wait(sm, 0.4)
	_dash_then_wait(sm, 0.4)
	_run(sm, _intent(), 2.0) # slow reload finished -> 1 charge
	assert_eq(sm.dash_charges(), 1)
	assert_false(sm.dash_is_reloading(), "second charge uses the normal recharge")
	assert_true(sm.dash_recharge_ratio() > 0.0, "next charge already recharging")


func test_single_dash_recharges_faster() -> void:
	var sm := _charged_sm()
	_dash_then_wait(sm, 0.3)
	assert_eq(sm.dash_charges(), 1)
	assert_false(sm.dash_is_reloading())
	_run(sm, _intent(), 0.7) # 1.0s total since the dash > 0.8s recharge
	assert_eq(sm.dash_charges(), 2)


func test_chaining_gap_blocks_instant_second_dash() -> void:
	var sm := _charged_sm()
	sm.tick(_intent(false, false, true), DT)
	_run(sm, _intent(), 0.21) # dash just ended, gap running
	assert_eq(sm.state, ActionStateMachine.State.IDLE)
	assert_false(sm.dash_ready(), "gap not over")
	_run(sm, _intent(), 0.2)
	assert_true(sm.dash_ready())


func test_revive_refills_dash_charges() -> void:
	var sm := _charged_sm()
	_dash_then_wait(sm, 0.4)
	_dash_then_wait(sm, 0.4)
	sm.kill()
	sm.revive()
	assert_eq(sm.dash_charges(), 2)
	assert_true(sm.dash_ready())


func test_revive_does_nothing_when_alive() -> void:
	var sm := _sm()
	sm.apply_stagger(0.2)
	sm.revive()
	assert_eq(sm.state, ActionStateMachine.State.STAGGER)


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


# ---------------------------------------------------------------- heavy combo / quick-combo cooldown

## Melee-style weapon: 3-hit heavy combo and a cooldown after the quick combo.
func _combo_sm(light_cooldown := 0.6) -> ActionStateMachine:
	var w := _weapon(3)
	var hits: Array[AttackMove] = []
	for i in 3:
		hits.append(_move(0.1, 0.1, 0.08, 10.0))
	w.heavy_combo = hits
	w.light_combo_cooldown = light_cooldown
	w.input_buffer = 0.3
	return SM.new(w, 1.0)


func test_one_charge_release_plays_a_three_hit_heavy_combo() -> void:
	var sm := _combo_sm()
	_run(sm, _intent(true), 1.0)
	var ev := sm.tick(_intent(false), DT)
	ev.append_array(_run(sm, _intent(), 1.5)) # no further input at all
	var started := _of_type(ev, "attack_started")
	assert_eq(started.size(), 3, "one release = three heavy hits")
	for i in 3:
		assert_true(started[i].is_heavy)
		assert_eq(started[i].combo_index, i)
	assert_false(started[0].is_final)
	assert_false(started[1].is_final)
	assert_true(started[2].is_final, "the third hit is the finisher")
	assert_eq(sm.state, ActionStateMachine.State.IDLE, "combo over")


func test_heavy_combo_keeps_the_charge_multiplier_on_every_hit() -> void:
	var sm := _combo_sm()
	_run(sm, _intent(true), 1.6) # full charge
	var ev := sm.tick(_intent(false), DT)
	ev.append_array(_run(sm, _intent(), 1.5))
	var started := _of_type(ev, "attack_started")
	assert_eq(started.size(), 3)
	for e in started:
		assert_eq(snappedf(e.charge_mult, 0.001), 1.5, "same charge on every hit")


func test_stagger_cancels_the_rest_of_a_heavy_combo() -> void:
	var sm := _combo_sm()
	_run(sm, _intent(true), 1.0)
	sm.tick(_intent(false), DT)
	_run(sm, _intent(), 0.1)
	assert_eq(sm.state, ActionStateMachine.State.ATTACK)
	sm.apply_stagger(0.2)
	var ev := _run(sm, _intent(), 1.0)
	assert_eq(_of_type(ev, "attack_started").size(), 0, "no more hits after being staggered")


func test_quick_combo_needs_a_click_for_every_hit() -> void:
	var sm := _combo_sm()
	var ev := _tap(sm)
	ev.append_array(_run(sm, _intent(), 1.0)) # waits, no more clicks
	assert_eq(_of_type(ev, "attack_started").size(), 1, "one click = one hit")


func test_cooldown_after_the_full_quick_combo() -> void:
	var sm := _combo_sm(0.6)
	for i in 3:
		_tap(sm)
		_run(sm, _intent(), 0.36) # a light hit takes 0.1 + 0.1 + 0.15 = 0.35s
	assert_eq(sm.state, ActionStateMachine.State.IDLE)
	assert_true(sm.light_cooldown_left() > 0.3, "cooldown running after the finisher")
	# A tap right away is ignored (too early even for the buffer).
	var early := _tap(sm)
	early.append_array(_run(sm, _intent(), 0.2))
	assert_eq(_of_type(early, "attack_started").size(), 0, "locked out during the cooldown")
	# After the cooldown a tap starts a fresh combo at hit 1.
	_run(sm, _intent(), 0.7)
	var fresh := _of_type(_tap(sm), "attack_started")
	assert_eq(fresh.size(), 1)
	assert_eq(fresh[0].combo_index, 0)


func test_tap_just_before_the_cooldown_ends_is_buffered() -> void:
	var sm := _combo_sm(0.6)
	for i in 3:
		_tap(sm)
		_run(sm, _intent(), 0.36)
	var left := sm.light_cooldown_left()
	_run(sm, _intent(), maxf(left - 0.2, 0.0)) # inside the 0.3s buffer window
	var ev := _tap(sm)
	ev.append_array(_run(sm, _intent(), 0.4))
	assert_eq(_of_type(ev, "attack_started").size(), 1, "buffered tap fires once the cooldown ends")


func test_heavy_charge_is_allowed_during_the_quick_combo_cooldown() -> void:
	var sm := _combo_sm(0.6)
	for i in 3:
		_tap(sm)
		_run(sm, _intent(), 0.36)
	assert_true(sm.light_cooldown_left() > 0.0)
	_run(sm, _intent(true), 0.6)
	assert_eq(sm.state, ActionStateMachine.State.CHARGING, "can still charge a heavy")


func test_no_cooldown_for_single_move_weapons() -> void:
	var sm := _sm(1)
	_tap(sm)
	_run(sm, _intent(), 0.4)
	assert_eq(sm.light_cooldown_left(), 0.0)
	var ev := _of_type(_tap(sm), "attack_started")
	assert_eq(ev.size(), 1, "bow-style weapons can fire again right away")


# ---------------------------------------------------------------- combo lock helpers

func test_in_combo_during_non_final_light_and_window() -> void:
	var sm := _sm()
	assert_false(sm.in_combo(), "idle")
	_tap(sm)
	_run(sm, _intent(), 0.1)
	assert_true(sm.in_combo(), "mid first hit")
	_run(sm, _intent(), LIGHT_TOTAL)
	assert_true(sm.in_combo(), "inside the window to continue")
	_run(sm, _intent(), 0.8)
	assert_false(sm.in_combo(), "window expired")


func test_hold_stagger_extends_only_stagger() -> void:
	var sm := _sm()
	sm.apply_stagger(0.05)
	sm.hold_stagger(0.5)
	_run(sm, _intent(), 0.3)
	assert_eq(sm.state, ActionStateMachine.State.STAGGER, "still held")
	var idle := _sm()
	idle.hold_stagger(0.5)
	assert_eq(idle.state, ActionStateMachine.State.IDLE)


# ---------------------------------------------------------------- parry / wind-up

func test_fresh_block_parries_then_window_closes() -> void:
	var sm := _sm()
	sm.parry_window = 0.2
	_run(sm, _intent(false, true), 0.05)
	assert_eq(sm.state, ActionStateMachine.State.BLOCK)
	assert_true(sm.is_parrying(), "parry in the first moments of a block")
	_run(sm, _intent(false, true), 0.3)
	assert_false(sm.is_parrying(), "window closed while still holding block")


func test_click_after_parry_counter_attacks_at_once() -> void:
	var sm := _sm()
	_run(sm, _intent(false, true), 0.05)
	sm.grant_counter() # a parry just landed
	var events := _run(sm, _intent(true, true), DT) # click while still holding block
	assert_eq(sm.state, ActionStateMachine.State.ATTACK, "the click starts a swing immediately")
	assert_eq(_of_type(events, "attack_started").size(), 1, "one attack_started fired on the click")


func test_click_while_blocking_without_a_parry_does_nothing() -> void:
	var sm := _sm()
	_run(sm, _intent(false, true), 0.05)
	_run(sm, _intent(true, true), DT * 3.0)
	assert_eq(sm.state, ActionStateMachine.State.BLOCK, "no parry, no counter: still blocking")


func test_counter_window_expires() -> void:
	var sm := _sm()
	_run(sm, _intent(false, true), 0.05)
	sm.grant_counter()
	_run(sm, _intent(false, true), sm.parry_counter_window + 0.1)
	_run(sm, _intent(true, true), DT * 3.0)
	assert_eq(sm.state, ActionStateMachine.State.BLOCK, "too late for a counter")


func test_block_mashing_does_not_parry() -> void:
	var sm := _sm()
	sm.parry_window = 0.2
	_run(sm, _intent(false, true), 0.5) # first block: parry window passes
	_run(sm, _intent(), 0.1) # let go for a moment
	_run(sm, _intent(false, true), 0.05) # block again right away
	assert_eq(sm.state, ActionStateMachine.State.BLOCK)
	assert_false(sm.is_parrying(), "re-blocking right after letting go has no parry window")


func test_parry_returns_after_a_pause() -> void:
	var sm := _sm()
	sm.parry_window = 0.2
	_run(sm, _intent(false, true), 0.5)
	_run(sm, _intent(), sm.parry_cooldown + 0.1)
	_run(sm, _intent(false, true), 0.05)
	assert_true(sm.is_parrying(), "after a short pause the parry window is back")


func test_startup_progress_rises_during_the_wind_up() -> void:
	var sm := _sm()
	assert_eq(sm.startup_progress(), 0.0, "idle")
	_tap(sm)
	var early := sm.startup_progress()
	_run(sm, _intent(), 0.05)
	var later := sm.startup_progress()
	assert_true(later > early, "wind-up progresses")
	_run(sm, _intent(), 0.3)
	assert_eq(sm.startup_progress(), 0.0, "0 once the swing is past its wind-up")
