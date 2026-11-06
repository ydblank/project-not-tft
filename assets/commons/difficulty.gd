extends RefCounted
class_name Difficulty

# Easy / Normal / Hard. The pause menu's Difficulty button (or the Settings slider) picks one, and
# DevTuning applies it to the enemy bots: how hard they hit and how fast they react. Your teammate and
# fighters a human controls are not changed.
#
# Every number is a multiplier on the normal value.
#   damage          how hard enemy bots hit (HP is not changed)
#   attack_cooldown pause between an enemy bot's attacks (bigger = slower)
#   dodge_cooldown  wait between dodges
#   dodge_reaction  delay before it dodges an arrow
#   combo_break     delay before it dashes out of a combo
#   dash_interval   how often it considers dashing

const NAMES: Array[String] = ["Easy", "Normal", "Hard"]
const NORMAL := 1

const PRESETS: Array[Dictionary] = [
	{"damage": 0.6, "attack_cooldown": 1.6, "dodge_cooldown": 2.0, "dodge_reaction": 1.6, "combo_break": 1.6, "dash_interval": 1.5},
	{"damage": 1.0, "attack_cooldown": 1.0, "dodge_cooldown": 1.0, "dodge_reaction": 1.0, "combo_break": 1.0, "dash_interval": 1.0},
	{"damage": 1.3, "attack_cooldown": 0.6, "dodge_cooldown": 0.6, "dodge_reaction": 0.6, "combo_break": 0.6, "dash_interval": 0.7},
]


## The multipliers for a difficulty index (0 Easy, 1 Normal, 2 Hard).
static func preset(index: int) -> Dictionary:
	return PRESETS[clampi(index, 0, PRESETS.size() - 1)]


static func name_of(index: int) -> String:
	return NAMES[clampi(index, 0, NAMES.size() - 1)]
