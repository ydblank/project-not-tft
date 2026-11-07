@tool
extends McpTestSuite

# Rebindable controls (Keybinds): bindings <-> events, swapping on conflict, reset, save / load.
# Every test ends with Keybinds.reset_all() so the real InputMap is left as the project has it.

const TMP_PATH := "user://test_keybinds.cfg"


func suite_name() -> String:
	return "keybinds"


func teardown() -> void:
	Keybinds.reset_all()


func _key(code: Key) -> Dictionary:
	return {"type": "key", "code": int(code)}


func _has_key_event(action: StringName, code: Key) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey and (e.physical_keycode == code or e.keycode == code):
			return true
	return false


func test_events_round_trip() -> void:
	var bindings := [
		_key(KEY_Q),
		{"type": "mouse", "button": MOUSE_BUTTON_RIGHT},
		{"type": "joy_button", "index": JOY_BUTTON_Y},
		{"type": "joy_axis", "axis": JOY_AXIS_TRIGGER_LEFT, "sign": 1},
	]
	for b in bindings:
		var back := Keybinds.binding_of(Keybinds.event_of(b))
		assert_eq(back, b, "round trip " + Keybinds.describe(b))


func test_defaults_come_from_the_project() -> void:
	Keybinds.reset_all()
	assert_eq(Keybinds.describe_keyboard(&"skill"), "E", "skill is E")
	assert_true(Keybinds.describe_keyboard(&"dash").contains("Space"), "dash keeps Space")
	assert_eq(Keybinds.describe_pad(&"skill"), "B", "controller skill is B")
	assert_eq(Keybinds.describe_pad(&"Attack"), "RT / X")
	assert_eq(Keybinds.describe_keyboard(&"ultimate"), "Q", "ultimate is Q")
	assert_eq(Keybinds.describe_pad(&"ultimate"), "RB", "controller ultimate is RB")
	assert_false(Keybinds.describe_pad(&"dash").contains("RB"), "dash gave RB to the ultimate")


func test_rebinding_a_key_updates_the_input_map() -> void:
	Keybinds.set_keyboard(&"skill", _key(KEY_T))
	assert_true(_has_key_event(&"skill", KEY_T), "T now casts the skill")
	assert_false(_has_key_event(&"skill", KEY_E), "E no longer does")
	Keybinds.reset_all()
	assert_true(_has_key_event(&"skill", KEY_E), "reset puts E back")


func test_a_taken_key_is_swapped() -> void:
	Keybinds.set_keyboard(&"skill", _key(KEY_W)) # W moves up
	assert_true(_has_key_event(&"skill", KEY_W), "skill gets W")
	assert_true(_has_key_event(&"W", KEY_E), "move up gets the skill's old key")
	assert_false(_has_key_event(&"W", KEY_W), "and no longer has W")


func test_one_of_several_keys_is_just_dropped() -> void:
	Keybinds.set_keyboard(&"skill", _key(KEY_SPACE)) # dash has F and Space
	assert_true(_has_key_event(&"skill", KEY_SPACE))
	assert_false(_has_key_event(&"dash", KEY_SPACE), "dash loses Space")
	assert_true(_has_key_event(&"dash", KEY_F), "but keeps F")
	assert_false(_has_key_event(&"dash", KEY_E), "and does not pick up E")


func test_pad_rebind_and_swap() -> void:
	var a := {"type": "joy_button", "index": JOY_BUTTON_A} # a dash button by default
	Keybinds.set_pad(&"skill", a)
	assert_eq(Keybinds.pad_bindings(&"skill"), [a], "skill on A")
	assert_false(Keybinds.describe_pad(&"dash").contains("A"), "dash lets go of A")
	assert_true(Keybinds.describe_pad(&"dash").contains("LT"), "dash keeps LT")


func test_save_and_load() -> void:
	Keybinds.set_keyboard(&"Attack", _key(KEY_J))
	Keybinds.set_pad(&"Block", {"type": "joy_button", "index": JOY_BUTTON_X})
	var cfg := ConfigFile.new()
	assert_eq(Keybinds.save(), OK)
	var saved := ConfigFile.new()
	assert_eq(saved.load(Keybinds.SAVE_PATH), OK)
	assert_eq(saved.save(TMP_PATH), OK)
	Keybinds.reset_all()
	assert_eq(Keybinds.load_file(TMP_PATH), OK)
	assert_eq(Keybinds.describe_pad(&"Block"), "X", "controller binding loaded")
	Keybinds.set_keyboard(&"Attack", Keybinds.keyboard_bindings(&"Attack")[0]) # re-apply to the InputMap
	assert_true(_has_key_event(&"Attack", KEY_J), "keyboard binding loaded")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_PATH))
	Keybinds.reset_all()
	Keybinds.save() # leave the real file at the defaults
