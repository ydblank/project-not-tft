extends CanvasLayer
class_name PartySelect

# The party screen at the start of a match: pick the class + weapon of you and your ally (Knight / Sword,
# Thief / Dagger, Archer / Bow, Mage / Staff) before the 3-2-1 countdown. The game is paused while the screen
# is open, so the countdown only starts running once you press Start.
#
# The choice is remembered for the rest of the session (a static), so Retry and respawned matches keep your
# party and skip the screen. The pause menu's "Party" button reloads the level and shows the screen again.
# It only changes your side; the enemy team is unchanged. Loadouts are the ones in LoadoutSwitcher.LOADOUTS.

## Remembered picks, one per row: 0 and 1 are indexes into LoadoutSwitcher.LOADOUTS (you, ally), then the
## option rows (see OPTION_NAMES): mode, AI bots, difficulty. -1 = not picked yet.
static var _picks: Array[int] = [-1, -1, 0, 0, 1]
## Set by the pause menu's Party button: show the screen on the next load even if a party is remembered.
static var show_next_time: bool = false

const SLOT_TITLES := ["You", "Ally", "Mode", "AI bots", "Difficulty"]
## The choices of the option rows (slots 2 to 4). Index 0 of "AI bots" is On.
const OPTION_NAMES := {
	2: ["1 Player", "2 Players"],
	3: ["On", "Off"],
	4: Difficulty.NAMES,
}
const MODE_SLOT := 2
const BOTS_SLOT := 3
const DIFFICULTY_SLOT := 4
const COLOR_TITLE := Color(1.0, 0.85, 0.4)

var _labels: Array[Label] = []
var _start_from_pad: bool = false
var _start_button: Button
var _next_buttons: Array[Button] = []
## Things hidden behind the screen (restored on Start).
var _hidden: Array[Node] = []


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_deferred.call_deferred()


## Called once the level tools and fighters exist.
func _apply_deferred() -> void:
	var remembered := _picks[0] >= 0
	if DevSettings.get_value("skip_countdown"):
		queue_free() # the "skip the countdown" test setting also skips the party screen
		return
	if remembered:
		_apply_picks()
	if remembered and not show_next_time:
		queue_free()
		return
	show_next_time = false
	if not remembered:
		_start_from_current()
	_hide_scene()
	_build()
	get_tree().paused = true
	_next_buttons[0].grab_focus()


func _input(event: InputEvent) -> void:
	# Left / Right (keyboard, D-pad, stick) change the class of the row the cursor is on.
	if event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_right"):
		var focused := get_viewport().gui_get_focus_owner()
		if focused and focused.has_meta(&"slot"):
			get_viewport().set_input_as_handled()
			_step(int(focused.get_meta(&"slot")), 1 if event.is_action_pressed(&"ui_right") else -1)
			return
	# The controller's Start button starts the match. GamepadControls turns it into an Esc key tap, so remember it
	# here and treat that Esc as "Start" (a keyboard Esc on its own does nothing).
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		if GamepadControls.active:
			_start_from_pad = true
		else:
			_start()
		return
	# Esc must not open the pause menu on top of this screen.
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _start_from_pad:
			_start()


## First time: start the picks from whatever the scene's fighters are using.
func _start_from_current() -> void:
	for slot in 2:
		var stats := _stats_of(_fighter(slot))
		_picks[slot] = 0
		if stats:
			for i in LoadoutSwitcher.LOADOUTS.size():
				if LoadoutSwitcher.LOADOUTS[i].weapon == stats.entity_weapon:
					_picks[slot] = i
	_picks[DIFFICULTY_SLOT] = int(DevSettings.get_value("difficulty"))


## Behind the screen only the arena shows: fighters and every HUD layer are hidden until Start.
func _hide_scene() -> void:
	for group_name in ["players", "allies", "enemies"]:
		for node in get_tree().get_nodes_in_group(group_name):
			_hide(node as CanvasItem)
	_hide_layers(get_tree().root)


func _hide_layers(node: Node) -> void:
	for child in node.get_children():
		if child == self:
			continue
		var layer_node := child as CanvasLayer
		if layer_node and layer_node.visible:
			layer_node.visible = false
			_hidden.append(layer_node)
		_hide_layers(child)


func _hide(item: CanvasItem) -> void:
	if item and item.visible:
		item.visible = false
		_hidden.append(item)


func _show_scene() -> void:
	for node in _hidden:
		if is_instance_valid(node):
			node.visible = true
	_hidden.clear()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Pick your party"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", COLOR_TITLE)
	box.add_child(title)

	for slot in SLOT_TITLES.size():
		box.add_child(_build_slot(slot))

	_start_button = Button.new()
	_start_button.text = "OK"
	_start_button.custom_minimum_size = Vector2(0, 40)
	_start_button.pressed.connect(_start)
	box.add_child(_start_button)



func _build_slot(slot: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var who := Label.new()
	who.text = SLOT_TITLES[slot]
	who.custom_minimum_size = Vector2(80, 0)
	row.add_child(who)
	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(190, 0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var arrows: Array[Button] = []
	for step in [-1, 1]:
		var arrow := Button.new()
		arrow.text = "<" if step < 0 else ">"
		arrow.custom_minimum_size = Vector2(40, 36)
		arrow.flat = true
		arrow.add_theme_stylebox_override("focus", StyleBoxEmpty.new()) # the row is highlighted instead
		arrow.pressed.connect(_step.bind(slot, step))
		arrow.set_meta(&"slot", slot)
		# The row lights up gold while the cursor is on it.
		arrow.focus_entered.connect(_highlight.bind(who, name_label, true))
		arrow.focus_exited.connect(_highlight.bind(who, name_label, false))
		arrows.append(arrow)
	row.add_child(arrows[0])
	row.add_child(name_label)
	row.add_child(arrows[1])
	_labels.append(name_label)
	_next_buttons.append(arrows[1])
	_refresh_label(slot)
	return row


func _highlight(who: Label, name_label: Label, on: bool) -> void:
	var color := COLOR_TITLE if on else Color.WHITE
	who.add_theme_color_override("font_color", color)
	name_label.add_theme_color_override("font_color", color)


func _step(slot: int, step: int) -> void:
	var count: int = LoadoutSwitcher.LOADOUTS.size() if slot < MODE_SLOT else OPTION_NAMES[slot].size()
	_picks[slot] = posmod(_picks[slot] + step, count)
	_refresh_label(slot)
	Sfx.play(&"ui_open", -6.0, 1.0, 0.0, 0.0)


func _refresh_label(slot: int) -> void:
	_labels[slot].text = LoadoutSwitcher.LOADOUTS[_picks[slot]].name if slot < MODE_SLOT else OPTION_NAMES[slot][_picks[slot]]


func _start() -> void:
	_show_scene() # before the picks: they put fighters to sleep (hidden) and toggle layers themselves
	_apply_picks()
	Sfx.play(&"ui_close", 0.0, 1.0, 0.0, 0.0)
	get_tree().paused = false
	queue_free()


# ---------------------------------------------------------------- applying

func _apply_picks() -> void:
	for slot in 2:
		_apply_loadout(_fighter(slot), LoadoutSwitcher.LOADOUTS[_picks[slot]], slot == 1)
	var switcher := get_parent().get_node_or_null("LoadoutSwitcher") if get_parent() else null
	if switcher and switcher.has_method("_sync_with_player"):
		switcher.call("_sync_with_player") # keep its button text in step
	_apply_options()


## Mode, AI bots and difficulty. The level reloads with its scene defaults, so they are applied again every time.
func _apply_options() -> void:
	var root := get_parent()
	if root == null:
		return
	DevSettings.set_value("difficulty", _picks[DIFFICULTY_SLOT])
	DevSettings.save()
	var tuning := root.get_node_or_null("DevTuning")
	if tuning and tuning.has_method("apply_all"):
		tuning.call("apply_all")
	var bots := root.get_node_or_null("BotToggle") as BotToggle
	if bots and bots.bots_enabled != (_picks[BOTS_SLOT] == 0):
		bots.set_bots_enabled(_picks[BOTS_SLOT] == 0)
	var coop := root.get_node_or_null("LocalCoop") as LocalCoop
	if coop and coop.two_player != (_picks[MODE_SLOT] == 1):
		coop.set_two_player(_picks[MODE_SLOT] == 1)


func _apply_loadout(fighter: Node2D, loadout: Dictionary, rename_to_class: bool) -> void:
	var stats := _stats_of(fighter)
	if stats == null:
		return
	stats.entity_class = loadout["class"]
	stats.entity_weapon = loadout["weapon"]
	var combat := CombatComponent.find_on(fighter)
	if combat == null:
		return
	combat.refresh_loadout()
	if rename_to_class and combat.health_component and combat.health_component.healthbar:
		var label := combat.health_component.healthbar.get_parent().get_node_or_null("Label") as Label
		if label:
			label.text = "Ally " + String(loadout["name"]).get_slice(" / ", 0).to_lower()


## Slot 0 = the fighter you control, slot 1 = your first AI teammate.
func _fighter(slot: int) -> Node2D:
	var group := "players" if slot == 0 else "allies"
	for node in get_tree().get_nodes_in_group(group):
		var candidate := node as Node2D
		if candidate and (slot == 1 or candidate.is_multiplayer_authority()):
			return candidate
	return null


func _stats_of(fighter: Node) -> StatsComponent:
	if fighter == null:
		return null
	for child in fighter.get_children():
		for grandchild in child.get_children():
			if grandchild is StatsComponent:
				return grandchild
	return null
