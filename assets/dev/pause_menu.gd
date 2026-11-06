extends CanvasLayer
class_name PauseMenu

# Esc opens the pause menu: Resume / Settings / Exit.
# Settings is a dev panel of game-feel variables (see DevSettings). Changes
# apply live, and are saved to disk (Save button, and automatically on Resume).

## Bump this whenever a change is made, so the number in the pause menu shows which build is running.
const CHANGE_NUMBER := 63

@export var tuning: DevTuning

var _dim: ColorRect
var _main_panel: PanelContainer
var _settings_panel: PanelContainer
## Holds the test / mode buttons (AI Bots, Teams, ...) at their usual spots, shown only while paused.
var _option_layer: CanvasLayer
var _resume_button: Button
var _difficulty_button: Button
## "Exit the game?" panel with Confirm / Cancel.
var _confirm_panel: PanelContainer
var _cancel_button: Button
## Controller button hints ("A Confirm  B Back"), one per panel; shown only while a controller is in use.
var _hints: Dictionary = {} # panel -> Label
var _status: Label
var _rows: Dictionary = {} # key -> {"control": Control, "value": Label}
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
	elif _settings_panel.visible or _confirm_panel.visible:
		_show_main() # Esc / B = cancel or back
	else:
		resume()


func open() -> void:
	Sfx.play(&"ui_open", 0.0, 1.0, 0.0, 0.0)
	get_tree().paused = true
	visible = true
	_option_layer.visible = true
	_set_option_focus(true)
	_show_main()


func resume() -> void:
	Sfx.play(&"ui_close", 0.0, 1.0, 0.0, 0.0)
	_save_if_dirty()
	visible = false
	_option_layer.visible = false
	_set_option_focus(false)
	get_tree().paused = false


## The paused top buttons can be reached with the D-pad while the menu is open; in play they must not take
## focus, or a key like Space would press the last one.
func _set_option_focus(enabled: bool) -> void:
	for node in get_tree().get_nodes_in_group("game_option"):
		var control := node as Control
		if control:
			control.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	if not enabled:
		get_viewport().gui_release_focus()


func _ask_exit() -> void:
	_main_panel.visible = false
	_settings_panel.visible = false
	_confirm_panel.visible = true
	_cancel_button.grab_focus() # the safe answer is pre-selected, so a stray A press does not quit
	_update_hints()


func _exit_game() -> void:
	_save_if_dirty()
	get_tree().paused = false
	get_tree().quit()


func _show_main() -> void:
	_main_panel.visible = true
	_settings_panel.visible = false
	_confirm_panel.visible = false
	_update_difficulty_text()
	_resume_button.grab_focus()
	_update_hints()


func _show_settings() -> void:
	_main_panel.visible = false
	_settings_panel.visible = true
	_confirm_panel.visible = false
	_status.text = ""
	_update_hints()


## Easy -> Normal -> Hard -> Easy. Saved with the other settings; the Settings slider follows.
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


## "A Confirm   B Back" under the menu, only while a controller is switched on.
func _update_hints() -> void:
	for panel in _hints:
		var label: Label = _hints[panel]
		label.visible = GamepadControls.active
		if panel == _confirm_panel:
			label.text = "A  Confirm      B  Cancel"
		elif panel == _settings_panel:
			label.text = "A  Confirm      B  Back"
		else:
			label.text = "A  Confirm      B  Resume"


## Moves the game's test / mode buttons (AI Bots, Teams, Parry Training, Host / Join, ...) onto a layer above the pause
## dim. They keep their anchors and offsets, so they sit exactly where they always did; the layer is only
## shown while paused, so they are gone from the combat screen. Every such button joins the "game_option"
## group when its script builds it.
func _collect_options() -> void:
	for node in get_tree().get_nodes_in_group("game_option"):
		var control := node as Control # buttons, and the Host / Join address field
		if control and control.get_parent() != _option_layer:
			control.get_parent().remove_child(control)
			_option_layer.add_child(control)


# ======================================================================
# Building the UI
# ======================================================================

func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.6)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	_option_layer = CanvasLayer.new()
	_option_layer.layer = 21 # above the dim and the menu panels
	_option_layer.visible = false
	add_child(_option_layer)

	# ---- main menu ----
	_main_panel = PanelContainer.new()
	_main_panel.add_theme_stylebox_override("panel", _panel_style())
	_main_panel.set_anchors_preset(Control.PRESET_CENTER)
	_main_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_main_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_place_below_buttons(_main_panel)
	add_child(_main_panel)
	var main_box := _padded_vbox(_main_panel, 14)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	main_box.add_child(title)
	_resume_button = _button("Resume", resume, main_box)
	_difficulty_button = _button("Difficulty", _cycle_difficulty, main_box)
	_button("Settings", _show_settings, main_box)
	_button("Exit", _ask_exit, main_box)
	_add_hint(_main_panel, main_box)
	var change_label := Label.new()
	change_label.text = "change #%d" % CHANGE_NUMBER
	change_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	change_label.add_theme_font_size_override("font_size", 16)
	change_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	main_box.add_child(change_label)

	# ---- exit confirmation ----
	_confirm_panel = PanelContainer.new()
	_confirm_panel.add_theme_stylebox_override("panel", _panel_style())
	_confirm_panel.set_anchors_preset(Control.PRESET_CENTER)
	_confirm_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_confirm_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_place_below_buttons(_confirm_panel)
	add_child(_confirm_panel)
	var confirm_box := _padded_vbox(_confirm_panel, 14)
	var confirm_title := Label.new()
	confirm_title.text = "Exit the game?"
	confirm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_title.add_theme_font_size_override("font_size", 24)
	confirm_box.add_child(confirm_title)
	_button("Confirm", _exit_game, confirm_box)
	_cancel_button = _button("Cancel", _show_main, confirm_box)
	_add_hint(_confirm_panel, confirm_box)

	# ---- settings ----
	_settings_panel = PanelContainer.new()
	_settings_panel.add_theme_stylebox_override("panel", _panel_style())
	_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	_settings_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_settings_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_settings_panel)
	var box := _padded_vbox(_settings_panel, 10)
	var settings_title := Label.new()
	settings_title.text = "Dev settings"
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_title.add_theme_font_size_override("font_size", 22)
	box.add_child(settings_title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	_build_rows(list)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	box.add_child(_status)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	_button("Save", _save_now, buttons)
	_button("Reset to defaults", _reset_defaults, buttons)
	_button("Back", _show_main, buttons)
	_add_hint(_settings_panel, box)


func _build_rows(list: VBoxContainer) -> void:
	var current_group := ""
	for def in DevSettings.DEFS:
		if def.group != current_group:
			current_group = def.group
			var header := Label.new()
			header.text = current_group
			header.add_theme_font_size_override("font_size", 17)
			header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(0, 6)
			list.add_child(spacer)
			list.add_child(header)
		list.add_child(_build_row(def))


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


## Sits a panel a little below the screen's centre, so it clears the paused buttons stacked at the top.
func _place_below_buttons(panel: PanelContainer) -> void:
	panel.anchor_top = 0.62
	panel.anchor_bottom = 0.62


## Adds the (initially hidden) controller hint line at the bottom of a panel.
func _add_hint(panel: PanelContainer, box: VBoxContainer) -> void:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.65, 0.78, 0.95))
	label.visible = false
	box.add_child(label)
	_hints[panel] = label


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
	b.custom_minimum_size = Vector2(150, 34)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


# ======================================================================
# Editing / saving
# ======================================================================

func _changed(key: String, value: Variant) -> void:
	DevSettings.set_value(key, value)
	_dirty = true
	_status.text = ""
	var def := DevSettings.def_for(key)
	if def.type != "bool":
		_rows[key].value.text = _format(def, float(value))
	if tuning:
		tuning.apply_all()


func _reset_defaults() -> void:
	DevSettings.reset_all()
	for key in _rows:
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
	_status.text = "Defaults restored (press Save to keep them)"


func _save_now() -> void:
	var err := DevSettings.save()
	_dirty = false
	_status.text = "Saved" if err == OK else "Could not save (error %d)" % err


func _save_if_dirty() -> void:
	if _dirty:
		DevSettings.save()
		_dirty = false


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
