extends Node
class_name BotToggle

# Test helper: a button at the top of the screen removes every AI-controlled
# fighter from the fight ("AI Bots: OFF") and brings them back ("AI Bots: ON").
# Fighters controlled by a human (Player 1, Player 2) are never touched.
#
# "Removed" means asleep: hidden, no collision, can't be hit or targeted, not
# processed. Waking them restores everything. Nothing is deleted, so health and
# positions are kept. The respawner is told not to spawn new bots while off.

const ASLEEP_META := "bot_asleep"
const SAVED_LAYER_META := "bot_saved_layer"
const SAVED_MASK_META := "bot_saved_mask"
const GROUPS := ["players", "allies", "enemies"]
## Set by the "Teams: 1v1" button: this fighter sits the match out, and "AI Bots: ON" must not wake it.
const BENCH_META := "benched"

@export var start_enabled: bool = true

var bots_enabled: bool = true
var _button: Button


func _ready() -> void:
	_build_button()
	call_deferred("set_bots_enabled", start_enabled)


func _process(_delta: float) -> void:
	# New bots can appear while off (a respawn, or a fighter handed back to the AI): put them to sleep too.
	if not bots_enabled:
		_sleep_all()


func set_bots_enabled(value: bool) -> void:
	bots_enabled = value
	var respawner := _respawner()
	if respawner:
		respawner.set_bots_enabled(value)
	if value:
		_wake_all()
	else:
		_sleep_all()
	_update_button()


## True for fighters the AI is driving right now.
static func is_bot(entity: Node) -> bool:
	var combat := CombatComponent.find_on(entity)
	return combat != null and combat.controller is AIComponent


static func is_asleep(entity: Node) -> bool:
	return entity != null and entity.has_meta(ASLEEP_META)


static func is_benched(entity: Node) -> bool:
	return entity != null and entity.has_meta(BENCH_META)


func _sleep_all() -> void:
	var seen: Dictionary = {}
	for group_name in GROUPS:
		for node in get_tree().get_nodes_in_group(group_name):
			var entity := node as CharacterBody2D
			if entity == null or seen.has(entity):
				continue
			seen[entity] = true
			if not is_asleep(entity) and is_bot(entity):
				sleep(entity)


func _wake_all() -> void:
	for group_name in GROUPS:
		for node in get_tree().get_nodes_in_group(group_name):
			var entity := node as CharacterBody2D
			if entity and is_asleep(entity) and not is_benched(entity):
				wake(entity)


static func sleep(entity: CharacterBody2D) -> void:
	entity.set_meta(ASLEEP_META, true)
	entity.set_meta(SAVED_LAYER_META, entity.collision_layer)
	entity.set_meta(SAVED_MASK_META, entity.collision_mask)
	entity.collision_layer = 0
	entity.collision_mask = 0
	entity.visible = false
	entity.process_mode = Node.PROCESS_MODE_DISABLED
	_set_hurtbox(entity, false)
	_set_hud(entity, false)


## Wakes one sleeping fighter (also used when a human takes over a sleeping bot).
static func wake(entity: CharacterBody2D) -> void:
	entity.remove_meta(ASLEEP_META)
	entity.collision_layer = int(entity.get_meta(SAVED_LAYER_META, entity.collision_layer))
	entity.collision_mask = int(entity.get_meta(SAVED_MASK_META, entity.collision_mask))
	entity.visible = true
	# Still counting down: stay frozen, the countdown un-freezes everyone when it ends.
	entity.process_mode = Node.PROCESS_MODE_DISABLED if FightCountdown.active else Node.PROCESS_MODE_INHERIT
	_set_hurtbox(entity, true)
	_set_hud(entity, true)


static func _set_hurtbox(entity: Node, active: bool) -> void:
	for child in entity.get_children():
		for node in [child] + child.get_children():
			if node is HitboxComponent:
				node.can_be_hit = active
				node.set_deferred("monitorable", active)
				node.set_deferred("monitoring", active)


## The name label and health bar live in a CanvasLayer under the fighter, which
## does not follow the fighter's visibility.
static func _set_hud(entity: Node, shown: bool) -> void:
	for child in entity.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = shown


func _respawner() -> EnemyRespawner:
	if get_parent() == null:
		return null
	return get_parent().get_node_or_null("EnemyRespawner") as EnemyRespawner


# ---------------------------------------------------------------- UI

func _build_button() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	_button = Button.new()
	_button.toggle_mode = true
	# Never take keyboard focus: the game keys would otherwise press the button.
	_button.focus_mode = Control.FOCUS_NONE
	_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	# Zero-width box, growing leftwards, just left of the Dummy button.
	_button.offset_left = -215.0
	_button.offset_right = -215.0
	_button.offset_top = 8.0
	_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_button.toggled.connect(set_bots_enabled)
	layer.add_child(_button)
	_button.add_to_group("game_option") # the pause menu shows it in Dev Tools


func _update_button() -> void:
	if _button == null:
		return
	_button.set_pressed_no_signal(bots_enabled)
	_button.text = "AI Bots: %s" % ("ON" if bots_enabled else "OFF")
