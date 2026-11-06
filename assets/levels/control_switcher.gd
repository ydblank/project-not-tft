extends Node
class_name ControlSwitcher

# Press R to take over your teammate (the player's side is 2v2). The fighter you
# were playing is handed to the AI, the teammate gets your keyboard and mouse.
#
# Control is just a swap of "brains": the human fighter is in the "players" group
# and driven by a PlayerController, the AI fighter is in "allies" and driven by an
# AIComponent. Both components are created on demand and kept, so swapping back
# and forth is cheap. If the fighter you control is removed (dies for good),
# control passes to a living teammate by itself.

@export var key: Key = KEY_R
@export var show_hint: bool = true
## Off while local co-op is running (R does nothing, no automatic hand-over).
@export var enabled: bool = true: set = _set_enabled

signal control_changed(entity: Node2D)

const AI_SCENE := preload("res://assets/scenes/ai_component.tscn")
const MARKER_NAME := "ControlMarker"
const SKIP_PROPS := ["entity", "combat_component", "movement_component", "hitbox_component"]

var _hint: Label


func _ready() -> void:
	if show_hint:
		_build_hint()
	call_deferred("_mark_controlled")


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == key:
		get_viewport().set_input_as_handled()
		switch()


func _process(_delta: float) -> void:
	if not enabled:
		return
	# The fighter we controlled is gone: hand control to a living teammate.
	if _controlled() == null:
		var next := _next_teammate(null)
		if next:
			_take_control(next, _ai_template())


## Swap control to the next living teammate. Returns false if there is none.
func switch() -> bool:
	var current := _controlled()
	var target := _next_teammate(current)
	if current == null or target == null:
		return false
	var template := _ai_template()
	_give_to_ai(current, template)
	_take_control(target, template)
	return true


# ---------------------------------------------------------------- lookup

func _controlled() -> Node2D:
	for node in get_tree().get_nodes_in_group("players"):
		var candidate := node as Node2D
		if candidate and candidate.is_multiplayer_authority() and not _is_dead(candidate):
			return candidate
	return null


func _next_teammate(current: Node2D) -> Node2D:
	for node in get_tree().get_nodes_in_group("allies"):
		var candidate := node as Node2D
		if candidate and candidate != current and not _is_dead(candidate) and not BotToggle.is_asleep(candidate):
			return candidate
	return null


func _is_dead(entity: Node) -> bool:
	for child in entity.get_children():
		for grandchild in child.get_children():
			if grandchild is HealthComponent:
				return grandchild.is_dead()
	return false


func _find_child_of_type(entity: Node, type: Variant) -> Node:
	var combat := CombatComponent.find_on(entity)
	if combat == null or combat.get_parent() == null:
		return null
	for sibling in combat.get_parent().get_children():
		if is_instance_of(sibling, type):
			return sibling
	return null


## Any existing AI brain on the player's side, used as the settings to copy.
func _ai_template() -> AIComponent:
	for node in get_tree().get_nodes_in_group("allies"):
		var ai := _find_child_of_type(node, AIComponent) as AIComponent
		if ai:
			return ai
	return null


# ---------------------------------------------------------------- swapping brains

func _take_control(entity: Node2D, template: AIComponent) -> void:
	var combat := CombatComponent.find_on(entity)
	if combat == null:
		return
	var ai := _find_child_of_type(entity, AIComponent) as AIComponent
	if ai:
		ai.intent.clear()
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	var pc := _find_child_of_type(entity, PlayerController) as PlayerController
	if pc == null:
		pc = PlayerController.new()
		pc.name = "PlayerController"
		pc.entity = entity
		combat.get_parent().add_child(pc)
	pc.process_mode = Node.PROCESS_MODE_INHERIT
	combat.controller = pc
	# Only one fighter is ever human-controlled: anyone else goes back to the AI.
	for other in get_tree().get_nodes_in_group("players").duplicate():
		if other != entity and other.is_multiplayer_authority():
			_give_to_ai(other as Node2D, template)
	entity.remove_from_group("allies")
	entity.add_to_group("players")
	_after_swap()


func _give_to_ai(entity: Node2D, template: AIComponent) -> void:
	var combat := CombatComponent.find_on(entity)
	if combat == null:
		return
	var pc := _find_child_of_type(entity, PlayerController) as PlayerController
	if pc:
		pc.intent.clear()
		pc.process_mode = Node.PROCESS_MODE_DISABLED
	var ai := _find_child_of_type(entity, AIComponent) as AIComponent
	if ai == null:
		ai = AI_SCENE.instantiate() as AIComponent
		ai.name = "AIComponent"
		if template:
			for prop in template.get_property_list():
				var usage: int = prop.usage
				if (usage & PROPERTY_USAGE_STORAGE) and (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) and not SKIP_PROPS.has(prop.name):
					ai.set(prop.name, template.get(prop.name))
		ai.entity = entity as CharacterBody2D
		ai.combat_component = combat
		ai.movement_component = combat.movement_component
		ai.hitbox_component = combat.hitbox_component
		combat.get_parent().add_child(ai)
	ai.intent.clear()
	ai.process_mode = Node.PROCESS_MODE_INHERIT
	combat.controller = ai
	entity.remove_from_group("players")
	entity.add_to_group("allies")


func _after_swap() -> void:
	control_changed.emit(_controlled())
	_mark_controlled()
	var tuning := get_parent().get_node_or_null("DevTuning") if get_parent() else null
	if tuning and tuning.has_method("apply_all"):
		tuning.call("apply_all")


# ---------------------------------------------------------------- UI

## A small gold arrow above the fighter you control.
func _mark_controlled() -> void:
	var current := _controlled()
	for group_name in ["players", "allies"]:
		for node in get_tree().get_nodes_in_group(group_name):
			var old := node.get_node_or_null(MARKER_NAME)
			if old and node != current:
				old.queue_free()
	if current == null or current.has_node(MARKER_NAME):
		return
	var marker := Polygon2D.new()
	marker.name = MARKER_NAME
	marker.polygon = PackedVector2Array([Vector2(-4, -27), Vector2(4, -27), Vector2(0, -21)])
	marker.color = Color(1.0, 0.85, 0.2)
	marker.z_index = 50
	current.add_child(marker)


func _build_hint() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	_hint = Label.new()
	_hint.text = "R: switch character"
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_bottom = -8.0
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hint)


func _set_enabled(value: bool) -> void:
	enabled = value
	if _hint:
		_hint.visible = value # the "R: switch character" hint only makes sense while R works


## Shows or hides the "R: switch character" label (local co-op prints its own key list).
func set_hint_visible(value: bool) -> void:
	if _hint:
		_hint.visible = value
