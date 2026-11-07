extends Node2D
class_name BlockVisual

# Makes blocking readable at a glance, drawn on the fighter:
#   - a shield arc on the side being guarded (blue -> red as the shield drains)
#   - a bright pulse on the arc when a hit is blocked
#   - a small shield meter above the head while blocking or recovering
#   - a red flashing meter while the guard is broken
# Created by AnimationComponent; purely visual.

const ARC_RADIUS := 15.0
const ARC_HALF := deg_to_rad(67.5) # matches the 3 direction slots a block covers
const CENTER := Vector2(0, -2)
const BAR_SIZE := Vector2(18, 3)
const BAR_POS := Vector2(-9, -21)
const COLOR_FULL := Color(0.45, 0.75, 1.0)
const COLOR_LOW := Color(1.0, 0.3, 0.25)

var combat: CombatComponent
var shield: ShieldComponent

var _amount: float = 0.0 # 0..1, eases in while blocking
var _flash: float = 0.0 # pulse on a blocked hit
var _bar_alpha: float = 0.0
var _dir: Vector2 = Vector2.DOWN
var _time: float = 0.0
var _parry_flash: float = 0.0
var _armor_amount: float = 0.0 # 0..1, eases in while heavy super armor is up
var _armor_flash: float = 0.0 # pulse when a light hit is shrugged off
var _tell: int = TELL_NONE

const TELL_NONE := 0
const TELL_MELEE_WINDUP := 1 # a bot is about to swing
const TELL_MELEE_CHARGE := 2 # a bot is charging a heavy
const TELL_BOW_CHARGE := 3 # anyone drawing a heavy shot (a guide for you, a warning for bots)
const TELL_AIM_WINDUP := 4 # a ranged bot is about to shoot
const TELL_SKILL_CAST := 5 # casting a skill with a cast time (the Mage's fireball): drawn like a heavy charge
const COLOR_TELL := Color(1.0, 0.2, 0.15)
const COLOR_GOLD := Color(1.0, 0.85, 0.25)


func setup(p_combat: CombatComponent, p_shield: ShieldComponent) -> void:
	combat = p_combat
	shield = p_shield
	z_index = 3
	if combat and combat.hitbox_component:
		combat.hitbox_component.blocked_hit.connect(_on_blocked_hit)
		combat.hitbox_component.parried.connect(_on_parried)
	if combat:
		combat.armor_absorbed.connect(_on_armor_absorbed)
		combat.armor_broken.connect(_on_armor_broken)


func _on_blocked_hit(_direction: Vector2, is_heavy: bool) -> void:
	_flash = 1.0 if is_heavy else 0.75


func _on_parried(_direction: Vector2) -> void:
	_parry_flash = 1.0
	_flash = 1.0


func _on_armor_broken() -> void:
	_armor_flash = 1.0
	HitFX.shatter(self, global_position + CENTER)
	if combat.hitbox_component:
		combat.hitbox_component._show_text("ARMOR BREAK!", Color(1.0, 0.6, 0.2))


func _on_armor_absorbed(direction: Vector2) -> void:
	_armor_flash = 1.0
	Sfx.play(&"armor", combat.sfx_db() - 4.0, 0.7)
	HitFX.sparks(self, global_position + CENTER - direction * 8.0, direction, false)


func _process(delta: float) -> void:
	if combat == null or combat.sm == null:
		return
	_time += delta
	var state := combat.get_state()
	var blocking := state == ActionStateMachine.State.BLOCK
	_amount = move_toward(_amount, 1.0 if blocking else 0.0, delta * 10.0)
	if blocking:
		_dir = combat.sm.block_direction()
	_flash = maxf(_flash - delta * 5.0, 0.0)
	_parry_flash = maxf(_parry_flash - delta * 4.0, 0.0)
	_armor_flash = maxf(_armor_flash - delta * 4.0, 0.0)
	_armor_amount = move_toward(_armor_amount, 1.0 if (combat.has_super_armor() and state != ActionStateMachine.State.DEAD) else 0.0, delta * 8.0)
	_tell = _compute_tell(state)

	var show_bar := state != ActionStateMachine.State.DEAD and shield != null \
			and (blocking or shield.is_broken() or _shield_ratio() < 0.999)
	_bar_alpha = move_toward(_bar_alpha, 1.0 if show_bar else 0.0, delta * 5.0)

	visible = _amount > 0.0 or _bar_alpha > 0.0 or _armor_amount > 0.0 or _armor_flash > 0.0 or _tell != TELL_NONE
	queue_redraw()


func _shield_ratio() -> float:
	if shield == null or shield.max_shield_hp <= 0.0:
		return 1.0
	return clampf(shield.shield_hp / shield.max_shield_hp, 0.0, 1.0)


func _draw() -> void:
	var ratio := _shield_ratio()
	if _amount > 0.0:
		var base := COLOR_LOW.lerp(COLOR_FULL, ratio)
		var color := base.lerp(Color(1, 1, 1), _flash)
		var pulse := 0.85 + 0.15 * sin(_time * 12.0)
		color.a = _amount * pulse
		var radius := ARC_RADIUS + 3.0 * _flash - (1.0 - _amount) * 4.0
		var angle := _dir.angle()
		draw_arc(CENTER, radius, angle - ARC_HALF, angle + ARC_HALF, 24, color, (2.0 + 2.5 * _flash) * _amount, true)
		var inner := color
		inner.a *= 0.4
		draw_arc(CENTER, radius - 2.0, angle - ARC_HALF, angle + ARC_HALF, 24, inner, 1.0, true)

	_draw_extras()

	if _bar_alpha > 0.0:
		var broken := shield != null and shield.is_broken()
		var fill := COLOR_LOW.lerp(COLOR_FULL, ratio)
		if broken:
			# Guard broken: flashing red while it recovers.
			fill = COLOR_LOW if fmod(_time, 0.3) < 0.15 else Color(1.0, 0.7, 0.3)
		draw_rect(Rect2(BAR_POS - Vector2.ONE, BAR_SIZE + Vector2(2, 2)), Color(0, 0, 0, 0.65 * _bar_alpha))
		fill.a = _bar_alpha
		draw_rect(Rect2(BAR_POS, Vector2(BAR_SIZE.x * ratio, BAR_SIZE.y)), fill)


# ======================================================================
# Super armor, enemy wind-up warnings, bow charge indicator
# ======================================================================

func _is_bot() -> bool:
	return combat != null and combat.controller is AIComponent


func _is_ranged() -> bool:
	return combat != null and combat.weapon != null and combat.weapon.kind == WeaponData.Kind.RANGED


func _compute_tell(state: ActionStateMachine.State) -> int:
	if state == ActionStateMachine.State.DEAD or combat.weapon == null:
		return TELL_NONE
	if combat.get_skill_cast_ratio() >= 0.0:
		if _is_bot() and not Combat.enemy_tells:
			return TELL_NONE
		return TELL_SKILL_CAST
	var windup := state == ActionStateMachine.State.ATTACK and combat.sm.phase == ActionStateMachine.Phase.STARTUP
	if _is_ranged():
		if state == ActionStateMachine.State.CHARGING:
			if _is_bot() and not Combat.enemy_tells:
				return TELL_NONE
			return TELL_BOW_CHARGE # the draw guide: a guide for you, a warning when a bot is drawing
		if windup and _is_bot() and Combat.enemy_tells:
			return TELL_AIM_WINDUP
		return TELL_NONE
	if not (_is_bot() and Combat.enemy_tells):
		return TELL_NONE # warnings are for bots only: you know what you are about to do
	if windup:
		return TELL_MELEE_WINDUP
	if state == ActionStateMachine.State.CHARGING:
		return TELL_MELEE_CHARGE
	return TELL_NONE


func _draw_extras() -> void:
	# Heavy super armor: a faint steel ring while it is up, a bright pulse when it shrugs a hit off.
	if _armor_amount > 0.0 or _armor_flash > 0.0:
		# The ring is the armor that is left: it shrinks and turns red as light hits wear it down.
		var left := combat.get_armor_ratio()
		var steady := Color(0.85, 0.88, 1.0).lerp(Color(1.0, 0.35, 0.3), 1.0 - left)
		steady.a = (0.35 + 0.15 * sin(_time * 8.0)) * _armor_amount
		if left > 0.0:
			draw_arc(CENTER, 14.0, -PI * 0.5, -PI * 0.5 + TAU * left, 36, steady, 1.5 + 0.5 * left, true)
		if _armor_flash > 0.0:
			draw_arc(CENTER, 14.0 + 4.0 * (1.0 - _armor_flash), 0.0, TAU, 36, Color(1, 1, 1, _armor_flash), 2.5, true)
	match _tell:
		TELL_MELEE_WINDUP:
			_draw_melee_windup()
		TELL_MELEE_CHARGE:
			_draw_melee_charge()
		TELL_BOW_CHARGE, TELL_AIM_WINDUP:
			_draw_bow_guide()
		TELL_SKILL_CAST:
			_draw_skill_cast()


## The area the swing is about to hit, filling in as the wind-up ends.
func _draw_melee_windup() -> void:
	var move := combat.sm.current_move
	if move == null:
		return
	var progress := combat.sm.startup_progress()
	var dir := combat.sm.attack_dir
	var side := dir.orthogonal() * move.width * 0.5
	var near := CENTER
	var far := CENTER + dir * move.reach
	var points := PackedVector2Array([near + side, far + side, far - side, near - side])
	var heavy := combat.sm.current_is_heavy
	var fill := COLOR_TELL
	fill.a = lerpf(0.08, 0.5 if heavy else 0.38, progress)
	draw_colored_polygon(points, fill)
	var edge := COLOR_TELL
	edge.a = lerpf(0.3, 0.95, progress)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), edge, 1.0 + (1.0 if heavy else 0.0))


## A skill cast, shown like a heavy charge: for a bot the closing red ring and blinking "!" of a heavy;
## for you the ring that fills from white to gold, as when drawing a heavy shot, pulsing as the cast ends.
func _draw_skill_cast() -> void:
	var ratio := combat.get_skill_cast_ratio()
	if _is_bot():
		_draw_melee_charge(ratio)
		return
	var color := Color(1, 1, 1).lerp(COLOR_GOLD, ratio)
	color.a = 0.45 + 0.5 * ratio
	if ratio >= 0.85:
		color.a = 0.8 + 0.2 * sin(_time * 16.0)
	draw_arc(CENTER, 13.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 40, color, 2.0, true)


## A heavy being charged: a ring that closes in as it nears full power, and a blinking "!".
func _draw_melee_charge(ratio: float = -1.0) -> void:
	if ratio < 0.0:
		ratio = combat.get_charge_ratio()
	var color := COLOR_TELL
	color.a = 0.55 + 0.3 * sin(_time * (10.0 + 14.0 * ratio))
	draw_arc(CENTER, 11.0 + 9.0 * ratio, 0.0, TAU, 36, color, 1.5 + ratio * 1.5, true)
	if fmod(_time, 0.3) < 0.2:
		draw_string(ThemeDB.fallback_font, Vector2(-4.0, -30.0), "!", HORIZONTAL_ALIGNMENT_CENTER, 8.0, 18, Color(1.0, 0.3, 0.2))


## Aim line and a ring that fills with the draw. Gold for you, red when a bot is drawing at you.
func _draw_bow_guide() -> void:
	var drawing := combat.get_state() == ActionStateMachine.State.CHARGING
	var ratio := combat.get_charge_ratio() if drawing else 1.0
	var dir := combat.get_facing() if drawing else combat.sm.attack_dir
	if dir == Vector2.ZERO:
		return
	var bot := _is_bot()
	var color := (COLOR_TELL if bot else Color(1, 1, 1).lerp(COLOR_GOLD, ratio))
	var full := ratio >= 0.99
	color.a = 0.45 + 0.5 * ratio
	if full:
		color.a = 0.8 + 0.2 * sin(_time * 16.0)
	var length := 30.0 + 110.0 * ratio
	draw_line(CENTER + dir * 10.0, CENTER + dir * length, color, 1.5 if not full else 2.0, true)
	draw_arc(CENTER, 13.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 40, color, 2.0, true)
