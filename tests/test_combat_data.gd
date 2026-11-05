@tool
extends McpTestSuite


func suite_name() -> String:
	return "combat_data"


func test_every_weapon_resource_is_valid() -> void:
	for weapon_id in Weapons.WEAPONS.values():
		var w := Weapons.get_weapon_data(weapon_id)
		var label := str(Weapons.WEAPONS.keys()[weapon_id])
		assert_true(w != null, label + " loads as WeaponData")
		if w == null:
			continue
		assert_gt(w.light_move_count(), 0, label + " has light moves")
		assert_true(w.heavy_move != null, label + " has a heavy move")
		assert_gt(w.max_charge_time, w.charge_threshold, label + " max charge > threshold")
		var moves: Array[AttackMove] = w.light_moves.duplicate()
		moves.append(w.heavy_move)
		for m in moves:
			assert_true(m != null, label + " move not null")
			assert_gt(m.startup, 0.0, label + " startup > 0")
			assert_gt(m.active, 0.0, label + " active > 0")
			assert_gt(m.recovery, 0.0, label + " recovery > 0")
			assert_gt(m.damage_mult, 0.0, label + " damage_mult > 0")
		if w.kind == WeaponData.Kind.RANGED:
			assert_true(w.projectile_scene != null, label + " ranged weapon has a projectile")


func test_weapon_values_carried_over() -> void:
	var sword := Weapons.get_weapon_data(Weapons.WEAPONS.SWORD)
	assert_eq(sword.base_damage, 10.0)
	assert_eq(sword.light_move_count(), 3)
	assert_eq([sword.light_moves[0].damage_mult, sword.light_moves[1].damage_mult, sword.light_moves[2].damage_mult], [0.5, 0.5, 1.2])
	assert_eq(sword.light_moves[2].reaction, AttackMove.Reaction.KNOCKBACK, "final sword hit knocks back")
	assert_eq(sword.light_moves[0].reaction, AttackMove.Reaction.STAGGER)
	var dagger := Weapons.get_weapon_data(Weapons.WEAPONS.DAGGER)
	assert_eq(dagger.base_damage, 5.0)
	assert_eq(dagger.light_move_count(), 4)
	var bow := Weapons.get_weapon_data(Weapons.WEAPONS.BOW)
	assert_eq(bow.kind, WeaponData.Kind.RANGED)
	assert_eq(bow.heavy_max_mult, 2.5)


func test_damage_and_speed_formulas() -> void:
	var sword := Weapons.get_weapon_data(Weapons.WEAPONS.SWORD)
	var unarmed := Weapons.get_weapon_data(Weapons.WEAPONS.NONE)
	assert_eq(CombatGlobal.attack_damage(1.0, sword), 10.0, "str 1 × sword 10")
	assert_eq(CombatGlobal.attack_damage(2.0, sword), 20.0)
	assert_eq(CombatGlobal.attack_damage(1.0, unarmed), 1.0, "unarmed floors at 1")
	assert_eq(CombatGlobal.attack_damage(1.0, null), 1.0)
	# Knight (bonus -0.15) with sword (+0.10) at base 1.0
	assert_true(is_equal_approx(CombatGlobal.attack_speed(1.0 - 0.15, sword), 0.95), "knight + sword speed 0.95")


func test_every_class_weapon_pair_has_positive_speed() -> void:
	for class_id in Classes.CLASSES.values():
		var class_bonus: float = float(Classes.classStats[class_id].get("bonus_attack_speed", 0.0))
		for weapon_id in Weapons.WEAPONS.values():
			var speed := CombatGlobal.attack_speed(1.0 + class_bonus, Weapons.get_weapon_data(weapon_id))
			assert_gt(speed, 0.5, "speed %s/%s" % [class_id, weapon_id])


func test_defense_reduces_damage_with_floor() -> void:
	assert_eq(snappedf(CombatGlobal.receive_damage(20.0, 10.0), 0.001), 8.0, "knight def 20")
	assert_eq(CombatGlobal.receive_damage(20.0, 0.5), 1.0, "minimum 1")
	assert_eq(CombatGlobal.receive_damage(0.0, 7.0), 7.0)
