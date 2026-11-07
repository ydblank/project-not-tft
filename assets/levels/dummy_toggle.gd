extends Node
class_name DummyToggle

# Test helper: hides the training dummy (no collision, can't be hit, no lunge
# stop) and adds a button at the top of the screen to bring it back.

@export var dummy_path: NodePath = NodePath("../Dummy")
@export var start_hidden: bool = true

var _dummy: CharacterBody2D
var _button: Button
var _shown: bool = true
var _saved_layer: int = 0
var _saved_mask: int = 0


func _ready() -> void:
	_dummy = get_node_or_null(dummy_path) as CharacterBody2D
	if _dummy == null:
		return
	_saved_layer = _dummy.collision_layer
	_saved_mask = _dummy.collision_mask
	_build_button()
	set_shown(not start_hidden)


func set_shown(value: bool) -> void:
	_shown = value
	if is_instance_valid(_dummy):
		_dummy.visible = value
		_dummy.collision_layer = _saved_layer if value else 0
		_dummy.collision_mask = _saved_mask if value else 0
		_dummy.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
		if value:
			_dummy.add_to_group("dummies")
		else:
			_dummy.remove_from_group("dummies")
		for child in _dummy.get_children():
			if child is HitboxComponent:
				child.can_be_hit = value
				child.set_deferred("monitorable", value)
				child.set_deferred("monitoring", value)
	_update_button()


func _build_button() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	_button = Button.new()
	_button.toggle_mode = true
	# Never take keyboard focus: Space (dash) would otherwise press the button.
	_button.focus_mode = Control.FOCUS_NONE
	_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	# Zero-width box so the button is only as big as its text; it grows leftwards from just left of the Respawn button.
	_button.offset_left = -70.0
	_button.offset_right = -70.0
	_button.offset_top = 8.0
	_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_button.toggled.connect(set_shown)
	layer.add_child(_button)
	_button.add_to_group("game_option") # the pause menu shows it in Dev Tools


func _update_button() -> void:
	if _button == null:
		return
	_button.set_pressed_no_signal(_shown)
	_button.text = "Dummy: %s" % ("SHOWN" if _shown else "HIDDEN")
