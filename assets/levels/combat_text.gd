extends CanvasLayer
class_name CombatText

# Big combat call-outs in the middle of the screen, for the fighter you control:
#   - "GUARD BREAK!" (orange) when you break someone's guard, "GUARD BROKEN!" (red) when yours breaks;
#   - a hit combo counter ("3 HITS") that counts the hits you land in a row. It starts at 2, pops with every hit,
#     and ends when COMBO_WINDOW seconds pass without a hit or when you get hit.
# The guard-break banner used to be a small word floating over the fighter; it now lives here.

const COLOR_BREAK := Color(1.0, 0.6, 0.2)
const COLOR_BROKEN := Color(1.0, 0.3, 0.28)
const COLOR_COMBO := Color(1.0, 0.92, 0.5)
## Seconds without landing a hit before the combo ends.
const COMBO_WINDOW := 1.6
## Seconds the finished combo stays on screen (fading) before it disappears.
const COMBO_FADE := 0.5
const POP_SCALE := 1.35
const POP_SETTLE := 10.0
## Vertical position of the texts, as a fraction of the screen height.
const BANNER_Y := 0.38
const COMBO_Y := 0.52

const FIGHTER_GROUPS := ["players", "enemies", "allies"]

var _banner: Label
var _combo_label: Label
var _banner_tween: Tween
var _player: Node2D
var _combat: CombatComponent
var _hitbox: HitboxComponent
var _hits: int = 0
var _time_since_hit: float = 0.0
var _fade_left: float = 0.0 # seconds of fade-out left after a combo ended
var _connected: Dictionary = {} # fighter instance id -> true


func _ready() -> void:
	layer = 12 # above the HUD, below the countdown
	_banner = _make_label(54, BANNER_Y)
	_combo_label = _make_label(36, COMBO_Y)
	_combo_label.add_theme_color_override("font_color", COLOR_COMBO)
	get_tree().node_added.connect(_on_node_added)
	for group_name in FIGHTER_GROUPS:
		for node in get_tree().get_nodes_in_group(group_name):
			_watch(node)


func _process(delta: float) -> void:
	_follow_player()
	if _hits > 0:
		_time_since_hit += delta
		if _time_since_hit >= COMBO_WINDOW:
			_end_combo()
	_fade_left = maxf(_fade_left - delta, 0.0)
	var alpha := 1.0 if _hits >= 2 else _fade_left / COMBO_FADE
	_combo_label.modulate.a = alpha
	_combo_label.visible = alpha > 0.0
	_combo_label.scale = _combo_label.scale.lerp(Vector2.ONE, clampf(POP_SETTLE * delta, 0.0, 1.0))


func _make_label(font_size: int, y_fraction: float) -> Label:
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.anchor_top = y_fraction
	label.anchor_bottom = y_fraction
	label.offset_top = -40.0
	label.offset_bottom = 40.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible = false
	add_child(label)
	label.resized.connect(func(): label.pivot_offset = label.size * 0.5)
	return label


# ---------------------------------------------------------------- guard break

func _on_node_added(node: Node) -> void:
	if node is CharacterBody2D:
		_watch.call_deferred(node)


## Listens for guard breaks on every fighter (respawned fighters are new nodes, so they are picked up here too).
func _watch(node: Node) -> void:
	if not is_instance_valid(node) or not node is CharacterBody2D or _connected.has(node.get_instance_id()):
		return
	var combat := CombatComponent.find_on(node)
	if combat == null or combat.hitbox_component == null:
		return
	_connected[node.get_instance_id()] = true
	combat.hitbox_component.guard_broke.connect(_on_guard_broke.bind(node))


func _on_guard_broke(attacker: Node, victim: Node) -> void:
	if is_instance_valid(victim) and victim == _player:
		_announce("GUARD BROKEN!", COLOR_BROKEN)
	elif is_instance_valid(attacker) and attacker == _player:
		_announce("GUARD BREAK!", COLOR_BREAK)


func _announce(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.visible = true
	_banner.modulate.a = 1.0
	_banner.scale = Vector2.ONE * 1.5
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(0.7)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.3)
	_banner_tween.tween_callback(func(): _banner.visible = false)


# ---------------------------------------------------------------- hit combo

## Follows the fighter you control (it changes with a character switch).
func _follow_player() -> void:
	var player: Node2D = null
	for node in get_tree().get_nodes_in_group("players"):
		var candidate := node as Node2D
		if candidate and candidate.is_multiplayer_authority():
			player = candidate
			break
	if player == _player:
		return
	_unbind()
	_player = player
	_hits = 0
	_fade_left = 0.0
	if player == null:
		return
	_combat = CombatComponent.find_on(player)
	if _combat == null:
		return
	_hitbox = _combat.hitbox_component
	_combat.hit_landed.connect(_on_hit_landed)
	if _hitbox:
		_hitbox.hit_received.connect(_on_hit_received)


func _unbind() -> void:
	if is_instance_valid(_combat) and _combat.hit_landed.is_connected(_on_hit_landed):
		_combat.hit_landed.disconnect(_on_hit_landed)
	if is_instance_valid(_hitbox) and _hitbox.hit_received.is_connected(_on_hit_received):
		_hitbox.hit_received.disconnect(_on_hit_received)
	_combat = null
	_hitbox = null


func _on_hit_landed(_target: Node2D, result: int) -> void:
	if result != HitboxComponent.Result.HIT:
		return
	_hits += 1
	_time_since_hit = 0.0
	if _hits >= 2:
		_combo_label.text = "%d HITS" % _hits
		_combo_label.scale = Vector2.ONE * POP_SCALE
		_combo_label.visible = true


## Getting hit ends your combo.
func _on_hit_received(_attacker: Node, _damage: float, _direction: Vector2) -> void:
	_end_combo()


## The counter fades out (a combo of one hit was never shown).
func _end_combo() -> void:
	if _hits >= 2:
		_fade_left = COMBO_FADE
	_hits = 0
