extends CanvasLayer
class_name FightCountdown

# Freezes every fighter at level start and shows a big 3-2-1-FIGHT! countdown.
# Fighters are frozen with process_mode DISABLED (not the tree pause), so the
# Esc pause menu keeps working during the countdown (the countdown pauses with it).

@export var seconds: int = 3
@export var groups: Array[String] = ["players", "enemies", "allies"]
@export var fight_text: String = "FIGHT!"

var _label: Label
## True while the countdown is running (fighters are frozen). Other tools check it so they do not un-freeze anyone early.
static var active: bool = false
var _frozen: Array[Node] = []
var _tween: Tween


func _ready() -> void:
	layer = 15
	active = true
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 96)
	_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 12)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_label.pivot_offset = get_viewport().get_visible_rect().size * 0.5
	_freeze_fighters() # before the first physics frame, so nobody acts (or dashes) early
	call_deferred("_run")


func _exit_tree() -> void:
	active = false


func _freeze_fighters() -> void:
	for group_name in groups:
		for node in get_tree().get_nodes_in_group(group_name):
			if node is CharacterBody2D and not _frozen.has(node):
				_frozen.append(node)
				node.process_mode = Node.PROCESS_MODE_DISABLED


func _run() -> void:
	_freeze_fighters() # catches anything added since _ready
	for n in range(seconds, 0, -1):
		await _show(str(n), 1.0)
	active = false
	for node in _frozen:
		# Fighters put to sleep during the countdown (AI Bots OFF, 1v1) must stay switched off.
		if is_instance_valid(node) and not BotToggle.is_asleep(node):
			node.process_mode = Node.PROCESS_MODE_INHERIT
	_frozen.clear()
	await _show(fight_text, 0.6)
	queue_free()


func _show(text: String, duration: float) -> void:
	if text == fight_text:
		Sfx.play(&"fight", 0.0, 1.0, 0.0, 0.0)
	else:
		Sfx.play(&"countdown_tick", 0.0, 1.0 if text != "1" else 0.9, 0.0, 0.0)
	_label.text = text
	_label.modulate.a = 1.0
	_label.scale = Vector2(1.5, 1.5)
	if _tween:
		_tween.kill()
	var tween := create_tween()
	_tween = tween
	tween.set_parallel(true)
	tween.tween_property(_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_label, "modulate:a", 0.0, duration * 0.3).set_delay(duration * 0.7)
	await get_tree().create_timer(duration).timeout
