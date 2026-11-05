extends CanvasLayer

# On-screen controls reference. Key names are read from the InputMap at runtime
# so the panel always matches the project's real bindings. F1 toggles it.

const TOGGLE_KEY := KEY_F1

@onready var panel: PanelContainer = $Panel
@onready var grid: GridContainer = $Panel/Margin/VBox/Grid


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_rows()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == TOGGLE_KEY:
		panel.visible = not panel.visible
		get_viewport().set_input_as_handled()


func _build_rows() -> void:
	for child in grid.get_children():
		child.queue_free()

	var move_keys := "%s %s %s %s" % [_keys("W"), _keys("A"), _keys("S"), _keys("D")]
	_add_row(move_keys, "Move")
	_add_row(_keys("Attack") + " (tap)", "Light attack / combo")
	_add_row(_keys("Attack") + " (hold)", "Charge, release for one heavy hit")
	_add_row(_keys("Block") + " (hold)", "Shield - aim with mouse, covers 3 directions,\nslows you, no attack or dash")
	_add_row(_keys("dash"), "Dash")
	_add_row(OS.get_keycode_string(TOGGLE_KEY), "Show / hide controls")


func _add_row(keys: String, action: String) -> void:
	var key_label := Label.new()
	key_label.text = keys
	key_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	grid.add_child(key_label)

	var action_label := Label.new()
	action_label.text = action
	grid.add_child(action_label)


func _keys(action: String) -> String:
	if not InputMap.has_action(action):
		return "?"
	var names: PackedStringArray = []
	for event in InputMap.action_get_events(action):
		var key_name := _event_name(event)
		if key_name != "" and not names.has(key_name):
			names.append(key_name)
	return " / ".join(names) if not names.is_empty() else "?"


func _event_name(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				return "LMB"
			MOUSE_BUTTON_RIGHT:
				return "RMB"
			MOUSE_BUTTON_MIDDLE:
				return "MMB"
		return "Mouse %d" % event.button_index
	if event is InputEventKey:
		var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		if code == KEY_NONE:
			return ""
		return OS.get_keycode_string(code)
	return event.as_text()
