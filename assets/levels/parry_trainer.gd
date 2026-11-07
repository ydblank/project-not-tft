extends Node
class_name ParryTrainer

# Parry training mode. A button at the top of the screen (or F3) turns it on:
#   - the match becomes a 1v1 against the melee knight (same as "Teams: 1v1");
#   - the knight stops thinking and just swings on a fixed, predictable pattern (TrainingAttacker);
#   - both fighters are made unkillable and put face to face;
#   - a panel on the right shows short instructions, your parry stats, and feedback on your last try.
# Turning it off gives the knight its AI back and restores everything.

const PANEL_WIDTH := 300.0
## Where the two fighters are placed (world px), left of the centre column.
const PLAYER_START := Vector2(-70.0, 0.0)
const ENEMY_START := Vector2(-30.0, 0.0)
## A hit on the knight this soon after a parry counts as a counter.
const COUNTER_TIME := 1.5
## Attack speed of the knight when "Slow" is on (1.0 = normal): longer wind-up, easier to read.
const SLOW_ATTACK_SPEED := 0.55

## Warning ("!" before a swing) choices: label and seconds. The parry window is 0.2s, so ~0.4s lets a
## normal reaction (~0.25s) raise the block inside it; "Long" is early on purpose (you must wait).
const WARN_NAMES := ["Warning: 0.4s", "Warning: 0.7s", "Warning: off"]
const WARN_TIMES := [0.4, 0.7, 0.0]

const COLOR_GOOD :=Color(0.55, 1.0, 0.6)
const COLOR_WARN := Color(1.0, 0.85, 0.4)
const COLOR_BAD := Color(1.0, 0.5, 0.45)
const COLOR_INFO := Color(0.75, 0.85, 1.0)

const INSTRUCTIONS := "1. Aim your block at the knight.\n" \
		+ "2. When the knight turns red, press RIGHT MOUSE. The swing lands right after (parry window: first 0.2s of a block).\n" \
		+ "3. After a parry, click LEFT MOUSE to counter.\n" \
		+ "Heavies can't be parried. Re-blocking within 0.5s gives no parry."

var active: bool = false

var _button: Button
var _panel: PanelContainer
var _stats_label: Label
var _result_label: Label
var _pattern_button: Button
var _speed_button: Button
var _warn_button: Button
var _warn_index: int = 0

var _attacker: TrainingAttacker
var _enemy: CharacterBody2D
var _enemy_combat: CombatComponent
var _enemy_ai: AIComponent
var _player: CharacterBody2D
var _player_combat: CombatComponent
var _player_hitbox: HitboxComponent

var _pattern: int = TrainingAttacker.Pattern.SINGLE_LIGHT
var _slow: bool = false
var _prev_one_v_one: bool = false
var _prev_invincible: Dictionary = {} # HealthComponent -> bool
var _prev_attack_speed: float = 1.0

var _parries: int = 0
var _blocked: int = 0
var _hits: int = 0
var _counters: int = 0
var _streak: int = 0
var _best_streak: int = 0
var _since_parry: float = 999.0
var _block_started_ms: int = -1
var _prev_player_state: int = -1


func _ready() -> void:
	_build_ui()
	_refresh()


func _exit_tree() -> void:
	if active:
		disable()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		get_viewport().set_input_as_handled()
		set_active(not active)


func _physics_process(delta: float) -> void:
	if not active:
		return
	if not is_instance_valid(_enemy) or not is_instance_valid(_player):
		disable()
		return
	_since_parry += delta
	var state := _player_combat.get_state() as int
	if state == ActionStateMachine.State.BLOCK and _prev_player_state != ActionStateMachine.State.BLOCK:
		_block_started_ms = Time.get_ticks_msec()
	_prev_player_state = state


func set_active(value: bool) -> void:
	if value:
		enable()
	else:
		disable()


## Starts the training. Does nothing (and says why) if the knight or the player cannot be found.
func enable() -> void:
	if active:
		return
	var team := _team_size()
	_prev_one_v_one = team != null and team.one_v_one
	if team:
		team.set_one_v_one(true)
	_player = _find_player()
	_enemy = _find_knight()
	if _player == null or _enemy == null:
		if team:
			team.set_one_v_one(_prev_one_v_one)
		_say("Could not start: needs the player and the enemy knight.", COLOR_BAD)
		_refresh()
		return
	_player_combat = CombatComponent.find_on(_player)
	_enemy_combat = CombatComponent.find_on(_enemy)
	_player_hitbox = _player_combat.hitbox_component
	if BotToggle.is_asleep(_enemy):
		BotToggle.wake(_enemy) # "AI Bots: OFF" had put it to sleep
	_swap_brain_in()
	_set_invincible(true)
	_place_fighters()
	_prev_attack_speed = _enemy_combat.sm.attack_speed
	_apply_speed()
	_connect_signals()
	_reset_stats()
	_prev_player_state = -1
	active = true
	_say("Ready. Get your block up just before the knight's swing lands.", COLOR_INFO)
	_refresh()


## Ends the training and restores the knight's AI and the previous team size.
func disable() -> void:
	if not active:
		return
	active = false
	_disconnect_signals()
	if is_instance_valid(_enemy_combat):
		_enemy_combat.sm.attack_speed = _prev_attack_speed
	_swap_brain_out()
	_set_invincible(false)
	var team := _team_size()
	if team:
		team.set_one_v_one(_prev_one_v_one)
	var bots := get_parent().get_node_or_null("BotToggle") as BotToggle if get_parent() else null
	if bots and not bots.bots_enabled and is_instance_valid(_enemy) and BotToggle.is_bot(_enemy):
		BotToggle.sleep(_enemy) # "AI Bots: OFF" is still on
	_refresh()


# ---------------------------------------------------------------- setup helpers

func _swap_brain_in() -> void:
	var holder := _enemy_combat.get_parent()
	for sibling in holder.get_children():
		if sibling is AIComponent:
			_enemy_ai = sibling
	if _enemy_ai:
		_enemy_ai.intent.clear()
		_enemy_ai.process_mode = Node.PROCESS_MODE_DISABLED
	_attacker = TrainingAttacker.new()
	_attacker.name = "TrainingAttacker"
	_attacker.entity = _enemy
	_attacker.combat = _enemy_combat
	_attacker.pattern = _pattern as TrainingAttacker.Pattern
	_attacker.warn_time = WARN_TIMES[_warn_index]
	holder.add_child(_attacker)
	_enemy_combat.controller = _attacker


func _swap_brain_out() -> void:
	if is_instance_valid(_enemy_combat):
		if is_instance_valid(_enemy_ai):
			_enemy_ai.intent.clear()
			_enemy_ai.process_mode = Node.PROCESS_MODE_INHERIT
			_enemy_combat.controller = _enemy_ai
	if is_instance_valid(_attacker):
		_attacker.queue_free()
	_attacker = null
	_enemy_ai = null


func _set_invincible(on: bool) -> void:
	if on:
		_prev_invincible.clear()
		for fighter in [_player_combat, _enemy_combat]:
			var health: HealthComponent = fighter.health_component
			if health:
				_prev_invincible[health] = health.invincible
				health.set_hp(health.get_max_hp())
				health.invincible = true
	else:
		for health in _prev_invincible:
			if is_instance_valid(health):
				health.invincible = _prev_invincible[health]
		_prev_invincible.clear()


func _place_fighters() -> void:
	_player.global_position = PLAYER_START
	_enemy.global_position = ENEMY_START
	_player.velocity = Vector2.ZERO
	_enemy.velocity = Vector2.ZERO
	if _attacker:
		_attacker.restart(1.2)


func _apply_speed() -> void:
	if is_instance_valid(_enemy_combat):
		_enemy_combat.sm.attack_speed = SLOW_ATTACK_SPEED if _slow else _prev_attack_speed


func _connect_signals() -> void:
	if _player_hitbox:
		_player_hitbox.parried.connect(_on_parried)
		_player_hitbox.blocked_hit.connect(_on_blocked)
		_player_hitbox.hit_received.connect(_on_hit)
	_player_combat.hit_landed.connect(_on_player_hit_landed)


func _disconnect_signals() -> void:
	if is_instance_valid(_player_hitbox):
		if _player_hitbox.parried.is_connected(_on_parried):
			_player_hitbox.parried.disconnect(_on_parried)
		if _player_hitbox.blocked_hit.is_connected(_on_blocked):
			_player_hitbox.blocked_hit.disconnect(_on_blocked)
		if _player_hitbox.hit_received.is_connected(_on_hit):
			_player_hitbox.hit_received.disconnect(_on_hit)
	if is_instance_valid(_player_combat) and _player_combat.hit_landed.is_connected(_on_player_hit_landed):
		_player_combat.hit_landed.disconnect(_on_player_hit_landed)


# ---------------------------------------------------------------- feedback

func _on_parried(_direction: Vector2) -> void:
	_parries += 1
	_streak += 1
	_best_streak = maxi(_best_streak, _streak)
	_since_parry = 0.0
	_say("PARRY! Block went up %d ms before the hit. Now click to counter!" % _lead_ms(), COLOR_GOOD)
	_refresh()


func _on_blocked(_direction: Vector2, is_heavy: bool) -> void:
	_blocked += 1
	_streak = 0
	if is_heavy:
		_say("Heavy hit blocked. Heavy swings cannot be parried: block them (it costs shield) or dash away.", COLOR_INFO)
	else:
		var window_ms := int(_player_combat.parry_window * 1000.0)
		var lead := _lead_ms()
		if lead > window_ms:
			_say("Blocked, not parried: block went up %d ms early (window is %d ms). Press block later." % [lead, window_ms], COLOR_WARN)
		else:
			_say("Blocked, not parried: you re-blocked too soon after letting go. Wait half a second between tries.", COLOR_WARN)
	_refresh()


func _on_hit(_attacker_node: Node, _damage: float, _direction: Vector2) -> void:
	_hits += 1
	_streak = 0
	if _player_combat.get_state() == ActionStateMachine.State.BLOCK:
		_say("Hit through your block: aim it at the knight (your block faces the mouse).", COLOR_BAD)
	else:
		_say("Hit! Block was not up. Raise it (right mouse) just before the swing lands.", COLOR_BAD)
	_refresh()


func _on_player_hit_landed(target: Node2D, result: int) -> void:
	if target == _enemy and result == HitboxComponent.Result.HIT and _since_parry < COUNTER_TIME:
		_counters += 1
		_since_parry = 999.0
		_say("Counter landed! That is the full parry loop.", COLOR_GOOD)
		_refresh()


## Milliseconds since the player's current block began (0 when not blocking).
func _lead_ms() -> int:
	if _block_started_ms < 0 or _player_combat.get_state() != ActionStateMachine.State.BLOCK:
		return 0
	return Time.get_ticks_msec() - _block_started_ms


func _reset_stats() -> void:
	_parries = 0
	_blocked = 0
	_hits = 0
	_counters = 0
	_streak = 0
	_best_streak = 0
	_since_parry = 999.0


# ---------------------------------------------------------------- lookups

func _team_size() -> TeamSize:
	return get_parent().get_node_or_null("TeamSize") as TeamSize if get_parent() else null


func _find_player() -> CharacterBody2D:
	for node in get_tree().get_nodes_in_group("players"):
		var candidate := node as CharacterBody2D
		if candidate and candidate.is_multiplayer_authority() and CombatComponent.find_on(candidate):
			return candidate
	return null


## The awake melee enemy: the one 1v1 mode keeps.
func _find_knight() -> CharacterBody2D:
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as CharacterBody2D
		if enemy == null or BotToggle.is_benched(enemy):
			continue
		var combat := CombatComponent.find_on(enemy)
		if combat and combat.weapon and combat.weapon.kind == WeaponData.Kind.MELEE:
			return enemy
	return null


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)

	_button = Button.new()
	_button.toggle_mode = true
	_button.focus_mode = Control.FOCUS_NONE # game keys must not press it
	_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_button.offset_left = 0.0
	_button.offset_right = 0.0
	_button.offset_top = 76.0
	_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_button.tooltip_text = "Practise parrying a knight with a fixed attack pattern (F3)"
	_button.toggled.connect(func(pressed: bool): set_active(pressed))
	layer.add_child(_button)
	_button.add_to_group("game_option") # the pause menu shows it in Dev Tools

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -(PANEL_WIDTH + 12.0)
	_panel.offset_right = -12.0
	_panel.offset_top = 118.0
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.1, 0.9)
	style.border_color = Color(1.0, 0.85, 0.4, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	layer.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)

	var title := Label.new()
	title.text = "PARRY TRAINER"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	box.add_child(title)

	var guide := Label.new()
	guide.text = INSTRUCTIONS
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.custom_minimum_size = Vector2(PANEL_WIDTH - 20.0, 0.0)
	guide.add_theme_font_size_override("font_size", 11)
	guide.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	box.add_child(guide)

	box.add_child(HSeparator.new())

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 13)
	box.add_child(_stats_label)

	_result_label = Label.new()
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.custom_minimum_size = Vector2(PANEL_WIDTH - 20.0, 36.0)
	_result_label.add_theme_font_size_override("font_size", 12)
	box.add_child(_result_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	box.add_child(row)
	_pattern_button = _small_button(row, _cycle_pattern)
	_speed_button = _small_button(row, _toggle_speed)
	_small_button(row, _on_reset_pressed).text = "Reset"
	var row2 := HBoxContainer.new()
	box.add_child(row2)
	_warn_button = _small_button(row2, _cycle_warning)

	var hint := Label.new()
	hint.text = "F3 or the top button (paused): exit"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	box.add_child(hint)


func _small_button(parent: Control, callback: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 11)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func _cycle_pattern() -> void:
	_pattern = (_pattern + 1) % TrainingAttacker.PATTERN_NAMES.size()
	if _attacker:
		_attacker.pattern = _pattern as TrainingAttacker.Pattern
		_attacker.restart(1.0)
	_refresh()


func _cycle_warning() -> void:
	_warn_index = (_warn_index + 1) % WARN_TIMES.size()
	if _attacker:
		_attacker.warn_time = WARN_TIMES[_warn_index]
		_attacker.restart(1.0)
	_refresh()


func _on_reset_pressed() -> void:
	_reset_stats()
	_say("Stats reset.", COLOR_INFO)
	_refresh()


func _toggle_speed() -> void:
	_slow = not _slow
	_apply_speed()
	_refresh()


func _say(text: String, color: Color) -> void:
	if _result_label:
		_result_label.text = text
		_result_label.add_theme_color_override("font_color", color)


func _refresh() -> void:
	if _button == null:
		return
	_button.set_pressed_no_signal(active)
	_button.text = "Parry Training: ON (F3)" if active else "Parry Training: OFF (F3)"
	_panel.visible = active
	_pattern_button.text = "Pattern: " + TrainingAttacker.PATTERN_NAMES[_pattern]
	_speed_button.text = "Speed: Slow" if _slow else "Speed: Normal"
	_warn_button.text = WARN_NAMES[_warn_index]
	var attempts := _parries + _blocked + _hits
	var rate := (100.0 * _parries / attempts) if attempts > 0 else 0.0
	_stats_label.text = "Parries %d   Blocked %d   Hit %d\nCounters %d   Streak %d (best %d)\nParry rate %d%%" % [_parries, _blocked, _hits, _counters, _streak, _best_streak, int(rate)]
