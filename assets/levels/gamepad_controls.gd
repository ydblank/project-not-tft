extends Node
class_name GamepadControls

# Xbox-style controller support for Player 1 (1-player mode). It is ON by default and works at the same
# time as the keyboard and mouse: it adds gamepad bindings to the game's existing input actions, so
# project.godot stays untouched. The "Controller" button at the top of the screen (visible while paused)
# turns it off for keyboard and mouse only. The choice lasts for the session; `enabled` on the node sets
# the starting state.
#
#   Left stick / D-pad   move              Right stick   aim (the mouse takes over again when it moves)
#   RT or X              attack            LB (L1)       block            (defaults: rebindable in
#   LT (L2), A or RB     dash              B             skill             Settings -> Controls, see Keybinds)
#   Y                    switch character (R)
#   Start                pause (Esc); B also backs out of the pause menu
#
# Only controllers Godot recognises (SDL has a mapping for them: an Xbox 360 / XInput pad, and so a
# GPD Win 4's built-in pad) are used. An unrecognised device sends raw numbers with no known layout, which
# can look like a stuck stick, so it is ignored. Bindings follow plugging a controller in or out.

## Names of the aim actions this node creates (PlayerController reads them).
const AIM_LEFT := &"aim_left"
const AIM_RIGHT := &"aim_right"
const AIM_UP := &"aim_up"
const AIM_DOWN := &"aim_down"
## Stick dead zone for the aim stick.
const AIM_DEADZONE := 0.3
## A trigger counts as pressed past this much of a pull.
const TRIGGER_DEADZONE := 0.5
## The project's own dead zone for the action buttons.
const BUTTON_DEADZONE := 0.2

## Start with the controller on, working alongside the keyboard and mouse. False = keyboard and mouse only.
@export var enabled: bool = true

## True while controller support is on. PlayerController reads it so a controller does nothing when it is off.
static var active: bool = false

var _added: Array = [] # [action, event] pairs this node added, so they can be removed again
var _toggle_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Start and B must work while the pause menu is open
	Keybinds.ensure_loaded()
	for action in [AIM_LEFT, AIM_RIGHT, AIM_UP, AIM_DOWN]:
		if not InputMap.has_action(action):
			InputMap.add_action(action, AIM_DEADZONE)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_build_button()
	set_enabled(enabled)


func _exit_tree() -> void:
	_clear()
	active = false


## Turns controller support on or off (the "Controller" button calls this).
func set_enabled(value: bool) -> void:
	enabled = value
	active = value
	_rebuild()
	_update_button()


func _input(event: InputEvent) -> void:
	if not enabled or not event is InputEventJoypadButton or not event.pressed or not Input.is_joy_known(event.device):
		return
	if Keybinds.capturing:
		return # the key-bindings screen is waiting for this button: it is a binding, not "back" or "pause"
	match event.button_index:
		JOY_BUTTON_START:
			_tap_key(KEY_ESCAPE)
		JOY_BUTTON_B:
			if get_tree().paused:
				_tap_key(KEY_ESCAPE) # back out of the pause menu
		JOY_BUTTON_Y:
			if not get_tree().paused:
				_tap_key(KEY_R)


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_rebuild()
	_update_button()


## Number of controllers Godot recognises (the ones that are used).
func _known_pads() -> int:
	var count := 0
	for device in Input.get_connected_joypads():
		if Input.is_joy_known(device):
			count += 1
	return count


func _build_button() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	_toggle_button = Button.new()
	_toggle_button.toggle_mode = true
	_toggle_button.focus_mode = Control.FOCUS_NONE
	_toggle_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toggle_button.offset_left = 0.0
	_toggle_button.offset_right = 0.0
	_toggle_button.offset_top = 140.0
	_toggle_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toggle_button.tooltip_text = "Use an Xbox-style controller as well as the keyboard and mouse"
	_toggle_button.toggled.connect(func(pressed: bool): set_enabled(pressed))
	layer.add_child(_toggle_button)
	_toggle_button.add_to_group("game_option")
	_toggle_button.set_meta(&"settings_section", "Controls") # a player setting: the pause menu shows it under Settings, not Dev Tools


func _update_button() -> void:
	if _toggle_button == null:
		return
	_toggle_button.set_pressed_no_signal(enabled)
	if not enabled:
		_toggle_button.text = "Controller: OFF"
	elif _known_pads() == 0:
		_toggle_button.text = "Controller: ON (none found)"
	else:
		_toggle_button.text = "Controller: ON"


## Adds the bindings for every recognised controller (replacing the old ones). With the controller off,
## it only removes them.
func _rebuild() -> void:
	_clear()
	if not enabled:
		for action in Keybinds.pad_actions():
			if InputMap.has_action(action):
				InputMap.action_set_deadzone(action, BUTTON_DEADZONE) # the project's own value
		return
	for device in Input.get_connected_joypads():
		if not Input.is_joy_known(device):
			continue
		# Movement: left stick and D-pad.
		_axis(&"A", device, JOY_AXIS_LEFT_X, -1.0)
		_axis(&"D", device, JOY_AXIS_LEFT_X, 1.0)
		_axis(&"W", device, JOY_AXIS_LEFT_Y, -1.0)
		_axis(&"S", device, JOY_AXIS_LEFT_Y, 1.0)
		_button(&"A", device, JOY_BUTTON_DPAD_LEFT)
		_button(&"D", device, JOY_BUTTON_DPAD_RIGHT)
		_button(&"W", device, JOY_BUTTON_DPAD_UP)
		_button(&"S", device, JOY_BUTTON_DPAD_DOWN)
		# Aim: right stick.
		_axis(AIM_LEFT, device, JOY_AXIS_RIGHT_X, -1.0)
		_axis(AIM_RIGHT, device, JOY_AXIS_RIGHT_X, 1.0)
		_axis(AIM_UP, device, JOY_AXIS_RIGHT_Y, -1.0)
		_axis(AIM_DOWN, device, JOY_AXIS_RIGHT_Y, 1.0)
		# Actions: Keybinds holds them (the defaults, or what was rebound in Settings -> Controls).
		for action in Keybinds.pad_actions():
			for binding in Keybinds.pad_bindings(action):
				var event := Keybinds.event_of(binding, device)
				if event:
					_bind(action, event)
		# Menus: the D-pad and left stick already move the focus (Godot's ui_up / ui_down...), but A does not
		# confirm by default. (B backs out: see _input.)
		_button(&"ui_accept", device, JOY_BUTTON_A)
	# A trigger or stick bound to an action is only "pressed" when pushed well over (the default dead zone
	# is for movement sticks).
	for action in Keybinds.pad_actions():
		if InputMap.has_action(action):
			InputMap.action_set_deadzone(action, TRIGGER_DEADZONE if _has_axis(action) else BUTTON_DEADZONE)


## Re-adds the controller bindings (after a rebind in Settings -> Controls).
func refresh_bindings() -> void:
	_rebuild()


func _has_axis(action: StringName) -> bool:
	for binding in Keybinds.pad_bindings(action):
		if binding.get("type", "") == "joy_axis":
			return true
	return false


func _clear() -> void:
	for pair in _added:
		if InputMap.has_action(pair[0]):
			InputMap.action_erase_event(pair[0], pair[1])
	_added.clear()


func _axis(action: StringName, device: int, axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	_bind(action, event)


func _button(action: StringName, device: int, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	_bind(action, event)


func _bind(action: StringName, event: InputEvent) -> void:
	if InputMap.has_action(action):
		InputMap.action_add_event(action, event)
		_added.append([action, event])


## Sends a key press and release, so a controller button can trigger what a key does.
func _tap_key(keycode: Key) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = keycode
		key.physical_keycode = keycode
		key.pressed = pressed
		Input.parse_input_event(key)
