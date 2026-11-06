extends Node
class_name LocalCoop

# Local 2-player mode on one keyboard. A button at the top of the screen switches
# between "1P (mouse)" and "2P (local)".
#
# 2P keys (aim is set by the direction keys, diagonals included, no mouse):
#   Player 1 (blue team):  W A S D move,  F attack,  G block,  H dash,  R swap with the ally
#   Player 2 (the enemy knight):  arrow keys move,  N attack,  M block,  , (comma) dash,  . (period) swap enemy
# Player 2 takes over the enemy knight from the AI. If it dies and a new one
# respawns, Player 2 gets the new one. Switching back to 1P hands it to the AI again.

const P1_ACTIONS := {
	&"p1_attack": KEY_F, &"p1_block": KEY_G, &"p1_dash": KEY_H,
}
const P2_ACTIONS := {
	&"p2_up": KEY_UP, &"p2_down": KEY_DOWN, &"p2_left": KEY_LEFT, &"p2_right": KEY_RIGHT,
	&"p2_attack": KEY_N, &"p2_block": KEY_M, &"p2_dash": KEY_COMMA,
}
const P2_GROUP := "p2_controlled"
const P2_MARKER := "P2Marker"
const P2_CONTROLLER := "P2Controller"
const P2_COLOR := Color(1.0, 0.5, 0.15)

@export var start_in_two_player: bool = false

var two_player: bool = false
var _button: Button
var _hint_layer: CanvasLayer
var _p2_entity: CharacterBody2D


func _ready() -> void:
	_register_actions()
	_build_ui()
	var switcher := _switcher()
	if switcher:
		switcher.control_changed.connect(_on_p1_control_changed)
	call_deferred("set_two_player", start_in_two_player)


func _unhandled_input(event: InputEvent) -> void:
	if two_player and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_PERIOD:
		get_viewport().set_input_as_handled()
		switch_p2()


func _process(_delta: float) -> void:
	if not two_player:
		return
	# Player 2's fighter was removed (died for good): take the next enemy.
	if not is_instance_valid(_p2_entity) or _is_dead(_p2_entity):
		var next := _pick_p2_candidate()
		if next and next != _p2_entity:
			_release_p2()
			_take_p2(next)


func set_two_player(value: bool) -> void:
	two_player = value
	var switcher := _switcher()
	if switcher:
		switcher.set_hint_visible(not value) # the co-op key list shows the switch keys instead
	if value:
		_configure_p1(true)
		var enemy := _pick_p2_candidate()
		if enemy:
			_take_p2(enemy)
	else:
		_configure_p1(false)
		_release_p2()
	var controls := get_parent().get_node_or_null("ControlsHint") if get_parent() else null
	if controls is CanvasLayer:
		(controls as CanvasLayer).visible = not value # its labels show the 1P mouse controls
	_hint_layer.visible = value
	_update_button()


# ---------------------------------------------------------------- Player 1

func _configure_p1(coop: bool) -> void:
	# Every fighter on the blue team that has a player controller (R can swap between them).
	for group_name in ["players", "allies"]:
		for node in get_tree().get_nodes_in_group(group_name):
			var pc := _find_player_controller(node)
			if pc == null:
				continue
			if coop:
				pc.input_attack = &"p1_attack"
				pc.input_block = &"p1_block"
				pc.input_dash = &"p1_dash"
				pc.aim_with_mouse = false
			else:
				pc.input_attack = &"Attack"
				pc.input_block = &"Block"
				pc.input_dash = &"dash"
				pc.aim_with_mouse = true


## R swapped Player 1 to another fighter: that fighter needs the 2P key setup too.
func _on_p1_control_changed(_entity: Node2D) -> void:
	if two_player:
		_configure_p1(true)


# ---------------------------------------------------------------- Player 2

func _pick_p2_candidate() -> CharacterBody2D:
	var fallback: CharacterBody2D = null
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as CharacterBody2D
		if enemy == null or _is_dead(enemy) or BotToggle.is_benched(enemy):
			continue
		if enemy.name == "EnemyCharacter":
			return enemy # the melee knight
		if fallback == null:
			fallback = enemy
	return fallback


func _take_p2(entity: CharacterBody2D) -> void:
	if BotToggle.is_asleep(entity):
		BotToggle.wake(entity) # "AI Bots: OFF" - a human may still play the sleeping fighter
	var combat := CombatComponent.find_on(entity)
	if combat == null:
		return
	_p2_entity = entity
	for child in combat.get_parent().get_children():
		if child is AIComponent:
			child.intent.clear()
			child.process_mode = Node.PROCESS_MODE_DISABLED
	var pc := PlayerController.new()
	pc.name = P2_CONTROLLER
	pc.entity = entity
	pc.input_up = &"p2_up"
	pc.input_down = &"p2_down"
	pc.input_left = &"p2_left"
	pc.input_right = &"p2_right"
	pc.input_attack = &"p2_attack"
	pc.input_block = &"p2_block"
	pc.input_dash = &"p2_dash"
	pc.aim_with_mouse = false
	pc.lunge_target_groups = ["players", "allies"]
	pc.intent.aim_dir = Vector2.LEFT
	combat.get_parent().add_child(pc)
	combat.controller = pc
	entity.add_to_group(P2_GROUP)
	_add_marker(entity)


func _release_p2() -> void:
	if not is_instance_valid(_p2_entity):
		_p2_entity = null
		return
	var combat := CombatComponent.find_on(_p2_entity)
	if combat:
		var ai: AIComponent = null
		for child in combat.get_parent().get_children():
			if child is PlayerController and child.name == P2_CONTROLLER:
				child.queue_free()
			elif child is AIComponent:
				ai = child
		if ai:
			ai.intent.clear()
			ai.process_mode = Node.PROCESS_MODE_INHERIT
			combat.controller = ai
	_p2_entity.remove_from_group(P2_GROUP)
	var marker := _p2_entity.get_node_or_null(P2_MARKER)
	if marker:
		marker.queue_free()
	_p2_entity = null


func _add_marker(entity: Node2D) -> void:
	if entity.has_node(P2_MARKER):
		return
	var marker := Polygon2D.new()
	marker.name = P2_MARKER
	marker.polygon = PackedVector2Array([Vector2(-4, -27), Vector2(4, -27), Vector2(0, -21)])
	marker.color = P2_COLOR
	marker.z_index = 50
	entity.add_child(marker)


## Player 2 swaps to the other living enemy (the knight and the archer take turns); the one it leaves goes back to the AI.
func switch_p2() -> bool:
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as CharacterBody2D
		if enemy and enemy != _p2_entity and not _is_dead(enemy) and not BotToggle.is_benched(enemy):
			_release_p2()
			_take_p2(enemy)
			return true
	return false


# ---------------------------------------------------------------- helpers

func _register_actions() -> void:
	for table in [P1_ACTIONS, P2_ACTIONS]:
		for action in table:
			if not InputMap.has_action(action):
				InputMap.add_action(action)
				var event := InputEventKey.new()
				event.physical_keycode = table[action]
				InputMap.action_add_event(action, event)


func _local_player() -> Node2D:
	for node in get_tree().get_nodes_in_group("players"):
		var candidate := node as Node2D
		if candidate and candidate.is_multiplayer_authority():
			return candidate
	return null


func _find_player_controller(entity: Node) -> PlayerController:
	var combat := CombatComponent.find_on(entity)
	if combat == null or combat.get_parent() == null:
		return null
	for child in combat.get_parent().get_children():
		if child is PlayerController and child.name != P2_CONTROLLER:
			return child
	return null


func _is_dead(entity: Node) -> bool:
	var combat := CombatComponent.find_on(entity)
	return combat != null and combat.get_state() == ActionStateMachine.State.DEAD


func _switcher() -> ControlSwitcher:
	if get_parent() == null:
		return null
	return get_parent().get_node_or_null("ControlSwitcher") as ControlSwitcher


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	_button = Button.new()
	_button.toggle_mode = true
	# Never take keyboard focus: the game keys would otherwise press the button.
	_button.focus_mode = Control.FOCUS_NONE
	_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_button.offset_left = 320.0 # right of the loadout button
	_button.offset_right = 320.0 # zero-width box: the button is only as big as its text
	_button.offset_top = 8.0
	_button.grow_horizontal = Control.GROW_DIRECTION_END
	_button.toggled.connect(set_two_player)
	layer.add_child(_button)

	_hint_layer = CanvasLayer.new()
	_hint_layer.layer = 6
	add_child(_hint_layer)
	var hint := Label.new()
	hint.text = "P1:  WASD move   F attack   G block   H dash   R switch      P2:  Arrows move   N attack   M block   , dash   . switch"
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.offset_bottom = -8.0
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hint.add_theme_constant_override("outline_size", 5)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_layer.add_child(hint)
	_hint_layer.visible = false


func _update_button() -> void:
	if _button == null:
		return
	_button.set_pressed_no_signal(two_player)
	_button.text = "Mode: 2P (local)" if two_player else "Mode: 1P (mouse)"
