extends Node2D
class_name SkillCaster

# Runs a fighter's weapon skill (SkillData) once ActionStateMachine has started it, and draws
# the AoE marker (SkillMarker) while the skill is aimed or running. CombatComponent creates
# this node, forwards the "skill_started" / "skill_ended" events and calls tick() every
# physics frame after movement. One code path per SkillData.Kind:
#
#   SPIN         hits every enemy in the radius once, cuts down enemy projectiles in it;
#                CombatComponent makes the fighter block (and briefly parry) from all sides
#   DASH_STRIKE  CombatComponent moves the fighter; this stops the dash at the first enemy
#                (which takes the hit), at a wall, or after max_range
#   VOLLEY       volley_count fans of arrows along the live aim; one hit per target per volley
#   FIREBALL     after a cast time (the fireball grows in the caster's hands, marker up), one big
#                fireball that explodes on contact or at the aimed spot and leaves burning ground

const HURTBOX_MASK := 2
const WALL_MASK := 3
## Seconds between whoosh sounds during a spin.
const SPIN_SOUND_INTERVAL := 0.2
## Full turns the fighter makes during one spin (only the facing, for the look).
const SPIN_TURNS := 2.0
## Small extra reach so a projectile touching the spin's edge is cut too.
const SPIN_PROJECTILE_MARGIN := 4.0
## The dash strike looks this far ahead of the fighter's centre for its first target.
const DASH_STRIKE_LOOKAHEAD := 8.0
## Size of the skill fireball (the heavy fireball reaches 1.9 at a full charge).
const FIREBALL_SCALE := 1.6
## A point-aimed skill flies at least this far, so aiming on yourself still throws it.
const MIN_THROW := 16.0
## The fireball held during the cast: its sprite, how far in front of the caster, and its starting size.
const ORB_TEXTURE: Texture2D = preload("res://assets/art/1 Characters/Other/Fireball_Flight.png")
const ORB_OFFSET := 9.0
const ORB_START_SCALE := 0.3

var combat: CombatComponent
var marker: SkillMarker

var _skill: SkillData = null
var _dir: Vector2 = Vector2.RIGHT
var _elapsed: float = 0.0
## Cast time of the running skill (shortened by the Mage's ultimate), read from the state machine at the cast.
var _cast_time: float = 0.0
var _hit_targets: Dictionary = {}
var _sound_left: float = 0.0
var _volleys_fired: int = 0
var _volley_left: float = 0.0
var _dash_from: Vector2 = Vector2.ZERO
var _marker_was_visible: bool = false
## Fireball cast: the spot locked in when the button was released, and whether it has been thrown yet.
var _cast_target: Vector2 = Vector2.ZERO
var _thrown: bool = false
## The fireball growing in the caster's hands during the cast.
var _orb: Sprite2D = null
## The Whirlwind's spinning swoosh (SpinSlash).
var _spin_fx: SpinSlash = null


func setup(p_combat: CombatComponent) -> void:
	combat = p_combat
	name = "SkillCaster"
	add_to_group("danger_zones") # bots step out of an enemy skill that is being aimed or cast at them
	marker = SkillMarker.new()
	marker.name = "SkillMarker"
	add_child(marker)


## True while a skill is running.
func is_running() -> bool:
	return _skill != null


## 0..1 through a skill's cast time (the fireball growing in the caster's hands), -1 when not casting.
func cast_ratio() -> float:
	if _skill == null or _cast_time <= 0.0 or _thrown or _skill.kind != SkillData.Kind.FIREBALL:
		return -1.0
	return clampf(_elapsed / _cast_time, 0.0, 1.0)


func start(e: Dictionary) -> void:
	_skill = e.skill
	_dir = (e.dir as Vector2).normalized() if e.dir != Vector2.ZERO else Vector2.RIGHT
	_elapsed = 0.0
	_cast_time = combat.sm.skill_cast_time() if combat.sm.state == ActionStateMachine.State.SKILL else _skill.cast_time
	_hit_targets.clear()
	_sound_left = 0.0
	_volleys_fired = 0
	_volley_left = 0.0
	_dash_from = combat.entity.global_position
	match _skill.kind:
		SkillData.Kind.SPIN:
			Sfx.play(&"swing_heavy", combat.sfx_db() - 6.0, 0.8)
			_spin_fx = SpinSlash.spawn(combat.entity.get_parent(), combat.entity, _skill.radius, _skill.duration, SPIN_TURNS, _dir.angle())
		SkillData.Kind.DASH_STRIKE:
			Sfx.play(&"dash", combat.sfx_db(), 1.15, 0.05)
			Sfx.play(&"swing_light", combat.sfx_db() - 6.0, 0.9)
		SkillData.Kind.VOLLEY:
			_fire_volley(_dir)
		SkillData.Kind.FIREBALL:
			_cast_target = e.target
			_thrown = false
			if _cast_time <= 0.0:
				_throw_now()
			else:
				_start_orb()
				Sfx.play(&"swing_heavy", combat.sfx_db() - 10.0, 0.55)


func stop() -> void:
	_skill = null
	if is_instance_valid(_spin_fx):
		_spin_fx.finish() # fades out (also when the spin was cut short)
	_spin_fx = null
	if is_instance_valid(_orb):
		_orb.queue_free()
	_orb = null


## Called every physics frame (after the fighter has moved).
func tick(intent: CombatIntent, delta: float) -> void:
	var sm := combat.sm
	if _skill != null and sm.state != ActionStateMachine.State.SKILL:
		stop() # interrupted (parry stun, death, loadout change)
	if _skill != null:
		_elapsed += delta
		match _skill.kind:
			SkillData.Kind.SPIN:
				_tick_spin(delta)
			SkillData.Kind.DASH_STRIKE:
				_tick_dash_strike()
			SkillData.Kind.VOLLEY:
				_tick_volley(intent, delta)
			SkillData.Kind.FIREBALL:
				_tick_fireball_cast()
	_update_marker(intent)


# ======================================================================
# Spin
# ======================================================================

func _tick_spin(delta: float) -> void:
	var entity := combat.entity
	# The fighter turns with the swoosh (SpinSlash draws the sweep itself).
	var angle := _spin_fx.head_angle() if is_instance_valid(_spin_fx) else _dir.angle() + _elapsed / maxf(_skill.duration, 0.01) * TAU * SPIN_TURNS
	combat.sm.facing = Vector2.from_angle(angle)
	_sound_left -= delta
	if _sound_left <= 0.0:
		_sound_left += SPIN_SOUND_INTERVAL
		Sfx.play(&"swing_light", combat.sfx_db() - 8.0, 0.8 + randf() * 0.1)
	for hurtbox in _hurtboxes_in_circle(entity.global_position, _skill.radius):
		_strike(hurtbox, hurtbox.global_position - entity.global_position)
	_cut_projectiles(entity.global_position, _skill.radius + SPIN_PROJECTILE_MARGIN)


func _cut_projectiles(center: Vector2, radius: float) -> void:
	var team := combat.get_team()
	for node in get_tree().get_nodes_in_group("projectiles"):
		var projectile := node as ArrowProjectile
		if projectile == null or projectile.get_team() == team:
			continue
		if projectile.global_position.distance_to(center) <= radius:
			projectile.shatter()


# ======================================================================
# Dash strike
# ======================================================================

func _tick_dash_strike() -> void:
	var entity := combat.entity
	var ahead := entity.global_position + _dir * DASH_STRIKE_LOOKAHEAD
	for hurtbox in _hurtboxes_in_circle(ahead, _skill.width):
		if _strike(hurtbox, _dir):
			combat.sm.finish_skill() # stops at the first enemy hit
			return
	if entity.global_position.distance_to(_dash_from) >= _skill.max_range:
		combat.sm.finish_skill()
		return
	for i in entity.get_slide_collision_count():
		var collider := entity.get_slide_collision(i).get_collider()
		if not (collider is CharacterBody2D):
			combat.sm.finish_skill() # ran into a wall
			return


# ======================================================================
# Volley
# ======================================================================

func _tick_volley(intent: CombatIntent, delta: float) -> void:
	if _volleys_fired >= _skill.volley_count:
		return
	var aim := intent.aim_dir.normalized() if intent != null and intent.aim_dir != Vector2.ZERO else _dir
	combat.sm.facing = aim
	_volley_left -= delta
	if _volley_left <= 0.0:
		_fire_volley(aim)


func _fire_volley(aim: Vector2) -> void:
	_volleys_fired += 1
	_volley_left = _skill.volley_interval
	var weapon := combat.weapon
	if weapon == null or weapon.projectile_scene == null:
		return
	var entity := combat.entity
	var shared := {} # one hit per fighter per volley
	var count := maxi(_skill.arrows_per_volley, 1)
	var half := deg_to_rad(_skill.spread_deg) * 0.5
	for i in count:
		var t := 0.5 if count == 1 else float(i) / float(count - 1)
		var dir := aim.rotated(lerpf(-half, half, t))
		var arrow := weapon.projectile_scene.instantiate() as ArrowProjectile
		if arrow == null:
			return
		arrow.setup(combat.build_skill_hit(_skill, dir), entity)
		arrow.max_distance = _skill.max_range
		arrow.shared_hits = shared
		entity.get_parent().add_child(arrow)
		arrow.global_position = entity.global_position
		arrow.rotation = dir.angle()
	Sfx.play(&"bow_release", combat.sfx_db() - 12.0, 1.1 + randf() * 0.1)


# ======================================================================
# Fireball
# ======================================================================

## During the cast the fireball grows in front of the caster; when the cast time is up it is thrown.
func _tick_fireball_cast() -> void:
	if _thrown:
		return
	combat.sm.facing = _dir
	var progress := clampf(_elapsed / maxf(_cast_time, 0.01), 0.0, 1.0)
	if is_instance_valid(_orb):
		_orb.global_position = combat.entity.global_position + _dir * ORB_OFFSET
		_orb.rotation = _dir.angle()
		_orb.scale = Vector2.ONE * lerpf(ORB_START_SCALE, FIREBALL_SCALE, progress)
		_orb.frame = int(_elapsed * 14.0) % _orb.hframes
	if _elapsed >= _cast_time:
		_throw_now()


func _throw_now() -> void:
	_thrown = true
	if is_instance_valid(_orb):
		_orb.queue_free()
	_orb = null
	_throw_fireball(_cast_target)


func _start_orb() -> void:
	_orb = Sprite2D.new()
	_orb.texture = ORB_TEXTURE
	_orb.hframes = 4
	_orb.offset = Vector2(-8, 0)
	_orb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_orb.z_index = 4
	_orb.scale = Vector2.ONE * ORB_START_SCALE
	combat.entity.get_parent().add_child(_orb)
	_orb.global_position = combat.entity.global_position + _dir * ORB_OFFSET


func _throw_fireball(target: Vector2) -> void:
	var weapon := combat.weapon
	if weapon == null or weapon.projectile_scene == null:
		return
	var entity := combat.entity
	var offset := clamp_target(target)
	var dir := offset.normalized() if offset.length() > 1.0 else _dir
	var fireball := weapon.projectile_scene.instantiate() as FireballProjectile
	if fireball == null:
		push_warning("SkillCaster: the fireball skill needs a weapon that fires FireballProjectile")
		return
	var hit := combat.build_skill_hit(_skill, dir)
	hit.is_heavy = true # a big spell: cannot be parried, explodes like a held fireball
	fireball.setup(hit, entity, 1.0)
	fireball.explodes = true
	fireball.scale = Vector2.ONE * FIREBALL_SCALE
	fireball.radius_override = _skill.radius
	fireball.max_distance = maxf(offset.length(), MIN_THROW)
	fireball.burn_skill = _skill
	fireball.burn_damage_per_tick = combat.skill_power() * _skill.dot_mult_per_sec * _skill.dot_tick
	entity.get_parent().add_child(fireball)
	fireball.global_position = entity.global_position
	fireball.rotation = dir.angle()
	Sfx.play(&"swing_heavy", combat.sfx_db() - 8.0, 0.7)


## Aimed spot relative to the fighter, pulled in to the skill's max range.
func clamp_target(world_target: Vector2) -> Vector2:
	var skill := _skill if _skill != null else combat.sm.get_skill()
	var offset := world_target - combat.entity.global_position
	if not offset.is_finite():
		offset = Vector2.ZERO
	if skill != null:
		offset = offset.limit_length(skill.max_range)
	return offset


# ======================================================================
# Shared
# ======================================================================

## Hits one enemy hurtbox (once per skill). Returns true when the hit landed (not ignored).
func _strike(hurtbox: HitboxComponent, toward: Vector2) -> bool:
	var target := hurtbox.get_entity()
	if target == null or target == combat.entity or _hit_targets.has(target.get_instance_id()):
		return false
	if combat.hitbox_component and hurtbox.is_same_team(combat.hitbox_component.team):
		return false
	if hurtbox.health != null and hurtbox.health.is_dead():
		return false
	var result := hurtbox.receive_hit(combat.build_skill_hit(_skill, toward))
	if result == HitboxComponent.Result.IGNORED:
		return false
	_hit_targets[target.get_instance_id()] = true
	combat.hit_landed.emit(target, result)
	return true


func _hurtboxes_in_circle(center: Vector2, radius: float) -> Array[HitboxComponent]:
	var out: Array[HitboxComponent] = []
	var circle := CircleShape2D.new()
	circle.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, center)
	query.collision_mask = HURTBOX_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for result in combat.entity.get_world_2d().direct_space_state.intersect_shape(query, 32):
		var hurtbox := result.collider as HitboxComponent
		if hurtbox != null and hurtbox != combat.hitbox_component:
			out.append(hurtbox)
	return out


## Distance along `dir` before the first wall (fighters are skipped), up to `max_length`.
func _distance_to_wall(dir: Vector2, max_length: float) -> float:
	var from := combat.entity.global_position
	var query := PhysicsRayQueryParameters2D.create(from, from + dir * max_length, WALL_MASK)
	var excluded: Array[RID] = []
	for i in 6:
		query.exclude = excluded
		var result := combat.entity.get_world_2d().direct_space_state.intersect_ray(query)
		if result.is_empty():
			break
		if result.collider is CharacterBody2D:
			excluded.append(result.rid)
			continue
		return from.distance_to(result.position)
	return max_length


func _update_marker(intent: CombatIntent) -> void:
	if marker == null:
		return
	var sm := combat.sm
	var aiming := sm.state == ActionStateMachine.State.SKILL_AIM
	var casting := _skill != null and _skill.kind == SkillData.Kind.FIREBALL and not _thrown
	var running := _skill != null and (_skill.kind == SkillData.Kind.SPIN or _skill.kind == SkillData.Kind.VOLLEY or casting)
	var show := aiming or running
	marker.visible = show
	if not show:
		_marker_was_visible = false
		return
	if not _marker_was_visible:
		marker.color = SkillMarker.color_for_team(get_tree(), combat.get_team())
		_marker_was_visible = true
	marker.global_position = combat.entity.global_position
	marker.skill = _skill if running else sm.get_skill()
	marker.aiming = aiming
	var aim := intent.aim_dir if intent != null and intent.aim_dir != Vector2.ZERO else sm.facing
	marker.aim_dir = aim.normalized()
	if marker.skill == null:
		return
	match marker.skill.kind:
		SkillData.Kind.FIREBALL:
			if casting:
				marker.target = clamp_target(_cast_target) # locked in at the release
			else:
				marker.target = clamp_target(intent.skill_target) if intent != null else aim * marker.skill.max_range
		SkillData.Kind.DASH_STRIKE:
			marker.lane_length = _distance_to_wall(marker.aim_dir, marker.skill.max_range)


# ======================================================================
# Danger zone (read by AIComponent: bots step out of an enemy skill's marked area)
# ======================================================================

## True when `point` is inside the area this skill is about to hit (while it is aimed or running)
## and a fighter of `for_team` would be hurt there.
func danger_at(point: Vector2, for_team: int) -> bool:
	if marker == null or not marker.visible or marker.skill == null or for_team == combat.get_team():
		return false
	var local := point - marker.global_position
	var skill := marker.skill
	var dir := marker.aim_dir
	match skill.kind:
		SkillData.Kind.SPIN:
			return local.length() <= skill.radius
		SkillData.Kind.FIREBALL:
			return local.distance_to(marker.target) <= skill.radius
		SkillData.Kind.VOLLEY:
			return local.length() <= skill.max_range and absf(dir.angle_to(local)) <= deg_to_rad(skill.spread_deg) * 0.5
		SkillData.Kind.DASH_STRIKE:
			var along := local.dot(dir)
			var length := marker.lane_length if marker.lane_length > 0.0 else skill.max_range
			return along >= 0.0 and along <= length and absf(local.dot(dir.orthogonal())) <= skill.width
	return false


## Way out of the danger from `point` (unit vector): away from a circle's centre, sideways out of
## a fan or a lane.
func danger_escape(point: Vector2) -> Vector2:
	if marker == null or marker.skill == null:
		return Vector2.ZERO
	var local := point - marker.global_position
	match marker.skill.kind:
		SkillData.Kind.SPIN:
			return local.normalized() if local.length() > 0.5 else marker.aim_dir.orthogonal()
		SkillData.Kind.FIREBALL:
			var off := local - marker.target
			return off.normalized() if off.length() > 0.5 else marker.aim_dir.orthogonal()
	var side := marker.aim_dir.orthogonal()
	return side if local.dot(side) >= 0.0 else -side


## True for areas that are about to be hit (a dash out is worth it), as opposed to lingering fire.
func danger_is_incoming() -> bool:
	return true
