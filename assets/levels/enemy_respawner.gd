extends Node
class_name EnemyRespawner

# Test helper: brings enemies and allies back after they die. Every one already in the
# level when it starts gets a "slot" (its scene + spawn point). When one is
# removed, a fresh copy appears at the same spot after `respawn_delay`.
# A button at the top of the screen turns it on / off; while off, dead enemies
# stay dead, and turning it back on respawns the ones that are missing.

@export var enabled: bool = true
@export var respawn_delay: float = 2.5
@export var groups: Array[String] = ["enemies", "allies"]
@export var show_button: bool = true

## Set by the "AI Bots" button: while false nothing is spawned, the slots wait.
var bots_enabled: bool = true

var _missing_slots: Array = [] # slots whose enemy is gone while respawning is off
var _button: Button


func _ready() -> void:
	call_deferred("_scan_existing")
	if show_button:
		_build_button()


func _scan_existing() -> void:
	var found: Array[Node] = []
	for group_name in groups:
		for node in get_tree().get_nodes_in_group(group_name):
			if not found.has(node):
				found.append(node)
	for node in found:
		var enemy := node as Node2D
		if enemy == null or enemy.scene_file_path == "":
			continue
		var scene := load(enemy.scene_file_path) as PackedScene
		if scene == null:
			continue
		_track(enemy, {"scene": scene, "position": enemy.global_position, "parent": enemy.get_parent()})


func _track(enemy: Node, slot: Dictionary) -> void:
	enemy.tree_exited.connect(_on_enemy_gone.bind(slot), CONNECT_ONE_SHOT)


func _on_enemy_gone(slot: Dictionary) -> void:
	if not is_inside_tree():
		return # the level itself is closing
	if enabled and bots_enabled:
		_respawn_after_delay(slot)
	else:
		_missing_slots.append(slot)


func _respawn_after_delay(slot: Dictionary) -> void:
	await get_tree().create_timer(respawn_delay).timeout
	if not is_inside_tree():
		return
	if not enabled or not bots_enabled:
		_missing_slots.append(slot) # switched off while waiting
		return
	_spawn(slot)


func _spawn(slot: Dictionary) -> void:
	var parent: Node = slot.parent
	if not is_instance_valid(parent):
		return
	var enemy: Node2D = (slot.scene as PackedScene).instantiate()
	parent.add_child(enemy)
	enemy.global_position = slot.position
	_track(enemy, slot)


func set_enabled(value: bool) -> void:
	enabled = value
	_update_button()
	if enabled and bots_enabled:
		var pending := _missing_slots.duplicate()
		_missing_slots.clear()
		for slot in pending:
			_respawn_after_delay(slot)


# ---- toggle button ----

func _build_button() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	_button = Button.new()
	_button.toggle_mode = true
	_button.button_pressed = enabled
	# Never take keyboard focus: Space (dash) would otherwise press the button.
	_button.focus_mode = Control.FOCUS_NONE
	_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_button.offset_top = 8.0
	_button.toggled.connect(set_enabled)
	layer.add_child(_button)
	_button.add_to_group("game_option") # the pause menu shows it in Dev Tools
	_update_button()


func _update_button() -> void:
	if _button == null:
		return
	_button.set_pressed_no_signal(enabled)
	_button.text = "Respawn: %s" % ("ON" if enabled else "OFF")


## Called by the "AI Bots" button. Turning bots back on respawns the missing ones.
func set_bots_enabled(value: bool) -> void:
	bots_enabled = value
	if value and enabled:
		var pending := _missing_slots.duplicate()
		_missing_slots.clear()
		for slot in pending:
			_respawn_after_delay(slot)
