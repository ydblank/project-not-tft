extends Node

# Autoloaded as "Sfx". One place to play sound effects and to set the volume of
# the two audio buses it creates:
#   "SFX"   - everything played through Sfx.play()
#   "Music" - put music players on this bus (AudioStreamPlayer.bus = "Music")
#
#   Sfx.play(&"hit")                       # by name, see SOUNDS
#   Sfx.play(&"hit", -6.0, 0.9)            # quieter, lower pitch
#
# Sounds are plain files in assets/audio/sfx/. To change a sound, replace the file.

const BUS_SFX := &"SFX"
const BUS_MUSIC := &"Music"
const FOLDER := "res://assets/audio/sfx/"
const POOL_SIZE := 16
## The same sound cannot restart faster than this (seconds), so a flurry of hits does not stack into noise.
const MIN_REPEAT := 0.04

const SOUNDS := {
	# One file, or several: a random one is picked each time (never the same twice in a row).
	&"swing_light": "swing_light.wav",
	&"burn": "swing_light.wav", # burning-ground tick: PLACEHOLDER, the quick whoosh played low until a real sizzle is added
	&"swing_heavy": ["swing_heavy.wav", "swing_heavy_2.wav"],
	&"bow_release": ["bow_release.wav", "bow_release_2.wav"],
	&"dash": "dash.wav", # the grunt only (no whoosh)
	&"grunt": "dash.wav", # the same grunt recording, played lower / higher when a fighter lands a hit
	&"hit": ["hit.wav", "hit_2.wav", "hit_3.wav"],
	&"block": "block.wav",
	&"wall_hit": "countdown_tick.wav", # a projectile hitting a wall: the short dry wood tick, played lower for a dull thump (the block clang rang too long, high pitch was too tiny)
	&"wall_stone": "wall_stone.wav", # layered under wall_hit: a real stone hit (Sonniss Bluezone Stone Impact 041), trimmed to 0.4 s, mono
	# Reused recordings, played at different pitches: parry (bright), clash (heavy clang), armor (dull thud), finisher (deep hit).
	&"parry": "block.wav",
	&"clash": "block.wav",
	&"armor": "block.wav",
	&"finisher": ["hit_2.wav", "hit_3.wav"],
	&"guard_break": "guard_break.wav",
	&"death": "death.wav",
	&"countdown_tick": "countdown_tick.wav",
	&"fight": "fight.wav",
	&"ui_open": "ui_open.wav",
	&"ui_close": "ui_close.wav",
}

## Dev-tunable (pause menu), 0..1.
var sfx_volume: float = 0.8
var music_volume: float = 0.8

var _streams: Dictionary = {}
var _last_played: Dictionary = {}
var _last_variant: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # menu sounds play while the game is paused
	_ensure_bus(BUS_SFX)
	_ensure_bus(BUS_MUSIC)
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		_pool.append(player)
	_apply_volumes()


## Plays a sound. volume_db is relative to the SFX bus; pitch is a multiplier
## (1.0 = normal). pitch_jitter randomly varies pitch (and with it speed, they are one
## setting in Godot) by up to +-4% by default, and volume_jitter varies loudness by up to
## +-1 dB, so repeats do not sound identical (a little variation, close to the recording). Sounds with several files pick one at random.
func play(sound: StringName, volume_db: float = 0.0, pitch: float = 1.0, pitch_jitter: float = 0.04, volume_jitter: float = 1.0) -> void:
	var stream := _pick_stream(sound)
	if stream == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(sound, -10.0)) < MIN_REPEAT:
		return
	_last_played[sound] = now
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.volume_db = volume_db + randf_range(-volume_jitter, volume_jitter)
	player.pitch_scale = maxf(pitch * (1.0 + randf_range(-pitch_jitter, pitch_jitter)), 0.1)
	player.play()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()


func _apply_volumes() -> void:
	_set_bus_volume(BUS_SFX, sfx_volume)
	_set_bus_volume(BUS_MUSIC, music_volume)


func _set_bus_volume(bus: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(index, linear <= 0.0)


func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, &"Master")


## A random variant of the sound, never the same one twice in a row.
func _pick_stream(sound: StringName) -> AudioStream:
	var variants := _variants_for(sound)
	if variants.is_empty():
		return null
	var index := randi() % variants.size()
	if variants.size() > 1 and index == int(_last_variant.get(sound, -1)):
		index = (index + 1 + randi() % (variants.size() - 1)) % variants.size()
	_last_variant[sound] = index
	return variants[index]


func _variants_for(sound: StringName) -> Array:
	if _streams.has(sound):
		return _streams[sound]
	var entry: Variant = SOUNDS.get(sound, null)
	if entry == null:
		push_warning("Sfx: unknown sound '%s'" % sound)
		return []
	var files: Array = entry if entry is Array else [entry]
	var loaded: Array = []
	for file in files:
		var path: String = FOLDER + String(file)
		var stream: AudioStream = load(path) as AudioStream if ResourceLoader.exists(path) else null
		if stream:
			loaded.append(stream)
		else:
			push_warning("Sfx: could not load %s" % path)
	_streams[sound] = loaded
	return loaded
