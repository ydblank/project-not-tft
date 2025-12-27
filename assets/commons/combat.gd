extends Node

class calculations:
	static func assign_player_stats(player_stats: Dictionary, class_stats: Dictionary):
		var new_stats = {
			"hp": float(player_stats.get("hp", 0)) + float(class_stats.get("hp", 0)),
			"dmg": float(player_stats.get("dmg", 0)) + float(class_stats.get("dmg", 0)),
			"def": float(player_stats.get("def", 0)) + float(class_stats.get("attack_speed", 0)),
			"knockback_res": float(player_stats.get("knockback_res", 0)) + float(class_stats.get("knockback_res", 0)),
			"attack_speed": float(player_stats.get("attack_speed", 0)) + float(class_stats.get("attack_speed", 1.0))
		}
		
		return new_stats
		
	static func calculate_attack_speed(player_stats: Dictionary, weapon_stats: Dictionary):
		const base_attack_speed = 10
		var class_multiplier: float = float(player_stats.get("attack_speed", 1.0))
		var weapon_speed: float = float(weapon_stats.get("attack_speed", 1.0))

		var final_speed := (weapon_speed * class_multiplier) / base_attack_speed
		return max(final_speed, 0.001)
