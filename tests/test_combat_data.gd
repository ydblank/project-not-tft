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
	var staff := Weapons.get_weapon_data(Weapons.WEAPONS.STAFF)
	assert_eq(staff.kind, WeaponData.Kind.RANGED)
	assert_eq(staff.power_mult, 0.75)
	assert_eq(staff.heavy_hit_count(), 1, "staff heavy stays a single fireball")
	assert_gt(staff.light_combo_cooldown, bow.light_combo_cooldown, "staff quick shots are slower than the bow's")
	assert_gt(staff.heavy_max_mult, bow.heavy_max_mult, "a full staff charge hits harder than a full bow draw")
	assert_gt(staff.max_charge_time, bow.max_charge_time, "and takes longer to reach")
	var shot := staff.projectile_scene.instantiate()
	assert_true(shot is FireballProjectile, "staff fires a fireball")
	shot.free()


func test_fireball_grows_with_charge() -> void:
	assert_eq(FireballProjectile.size_for_charge(1.0), 1.0, "a quick shot is normal size")
	assert_gt(FireballProjectile.size_for_charge(2.5), FireballProjectile.size_for_charge(1.5), "more charge, bigger fireball")
	assert_true(is_equal_approx(FireballProjectile.size_for_charge(2.5), 1.9), "full staff charge is 1.9x")
	assert_eq(FireballProjectile.size_for_charge(0.1), FireballProjectile.MIN_SIZE, "size has a floor")


## A held (heavy) fireball explodes on contact; a quick one is a plain single hit.
func test_only_heavy_fireballs_explode() -> void:
	var staff := Weapons.get_weapon_data(Weapons.WEAPONS.STAFF)
	var heavy_hit := HitData.new()
	heavy_hit.is_heavy = true
	var heavy := staff.projectile_scene.instantiate() as FireballProjectile
	heavy.setup(heavy_hit, null, 2.0)
	assert_true(heavy.explodes, "heavy fireball explodes")
	var quick := staff.projectile_scene.instantiate() as FireballProjectile
	quick.setup(HitData.new(), null, 1.0)
	assert_false(quick.explodes, "quick fireball is a single hit")
	heavy.free()
	quick.free()


## The blast is neither tiny nor huge, and grows with the charge.
func test_fireball_blast_radius_and_falloff() -> void:
	var small := FireballProjectile.blast_radius(FireballProjectile.size_for_charge(0.6))
	var full := FireballProjectile.blast_radius(FireballProjectile.size_for_charge(2.5))
	assert_gt(small, 15.0, "even a weak blast is not insignificant")
	assert_gt(full, small, "a full charge has the bigger blast")
	assert_gt(60.0, full, "and it is not massive (under two fighters wide each side)")
	assert_eq(FireballProjectile.falloff(0.0, full, 0.5), 1.0, "full damage at the centre")
	assert_eq(FireballProjectile.falloff(full, full, 0.5), 0.5, "edge share at the rim")
	assert_eq(FireballProjectile.falloff(full * 3.0, full, 0.5), 0.5, "never below the edge share")


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
		Classes.CLASSES.MAGE: [Weapons.WEAPONS.STAFF, 12, 3, 5, 5, 100],
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


## Mage design: powerful but frail, slower than Archer and Thief, faster than Knight.
func test_mage_balance_against_other_classes() -> void:
	var speed := {}
	for pair in [
		[Classes.CLASSES.KNIGHT, Weapons.WEAPONS.SWORD],
		[Classes.CLASSES.MAGE, Weapons.WEAPONS.STAFF],
		[Classes.CLASSES.ARCHER, Weapons.WEAPONS.BOW],
		[Classes.CLASSES.THIEF, Weapons.WEAPONS.DAGGER],
	]:
		var bonus: float = float(Classes.classStats[pair[0]].bonus_attack_speed)
		speed[pair[0]] = CombatGlobal.attack_speed(1.0 + bonus, Weapons.get_weapon_data(pair[1]))
	assert_gt(speed[Classes.CLASSES.MAGE], speed[Classes.CLASSES.KNIGHT], "mage is faster than the knight")
	assert_gt(speed[Classes.CLASSES.ARCHER], speed[Classes.CLASSES.MAGE], "mage is slower than the archer")
	assert_gt(speed[Classes.CLASSES.THIEF], speed[Classes.CLASSES.MAGE], "mage is slower than the thief")
	var mage: Dictionary = Classes.classStats[Classes.CLASSES.MAGE]
	var archer: Dictionary = Classes.classStats[Classes.CLASSES.ARCHER]
	assert_gt(archer.bonus_def, mage.bonus_def, "mage is frailer than the archer")
	assert_gt(mage.bonus_power, archer.bonus_power, "mage has more power than the archer")
	var staff := Weapons.get_weapon_data(Weapons.WEAPONS.STAFF)
	var bow := Weapons.get_weapon_data(Weapons.WEAPONS.BOW)
	var mage_full: float = CombatGlobal.attack_damage(mage.bonus_power, staff) * staff.heavy_move.damage_mult * staff.heavy_max_mult
	var archer_full: float = CombatGlobal.attack_damage(archer.bonus_power, bow) * bow.heavy_move.damage_mult * bow.heavy_max_mult
	assert_gt(mage_full, archer_full, "a full staff charge out-damages a full bow draw")


## The pointy hat is the Mage, the green hood the Archer (shared with the Thief).
func test_class_sprites() -> void:
	assert_true(str(Classes.classStats[Classes.CLASSES.MAGE].sprite_path).ends_with("/3/3.png"), "mage: pointy hat")
	assert_true(str(Classes.classStats[Classes.CLASSES.ARCHER].sprite_path).ends_with("/1/1.png"), "archer: green hood")


## Stats a fighter really gets (base + class), and the hit damage of each class with its starting weapon.
func test_class_totals_and_starting_weapon_damage() -> void:
	var expected := {
		Classes.CLASSES.KNIGHT: {"weapon": Weapons.WEAPONS.SWORD, "power": 10.0, "def": 10.0, "knockback_res": 10.0, "hp": 100.0},
		Classes.CLASSES.THIEF: {"weapon": Weapons.WEAPONS.DAGGER, "power": 5.0, "def": 7.0, "knockback_res": 5.0, "hp": 100.0},
		Classes.CLASSES.ARCHER: {"weapon": Weapons.WEAPONS.BOW, "power": 7.0, "def": 5.0, "knockback_res": 5.0, "hp": 100.0},
		Classes.CLASSES.MAGE: {"weapon": Weapons.WEAPONS.STAFF, "power": 12.0, "def": 3.0, "knockback_res": 5.0, "hp": 100.0, "hit": 9.0}, # staff power_mult 0.75
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
		assert_eq(CombatGlobal.calculate_attack_damage(stats), want.get("hit", want["power"]), label + " hit damage with its starting weapon")
		stats.free()


func test_defense_reduces_damage_with_floor() -> void:
	assert_eq(snappedf(CombatGlobal.receive_damage(20.0, 10.0), 0.001), 8.0, "knight def 20")
	assert_eq(CombatGlobal.receive_damage(20.0, 0.5), 1.0, "minimum 1")
	assert_eq(CombatGlobal.receive_damage(0.0, 7.0), 7.0)


# ---------------------------------------------------------------- weapons table

func test_every_weapon_has_a_table_row_that_fits_its_moves() -> void:
	var props := {}
	for p in WeaponData.new().get_property_list():
		props[p.name] = true
	var special := ["type", "skill", "light_damage", "heavy_damage"]
	for weapon_id in Weapons.WEAPONS.values():
		var label := str(Weapons.WEAPONS.keys()[weapon_id])
		assert_true(Weapons.TABLE.has(weapon_id), label + " has a weapons-table row")
		var row: Dictionary = Weapons.TABLE.get(weapon_id, {})
		var w := Weapons.get_weapon_data(weapon_id)
		for field in row:
			assert_true(special.has(field) or props.has(field), "%s.%s is a real WeaponData property" % [label, field])
		if row.has("light_damage"):
			assert_eq(row.light_damage.size(), w.light_move_count(), label + ": one light_damage per quick hit")
		if row.has("heavy_damage"):
			assert_eq(row.heavy_damage.size(), Weapons.heavy_moves(w).size(), label + ": one heavy_damage per heavy hit")
		if String(row.get("skill", "")) != "":
			assert_true(ResourceLoader.exists(Weapons.SKILL_PATH % row.skill), label + " skill file exists")


func test_table_values_reach_the_loaded_weapons() -> void:
	for weapon_id in Weapons.WEAPONS.values():
		var row: Dictionary = Weapons.TABLE[weapon_id]
		var w := Weapons.get_weapon_data(weapon_id)
		var label := str(Weapons.WEAPONS.keys()[weapon_id])
		assert_eq(w.weapon_type, row.type, label + " type from the table")
		if row.has("power_mult"):
			assert_eq(w.power_mult, row.power_mult, label + " power from the table")
		for i in row.get("light_damage", []).size():
			assert_eq(w.light_moves[i].damage_mult, row.light_damage[i], label + " light hit %d damage" % i)
		var heavies := Weapons.heavy_moves(w)
		for i in row.get("heavy_damage", []).size():
			assert_eq(heavies[i].damage_mult, row.heavy_damage[i], label + " heavy hit %d damage" % i)
		var skill_id: String = row.get("skill", "")
		assert_eq(Skills.id_of(w.skill), skill_id, label + " skill from the table")


func test_weapon_types() -> void:
	var expected := {
		Weapons.WEAPONS.SWORD: WeaponData.Type.SWORD,
		Weapons.WEAPONS.DAGGER: WeaponData.Type.DAGGER,
		Weapons.WEAPONS.BOW: WeaponData.Type.BOW,
		Weapons.WEAPONS.STAFF: WeaponData.Type.STAFF,
	}
	for weapon_id in expected:
		assert_eq(Weapons.get_weapon_data(weapon_id).weapon_type, expected[weapon_id])
