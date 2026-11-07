extends Node
class_name DisplayToggle

# Windowed / fullscreen. F11 (or the "Display" button at the top of the screen, visible while paused)
# switches. The game starts as a maximised window (see [display] in project.godot) and scales up to the
# window: it is drawn at a fixed 1152 x 648 layout and stretched, so a bigger window or screen makes
# everything bigger instead of showing more of the arena.

var _button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # F11 must work while paused too
	_build_button()
	get_window().size_changed.connect(_update_button) # also fires when the mode changes (maximise, fullscreen)
	_update_button()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		get_viewport().set_input_as_handled()
		toggle()


func is_fullscreen() -> bool:
	var mode := get_window().mode
	return mode == Window.MODE_FULLSCREEN or mode == Window.MODE_EXCLUSIVE_FULLSCREEN


## Fullscreen <-> maximised window.
func toggle() -> void:
	get_window().mode = Window.MODE_MAXIMIZED if is_fullscreen() else Window.MODE_FULLSCREEN
	_update_button()


func _build_button() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	_button = Button.new()
	_button.focus_mode = Control.FOCUS_NONE
	_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_button.offset_left = 0.0
	_button.offset_right = 0.0
	_button.offset_top = 172.0
	_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_button.tooltip_text = "Switch between a window and fullscreen (F11)"
	_button.pressed.connect(toggle)
	layer.add_child(_button)
	_button.add_to_group("game_option")
	_button.set_meta(&"settings_section", "Display") # a player setting: the pause menu shows it under Settings, not Dev Tools


func _update_button() -> void:
	if _button:
		_button.text = "Display: Fullscreen (F11)" if is_fullscreen() else "Display: Windowed (F11)"
