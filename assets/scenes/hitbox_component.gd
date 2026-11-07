extends Area2D
class_name HitboxComponent

# The entity's hurtbox and the single place where an incoming hit is resolved:
#   ignore (dead / same team / disabled) -> defense -> block / shield HP
#   -> health -> knockback %-meter -> reaction on the CombatComponent -> feedback.

enum Result {IGNORED, BLOCKED, HIT, PARRIED}

signal hit_received(attacker: Node, damage: float, direction: Vector2)
signal hit_blocked()
## direction: attacker -> us. Used for the block flash and push-back.
signal blocked_hit(direction: Vector2, is_heavy: bool)
## The block was raised just in time: the hit does nothing and the attacker is thrown off balance.
signal parried(direction: Vector2)
## A blocked hit drained the shield: this fighter's guard just broke (CombatText shows the banner).
signal guard_broke(attacker: Node)

@export var team: int = 0
@export var can_be_hit: bool = true
@export var stats: StatsComponent
@export var health: HealthComponent
## Optional shield HP meter. Without one, blocking stops hits completely.
@export var shield: ShieldComponent

@export_group("Team look")
## Tints the entity's sprite by team so the same model reads differently per side.
@export var tint_by_team: bool = true
@export_range(0.0, 1.0) var team_tint_amount: float = 0.7
## Width in pixels of the solid team-coloured outline (0 = none).
@export_range(0.0, 3.0) var team_outline_width: float = 1.0

@export_group("Damage Settings")
@export var use_combat_calculations: bool = true
@export var damage_number_scene: PackedScene
## Used for "BLOCKED" and "GUARD BREAK!" when no damage number scene is set.
const POPUP_SCENE: PackedScene = preload("res://assets/effects/damage_number.tscn")

@export_group("Knockback")
@export var base_knockback_force: float = 220.0
@export var knockback_scale_start: float = 1.0
@export var knockback_scale_gain_per_hit: float = 0.15
@export var knockback_scale_gain_per_damage: float = 0.01
@export var knockback_scale_max: float = 6.0
## Like damage percent in Smash: 0 means it never goes down, only a respawn resets it.
@export var knockback_scale_decay_per_sec: float = 0.0

@export_group("Debug")
@export var debug_hits: bool = false

var knockback_scale: float = 1.0
var _combat: CombatComponent = null


func _ready() -> void:
	if not health:
		health = _find_sibling(HealthComponent) as HealthComponent
	if not shield:
		shield = _find_sibling(ShieldComponent) as ShieldComponent
	knockback_scale = knockback_scale_start
	_apply_team_tint()
	_combat = CombatComponent.find_on(get_entity())
	set_process(knockback_scale_decay_per_sec > 0.0)


func _process(delta: float) -> void:
	knockback_scale = maxf(knockback_scale_start, knockback_scale - knockback_scale_decay_per_sec * delta)


## The character / object this hurtbox belongs to.
func get_entity() -> Node2D:
	if owner is Node2D:
		return owner as Node2D
	return get_parent() as Node2D


func is_same_team(other_team: int) -> bool:
	return team == other_team


func set_team(new_team: int) -> void:
	team = new_team
	_apply_team_tint()


func receive_hit(hit: HitData) -> Result:
	if hit == null or not can_be_hit or health == null or health.is_dead():
		return Result.IGNORED
	if _combat and _combat.is_invulnerable():
		return Result.IGNORED # dash i-frames: melee, arrows and everything else pass through
	if is_same_team(hit.team) or hit.attacker == get_entity():
		return Result.IGNORED
	if _combat and _combat.is_ult_immune():
		return _immune(hit) # the Knight's ultimate: no damage, no stagger, no knockback

	var final_damage := hit.damage
	if use_combat_calculations and stats:
		final_damage = CombatGlobal.calculate_receive_damage(stats, hit.damage)
	if hit.is_dot:
		return _receive_dot(hit, final_damage)

	# Block: direction the hit comes FROM, relative to us. With a shield meter
	# the damage drains it; a hit that breaks it gets the rest through, and the
	# break stun (applied by CombatComponent) replaces the normal reaction.
	var guard_broken := false
	if _combat:
		var from_dir := -hit.direction
		if is_instance_valid(hit.attacker):
			from_dir = hit.attacker.global_position - global_position
		if _combat.is_blocking_from(from_dir):
			# Heavy attacks cannot be parried: they hit the normal block, drain the shield and can break it (stun).
			# A ranged fighter (bow, staff) cannot parry a melee hit either: it is only a normal block for them.
			if _combat.is_parrying() and not hit.is_heavy and (hit.is_ranged or not _combat.is_ranged_fighter()):
				_parry(hit)
				return Result.PARRIED
			if _combat.is_skill_guarding():
				# A sword spin blocks from every side without draining the shield.
				hit_blocked.emit()
				_impact(hit, 0.5, 1.2)
				_spawn_hit_fx(hit, true)
				blocked_hit.emit(hit.direction, hit.is_heavy)
				_show_text("BLOCKED", Color(0.6, 0.85, 1.0))
				return Result.BLOCKED
			if shield:
				final_damage = shield.absorb_damage(final_damage * shield.damage_mult_while_blocking)
				guard_broken = shield.is_broken()
			if not guard_broken or final_damage <= 0.0:
				hit_blocked.emit()
				_impact(hit, 0.5, 1.2)
				_spawn_hit_fx(hit, true)
				blocked_hit.emit(hit.direction, hit.is_heavy)
				_show_text("BLOCKED", Color(0.6, 0.85, 1.0))
				return Result.BLOCKED

	knockback_scale = minf(knockback_scale + knockback_scale_gain_per_hit + final_damage * knockback_scale_gain_per_damage, knockback_scale_max)

	health.take_damage(final_damage)
	hit_received.emit(hit.attacker, final_damage, hit.direction)
	_credit_ultimate(hit)

	var force := 0.0
	if hit.reaction == AttackMove.Reaction.KNOCKBACK:
		force = base_knockback_force * knockback_scale * maxf(hit.knockback_force_mult, 0.0)
	if _combat and not health.is_dead() and not guard_broken:
		_combat.receive_reaction(hit, force, final_damage)

	if debug_hits:
		print("[HIT] ", get_entity().name, " dmg=", snappedf(final_damage, 0.01), " reaction=", hit.reaction, " force=", snappedf(force, 0.1), " scale=", snappedf(knockback_scale, 0.01))

	_show_damage_number(int(round(final_damage)), hit)
	if guard_broken:
		guard_broke.emit(hit.attacker) # the "GUARD BREAK!" text is shown in the middle of the screen by CombatText
	# Heavy hits freeze a touch longer and kick the camera harder.
	var strength := 4.0 if hit.is_heavy else 1.8
	if health.is_dead():
		strength += 3.0
	if guard_broken:
		strength += 2.0
	if hit.is_finisher:
		strength += 3.0
	_impact(hit, 1.0 if hit.is_heavy else (1.3 if hit.is_finisher else 0.7), strength)
	_spawn_hit_fx(hit, false)
	return Result.HIT


## Freeze frame + camera jolt. Only when the player is hitting or being hit.
func _impact(hit: HitData, freeze_scale: float, strength: float) -> void:
	var involved := get_entity()
	var player_involved: bool = (involved != null and involved.is_in_group("players")) \
			or (is_instance_valid(hit.attacker) and hit.attacker.is_in_group("players"))
	if player_involved:
		Combat.hitstop(minf(hit.hitstop * freeze_scale, 0.09 if hit.is_finisher else 0.06))
		Combat.shake(strength, 0.12 + strength * 0.03, hit.direction)


func _show_damage_number(amount: int, hit: HitData = null) -> void:
	if amount <= 0 or not Combat.show_damage_numbers or not is_inside_tree():
		return
	var dn = (damage_number_scene if damage_number_scene else POPUP_SCENE).instantiate()
	get_tree().current_scene.add_child(dn)
	var spawn_pos := global_position + Vector2(randf_range(-6.0, 6.0), -20)
	var marker := get_entity().get_node_or_null("DamageSpawn") if get_entity() else null
	if marker is Node2D:
		spawn_pos = (marker as Node2D).global_position
	var color := _damage_number_color(hit)
	if hit and (hit.is_heavy or hit.is_finisher):
		(dn as Node2D).scale = Vector2(1.35, 1.35)
	if dn.has_method("setup"):
		dn.call("setup", amount, spawn_pos, color)
	else:
		(dn as Node2D).global_position = spawn_pos


func _find_sibling(type: Variant) -> Node:
	var parent := get_parent()
	if parent:
		for child in parent.get_children():
			if is_instance_of(child, type):
				return child
	return null


## Burning ground tick: unblockable, no freeze frame, an orange number; a short stagger (dashable) every tick.
func _receive_dot(hit: HitData, final_damage: float) -> Result:
	health.take_damage(final_damage)
	hit_received.emit(hit.attacker, final_damage, hit.direction)
	_credit_ultimate(hit)
	if _combat and not health.is_dead() and hit.stagger_time > 0.0:
		_combat.receive_reaction(hit, 0.0, final_damage)
	_show_damage_number(maxi(int(round(final_damage)), 1), hit)
	return Result.HIT


## Damage that is not an attack (standing outside the arena, hazards...).
## Skips defense, blocking, knockback and hitstop; still flashes and shows a number.
func apply_environment_damage(amount: float) -> void:
	if amount <= 0.0 or not can_be_hit or health == null or health.is_dead():
		return
	health.take_damage(amount)
	hit_received.emit(null, amount, Vector2.ZERO)
	_show_damage_number(int(round(amount)), null)


# ---- team colour ----

const TEAM_TINT_SHADER := preload("res://assets/effects/team_tint.gdshader")
## Team id -> tint. Teams not listed (e.g. the training dummy) keep their own colours.
const TEAM_TINTS := {
	0: Color(0.25, 0.6, 1.0), # players and allies: blue
	1: Color(1.0, 0.2, 0.2), # enemies: red
	2: Color(0.3, 1.0, 0.4), # second human player: green
}


func _apply_team_tint() -> void:
	var entity := get_entity()
	var sprite := entity.get_node_or_null("Sprite2D") as Sprite2D if entity else null
	if sprite == null:
		return
	if not tint_by_team or not TEAM_TINTS.has(team):
		if sprite.material is ShaderMaterial and (sprite.material as ShaderMaterial).shader == TEAM_TINT_SHADER:
			sprite.material = null
		return
	var mat := sprite.material as ShaderMaterial
	if mat == null or mat.shader != TEAM_TINT_SHADER:
		mat = ShaderMaterial.new()
		mat.shader = TEAM_TINT_SHADER
		sprite.material = mat
	mat.set_shader_parameter("tint", TEAM_TINTS[team])
	mat.set_shader_parameter("amount", team_tint_amount)
	mat.set_shader_parameter("outline_width", team_outline_width)


## Blood on living fighters, sparks on blocks and on things like the dummy.
func _spawn_hit_fx(hit: HitData, blocked: bool) -> void:
	var entity := get_entity()
	var pos := global_position
	if blocked:
		HitFX.sparks(self, pos - hit.direction * 6.0, hit.direction, hit.is_heavy)
		Sfx.play(&"block", _sfx_db(hit) + BLOCK_DB + (ARROW_HIT_DB if hit.is_ranged else 0.0), 1.0 - (0.1 if hit.is_heavy else 0.0))
		return
	var living := entity != null and (entity.is_in_group("players") or entity.is_in_group("enemies") or entity.is_in_group("allies"))
	Sfx.play(&"hit", _sfx_db(hit) + (ARROW_HIT_DB if hit.is_ranged else 0.0), 0.85 if hit.is_heavy else 1.0)
	_maybe_grunt(hit)
	if hit.is_finisher:
		HitFX.finisher(self, pos, hit.direction)
		Sfx.play(&"finisher", _sfx_db(hit) + 3.0, 0.75, 0.03)
	if living:
		HitFX.blood(self, pos, hit.direction, hit.is_heavy or health.is_dead())
	else:
		HitFX.sparks(self, pos, hit.direction, hit.is_heavy)


## Floating word above the fighter, for other components ("DODGE", the ultimate's name).
func show_popup(text: String, color: Color) -> void:
	_show_text(text, color)


## A hit reached our health: the attacker's ultimate meter fills by the hit's points.
## Only fighters of another team count (the training dummy and hazards have no CombatComponent).
func _credit_ultimate(hit: HitData) -> void:
	if hit.charge_points <= 0.0 or not is_instance_valid(hit.attacker):
		return
	var attacker := CombatComponent.find_on(hit.attacker)
	if attacker:
		attacker.on_hit_dealt(hit.charge_points)


## Knight ultimate: the hit does nothing. A clang, sparks and a gold "IMMUNE" instead.
## Not a block, so the attacker is not parried or slowed, and the meter gains nothing.
func _immune(hit: HitData) -> Result:
	if not hit.is_dot:
		_impact(hit, 0.4, 1.0)
		HitFX.sparks(self, global_position - hit.direction * 6.0, hit.direction, hit.is_heavy)
		Sfx.play(&"armor", _sfx_db(hit) + BLOCK_DB, 1.3)
		_show_text("IMMUNE", Color(1.0, 0.85, 0.3))
	return Result.BLOCKED


## Floating word above the fighter ("BLOCKED", "GUARD BREAK!").
func _show_text(text: String, color: Color) -> void:
	if not is_inside_tree():
		return
	var dn = (damage_number_scene if damage_number_scene else POPUP_SCENE).instantiate()
	get_tree().current_scene.add_child(dn)
	var spawn_pos := global_position + Vector2(0, -24)
	if dn.has_method("setup"):
		dn.call("setup", 0, spawn_pos, color, text)


## Sound level of a hit: full when a human-controlled fighter is on either side, quieter for bots only.
func _sfx_db(hit: HitData) -> float:
	var db := -7.0
	var victim := CombatComponent.find_on(get_entity())
	if victim:
		db = maxf(db, victim.sfx_db())
	if is_instance_valid(hit.attacker):
		var attacker := CombatComponent.find_on(hit.attacker)
		if attacker:
			db = maxf(db, attacker.sfx_db())
	return db


## Arrow impacts are played this much quieter (dB) than melee hits.
const ARROW_HIT_DB := -5.0
## Block clangs are played this much quieter (dB); blocking an arrow takes the arrow reduction on top of this.
const BLOCK_DB := -8.0
const GRUNT_CHANCE_LIGHT := 0.3
const GRUNT_CHANCE_HEAVY := 0.8
## A fighter does not grunt again within this many seconds, so a combo does not turn into a chorus.
const GRUNT_COOLDOWN := 0.7


## The fighter who landed the hit sometimes grunts: usually on heavy hits, now and then on quick ones
## (deeper for heavy hits).
func _maybe_grunt(hit: HitData) -> void:
	if not is_instance_valid(hit.attacker) or hit.is_ranged:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(hit.attacker.get_meta("last_grunt", -10.0)) < GRUNT_COOLDOWN:
		return
	if randf() >= (GRUNT_CHANCE_HEAVY if hit.is_heavy else GRUNT_CHANCE_LIGHT):
		return
	hit.attacker.set_meta("last_grunt", now)
	Sfx.play(&"grunt", _sfx_db(hit) - 3.0, 0.8 if hit.is_heavy else 1.0, 0.05)


## Red when a human-controlled fighter takes damage, white when one deals it, grey between bots,
## gold for heavy hits and finishers, orange for the arena\x27s damage over time.
func _damage_number_color(hit: HitData) -> Color:
	if hit == null or hit.is_dot:
		return Color(1.0, 0.6, 0.2)
	var victim := CombatComponent.find_on(get_entity())
	var attacker := CombatComponent.find_on(hit.attacker) if is_instance_valid(hit.attacker) else null
	if hit.is_heavy or hit.is_finisher:
		return Color(1.0, 0.85, 0.3)
	if victim and victim.controller is PlayerController:
		return Color(1.0, 0.4, 0.35)
	if attacker and attacker.controller is PlayerController:
		return Color(1, 1, 1)
	return Color(0.75, 0.75, 0.8)


const PARRY_STUN := 0.7


func _parry(hit: HitData) -> void:
	if _combat:
		_combat.grant_parry_counter()
	parried.emit(hit.direction)
	hit_blocked.emit()
	if not hit.is_ranged and is_instance_valid(hit.attacker):
		var attacker := CombatComponent.find_on(hit.attacker)
		if attacker:
			attacker.apply_parry_stun(PARRY_STUN)
	HitFX.parry(self, global_position - hit.direction * 6.0, hit.direction)
	Sfx.play(&"parry", _sfx_db(hit) + 2.0, 1.5, 0.03)
	_show_text("PARRY!", Color(1.0, 0.85, 0.25))
	_impact(hit, 1.6, 4.5)
