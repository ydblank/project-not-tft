extends CanvasLayer

# On-screen controller overlay (like a phone-emulator gamepad): a WASD pad on
# the left and the Ultimate / Skill / Attack / Block / Dash buttons on the right. Buttons light up
# while the real input is held. Key names are read from the InputMap, so the
# labels always match the project's bindings. F1 shows / hides it.

const TOGGLE_KEY := KEY_F1

const KEY_SIZE := 52.0
const BUTTON_SIZE := 64.0
const GAP := 6.0
const MARGIN := 24.0

const COLOR_IDLE_BG := Color(0.08, 0.08, 0.1, 0.55)
const COLOR_IDLE_BORDER := Color(1, 1, 1, 0.3)
const COLOR_IDLE_TEXT := Color(1, 1, 1, 0.75)
const COLOR_DOWN_BG := Color(1.0, 0.85, 0.4, 0.92)
const COLOR_DOWN_BORDER := Color(1, 1, 1, 0.95)
const COLOR_DOWN_TEXT := Color(0.1, 0.08, 0.02, 1)
const COLOR_COOLDOWN := Color(0, 0, 0, 0.6)
const COLOR_BROKEN := Color(0.45, 0.05, 0.05, 0.7)
const COLOR_RING := Color(0.3, 0.17, 0.0, 1) # dark: the charging Attack button is lit gold
const COLOR_SHIELD_RING := Color(0.55, 0.8, 1.0, 1)
const COLOR_DASH_RING := Color(1.0, 0.85, 0.4, 1)
const COLOR_PIP := Color(0.9, 0.95, 1.0, 1)
const COLOR_PIP_EMPTY := Color(1, 1, 1, 0.35)
const COLOR_SKILL_READY_FLASH := Color(1.0, 0.9, 0.5, 1)
## Ultimate meter ring and the ready glow.
const COLOR_ULT_READY := Color(1.0, 0.25, 0.2, 1)
## The skill button is dimmed this much when the weapon has no skill.
const NO_SKILL_ALPHA := 0.35
const SKILL_ICON_SIZE := 26.0

var _root: Control
var _player: Node2D
var _combat: CombatComponent
var _shield: ShieldComponent
var _by_action: Dictionary = {} # action name -> InputKey
var _pad: Control
var _buttons: Control
var _hint: Label
var _keys: Array[InputKey] = []
var _skill_icon: SkillIcon
var _skill_time: Label
var _skill_was_cooling: bool = false
var _skill_shown: SkillData = null
var _ult_label: Label
var _ult_was_ready: bool = false


## A drawn symbol (mouse button / spacebar) used in place of text.
class Glyph extends Control:
	enum Kind {MOUSE_LEFT, MOUSE_RIGHT, SPACE}

	var kind: Kind
	var color: Color = COLOR_IDLE_TEXT

	func _init(p_kind: Kind) -> void:
		kind = p_kind
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(30, 12) if kind == Kind.SPACE else Vector2(22, 30)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if kind == Kind.SPACE:
			# The "open box" spacebar symbol.
			draw_polyline(PackedVector2Array([Vector2(1, 1), Vector2(1, h - 1), Vector2(w - 1, h - 1), Vector2(w - 1, 1)]), color, 2.5)
			return

		# Mouse: outline, with the pressed button's half filled in.
		var outline := StyleBoxFlat.new()
		outline.bg_color = Color(0, 0, 0, 0)
		outline.border_color = color
		outline.set_border_width_all(2)
		outline.set_corner_radius_all(int(w * 0.5))
		draw_style_box(outline, Rect2(Vector2.ZERO, size))

		var split_y := h * 0.45
		var fill := StyleBoxFlat.new()
		fill.bg_color = color
		fill.set_corner_radius_all(1)
		var left := kind == Kind.MOUSE_LEFT
		if left:
			fill.corner_radius_top_left = int(w * 0.5)
		else:
			fill.corner_radius_top_right = int(w * 0.5)
		var half := Rect2(Vector2(0 if left else w * 0.5, 0), Vector2(w * 0.5, split_y))
		draw_style_box(fill, half)
		draw_line(Vector2(0, split_y), Vector2(w, split_y), color, 2.0)
		draw_line(Vector2(w * 0.5, 0), Vector2(w * 0.5, split_y), color, 2.0)


## The skill's icon: the SkillData texture, or a generic drawn four-point sparkle when it has none.
class SkillIcon extends Control:
	var texture: Texture2D = null
	var color: Color = COLOR_IDLE_TEXT

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(SKILL_ICON_SIZE, SKILL_ICON_SIZE)

	func _draw() -> void:
		if texture != null:
			draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false)
			return
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		var star := PackedVector2Array()
		for i in 8:
			var a := -PI * 0.5 + TAU * i / 8.0
			star.append(c + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.32))
		draw_colored_polygon(star, color)


## Cooldown overlay for a round button: a dark "clock" sweep for the time
## still remaining, and an optional ring around the rim (charge / shield HP).
class Spinner extends Control:
	var _cooldown: float = 0.0
	var _cooldown_color: Color = COLOR_COOLDOWN
	var _ring: float = -1.0
	var _ring_color: Color = COLOR_RING
	var _pips_total: int = 0
	var _pips_filled: int = 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	## Small dots along the bottom, one per charge (filled = available).
	func set_pips(total: int, filled: int) -> void:
		if total == _pips_total and filled == _pips_filled:
			return
		_pips_total = total
		_pips_filled = filled
		queue_redraw()

	## remaining: 1.0 = just started, 0.0 = ready. ring < 0 hides the rim ring.
	func set_values(remaining: float, ring: float, cooldown_color: Color, ring_color: Color) -> void:
		remaining = clampf(remaining, 0.0, 1.0)
		ring = clampf(ring, 0.0, 1.0) if ring >= 0.0 else -1.0
		if is_equal_approx(remaining, _cooldown) and is_equal_approx(ring, _ring) \
				and cooldown_color == _cooldown_color and ring_color == _ring_color:
			return
		_cooldown = remaining
		_ring = ring
		_cooldown_color = cooldown_color
		_ring_color = ring_color
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5 - 2.0
		const START := -PI * 0.5 # 12 o'clock
		if _cooldown > 0.0:
			# The remaining time is the dark wedge; it shrinks clockwise.
			var from := START + TAU * (1.0 - _cooldown)
			var points := PackedVector2Array([center])
			var steps := maxi(int(48.0 * _cooldown), 2)
			for i in steps + 1:
				var a := from + (START + TAU - from) * float(i) / float(steps)
				points.append(center + Vector2(cos(a), sin(a)) * radius)
			draw_colored_polygon(points, _cooldown_color)
		if _ring >= 0.0:
			draw_arc(center, radius - 1.0, START, START + TAU * _ring, 48, _ring_color, 3.0, true)
		if _pips_total > 0:
			var spacing := 11.0
			var x0 := center.x - spacing * (_pips_total - 1) * 0.5
			var y := -9.0 # just above the button so they never cover the symbol
			for i in _pips_total:
				var p := Vector2(x0 + spacing * i, y)
				if i < _pips_filled:
					draw_circle(p, 3.5, COLOR_PIP)
				else:
					draw_arc(p, 3.0, 0.0, TAU, 12, COLOR_PIP_EMPTY, 1.5, true)


## One on-screen button: lights up while its input action is held. Shows text
## for letters and drawn symbols for the mouse buttons and spacebar.
class InputKey extends PanelContainer:
	var action: StringName
	## Only round buttons get one (dash / block / attack).
	var spinner: Spinner
	var _idle_style := StyleBoxFlat.new()
	var _down_style := StyleBoxFlat.new()
	var _labels: Array[Label] = []
	var _glyphs: Array[Glyph] = []
	var _was_down := false

	func _init(p_action: StringName, tokens: PackedStringArray, size: float, circular: bool) -> void:
		action = p_action
		custom_minimum_size = Vector2(size, size)
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		pivot_offset = Vector2(size, size) * 0.5

		_setup_style(_idle_style, COLOR_IDLE_BG, COLOR_IDLE_BORDER, size, circular)
		_setup_style(_down_style, COLOR_DOWN_BG, COLOR_DOWN_BORDER, size, circular)
		add_theme_stylebox_override("panel", _idle_style)

		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 4)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(box)

		for token in tokens:
			var item := _make_token(token)
			box.add_child(item)
			if item is CenterContainer:
				item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if circular:
			spinner = Spinner.new()
			add_child(spinner) # last child = drawn on top
		_apply(false)

	func _make_token(token: String) -> Control:
		var glyph_kind := -1
		match token:
			"LMB":
				glyph_kind = Glyph.Kind.MOUSE_LEFT
			"RMB":
				glyph_kind = Glyph.Kind.MOUSE_RIGHT
			"Space":
				glyph_kind = Glyph.Kind.SPACE
		if glyph_kind >= 0:
			var glyph := Glyph.new(glyph_kind)
			_glyphs.append(glyph)
			var center := CenterContainer.new()
			center.add_child(glyph)
			return center
		var label := Label.new()
		label.text = token
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 18)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_labels.append(label)
		return label

	func _setup_style(style: StyleBoxFlat, bg: Color, border: Color, size: float, circular: bool) -> void:
		style.bg_color = bg
		style.set_border_width_all(2)
		style.border_color = border
		style.set_corner_radius_all(int(size * 0.5) if circular else 8)
		style.content_margin_left = 2
		style.content_margin_right = 2
		style.content_margin_top = 2
		style.content_margin_bottom = 2

	func refresh() -> void:
		var down := Input.is_action_pressed(action)
		if down != _was_down:
			_apply(down)

	func _apply(down: bool) -> void:
		_was_down = down
		add_theme_stylebox_override("panel", _down_style if down else _idle_style)
		var text_color := COLOR_DOWN_TEXT if down else COLOR_IDLE_TEXT
		for label in _labels:
			label.add_theme_color_override("font_color", text_color)
		for glyph in _glyphs:
			glyph.color = text_color
			glyph.queue_redraw()
		scale = Vector2.ONE * (0.92 if down else 1.0)

	## A short glow (the skill coming off cooldown).
	func flash(color: Color) -> void:
		var tween := create_tween()
		self_modulate = color * 1.6
		tween.tween_property(self, "self_modulate", Color.WHITE, 0.45)

	## Puts a control above the key's text (the skill icon).
	func add_top(item: Control) -> void:
		var box := get_child(0) as VBoxContainer
		var center := CenterContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(item)
		box.add_child(center)
		box.move_child(center, 0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Keybinds.ensure_loaded() # the labels show the rebound keys, so load them first
	add_to_group(&"keybind_listeners")
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _process(_delta: float) -> void:
	if not _root.visible:
		return
	for key in _keys:
		key.refresh()
	_update_spinners()


# ======================================================================
# Cooldown spinners
#   Dash   - dark sweep while the dash cooldown runs
#   Block  - blue ring = shield HP (when not full); red sweep while broken
#   Attack - gold ring fills while charging a heavy hit
# ======================================================================

func _update_spinners() -> void:
	_resolve_player()
	var dash := _spinner_for("dash")
	var block := _spinner_for("Block")
	var attack := _spinner_for("Attack")
	if _combat == null:
		for s in [dash, block, attack]:
			if s:
				s.set_values(0.0, -1.0, COLOR_COOLDOWN, COLOR_RING)
		return

	if dash:
		# Charges as dots. A short sweep covers the gap between chained dashes;
		# a ring shows a charge coming back; the red sweep is the slow reload
		# after every charge was used in a row.
		var charges := _combat.get_dash_charges()
		var max_charges := _combat.get_dash_max_charges()
		var recharge := _combat.get_dash_recharge_ratio()
		var reloading := _combat.is_dash_reloading()
		var sweep := recharge if reloading else _combat.get_dash_cooldown_ratio()
		var ring := -1.0
		if not reloading and charges < max_charges and recharge > 0.0:
			ring = 1.0 - recharge
		dash.set_values(sweep, ring, COLOR_BROKEN if reloading else COLOR_COOLDOWN, COLOR_DASH_RING)
		dash.set_pips(max_charges if max_charges > 1 else 0, charges)

	if block:
		if _shield == null:
			block.set_values(0.0, -1.0, COLOR_COOLDOWN, COLOR_SHIELD_RING)
		else:
			var ratio := _shield.shield_hp / maxf(_shield.max_shield_hp, 0.001)
			if _shield.is_broken():
				block.set_values(1.0 - ratio, ratio, COLOR_BROKEN, COLOR_SHIELD_RING)
			else:
				block.set_values(0.0, ratio if ratio < 0.999 else -1.0, COLOR_COOLDOWN, COLOR_SHIELD_RING)

	if attack:
		var charging := _combat.get_state() == ActionStateMachine.State.CHARGING
		attack.set_values(0.0, _combat.get_charge_ratio() if charging else -1.0, COLOR_COOLDOWN, COLOR_RING)

	_update_skill_button()
	_update_ult_button()


## Ultimate (Q): a red ring fills with the meter; when full the button glows red; while it runs a
## sweep in the ultimate's colour shows the time left. Dimmed for a class without an ultimate.
func _update_ult_button() -> void:
	var key: InputKey = _by_action.get("ultimate")
	if key == null or key.spinner == null:
		return
	var has_ult := _combat != null and _combat.has_ultimate()
	key.modulate.a = 1.0 if has_ult else NO_SKILL_ALPHA
	if not has_ult:
		key.spinner.set_values(0.0, -1.0, COLOR_COOLDOWN, COLOR_ULT_READY)
		key.self_modulate = Color.WHITE
		return
	var active := _combat.is_ult_active()
	var full := _combat.is_ult_ready()
	if active:
		var c := _combat.get_ult_color()
		c.a = 0.55
		key.spinner.set_values(_combat.get_ult_time_ratio(), -1.0, c, COLOR_ULT_READY)
	else:
		key.spinner.set_values(0.0, _combat.get_ult_charge(), COLOR_COOLDOWN, COLOR_ULT_READY)
	if full:
		# Ready: the button throbs red, in step with the aura on the fighter.
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * UltimateAura.READY_PULSE)
		key.self_modulate = Color.WHITE.lerp(COLOR_ULT_READY * 1.6, 0.35 + 0.35 * pulse)
	elif _ult_was_ready:
		key.self_modulate = Color.WHITE
	_ult_was_ready = full
	if _ult_label:
		_ult_label.add_theme_color_override("font_color", _combat.get_ult_color() if active else COLOR_ULT_READY)


## Skill (E): icon, dark sweep + seconds left while on cooldown, a flash when it is ready again,
## dimmed when the weapon has no skill.
func _update_skill_button() -> void:
	var key: InputKey = _by_action.get("skill")
	if key == null:
		return
	var skill := _combat.get_skill() if _combat else null
	key.modulate.a = 1.0 if skill != null else NO_SKILL_ALPHA
	if skill != _skill_shown:
		_skill_shown = skill
		if _skill_icon:
			_skill_icon.texture = skill.icon if skill else null
			_skill_icon.queue_redraw()
		key.tooltip_text = skill.display_name if skill else "No skill"
	var ratio := _combat.get_skill_cooldown_ratio() if _combat else 0.0
	var left := _combat.get_skill_cooldown_left() if _combat else 0.0
	if key.spinner:
		# While casting (the fireball), a gold ring fills like the Attack button's heavy charge.
		var cast := _combat.get_skill_cast_ratio() if _combat else -1.0
		key.spinner.set_values(ratio, cast, COLOR_COOLDOWN, COLOR_DASH_RING)
	if _skill_time:
		_skill_time.visible = left > 0.0
		_skill_time.text = str(ceili(left))
	var cooling := left > 0.0
	if _skill_was_cooling and not cooling and skill != null:
		key.flash(COLOR_SKILL_READY_FLASH)
	_skill_was_cooling = cooling


func _spinner_for(action: String) -> Spinner:
	var key: InputKey = _by_action.get(action)
	return key.spinner if key else null


## Rebuilds the buttons so their labels show the new keys (Settings -> Controls calls this group).
func on_keybinds_changed() -> void:
	var was_visible := _root.visible
	_root.queue_free()
	_keys.clear()
	_by_action.clear()
	_skill_shown = null
	_build()
	_root.visible = was_visible
	_layout()


## The local player's components (re-resolved if the player node goes away).
func _resolve_player() -> void:
	if is_instance_valid(_player) and is_instance_valid(_combat) and _player.is_in_group("players"):
		return
	_player = null
	_combat = null
	_shield = null
	for node in get_tree().get_nodes_in_group("players"):
		var candidate := node as Node2D
		if candidate == null or not candidate.is_multiplayer_authority():
			continue
		_player = candidate
		_combat = CombatComponent.find_on(candidate)
		if _combat and _combat.get_parent():
			for sibling in _combat.get_parent().get_children():
				if sibling is ShieldComponent:
					_shield = sibling
		return


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == TOGGLE_KEY:
		_root.visible = not _root.visible
		get_viewport().set_input_as_handled()


# ======================================================================
# Build / layout
# ======================================================================

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Movement pad (cross layout): W on top, A S D underneath.
	_pad = Control.new()
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.custom_minimum_size = Vector2(KEY_SIZE * 3 + GAP * 2, KEY_SIZE * 2 + GAP)
	_pad.size = _pad.custom_minimum_size
	_root.add_child(_pad)
	var step := KEY_SIZE + GAP
	_add_key(_pad, "W", Vector2(step, 0), KEY_SIZE, false)
	_add_key(_pad, "A", Vector2(0, step), KEY_SIZE, false)
	_add_key(_pad, "S", Vector2(step, step), KEY_SIZE, false)
	_add_key(_pad, "D", Vector2(step * 2, step), KEY_SIZE, false)

	# Action buttons: Ultimate bottom-left, Skill top-left, Dash on top, Block left, Attack (largest) bottom-right.
	var ult_offset := BUTTON_SIZE * 0.5 + GAP
	var skill_offset := BUTTON_SIZE * 0.5 + GAP
	_buttons = Control.new()
	_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buttons.custom_minimum_size = Vector2(BUTTON_SIZE * 2 + GAP + 20 + skill_offset + ult_offset, BUTTON_SIZE * 2 + GAP)
	_buttons.size = _buttons.custom_minimum_size
	_root.add_child(_buttons)
	var big := BUTTON_SIZE + 20.0
	_add_key(_buttons, "ultimate", Vector2(0, BUTTON_SIZE + GAP), BUTTON_SIZE, true)
	_add_key(_buttons, "skill", Vector2(ult_offset, 0), BUTTON_SIZE, true)
	_add_key(_buttons, "dash", Vector2(ult_offset + skill_offset + BUTTON_SIZE * 0.5, 0), BUTTON_SIZE, true)
	_add_key(_buttons, "Block", Vector2(ult_offset + skill_offset, BUTTON_SIZE + GAP), BUTTON_SIZE, true)
	_add_key(_buttons, "Attack", Vector2(ult_offset + skill_offset + BUTTON_SIZE + GAP, BUTTON_SIZE - 12.0 + GAP), big, true)
	var ult_key: InputKey = _by_action["ultimate"]
	_ult_label = Label.new()
	_ult_label.text = "ULT"
	_ult_label.add_theme_font_size_override("font_size", 11)
	_ult_label.add_theme_color_override("font_color", COLOR_ULT_READY)
	_ult_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ult_key.add_top(_ult_label)
	var skill_key: InputKey = _by_action["skill"]
	_skill_icon = SkillIcon.new()
	skill_key.add_top(_skill_icon)
	_skill_time = Label.new()
	_skill_time.set_anchors_preset(Control.PRESET_FULL_RECT)
	_skill_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_skill_time.add_theme_font_size_override("font_size", 22)
	_skill_time.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_skill_time.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_skill_time.add_theme_constant_override("outline_size", 5)
	_skill_time.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_time.visible = false
	skill_key.add_child(_skill_time) # after the spinner: the number sits on top of the sweep

	_hint = Label.new()
	_hint.text = "%s hide" % OS.get_keycode_string(TOGGLE_KEY)
	_hint.add_theme_font_size_override("font_size", 11)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hint)


func _add_key(parent: Control, action: StringName, pos: Vector2, size: float, circular: bool) -> void:
	var key := InputKey.new(action, _key_tokens(action), size, circular)
	key.position = pos
	key.size = Vector2(size, size)
	parent.add_child(key)
	_keys.append(key)
	_by_action[String(action)] = key


func _layout() -> void:
	if _root == null:
		return
	var view := get_viewport().get_visible_rect().size
	_pad.position = Vector2(MARGIN, view.y - MARGIN - _pad.size.y)
	_buttons.position = Vector2(view.x - MARGIN - _buttons.size.x, view.y - MARGIN - _buttons.size.y)
	_hint.position = Vector2(view.x - MARGIN - _hint.size.x, view.y - MARGIN - _buttons.size.y - 18.0)


# ======================================================================
# Key names from the InputMap
# ======================================================================

## One token per distinct binding of the action (e.g. ["F", "Space"]).
func _key_tokens(action: String) -> PackedStringArray:
	var names: PackedStringArray = []
	if InputMap.has_action(action):
		for event in InputMap.action_get_events(action):
			var key_name := _event_name(event)
			if key_name != "" and not names.has(key_name):
				names.append(key_name)
	if names.is_empty():
		names.append("?")
	return names


func _event_name(event: InputEvent) -> String:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return "" # the overlay shows the keyboard and mouse; controller bindings are listed in Settings -> Controls
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				return "LMB"
			MOUSE_BUTTON_RIGHT:
				return "RMB"
			MOUSE_BUTTON_MIDDLE:
				return "MMB"
		return "Mouse %d" % event.button_index
	if event is InputEventKey:
		var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		if code == KEY_NONE:
			return ""
		return OS.get_keycode_string(code)
	return event.as_text()
