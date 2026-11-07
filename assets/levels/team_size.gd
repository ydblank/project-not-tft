extends Node
class_name TeamSize

# Test helper: a button at the top of the screen switches between "Teams: 2v2"
# and "Teams: 1v1". In 1v1 your ally and the second enemy sit the match out
# (the enemy kept is the one Player 2 controls, otherwise a melee knight).
# Benched fighters are put to sleep exactly like with the "AI Bots" button
# (hidden, no collision, cannot be hit), with an extra mark so "AI Bots: ON"
# does not wake them. Going back to 2v2 brings them back.

@export var start_one_v_one: bool = false

var one_v_one: bool = false
var _button: Button


func _ready() -> void:
	_build_button()
	call_deferred("set_one_v_one", start_one_v_one)


func _process(_delta: float) -> void:
	# Respawns and fighters handed back to the AI can bring a new bot into a 1v1: bench it too.
	if one_v_one:
		_bench_extras()


func set_one_v_one(value: bool) -> void:
	one_v_one = value
	if value:
		_bench_extras()
	else:
		_unbench_all()
	var switcher := _switcher()
	if switcher:
		switcher.set_hint_visible(not value and not _coop_active())
	_update_button()


# ---------------------------------------------------------------- benching

func _bench_extras() -> void:
	# Blue team: every AI fighter (your ally, or the old body of a character you swapped away from).
	for node in get_tree().get_nodes_in_group("allies"):
		_bench_if_bot(node as CharacterBody2D)
	# Red team: keep one fighter, bench the rest.
	var keeper := _enemy_to_keep()
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as CharacterBody2D
		if enemy != keeper:
			_bench_if_bot(enemy)


func _bench_if_bot(entity: CharacterBody2D) -> void:
	if entity == null or BotToggle.is_benched(entity) or not BotToggle.is_bot(entity):
		return
	entity.set_meta(BotToggle.BENCH_META, true)
	if not BotToggle.is_asleep(entity):
		BotToggle.sleep(entity)


func _unbench_all() -> void:
	var bots_on := _bots_enabled()
	for group_name in ["allies", "enemies", "players"]:
		for node in get_tree().get_nodes_in_group(group_name):
			var entity := node as CharacterBody2D
			if entity and BotToggle.is_benched(entity):
				entity.remove_meta(BotToggle.BENCH_META)
				if bots_on:
					BotToggle.wake(entity) # with "AI Bots: OFF" they stay asleep like every other bot


## The red-team fighter that plays on: Player 2's, else an awake melee one, else any awake one.
func _enemy_to_keep() -> CharacterBody2D:
	var fallback: CharacterBody2D = null
	var melee: CharacterBody2D = null
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as CharacterBody2D
		if enemy == null or BotToggle.is_benched(enemy):
			continue
		if enemy.is_in_group("p2_controlled"):
			return enemy
		var combat := CombatComponent.find_on(enemy)
		if combat and combat.weapon and combat.weapon.kind == WeaponData.Kind.MELEE and melee == null:
			melee = enemy
		if fallback == null:
			fallback = enemy
	return melee if melee else fallback


func _bots_enabled() -> bool:
	var toggle := get_parent().get_node_or_null("BotToggle") as BotToggle if get_parent() else null
	return toggle == null or toggle.bots_enabled


func _coop_active() -> bool:
	var coop := get_parent().get_node_or_null("LocalCoop") as LocalCoop if get_parent() else null
	return coop != null and coop.two_player


func _switcher() -> ControlSwitcher:
	if get_parent() == null:
		return null
	return get_parent().get_node_or_null("ControlSwitcher") as ControlSwitcher


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
	# Zero-width box so the button is only as big as its text; second row, centred under "Respawn".
	_button.offset_left = 0.0
	_button.offset_right = 0.0
	_button.offset_top = 40.0
	_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_button.toggled.connect(func(pressed: bool): set_one_v_one(pressed))
	layer.add_child(_button)
	_button.add_to_group("game_option") # the pause menu shows it in Dev Tools


func _update_button() -> void:
	if _button == null:
		return
	_button.set_pressed_no_signal(one_v_one)
	_button.text = "Teams: 1v1" if one_v_one else "Teams: 2v2"
