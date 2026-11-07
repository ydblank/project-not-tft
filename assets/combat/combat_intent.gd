@tool
extends RefCounted
class_name CombatIntent

# What a controller (player input or AI) wants this physics frame.
# Buttons are "held" states; ActionStateMachine does its own edge detection,
# so a press can never be lost between frames.

var move_dir: Vector2 = Vector2.ZERO
var aim_dir: Vector2 = Vector2.DOWN
var attack_held: bool = false
var block_held: bool = false
var dash_held: bool = false
## Skill button (E): hold to aim an aimed skill, release to cast.
var skill_held: bool = false
## World point the skill is aimed at (used by point-aimed skills such as the fireball).
var skill_target: Vector2 = Vector2.ZERO
## Maximum lunge distance for the next attack (AI uses it to keep min distance).
var lunge_limit: float = INF


func clear() -> void:
	move_dir = Vector2.ZERO
	attack_held = false
	block_held = false
	dash_held = false
	skill_held = false
	lunge_limit = INF


func copy_from(other: CombatIntent) -> void:
	move_dir = other.move_dir
	aim_dir = other.aim_dir
	attack_held = other.attack_held
	block_held = other.block_held
	dash_held = other.dash_held
	skill_held = other.skill_held
	skill_target = other.skill_target
	lunge_limit = other.lunge_limit
