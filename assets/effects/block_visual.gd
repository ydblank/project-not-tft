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


func setup(p_combat: CombatComponent, p_shield: ShieldComponent) -> void:
	combat = p_combat
	shield = p_shield
	z_index = 3
	if combat and combat.hitbox_component:
		combat.hitbox_component.blocked_hit.connect(_on_blocked_hit)


func _on_blocked_hit(_direction: Vector2, is_heavy: bool) -> void:
	_flash = 1.0 if is_heavy else 0.75


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

	var show_bar := state != ActionStateMachine.State.DEAD and shield != null \
			and (blocking or shield.is_broken() or _shield_ratio() < 0.999)
	_bar_alpha = move_toward(_bar_alpha, 1.0 if show_bar else 0.0, delta * 5.0)

	visible = _amount > 0.0 or _bar_alpha > 0.0
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

	if _bar_alpha > 0.0:
		var broken := shield != null and shield.is_broken()
		var fill := COLOR_LOW.lerp(COLOR_FULL, ratio)
		if broken:
			# Guard broken: flashing red while it recovers.
			fill = COLOR_LOW if fmod(_time, 0.3) < 0.15 else Color(1.0, 0.7, 0.3)
		draw_rect(Rect2(BAR_POS - Vector2.ONE, BAR_SIZE + Vector2(2, 2)), Color(0, 0, 0, 0.65 * _bar_alpha))
		fill.a = _bar_alpha
		draw_rect(Rect2(BAR_POS, Vector2(BAR_SIZE.x * ratio, BAR_SIZE.y)), fill)
