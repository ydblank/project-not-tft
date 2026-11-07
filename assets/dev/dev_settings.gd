extends RefCounted
class_name DevSettings

# Dev-tunable "game feel" variables. The pause menu edits them, DevTuning
# pushes them into the running game, and they are saved to disk so they survive
# restarts. Defaults match the values the game ships with, so an untouched
# settings file changes nothing.
#
# To add a setting: add a row to DEFS, then apply it in DevTuning.

const SAVE_PATH := "user://dev_settings.cfg"
const SECTION := "dev"

# type: "float" | "int" | "bool". group: header in the menu.
const DEFS := [
	# ---- Difficulty (also the pause menu's Difficulty button) ----
	{"key": "difficulty", "group": "Difficulty", "label": "0 Easy, 1 Normal, 2 Hard", "type": "int", "min": 0, "max": 2, "step": 1, "default": 1},
	# ---- Display ----
	{"key": "show_knockback", "group": "Display", "label": "Show knockback % next to health bars", "type": "bool", "default": true},
	# ---- Controls ----
	{"key": "rumble_strength", "group": "Controls", "label": "Controller rumble (0 = off)", "type": "float", "min": 0.0, "max": 1.0, "step": 0.1, "default": 0.7},
	# ---- Match ----
	{"key": "skip_countdown", "group": "Match", "label": "Skip the 3-2-1 countdown (next launch)", "type": "bool", "default": false},
	# ---- Dash ----
	{"key": "dash_charges", "group": "Dash", "label": "Charges", "type": "int", "min": 1, "max": 5, "step": 1, "default": 3},
	{"key": "dash_recharge_time", "group": "Dash", "label": "Recharge per charge (s)", "type": "float", "min": 0.2, "max": 5.0, "step": 0.1, "default": 1.5},
	{"key": "dash_reload_time", "group": "Dash", "label": "Slow reload when empty (s)", "type": "float", "min": 0.2, "max": 6.0, "step": 0.1, "default": 2.5},
	{"key": "dash_first_charge_speed", "group": "Dash", "label": "First charge back after all used: speed x", "type": "float", "min": 1.0, "max": 4.0, "step": 0.25, "default": 2.0},
	{"key": "dash_gap", "group": "Dash", "label": "Gap between dashes (s)", "type": "float", "min": 0.0, "max": 0.6, "step": 0.01, "default": 0.0},
	{"key": "dash_speed", "group": "Dash", "label": "Dash speed", "type": "float", "min": 100.0, "max": 800.0, "step": 10.0, "default": 300.0},
	{"key": "dash_duration", "group": "Dash", "label": "Dash duration (s)", "type": "float", "min": 0.05, "max": 0.6, "step": 0.01, "default": 0.2},
	{"key": "dash_invulnerable", "group": "Dash", "label": "Invulnerable while dashing", "type": "bool", "default": true},

	# ---- Movement ----
	{"key": "move_speed_mult", "group": "Movement", "label": "Walk speed x", "type": "float", "min": 0.3, "max": 2.5, "step": 0.05, "default": 1.0},
	{"key": "ranged_strafe_speed", "group": "Movement", "label": "Strafe speed while shooting", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "default": 0.15},
	{"key": "charge_block_speed", "group": "Movement", "label": "Speed while charging / blocking", "type": "float", "min": 0.05, "max": 1.0, "step": 0.05, "default": 0.25},

	# ---- Combat ----
	{"key": "attack_speed_mult", "group": "Combat", "label": "Attack speed x", "type": "float", "min": 0.3, "max": 3.0, "step": 0.05, "default": 1.0},
	{"key": "damage_mult", "group": "Combat", "label": "Damage x", "type": "float", "min": 0.1, "max": 5.0, "step": 0.1, "default": 1.0},
	{"key": "knockback_force", "group": "Combat", "label": "Knockback force", "type": "float", "min": 0.0, "max": 800.0, "step": 10.0, "default": 220.0},
	{"key": "hitstop_mult", "group": "Combat", "label": "Hitstop x", "type": "float", "min": 0.0, "max": 4.0, "step": 0.1, "default": 1.0},
	{"key": "shake_mult", "group": "Combat", "label": "Camera shake x", "type": "float", "min": 0.0, "max": 3.0, "step": 0.1, "default": 1.0},
	{"key": "light_combo_cooldown", "group": "Combat", "label": "Quick-combo cooldown (s)", "type": "float", "min": 0.0, "max": 2.0, "step": 0.05, "default": 0.6},
	{"key": "combo_hitstun", "group": "Combat", "label": "Combo hitstun (s)", "type": "float", "min": 0.0, "max": 1.5, "step": 0.05, "default": 0.55},
	{"key": "post_stun_immunity", "group": "Combat", "label": "Stun immunity after a stun (s)", "type": "float", "min": 0.0, "max": 1.5, "step": 0.05, "default": 0.5},
	{"key": "parry_window", "group": "Combat", "label": "Parry window (s)", "type": "float", "min": 0.0, "max": 0.5, "step": 0.01, "default": 0.2},
	{"key": "armor_hp", "group": "Combat", "label": "Heavy super armor durability (0 = none)", "type": "float", "min": 0.0, "max": 40.0, "step": 1.0, "default": 10.0},
	{"key": "damage_numbers", "group": "Combat", "label": "Damage numbers", "type": "bool", "default": true},
	{"key": "enemy_tells", "group": "Combat", "label": "Enemy wind-up warnings", "type": "bool", "default": true},

	# ---- Skills (weapon skill on E). Distances are in arena tiles (16 px); F5 shows a tile ruler. ----
	# Rows with "skill" + "field" have no default of their own: it is that field of the skills table
	# (assets/resources/skills.gd), so the table stays the one place the balance lives.
	{"key": "skill_cooldown_scale", "group": "Skills", "label": "Cooldown x", "type": "float", "min": 0.1, "max": 3.0, "step": 0.05, "default": 1.0},
	{"key": "skill_spin_radius", "group": "Skills", "label": "Sword spin radius (tiles)", "type": "float", "min": 0.5, "max": 6.0, "step": 0.25, "skill": "sword_spin", "field": "radius_tiles"},
	{"key": "skill_spin_move", "group": "Skills", "label": "Sword spin walking speed (x normal)", "type": "float", "min": 0.0, "max": 1.5, "step": 0.05, "skill": "sword_spin", "field": "move_speed_mult"},
	{"key": "skill_dagger_range", "group": "Skills", "label": "Dagger dash range (tiles)", "type": "float", "min": 1.0, "max": 15.0, "step": 0.5, "skill": "dagger_dash", "field": "range_tiles"},
	{"key": "skill_volley_range", "group": "Skills", "label": "Bow volley range (tiles)", "type": "float", "min": 2.0, "max": 25.0, "step": 0.5, "skill": "bow_volley", "field": "range_tiles"},
	{"key": "skill_volley_spread", "group": "Skills", "label": "Bow volley spread (degrees)", "type": "float", "min": 5.0, "max": 120.0, "step": 5.0, "skill": "bow_volley", "field": "spread_deg"},
	{"key": "skill_fireball_range", "group": "Skills", "label": "Fireball range (tiles)", "type": "float", "min": 2.0, "max": 20.0, "step": 0.5, "skill": "staff_fireball", "field": "range_tiles"},
	{"key": "skill_fireball_cast", "group": "Skills", "label": "Fireball cast time (s)", "type": "float", "min": 0.0, "max": 2.0, "step": 0.1, "skill": "staff_fireball", "field": "cast_time"},
	{"key": "skill_fireball_radius", "group": "Skills", "label": "Fireball blast radius (tiles)", "type": "float", "min": 0.5, "max": 8.0, "step": 0.25, "skill": "staff_fireball", "field": "radius_tiles"},
	{"key": "skill_burn_radius", "group": "Skills", "label": "Burning ground radius (tiles)", "type": "float", "min": 0.5, "max": 8.0, "step": 0.25, "skill": "staff_fireball", "field": "burn_radius_tiles"},

	# ---- Ultimate (class ultimate on Q). The balance numbers live in assets/resources/ultimates.gd. ----
	{"key": "ult_charge_scale", "group": "Ultimate", "label": "Meter fill speed x", "type": "float", "min": 0.1, "max": 5.0, "step": 0.1, "default": 1.0},
	{"key": "ult_duration_scale", "group": "Ultimate", "label": "Duration x", "type": "float", "min": 0.2, "max": 3.0, "step": 0.1, "default": 1.0},
	{"key": "ult_always_full", "group": "Ultimate", "label": "Always full (testing, every fighter)", "type": "bool", "default": false},

	# ---- Audio ----
	{"key": "sfx_volume", "group": "Audio", "label": "Sound effects volume", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "default": 0.8, "percent": true},
	{"key": "music_volume", "group": "Audio", "label": "Music volume", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "default": 0.8, "percent": true},

	# ---- Camera ----
	{"key": "camera_follow", "group": "Camera", "label": "Follow strength", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "default": 0.35},
	{"key": "death_slowmo", "group": "Camera", "label": "Death slow-motion and zoom", "type": "bool", "default": true},

	# ---- Arena ----
	{"key": "arena_damage_percent", "group": "Arena", "label": "Outside damage (% max HP / s)", "type": "float", "min": 0.0, "max": 40.0, "step": 1.0, "default": 8.0},
	{"key": "arena_slow", "group": "Arena", "label": "Outside speed x", "type": "float", "min": 0.1, "max": 1.0, "step": 0.05, "default": 0.5},

	# ---- AI ----
	{"key": "ai_attack_cooldown", "group": "AI", "label": "Attack cooldown (s)", "type": "float", "min": 0.1, "max": 3.0, "step": 0.1, "default": 0.7},
	{"key": "ai_dodge_enabled", "group": "AI", "label": "Dodging", "type": "bool", "default": true},
	{"key": "ai_dodge_cooldown", "group": "AI", "label": "Dodge cooldown (s)", "type": "float", "min": 0.1, "max": 3.0, "step": 0.1, "default": 0.8},
	{"key": "respawn_delay", "group": "AI", "label": "Respawn delay (s)", "type": "float", "min": 0.5, "max": 10.0, "step": 0.5, "default": 2.5},
]

static var values: Dictionary = {}
static var _loaded: bool = false


## Loads defaults, then the saved file on top. Safe to call repeatedly.
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	reset_all()
	load_file()


static func get_value(key: String) -> Variant:
	ensure_loaded()
	return values.get(key, default_of(key))


static func set_value(key: String, value: Variant) -> void:
	ensure_loaded()
	var def := def_for(key)
	if def.is_empty():
		return
	values[key] = _coerce(def, value)


static func default_of(key: String) -> Variant:
	return _default_for(def_for(key))


## A row's default: its own "default", or for skill rows the skills table's value.
static func _default_for(def: Dictionary) -> Variant:
	if def.has("skill"):
		return Skills.value(def.skill, def.field, def.get("default"))
	return def.get("default")


static func def_for(key: String) -> Dictionary:
	for def in DEFS:
		if def.key == key:
			return def
	return {}


static func reset_all() -> void:
	values.clear()
	for def in DEFS:
		values[def.key] = _default_for(def)


static func is_default(key: String) -> bool:
	return get_value(key) == default_of(key)


static func save() -> Error:
	ensure_loaded()
	var cfg := ConfigFile.new()
	for def in DEFS:
		# Only settings that were changed are written, so an untouched one follows its default
		# (and a new value in the skills table) instead of being pinned to an old one.
		if values[def.key] != _default_for(def):
			cfg.set_value(SECTION, def.key, values[def.key])
	return cfg.save(SAVE_PATH)


## Reads the save file (if any). Unknown keys are ignored, bad values clamped.
static func load_file(path: String = SAVE_PATH) -> Error:
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err != OK:
		return err
	for def in DEFS:
		if cfg.has_section_key(SECTION, def.key):
			values[def.key] = _coerce(def, cfg.get_value(SECTION, def.key))
	return OK


static func _coerce(def: Dictionary, value: Variant) -> Variant:
	match def.type:
		"bool":
			return bool(value)
		"int":
			return clampi(int(value), int(def.min), int(def.max))
		_:
			return clampf(float(value), float(def.min), float(def.max))
