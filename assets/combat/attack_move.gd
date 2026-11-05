@tool
extends Resource
class_name AttackMove

# One attack in a weapon's moveset. All times are in seconds at attack speed 1.0;
# CombatComponent divides them by the entity's attack speed.

enum Reaction {STAGGER, KNOCKBACK}

@export_group("Timing")
@export var startup: float = 0.10
@export var active: float = 0.10
@export var recovery: float = 0.15

@export_group("Movement")
## Distance the attacker lunges toward the aim during startup.
@export var lunge_distance: float = 10.0

@export_group("Hitbox")
## How far in front of the attacker's centre the hitbox reaches.
@export var reach: float = 18.0
## How far behind the attacker's centre the hitbox starts (covers hugging targets).
@export var back_reach: float = 4.0
@export var width: float = 22.0

@export_group("Damage")
@export var damage_mult: float = 1.0
@export var reaction: Reaction = Reaction.STAGGER
@export var stagger_time: float = 0.2
@export var knockback_mult: float = 1.0
## Real-time seconds of hitstop when this move lands.
@export var hitstop: float = 0.05

@export_group("Visuals")
@export var vfx_animation: StringName = &"slash"
@export var vfx_scale: float = 1.0
