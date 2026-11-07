extends Node
class_name KnockbackMeter

# Shows every fighter's knockback meter as a percentage next to its health bar ("KB 30%").
#
# The meter is HitboxComponent.knockback_scale, shown as the extra on top of normal: a scale of 1.0 reads 0%, and it
# rises with every hit the fighter takes (+0.15 per hit and +0.01 per damage, up to 6.0 = 500%). It never fades:
# only a respawn resets it. The higher it is, the further a hit throws the fighter, like the damage percent in Smash.
#
# This node only draws it: a small label is added to each fighter's health bar (fighters that appear later, such as
# respawns, get one too). The colour goes white -> yellow -> red as the meter climbs, and the number pops when it
# rises. It can be hidden with the "Show knockback %" setting (Settings > Display).

const COLOR_LOW := Color(1.0, 1.0, 1.0)
const COLOR_MID := Color(1.0, 0.85, 0.3)
const COLOR_HIGH := Color(1.0, 0.3, 0.25)
## The label's pop (scale) when the meter rises, and how fast it settles back (per second).
const POP_SCALE := 1.35
const POP_SETTLE := 6.0

const FIGHTER_GROUPS := ["players", "enemies", "allies"]

var _entries: Dictionary = {} # fighter instance id -> {"fighter", "hitbox", "label", "last"}


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	for group_name in FIGHTER_GROUPS:
		for node in get_tree().get_nodes_in_group(group_name):
			_add(node)


func _on_node_added(node: Node) -> void:
	if node is CharacterBody2D:
		_add.call_deferred(node) # groups are set up by the time the deferred call runs


func _process(delta: float) -> void:
	var show := bool(DevSettings.get_value("show_knockback"))
	for id in _entries.keys():
		var entry: Dictionary = _entries[id]
		# Untyped on purpose: assigning an already freed object to a typed variable is an error, and a fighter
		# (and its health bar and our label with it) can be freed at any time, for example when it dies.
		var fighter = entry.fighter
		var label = entry.label
		var hitbox = entry.hitbox
		if not is_instance_valid(fighter) or not is_instance_valid(label) or not is_instance_valid(hitbox):
			if is_instance_valid(label):
				label.queue_free()
			_entries.erase(id)
			continue
		label.visible = show
		if not show:
			continue
		var scale_now: float = hitbox.knockback_scale
		label.text = "KB %d%%" % int(round((scale_now - 1.0) * 100.0))
		label.add_theme_color_override("font_color", _color_for(scale_now))
		if scale_now > entry.last + 0.001:
			label.scale = Vector2.ONE * POP_SCALE
		entry.last = scale_now
		label.scale = label.scale.lerp(Vector2.ONE, clampf(POP_SETTLE * delta, 0.0, 1.0))


## White at 0%, yellow at 100%, red at 200% and above.
func _color_for(knockback_scale: float) -> Color:
	var up := clampf(knockback_scale - 1.0, 0.0, 2.0)
	if up <= 1.0:
		return COLOR_LOW.lerp(COLOR_MID, up)
	return COLOR_MID.lerp(COLOR_HIGH, up - 1.0)


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
	if combat == null or combat.hitbox_component == null or combat.health_component == null:
		return
	var bar := combat.health_component.healthbar
	if bar == null:
		return
	var label := Label.new()
	label.name = "KnockbackLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	label.text = "KB 0%"
	bar.add_child(label)
	# Just above the bar, level with the fighter's name, on the side the name is NOT on: the bars on the left of the
	# screen have their name on the left (label at the right end), the bars on the right have it on the right (label at the
	# left end).
	var on_right_half := bar.get_global_rect().get_center().x > bar.get_viewport().get_visible_rect().size.x * 0.5
	label.offset_top = -23.0
	if on_right_half:
		label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.offset_left = 0.0
		label.pivot_offset = Vector2(0.0, 10.0)
	else:
		label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		label.offset_right = 0.0
		label.pivot_offset = Vector2(60.0, 10.0)
	_entries[node.get_instance_id()] = {"fighter": node, "hitbox": combat.hitbox_component, "label": label, "last": 1.0}
