extends RefCounted
class_name Keybinds

# Remappable controls for Player 1 (1P mode): one keyboard / mouse input and one controller input
# per action, edited in Pause -> Settings -> Controls -> Key bindings and saved to SAVE_PATH.
#
#   keyboard  the project's own bindings (project.godot) are the defaults. A rebind replaces the
#             action's key / mouse events in the InputMap; the defaults are remembered so Reset puts
#             them back.
#   pad       PAD_DEFAULTS (what GamepadControls used to hard-code). GamepadControls asks
#             pad_bindings() when it adds the controller bindings, so a rebind takes effect when it
#             rebuilds them (Keybinds asks it to). Movement and aim stay on the sticks / D-pad.
#
# Binding a key that another action already uses swaps them, so no action is left unbound.
# Bindings are stored as small dictionaries (see binding_of / event_of), so the save file is plain text.

const SAVE_PATH := "user://keybinds.cfg"

## Actions you can rebind, in menu order. pad = false: movement, driven by the left stick / D-pad.
const ACTIONS: Array[Dictionary] = [
	{"action": &"W", "label": "Move up", "pad": false},
	{"action": &"S", "label": "Move down", "pad": false},
	{"action": &"A", "label": "Move left", "pad": false},
	{"action": &"D", "label": "Move right", "pad": false},
	{"action": &"Attack", "label": "Attack", "pad": true},
	{"action": &"Block", "label": "Block", "pad": true},
	{"action": &"dash", "label": "Dash", "pad": true},
	{"action": &"skill", "label": "Skill", "pad": true},
	{"action": &"ultimate", "label": "Ultimate", "pad": true},
]

## Controller defaults per action (any of them works). Triggers are axes pulled past half way.
const PAD_DEFAULTS := {
	&"Attack": [{"type": "joy_axis", "axis": JOY_AXIS_TRIGGER_RIGHT, "sign": 1}, {"type": "joy_button", "index": JOY_BUTTON_X}],
	&"Block": [{"type": "joy_button", "index": JOY_BUTTON_LEFT_SHOULDER}],
	&"dash": [{"type": "joy_axis", "axis": JOY_AXIS_TRIGGER_LEFT, "sign": 1}, {"type": "joy_button", "index": JOY_BUTTON_A}],
	&"skill": [{"type": "joy_button", "index": JOY_BUTTON_B}],
	&"ultimate": [{"type": "joy_button", "index": JOY_BUTTON_RIGHT_SHOULDER}],
}

const PAD_BUTTON_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_GUIDE: "Guide", JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "LS click", JOY_BUTTON_RIGHT_STICK: "RS click",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
}
const PAD_AXIS_NAMES := {
	JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT",
	JOY_AXIS_LEFT_X: "Left stick X", JOY_AXIS_LEFT_Y: "Left stick Y",
	JOY_AXIS_RIGHT_X: "Right stick X", JOY_AXIS_RIGHT_Y: "Right stick Y",
}
## Buttons the menus need (Start pauses, B backs out of menus, Y switches character): never bound to an action.
const PAD_RESERVED := [JOY_BUTTON_START, JOY_BUTTON_GUIDE, JOY_BUTTON_Y]

## True while the key-bindings screen waits for a press (GamepadControls then leaves B and Start alone).
static var capturing: bool = false
static var _loaded: bool = false
## action -> Array[InputEvent]: the keyboard / mouse events project.godot gave the action.
static var _project_keys: Dictionary = {}
## action -> Array of binding dictionaries, only for actions you rebound.
static var _keyboard: Dictionary = {}
## action -> Array of binding dictionaries, only for actions you rebound.
static var _pad: Dictionary = {}


## Remembers the project defaults, then loads and applies the saved bindings. Safe to call repeatedly.
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for entry in ACTIONS:
		var events: Array[InputEvent] = []
		if InputMap.has_action(entry.action):
			for e in InputMap.action_get_events(entry.action):
				if _is_keyboard_event(e):
					events.append(e)
		_project_keys[entry.action] = events
	load_file()
	_apply_keyboard()


# ======================================================================
# Reading
# ======================================================================

## The keyboard / mouse bindings of an action (the project's, until you rebind it).
static func keyboard_bindings(action: StringName) -> Array:
	ensure_loaded()
	if _keyboard.has(action):
		return _keyboard[action]
	var out: Array = []
	for e in _project_keys.get(action, []):
		out.append(binding_of(e))
	return out


## The controller bindings of an action (GamepadControls adds one event per entry).
static func pad_bindings(action: StringName) -> Array:
	ensure_loaded()
	return _pad.get(action, PAD_DEFAULTS.get(action, []))


## Actions GamepadControls binds on the controller.
static func pad_actions() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry in ACTIONS:
		if entry.pad:
			out.append(entry.action)
	return out


static func describe_keyboard(action: StringName) -> String:
	return _describe_all(keyboard_bindings(action))


static func describe_pad(action: StringName) -> String:
	return _describe_all(pad_bindings(action))


static func _describe_all(bindings: Array) -> String:
	var names: PackedStringArray = []
	for b in bindings:
		names.append(describe(b))
	return " / ".join(names) if not names.is_empty() else "-"


## Human name of one binding ("E", "LMB", "RT", "B").
static func describe(binding: Dictionary) -> String:
	match binding.get("type", ""):
		"key":
			return OS.get_keycode_string(int(binding.code))
		"mouse":
			match int(binding.button):
				MOUSE_BUTTON_LEFT:
					return "LMB"
				MOUSE_BUTTON_RIGHT:
					return "RMB"
				MOUSE_BUTTON_MIDDLE:
					return "MMB"
			return "Mouse %d" % int(binding.button)
		"joy_button":
			return PAD_BUTTON_NAMES.get(int(binding.index), "Button %d" % int(binding.index))
		"joy_axis":
			var axis_name: String = PAD_AXIS_NAMES.get(int(binding.axis), "Axis %d" % int(binding.axis))
			if int(binding.axis) == JOY_AXIS_TRIGGER_LEFT or int(binding.axis) == JOY_AXIS_TRIGGER_RIGHT:
				return axis_name
			return axis_name + (" +" if int(binding.sign) > 0 else " -")
	return "-"


# ======================================================================
# Changing
# ======================================================================

## Binds one keyboard / mouse input to an action (replacing its keys). Another action using it gets
## this action's old first key, or just loses it if it has another.
static func set_keyboard(action: StringName, binding: Dictionary) -> void:
	ensure_loaded()
	var old: Array = keyboard_bindings(action)
	for entry in ACTIONS:
		var other: StringName = entry.action
		if other != action:
			var swapped: Variant = _swap_out(keyboard_bindings(other), binding, old)
			if swapped != null:
				_keyboard[other] = swapped
	_keyboard[action] = [binding]
	_apply_keyboard()


## Binds one controller input to an action (replacing its defaults). Another action using it gets
## this action's old first input, or just loses it if it has another.
static func set_pad(action: StringName, binding: Dictionary) -> void:
	ensure_loaded()
	var old: Array = pad_bindings(action)
	for other in pad_actions():
		if other != action:
			var swapped: Variant = _swap_out(pad_bindings(other), binding, old)
			if swapped != null:
				_pad[other] = swapped
	_pad[action] = [binding]


## Back to the project's keys and the controller defaults.
static func reset_all() -> void:
	ensure_loaded()
	_keyboard.clear()
	_pad.clear()
	_apply_keyboard()


static func save() -> Error:
	var cfg := ConfigFile.new()
	for action in _keyboard:
		cfg.set_value("keyboard", String(action), _keyboard[action])
	for action in _pad:
		cfg.set_value("pad", String(action), _pad[action])
	return cfg.save(SAVE_PATH)


static func load_file(path: String = SAVE_PATH) -> Error:
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err != OK:
		return err
	var known := {}
	for entry in ACTIONS:
		known[String(entry.action)] = entry
	if cfg.has_section("keyboard"):
		for key in cfg.get_section_keys("keyboard"):
			var value: Variant = cfg.get_value("keyboard", key)
			if known.has(key) and value is Array:
				_keyboard[StringName(key)] = value
	if cfg.has_section("pad"):
		for key in cfg.get_section_keys("pad"):
			var value: Variant = cfg.get_value("pad", key)
			if known.has(key) and known[key].pad and value is Array:
				_pad[StringName(key)] = value
	return OK


# ======================================================================
# Events <-> bindings
# ======================================================================

## Binding dictionary for an input event, {} for events that cannot be bound.
static func binding_of(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		return {"type": "key", "code": int(code)} if code != KEY_NONE else {}
	if event is InputEventMouseButton:
		return {"type": "mouse", "button": int(event.button_index)}
	if event is InputEventJoypadButton:
		return {"type": "joy_button", "index": int(event.button_index)}
	if event is InputEventJoypadMotion:
		return {"type": "joy_axis", "axis": int(event.axis), "sign": 1 if event.axis_value >= 0.0 else -1}
	return {}


## Input event for a binding (device -1 = any device).
static func event_of(binding: Dictionary, device: int = -1) -> InputEvent:
	match binding.get("type", ""):
		"key":
			var key := InputEventKey.new()
			key.physical_keycode = int(binding.code) as Key
			return key
		"mouse":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = int(binding.button) as MouseButton
			return mouse
		"joy_button":
			var button := InputEventJoypadButton.new()
			button.device = device
			button.button_index = int(binding.index) as JoyButton
			return button
		"joy_axis":
			var motion := InputEventJoypadMotion.new()
			motion.device = device
			motion.axis = int(binding.axis) as JoyAxis
			motion.axis_value = 1.0 if int(binding.sign) > 0 else -1.0
			return motion
	return null


static func is_pad_binding(binding: Dictionary) -> bool:
	return binding.get("type", "") in ["joy_button", "joy_axis"]


# ======================================================================
# Internals
# ======================================================================

## Puts every action's keyboard / mouse events back to the project's, then the rebound ones on top.
static func _apply_keyboard() -> void:
	for entry in ACTIONS:
		var action: StringName = entry.action
		if not InputMap.has_action(action):
			continue
		for e in InputMap.action_get_events(action):
			if _is_keyboard_event(e):
				InputMap.action_erase_event(action, e)
		if _keyboard.has(action):
			for b in _keyboard[action]:
				var e := event_of(b)
				if e:
					InputMap.action_add_event(action, e)
		else:
			for e in _project_keys.get(action, []):
				InputMap.action_add_event(action, e)


static func _is_keyboard_event(e: InputEvent) -> bool:
	return e is InputEventKey or e is InputEventMouseButton


static func _same(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty() or a.get("type") != b.get("type"):
		return false
	for k in a:
		if k != "type" and int(a[k]) != int(b.get(k, -999)):
			return false
	return true


## `list` with `binding` taken out: replaced by the first of `replacement` when it was the only one,
## dropped when there are others. null when `binding` is not in it.
static func _swap_out(list: Array, binding: Dictionary, replacement: Array) -> Variant:
	var i := _index_of(list, binding)
	if i < 0:
		return null
	var out := list.duplicate()
	if out.size() > 1 or replacement.is_empty():
		out.remove_at(i)
	else:
		out[i] = replacement[0]
	return out


static func _index_of(list: Array, binding: Dictionary) -> int:
	for i in list.size():
		if _same(list[i], binding):
			return i
	return -1
