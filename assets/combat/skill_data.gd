@tool
extends Resource
class_name SkillData

## One weapon's special skill (the E button). Its balance numbers (damage, cooldown, cast time, reach) are set from
## the table in assets/resources/skills.gd when the weapon loads; this resource holds how the skill works. Belongs to a weapon resource, not to a weapon type,
## so two swords can have different skills. Distances are in pixels; one arena tile is TILE pixels.
##
## `kind` picks the code path in SkillCaster; `tags` describe the skill so the AI can decide when to use it.

enum Kind {SPIN, DASH_STRIKE, VOLLEY, FIREBALL}
enum Tag {DEFENSIVE, DAMAGE, MELEE, RANGED, GAP_CLOSER, AOE}
## NONE = casts on press; DIRECTION = aimed along the aim direction; POINT = aimed at a spot (clamped to max_range).
enum AimMode {NONE, DIRECTION, POINT}

## Pixels per arena tile (the arena tileset uses Godot's default 16 x 16 tiles).
const TILE := 16.0

@export var display_name: String = ""
## HUD icon. Empty = the generic skill icon.
@export var icon: Texture2D
@export var kind: Kind = Kind.SPIN
@export var tags: Array[Tag] = []
@export var aim_mode: AimMode = AimMode.NONE

@export_group("Timing")
## Seconds before the skill can be used again (starts when it is cast).
@export var cooldown: float = 5.0
## Wind-up before the skill takes effect (the fireball is thrown when it ends). The fighter stands still and
## the marker stays up meanwhile, so it doubles as a warning. A stagger during it cancels the skill.
@export var cast_time: float = 0.0
## How long the fighter stays busy after the cast time (spin length, volley length, the fireball throw).
@export var duration: float = 0.3
## Hits during the cast cannot stagger or knock the caster out of it.
@export var unstoppable: bool = false

@export_group("Reach")
## Max reach in pixels: dash length, arrow flight distance, fireball throw distance.
@export var max_range: float = 96.0
## Area radius in pixels: spin circle, fireball blast.
@export var radius: float = 32.0
## Lane width in pixels (dagger dash strike, marker lane).
@export var width: float = 14.0

@export_group("Damage")
## Multiplier on the fighter's power for the main hit (each arrow for the volley).
@export var damage_mult: float = 1.0
@export var reaction: AttackMove.Reaction = AttackMove.Reaction.KNOCKBACK
@export var stagger_time: float = 0.3
@export var knockback_mult: float = 1.0
@export var hitstop: float = 0.06

@export_group("Spin")
## The first part of a spin parries hits (like a fresh block); after it the spin only blocks.
@export var parry_window: float = 0.2
## Walking speed while the skill runs, as a share of normal (1 = full speed). Used by the spin and the volley,
## which let you move. Below 0 = the shared "slowed" speed of blocking and charging (25%).
@export var move_speed_mult: float = -1.0

@export_group("Dash strike")
## Dash speed in pixels per second.
@export var dash_speed: float = 420.0

@export_group("Volley")
@export var volley_count: int = 5
@export var arrows_per_volley: int = 5
## Total fan angle of one volley, in degrees.
@export var spread_deg: float = 40.0
## Seconds between volleys.
@export var volley_interval: float = 0.18

@export_group("Burning ground")
## Damage per second of the burning ground, as a multiplier on power. 0 = no burning ground.
@export var dot_mult_per_sec: float = 0.0
## How long the ground burns, in seconds.
@export var dot_duration: float = 3.0
## Seconds between burn ticks.
@export var dot_tick: float = 0.5
## Stagger each burn tick puts on the fighters standing in the fire (0 = none).
@export var dot_stagger_time: float = 0.0
## Burning ground radius in pixels. 0 = same as `radius`.
@export var dot_radius: float = 0.0

@export_group("AI")
## The AI only uses the skill on a target at least this far away (pixels).
@export var ai_min_range: float = 0.0
## ... and at most this far away. 0 = use `max_range`.
@export var ai_max_range: float = 0.0


func has_tag(tag: Tag) -> bool:
	return tags.has(tag)


## True when the skill is aimed (holding the button shows the marker).
func is_aimed() -> bool:
	return aim_mode != AimMode.NONE


## Burning ground radius (falls back to the blast radius).
func burn_radius() -> float:
	return dot_radius if dot_radius > 0.0 else radius


## Farthest target distance the AI considers.
func ai_reach() -> float:
	return ai_max_range if ai_max_range > 0.0 else max_range
