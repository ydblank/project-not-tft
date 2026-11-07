extends CanvasLayer
class_name PauseMenu

# Esc opens the pause menu: Resume / Difficulty / Settings / Dev Tools / Exit.
#   Settings   player options only: sound, display (window mode, camera shake, death slow-motion,
#              damage numbers) and controls (controller on / off, and Key bindings: rebind every
#              action on keyboard / mouse and controller, see Keybinds). See PLAYER_SECTIONS.
#   Dev Tools  the test / mode buttons (AI Bots, Teams, Parry Training, Host / Join, ...) in a grid,
#              and every other DevSettings value as a slider or checkbox.
# Changes apply live, and are saved to disk (Save button, and automatically on Resume).
# The test buttons are built by the level tools (group "game_option"); a button with the meta
# "settings_section" is a player setting and goes into that Settings section instead.

## What the Settings panel shows: DevSettings keys per section. The section's player buttons
## (meta "settings_section", e.g. the window mode and controller toggles) are added under its title.
## Everything else in DevSettings is a dev setting and lives in Dev Tools.
const PLAYER_SECTIONS := [
	{"title": "Audio", "keys": ["sfx_volume", "music_volume"]},
	{"title": "Display", "keys": ["shake_mult", "death_slowmo", "damage_numbers"]},
	{"title": "Controls", "keys": []},
]
const TOOL_COLUMNS := 3
const DEV_SCROLL_SIZE := Vector2(640, 200)
const SETTINGS_WIDTH := 520.0
const COLOR_HEADER := Color(1.0, 0.85, 0.4)
## A press this soon after a binding was clicked is ignored (it is the click itself).
const CAPTURE_GRACE := 0.2
## How far a stick or trigger must move to count as the new binding.
const CAPTURE_AXIS := 0.6

@export var tuning: DevTuning

var _dim: ColorRect
var _main_panel: PanelContainer
var _settings_panel: PanelContainer
var _dev_panel: PanelContainer
var _keys_panel: PanelContainer
var _keys_button: Button
## Key-bindings screen: "action|keyboard" / "action|pad" -> the button showing that binding.
var _bind_buttons: Dictionary = {}
## The binding waiting for a press: its action and "keyboard" or "pad" (empty = not waiting).
var _capture_action: StringName = &""
var _capture_mode: String = ""
var _capture_started: float = 0.0
var _resume_button: Button
var _difficulty_button: Button
var _settings_button: Button
var _dev_button: Button
## "Exit the game?" panel with Confirm / Cancel.
var _confirm_panel: PanelContainer
var _cancel_button: Button
var _statuses: Dictionary = {} # panel -> Label
var _rows: Dictionary = {} # key -> {"control": Control, "value": Label}
var _panel_keys: Dictionary = {} # panel -> Array of DevSettings keys shown in it
## The grid of test buttons in Dev Tools, and the Settings sections' button holders (title -> box).
var _tool_grid: GridContainer
var _section_boxes: Dictionary = {}
var _dirty: bool = false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	DevSettings.ensure_loaded()
	if tuning == null and get_parent():
		tuning = get_parent().get_node_or_null("DevTuning") as DevTuning
	_build()
	_update_difficulty_text()
	visible = false
	_collect_options.call_deferred() # after every level tool has built its button


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		return
	get_viewport().set_input_as_handled()
	if not visible:
		open()
	elif _keys_panel.visible:
		_show_settings() # back to Settings
	elif not _main_panel.visible:
		_show_main() # Esc / B = cancel or back
	else:
		resume()


func open() -> void:
	Sfx.play(&"ui_open", 0.0, 1.0, 0.0, 0.0)
	get_tree().paused = true
	visible = true
	_set_option_focus(true)
	_show_main()


func resume() -> void:
	Sfx.play(&"ui_close", 0.0, 1.0, 0.0, 0.0)
	_save_if_dirty()
	visible = false
	_set_option_focus(false)
	get_tree().paused = false


## The test buttons can be reached with the D-pad while the menu is open; in play they must not take
## focus, or a key like Space would press the last one.
func _set_option_focus(enabled: bool) -> void:
	for node in get_tree().get_nodes_in_group("game_option"):
		var control := node as Control
		if control:
			control.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	if not enabled:
		get_viewport().gui_release_focus()


func _ask_exit() -> void:
	_show_only(_confirm_panel)
	_cancel_button.grab_focus() # the safe answer is pre-selected, so a stray A press does not quit


func _exit_game() -> void:
	_save_if_dirty()
	get_tree().paused = false
	get_tree().quit()


func _show_main() -> void:
	var came_from := _visible_panel()
	_show_only(_main_panel)
	_update_difficulty_text()
	# Back from a sub-menu: keep the cursor on the button that opened it.
	if came_from == _settings_panel:
		_settings_button.grab_focus()
	elif came_from == _dev_panel:
		_dev_button.grab_focus()
	else:
		_resume_button.grab_focus()


func _show_settings() -> void:
	var came_from := _visible_panel()
	_show_only(_settings_panel)
	if came_from == _keys_panel:
		_keys_button.grab_focus()
	else:
		_focus_first(_settings_panel)


func _show_keys() -> void:
	_show_only(_keys_panel)
	_refresh_bind_buttons()
	_focus_first(_keys_panel)


func _show_dev_tools() -> void:
	_show_only(_dev_panel)
	_focus_first(_dev_panel)


func _show_only(panel: PanelContainer) -> void:
	_cancel_capture()
	for p in [_main_panel, _settings_panel, _dev_panel, _keys_panel, _confirm_panel]:
		p.visible = p == panel
	if _statuses.has(panel):
		_statuses[panel].text = ""


func _visible_panel() -> PanelContainer:
	for p in [_settings_panel, _dev_panel, _keys_panel, _confirm_panel]:
		if p.visible:
			return p
	return _main_panel


## First control in the panel, top to bottom, that can take focus (for the controller).
func _focus_first(panel: Control) -> void:
	var first := _first_focusable(panel)
	if first:
		first.grab_focus()


func _first_focusable(node: Node) -> Control:
	for child in node.get_children():
		var control := child as Control
		if control and control.is_visible_in_tree() and control.focus_mode == Control.FOCUS_ALL \
				and (control is BaseButton or control is Slider or control is LineEdit):
			return control
		var inner := _first_focusable(child)
		if inner:
			return inner
	return null


## Easy -> Normal -> Hard -> Easy. Saved with the other settings; the Dev Tools slider follows.
func _cycle_difficulty() -> void:
	var next := (int(DevSettings.get_value("difficulty")) + 1) % Difficulty.NAMES.size()
	_changed("difficulty", next)
	if _rows.has("difficulty"):
		(_rows["difficulty"].control as HSlider).set_value_no_signal(float(next))
		_rows["difficulty"].value.text = str(next)
	_save_now()
	_update_difficulty_text()
	Sfx.play(&"ui_open", -6.0, 1.0, 0.0, 0.0)


func _update_difficulty_text() -> void:
	if _difficulty_button:
		_difficulty_button.text = "Difficulty: " + Difficulty.name_of(int(DevSettings.get_value("difficulty")))


## Moves the level tools' buttons (group "game_option") into the menu: player settings (meta
## "settings_section") into that Settings section, everything else into the Dev Tools grid. They keep
## their scripts and signals; only their place on screen changes, and they are only seen while paused.
func _collect_options() -> void:
	for node in get_tree().get_nodes_in_group("game_option"):
		var control := node as Control # buttons, and the Host / Join address field
		if control == null:
			continue
		var section: String = control.get_meta(&"settings_section", "")
		var target: Control = _section_boxes.get(section, _tool_grid)
		if control.get_parent() == target:
			continue
		control.get_parent().remove_child(control)
		control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control.custom_minimum_size = Vector2(0, 32)
		target.add_child(control)
	_set_option_focus(visible)


# ======================================================================
# Building the UI
# ======================================================================

func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.6)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	# ---- main menu ----
	_main_panel = _make_panel()
	var main_box := _padded_vbox(_main_panel, 12)
	_title("Paused", main_box, 26)
	_resume_button = _button("Resume", resume, main_box)
	_difficulty_button = _button("Difficulty", _cycle_difficulty, main_box)
	_settings_button = _button("Settings", _show_settings, main_box)
	_dev_button = _button("Dev Tools", _show_dev_tools, main_box)
	_button("Exit", _ask_exit, main_box)

	# ---- exit confirmation ----
	_confirm_panel = _make_panel()
	var confirm_box := _padded_vbox(_confirm_panel, 14)
	_title("Exit the game?", confirm_box, 24)
	_button("Confirm", _exit_game, confirm_box)
	_cancel_button = _button("Cancel", _show_main, confirm_box)

	_build_settings()
	_build_dev_tools()
	_build_keys()


## Player settings: a short list in sections, no scrolling.
func _build_settings() -> void:
	_settings_panel = _make_panel()
	var box := _padded_vbox(_settings_panel, 8)
	_title("Settings", box, 22)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(SETTINGS_WIDTH, 0)
	list.add_theme_constant_override("separation", 6)
	box.add_child(list)
	var keys: Array = []
	for section in PLAYER_SECTIONS:
		_header(section.title, list)
		var buttons := VBoxContainer.new() # the level tools' player buttons land here (_collect_options)
		buttons.add_theme_constant_override("separation", 6)
		list.add_child(buttons)
		_section_boxes[section.title] = buttons
		if section.title == "Controls":
			_keys_button = _button("Key bindings", _show_keys, buttons)
		for key in section.keys:
			var def := DevSettings.def_for(key)
			if not def.is_empty():
				list.add_child(_build_row(def))
				keys.append(key)
	_panel_keys[_settings_panel] = keys
	_add_footer(_settings_panel, box)


## Dev tools: the test buttons in a grid, then every dev setting (scrolling).
func _build_dev_tools() -> void:
	_dev_panel = _make_panel()
	var box := _padded_vbox(_dev_panel, 8)
	_title("Dev Tools", box, 22)
	_header("Test and match options", box)
	_tool_grid = GridContainer.new()
	_tool_grid.columns = TOOL_COLUMNS
	_tool_grid.add_theme_constant_override("h_separation", 8)
	_tool_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(_tool_grid)
	_header("Tuning (F5 shows a tile ruler for the skill ranges)", box)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = DEV_SCROLL_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	var player_keys := {}
	for section in PLAYER_SECTIONS:
		for key in section.keys:
			player_keys[key] = true
	var keys: Array = []
	var current_group := ""
	for def in DevSettings.DEFS:
		if player_keys.has(def.key):
			continue
		if def.group != current_group:
			current_group = def.group
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(0, 4)
			list.add_child(spacer)
			_header(current_group, list, 15)
		list.add_child(_build_row(def))
		keys.append(def.key)
	_panel_keys[_dev_panel] = keys
	_add_footer(_dev_panel, box)


## Status line and Save / Reset to defaults / Back.
func _add_footer(panel: PanelContainer, box: VBoxContainer) -> void:
	var status := Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	box.add_child(status)
	_statuses[panel] = status
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	_button("Save", _save_now, buttons)
	_button("Reset to defaults", func(): _reset_defaults(panel), buttons)
	_button("Back", _show_main, buttons)


func _build_row(def: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var label := Label.new()
	label.text = def.label
	label.custom_minimum_size = Vector2(250, 0)
	row.add_child(label)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(60, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var control: Control
	if def.type == "bool":
		var check := CheckBox.new()
		check.button_pressed = DevSettings.get_value(def.key)
		check.toggled.connect(func(on: bool): _changed(def.key, on))
		control = check
		value_label.text = ""
	else:
		var slider := HSlider.new()
		slider.min_value = def.min
		slider.max_value = def.max
		slider.step = def.step
		slider.value = DevSettings.get_value(def.key)
		slider.custom_minimum_size = Vector2(190, 0)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value_changed.connect(func(x: float): _changed(def.key, x))
		control = slider
		value_label.text = _format(def, slider.value)
	row.add_child(control)
	row.add_child(value_label)
	_rows[def.key] = {"control": control, "value": value_label}
	return row


func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.visible = false
	add_child(panel)
	return panel


func _title(text: String, parent: Control, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)


func _header(text: String, parent: Control, font_size: int = 17) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", COLOR_HEADER)
	parent.add_child(label)


func _padded_vbox(panel: PanelContainer, separation: int) -> VBoxContainer:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	margin.add_child(box)
	return box


func _button(text: String, callback: Callable, parent: Control) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(170, 34)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


# ======================================================================
# Key bindings (Settings -> Controls -> Key bindings)
# ======================================================================

## Action | Keyboard / mouse | Controller. Click a binding, then press the new key or button.
func _build_keys() -> void:
	_keys_panel = _make_panel()
	var box := _padded_vbox(_keys_panel, 8)
	_title("Key bindings", box, 22)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for heading in ["Action", "Keyboard / mouse", "Controller"]:
		var label := Label.new()
		label.text = heading
		label.add_theme_color_override("font_color", COLOR_HEADER)
		grid.add_child(label)
	for entry in Keybinds.ACTIONS:
		var name_label := Label.new()
		name_label.text = entry.label
		name_label.custom_minimum_size = Vector2(130, 0)
		grid.add_child(name_label)
		var key_button := _button("", _start_capture.bind(entry.action, "keyboard"), grid)
		key_button.custom_minimum_size = Vector2(190, 30)
		_bind_buttons["%s|keyboard" % entry.action] = key_button
		if entry.pad:
			var pad_button := _button("", _start_capture.bind(entry.action, "pad"), grid)
			pad_button.custom_minimum_size = Vector2(190, 30)
			_bind_buttons["%s|pad" % entry.action] = pad_button
		else:
			var stick := Label.new()
			stick.text = "Left stick / D-pad"
			stick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stick.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
			grid.add_child(stick)
	var note := Label.new()
	note.text = "Click a binding, then press the new key or button (Esc cancels). A key another action uses is swapped."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(530, 0)
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	box.add_child(note)
	var status := Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	box.add_child(status)
	_statuses[_keys_panel] = status
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	_button("Reset to defaults", _reset_keybinds, buttons)
	_button("Back", _show_settings, buttons)


func _refresh_bind_buttons() -> void:
	for entry in Keybinds.ACTIONS:
		var key_button: Button = _bind_buttons.get("%s|keyboard" % entry.action)
		if key_button:
			key_button.text = Keybinds.describe_keyboard(entry.action)
		var pad_button: Button = _bind_buttons.get("%s|pad" % entry.action)
		if pad_button:
			pad_button.text = Keybinds.describe_pad(entry.action)


func _start_capture(action: StringName, mode: String) -> void:
	_cancel_capture()
	_capture_action = action
	_capture_mode = mode
	_capture_started = Time.get_ticks_msec() / 1000.0
	Keybinds.capturing = true
	var button: Button = _bind_buttons["%s|%s" % [action, mode]]
	button.text = "Press a key..." if mode == "keyboard" else "Press a button..."
	_statuses[_keys_panel].text = ""


func _cancel_capture() -> void:
	if _capture_action == &"":
		return
	_capture_action = &""
	_capture_mode = ""
	_release_capture_flag()
	_refresh_bind_buttons()


## Keeps GamepadControls away from B / Start until the press that ended the capture is over.
func _release_capture_flag() -> void:
	get_tree().create_timer(0.15, true).timeout.connect(func(): Keybinds.capturing = _capture_action != &"")


## While a binding waits for a press, the next key / mouse button (keyboard column) or controller
## button / stick / trigger (controller column) becomes the binding. Esc (or Start) cancels.
func _input(event: InputEvent) -> void:
	if _capture_action == &"" or not event.is_pressed() or event.is_echo():
		return
	var cancel: bool = (event is InputEventKey and event.keycode == KEY_ESCAPE) \
			or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START)
	if cancel:
		get_viewport().set_input_as_handled()
		_cancel_capture()
		return
	if Time.get_ticks_msec() / 1000.0 - _capture_started < CAPTURE_GRACE:
		get_viewport().set_input_as_handled() # the click / A press that opened the capture
		return
	var binding := {}
	if _capture_mode == "keyboard" and (event is InputEventKey or event is InputEventMouseButton):
		binding = Keybinds.binding_of(event)
	elif _capture_mode == "pad":
		if event is InputEventJoypadButton and not Keybinds.PAD_RESERVED.has(event.button_index):
			binding = Keybinds.binding_of(event)
		elif event is InputEventJoypadMotion and absf(event.axis_value) >= CAPTURE_AXIS:
			binding = Keybinds.binding_of(event)
	if event is InputEventMouseMotion or (event is InputEventJoypadMotion and binding.is_empty()):
		return # resting sticks and mouse moves are not presses
	get_viewport().set_input_as_handled()
	if binding.is_empty():
		_statuses[_keys_panel].text = "That cannot be bound here"
		return
	var action := _capture_action
	if _capture_mode == "keyboard":
		Keybinds.set_keyboard(action, binding)
	else:
		Keybinds.set_pad(action, binding)
	_capture_action = &""
	_capture_mode = ""
	_release_capture_flag()
	_apply_keybinds()
	_statuses[_keys_panel].text = "%s: %s" % [_label_of(action), Keybinds.describe(binding)]


func _reset_keybinds() -> void:
	_cancel_capture()
	Keybinds.reset_all()
	_apply_keybinds()
	_statuses[_keys_panel].text = "Key bindings reset"


## Saves the bindings and passes them on: the controller bindings and the on-screen key labels.
func _apply_keybinds() -> void:
	Keybinds.save()
	var pad := get_parent().get_node_or_null("GamepadControls") as GamepadControls if get_parent() else null
	if pad:
		pad.refresh_bindings()
	get_tree().call_group(&"keybind_listeners", &"on_keybinds_changed")
	_refresh_bind_buttons()


func _label_of(action: StringName) -> String:
	for entry in Keybinds.ACTIONS:
		if entry.action == action:
			return entry.label
	return String(action)


# ======================================================================
# Editing / saving
# ======================================================================

func _changed(key: String, value: Variant) -> void:
	DevSettings.set_value(key, value)
	_dirty = true
	_set_status("")
	var def := DevSettings.def_for(key)
	if def.type != "bool" and _rows.has(key):
		_rows[key].value.text = _format(def, float(value))
	if tuning:
		tuning.apply_all()


## Resets only the settings shown in `panel` (Settings does not touch the dev values, and back).
func _reset_defaults(panel: PanelContainer) -> void:
	for key in _panel_keys.get(panel, []):
		DevSettings.set_value(key, DevSettings.default_of(key))
		var def := DevSettings.def_for(key)
		var control: Control = _rows[key].control
		var value: Variant = DevSettings.get_value(key)
		if control is CheckBox:
			(control as CheckBox).set_pressed_no_signal(value)
		else:
			(control as HSlider).set_value_no_signal(float(value))
			_rows[key].value.text = _format(def, float(value))
	_dirty = true
	if tuning:
		tuning.apply_all()
	_update_difficulty_text()
	_set_status("Defaults restored (press Save to keep them)")


func _save_now() -> void:
	var err := DevSettings.save()
	_dirty = false
	_set_status("Saved" if err == OK else "Could not save (error %d)" % err)


func _save_if_dirty() -> void:
	if _dirty:
		DevSettings.save()
		_dirty = false


func _set_status(text: String) -> void:
	for panel in _statuses:
		_statuses[panel].text = text


func _format(def: Dictionary, value: float) -> String:
	if def.type == "int":
		return str(int(value))
	var step: float = def.step
	if step >= 1.0:
		return str(int(value))
	return String.num(value, 2 if step < 0.1 else 1)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.97)
	style.border_color = Color(1, 1, 1, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style
