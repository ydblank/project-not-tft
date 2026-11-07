@tool
extends McpTestSuite

const TMP_PATH := "user://test_dev_settings.cfg"


func suite_name() -> String:
	return "dev_settings"


func test_defs_are_well_formed() -> void:
	var seen: Dictionary = {}
	for def in DevSettings.DEFS:
		assert_false(seen.has(def.key), "duplicate key " + def.key)
		seen[def.key] = true
		assert_true(def.has("label") and def.has("group") and def.has("type"), def.key + " has label/group/type")
		if def.type != "bool":
			assert_true(def.min < def.max, def.key + " min < max")
			var default: Variant = DevSettings.default_of(def.key)
			assert_true(default != null and default >= def.min and default <= def.max, def.key + " default in range")
			assert_true(def.step > 0.0, def.key + " has a step")


func test_set_value_clamps_and_coerces() -> void:
	DevSettings.reset_all()
	DevSettings.set_value("dash_charges", 99)
	assert_eq(DevSettings.get_value("dash_charges"), 5, "int clamped to max")
	DevSettings.set_value("dash_speed", -5.0)
	assert_eq(DevSettings.get_value("dash_speed"), 100.0, "float clamped to min")
	DevSettings.set_value("dash_invulnerable", 0)
	assert_eq(DevSettings.get_value("dash_invulnerable"), false)
	DevSettings.reset_all()


func test_unknown_key_is_ignored() -> void:
	DevSettings.reset_all()
	DevSettings.set_value("not_a_setting", 1.0)
	assert_false(DevSettings.values.has("not_a_setting"))


func test_save_and_load_round_trip() -> void:
	DevSettings.reset_all()
	DevSettings.set_value("dash_charges", 4)
	DevSettings.set_value("knockback_force", 400.0)
	DevSettings.set_value("ai_dodge_enabled", false)
	var cfg := ConfigFile.new()
	for def in DevSettings.DEFS:
		cfg.set_value(DevSettings.SECTION, def.key, DevSettings.values[def.key])
	assert_eq(cfg.save(TMP_PATH), OK)

	DevSettings.reset_all()
	assert_eq(DevSettings.get_value("dash_charges"), 3, "reset to default first")
	assert_eq(DevSettings.load_file(TMP_PATH), OK)
	assert_eq(DevSettings.get_value("dash_charges"), 4)
	assert_eq(DevSettings.get_value("knockback_force"), 400.0)
	assert_eq(DevSettings.get_value("ai_dodge_enabled"), false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_PATH))
	DevSettings.reset_all()


func test_missing_file_keeps_defaults() -> void:
	DevSettings.reset_all()
	assert_true(DevSettings.load_file("user://definitely_missing.cfg") != OK)
	assert_true(DevSettings.is_default("dash_charges"))
