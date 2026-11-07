extends Node
class_name DevTuning

# Pushes the DevSettings values into the running game: every fighter (player,
# enemies, allies), the arena, the respawner and the global combat multipliers.
# Add one to the level. New fighters (respawns) are tuned as they appear.

const FIGHTER_GROUPS := ["players", "enemies", "allies"]


func _ready() -> void:
	DevSettings.ensure_loaded()
	get_tree().node_added.connect(_on_node_added)
	call_deferred("apply_all")


func _on_node_added(node: Node) -> void:
	if node is CharacterBody2D:
		for group_name in FIGHTER_GROUPS:
			if node.is_in_group(group_name):
				call_deferred("_apply_entity_deferred", node)
				return


func _apply_entity_deferred(node: Node) -> void:
	if is_instance_valid(node):
		_apply_entity(node)


func apply_all() -> void:
	var seen: Dictionary = {}
	for group_name in FIGHTER_GROUPS:
		for node in get_tree().get_nodes_in_group(group_name):
			if not seen.has(node):
				seen[node] = true
				_apply_entity(node)
	_apply_globals()


func _apply_globals() -> void:
	Combat.hitstop_multiplier = DevSettings.get_value("hitstop_mult")
	Combat.damage_multiplier = DevSettings.get_value("damage_mult")
	Combat.enemy_damage_multiplier = Difficulty.preset(int(DevSettings.get_value("difficulty"))).damage
	Combat.shake_multiplier = DevSettings.get_value("shake_mult")
	Sfx.set_sfx_volume(DevSettings.get_value("sfx_volume"))
	Sfx.set_music_volume(DevSettings.get_value("music_volume"))
	Combat.show_damage_numbers = DevSettings.get_value("damage_numbers")
	Combat.enemy_tells = DevSettings.get_value("enemy_tells")
	_apply_skills()

	var level := get_parent()
	if level == null:
		return
	var arena := level.get_node_or_null("ArenaBounds") as ArenaBounds
	if arena:
		arena.damage_percent_per_second = DevSettings.get_value("arena_damage_percent")
		arena.speed_multiplier_outside = DevSettings.get_value("arena_slow")
	var cam_follow := level.get_node_or_null("CameraFollow") as CameraFollow
	if cam_follow:
		cam_follow.follow_strength = DevSettings.get_value("camera_follow")
	var death_slowmo := level.get_node_or_null("DeathSlowMo") as DeathSlowMo
	if death_slowmo:
		death_slowmo.enabled = DevSettings.get_value("death_slowmo")
	var respawner := level.get_node_or_null("EnemyRespawner") as EnemyRespawner
	if respawner:
		respawner.respawn_delay = DevSettings.get_value("respawn_delay")


func _apply_entity(entity: Node) -> void:
	var combat := CombatComponent.find_on(entity)
	if combat == null or combat.sm == null:
		return
	var v := func(key: String) -> Variant: return DevSettings.get_value(key)

	# ---- dash ----
	var stats := combat.stats_component
	if stats:
		stats.dash_charges = v.call("dash_charges")
		stats.dash_recharge_time = v.call("dash_recharge_time")
		stats.dash_reload_time = v.call("dash_reload_time")
		stats.dash_cooldown = v.call("dash_gap")
		stats.dash_speed = v.call("dash_speed")
		stats.dash_duration = v.call("dash_duration")
		var sm := combat.sm
		sm.dash_first_charge_speedup = v.call("dash_first_charge_speed")
		# Only touch the dash state when something changed (configure refills charges).
		if sm.dash_max_charges != stats.dash_charges \
				or not is_equal_approx(sm.dash_recharge_time, stats.dash_recharge_time) \
				or not is_equal_approx(sm.dash_reload_time, stats.dash_reload_time) \
				or not is_equal_approx(sm.dash_cooldown, stats.dash_cooldown) \
				or not is_equal_approx(sm.dash_duration, stats.dash_duration):
			sm.configure_dash(stats.dash_duration, stats.dash_cooldown, stats.dash_charges, stats.dash_recharge_time, stats.dash_reload_time)
	combat.dash_invulnerable = v.call("dash_invulnerable")

	# ---- movement ----
	var move := combat.movement_component
	if move and stats:
		move.dash_speed = stats.dash_speed
		move.move_speed = float(stats.get_entity_stats().get("move_speed", 100.0)) * float(v.call("move_speed_mult"))
	combat.ranged_attack_speed_mult = v.call("ranged_strafe_speed")
	combat.slowed_speed_mult = v.call("charge_block_speed")

	# ---- combat ----
	combat.set_attack_speed_scale(v.call("attack_speed_mult"))
	combat.post_stun_immunity = v.call("post_stun_immunity")
	combat.set_parry_window(v.call("parry_window"))
	combat.armor_hp_max = v.call("armor_hp")
	combat.set_skill_cooldown_scale(v.call("skill_cooldown_scale"))
	# These two override the weapons table (assets/resources/weapons.gd) only once their slider is moved.
	if combat.weapon and not DevSettings.is_default("combo_hitstun"):
		combat.weapon.combo_hitstun = v.call("combo_hitstun")
	if combat.weapon and combat.weapon.light_move_count() > 1 and not DevSettings.is_default("light_combo_cooldown"):
		combat.weapon.light_combo_cooldown = v.call("light_combo_cooldown")
	if combat.hitbox_component:
		combat.hitbox_component.base_knockback_force = v.call("knockback_force")

	# ---- AI (only enemies / allies have one) ----
	var ai := _find_ai(entity)
	if ai:
		# Difficulty only changes the enemy bots, not your teammate.
		var diff := Difficulty.preset(int(v.call("difficulty")) if entity.is_in_group("enemies") else Difficulty.NORMAL)
		ai.attack_cooldown = float(v.call("ai_attack_cooldown")) * diff.attack_cooldown
		ai.dodge_enabled = v.call("ai_dodge_enabled")
		ai.dodge_cooldown = float(v.call("ai_dodge_cooldown")) * diff.dodge_cooldown
		ai.guard_punish_chance = diff.guard_punish
		_scale_from_base(ai, "dodge_reaction_time", diff.dodge_reaction)
		_scale_from_base(ai, "combo_break_reaction", diff.combo_break)
		_scale_from_base(ai, "dash_decision_interval", diff.dash_interval)
		_scale_from_base(ai, "skill_aim_time", diff.dodge_reaction) # harder bots telegraph their skills for less time


## Sets an AI timer to `multiplier` x its original value (remembered the first time, so applying again never compounds).
func _scale_from_base(ai: AIComponent, property: String, multiplier: float) -> void:
	var key := "base_" + property
	if not ai.has_meta(key):
		ai.set_meta(key, ai.get(property))
	ai.set(property, float(ai.get_meta(key)) * multiplier)


func _find_ai(entity: Node) -> AIComponent:
	for child in entity.get_children():
		if child is AIComponent:
			return child
		for grandchild in child.get_children():
			if grandchild is AIComponent:
				return grandchild
	return null


## Skills sliders: each row names a skills-table field (assets/resources/skills.gd) and defaults to its
## value, so an untouched slider leaves the table in charge. Written into the weapons' shared SkillData
## resources for this run only (the files on disk keep their values).
func _apply_skills() -> void:
	var by_id := {}
	for weapon in Weapons.WEAPONS.values():
		var data := Weapons.get_weapon_data(weapon)
		if data and data.skill:
			by_id[Skills.id_of(data.skill)] = data.skill
	for def in DevSettings.DEFS:
		if def.has("skill") and by_id.has(def.skill):
			Skills.set_field(by_id[def.skill], def.field, DevSettings.get_value(def.key))
