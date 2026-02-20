extends Node2D
class_name AnimationComponent

# Optional component references - AnimationComponent works independently
# but can use these if provided for better integration
@export var movement_component: MovementComponent
@export var attack_component: AttackComponent

@export var animation_player_path: NodePath = NodePath("../AnimationPlayer")
@export var animation_tree_path: NodePath = NodePath("../AnimationTree")
@export var sprite_path: NodePath = NodePath("../Sprite2D")

@export_group("Animation States")
@export var idle_state_name: String = "Idle"
@export var walk_state_name: String = "Walk"
@export var attack_state_name: String = "Attack"

@export_group("Settings")
@export var auto_update: bool = true
@export var update_on_physics: bool = true

var animation_player: AnimationPlayer
var animation_tree: AnimationTree
var sprite: Sprite2D
var state_machine: AnimationNodeStateMachinePlayback

var current_direction: Vector2 = Vector2.DOWN

@onready var entity: Node = get_parent()

func _ready() -> void:
	if not entity:
		push_error("AnimationComponent: Must have a parent entity")
		return
	
	_initialize_animation_nodes()
	
	if update_on_physics:
		set_physics_process(true)
	else:
		set_process(true)

func _initialize_animation_nodes() -> void:
	if has_node(animation_player_path):
		animation_player = get_node(animation_player_path) as AnimationPlayer
	else:
		push_warning("AnimationComponent: AnimationPlayer not found at path: ", animation_player_path)
	
	if has_node(animation_tree_path):
		animation_tree = get_node(animation_tree_path) as AnimationTree
		if animation_tree:
			state_machine = animation_tree.get("parameters/playback")
			if not state_machine:
				push_warning("AnimationComponent: Could not get state machine from AnimationTree")
	else:
		push_warning("AnimationComponent: AnimationTree not found at path: ", animation_tree_path)
	
	if has_node(sprite_path):
		sprite = get_node(sprite_path) as Sprite2D
	else:
		push_warning("AnimationComponent: Sprite2D not found at path: ", sprite_path)

func _physics_process(_delta: float) -> void:
	if not update_on_physics or not auto_update:
		return
	update_animation()

func _process(_delta: float) -> void:
	if update_on_physics or not auto_update:
		return
	update_animation()

func update_animation() -> void:
	#if not _is_authority():
		#return
	
	var animation_direction := _get_animation_direction()
	update_animation_parameters(animation_direction)
	pick_new_state()

func update_animation_parameters(dir: Vector2) -> void:
	if not animation_tree:
		return
	
	var normalized_dir := dir.normalized() if dir != Vector2.ZERO else current_direction
	current_direction = normalized_dir
	
	animation_tree.set("parameters/" + idle_state_name + "/blend_position", normalized_dir)
	animation_tree.set("parameters/" + walk_state_name + "/blend_position", normalized_dir)
	animation_tree.set("parameters/" + attack_state_name + "/blend_position", normalized_dir)

func pick_new_state() -> void:
	if not state_machine:
		return
	
	var attack_state := _get_attack_state()
	var is_moving := _is_entity_moving()
	
	if attack_state == AttackComponent.AttackState.IDLE:
		if is_moving:
			state_machine.travel(walk_state_name)
		else:
			state_machine.travel(idle_state_name)
	
	elif attack_state == AttackComponent.AttackState.STARTUP or attack_state == AttackComponent.AttackState.ACTIVE:
		state_machine.travel(attack_state_name)
	
	elif attack_state == AttackComponent.AttackState.RECOVERY or attack_state == AttackComponent.AttackState.COMBO_WINDOW:
		if is_moving:
			state_machine.travel(walk_state_name)
		else:
			state_machine.travel(idle_state_name)

func force_state(state_name: String) -> void:
	if state_machine:
		state_machine.travel(state_name)

func set_blend_position(state_name: String, blend_pos: Vector2) -> void:
	if animation_tree:
		animation_tree.set("parameters/" + state_name + "/blend_position", blend_pos)

func play_animation(animation_name: String) -> void:
	if animation_player:
		animation_player.play(animation_name)

func stop_animation() -> void:
	if animation_player:
		animation_player.stop()

func get_current_animation() -> String:
	if animation_player:
		return animation_player.current_animation
	return ""

func is_playing() -> bool:
	if animation_player:
		return animation_player.is_playing()
	return false

func get_sprite() -> Sprite2D:
	return sprite

func set_sprite_texture(texture: Texture2D) -> void:
	if sprite:
		sprite.texture = texture

func set_sprite_modulate(color: Color) -> void:
	if sprite:
		sprite.self_modulate = color

func set_sprite_position(pos: Vector2) -> void:
	if sprite:
		sprite.position = pos

func reset_sprite_visuals() -> void:
	if sprite:
		sprite.position = Vector2.ZERO
		sprite.self_modulate = Color(1, 1, 1, 1)

func _get_animation_direction() -> Vector2:
	var is_attacking := _is_attacking()
	var velocity := _get_entity_velocity()
	var facing_dir := _get_facing_direction()
	
	if is_attacking:
		return facing_dir
	elif velocity != Vector2.ZERO:
		return velocity.normalized()
	else:
		return facing_dir

func _get_attack_state() -> AttackComponent.AttackState:
	if attack_component and attack_component.has_method("get_attack_state"):
		return attack_component.get_attack_state()
	return AttackComponent.AttackState.IDLE

func _is_attacking() -> bool:
	return _get_attack_state() != AttackComponent.AttackState.IDLE

func _is_entity_moving() -> bool:
	if movement_component:
		if movement_component.has_method("is_moving"):
			return movement_component.is_moving()
		return movement_component.velocity.length() > 0.0
	
	if entity is CharacterBody2D:
		return (entity as CharacterBody2D).velocity.length() > 0.0
	
	return false

func _get_entity_velocity() -> Vector2:
	if movement_component:
		if movement_component.has_method("get_velocity"):
			return movement_component.get_velocity()
		return movement_component.velocity
	
	if entity is CharacterBody2D:
		return (entity as CharacterBody2D).velocity
	
	return Vector2.ZERO

func _get_facing_direction() -> Vector2:
	if movement_component:
		return movement_component.facing_direction
	
	if entity and entity.has("facing_direction"):
		return entity.get("facing_direction")
	
	return current_direction

func _is_authority() -> bool:
	if not entity:
		return true
	
	if entity.has_method("_local_is_authority"):
		return entity.call("_local_is_authority")
	
	if entity.has_method("is_multiplayer_authority"):
		var mp = entity.multiplayer.multiplayer_peer
		if mp and mp.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			return entity.call("is_multiplayer_authority")
	
	return true

func sync_remote_animation(dir: Vector2, is_attacking: bool, is_moving: bool) -> void:
	update_animation_parameters(dir)
	
	if is_attacking:
		force_state(attack_state_name)
	elif is_moving:
		force_state(walk_state_name)
	else:
		force_state(idle_state_name)

func flash_red() -> void:
	var sprite := get_sprite()
	if sprite == null:
		return

	sprite.modulate = Color(1, 0.2, 0.2, 1)
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(sprite):
		sprite.modulate = Color(1, 1, 1, 1)
