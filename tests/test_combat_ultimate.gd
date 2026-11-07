@tool
extends McpTestSuite

# Class ultimates (GAM-23): the meter, activation and per-class effects in ActionStateMachine,
# and the Ultimates balance table.

const SM := preload("res://assets/combat/action_state_machine.gd")
const DT := 1.0 / 60.0


func suite_name() -> String:
	return "combat_ultimate"


# ---------------------------------------------------------------- helpers

func _weapon(ranged := false, skill: SkillData = null) -> WeaponData:
	var w := WeaponData.new()
	var m := AttackMove.new()
	m.startup = 0.1
	m.active = 0.1
	m.recovery = 0.15
	var moves: Array[AttackMove] = [m]
	w.light_moves = moves
	w.heavy_move = m
	w.kind = WeaponData.Kind.RANGED if ranged else WeaponData.Kind.MELEE
	w.heavy_min_mult = 0.5
	w.heavy_max_mult = 2.0
	w.charge_threshold = 0.4
	w.max_charge_time = 2.0
	w.light_combo_cooldown = 0.5
	w.skill = skill
	return w


func _sm(cls: int, weapon: WeaponData = null) -> ActionStateMachine:
	var sm := SM.new(weapon if weapon else _weapon(), 1.0)
	sm.set_ultimate(Ultimates.row_for(cls))
	return sm


func _intent(ult := false, attack := false, skill := false) -> CombatIntent:
	var i := CombatIntent.new()
	i.ultimate_held = ult
	i.attack_held = attack
	i.skill_held = skill
	i.aim_dir = Vector2.RIGHT
	return i


func _run(sm: ActionStateMachine, intent: CombatIntent, seconds: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var t := 0.0
	while t < seconds - 0.00001:
		events.append_array(sm.tick(intent, DT))
		t += DT
	return events


func _of_type(events: Array[Dictionary], type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in events:
		if e.type == type:
			out.append(e)
	return out


## assert_eq for floats, within `eps`.
func _near(actual: float, expected: float, eps: float, msg: String = "") -> void:
	assert_true(absf(actual - expected) <= eps, "%s (got %s, expected %s)" % [msg, actual, expected])


## Fills the meter and presses the ultimate.
func _fire(sm: ActionStateMachine) -> Array[Dictionary]:
	sm.ult_charge = 1.0
	var events := sm.tick(_intent(true), DT)
	sm.tick(_intent(), DT) # let go of the button
	return events


# ---------------------------------------------------------------- table and charge

func test_every_class_has_an_ultimate_with_known_fields() -> void:
	for cls in [Classes.CLASSES.KNIGHT, Classes.CLASSES.THIEF, Classes.CLASSES.ARCHER, Classes.CLASSES.MAGE]:
		assert_true(Ultimates.has_ultimate(cls), "class %d has an ultimate" % cls)
		for field in Ultimates.TABLE[cls]:
			assert_true(Ultimates.DEFAULTS.has(field), "class %d field '%s' is a known field" % [cls, field])
		var row := Ultimates.row_for(cls)
		assert_eq(row.duration, 5.0, "5 s for class %d" % cls)
	assert_false(Ultimates.has_ultimate(Classes.CLASSES.NONE), "no class, no ultimate")
	assert_true(Ultimates.row_for(Classes.CLASSES.NONE).is_empty())


func test_charge_comes_from_the_hit_multiplier() -> void:
	var row := Ultimates.row_for(Classes.CLASSES.KNIGHT)
	var needed: float = row.charge_points
	_near(Ultimates.charge_gain(1.0, 1.0, row), 1.0 / needed, 0.0001, "a 1.0 hit at full HP")
	_near(Ultimates.charge_gain(2.0, 1.0, row), 2.0 / needed, 0.0001, "a 2.0 hit gives twice as much")
	assert_eq(Ultimates.charge_gain(0.0, 1.0, row), 0.0, "a hit without points gives nothing")


func test_low_hp_speeds_up_the_charge_below_half() -> void:
	var row := Ultimates.row_for(Classes.CLASSES.MAGE)
	_near(Ultimates.hp_mult(1.0, row), 1.0, 0.0001, "full HP: normal")
	_near(Ultimates.hp_mult(0.6, row), 1.0, 0.0001, "above half: normal")
	_near(Ultimates.hp_mult(0.5, row), 1.0, 0.0001, "at half: still normal")
	_near(Ultimates.hp_mult(0.25, row), 1.5, 0.0001, "a quarter: 1.5x")
	_near(Ultimates.hp_mult(0.0, row), 2.0, 0.0001, "near death: 2x")


func test_meter_fills_and_caps() -> void:
	var sm := _sm(Classes.CLASSES.KNIGHT)
	sm.add_ult_charge(0.4)
	_near(sm.ult_charge, 0.4, 0.0001)
	assert_false(sm.ult_ready())
	sm.add_ult_charge(0.9)
	assert_eq(sm.ult_charge, 1.0, "capped at full")
	assert_true(sm.ult_ready())


func test_no_ultimate_class_never_charges() -> void:
	var sm := _sm(Classes.CLASSES.NONE)
	sm.add_ult_charge(1.0)
	assert_eq(sm.ult_charge, 0.0)
	assert_false(sm.ult_ready())


# ---------------------------------------------------------------- activation

func test_press_needs_a_full_meter() -> void:
	var sm := _sm(Classes.CLASSES.KNIGHT)
	sm.ult_charge = 0.6
	sm.tick(_intent(true), DT)
	assert_false(sm.ult_active(), "not full: nothing")
	_near(sm.ult_charge, 0.6, 0.0001, "and the meter is kept")


func test_press_with_a_full_meter_starts_it_and_empties_the_meter() -> void:
	var sm := _sm(Classes.CLASSES.KNIGHT)
	var events := _fire(sm)
	assert_eq(_of_type(events, "ultimate_started").size(), 1)
	assert_true(sm.ult_active())
	assert_eq(sm.ult_charge, 0.0)
	assert_eq(sm.state, ActionStateMachine.State.IDLE, "no state of its own")


func test_no_charge_while_active_and_it_ends_after_its_duration() -> void:
	var sm := _sm(Classes.CLASSES.KNIGHT)
	_fire(sm)
	sm.add_ult_charge(0.5)
	assert_eq(sm.ult_charge, 0.0, "nothing gained while it runs")
	var events := _run(sm, _intent(), 4.8)
	assert_true(sm.ult_active(), "still on just before 5 s")
	events = _run(sm, _intent(), 0.3)
	assert_eq(_of_type(events, "ultimate_ended").size(), 1, "ends at 5 s")
	assert_false(sm.ult_active())


func test_cannot_fire_while_stunned() -> void:
	var sm := _sm(Classes.CLASSES.THIEF)
	sm.ult_charge = 1.0
	sm.apply_stagger(1.0)
	sm.tick(_intent(true), DT)
	assert_false(sm.ult_active(), "staggered: no ultimate")


func test_death_and_respawn_empty_the_meter() -> void:
	var sm := _sm(Classes.CLASSES.THIEF)
	_fire(sm)
	sm.kill()
	assert_false(sm.ult_active(), "death ends it")
	sm.revive()
	assert_eq(sm.ult_charge, 0.0, "respawn starts empty")


# ---------------------------------------------------------------- per class

func test_knight_ignores_every_stun() -> void:
	var sm := _sm(Classes.CLASSES.KNIGHT)
	_fire(sm)
	assert_true(sm.ult_immune())
	sm.apply_stagger(1.0)
	assert_eq(sm.state, ActionStateMachine.State.IDLE, "no stagger")
	sm.apply_stagger(1.0, false, true)
	assert_eq(sm.state, ActionStateMachine.State.IDLE, "not even a forced (parry) stun")
	sm.apply_knockback(0.3)
	assert_eq(sm.state, ActionStateMachine.State.IDLE, "no knockback")
	_near(sm.ult_move_speed_mult(), 1.2, 0.0001, "walks faster")


func test_thief_is_faster_and_dodges_projectiles() -> void:
	var normal := _sm(Classes.CLASSES.THIEF)
	normal.tick(_intent(false, true), DT)
	normal.tick(_intent(), DT)
	_run(normal, _intent(), 0.05)
	var sm := _sm(Classes.CLASSES.THIEF)
	_fire(sm)
	assert_true(sm.ult_dodges_projectiles())
	_near(sm.ult_move_speed_mult(), 1.4, 0.0001)
	sm.tick(_intent(false, true), DT)
	sm.tick(_intent(), DT)
	_run(sm, _intent(), 0.05)
	assert_gt(sm.startup_progress(), normal.startup_progress() * 1.3, "the wind-up runs 1.4x faster")


func test_archer_holding_attack_streams_charged_heavies() -> void:
	var sm := _sm(Classes.CLASSES.ARCHER, _weapon(true))
	_fire(sm)
	var events := _run(sm, _intent(false, true), 2.0)
	var attacks := _of_type(events, "attack_started")
	assert_gt(attacks.size(), 1, "holding keeps firing")
	var expected := lerpf(0.5, 2.0, Ultimates.row_for(Classes.CLASSES.ARCHER).auto_heavy_charge)
	for a in attacks:
		assert_true(a.is_heavy, "every shot is a heavy")
		_near(a.charge_mult, expected, 0.0001, "charged to the table's share")
	assert_ne(sm.state, ActionStateMachine.State.CHARGING, "never stops to charge")


func test_archer_heavies_keep_the_quick_shot_pace() -> void:
	var quick := _sm(Classes.CLASSES.ARCHER, _weapon(true))
	var quick_shots := 0
	for i in 120: # tap every frame-pair for 2 s
		quick_shots += _of_type(quick.tick(_intent(false, i % 2 == 0), DT), "attack_started").size()
	var sm := _sm(Classes.CLASSES.ARCHER, _weapon(true))
	_fire(sm)
	var ult_shots := _of_type(_run(sm, _intent(false, true), 2.0), "attack_started").size()
	assert_true(absi(ult_shots - quick_shots) <= 1, "same pace: %d quick vs %d ultimate" % [quick_shots, ult_shots])


func test_mage_cuts_cooldown_cast_and_charge_time() -> void:
	var fireball := SkillData.new()
	fireball.kind = SkillData.Kind.FIREBALL
	fireball.cooldown = 10.0
	fireball.cast_time = 0.4
	fireball.duration = 0.0
	var sm := _sm(Classes.CLASSES.MAGE, _weapon(true, fireball))
	_fire(sm)
	sm.tick(_intent(false, false, true), DT)
	assert_eq(sm.state, ActionStateMachine.State.SKILL)
	_near(sm.skill_cast_time(), 0.1, 0.0001, "cast time x0.25")
	_run(sm, _intent(), 2.6)
	assert_true(sm.skill_ready(), "a 10 s cooldown is back in about 2.5 s")
	# Heavy charge: the 0.4 s hold before charging becomes 0.1 s.
	sm.tick(_intent(false, true), DT)
	_run(sm, _intent(false, true), 0.15)
	assert_eq(sm.state, ActionStateMachine.State.CHARGING, "charging after 0.15 s")


func test_mage_cooldown_is_normal_without_the_ultimate() -> void:
	var fireball := SkillData.new()
	fireball.kind = SkillData.Kind.FIREBALL
	fireball.cooldown = 10.0
	var sm := _sm(Classes.CLASSES.MAGE, _weapon(true, fireball))
	sm.tick(_intent(false, false, true), DT)
	_run(sm, _intent(), 2.6)
	assert_false(sm.skill_ready(), "still cooling down")
