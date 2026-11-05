extends Node2D
class_name CombatComponent

# The single owner of an entity's combat state, facing and velocity.
#
# Each physics frame:
#   1. read the controller's CombatIntent (PlayerController or AIComponent)
#   2. tick the ActionStateMachine (pure logic)
#   3. apply its events: VFX / projectiles, hitbox window
#   4. compute velocity for the current movement mode -> MovementComponent.drive()
#   5. while the attack is ACTIVE, resolve melee overlaps into HitData
#
# Incoming hits arrive through the entity's HitboxComponent, which calls
# receive_reaction() after damage has been applied.

signal state_changed(from: ActionStateMachine.State, to: ActionStateMachine.State)
signal attack_started(move: AttackMove, is_heavy: bool)
signal hit_landed(target: Node2D, result: int)

const SLASH_VFX: PackedScene = preload("res://assets/effects/slash.tscn")
const HURTBOX_LAYER := 2
const KNOCKBACK_FRICTION := 1000.0
const KNOCKBACK_DURATION := 0.25

@export var entity: CharacterBody2D
@export var controller: Node
@export var stats_component: StatsComponent
@export var movement_component: MovementComponent
@export var health_component: HealthComponent
@export var hitbox_component: HitboxComponent
@export_range(0.0, 1.0) var slowed_speed_mult: float = 0.25

var sm: ActionStateMachine
var weapon: WeaponData

var _attack_hitbox: Area2D
var _attack_shape: CollisionShape2D
var _hit_targets: Dictionary = {}
var _current_hit_mult: float = 1.0
var _knockback_velocity: Vector2 = Vector2.ZERO
var _neutral_intent := CombatIntent.new()
var _last_state: ActionStateMachine.State = ActionStateMachine.State.IDLE


func _ready() -> void:
	if entity == null:
		entity = owner as CharacterBody2D
	weapon = stats_component.get_weapon_data() if stats_component else null
	sm = ActionStateMachine.new(weapon, CombatGlobal.calculate_attack_speed(stats_component))
	if stats_component:
		sm.dash_duration = stats_component.dash_duration
		sm.dash_cooldown = stats_component.dash_cooldown
	_build_attack_hitbox()
	if health_component:
		health_component.died.connect(_on_died)


# ======================================================================
# Frame loop
# ======================================================================

func _physics_process(delta: float) -> void:
	if entity == null or sm == null:
		return

	var intent := _get_intent()
	var events := sm.tick(intent, delta)
	for e in events:
		_handle_event(e)
	_emit_state_change()

	var velocity := _compute_velocity(intent, delta)
	if movement_component:
		movement_component.drive(velocity)

	if sm.state == ActionStateMachine.State.ATTACK and sm.phase == ActionStateMachine.Phase.ACTIVE:
		_resolve_melee_hits()


func _get_intent() -> CombatIntent:
	if controller and "intent" in controller and controller.intent is CombatIntent:
		return controller.intent
	return _neutral_intent


func _handle_event(e: Dictionary) -> void:
	match e.type:
		"attack_started":
			_on_attack_started(e)
		"active_started":
			_resolve_melee_hits()
		"active_ended":
			pass


func _emit_state_change() -> void:
	if sm.state != _last_state:
		var from := _last_state
		_last_state = sm.state
		if sm.state != ActionStateMachine.State.KNOCKBACK:
			_knockback_velocity = Vector2.ZERO
		state_changed.emit(from, sm.state)


# ======================================================================
# Movement
# ======================================================================

func _compute_velocity(intent: CombatIntent, delta: float) -> Vector2:
	var move_speed := movement_component.move_speed if movement_component else 100.0
	match sm.movement_mode():
		ActionStateMachine.MoveMode.FREE:
			return intent.move_dir.limit_length(1.0) * move_speed
		ActionStateMachine.MoveMode.SLOWED:
			return intent.move_dir.limit_length(1.0) * move_speed * slowed_speed_mult
		ActionStateMachine.MoveMode.LUNGE:
			return sm.lunge_velocity()
		ActionStateMachine.MoveMode.DASH:
			var dash_speed := movement_component.dash_speed if movement_component else 300.0
			return sm.dash_dir * dash_speed
		ActionStateMachine.MoveMode.KNOCKBACK:
			_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta)
			return _knockback_velocity
	return Vector2.ZERO


# ======================================================================
# Attacking
# ======================================================================

func _on_attack_started(e: Dictionary) -> void:
	var move: AttackMove = e.move
	var dir: Vector2 = e.dir
	_hit_targets.clear()
	_current_hit_mult = e.charge_mult

	if weapon and weapon.kind == WeaponData.Kind.RANGED:
		_spawn_projectile(move, dir, e.charge_mult)
	else:
		_place_attack_hitbox(move, dir)
		_spawn_slash_vfx(move, dir, e.is_heavy)

	attack_started.emit(move, e.is_heavy)


func _build_attack_hitbox() -> void:
	_attack_hitbox = Area2D.new()
	_attack_hitbox.name = "AttackHitbox"
	_attack_hitbox.collision_layer = 0
	_attack_hitbox.collision_mask = HURTBOX_LAYER
	_attack_hitbox.monitorable = false
	_attack_hitbox.monitoring = true
	_attack_shape = CollisionShape2D.new()
	_attack_shape.shape = RectangleShape2D.new()
	_attack_hitbox.add_child(_attack_shape)
	add_child(_attack_hitbox)


## Rectangle from -back_reach to +reach along dir, centred on the entity.
func _place_attack_hitbox(move: AttackMove, dir: Vector2) -> void:
	var length := move.reach + move.back_reach
	(_attack_shape.shape as RectangleShape2D).size = Vector2(length, move.width)
	_attack_shape.position = Vector2((move.reach - move.back_reach) * 0.5, 0.0)
	_attack_hitbox.global_position = entity.global_position
	_attack_hitbox.global_rotation = dir.angle()


func _resolve_melee_hits() -> void:
	if sm.current_move == null or (weapon and weapon.kind == WeaponData.Kind.RANGED):
		return
	# Follow the attacker during the lunge so the hitbox stays attached.
	_attack_hitbox.global_position = entity.global_position
	for area in _attack_hitbox.get_overlapping_areas():
		var target_hurtbox := area as HitboxComponent
		if target_hurtbox == null or target_hurtbox == hitbox_component:
			continue
		var target := target_hurtbox.get_entity()
		if target == null or target == entity or _hit_targets.has(target.get_instance_id()):
			continue
		if hitbox_component and target_hurtbox.is_same_team(hitbox_component.team):
			continue
		_hit_targets[target.get_instance_id()] = true
		var hit := build_hit(sm.current_move, (target.global_position - entity.global_position), _current_hit_mult)
		var result := target_hurtbox.receive_hit(hit)
		hit_landed.emit(target, result)


## Builds the HitData for one move. Also used by projectiles.
func build_hit(move: AttackMove, toward_target: Vector2, charge_mult: float) -> HitData:
	var hit := HitData.new()
	hit.attacker = entity
	hit.team = hitbox_component.team if hitbox_component else -1
	hit.damage = maxf(CombatGlobal.calculate_attack_damage(stats_component) * move.damage_mult * charge_mult, 1.0)
	hit.direction = toward_target.normalized() if toward_target != Vector2.ZERO else sm.attack_dir
	hit.reaction = move.reaction
	hit.stagger_time = move.stagger_time
	hit.knockback_force_mult = move.knockback_mult * charge_mult
	hit.hitstop = move.hitstop
	return hit


func _spawn_slash_vfx(move: AttackMove, dir: Vector2, is_heavy: bool) -> void:
	var fx := SLASH_VFX.instantiate()
	entity.get_parent().add_child(fx)
	fx.global_position = entity.global_position
	fx.play(move.vfx_animation, dir.angle(), move.vfx_scale, is_heavy)


func _spawn_projectile(move: AttackMove, dir: Vector2, charge_mult: float) -> void:
	if weapon.projectile_scene == null:
		return
	var projectile := weapon.projectile_scene.instantiate() as ArrowProjectile
	if projectile == null:
		push_error("CombatComponent: projectile_scene must be an ArrowProjectile")
		return
	projectile.setup(build_hit(move, dir, charge_mult), entity)
	entity.get_parent().add_child(projectile)
	projectile.global_position = entity.global_position
	projectile.rotation = dir.angle()


# ======================================================================
# Receiving hits (called by HitboxComponent after damage is applied)
# ======================================================================

func receive_reaction(hit: HitData, knockback_force: float) -> void:
	if sm.state == ActionStateMachine.State.DEAD:
		return
	if hit.reaction == AttackMove.Reaction.KNOCKBACK and knockback_force > 0.0:
		sm.apply_knockback(KNOCKBACK_DURATION)
		_emit_state_change()
		_knockback_velocity = hit.direction.normalized() * knockback_force
	else:
		sm.apply_stagger(hit.stagger_time)
		_emit_state_change()


func is_blocking_from(from_dir: Vector2) -> bool:
	return sm != null and sm.is_blocking_from(from_dir)


func _on_died() -> void:
	sm.kill()
	_emit_state_change()


# ======================================================================
# Queries for animation / AI
# ======================================================================

func get_state() -> ActionStateMachine.State:
	return sm.state if sm else ActionStateMachine.State.IDLE


func get_phase() -> ActionStateMachine.Phase:
	return sm.phase if sm else ActionStateMachine.Phase.NONE


func get_facing() -> Vector2:
	return sm.facing if sm else Vector2.DOWN


func get_charge_ratio() -> float:
	return sm.charge_ratio() if sm else 0.0


func is_attacking() -> bool:
	return get_state() == ActionStateMachine.State.ATTACK


## Total reach of the next light move including its lunge (used by AI).
func get_threat_range() -> float:
	if weapon == null:
		return 0.0
	if weapon.kind == WeaponData.Kind.RANGED:
		return weapon.ai_engage_range
	var move := weapon.get_light_move(0)
	return (move.reach + move.lunge_distance) if move else 0.0


static func find_on(node: Node) -> CombatComponent:
	if node == null:
		return null
	for child in node.get_children():
		if child is CombatComponent:
			return child
		for grandchild in child.get_children():
			if grandchild is CombatComponent:
				return grandchild
	return null
