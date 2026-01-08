extends Node

class calculations:
	static func assign_player_stats(player_stats: Dictionary, class_stats: Dictionary):
		var new_stats = {
			"hp": float(player_stats.get("hp", 0)) + float(class_stats.get("hp", 0)),
			"str": float(player_stats.get("str", 1)) + float(class_stats.get("str", 0)),
			"def": float(player_stats.get("def", 0)) + float(class_stats.get("def", 0)),
			"knockback_res": float(player_stats.get("knockback_res", 0)) + float(class_stats.get("knockback_res", 0)),
			"attack_speed": float(player_stats.get("attack_speed", 0)) + float(class_stats.get("attack_speed", 0))
		}
		
		return new_stats
		
	static func calculate_attack_speed(entity_stats: Dictionary, weapon_stats: Dictionary):
		const base_attack_speed = 10
		var class_multiplier: float = float(entity_stats.get("attack_speed", 1.0))
		var weapon_speed: float = float(weapon_stats.get("attack_speed", 1.0))

		var final_speed := (weapon_speed * class_multiplier) / base_attack_speed
		return max(final_speed, 0.001)
		
	static func calculate_attack_damage(entity_stats: Dictionary, weapon_stats: Dictionary):
		var entity_str: float = float(entity_stats.get("str", 1.0))
		var weapon_dmg: float = float(weapon_stats.get("dmg", 0))
		
		var total_dmg = entity_str * weapon_dmg
		print(total_dmg)
		return max(total_dmg, 1)
		
	static func calculate_receive_damage(entity_stats: Dictionary, received_damage: float):
		var entity_def: int = int(entity_stats.get("def", 0))
		
		var eff_def = 1.0 - (float(entity_def)/100)
		var total_receieved_damage = eff_def * received_damage
		return max(total_receieved_damage, 1)
