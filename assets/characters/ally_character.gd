extends "res://assets/characters/enemy_character.gd"

# An AI fighter on the player's side. It reuses the enemy scene and death
# handling, but joins the "allies" group instead of "enemies" so it is hunted
# by enemies, bound by the arena, and never confused with the human player.


func _enter_tree() -> void:
	remove_from_group("enemies")
	add_to_group("allies")
