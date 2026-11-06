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
	assert_eq(sword.power_mult, 1.0)
	assert_eq(sword.light_move_count(), 3)
	assert_eq([sword.light_moves[0].damage_mult, sword.light_moves[1].damage_mult, sword.light_moves[2].damage_mult], [0.5, 0.5, 1.2])
	assert_eq(sword.light_moves[2].reaction, AttackMove.Reaction.KNOCKBACK, "final sword hit knocks back")
	assert_eq(sword.light_moves[0].reaction, AttackMove.Reaction.STAGGER)
	assert_eq(sword.heavy_hit_count(), 3, "sword heavy is a 3-hit combo")
	assert_true(sword.light_combo_cooldown > 0.0, "sword has a quick-combo cooldown")
	var dagger := Weapons.get_weapon_data(Weapons.WEAPONS.DAGGER)
	assert_eq(dagger.power_mult, 1.0)
	assert_eq(dagger.light_move_count(), 4)
	var bow := Weapons.get_weapon_data(Weapons.WEAPONS.BOW)
	assert_eq(bow.power_mult, 1.0)
	assert_eq(bow.kind, WeaponData.Kind.RANGED)
	assert_eq(bow.heavy_max_mult, 2.0)
	assert_eq(bow.heavy_hit_count(), 1, "bow heavy stays a single shot")
	assert_gt(bow.light_combo_cooldown, 0.0, "bow has a cooldown between quick shots (no machine gun)")
	assert_gt(bow.max_charge_time, sword.max_charge_time, "a full bow charge takes longer than melee")


func test_damage_and_speed_formulas() -> void:
	var sword := Weapons.get_weapon_data(Weapons.WEAPONS.SWORD)
	var unarmed := Weapons.get_weapon_data(Weapons.WEAPONS.NONE)
	var bow := Weapons.get_weapon_data(Weapons.WEAPONS.BOW)
	assert_eq(CombatGlobal.attack_damage(10.0, sword), 10.0, "power 10 × sword 1.0")
	assert_eq(CombatGlobal.attack_damage(20.0, sword), 20.0)
	assert_eq(CombatGlobal.attack_damage(7.0, bow), 7.0, "power 7 × bow 1.0")
	assert_eq(CombatGlobal.attack_damage(7.0, unarmed), 7.0, "fist uses the fighter's power")
	assert_eq(CombatGlobal.attack_damage(0.0, sword), 1.0, "no power floors at 1")
	assert_eq(CombatGlobal.attack_damage(0.5, null), 1.0, "floors at 1")
	assert_eq(CombatGlobal.attack_damage(5.0, null), 5.0, "no weapon: power as it is")
	# Knight (bonus -0.15) with sword (+0.10) at base 1.0
	assert_true(is_equal_approx(CombatGlobal.attack_speed(1.0 - 0.15, sword), 0.95), "knight + sword speed 0.95")


func test_every_class_weapon_pair_has_positive_speed() -> void:
	for class_id in Classes.CLASSES.values():
		var class_bonus: float = float(Classes.classStats[class_id].get("bonus_attack_speed", 0.0))
		for weapon_id in Weapons.WEAPONS.values():
			var speed := CombatGlobal.attack_speed(1.0 + class_bonus, Weapons.get_weapon_data(weapon_id))
			assert_gt(speed, 0.5, "speed %s/%s" % [class_id, weapon_id])


## Design sheet (GAM-29): class -> [weapon, power, defense, knockback res, attack speed rating, HP].
## The sheet lists Fist for the Archer; the bow stays until the slingshot exists.
func test_class_table_matches_sheet() -> void:
	var sheet := {
		Classes.CLASSES.KNIGHT: [Weapons.WEAPONS.SWORD, 10, 10, 10, 2, 100],
		Classes.CLASSES.THIEF: [Weapons.WEAPONS.DAGGER, 5, 7, 5, 10, 100],
		Classes.CLASSES.ARCHER: [Weapons.WEAPONS.BOW, 7, 5, 5, 7, 100],
	}
	for class_id in sheet:
		var row: Array = sheet[class_id]
		var label := str(Classes.CLASSES.keys()[class_id])
		var stats: Dictionary = Classes.classStats[class_id]
		assert_eq(stats.allowed_weapons, [row[0]], label + " has only its starting weapon")
		assert_eq(stats.bonus_power, row[1], label + " power")
		assert_eq(stats.bonus_def, row[2], label + " defense")
		assert_eq(stats.bonus_knockback_res, row[3], label + " knockback res")
		var rating_bonus: float = Classes.ATTACK_SPEED_PER_POINT * float(row[4]) - Classes.ATTACK_SPEED_OFFSET
		assert_true(is_equal_approx(float(stats.bonus_attack_speed), rating_bonus), label + " attack speed rating")
		assert_eq(stats.bonus_hp, 0, label + " HP stays at the 100 base")


## Stats a fighter really gets (base + class), and the hit damage of each class with its starting weapon.
func test_class_totals_and_starting_weapon_damage() -> void:
	var expected := {
		Classes.CLASSES.KNIGHT: {"weapon": Weapons.WEAPONS.SWORD, "power": 10.0, "def": 10.0, "knockback_res": 10.0, "hp": 100.0},
		Classes.CLASSES.THIEF: {"weapon": Weapons.WEAPONS.DAGGER, "power": 5.0, "def": 7.0, "knockback_res": 5.0, "hp": 100.0},
		Classes.CLASSES.ARCHER: {"weapon": Weapons.WEAPONS.BOW, "power": 7.0, "def": 5.0, "knockback_res": 5.0, "hp": 100.0},
	}
	for class_id in expected:
		var want: Dictionary = expected[class_id]
		var label := str(Classes.CLASSES.keys()[class_id])
		var stats := StatsComponent.new()
		stats.entity_class = class_id
		stats.entity_weapon = want["weapon"]
		var got := stats.get_entity_stats()
		for key in ["power", "def", "knockback_res", "hp"]:
			assert_eq(got[key], want[key], "%s %s" % [label, key])
		assert_eq(CombatGlobal.calculate_attack_damage(stats), want["power"], label + " hit damage with its starting weapon")
		stats.free()


func test_defense_reduces_damage_with_floor() -> void:
	assert_eq(snappedf(CombatGlobal.receive_damage(20.0, 10.0), 0.001), 8.0, "knight def 20")
	assert_eq(CombatGlobal.receive_damage(20.0, 0.5), 1.0, "minimum 1")
	assert_eq(CombatGlobal.receive_damage(0.0, 7.0), 7.0)
