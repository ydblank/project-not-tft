@tool
extends McpTestSuite

# Checks the sound table: every file it names exists, and the tuning choices made
# by ear stay as decided.

const SfxScript := preload("res://assets/commons/sfx.gd")


func suite_name() -> String:
	return "sfx"


func _files_of(sound: StringName) -> Array:
	var entry: Variant = SfxScript.SOUNDS[sound]
	return entry if entry is Array else [entry]


func test_every_listed_file_exists() -> void:
	for sound in SfxScript.SOUNDS:
		for file in _files_of(sound):
			assert_true(ResourceLoader.exists(SfxScript.FOLDER + String(file)), "%s: %s exists" % [sound, file])


func test_dash_is_the_grunt_only() -> void:
	var files := _files_of(&"dash")
	assert_eq(files.size(), 1, "dash has a single recording (no whoosh variant)")
	assert_eq(files[0], "dash.wav")


func test_heavy_swing_is_quieter_than_recorded() -> void:
	assert_true(CombatComponent.SWING_HEAVY_DB < 0.0, "heavy swing is turned down")
	assert_true(CombatComponent.SWING_PITCH_LIGHT < 1.0 and CombatComponent.SWING_PITCH_HEAVY < 1.0, "swings are pitched down")
	assert_true(CombatComponent.DASH_PITCH_JITTER > 0.0 and CombatComponent.DASH_PITCH_JITTER <= 0.06, "dash grunt varies only a little")


func test_dagger_swings_stay_out() -> void:
	for file in _files_of(&"swing_light"):
		assert_false(String(file).contains("dagger"), "no dagger swing in the quick-swing pool")


func test_grunt_and_quick_swing_level() -> void:
	assert_true(SfxScript.SOUNDS.has(&"grunt"), "a grunt sound exists for landed hits")
	assert_true(CombatComponent.SWING_LIGHT_DB < -3.0, "quick swing is turned down clearly")
	assert_true(HitboxComponent.GRUNT_CHANCE_LIGHT < HitboxComponent.GRUNT_CHANCE_HEAVY, "heavy hits grunt more often than quick ones")
	assert_true(HitboxComponent.GRUNT_CHANCE_LIGHT < 0.5, "quick hits grunt only some of the time")


func test_arrow_sounds_are_turned_down() -> void:
	assert_true(CombatComponent.BOW_RELEASE_DB <= -6.0, "bow shot is turned down clearly")
	assert_true(HitboxComponent.ARROW_HIT_DB < 0.0, "arrow impact is quieter than a melee hit")


func test_block_is_turned_down_and_countdown_is_not_a_beep() -> void:
	assert_true(HitboxComponent.BLOCK_DB <= -6.0, "block clang is turned down clearly")
	assert_true(HitboxComponent.BLOCK_DB + HitboxComponent.ARROW_HIT_DB < HitboxComponent.BLOCK_DB, "blocking an arrow is quieter still")
	for sound in [&"countdown_tick", &"fight"]:
		assert_true(ResourceLoader.exists(SfxScript.FOLDER + String(SfxScript.SOUNDS[sound])), "%s exists" % sound)
