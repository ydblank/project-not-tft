extends Control
class_name UltimateBar

# Thin ultimate meter under a fighter's HUD health bar (GAM-23). Created by HealthBarComponent
# for any fighter whose class has an ultimate, so the enemy's meter shows on their bar too.
#   filling: dark red, brighter at the leading edge
#   full:    pulsing red (in step with the aura)
#   active:  the ultimate's colour, emptying over its duration

const HEIGHT := 4.0
const GAP := 2.0
const COLOR_BG := Color(0, 0, 0, 0.55)
const COLOR_FILL := Color(0.75, 0.1, 0.08)
const COLOR_FULL := Color(1.0, 0.25, 0.2)

var combat: CombatComponent


func setup(p_combat: CombatComponent, below: Control) -> void:
	combat = p_combat
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(0, below.size.y + GAP)
	size = Vector2(below.size.x, HEIGHT)


func _process(_delta: float) -> void:
	visible = is_instance_valid(combat) and combat.has_ultimate()
	if visible:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)
	var ratio := combat.get_ult_charge()
	var color := COLOR_FILL
	if combat.is_ult_active():
		ratio = combat.get_ult_time_ratio()
		color = combat.get_ult_color()
	elif combat.is_ult_ready():
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * UltimateAura.READY_PULSE)
		color = COLOR_FULL.lerp(Color(1, 0.8, 0.7), 0.35 * pulse)
	if ratio > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * ratio, size.y)), color)
