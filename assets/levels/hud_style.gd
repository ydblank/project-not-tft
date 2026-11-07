extends Node
class_name HudStyle

# Gives every fighter's combat HUD (health bar, shield bar, name) a cleaner look. It restyles the bars that the
# fighter scenes already contain, at run time, so the look lives in one place and respawned fighters get it too:
#   - rounded bars with a dark framed background;
#   - the health fill goes green -> amber -> red as health drops, with a warm trail where the last hit took it;
#   - the shield bar is blue (red while the guard is broken) instead of grey;
#   - names get an outline so they read over any tile, tinted by team (blue / red).
# Positions and sizes are not touched. To change the look, edit the constants below.

const COLOR_HEALTH_HIGH := Color(0.28, 0.80, 0.55)
const COLOR_HEALTH_MID := Color(0.97, 0.76, 0.26)
const COLOR_HEALTH_LOW := Color(0.93, 0.30, 0.28)
## Health ratio at which the fill starts to turn amber, and where it is fully red.
const HEALTH_MID_AT := 0.55
const HEALTH_LOW_AT := 0.25
const COLOR_TRAIL := Color(1.0, 0.82, 0.52, 0.95)
const COLOR_SHIELD := Color(0.45, 0.72, 1.0)
const COLOR_SHIELD_BROKEN := Color(0.95, 0.35, 0.32)
const COLOR_BG := Color(0.06, 0.07, 0.11, 0.92)
const COLOR_FRAME := Color(0.0, 0.0, 0.0, 0.95)
const NAME_FRIEND := Color(0.82, 0.93, 1.0)
const NAME_FOE := Color(1.0, 0.72, 0.66)
const CORNER := 3
const FIGHTER_GROUPS := ["players", "enemies", "allies"]

var _entries: Dictionary = {} # fighter instance id -> {"fighter", "combat", "hp_fill", "shield_fill"}


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	for group_name in FIGHTER_GROUPS:
		for node in get_tree().get_nodes_in_group(group_name):
			_add(node)


func _on_node_added(node: Node) -> void:
	if node is CharacterBody2D:
		_add.call_deferred(node)


func _process(_delta: float) -> void:
	for id in _entries.keys():
		var entry: Dictionary = _entries[id]
		# Untyped on purpose: a fighter can be freed at any time (a typed variable would error on a freed object).
		var fighter = entry.fighter
		var combat = entry.combat
		if not is_instance_valid(fighter) or not is_instance_valid(combat):
			_entries.erase(id)
			continue
		if entry.hp_fill and combat.health_component:
			entry.hp_fill.bg_color = _health_color(combat.health_component.get_hp_percentage() / 100.0)
			entry.hp_fill.border_color = entry.hp_fill.bg_color.lightened(0.35)
		if entry.shield_fill and combat.shield_component:
			var broken: bool = combat.shield_component.is_broken()
			var pulse: float = 0.8 + 0.2 * sin(Time.get_ticks_msec() / 90.0) if broken else 1.0
			entry.shield_fill.bg_color = (COLOR_SHIELD_BROKEN if broken else COLOR_SHIELD) * Color(pulse, pulse, pulse, 1.0)
			entry.shield_fill.border_color = entry.shield_fill.bg_color.lightened(0.35)


## Green when healthy, amber below HEALTH_MID_AT, red below HEALTH_LOW_AT (blended, not stepped).
func _health_color(ratio: float) -> Color:
	if ratio >= HEALTH_MID_AT:
		return COLOR_HEALTH_HIGH.lerp(COLOR_HEALTH_MID, 1.0 - clampf((ratio - HEALTH_MID_AT) / (1.0 - HEALTH_MID_AT) * 2.0, 0.0, 1.0))
	return COLOR_HEALTH_MID.lerp(COLOR_HEALTH_LOW, 1.0 - clampf((ratio - HEALTH_LOW_AT) / (HEALTH_MID_AT - HEALTH_LOW_AT), 0.0, 1.0))


func _add(node: Node) -> void:
	if not is_instance_valid(node) or not node is CharacterBody2D or _entries.has(node.get_instance_id()):
		return
	var is_fighter := false
	for group_name in FIGHTER_GROUPS:
		if node.is_in_group(group_name):
			is_fighter = true
	if not is_fighter:
		return
	var combat := CombatComponent.find_on(node)
	if combat == null:
		return
	var entry := {"fighter": node, "combat": combat, "hp_fill": null, "shield_fill": null}
	var friendly := node.is_in_group("players") or node.is_in_group("allies")
	var bar: HealthBarComponent = combat.health_component.healthbar if combat.health_component else null
	if bar:
		entry.hp_fill = _style_bar(bar, _health_color(1.0), COLOR_TRAIL)
		_style_name(bar.get_parent().get_node_or_null("Label") as Label, friendly)
	var shield_bar: ShieldBarComponent = combat.shield_component.shield_bar if combat.shield_component else null
	if shield_bar:
		entry.shield_fill = _style_bar(shield_bar, COLOR_SHIELD, COLOR_TRAIL)
	_entries[node.get_instance_id()] = entry


## Rounds and frames a ProgressBar and its trailing Damagebar; returns the main fill so its colour can change.
func _style_bar(bar: ProgressBar, fill_color: Color, trail_color: Color) -> StyleBoxFlat:
	var fill := _box(fill_color)
	fill.border_width_top = 1 # a faint highlight along the top edge
	fill.border_color = fill_color.lightened(0.35)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	var trail_bar := bar.get_node_or_null("Damagebar") as ProgressBar
	if trail_bar:
		var back := _box(COLOR_BG)
		back.set_expand_margin_all(1.0)
		back.shadow_color = Color(0, 0, 0, 0.35)
		back.shadow_size = 2
		back.shadow_offset = Vector2(0, 1)
		back.set_border_width_all(1)
		back.border_color = COLOR_FRAME
		trail_bar.add_theme_stylebox_override("background", back)
		trail_bar.add_theme_stylebox_override("fill", _box(trail_color))
	return fill


func _style_name(label: Label, friendly: bool) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", NAME_FRIEND if friendly else NAME_FOE)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06, 1.0))
	label.add_theme_constant_override("outline_size", 5)


func _box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(CORNER)
	return box
