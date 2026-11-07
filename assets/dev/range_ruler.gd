extends Node2D
class_name RangeRuler

# Dev tool for balancing skill ranges: F5 shows / hides labelled rings at RINGS_TILES arena tiles
# (16 px each) around your fighter, so "6 tiles" in the pause menu's Skills sliders can be judged
# by eye against the arena and the other fighters. Drawn in the world, over the floor.

const TOGGLE_KEY := KEY_F5
const RINGS_TILES: Array[int] = [2, 4, 6, 8, 10, 12]
const RING_COLOR := Color(1.0, 1.0, 1.0, 0.35)
const LABEL_COLOR := Color(1.0, 1.0, 1.0, 0.8)
const FONT_SIZE := 6

@export var shown: bool = false

var _player: Node2D


func _ready() -> void:
	z_index = 2
	visible = shown


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == TOGGLE_KEY:
		shown = not shown
		visible = shown
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not shown:
		return
	if not is_instance_valid(_player) or not _player.is_in_group("players"):
		_player = null
		for node in get_tree().get_nodes_in_group("players"):
			if node is Node2D and (node as Node2D).is_multiplayer_authority():
				_player = node
				break
	if _player:
		global_position = _player.global_position
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for tiles in RINGS_TILES:
		var r := tiles * SkillData.TILE
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, RING_COLOR, 0.6)
		draw_string(font, Vector2(r + 1.0, -1.0), "%d" % tiles, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, LABEL_COLOR)
	# Tick marks every tile along the four axes.
	var outer := RINGS_TILES[-1]
	for axis in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		for i in range(1, outer + 1):
			var p: Vector2 = axis * i * SkillData.TILE
			var side: Vector2 = axis.orthogonal() * (2.0 if i % 2 == 0 else 1.0)
			draw_line(p - side, p + side, RING_COLOR, 0.6)
	draw_string(font, Vector2(-14, -RINGS_TILES[-1] * SkillData.TILE - 3.0), "tiles (F5)", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, LABEL_COLOR)
