extends Node
class_name LoadoutSwitcher

# Test helper: cycles the local player's class + weapon while the game runs so
# you can try melee and ranged. Button at the top of the screen, or press F2.

const SWITCH_KEY := KEY_F2

const LOADOUTS := [
	{"name": "Archer / Bow", "class": Classes.CLASSES.ARCHER, "weapon": Weapons.WEAPONS.BOW},
	{"name": "Knight / Sword", "class": Classes.CLASSES.KNIGHT, "weapon": Weapons.WEAPONS.SWORD},
	{"name": "Thief / Dagger", "class": Classes.CLASSES.THIEF, "weapon": Weapons.WEAPONS.DAGGER},
	{"name": "Mage / Staff", "class": Classes.CLASSES.MAGE, "weapon": Weapons.WEAPONS.STAFF},
]

var _index: int = 0
var _button: Button


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	_button = Button.new()
	# Never take keyboard focus: Space (dash) would otherwise press the button.
	_button.focus_mode = Control.FOCUS_NONE
	_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_button.offset_left = 100.0
	_button.offset_top = 8.0
	_button.grow_horizontal = Control.GROW_DIRECTION_END
	_button.pressed.connect(cycle)
	layer.add_child(_button)
	_button.add_to_group("game_option") # the pause menu shows it in Dev Tools
	call_deferred("_sync_with_player")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == SWITCH_KEY:
		cycle()
		get_viewport().set_input_as_handled()


func cycle() -> void:
	_index = (_index + 1) % LOADOUTS.size()
	_apply()


## Starts from whatever the player scene is configured with.
func _sync_with_player() -> void:
	var player := _local_player()
	var stats := _stats_of(player)
	if stats:
		for i in LOADOUTS.size():
			if LOADOUTS[i].weapon == stats.entity_weapon:
				_index = i
	_update_text()


func _apply() -> void:
	var player := _local_player()
	var stats := _stats_of(player)
	if stats == null:
		return
	var loadout: Dictionary = LOADOUTS[_index]
	stats.entity_class = loadout["class"]
	stats.entity_weapon = loadout["weapon"]
	var combat := CombatComponent.find_on(player)
	if combat:
		combat.refresh_loadout()
	_update_text()


func _update_text() -> void:
	_button.text = "Player: %s  (F2)" % LOADOUTS[_index].name


func _local_player() -> Node2D:
	for node in get_tree().get_nodes_in_group("players"):
		var candidate := node as Node2D
		if candidate and candidate.is_multiplayer_authority():
			return candidate
	return null


func _stats_of(player: Node) -> StatsComponent:
	if player == null:
		return null
	for child in player.get_children():
		for grandchild in child.get_children():
			if grandchild is StatsComponent:
				return grandchild
	return null
