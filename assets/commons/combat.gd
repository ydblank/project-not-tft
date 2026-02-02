extends Node
class_name CombatGlobal

static func calculate_attack_speed(stats_resource: StatsComponent) -> float:
	if stats_resource == null:
		return 0.1
	
	var entity_stats = stats_resource.get_entity_stats()
	var class_attack_speed_bonus: float = float(entity_stats.get("attack_speed", 1.0))
	var weapon_attack_speed_bonus: float = float(stats_resource.weapon_obj.get("attack_speed", 0.0))

	# Additive: base + class_bonus + weapon_bonus
	var final_speed := class_attack_speed_bonus + weapon_attack_speed_bonus
	print("Final Attack Speed: ", final_speed)
	return max(final_speed, 0.001)
	
static func calculate_attack_damage(stats_resource: StatsComponent) -> float:
	if stats_resource == null:
		return 1.0
	
	var entity_stats = stats_resource.get_entity_stats()
	var entity_str: float = float(entity_stats.get("str", 1.0))
	var weapon_dmg: float = float(stats_resource.weapon_obj.get("dmg", 0))
	
	var total_dmg = entity_str * weapon_dmg
	print("Total Damage: ", total_dmg)
	return max(total_dmg, 1)
	
static func calculate_receive_damage(stats_resource: StatsComponent, received_damage: float) -> float:
	if stats_resource == null:
		return received_damage
	
	var entity_stats = stats_resource.get_entity_stats()
	var entity_def: int = int(entity_stats.get("def", 0))
	
	var eff_def = 1.0 - (float(entity_def) / 100)
	var total_receieved_damage = eff_def * received_damage
	return max(total_receieved_damage, 1)
