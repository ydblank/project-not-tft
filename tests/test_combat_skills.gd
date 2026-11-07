@tool
extends McpTestSuite

# Weapon skills (GAM-20): the SKILL_AIM / SKILL states of ActionStateMachine and the skill data.

const SM := preload("res://assets/combat/action_state_machine.gd")
const DT := 1.0 / 60.0


func suite_name() -> String:
	return "combat_skills"


# ---------------------------------------------------------------- helpers

func _skill(kind := SkillData.Kind.SPIN, aim := SkillData.AimMode.NONE, cooldown := 5.0, duration := 0.5, unstoppable := false) -> SkillData:
	var s := SkillData.new()
	s.kind = kind
	s.aim_mode = aim
	s.cooldown = cooldown
	s.duration = duration
	s.unstoppable = unstoppable
	return s


func _sm(skill: SkillData) -> ActionStateMachine:
	var w := WeaponData.new()
	var m := AttackMove.new()
	var moves: Array[AttackMove] = [m]
	w.light_moves = moves
	w.heavy_move = m
	w.skill = skill
	return SM.new(w, 1.0)


func _intent(skill := false, block := false, aim := Vector2.RIGHT, target := Vector2(50, 0)) -> CombatIntent:
	var i := CombatIntent.new()
	i.skill_held = skill
	i.block_held = block
	i.aim_dir = aim
	i.skill_target = target
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


# ---------------------------------------------------------------- casting

func test_unaimed_skill_casts_on_press() -> void:
	var sm := _sm(_skill())
	var events := sm.tick(_intent(true), DT)
	assert_eq(_of_type(events, "skill_started").size(), 1, "spin casts on press")
	assert_eq(sm.state, ActionStateMachine.State.SKILL)


func test_aimed_skill_waits_for_release() -> void:
	var sm := _sm(_skill(SkillData.Kind.VOLLEY, SkillData.AimMode.DIRECTION))
	var events := _run(sm, _intent(true, false, Vector2.UP), 0.5)
	assert_eq(_of_type(events, "skill_started").size(), 0, "no cast while held")
	assert_true(sm.is_skill_aiming(), "holding aims")
	assert_eq(sm.movement_mode(), ActionStateMachine.MoveMode.SLOWED, "slowed while aiming")
	events = sm.tick(_intent(false, false, Vector2.UP, Vector2(3, 4)), DT)
	var started := _of_type(events, "skill_started")
	assert_eq(started.size(), 1, "release casts")
	assert_eq(started[0].dir, Vector2.UP, "cast along the aim")
	assert_eq(started[0].target, Vector2(3, 4), "cast at the aimed point")


func test_quick_tap_of_aimed_skill_casts() -> void:
	var sm := _sm(_skill(SkillData.Kind.FIREBALL, SkillData.AimMode.POINT))
	var events := sm.tick(_intent(true), DT)
	events.append_array(sm.tick(_intent(false), DT))
	assert_eq(_of_type(events, "skill_started").size(), 1, "tap casts at once")


func test_block_cancels_aim_without_cooldown() -> void:
	var sm := _sm(_skill(SkillData.Kind.VOLLEY, SkillData.AimMode.DIRECTION))
	_run(sm, _intent(true), 0.2)
	sm.tick(_intent(true, true), DT)
	assert_false(sm.is_skill_aiming(), "block cancels the aim")
	assert_true(sm.skill_ready(), "no cooldown spent")


func test_cooldown_blocks_recast_then_expires() -> void:
	var sm := _sm(_skill(SkillData.Kind.SPIN, SkillData.AimMode.NONE, 2.0, 0.3))
	sm.tick(_intent(true), DT)
	assert_false(sm.skill_ready(), "on cooldown after cast")
	assert_gt(sm.skill_cooldown_ratio(), 0.9, "cooldown ratio starts full")
	_run(sm, _intent(false), 0.5)
	assert_eq(sm.state, ActionStateMachine.State.IDLE, "skill ended after its duration")
	var events := sm.tick(_intent(true), DT)
	assert_eq(_of_type(events, "skill_started").size(), 0, "no recast on cooldown")
	_run(sm, _intent(false), 1.6)
	assert_true(sm.skill_ready(), "ready after the cooldown")
	assert_eq(sm.skill_cooldown_ratio(), 0.0)


func test_skill_ends_with_event() -> void:
	var sm := _sm(_skill(SkillData.Kind.SPIN, SkillData.AimMode.NONE, 5.0, 0.3))
	var events := _run(sm, _intent(true), 0.5)
	assert_eq(_of_type(events, "skill_ended").size(), 1)


func test_finish_skill_ends_early() -> void:
	var sm := _sm(_skill(SkillData.Kind.DASH_STRIKE, SkillData.AimMode.NONE, 5.0, 1.0))
	sm.tick(_intent(true), DT)
	assert_eq(sm.movement_mode(), ActionStateMachine.MoveMode.SKILL_DASH)
	sm.finish_skill()
	sm.tick(_intent(false), DT)
	assert_eq(sm.state, ActionStateMachine.State.IDLE)


func test_stagger_interrupts_aim_and_normal_skill() -> void:
	var sm := _sm(_skill(SkillData.Kind.VOLLEY, SkillData.AimMode.DIRECTION))
	_run(sm, _intent(true), 0.1)
	sm.apply_stagger(0.3)
	assert_eq(sm.state, ActionStateMachine.State.STAGGER, "stagger stops the aim")
	var sm2 := _sm(_skill(SkillData.Kind.VOLLEY))
	sm2.tick(_intent(true), DT)
	sm2.apply_stagger(0.3)
	assert_eq(sm2.state, ActionStateMachine.State.STAGGER, "stagger stops a normal skill")
	assert_false(sm2.skill_ready(), "cooldown is still spent")


func test_press_during_stagger_is_buffered() -> void:
	var sm := _sm(_skill())
	sm.apply_stagger(0.1)
	sm.tick(_intent(true), DT) # pressed while stunned
	var events := _run(sm, _intent(false), 0.2)
	assert_eq(_of_type(events, "skill_started").size(), 1, "the press fires once the stun ends")
	var sm2 := _sm(_skill())
	sm2.apply_stagger(0.6)
	sm2.tick(_intent(true), DT)
	events = _run(sm2, _intent(false), 0.8)
	assert_eq(_of_type(events, "skill_started").size(), 0, "a press long before the stun ends is dropped")


func test_unstoppable_skill_ignores_hits_but_not_parry() -> void:
	var sm := _sm(_skill(SkillData.Kind.SPIN, SkillData.AimMode.NONE, 5.0, 0.6, true))
	sm.tick(_intent(true), DT)
	sm.apply_stagger(0.3)
	sm.apply_knockback(0.3)
	assert_eq(sm.state, ActionStateMachine.State.SKILL, "unstoppable")
	sm.apply_stagger(0.3, false, true)
	assert_eq(sm.state, ActionStateMachine.State.STAGGER, "a forced (parry) stun still lands")


func test_dead_cannot_cast_and_revive_resets() -> void:
	var sm := _sm(_skill())
	sm.tick(_intent(true), DT)
	sm.kill()
	var events := _run(sm, _intent(false), 0.1)
	events.append_array(sm.tick(_intent(true), DT))
	assert_eq(_of_type(events, "skill_started").size(), 0, "dead cannot cast")
	sm.revive()
	assert_true(sm.skill_ready(), "revive resets the cooldown")


func test_no_skill_weapon_does_nothing() -> void:
	var sm := _sm(null)
	var events := sm.tick(_intent(true), DT)
	assert_eq(_of_type(events, "skill_started").size(), 0)
	assert_false(sm.skill_ready())
	assert_eq(sm.state, ActionStateMachine.State.IDLE)


func test_movement_mode_per_kind() -> void:
	var expected := {
		SkillData.Kind.SPIN: ActionStateMachine.MoveMode.SLOWED,
		SkillData.Kind.VOLLEY: ActionStateMachine.MoveMode.SLOWED,
		SkillData.Kind.FIREBALL: ActionStateMachine.MoveMode.LOCKED,
		SkillData.Kind.DASH_STRIKE: ActionStateMachine.MoveMode.SKILL_DASH,
	}
	for kind in expected:
		var sm := _sm(_skill(kind))
		sm.tick(_intent(true), DT)
		assert_eq(sm.movement_mode(), expected[kind], "move mode for kind %d" % kind)


func test_cooldown_scale() -> void:
	var sm := _sm(_skill(SkillData.Kind.SPIN, SkillData.AimMode.NONE, 4.0, 0.1))
	sm.skill_cooldown_scale = 0.5
	sm.tick(_intent(true), DT)
	assert_true(absf(sm.skill_cooldown_left() - 2.0) < 0.05, "cooldown halved")


# ---------------------------------------------------------------- data

func test_weapon_skills_are_wired_to_the_table() -> void:
	var T: Dictionary = SkillData.Tag
	var rows := [
		[Weapons.WEAPONS.SWORD, SkillData.Kind.SPIN, "sword_spin", [T.DEFENSIVE, T.DAMAGE, T.MELEE]],
		[Weapons.WEAPONS.DAGGER, SkillData.Kind.DASH_STRIKE, "dagger_dash", [T.GAP_CLOSER, T.DAMAGE, T.RANGED]],
		[Weapons.WEAPONS.BOW, SkillData.Kind.VOLLEY, "bow_volley", [T.DAMAGE, T.AOE, T.RANGED]],
		[Weapons.WEAPONS.STAFF, SkillData.Kind.FIREBALL, "staff_fireball", [T.DAMAGE, T.AOE, T.RANGED]],
	]
	for row in rows:
		var w := Weapons.get_weapon_data(row[0])
		var label := w.display_name
		assert_true(w.skill != null, label + " has a skill")
		if w.skill == null:
			continue
		assert_eq(w.skill.kind, row[1], label + " skill kind")
		assert_eq(Skills.id_of(w.skill), row[2], label + " skill file")
		assert_eq(w.skill.damage_mult, Skills.value(row[2], "damage_mult"), label + " multiplier from the skills table")
		assert_eq(w.skill.cooldown, Skills.value(row[2], "cooldown"), label + " cooldown from the skills table")
		assert_gt(w.skill.damage_mult, 0.0, label + " deals damage")
		for tag in row[3]:
			assert_true(w.skill.has_tag(tag), label + " has tag %d" % tag)
	var bow := Weapons.get_weapon_data(Weapons.WEAPONS.BOW).skill
	assert_gt(bow.volley_count, 1, "several volleys")
	var staff := Weapons.get_weapon_data(Weapons.WEAPONS.STAFF).skill
	assert_gt(staff.dot_mult_per_sec, 0.0, "the burning ground hurts")
	assert_gt(staff.cast_time, 0.0, "the fireball has a cast time")
	assert_gt(staff.duration, 0.0, "the Mage stays busy a moment after the throw")
	assert_gt(staff.dot_stagger_time, 0.0, "every burn tick staggers")
	assert_true(Weapons.get_weapon_data(Weapons.WEAPONS.NONE).skill == null, "unarmed has no skill")


# ---------------------------------------------------------------- skills table

func test_every_table_row_matches_a_skill_file_and_fields() -> void:
	var props := {}
	for p in SkillData.new().get_property_list():
		props[p.name] = true
	for id in Skills.TABLE:
		var path := "res://assets/combat/skills/%s.tres" % id
		assert_true(ResourceLoader.exists(path), "table row %s has a skill file" % id)
		for field in Skills.TABLE[id]:
			var prop: String = Skills.TILE_FIELDS.get(field, Skills.RENAMED_FIELDS.get(field, field))
			assert_true(props.has(prop), "%s.%s sets a real SkillData property (%s)" % [id, field, prop])


func test_table_values_reach_the_loaded_skills() -> void:
	var staff := Weapons.get_weapon_data(Weapons.WEAPONS.STAFF).skill
	assert_eq(staff.cast_time, Skills.value("staff_fireball", "cast_time"), "cast time from the table")
	assert_eq(staff.damage_mult, Skills.value("staff_fireball", "damage_mult"), "damage from the table")
	assert_eq(staff.max_range, float(Skills.value("staff_fireball", "range_tiles")) * SkillData.TILE, "range tiles -> pixels")
	var spin := Weapons.get_weapon_data(Weapons.WEAPONS.SWORD).skill
	assert_eq(spin.max_range, spin.radius, "the spin reaches as far as its circle")
	var volley := Weapons.get_weapon_data(Weapons.WEAPONS.BOW).skill
	assert_gt(volley.duration, volley.volley_interval * (volley.volley_count - 1), "the volley lasts through its last volley")


func test_skill_sliders_default_to_the_table() -> void:
	DevSettings.reset_all()
	for def in DevSettings.DEFS:
		if def.has("skill"):
			assert_eq(DevSettings.default_of(def.key), Skills.value(def.skill, def.field), def.key + " defaults to the table")
