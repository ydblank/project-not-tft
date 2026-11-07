extends Node2D
class_name SkillMarker

# Shows where a skill will land: drawn while the skill button is held (aiming) and while a
# spin or a volley runs. Blue when the caster is on the local player's team, red otherwise,
# so an enemy bot aiming a skill doubles as a warning. Owned and updated by SkillCaster;
# coordinates are relative to the caster.
#
#   spin       ring of the spin radius
#   dash       lane along the aim, cut short at the first wall
#   volley     fan of the spread angle out to the arrows' range
#   fireball   faint max-range ring around the caster + blast circle at the aimed spot (it stays up,
#              on the locked spot, during the cast; the cast time itself shows on the fighter, see BlockVisual)

const COLOR_ALLY := Color(0.3, 0.6, 1.0)
const COLOR_ENEMY := Color(1.0, 0.2, 0.15)
const FILL_ALPHA := 0.16
const LINE_ALPHA := 0.75
const RANGE_RING_ALPHA := 0.3
const DASH_SEGMENTS := 48

var skill: SkillData = null
var aim_dir: Vector2 = Vector2.RIGHT
## Aimed spot relative to the caster (point-aimed skills).
var target: Vector2 = Vector2.ZERO
## Dash lane length after walls are taken into account.
var lane_length: float = 0.0
## Shows the max-range ring (while aiming).
var aiming: bool = false
var color: Color = COLOR_ENEMY

var _time: float = 0.0


## Team of the local (human, this machine) player: the first "players" fighter we control.
static func local_team(tree: SceneTree) -> int:
	if tree == null:
		return 0
	for node in tree.get_nodes_in_group("players"):
		if node is Node and (node as Node).is_multiplayer_authority():
			for child in (node as Node).get_children():
				if child is HitboxComponent:
					return (child as HitboxComponent).team
	return 0


## Blue for the local player's side, red for everyone else.
static func color_for_team(tree: SceneTree, team: int) -> Color:
	return COLOR_ALLY if team == local_team(tree) else COLOR_ENEMY


func _ready() -> void:
	z_index = 2 # over the floor and the fighters, like the shrinking zone's tint
	visible = false


func _process(delta: float) -> void:
	_time += delta
	if visible:
		queue_redraw()


func _draw() -> void:
	if skill == null:
		return
	var fill := Color(color, FILL_ALPHA)
	var line := Color(color, LINE_ALPHA)
	var dir := aim_dir.normalized() if aim_dir != Vector2.ZERO else Vector2.RIGHT
	match skill.kind:
		SkillData.Kind.SPIN:
			draw_circle(Vector2.ZERO, skill.radius, fill)
			draw_arc(Vector2.ZERO, skill.radius, 0.0, TAU, 40, line, 1.5)
		SkillData.Kind.DASH_STRIKE:
			var length := lane_length if lane_length > 0.0 else skill.max_range
			var side := dir.orthogonal() * skill.width * 0.5
			var tip := dir * length
			var lane := PackedVector2Array([side, tip + side, tip + dir * skill.width * 0.5, tip - side, -side])
			draw_colored_polygon(lane, fill)
			lane.append(side)
			draw_polyline(lane, line, 1.2)
		SkillData.Kind.VOLLEY:
			var half := deg_to_rad(skill.spread_deg) * 0.5
			var fan := PackedVector2Array([Vector2.ZERO])
			for i in 17:
				fan.append(dir.rotated(lerpf(-half, half, i / 16.0)) * skill.max_range)
			draw_colored_polygon(fan, fill)
			fan.append(Vector2.ZERO)
			draw_polyline(fan, line, 1.2)
		SkillData.Kind.FIREBALL:
			if aiming:
				_draw_dashed_ring(skill.max_range, Color(color, RANGE_RING_ALPHA))
				draw_line(Vector2.ZERO, target, Color(color, RANGE_RING_ALPHA), 1.0)
			var pulse := 1.0 + 0.04 * sin(_time * 8.0)
			draw_circle(target, skill.radius * pulse, fill)
			draw_arc(target, skill.radius * pulse, 0.0, TAU, 40, line, 1.5)
			draw_circle(target, 2.0, line)
	if aiming and skill.kind != SkillData.Kind.FIREBALL and skill.kind != SkillData.Kind.SPIN:
		_draw_dashed_ring(skill.max_range, Color(color, RANGE_RING_ALPHA))


func _draw_dashed_ring(radius: float, ring_color: Color) -> void:
	var step := TAU / DASH_SEGMENTS
	for i in DASH_SEGMENTS:
		if i % 2 == 0:
			draw_arc(Vector2.ZERO, radius, i * step, (i + 1) * step, 3, ring_color, 1.0)
